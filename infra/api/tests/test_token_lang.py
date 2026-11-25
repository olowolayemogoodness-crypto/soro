import json

import jwt
import pytest
from fastapi.testclient import TestClient

import main

client = TestClient(main.app)
BODY = {"room": "soro-demo", "participant": "student-1", "topic_id": "math101-quadratics"}
SECRET = "n" * 40


@pytest.fixture(autouse=True)
def env(monkeypatch):
    monkeypatch.setenv("LIVEKIT_MODE", "nobus")
    monkeypatch.setenv("NOBUS_LIVEKIT_URL", "ws://nobus.test:7880")
    monkeypatch.setenv("NOBUS_LIVEKIT_API_KEY", "nobuskey")
    monkeypatch.setenv("NOBUS_LIVEKIT_API_SECRET", SECRET)


def meta(resp):
    return json.loads(jwt.decode(resp.json()["token"], SECRET, algorithms=["HS256"])["metadata"])


def test_token_carries_the_tutor_language():
    for lang in ("en", "yo"):
        r = client.post("/session/token", json={**BODY, "lang": lang})
        assert r.status_code == 200 and meta(r) == {"topic_id": "math101-quadratics", "lang": lang}


def test_language_is_optional_and_validated():
    assert meta(client.post("/session/token", json=BODY)) == {"topic_id": "math101-quadratics"}
    assert client.post("/session/token", json={**BODY, "lang": "fr"}).status_code == 422
