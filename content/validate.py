"""Validate lesson packs and emit the native-speaker checklist (content/NATIVE-CHECK.md).

Usage: python3 content/validate.py   (from repo root; exits 1 on any failure)
Checks: structure, NFC on every string, audio names, one question per prompt/correction,
no final answers in prompts or tutor-authored canvas text, English/Yoruba hint parity,
and (when contracts/ and jsonschema are available) the frozen lesson-pack schema.
"""
import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).parent
sys.path.insert(0, str(ROOT.parent / "agent"))
PACKS = [ROOT / "lesson-pack.json", *sorted((ROOT / "packs").glob("*.json"))]
# Final answers a tutor must never state (roots, factors, vertex) in prompts/ink.
LEAKS = [r"x\s*=\s*-?\d", r"\(x\s*[-+−]\s*\d+\)", r"\bvertex\s*[:=]", r"x\s*[-+−]\s*\d+\s*=\s*0"]
VERIFIED = {"root", "vertex"}  # the only glossary terms a native speaker has confirmed (CLAUDE.md)
errors: list[str] = []


def load(name):
    p = ROOT / name
    return json.loads(p.read_text(encoding="utf-8")) if p.is_file() else {}


TERM_MAP, EN_TEXT = load("term-map.json"), load("en-text.json")


def strings(o, path=""):
    if isinstance(o, str):
        yield path, o
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from strings(v, f"{path}[{i}]")
    elif isinstance(o, dict):
        for k, v in o.items():
            yield from strings(v, f"{path}.{k}")


def err(pack, msg):
    errors.append(f"{pack}: {msg}")


def one_q(t):
    return t.count("?") == 1 and t.rstrip().endswith("?")


def correction(m, lang):
    """Misconception value is a string (simple form) or {correction_yo, correction_en}."""
    if isinstance(m, str):
        return m
    return m.get(f"correction_{lang}") or ""


def check_steps(name, topic, problem):
    ids = [s["id"] for s in problem["steps"]]
    if len(ids) != len(set(ids)):
        err(name, f"{problem['id']}: duplicate step ids")
    en_hints = EN_TEXT.get("hints", {}).get(topic, {}).get(problem["id"], {})
    for s in problem["steps"]:
        where = f"{problem['id']}.{s['id']}"
        for key in ("prompt_yo", "prompt_en"):
            p = s[key]
            if not one_q(p):
                err(name, f"{where}.{key}: must contain exactly one question, at the end")
            for pat in LEAKS:
                if re.search(pat, p):
                    err(name, f"{where}.{key}: leaks an answer ({pat})")
        for m, val in s.get("misconceptions", {}).items():
            for lang in ("yo", "en"):
                txt = correction(val, lang)
                if lang == "en" and isinstance(val, str):
                    continue  # simple form has no English text
                if not one_q(txt):
                    err(name, f"{where}: misconception {m!r} ({lang}) must end with exactly one question")
        hints = s.get("hint_ladder", [])
        for i, h in enumerate(hints, 1):
            if h.count("?") > 1 or ("?" in h and not h.rstrip().endswith("?")):
                err(name, f"{where}: hint {i} has a stray question")
        if en_hints:
            en = en_hints.get(s["id"], [])
            if len(en) != len(hints):
                err(name, f"{where}: {len(hints)} Yoruba hints but {len(en)} English hints")
            for i, h in enumerate(en, 1):
                if h.count("?") > 1 or ("?" in h and not h.rstrip().endswith("?")):
                    err(name, f"{where}: English hint {i} has a stray question")
        for op in s.get("canvas_ops", []):
            prm = op.get("params", {})
            if prm.get("author") == "tutor" and prm.get("reveal_answer"):
                err(name, f"{where}: tutor canvas op reveals answer")
            for pat in LEAKS:
                if re.search(pat, prm.get("latex_or_text", "")):
                    err(name, f"{where}: tutor canvas text leaks answer: {prm.get('latex_or_text')!r}")


def schema_check(name, pack):
    schema_path = ROOT.parent / "contracts" / "lesson-pack.json"
    if not schema_path.is_file():
        return "contracts/ not found: frozen schema NOT checked"
    try:
        from jsonschema import validators
    except ImportError:
        return "jsonschema not installed: frozen schema NOT checked"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    bad = sorted(validators.validator_for(schema)(schema).iter_errors(pack), key=lambda e: list(e.path))
    for e in bad[:5]:
        err(name, f"frozen schema: {list(e.path)[:5]} {e.message[:100]}")
    return f"frozen schema: {len(bad)} errors"


