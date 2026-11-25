"""POST /tutor/turn: a plain-HTTP text turn of the Soro tutor brain for the tablet app (issue #39).

Three modes share one response shape and always answer HTTP 200 with a valid body:
  * pack: the typed problem or topic matches a lesson pack; walked with agent Tutor/Walker;
  * solve: the full worked solution as ordered write ops, then a try-it-yourself problem;
  * general: no pack matches; one LLM call returns a strict-JSON guided plan, which is
    schema-validated, arithmetic-verified, then walked with the same guards.
On any failure the reply is the honest "quadratics and friction for now" script line.
"""
from __future__ import annotations

import ast
import hashlib
import json
import math
import os
import re
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor, wait
from dataclasses import dataclass, field
from fractions import Fraction
from pathlib import Path
from typing import Any, Optional

from fastapi import APIRouter, Header, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse

AGENT_DIR = Path(os.getenv("SORO_AGENT_DIR", Path(__file__).resolve().parents[2] / "agent"))
if str(AGENT_DIR) not in sys.path:
    sys.path.append(str(AGENT_DIR))

router = APIRouter()

BUDGET_S = float(os.getenv("SORO_TURN_BUDGET", "6"))
SESSION_TTL_S = float(os.getenv("SORO_TURN_SESSION_TTL", "3600"))
MAX_SESSIONS = 2000
HONEST = "I can help with the quadratics and friction lessons for now. Try one of those problems and we will work it out together."
AUDIO_RE = re.compile(r"^[0-9a-f]{40}\.mp3$")
LANGS = ("en", "yo")


# --------------------------------------------------------------------------- safe evaluator
_SAFE_FUNCS = {"S": lambda v: _sqrt(v)}


def _sqrt(v):
    if isinstance(v, Fraction) and v >= 0:
        n, d = math.isqrt(v.numerator), math.isqrt(v.denominator)
        if n * n == v.numerator and d * d == v.denominator:
            return Fraction(n, d)
    return math.sqrt(v)


def _prep(expr: str) -> str:
    s = expr.lower().replace("−", "-").replace("–", "-").replace("×", "*").replace("÷", "/").replace("²", "^2")
    s = re.sub(r"\s+", "", s).replace("sqrt(", "S(").replace("√(", "S(")
    s = re.sub(r"√(\d+(?:\.\d+)?)", r"S(\1)", s)
    s = re.sub(r"(\d|\))(?=[a-z(S])", r"\1*", s)
    s = re.sub(r"(?<=[a-z])(?=\(|\d)", "*", s)
    s = re.sub(r"\)(?=\()", ")*", s)
    return s.replace("^", "**")


def safe_eval(expr: str, env: Optional[dict] = None):
    """Evaluate +,-,*,/,** and sqrt over Fractions; raises ValueError on anything else."""
    env = env or {}
    try:
        tree = ast.parse(_prep(expr), mode="eval")
    except SyntaxError as e:
        raise ValueError("bad expression") from e

    def ev(n):
        if isinstance(n, ast.Expression):
            return ev(n.body)
        if isinstance(n, ast.Constant) and isinstance(n.value, (int, float)) and not isinstance(n.value, bool):
            return Fraction(str(n.value))
        if isinstance(n, ast.Name) and n.id in env:
            return Fraction(env[n.id])
        if isinstance(n, ast.UnaryOp) and isinstance(n.op, (ast.USub, ast.UAdd)):
            v = ev(n.operand)
            return -v if isinstance(n.op, ast.USub) else v
        if isinstance(n, ast.BinOp):
            a, b = ev(n.left), ev(n.right)
            if isinstance(n.op, ast.Add): return a + b
            if isinstance(n.op, ast.Sub): return a - b
            if isinstance(n.op, ast.Mult): return a * b
            if isinstance(n.op, ast.Div):
                if b == 0: raise ValueError("div by zero")
                return a / b
            if isinstance(n.op, ast.Pow):
                if isinstance(b, Fraction) and b.denominator == 1 and abs(b) <= 12 and abs(a) < 1e6:
                    return a ** int(b)
                raise ValueError("bad power")
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id in _SAFE_FUNCS and len(n.args) == 1:
            return _SAFE_FUNCS[n.func.id](ev(n.args[0]))
        raise ValueError("unsupported")

    return ev(tree)


