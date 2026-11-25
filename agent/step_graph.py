"""Step-graph walker (B4): deterministic core of the Soro tutor.

Guarantees, enforced here and not left to the LLM:
  * every reply ends with exactly ONE question;
  * tutor text and tutor ink come only from the lesson pack (never generated),
    and a leak guard blocks final answers (roots, factors) before sending;
  * a known misconception gets its own targeted correction from the pack;
  * wrong answers climb the hint ladder; student ink only echoes what the
    student said.
"""
from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from typing import Callable, Optional

NFC = lambda s: unicodedata.normalize("NFC", s)

# Same patterns as content/validate.py: final answers a tutor must never state.
LEAKS = [r"x\s*=\s*-?\d", r"\(x\s*[-+−]\s*\d+\)", r"\bvertex\s*[:=]", r"x\s*[-+−]\s*\d+\s*=\s*0"]

# Prose steps cannot be parsed deterministically; keyword fallback by "<problem>.<step>".
KEYWORDS = {
    "p1.s4": [r"\bzero\b", r"\b0\b", r"equals?\s*0", r"is\s*0"],
    "p1.s5": [r"\b(match|matches|same|yes|agree)\b", r"\bcross"],
    "p2.s4": [r"square\s*root", r"root\b", r"±|plus or minus|plus and minus"],
}
KEYWORDS["*.s4"] = KEYWORDS["p1.s4"]  # factorable problems p3.. share the p1 prose steps
KEYWORDS["*.s5"] = KEYWORDS["p1.s5"]

READY_EN = "Ready to try one on your own, with no help from me?"
READY_YO = "Ṣé o ṣetán láti gbìyànjú ọ̀kan fúnra rẹ, láìsí ìrànlọ́wọ́ mi?"  # needs native check

REJECT = re.compile(r"(doesn'?t|does not|not)\s+help|don'?t (get|understand)|no help|confus", re.I)
ANALOGIES = {  # one at a time; each ends with ONE question and never gives an answer
    "root": ("Think of a ball thrown up: it lands where its path meets the ground. Where would that be for this curve?",
             "Ronú nípa bọ́ọ̀lù tí a ju sókè: ó ń balẹ̀ níbi tí ọ̀nà rẹ̀ ti pàdé ilẹ̀. Níbo ni ìyẹn máa jẹ́ lórí ìlà yìí?"),
    "friction": ("Think of a danfo skidding on a wet road: what is missing between the tyres and the road?",
                 "Ronú nípa danfo tó ń yọ̀ lórí ọ̀nà tó tutù: kí ni ó dín kù láàrin táyà àti ọ̀nà?"),
}


@dataclass
class Turn:
    kind: str  # open | correct | misconception | hint | transfer | analogy | done
    text_en: str
    text_yo: str
    step_id: str
    canvas_ops: list = field(default_factory=list)
    term_ids: list = field(default_factory=list)
    needs_analogy: bool = False
    transfer_check: Optional[dict] = None


def canon(text: str) -> str:
    t = NFC(text).lower().replace("−", "-").replace("–", "-").replace("×", "*").replace("²", "^2")
    return re.sub(r"\s+", "", t)


def ensure_one_question(text: str, fallback: str) -> str:
    """Return text if it already ends in exactly one question, else append the step prompt."""
    t = text.strip()
    if t.count("?") == 1 and t.endswith("?"):
        return t
    if "?" in t:  # stray question mid-text: drop to the prompt alone
        return fallback
    return f"{t} {fallback}"


def leaks(text: str) -> bool:
    return any(re.search(p, text) for p in LEAKS)


def answer_patterns(problem: dict) -> list[str]:
    """Patterns for THIS problem's true answer, derived from its `factored=` concepts.

    A correction may echo the student's wrong factors, e.g. (x + 2)(x + 3); only the
    real factors and roots are forbidden.
    """
    pats = [r"\bvertex\s*[:=]"]
    for step in problem["steps"]:
        for c in step.get("acceptable_concepts", []):
            name, _, value = c.partition("=")
            if name != "factored":
                continue
            for off in _offsets(canon(value)):
                sign = r"[-−]" if off < 0 else r"\+"
                pats.append(rf"\(x\s*{sign}\s*{abs(off)}\)")
                pats.append(rf"x\s*=\s*{-off}(?!\d)")
    return pats


def _nums(c: str) -> list[int]:
    return [int(n) for n in re.findall(r"[+-]?\d+", c)]


def _offsets(c: str) -> list[int]:
    return sorted(int(n) for n in re.findall(r"\(x([+-]\d+)\)", c))


def match_concept(concept: str, text: str) -> Optional[bool]:
    """True/False for parseable concepts, None for prose (needs keywords or judge)."""
    name, _, value = concept.partition("=")
    c = canon(text)
    if name in {"a", "b", "c"}:
        m = re.search(rf"(?<![a-z]){name}=([+-]?\d+)", c)
        return bool(m) and int(m.group(1)) == int(value)
    if name == "pair":
        want, have = _nums(value), _nums(c)
        return all(w in have for w in want)
    if name == "factored":
        return _offsets(canon(value)) == _offsets(c) and bool(_offsets(c))
    return None


