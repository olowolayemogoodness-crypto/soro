import json

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