def _names(expr: str) -> set[str]:
    try:
        return {n.id for n in ast.walk(ast.parse(_prep(expr), mode="eval")) if isinstance(n, ast.Name) and n.id != "S"}
    except SyntaxError:
        return set()


def parse_equation(text: str) -> Optional[tuple[str, str, str]]:
    """Find a one-variable equation inside free text -> (lhs, rhs, var), or None."""
    toks = (text or "").replace("=", " = ").split()
    if "=" not in toks or len(toks) > 40:
        return None
    k = toks.index("=")
    for i in range(0, k):
        for j in range(len(toks), k, -1):
            lhs, rhs = "".join(toks[i:k]), "".join(toks[k + 1:j])
            if not lhs or not rhs or "=" in rhs:
                continue
            names = _names(lhs) | _names(rhs)
            if len(names) != 1:
                continue
            var = next(iter(names))
            try:
                safe_eval(lhs, {var: 1}); safe_eval(rhs, {var: 1})
            except (ValueError, TypeError, OverflowError):
                continue
            return lhs, rhs, var
    return None


def quad_coeffs(lhs: str, rhs: str, var: str) -> Optional[tuple[Fraction, Fraction, Fraction]]:
    try:
        f = lambda v: safe_eval(lhs, {var: v}) - safe_eval(rhs, {var: v})
        c, p, m = f(0), f(1), f(-1)
        a, b = (p + m) / 2 - c, (p - m) / 2
        if a != 0 and f(2) == 4 * a + 2 * b + c and f(3) == 9 * a + 3 * b + c:
            return a, b, c
    except (ValueError, TypeError, OverflowError):
        pass
    return None


def verify_result(problem: str, result: str) -> bool:
    """Every root named in `result` must satisfy the problem's equation."""
    eq = parse_equation(problem)
    if not eq:
        return False
    lhs, rhs, var = eq
    vals = re.findall(rf"{var}\s*=\s*([^,;]+?)(?=\s+(?:or|and)\s+{var}\s*=|[,;]|$)", result.replace("−", "-"), re.I)
    if not vals:
        return False
    for raw in vals:
        raw = raw.strip()
        pm = re.fullmatch(r"(.+?)\s*[±]\s*(.+)", raw)
        cands = [raw] if not pm else [f"({pm.group(1)})+({pm.group(2)})", f"({pm.group(1)})-({pm.group(2)})"]
        for c in cands:
            try:
                v = safe_eval(c)
                r = abs(float(safe_eval(lhs, {var: v}) - safe_eval(rhs, {var: v}))) if isinstance(v, Fraction) else \
                    abs(float(safe_eval(lhs, {var: Fraction(v)}) - safe_eval(rhs, {var: Fraction(v)})))
            except (ValueError, TypeError, OverflowError):
                return False
            if r > 1e-6:
                return False
    return True


# --------------------------------------------------------------------------- formatting helpers
def fnum(v) -> str:
    v = Fraction(v)
    t = str(v.numerator) if v.denominator == 1 else f"{v.numerator}/{v.denominator}"
    return t.replace("-", "−")


def fterm(coef: Fraction, body: str, first: bool = False) -> str:
    sign = "-" if coef < 0 else "+"
    mag = abs(coef)
    mag_s = "" if (mag == 1 and body) else fnum(mag)
    s = f"{mag_s}{body}"
    if first:
        return ("−" if coef < 0 else "") + s
    return f" {'−' if sign == '-' else '+'} {s}"


def fbracket(root: Fraction) -> str:
    return f"(x − {fnum(root)})" if root > 0 else f"(x + {fnum(-root)})" if root < 0 else "x"


