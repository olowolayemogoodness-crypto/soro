import copy
import json
import re
from pathlib import Path

import pytest

import brain as brain_mod
from tutor import Tutor, one_question

CONTENT = Path(__file__).parents[2] / "content"
PACK = json.loads((CONTENT / "lesson-pack.json").read_text(encoding="utf-8"))
YORUBA_MARKS = re.compile(r"[ẹọṣàáèéìíòóùúńǹ]")


def tutor_captions(reply):
    return [e for e in reply.events if e["type"] == "caption" and e["role"] == "tutor"]


def test_english_mode_speaks_and_captions_english_only():
    t = Tutor(PACK, use_brain=False, lang="en")
    start = t.start()
    caps = tutor_captions(start)
    assert [c["lang"] for c in caps] == ["en"] and start.spoken == start.caption_en
    assert not YORUBA_MARKS.search(start.spoken)


def test_yoruba_mode_gives_yoruba_caption_plus_english_line():
    t = Tutor(PACK, use_brain=False, lang="yo")
    start = t.start()
    caps = tutor_captions(start)
    assert [c["lang"] for c in caps] == ["yo", "en"] and caps[0]["text"] != caps[1]["text"]
    assert caps[0]["text"] == start.spoken == start.spoken_yo   # the Yoruba line is what is spoken
    assert caps[1]["text"] == start.caption_en                  # the second caption is the English line


def test_student_caption_is_always_english():
    for lang in ("en", "yo"):
        t = Tutor(PACK, use_brain=False, lang=lang)
        t.start()
        r = t.handle("a=1, b=5, c=6")
        stu = [e for e in r.events if e["type"] == "caption" and e["role"] == "student"]
        assert stu and stu[0]["lang"] == "en"


def test_english_correction_targets_the_specific_error_and_is_english():
    t = Tutor(PACK, use_brain=False, lang="en")
    t.start()
    r = t.handle("a=1, b=5, c=6")
    assert r.kind == "misconception" and "plus five or minus five" in r.spoken
    assert one_question(r.spoken) and not YORUBA_MARKS.search(r.spoken)


def test_english_hints_are_english_and_climb():
    t = Tutor(PACK, use_brain=False, lang="en")
    t.start()
    first, second = t.handle("no idea"), t.handle("still no idea")
    assert first.kind == second.kind == "hint" and first.spoken != second.spoken
    for r in (first, second):
        assert one_question(r.spoken) and not YORUBA_MARKS.search(r.spoken)


def test_term_chip_audio_follows_language():
    for lang, suffix in (("yo", "coefficient.mp3"), ("en", "coefficient_en.mp3")):
        t = Tutor(PACK, use_brain=False, lang=lang)
        chip = next(e for e in t.start().events if e["type"] == "term_chip")
        assert chip["audio_url"].endswith("/" + suffix) and chip["term_en"] and chip["term_yo"]


def test_unknown_language_is_rejected():
    with pytest.raises(ValueError):
        Tutor(PACK, use_brain=False, lang="fr")


def test_brain_prompt_follows_language():
    yo, en = brain_mod.system_prompt("yo"), brain_mod.system_prompt("en")
    assert "Yoruba" in yo and "tone marks" in yo
    assert "plain English" in en and "tone marks" not in en
    assert "EXACTLY ONE" in yo and "EXACTLY ONE" in en  # the guard rules never change


class FakeBrain:
    def __init__(self, out):
        self.out, self.seen = out, None

    def respond(self, ctx):
        self.seen = ctx
        return dict(self.out), "fake", 9


def test_brain_gets_language_and_english_reply_is_used():
    fb = FakeBrain({"spoken": "Hold on, is the sign in front of 5x plus or minus?", "caption_en": "Hold on, is the sign in front of 5x plus or minus?"})
    t = Tutor(PACK, brain=fb, lang="en")
    t.start()
    r = t.handle("a=1, b=5, c=6")
    assert fb.seen["tutor_language"] == "en" and r.provider == "fake" and one_question(r.spoken)


def test_english_brain_reply_that_breaks_a_rule_falls_back_to_pack():
    fb = FakeBrain({"spoken": "Great! The roots are x = 2 and x = 3, right?", "caption_en": "x"})
    t = Tutor(PACK, brain=fb, lang="en")
    t.start()
    t.handle("a=1, b=-5, c=6")
    r = t.handle("1 and 6")
    assert r.provider == "pack" and "x = 2" not in r.spoken


def test_pack_follows_the_frozen_shape_for_these_fields():
    for prob in PACK["problems"]:
        for st in prob["steps"]:
            assert "term_ids" not in st                      # not allowed by the frozen lesson-pack contract
            for m in st["misconceptions"].values():
                assert set(m) <= {"triggers", "correction_yo", "correction_en", "canvas_ops"} and m["correction_en"]


def test_negative_c_problems_do_not_claim_same_sign():
    # p5, p9, p10 have c < 0: the old hint wrongly said both numbers share a sign because c is positive
    en_hints = json.loads((CONTENT / "en-text.json").read_text(encoding="utf-8"))["hints"]["math101-quadratics"]
    for pid in ("p5", "p9", "p10"):
        step = next(s for s in next(p for p in PACK["problems"] if p["id"] == pid)["steps"] if s["id"] == "s2")
        assert "different signs" in en_hints[pid]["s2"][1] and "same sign" not in en_hints[pid]["s2"][1]
        assert "yàtọ̀" in step["hint_ladder"][1]
    for pid in ("p1", "p3", "p4"):
        assert "same sign" in en_hints[pid]["s2"][1]
