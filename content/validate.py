"""Validate lesson packs and emit the native-speaker checklist.

Usage: python content/validate.py   (from repo root; exits 1 on any failure)
Checks: structure, NFC on every string, audio names, one question per prompt,
and no final answers in prompts or tutor-authored canvas text.
"""
import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).parent
PACKS = [ROOT / "lesson-pack.json", *sorted((ROOT / "packs").glob("*.json"))]
# Final answers a tutor must never state (roots, factors, vertex) in prompts/ink.
LEAKS = [r"x\s*=\s*-?\d", r"\(x\s*[-+−]\s*\d+\)", r"\bvertex\s*[:=]", r"x\s*[-+−]\s*\d+\s*=\s*0"]
errors: list[str] = []


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


def check_steps(name, problem):
    ids = [s["id"] for s in problem["steps"]]
    if len(ids) != len(set(ids)):
        err(name, f"{problem['id']}: duplicate step ids")
    for s in problem["steps"]:
        where = f"{problem['id']}.{s['id']}"
        for key in ("prompt_yo", "prompt_en"):
            p = s[key]
            if p.count("?") != 1 or not p.rstrip().endswith("?"):
                err(name, f"{where}.{key}: must contain exactly one question, at the end")
            for pat in LEAKS:
                if re.search(pat, p):
                    err(name, f"{where}.{key}: leaks an answer ({pat})")
        # Corrections must END in exactly one question; hints may be bare (the walker
        # appends the step prompt) or end in exactly one question.
        for m, txt in s.get("misconceptions", {}).items():
            if txt.count("?") != 1 or not txt.rstrip().endswith("?"):
                err(name, f"{where}: misconception {m!r} must end with exactly one question")
        for i, h in enumerate(s.get("hint_ladder", []), 1):
            if h.count("?") > 1 or ("?" in h and not h.rstrip().endswith("?")):
                err(name, f"{where}: hint {i} has a stray question")
        for op in s.get("canvas_ops", []):
            prm = op.get("params", {})
            if prm.get("author") == "tutor" and prm.get("reveal_answer"):
                err(name, f"{where}: tutor canvas op reveals answer")
            text = prm.get("latex_or_text", "")
            for pat in LEAKS:
                if re.search(pat, text):
                    err(name, f"{where}: tutor canvas text leaks answer: {text!r}")


checklist = ["# Native-speaker checklist (needs native check)\n",
             "Tick each Yorùbá string once a native speaker has confirmed spelling, tone marks and under-dots.",
             "Glossary entries where the Yorùbá equals the English are loanwords: propose a term or approve the loanword.\n"]
for path in PACKS:
    name = path.name
    pack = json.loads(path.read_text(encoding="utf-8"))
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
        check_steps(name, pr)
        for s in pr["steps"]:
            for t in s.get("term_ids", []):
                if t not in gids:
                    err(name, f"{pr['id']}.{s['id']}: unknown term_id {t}")
    checklist.append(f"\n## {name}\n")
    for g in pack.get("glossary", []):
        flag = " (loanword?)" if g["yo"].lower() == g["en"].lower() or g["yo"] == g["id"] else ""
        checklist.append(f"- [ ] glossary `{g['id']}`: **{g['yo']}** = {g['en']}{flag}")
    for pr in pack.get("problems", []):
        checklist.append(f"- [ ] {pr['id']} statement: {pr['statement_yo']}")
        for s in pr["steps"]:
            checklist.append(f"- [ ] {pr['id']}.{s['id']} prompt: {s['prompt_yo']}")
            for m, txt in s.get("misconceptions", {}).items():
                checklist.append(f"- [ ] {pr['id']}.{s['id']} correction for `{m}`: {txt}")
            for i, h in enumerate(s.get("hint_ladder", []), 1):
                checklist.append(f"- [ ] {pr['id']}.{s['id']} hint {i}: {h}")
    tc = pack.get("transfer_check", {})
    checklist.append(f"- [ ] transfer check: {tc.get('statement_yo', '')}")

(ROOT / "NATIVE-CHECK.md").write_text("\n".join(checklist) + "\n", encoding="utf-8")
if errors:
    print("FAIL")
    print("\n".join(errors))
    sys.exit(1)
print(f"OK: {len(PACKS)} packs valid, all strings NFC, checklist -> content/NATIVE-CHECK.md")