def worked_quadratic(a, b, c, rhs_zero: bool, eq_text: str) -> Optional[list[tuple[str, str]]]:
    """(line, say) pairs for x^2 + bx + c = 0 by factorising, or x^2 + bx = k by completing the square."""
    if a != 1:
        return None
    if rhs_zero:
        disc = b * b - 4 * c
        if disc < 0 or math.isqrt(int(disc)) ** 2 != disc or disc.denominator != 1 or b.denominator != 1 or c.denominator != 1:
            return None
        s = math.isqrt(int(disc))
        r1, r2 = sorted([(-b - s) / 2, (-b + s) / 2])
        if r1.denominator != 1:
            return None
        p, q = -r1, -r2
        return [
            (eq_text, "Here is the equation."),
            (f"{fnum(p)} × {fnum(q)} = {fnum(c)},  {fnum(p)} + {fnum(q)} = {fnum(b)}",
             f"Find two numbers that multiply to {fnum(c)} and add up to {fnum(b)}: {fnum(p)} and {fnum(q)}."),
            (f"{fbracket(r1)}{fbracket(r2)} = 0", "Put them in the two brackets."),
            (f"{fbracket(r1)[1:-1]} = 0  or  {fbracket(r2)[1:-1]} = 0", "A product is zero only when one bracket is zero."),
            (f"x = {fnum(r1)}  or  x = {fnum(r2)}", "Solve each bracket to get the roots."),
        ]
    k = -c  # x^2 + bx = k
    h = b / 2
    k2 = k + h * h
    lines = [
        (eq_text, "Here is the equation, constant on the right."),
        (f"x²{fterm(b, 'x')} + {fnum(h * h)} = {fnum(k)} + {fnum(h * h)}",
         f"Add half of b, squared, which is {fnum(h * h)}, to both sides."),
        (f"(x {'+' if h >= 0 else '−'} {fnum(abs(h))})² = {fnum(k2)}", "The left side is now a perfect square."),
    ]
    root = _sqrt(k2) if k2 >= 0 else None
    if root is None:
        return None
    if isinstance(root, Fraction):
        lines.append((f"x {'+' if h >= 0 else '−'} {fnum(abs(h))} = ± {fnum(root)}", "Take the square root of both sides."))
        lines.append((f"x = {fnum(-h + root)}  or  x = {fnum(-h - root)}", "Move the number across to finish."))
    else:
        lines.append((f"x {'+' if h >= 0 else '−'} {fnum(abs(h))} = ± √{fnum(k2)}", "Take the square root of both sides."))
        lines.append((f"x = {fnum(-h)} ± √{fnum(k2)}", "Move the number across to finish."))
    return lines


FRICTION_WORKED = [
    ("Smooth floor: very little friction", "On a smooth floor there is very little friction, so the crate keeps moving."),
    ("Rough floor: friction f = μN opposes the motion", "On a rougher floor friction pushes back against the motion."),
    ("Bigger μ gives bigger f, so the crate slows down faster", "A bigger friction coefficient means a bigger force, so the crate stops sooner."),
]


# --------------------------------------------------------------------------- packs and brain wiring
_packs: dict[str, dict] = {}


def content_dir() -> Path:
    return Path(os.getenv("SORO_CONTENT_DIR", "../content")).resolve()


def load_packs() -> dict[str, dict]:
    if _packs:
        return _packs
    base = content_dir()
    files = [base / "lesson-pack.json", *sorted((base / "packs").glob("*.json"))]
    for f in files:
        if f.is_file():
            try:
                p = json.loads(f.read_text(encoding="utf-8"))
                _packs[p["topic_id"]] = p
            except (OSError, ValueError, KeyError):
                continue
    return _packs


def _agent():
    import brain, tutor, step_graph  # noqa: E401  (agent modules, path added above)
    return brain, tutor, step_graph


_brain_obj: Any = None
_brain_failed = False


def get_brain():
    """The shared Brain (Gemini main, Groq fallback), or None when it cannot be built. Tests patch this."""
    global _brain_obj, _brain_failed
    if _brain_obj is None and not _brain_failed:
        try:
            brain, _, _ = _agent()
            b = brain.Brain()
            b.timeout = float(os.getenv("SORO_TURN_PROVIDER_TIMEOUT", "3"))
            _brain_obj = b
        except Exception:  # noqa: BLE001
            _brain_failed = True
    return _brain_obj


def match_pack(problem: str, text: str) -> Optional[tuple[dict, str]]:
    """Match a typed problem or topic to (pack, problem_id)."""
    packs = load_packs()
    quad = packs.get("math101-quadratics")
    fric = packs.get("physics-friction")
    for src in (problem, text):
        eq = parse_equation(src or "")
        if eq and quad:
            qc = quad_coeffs(*eq)
            if qc:
                for p in quad["problems"]:
                    pe = parse_equation(p["equation"])
                    if pe and quad_coeffs(*pe) == qc:
                        return quad, p["id"]
    blob = f"{problem} {text}".lower()
    if fric and re.search(r"friction|crate|skid|slid", blob):
        return fric, fric["problems"][0]["id"]
    if quad and not parse_equation(problem or "") and re.search(r"complet\w* the square", blob):
        return quad, "p2"
    if quad and not parse_equation(problem or "") and re.search(r"quadratic|factori[sz]|factoris", blob):
        return quad, "p1"
    return None


