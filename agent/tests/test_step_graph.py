import copy
import json
import re
from pathlib import Path

import pytest

from step_graph import LEAKS, Walker, leaks

PACK = json.loads((Path(__file__).parents[2] / "content" / "lesson-pack.json").read_text(encoding="utf-8"))
ROOTS = re.compile(r"x\s*=\s*[23]\b|\(x\s*[-−]\s*[23]\)")


def one_question(t):
    return t.count("?") == 1 and t.rstrip().endswith("?")


def test_open_asks_one_question_and_writes_blank_not_answer():
    t = Walker(PACK).open()
    assert one_question(t.text_en) and one_question(t.text_yo)
    assert t.canvas_ops[0]["params"]["latex_or_text"] == "a = ?, b = ?, c = ?"


def test_scripted_wrong_answer_gets_targeted_correction():
    w = Walker(PACK)
    t = w.submit("a=1, b=5, c=6")
    assert t.kind == "misconception"
    assert "plus five" in t.text_yo and one_question(t.text_yo)


def test_factoring_sign_mismatch_correction():
    w = Walker(PACK)
    for ans in ("a=1 b=-5 c=6", "-2 and -3"):
        assert w.submit(ans).kind == "correct"
    t = w.submit("(x+2)(x+3)=0")
    assert t.kind == "misconception"
    assert "−5x tàbí +5x" in t.text_yo and one_question(t.text_yo)


def test_hint_ladder_climbs_then_flags_analogy():
    w = Walker(PACK)
    first, second, third = (w.submit("no idea") for _ in range(3))
    assert first.kind == second.kind == "hint" and first.text_yo != second.text_yo
    assert all(one_question(t.text_yo) and one_question(t.text_en) for t in (first, second, third))
    assert third.needs_analogy


def test_full_correct_run_and_never_states_roots_before_student():
    w = Walker(PACK)
    answers = ["a=1, b=-5, c=6", "-2 and -3", "(x-2)(x-3)=0", "one bracket must be zero", "yes they match"]
    turns = [w.open()]
    for a in answers:
        turns.append(w.submit(a))
    tutor_text = []
    for i, t in enumerate(turns):
        tutor_text.append(t.text_en + t.text_yo)
        for op in t.canvas_ops:
            if op["params"].get("author") != "student":
                tutor_text.append(op["params"].get("latex_or_text", ""))
    # roots / factors only ever appear as student ink, never in tutor text or tutor ink
    assert not ROOTS.search(" ".join(tutor_text))
    assert turns[-1].kind == "transfer" and turns[-1].transfer_check["assist"] is False
    assert one_question(turns[-1].text_en) and one_question(turns[-1].text_yo)
    assert any(op["params"]["author"] == "student" for op in turns[-1].canvas_ops)


def test_every_step_text_is_leak_free_and_ends_in_one_question():
    for p in PACK["problems"]:
        for s in p["steps"]:
            assert not leaks(s["prompt_en"]) and not leaks(s["prompt_yo"])


def test_analogy_once_and_dropped_when_it_does_not_help():
    w = Walker(PACK)
    a = w.analogy("root")
    assert a and one_question(a.text_en) and w.analogy("root") is None
    w.submit("that doesn't help me")
    assert w.analogy("friction") is None


def test_leak_guard_blocks_answer_in_correction():
    w = Walker(copy.deepcopy(PACK))  # this test edits the pack; never share it
    w.step["misconceptions"]["b=5"] = "The roots are x = 2 and x = 3, right?"
    t = w.submit("b=5")
    assert "x = 2" not in t.text_en and one_question(t.text_en)


FACTORABLE = [p["id"] for p in PACK["problems"] if p["id"] != "p2"]


def _answer(step):
    a = step["acceptable_concepts"]
    if a[0].startswith("a="):
        return ", ".join(a)
    if a[0].startswith("pair="):
        return " and ".join(a[0].split("=")[1].split(","))
    if a[0].startswith("factored="):
        return a[0].split("=")[1] + "=0"
    return "one bracket must be zero" if step["id"] == "s4" else "yes they match"


@pytest.mark.parametrize("pid", FACTORABLE)
def test_every_factorable_problem_runs_to_transfer_without_leaking(pid):
    w = Walker(PACK, pid)
    prob = w.problem
    # roots/factors of THIS problem, from its own concepts; must never appear in tutor text
    tutor_text, turns = [], [w.open()]
    for s in prob["steps"]:
        for key, txt in s["misconceptions"].items():       # each known error gets its targeted fix
            if key.startswith(("b=", "c=", "pair=", "factored=")):
                t = Walker(PACK, pid)
                t.i = prob["steps"].index(s)
                got = t.submit(key.split("=", 1)[1] if key.startswith("factored=") else key.replace("=", " = ", 1) if key[0] in "bc" else key.split("=")[1].replace(",", " and "))
                assert got.kind == "misconception" and got.text_yo == txt["correction_yo"] and got.text_en == txt["correction_en"] and one_question(got.text_yo) and one_question(got.text_en), (pid, s["id"], key)
    for s in prob["steps"]:
        turns.append(w.submit(_answer(s)))
    assert turns[-1].kind == "transfer" and one_question(turns[-1].text_yo)
    for t in turns:
        tutor_text += [t.text_en, t.text_yo] + [o["params"].get("latex_or_text", "") for o in t.canvas_ops if o["params"].get("author") == "tutor"]
    assert not any(w._leaks(x) for x in tutor_text), pid
