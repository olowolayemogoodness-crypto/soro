import json
from pathlib import Path

import pytest

import brain as brain_mod
from brain import Brain, BrainError
from tutor import Tutor, one_question

PACK = json.loads((Path(__file__).parents[2] / "content" / "lesson-pack.json").read_text(encoding="utf-8"))


class FakeBrain:
    def __init__(self, yo, en="What is the sign in front of 5x?"):
        self.out = {"spoken_yo": yo, "caption_en": en}

    def respond(self, ctx):
        return dict(self.out), "fake", 12


def test_good_brain_reply_is_used():
    t = Tutor(PACK, brain=FakeBrain("Dúró, wo àmì tó wà níwájú 5x: plus ni tàbí minus?"))
    t.start()
    r = t.handle("a=1, b=5, c=6")
    assert r.provider == "fake" and r.kind == "misconception" and one_question(r.spoken_yo)


@pytest.mark.parametrize("bad", [
    "Ó dára! Kí ni a? Kí ni b?",                       # two questions
    "Ìdáhùn ni x = 2 àti x = 3, ṣé o gbọ́?",           # states the roots
    "Ọ̀rọ̀ yìí gùn jù " * 30 + "ṣé?",                   # too long for voice
    "Ó dára, tẹ̀síwájú.",                              # no question
])
def test_guard_falls_back_to_pack_text(bad):
    t = Tutor(PACK, brain=FakeBrain(bad))
    t.start()
    t.handle("a=1, b=-5, c=6")           # reach s2
    r = t.handle("1 and 6")              # wrong, gets a hint turn
    assert r.provider == "pack" and one_question(r.spoken_yo)


def test_brain_failure_uses_pack_and_loop_continues():
    class Down:
        def respond(self, ctx):
            raise BrainError("both providers down")
    t = Tutor(PACK, brain=Down())
    t.start()
    r = t.handle("a=1, b=-5, c=6")
    assert r.provider == "pack" and r.kind == "correct" and one_question(r.spoken_yo)


def test_events_follow_contract_shapes():
    t = Tutor(PACK, use_brain=False)
    start = t.start()
    assert start.events[0] == {"v": 1, "type": "tier", "level": 0}
    r = t.handle("a=1, b=-5, c=6")
    kinds = [e["type"] for e in r.events]
    assert kinds[0] == "caption" and r.events[0]["role"] == "student"
    chip = next(e for e in r.events if e["type"] == "term_chip")
    assert chip["audio_url"].startswith("/packs/math101-quadratics/audio/") and chip["term_yo"]
    ink = [e for e in r.events if e["type"] == "canvas_cmd"]
    assert ink[0]["params"]["author"] == "student" and ink[1]["params"]["author"] == "tutor"


def test_brain_switch_and_failover(monkeypatch):
    calls = []

    def gem(model, system, user, timeout):
        calls.append("gemini")
        raise BrainError("gemini HTTP 429")

    def grq(model, system, user, timeout):
        calls.append("groq")
        return {"spoken_yo": "Ó dára. Kí ni b?", "caption_en": "What is b?"}

    monkeypatch.setitem(brain_mod.ADAPTERS, "gemini", gem)
    monkeypatch.setitem(brain_mod.ADAPTERS, "groq", grq)
    monkeypatch.setenv("SORO_BRAIN_PROVIDER", "gemini")
    monkeypatch.setenv("SORO_BRAIN_FALLBACK_PROVIDER", "groq")
    _, used, _ = Brain().respond({"x": 1})
    assert used == "groq" and calls == ["gemini", "groq"]

    calls.clear()
    monkeypatch.setenv("SORO_BRAIN_PROVIDER", "groq")       # the switch
    _, used, _ = Brain().respond({"x": 1})
    assert used == "groq" and calls == ["groq"]