def _dedupe(concepts: list[str]) -> list[str]:
    seen, out = set(), []
    for c in concepts:
        name, _, v = c.partition("=")
        key = (name, tuple(sorted(_nums(v)))) if name == "pair" else c
        if key not in seen:
            seen.add(key)
            out.append(c)
    return out


class Walker:
    def __init__(self, pack: dict, problem_id: str = "p1",
                 judge: Optional[Callable[[dict, str], Optional[str]]] = None):
        self.pack = pack
        self.problem = next(p for p in pack["problems"] if p["id"] == problem_id)
        self.steps = self.problem["steps"]
        self.i = 0
        self.attempts = 0
        self.judge = judge  # (step, text) -> "correct" | misconception key | None
        self.analogy_used: set[str] = set()
        self.analogy_dropped = False
        self.finished = False
        self.forbidden = answer_patterns(self.problem)

    def _leaks(self, text: str) -> bool:
        return any(re.search(p, text) for p in self.forbidden)

    # -- helpers ---------------------------------------------------------
    @property
    def step(self) -> dict:
        return self.steps[self.i]

    def _prompt(self) -> tuple[str, str]:
        return self.step["prompt_en"], self.step["prompt_yo"]

    def _guard(self, en: str, yo: str) -> tuple[str, str]:
        """Final safety net: never emit a final answer, never emit a non-question."""
        pen, pyo = self._prompt()
        if self._leaks(en) or self._leaks(yo):
            return pen, pyo
        return ensure_one_question(en, pen), ensure_one_question(yo, pyo)

    def _tutor_ops(self) -> list:
        ops = []
        for op in self.step.get("canvas_ops", []):
            p = op.get("params", {})
            if p.get("author") == "tutor" and (p.get("reveal_answer") or self._leaks(p.get("latex_or_text", ""))):
                continue  # drop any op that would write the answer
            ops.append({"v": 1, "type": "canvas_cmd", "sim": self.pack["sim"], "visual": self.pack["visual"], **op})
        return ops

    # -- public API ------------------------------------------------------
    def open(self) -> Turn:
        en, yo = self._guard(*self._prompt())
        return Turn("open", en, yo, self.step["id"], self._tutor_ops(), self.step.get("term_ids", []))

    def classify(self, text: str) -> tuple[str, Optional[str]]:
        step = self.step
        concepts = _dedupe(step.get("acceptable_concepts", []))
        for key in step.get("misconceptions", {}):
            if match_concept(key, text) is True:
                return "misconception", key
        results = [match_concept(c, text) for c in concepts]
        if results and all(r is True for r in results):
            return "correct", None
        if any(r is None for r in results):  # prose step
            kw = KEYWORDS.get(f"{self.problem['id']}.{step['id']}") or KEYWORDS.get(f"*.{step['id']}", [])
            if any(re.search(p, text, re.I) for p in kw):
                return "correct", None
        if self.judge:
            verdict = self.judge(step, text)
            if verdict == "correct":
                return "correct", None
            if verdict in step.get("misconceptions", {}):
                return "misconception", verdict
        return "incorrect", None

    def submit(self, text: str) -> Turn:
        if self.finished:
            return Turn("done", "", "", self.step["id"])
        if REJECT.search(text) and not self.analogy_dropped and self.analogy_used:
            self.analogy_dropped = True  # student says the analogy does not help: drop it
        kind, key = self.classify(text)
        if kind == "misconception":
            en, yo = self._guard(self.step["misconceptions"][key], self.step["misconceptions"][key])
            self.attempts += 1
            return Turn("misconception", en, yo, self.step["id"], [], self.step.get("term_ids", []),
                        needs_analogy=self.attempts >= 2)
        if kind == "correct":
            ink = [{"v": 1, "type": "canvas_cmd", "sim": self.pack["sim"], "visual": self.pack["visual"],
                    "op": "write_step", "params": {"step_id": self.step["id"], "latex_or_text": text.strip()[:80],
                                                   "author": "student", "reveal_answer": False}}]
            self.attempts = 0
            self.i += 1
            if self.i >= len(self.steps):
                self.i = len(self.steps) - 1
                self.finished = True
                tc = self.pack["transfer_check"]
                return Turn("transfer", f"{tc['statement_en']} {READY_EN}", f"{tc['statement_yo']} {READY_YO}",
                            self.step["id"], ink, [], transfer_check={"v": 1, "type": "transfer_check",
                                                                        "problem_id": tc["id"], "assist": False})
            nxt = self.open()
            nxt.kind, nxt.canvas_ops = "correct", ink + nxt.canvas_ops
            return nxt
        # incorrect: climb the hint ladder
        ladder = self.step.get("hint_ladder") or []
        hint = ladder[min(self.attempts, len(ladder) - 1)] if ladder else ""
        self.attempts += 1
        en, yo = self._guard(hint or self.step["prompt_en"], hint or self.step["prompt_yo"])
        return Turn("hint", en, yo, self.step["id"], [], self.step.get("term_ids", []),
                    needs_analogy=self.attempts >= 2 and not self.analogy_dropped)

    def analogy(self, term_id: str) -> Optional[Turn]:
        """One everyday analogy at a time; none once the student said it does not help."""
        if self.analogy_dropped or term_id in self.analogy_used or term_id not in ANALOGIES:
            return None
        self.analogy_used.add(term_id)
        en, yo = ANALOGIES[term_id]
        return Turn("analogy", en, yo, self.step["id"])