# --------------------------------------------------------------------------- audio (Spitch)
def audio_dir() -> Path:
    d = Path(os.getenv("SORO_TUTOR_AUDIO_DIR", Path(tempfile.gettempdir()) / "soro-tutor-audio"))
    d.mkdir(parents=True, exist_ok=True)
    return d


def mp3_ms(data: bytes) -> Optional[int]:
    """Duration of a (CBR) mp3 from its first frame header."""
    i = 0
    if data[:3] == b"ID3" and len(data) > 10:
        i = 10 + ((data[6] & 0x7F) << 21 | (data[7] & 0x7F) << 14 | (data[8] & 0x7F) << 7 | (data[9] & 0x7F))
    br_tab = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0]  # MPEG1 layer 3
    br_tab2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0]     # MPEG2/2.5 layer 3
    while i + 4 < len(data):
        if data[i] == 0xFF and (data[i + 1] & 0xE0) == 0xE0 and (data[i + 1] >> 1) & 3 == 1:
            v1 = (data[i + 1] >> 3) & 3 == 3
            br = (br_tab if v1 else br_tab2)[data[i + 2] >> 4]
            if br:
                return int((len(data) - i) * 8 / br)
        i += 1
    return None


def synth_audio(text: str, lang: str, deadline: float) -> Optional[tuple[str, int]]:
    """(url, ms) for `text`, cached by text hash; None when no key, failure or out of budget."""
    text = (text or "").strip()
    if not text or not os.getenv("SPITCH_API_KEY") and not _cached_exists(text, lang):
        return None
    h = _audio_hash(text, lang)
    path = audio_dir() / f"{h}.mp3"
    try:
        if not path.is_file():
            remaining = deadline - time.monotonic()
            if remaining < 0.5:
                return None
            import tts
            data = tts.synth(text, voice=os.getenv("SORO_TTS_VOICE_EN", "lucy") if lang == "en" else tts.VOICE,
                             language=lang, timeout=remaining, retries=0)
            tmp = path.with_suffix(f".{os.getpid()}.{threading.get_ident()}.tmp")
            tmp.write_bytes(data)
            tmp.replace(path)
        ms = mp3_ms(path.read_bytes())
    except Exception:  # noqa: BLE001
        return None
    return (f"/tutor/audio/{h}.mp3", ms) if ms else None


def _audio_hash(text: str, lang: str) -> str:
    return hashlib.sha1(f"{lang}|{text}".encode("utf-8")).hexdigest()


def _cached_exists(text: str, lang: str) -> bool:
    return (audio_dir() / f"{_audio_hash(text, lang)}.mp3").is_file()


def attach_audio(out: dict, lang: str, deadline: float) -> None:
    """Add audio_url/audio_ms to the say line and per-step lines, in parallel, within the budget."""
    if not os.getenv("SPITCH_API_KEY") and not any(_cached_exists(t, lang) for t in _spoken_texts(out)):
        return
    jobs: list[tuple[dict, str]] = [(out, out["say"])]
    for st in out.get("steps", [])[:8]:
        jobs.append((st, st["say"]))
    ex = ThreadPoolExecutor(max_workers=min(8, len(jobs)))
    futs = {ex.submit(synth_audio, t, lang, deadline): tgt for tgt, t in jobs}
    done, _ = wait(futs, timeout=max(0.0, deadline - time.monotonic()))
    ex.shutdown(wait=False, cancel_futures=True)
    for f in done:
        r = f.result()
        if r:
            futs[f]["audio_url"], futs[f]["audio_ms"] = r
    for st in out.get("steps", []):
        if "audio_ms" in st and st["board"]:
            st["board"][0]["audio_ms"] = st["audio_ms"]


def _spoken_texts(out: dict) -> list[str]:
    return [out["say"], *[s["say"] for s in out.get("steps", [])]]


