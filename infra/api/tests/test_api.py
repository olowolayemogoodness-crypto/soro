import json
from datetime import date

import jwt
import pytest
from fastapi.testclient import TestClient

import main

client = TestClient(main.app)

BODY = {"room": "soro-demo", "participant": "student-1", "topic_id": "math101-quadratics"}


@pytest.fixture(autouse=True)
def env(monkeypatch, tmp_path):
    (tmp_path / "audio").mkdir()
    (tmp_path / "audio" / "root.mp3").write_bytes(b"ID3fake")
    (tmp_path / "lesson-pack.json").write_text(
        json.dumps({"topic_id": "math101-quadratics", "glossary": []}), encoding="utf-8"
    )
    monkeypatch.setenv("SORO_CONTENT_DIR", str(tmp_path))
    monkeypatch.setenv("LIVEKIT_MODE", "nobus")
    monkeypatch.setenv("NOBUS_LIVEKIT_URL", "ws://nobus.test:7880")
    monkeypatch.setenv("NOBUS_LIVEKIT_API_KEY", "nobuskey")
    monkeypatch.setenv("NOBUS_LIVEKIT_API_SECRET", "n" * 40)
    monkeypatch.setenv("CLOUD_LIVEKIT_URL", "wss://cloud.test")
    monkeypatch.setenv("CLOUD_LIVEKIT_API_KEY", "cloudkey")
    monkeypatch.setenv("CLOUD_LIVEKIT_API_SECRET", "c" * 40)


def test_health_shape():
    assert client.get("/health").json() == {"ok": True, "tier": 0, "livekit_mode": "nobus"}


def test_pack_served_and_missing():
    assert client.get("/packs/math101-quadratics").json()["topic_id"] == "math101-quadratics"
    assert client.get("/packs/physics-friction").status_code == 404
    assert client.get("/packs/..%2Fetc").status_code in (400, 404)


def test_audio_served_and_traversal_blocked():
    r = client.get("/packs/math101-quadratics/audio/root.mp3")
    assert r.status_code == 200 and r.headers["content-type"] == "audio/mpeg"
    assert client.get("/packs/math101-quadratics/audio/..%2F..%2Fpyproject.toml").status_code in (400, 404)
    assert client.get("/packs/math101-quadratics/audio/x.wav").status_code == 400


def test_token_nobus_then_failover_to_cloud(monkeypatch):
    r = client.post("/session/token", json=BODY).json()
    assert r["livekit_url"] == "ws://nobus.test:7880" and r["room"] == "soro-demo"
    claims = jwt.decode(r["token"], "n" * 40, algorithms=["HS256"])
    assert claims["iss"] == "nobuskey" and claims["sub"] == "student-1"
    assert claims["video"]["room"] == "soro-demo" and claims["video"]["roomJoin"] is True

    monkeypatch.setenv("LIVEKIT_MODE", "cloud")
    assert client.get("/health").json()["livekit_mode"] == "cloud"
    r = client.post("/session/token", json=BODY).json()
    assert r["livekit_url"] == "wss://cloud.test"
    assert jwt.decode(r["token"], "c" * 40, algorithms=["HS256"])["iss"] == "cloudkey"


def test_token_errors(monkeypatch):
    assert client.post("/session/token", json={**BODY, "room": "bad room!"}).status_code == 422
    monkeypatch.delenv("NOBUS_LIVEKIT_API_SECRET")
    assert client.post("/session/token", json=BODY).status_code == 503
    monkeypatch.setenv("LIVEKIT_MODE", "bogus")
    assert client.get("/health").status_code == 500


def test_streak_consecutive_days_and_unique_repeats():
    dates = [date(2026, 11, 20), date(2026, 11, 21), date(2026, 11, 21), date(2026, 11, 22)]
    assert main.streak_from_dates(dates, date(2026, 11, 22)) == {
        "current": 3, "longest": 3, "last_active_date": "2026-11-22"
    }


def test_streak_gap_resets_current_but_preserves_longest():
    dates = [date(2026, 11, 15), date(2026, 11, 16), date(2026, 11, 18), date(2026, 11, 19)]
    assert main.streak_from_dates(dates, date(2026, 11, 19)) == {
        "current": 2, "longest": 2, "last_active_date": "2026-11-19"
    }
    assert main.streak_from_dates(dates, date(2026, 11, 21))["current"] == 0


def test_empty_streak():
    assert main.streak_from_dates([], date(2026, 11, 22)) == {
        "current": 0, "longest": 0, "last_active_date": None
    }


def test_progress_without_database_is_service_unavailable(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)
    response = client.get("/progress")
    assert response.status_code == 503
    assert response.json()["detail"] == "DATABASE_URL is not configured"


def test_progress_response_groups_days_and_topics_and_keeps_check_results():
    rows = [
        {
            "session_id": "s1", "activity_date": date(2026, 11, 22), "subject": "Mathematics",
            "topic": "Quadratics", "lesson": "Factoring", "steps_done": 2,
            "check_result": "passed", "attempts": 1,
        },
        {
            "session_id": "s2", "activity_date": date(2026, 11, 22), "subject": "Mathematics",
            "topic": "Quadratics", "lesson": "Roots", "steps_done": 1,
            "check_result": "needs_practice", "attempts": 2,
        },
        {
            "session_id": "s3", "activity_date": date(2026, 11, 20), "subject": "Physics",
            "topic": "Friction", "lesson": "Forces", "steps_done": 3,
            "check_result": "not_taken", "attempts": 0,
        },
    ]
    progress = main.assemble_progress({"id": "demo-learner", "display_name": "Demo learner"}, rows, date(2026, 11, 22))
    assert progress["learner"]["display_name"] == "Demo learner"
    assert [day["date"] for day in progress["days"]] == ["2026-11-22", "2026-11-20"]
    assert [session["unaided_check"]["result"] for session in progress["days"][0]["sessions"]] == ["passed", "needs_practice"]
    assert progress["topics"] == [
        {"subject": "Mathematics", "topic": "Quadratics", "attempts": 3, "passed": 1, "needs_practice": 1},
        {"subject": "Physics", "topic": "Friction", "attempts": 0, "passed": 0, "needs_practice": 0},
    ]
