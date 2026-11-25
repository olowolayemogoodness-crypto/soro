"""Tutor: step-graph walker + brain, wrapped in hard guards, in the session's language.

The student always speaks English. `lang` sets what the TUTOR says and writes:
"en" -> English; "yo" -> Yoruba (English maths terms kept) plus an English caption line.
The walker decides WHAT to say (from the lesson pack). The brain only rephrases it, and every
brain output is validated; on any failure the walker's own text is used, so the pedagogy
rules hold even if the LLM misbehaves.
"""
from __future__ import annotations

import unicodedata
from dataclasses import dataclass, field
from typing import Optional

from brain import Brain, BrainError
from step_graph import Turn, Walker

NFC = lambda s: unicodedata.normalize("NFC", s)
MAX_WORDS = 45  # voice budget; pack text is the fallback
LANGS = ("en", "yo")


@dataclass
class Reply:
    spoken: str            # the tutor's line in the session language (what is spoken and captioned)
    caption_en: str        # English line (same as `spoken` in English mode)
    events: list = field(default_factory=list)  # session-events / canvas_cmd messages, in send order
    provider: str = "pack"  # which brain wrote it ("pack" = deterministic fallback)
    latency_ms: int = 0
    kind: str = ""
    lang: str = "yo"
    spoken_yo: str = ""    # always the Yoruba line, kept for callers that want both


def one_question(t: str) -> bool:
    return t.count("?") == 1 and t.rstrip().endswith("?")


class Tutor:
    def __init__(self, pack: dict, problem_id: str = "p1", brain: Optional[Brain] = None,
                 use_brain: bool = True, lang: str = "yo"):
        if lang not in LANGS:
            raise ValueError(f"lang must be one of {LANGS}, got {lang!r}")
        self.pack = pack
        self.lang = lang
        self.walker = Walker(pack, problem_id)
        self.brain = brain if brain is not None else (Brain() if use_brain else None)
        self.glossary = {g["id"]: g for g in pack["glossary"]}

    def _caption_events(self, yo: str, en: str) -> list:
        """Tutor caption in the session language, plus an English line in Yoruba mode."""
        if self.lang == "en":
            return [{"v": 1, "type": "caption", "role": "tutor", "text": en, "lang": "en"}]
        return [{"v": 1, "type": "caption", "role": "tutor", "text": yo, "lang": "yo"},
                {"v": 1, "type": "caption", "role": "tutor", "text": en, "lang": "en"}]

    def _chip(self, tid: str) -> Optional[dict]:
        g = self.glossary.get(tid)
        if not g:
            return None
        # English mode points at the English clip (<id>_en.mp3); Yoruba mode at the Yoruba clip.
        audio = g["audio"] if self.lang == "yo" else g["audio"].replace(".mp3", "_en.mp3")
        return {"v": 1, "type": "term_chip", "term_yo": g["yo"], "term_en": g["en"],
                "audio_url": f"/packs/{self.pack['topic_id']}/audio/{audio}"}

    def _events(self, turn: Turn, yo: str, en: str, student_text: str = "") -> list:
        ev = []
        if student_text:  # the student always speaks English
            ev.append({"v": 1, "type": "caption", "role": "student", "text": student_text, "lang": "en"})
        ev += turn.canvas_ops
        ev += self._caption_events(yo, en)
        ev += [c for c in (self._chip(t) for t in turn.term_ids) if c]
        if turn.transfer_check:
            ev.append(turn.transfer_check)
        return ev

    def _rephrase(self, turn: Turn, utterance: str) -> tuple[str, str, str, int]:
        """Brain rephrase in the session language, validated; returns (yo, en, provider, ms)."""
        if not self.brain:
            return turn.text_yo, turn.text_en, "pack", 0
        ctx = {  # no names, no ids: only the problem state and the student's words
            "tutor_language": self.lang,
            "problem_equation": self.walker.problem["equation"],
            "step_id": turn.step_id,
            "move": turn.kind,
            "planned_reply": turn.text_yo if self.lang == "yo" else turn.text_en,
            "planned_reply_en": turn.text_en,
            "student_utterance": utterance,
        }
        try:
            data, provider, ms = self.brain.respond(ctx)
        except BrainError:
            return turn.text_yo, turn.text_en, "pack", 0
        said = NFC(str(data.get("spoken") or data.get("spoken_yo") or "").strip())
        en = str(data.get("caption_en", "")).strip() or turn.text_en
        if self.lang == "en":
            en = said or en
        bad = (not one_question(said or "x") or len(said.split()) > MAX_WORDS
               or self.walker._leaks(said) or self.walker._leaks(en) or not one_question(en))
        if bad:  # guard tripped: keep the verified pack text
            return turn.text_yo, turn.text_en, "pack", ms
        return (said if self.lang == "yo" else turn.text_yo), en, provider, ms

    def _spoken(self, yo: str, en: str) -> str:
        return yo if self.lang == "yo" else en

    def start(self) -> Reply:
        turn = self.walker.open()
        yo, en = turn.text_yo, turn.text_en  # the opening line is verified pack text
        ev = [{"v": 1, "type": "tier", "level": 0}] + self._events(turn, yo, en)
        return Reply(self._spoken(yo, en), en, ev, "pack", 0, turn.kind, self.lang, yo)

    def handle(self, utterance: str) -> Reply:
        turn = self.walker.submit(utterance)
        yo, en, prov, ms = self._rephrase(turn, utterance)
        # a transfer-check turn keeps the exact pack text: the statement must not be reworded
        if turn.kind == "transfer":
            yo, en = turn.text_yo, turn.text_en
        events = self._events(turn, yo, en, student_text=utterance)
        if turn.needs_analogy:
            a = self.walker.analogy("friction" if self.pack["subject"] == "physics" else "root")
            if a:
                yo, en = a.text_yo, a.text_en
                events += self._caption_events(yo, en)
        return Reply(self._spoken(yo, en), en, events, prov, ms, turn.kind, self.lang, yo)