# --------------------------------------------------------------------------- sessions
@dataclass
class Session:
    sid: str
    lang: str
    problem: str = ""
    kind: str = ""                      # pack | general
    tutor: Any = None                   # agent Tutor for pack sessions
    pack: Optional[dict] = None
    pid: str = ""
    plan: Optional[dict] = None         # validated plan for general sessions
    src: str = "script"                 # provider that wrote the plan
    idx: int = 0
    attempts: int = 0
    finished: bool = False
    opened: bool = False
    last: float = field(default_factory=time.monotonic)
    lock: threading.Lock = field(default_factory=threading.Lock)


_sessions: dict[str, Session] = {}
_sessions_lock = threading.Lock()


def get_session(sid: str, lang: str, problem: str) -> Session:
    now = time.monotonic()
    with _sessions_lock:
        for k in [k for k, s in _sessions.items() if now - s.last > SESSION_TTL_S]:
            del _sessions[k]
        if len(_sessions) >= MAX_SESSIONS:
            del _sessions[min(_sessions, key=lambda k: _sessions[k].last)]
        s = _sessions.get(sid)
        if s is None or s.lang != lang or (problem and s.problem and canon_text(problem) != canon_text(s.problem)):
            s = _sessions[sid] = Session(sid, lang, problem)
        elif problem and not s.problem:
            s.problem = problem
        s.last = now
        return s


def canon_text(t: str) -> str:
    return re.sub(r"\s+", "", t.lower().replace("−", "-").replace("²", "^2"))


def reset_sessions() -> None:
    with _sessions_lock:
        _sessions.clear()


# --------------------------------------------------------------------------- response helpers
def board_from_text(text: str) -> dict:
    return {"op": "blank", "text": text.replace("?", "[ ]")} if "?" in text or "[ ]" in text else {"op": "write", "text": text}


def make_resp(sess: Session, step_id: str, say: str, board: list, source: str, done: bool = False, **extra) -> dict:
    out = {"session_id": sess.sid, "step_id": step_id, "say": say, "board": board, "done": done, "source": source}
    out.update({k: v for k, v in extra.items() if v})
    return out


def honest(sid: str, step_id: str = "") -> dict:
    return {"session_id": sid, "step_id": step_id, "say": HONEST, "board": [], "done": False, "source": "script"}


def source_of(provider: str) -> str:
    return provider if provider in ("gemini", "groq") else "script"


# --------------------------------------------------------------------------- pack mode
def pack_ops(events: list) -> list:
    """Tutor canvas ops become write/blank ops; student ink becomes write plus a tick."""
    board = []
    for ev in events:
        if ev.get("type") != "canvas_cmd" or ev.get("op") != "write_step":
            continue
        p = ev.get("params", {})
        txt = p.get("latex_or_text") or ""
        if not txt:
            continue
        if p.get("author") == "student":
            board += [{"op": "write", "text": txt}, {"op": "mark", "kind": "tick", "target": "last"}]
        else:
            board.append(board_from_text(txt))
    return board


def pack_turn(sess: Session, text: str, step_id: str, brain) -> dict:
    _, tutor_mod, _ = _agent()
    pack = sess.pack
    if sess.tutor is None:
        sess.tutor = tutor_mod.Tutor(pack, sess.pid, brain=brain, use_brain=False, lang=sess.lang)
        if step_id:
            ids = [s["id"] for s in sess.tutor.walker.steps]
            if step_id in ids:
                sess.tutor.walker.i = ids.index(step_id)
    t = sess.tutor
    if sess.finished:
        return make_resp(sess, t.walker.step["id"], "You worked that one through yourself. Ask me for a new problem whenever you like.", [], "script", True)
    if not sess.opened or not text.strip():
        sess.opened = True
        reply = t.start()
        board = pack_ops(reply.events)
        eq = t.walker.problem.get("equation")
        if eq:
            board.insert(0, {"op": "write", "text": eq})
        return make_resp(sess, t.walker.step["id"], reply.spoken, board, "script")
    reply = t.handle(text)
    board = pack_ops(reply.events)
    sess.finished = t.walker.finished
    if reply.kind == "correct" and not any(b.get("op") == "mark" for b in board):
        board.append({"op": "mark", "kind": "tick", "target": "last"})
    return make_resp(sess, t.walker.step["id"], reply.spoken, board, source_of(reply.provider), sess.finished)


