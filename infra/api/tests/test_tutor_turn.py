import os
import time
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

import main
import tutor_turn as tt

client = TestClient(main.app)
CONTENT = Path(__file__).resolve().parents[3] / "content"
MP3 = bytes([0xFF, 0xFB, 0x90, 0x00]) + b"\0" * 16000  # 128 kbps, about 1000 ms

PLAN = {
    "spoken": "Let us solve it together.",
    "problem": "3x + 5 = 20",
    "steps": [
        {"question": "What do we do to both sides to get rid of the +5?", "expected": "subtract 5|minus 5|-5", "blanks": "3x = 20 - [ ]"},
        {"question": "What is 20 minus 5?", "expected": "15", "blanks": "3x = [ ]"},
        {"question": "What do we divide both sides by?", "expected": "3|divide by 3", "blanks": "x = 15 / [ ]"},
    ],
    "worked": [{"line": "3x + 5 = 20", "say": "Start here."}, {"line": "3x = 15", "say": "Subtract 5."}, {"line": "x = 5", "say": "Divide by 3."}],
    "result": "x = 5",
    "similar": "2x + 1 = 9",
}


class FakeBrain:
    """Rephrase brain for pack mode and plan source for general mode."""
    primary, fallback = "gemini", "groq"

    def __init__(self, plan=None, reply=None, fail=False):
        self.plan_data, self.reply, self.fail = plan, reply, fail

    def respond(self, ctx):
        if self.fail or self.reply is None:
            raise tt._agent()[0].BrainError("down")
        return self.reply, "gemini", 5

    def plan(self, problem, text, lang):
        if self.fail or self.plan_data is None:
            raise tt.PlanError("down")
        return dict(self.plan_data), "gemini"


@pytest.fixture(autouse=True)
def env(monkeypatch, tmp_path):
    monkeypatch.setenv("SORO_CONTENT_DIR", str(CONTENT))
    monkeypatch.setenv("SORO_TUTOR_AUDIO_DIR", str(tmp_path))
    monkeypatch.delenv("SPITCH_API_KEY", raising=False)
    monkeypatch.delenv("SORO_RECORD_KEY", raising=False)
    tt._packs.clear()
    tt.reset_sessions()
    monkeypatch.setattr(tt, "get_brain", lambda: FakeBrain())


def turn(**kw):
    kw.setdefault("session_id", "s1")
    kw.setdefault("lang", "en")
    kw.setdefault("mode", "guide")
    r = client.post("/tutor/turn", json=kw)
    assert r.status_code == 200
    return r.json()


def valid(out):
    assert {"session_id", "step_id", "say", "board", "done", "source"} <= set(out)
    assert out["source"] in ("gemini", "groq", "script")
    for op in out["board"]:
        assert op["op"] in ("write", "blank", "mark")


def test_pack_guide_opens_with_blanks_only():
    out = turn(problem="x^2 - 5x + 6 = 0", text="Help me solve this")
    valid(out)
    assert out["say"].count("?") == 1 and out["step_id"] == "s1"
    assert out["board"][0] == {"op": "write", "text": "x² − 5x + 6 = 0"}
    assert out["board"][1]["op"] == "blank" and "[ ]" in out["board"][1]["text"]
    blob = str(out)
    assert "x = 2" not in blob and "(x − 2)" not in blob


def test_pack_guide_walks_and_wrong_answer_stays_on_step():
    turn(problem="x^2 - 5x + 6 = 0", text="help")
    wrong = turn(text="no idea")
    assert wrong["step_id"] == "s1" and wrong["say"].count("?") == 1
    ok = turn(text="a=1, b=-5, c=6")
    assert ok["step_id"] == "s2"
    assert any(b["op"] == "mark" and b["kind"] == "tick" for b in ok["board"])


def test_pack_guide_brain_leak_is_dropped():
    tt.get_brain = lambda: FakeBrain(reply={"spoken": "The factors are (x - 2)(x - 3)?", "caption_en": "The factors are (x - 2)(x - 3)?"})
    turn(problem="x^2 - 5x + 6 = 0", text="help")
    out = turn(text="a=1, b=-5, c=6")
    assert "(x - 2)" not in out["say"] and out["say"].count("?") == 1