def fixed_lines():
    """Tutor lines that live in code, not in the pack."""
    try:
        import step_graph as sg
    except Exception:
        return []
    rows = [("transfer check ready line", sg.READY_YO, sg.READY_EN)]
    rows += [(f"analogy: {k}", yo, en) for k, (en, yo) in sg.ANALOGIES.items()]
    return rows


lines = ["# Native-speaker checklist",
         "",
         "Please review every Yorùbá string and clip below. Tutor Yorùbá and voice are the biggest risk.",
         "",
         "**How to mark:** write `OK` in the last column, or the corrected text. Check spelling, tone marks (à á), under-dots (ẹ ọ ṣ),",
         "that it sounds natural when spoken, and that the **clip** says the same thing as the text.",
         "Rows marked **loanword** use the English word with a Yorùbá voice: say if a real Yorùbá word should replace it.",
         ""]
notes = []
for path in PACKS:
    name = path.name
    pack = json.loads(path.read_text(encoding="utf-8"))
    topic = pack.get("topic_id", "")
    for k in ("topic_id", "subject", "lang", "sim", "visual", "glossary", "problems", "transfer_check"):
        if k not in pack:
            err(name, f"missing key {k}")
    for sp, s in strings(pack):
        if unicodedata.normalize("NFC", s) != s:
            err(name, f"not NFC at {sp}: {s[:40]!r}")
    for g in pack.get("glossary", []):
        if g.get("audio") != f"{g['id']}.mp3":
            err(name, f"glossary {g['id']}: audio must be <id>.mp3")
    gids = {g["id"] for g in pack.get("glossary", [])}
    for pr in pack.get("problems", []):
        check_steps(name, topic, pr)
        for sid, tids in TERM_MAP.get(topic, {}).get(pr["id"], {}).items():
            for t in tids:
                if t not in gids:
                    err(name, f"{pr['id']}.{sid}: term-map references unknown term {t}")
    notes.append(f"{name}: {schema_check(name, pack)}")

    lines += [f"## {name}", "", "### Glossary and clips", "",
              "| Term | Yorùbá | English | Status | Clip | Native verdict |", "|---|---|---|---|---|---|"]
    for g in pack.get("glossary", []):
        status = "verified" if g["id"] in VERIFIED else ("**loanword**" if g["yo"].lower() == g["en"].lower() else "DRAFT")
        lines.append(f"| `{g['id']}` | {g['yo']} | {g['en']} | {status} | `audio/{g['audio']}` | |")
    lines += ["", "### Tutor lines (Yorùbá with English gloss)", "",
              "| Where | Yorùbá | English gloss | Native verdict |", "|---|---|---|---|"]
    en_all = EN_TEXT.get("hints", {}).get(topic, {})
    for pr in pack.get("problems", []):
        lines.append(f"| {pr['id']} statement | {pr['statement_yo']} | {pr.get('statement_en', '')} | |")
        for s in pr["steps"]:
            lines.append(f"| {pr['id']}.{s['id']} question | {s['prompt_yo']} | {s['prompt_en']} | |")
            for m, val in s.get("misconceptions", {}).items():
                lines.append(f"| {pr['id']}.{s['id']} correction for `{m}` | {correction(val, 'yo')} | {correction(val, 'en')} | |")
            en_h = en_all.get(pr["id"], {}).get(s["id"], [])
            for i, h in enumerate(s.get("hint_ladder", [])):
                lines.append(f"| {pr['id']}.{s['id']} hint {i + 1} | {h} | {en_h[i] if i < len(en_h) else ''} | |")
    tc = pack.get("transfer_check", {})
    lines.append(f"| transfer check | {tc.get('statement_yo', '')} | {tc.get('statement_en', '')} | |")
    lines.append("")

lines += ["## Fixed tutor lines (in code)", "", "| Where | Yorùbá | English gloss | Native verdict |", "|---|---|---|---|"]
lines += [f"| {w} | {yo} | {en} | |" for w, yo, en in fixed_lines()]
lines.append("")
(ROOT / "NATIVE-CHECK.md").write_text("\n".join(lines), encoding="utf-8")
if errors:
    print("FAIL")
    print("\n".join(errors))
    sys.exit(1)
print(f"OK: {len(PACKS)} packs valid, all strings NFC, checklist -> content/NATIVE-CHECK.md")
for n in notes:
    print("  ", n)