def pack_solve(sess: Session) -> dict:
    pack, pid = sess.pack, sess.pid
    prob = next(p for p in pack["problems"] if p["id"] == pid)
    tc = pack["transfer_check"]
    if pack["subject"] == "physics":
        pairs = [(l, s) for l, s in FRICTION_WORKED]
        try_text, try_blank = tc["statement_en"], None
    else:
        eq = parse_equation(prob["equation"])
        qc = quad_coeffs(*eq) if eq else None
        pairs = worked_quadratic(*qc, rhs_zero=canon_text(eq[1]) == "0", eq_text=prob["equation"]) if qc else None
        if not pairs:
            return honest(sess.sid)
        try_text, try_blank = tc["statement_en"], "(x − [ ])(x − [ ]) = 0"
    steps = [{"say": s, "board": [{"op": "write", "text": l}]} for l, s in pairs]
    tail_board = [{"op": "write", "text": try_text}] + ([{"op": "blank", "text": try_blank}] if try_blank else [])
    steps.append({"say": "Now try a similar one yourself.", "board": tail_board})
    return solve_resp(sess, prob["steps"][-1]["id"], steps, "script", sess.lang)


def solve_resp(sess: Session, step_id: str, steps: list, source: str, lang: str) -> dict:
    board = [op for st in steps for op in st["board"]]
    out = make_resp(sess, step_id, "Here is the full working, step by step. Then try a similar one yourself.", board, source, True)
    out["steps"] = steps
    sess.finished = True
    return out


# --------------------------------------------------------------------------- general mode
PLAN_SYSTEM = """You are Soro, a warm STEM tutor. The student asked about a problem or concept that is not in our lessons. Build a guided plan. {language_rule}
Return strict JSON only, with this shape:
{{"spoken": "<one short friendly sentence introducing the problem>",
 "problem": "<the problem restated in plain text>",
 "steps": [{{"question": "<one scaffolding question ending in exactly one ?, never containing the answer>", "expected": "<short correct student answer; alternatives separated by |>", "blanks": "<the board structure for this step with [ ] for each blank, no answers>"}}],
 "worked": [{{"line": "<one board line of the full worked solution>", "say": "<one short spoken sentence for this line>"}}],
 "result": "<the final result, e.g. x = 2 or x = 3; for an explanation, one sentence>",
 "similar": "<a similar practice problem, no solution>"}}
Rules: 3 to 6 steps; worked lines must end exactly at result; use plain ASCII maths (x^2, sqrt(2)); questions are not about anything you have not shown; for pure explanations (science concepts) expected holds the key idea words and worked holds the explanation lines."""
LANG_RULES = {"en": "Write questions and spoken lines in clear plain English.",
              "yo": "Write `spoken`, questions and `say` lines in short natural Yoruba with full tone marks, keeping English maths terms; keep expected, blanks, worked lines and result in English or plain maths."}


class PlanError(Exception):
    pass


def request_plan(problem: str, text: str, lang: str, deadline: float) -> tuple[dict, str]:
    """One LLM call (Gemini then Groq) inside the budget; returns (raw plan, provider)."""
    brain = get_brain()
    if brain is None:
        raise PlanError("no brain")
    if hasattr(brain, "plan"):  # fake brains in tests
        return brain.plan(problem, text, lang)
    import httpx
    from brain import ADAPTERS, BrainError
    system = PLAN_SYSTEM.format(language_rule=LANG_RULES.get(lang, LANG_RULES["en"]))
    user = json.dumps({"problem": problem, "student_message": text}, ensure_ascii=False)
    for provider in dict.fromkeys((brain.primary, brain.fallback)):
        remaining = deadline - time.monotonic()
        if remaining < 0.5:
            break
        try:
            return ADAPTERS[provider](brain.models[provider], system, user, remaining), provider
        except (BrainError, httpx.HTTPError, KeyError, IndexError):
            continue
    raise PlanError("brain failed")