def test_pack_brain_reply_reports_provider():
    tt.get_brain = lambda: FakeBrain(reply={"spoken": "Nice. Which two numbers multiply to c and add to b?",
                                           "caption_en": "Nice. Which two numbers multiply to c and add to b?"})
    turn(problem="x^2 - 5x + 6 = 0", text="help")
    out = turn(text="a=1, b=-5, c=6")
    assert out["source"] == "gemini" and out["say"].startswith("Nice.")


def test_topic_without_equation_matches_pack():
    out = turn(session_id="t", text="explain friction on a crate")
    assert out["step_id"] == "s1" and "smooth floor" in out["say"].lower()


def test_pack_solve_full_working_and_try_it():
    out = turn(mode="solve", problem="x^2 - 5x + 6 = 0", text="solve this")
    valid(out)
    texts = [b["text"] for b in out["board"]]
    assert "(x − 2)(x − 3) = 0" in texts and "x = 2  or  x = 3" in texts
    assert out["board"][-1]["op"] == "blank" and out["done"] is True
    assert all(s["say"] for s in out["steps"])


def test_pack_solve_completing_square():
    out = turn(mode="solve", problem="x² + 2x = 1")
    texts = [b["text"] for b in out["board"]]
    assert "(x + 1)² = 2" in texts and "x = −1 ± √2" in texts


def test_general_guide_walks_plan_without_leaking():
    tt.get_brain = lambda: FakeBrain(plan=PLAN)
    out = turn(problem="3x + 5 = 20", text="help")
    valid(out)
    assert out["source"] == "gemini" and out["say"].count("?") == 1
    assert out["board"][0]["text"] == "3x + 5 = 20"
    assert "x = 5" not in str(out)
    out = turn(text="subtract 5")
    assert out["step_id"] == "s2" and out["board"][0]["text"] == "subtract 5"
    assert turn(text="banana")["step_id"] == "s2"
    turn(text="15")
    fin = turn(text="divide by 3")
    assert fin["done"] is True and "x = 5" not in fin["say"]


def test_general_guide_leaking_question_is_replaced():
    plan = dict(PLAN, steps=[dict(PLAN["steps"][0], question="Is the answer x = 5?"), *PLAN["steps"][1:]])
    tt.get_brain = lambda: FakeBrain(plan=plan)
    out = turn(problem="3x + 5 = 20", text="help")
    assert "x = 5" not in out["say"] and out["say"].count("?") == 1


def test_general_solve_returns_ordered_lines_and_similar():
    tt.get_brain = lambda: FakeBrain(plan=PLAN)
    out = turn(mode="solve", problem="3x + 5 = 20", text="solve this")
    assert [b["text"] for b in out["board"]] == ["3x + 5 = 20", "3x = 15", "x = 5", "2x + 1 = 9"]
    assert out["done"] and len(out["steps"]) == 4


def test_general_explanation_only():
    plan = {"spoken": "Plants make food from light.", "problem": "How does photosynthesis work?",
            "steps": [{"question": "What do plants take in from the air?", "expected": "carbon dioxide|co2", "blanks": "[ ] + water + light"},
                      {"question": "What energy source drives it?", "expected": "sunlight|light", "blanks": ""},
                      {"question": "What sugar does the plant make?", "expected": "glucose", "blanks": "6CO2 + 6H2O -> [ ] + 6O2"}],
            "worked": [{"line": "6CO2 + 6H2O -> C6H12O6 + 6O2", "say": "That is the equation."}, {"line": "Plants make glucose from light", "say": "In short."}],
            "result": "Plants make glucose from light", "similar": ""}
    tt.get_brain = lambda: FakeBrain(plan=plan)
    out = turn(problem="How does photosynthesis work?", text="")
    assert out["source"] == "gemini" and out["say"].count("?") == 1 and "glucose" not in out["say"].lower()
    assert turn(text="carbon dioxide")["step_id"] == "s2"