def validate_plan(raw: dict, problem_hint: str) -> dict:
    """Schema check, 3 to 6 steps, one question per step, and the worked lines end at a verified result."""
    if not isinstance(raw, dict):
        raise PlanError("not an object")
    problem = str(raw.get("problem") or problem_hint or "").strip()
    steps, worked = raw.get("steps"), raw.get("worked")
    result = str(raw.get("result") or "").strip()
    if not problem or not result or not isinstance(steps, list) or not 3 <= len(steps) <= 6:
        raise PlanError("bad shape")
    clean_steps = []
    for st in steps:
        if not isinstance(st, dict):
            raise PlanError("bad step")
        q, exp = str(st.get("question") or "").strip(), str(st.get("expected") or "").strip()
        if q.count("?") != 1 or not q.endswith("?") or not exp or len(q) > 240:
            raise PlanError("bad question")
        clean_steps.append({"question": q, "expected": exp, "blanks": str(st.get("blanks") or "").strip()[:120]})
    if not isinstance(worked, list) or not 2 <= len(worked) <= 14:
        raise PlanError("bad worked")
    lines = []
    for w in worked:
        line, say = (w.get("line"), w.get("say")) if isinstance(w, dict) else (w, "")
        if not isinstance(line, str) or not line.strip():
            raise PlanError("bad line")
        lines.append((line.strip()[:160], str(say or "").strip()[:200]))
    if canon_text(result) not in canon_text(lines[-1][0]) and canon_text(lines[-1][0]) not in canon_text(result):
        raise PlanError("worked does not end at result")
    if re.search(r"=", problem) and re.search(r"\d", problem):
        if not verify_result(problem, result):
            raise PlanError("result fails verification")
    elif parse_equation(problem_hint or ""):
        if not verify_result(problem_hint, result):
            raise PlanError("result fails verification")
    return {"spoken": str(raw.get("spoken") or "").strip()[:240], "problem": problem, "steps": clean_steps,
            "worked": lines, "result": result, "similar": str(raw.get("similar") or "").strip()[:160]}


def leak_check(plan: dict, say: str, include_current: bool = True, idx: int = 0) -> bool:
    """True if `say` states any expected answer of the plan or its final result."""
    known = canon_text(plan["problem"])
    cands = [plan["result"]] + [a for st in plan["steps"][idx if include_current else idx + 1:] for a in st["expected"].split("|")]
    cs = canon_text(say)
    for a in cands:
        ca = canon_text(a)
        if not ca:
            continue
        if len(ca) >= 3 or re.search(r"[a-z]", ca):
            if ca in cs and ca not in known:
                return True
        elif ca not in known and re.search(rf"(?<![\d.]){re.escape(a.strip())}(?![\d.])", say):
            return True
    return False


def matches_expected(text: str, expected: str) -> bool:
    ct = canon_text(text)
    for alt in expected.split("|"):
        ca = canon_text(alt)
        if not ca:
            continue
        if ca in ct:
            return True
        try:
            if safe_eval(alt) == safe_eval(text):
                return True
        except (ValueError, TypeError):
            pass
    return False


def safe_question(plan: dict, idx: int) -> tuple[str, str]:
    """(question, blanks) for step idx with the leak guard applied."""
    st = plan["steps"][idx]
    q, blanks = st["question"], st["blanks"]
    if leak_check(plan, q, True, idx):
        q = "What do you think goes in the blank?" if blanks else "What do you think comes next?"
    if blanks and leak_check(plan, blanks, True, idx):
        blanks = ""
    return q, blanks


def general_open(sess: Session) -> dict:
    plan = sess.plan
    q, blanks = safe_question(plan, 0)
    board = [{"op": "write", "text": plan["problem"]}] + ([board_from_text(blanks)] if blanks else [])
    sess.opened = True
    say = f"{plan['spoken']} {q}" if plan["spoken"] and "?" not in plan["spoken"] and not leak_check(plan, plan["spoken"]) else q
    return make_resp(sess, "s1", say, board, sess.src)


def general_turn(sess: Session, text: str) -> dict:
    plan = sess.plan
    if sess.finished:
        return make_resp(sess, f"s{len(plan['steps'])}", "You worked that through yourself. Ask me another question whenever you like.", [], "script", True)
    if not sess.opened or not text.strip():
        return general_open(sess)
    st = plan["steps"][sess.idx]
    if matches_expected(text, st["expected"]):
        board = [{"op": "write", "text": text.strip()[:80]}, {"op": "mark", "kind": "tick", "target": "last"}]
        sess.idx += 1
        sess.attempts = 0
        if sess.idx >= len(plan["steps"]):
            sess.finished = True
            return make_resp(sess, f"s{len(plan['steps'])}", "Yes, that completes it. You worked the whole thing out yourself. Want to try a similar one?",
                             board, sess.src, True)
        q, blanks = safe_question(plan, sess.idx)
        if blanks:
            board.append(board_from_text(blanks))
        return make_resp(sess, f"s{sess.idx + 1}", f"Right. {q}", board, sess.src)
    sess.attempts += 1
    q, blanks = safe_question(plan, sess.idx)
    lead = "Not quite yet. Check it against the blanks." if sess.attempts == 1 else "Still not it. Take it one small piece at a time."
    board = [board_from_text(blanks)] if blanks and sess.attempts > 1 else []
    return make_resp(sess, f"s{sess.idx + 1}", f"{lead} {q}", board, sess.src)


def general_solve(sess: Session) -> dict:
    plan = sess.plan
    steps = [{"say": s or f"Step {i + 1}.", "board": [{"op": "write", "text": l}]} for i, (l, s) in enumerate(plan["worked"])]
    tail = [{"op": "write", "text": plan["similar"]}] if plan["similar"] else []
    steps.append({"say": "Now try a similar one yourself." if tail else "That is the full working.", "board": tail})
    return solve_resp(sess, f"s{len(plan['steps'])}", steps, sess.src, sess.lang)


def ensure_general(sess: Session, problem: str, text: str, deadline: float) -> None:
    if sess.plan is None:
        raw, provider = request_plan(problem or sess.problem, text, sess.lang, deadline)
        sess.plan = validate_plan(raw, problem or sess.problem)
        sess.src = source_of(provider)
        sess.kind = "general"


# --------------------------------------------------------------------------- the endpoint
def run_turn(body: dict, deadline: float) -> dict:
    sid = str(body.get("session_id") or "anon")[:80]
    lang = body.get("lang") if body.get("lang") in LANGS else "en"
    mode = "solve" if body.get("mode") == "solve" else "guide"
    problem = str(body.get("problem") or "").strip()[:400]
    text = str(body.get("text") or "").strip()[:800]
    step_id = str(body.get("step_id") or "")[:20]
    sess = get_session(sid, lang, problem)
    with sess.lock:
        if not sess.kind:
            m = match_pack(sess.problem or problem, text)
            if m:
                sess.pack, sess.pid = m
                sess.kind = "pack"
            elif not (sess.problem or problem or text):
                return honest(sid)
        if sess.kind == "pack":
            if mode == "solve":
                return pack_solve(sess)
            return pack_turn(sess, text, step_id, get_brain())
        try:
            ensure_general(sess, problem or sess.problem, text, deadline)
        except PlanError:
            sess.kind = ""
            return honest(sid)
        return general_solve(sess) if mode == "solve" else general_turn(sess, text)


@router.post("/tutor/turn")
async def tutor_turn(request: Request, x_soro_key: Optional[str] = Header(default=None)) -> JSONResponse:
    want = os.getenv("SORO_RECORD_KEY", "")
    if want and x_soro_key != want:
        raise HTTPException(401, "missing or wrong X-Soro-Key")
    try:
        body = await request.json()
        if not isinstance(body, dict):
            body = {}
    except Exception:  # noqa: BLE001
        body = {}
    from starlette.concurrency import run_in_threadpool
    out = await run_in_threadpool(handle, body)
    return JSONResponse(out)


def handle(body: dict) -> dict:
    sid = str(body.get("session_id") or "anon")[:80]
    deadline = time.monotonic() + BUDGET_S
    try:
        out = run_turn(body, deadline)
        lang = body.get("lang") if body.get("lang") in LANGS else "en"
        attach_audio(out, lang, deadline)
        return out
    except Exception:  # noqa: BLE001  never an error body
        return honest(sid)


@router.get("/tutor/audio/{name}")
def tutor_audio(name: str) -> FileResponse:
    if not AUDIO_RE.fullmatch(name):
        raise HTTPException(400, "invalid audio name")
    path = audio_dir() / name
    if not path.is_file():
        raise HTTPException(404, "no such audio")
    return FileResponse(path, media_type="audio/mpeg")