@pytest.mark.parametrize("mutate", [
    lambda p: p.update(result="x = 6"),                       # worked lines and result fail verification
    lambda p: p.update(steps=p["steps"][:2]),                 # too few steps
    lambda p: p["steps"][0].update(question="What? Why?"),    # two questions
    lambda p: p.pop("worked"),
])
def test_bad_plan_gets_honest_reply(mutate):
    plan = {**PLAN, "worked": [dict(w) for w in PLAN["worked"]], "steps": [dict(s) for s in PLAN["steps"]]}
    mutate(plan)
    tt.get_brain = lambda: FakeBrain(plan=plan)
    out = turn(problem="3x + 5 = 20", text="help")
    assert out["source"] == "script" and out["say"] == tt.HONEST and out["board"] == []


def test_brain_failure_and_garbage_requests_still_200():
    tt.get_brain = lambda: FakeBrain(fail=True)
    assert turn(problem="3x + 5 = 20")["say"] == tt.HONEST
    tt.get_brain = lambda: None
    assert turn(session_id="q", problem="tell me about volcanoes")["say"] == tt.HONEST
    for raw in (b"not json", b"[1,2]", b"{}"):
        r = client.post("/tutor/turn", content=raw)
        assert r.status_code == 200 and r.json()["source"] == "script"


def test_optional_key_and_cors(monkeypatch):
    monkeypatch.setenv("SORO_RECORD_KEY", "k")
    assert client.post("/tutor/turn", json={"session_id": "a"}).status_code == 401
    assert client.post("/tutor/turn", json={"session_id": "a"}, headers={"X-Soro-Key": "k"}).status_code == 200
    r = client.options("/tutor/turn", headers={"Origin": "http://x.test", "Access-Control-Request-Method": "POST",
                                               "Access-Control-Request-Headers": "x-soro-key,content-type"})
    assert r.headers["access-control-allow-origin"] in ("*", "http://x.test")


def test_sessions_expire(monkeypatch):
    turn(problem="x^2 - 5x + 6 = 0", text="help")
    turn(text="a=1, b=-5, c=6")
    monkeypatch.setattr(tt, "SESSION_TTL_S", -1)
    assert turn(problem="x^2 - 5x + 6 = 0", text="help")["step_id"] == "s1"


def test_audio_attached_when_spitch_works(monkeypatch):
    import tts
    monkeypatch.setenv("SPITCH_API_KEY", "x")
    monkeypatch.setattr(tts, "synth", lambda *a, **k: MP3)
    out = turn(mode="solve", problem="x^2 - 5x + 6 = 0")
    assert out["audio_ms"] == 1000 and out["audio_url"].startswith("/tutor/audio/")
    assert out["steps"][0]["audio_ms"] == 1000 and out["steps"][0]["board"][0]["audio_ms"] == 1000
    got = client.get(out["audio_url"])
    assert got.status_code == 200 and got.content == MP3
    assert client.get("/tutor/audio/../x.mp3").status_code in (400, 404)


def test_audio_omitted_on_failure_or_timeout(monkeypatch):
    import tts
    monkeypatch.setenv("SPITCH_API_KEY", "x")

    def boom(*a, **k):
        raise tts.TTSError("down")
    monkeypatch.setattr(tts, "synth", boom)
    assert "audio_url" not in turn(problem="x^2 - 5x + 6 = 0")

    monkeypatch.setattr(tts, "synth", lambda *a, **k: time.sleep(1) or MP3)
    monkeypatch.setattr(tt, "BUDGET_S", 0.6)
    t0 = time.monotonic()
    out = turn(session_id="slow", problem="x^2 - 5x + 6 = 0")
    assert "audio_url" not in out and time.monotonic() - t0 < 1.5


def test_safe_eval_and_verify():
    assert tt.safe_eval("2(3+4)^2") == 98
    with pytest.raises(ValueError):
        tt.safe_eval("__import__('os')")
    assert tt.verify_result("x^2 - 5x + 6 = 0", "x = 2 or x = 3")
    assert not tt.verify_result("x^2 - 5x + 6 = 0", "x = 2 or x = 4")
    assert tt.verify_result("x^2 + 2x = 1", "x = -1 ± sqrt(2)")
