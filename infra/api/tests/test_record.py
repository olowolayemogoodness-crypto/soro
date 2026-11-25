import pytest
from fastapi.testclient import TestClient

import main

client = TestClient(main.app)
BODY = {"session_id": "s-1", "subject": "mathematics", "topic": "math101-quadratics",
        "lesson": "Solving x^2-5x+6=0", "step": 2, "completed": True,
        "check": {"result": "passed", "attempts": 1}}


class Row(dict):
    pass


class FakeConn:
    """Records SQL and answers the two SELECTs the endpoint makes."""
    def __init__(self, owner="demo-learner", steps_done=2):
        self.calls, self.owner, self.steps_done = [], owner, steps_done

    def __enter__(self): return self
    def __exit__(self, *a): return False

    def execute(self, sql, params=()):
        self.calls.append((" ".join(sql.split()), params))
        conn = self

        class R:
            def fetchone(self_inner):
                if "SELECT learner_id" in sql: return {"learner_id": conn.owner}
                if "count(*)" in sql: return {"n": conn.steps_done}
        return R()


@pytest.fixture
def conn(monkeypatch):
    c = FakeConn()
    monkeypatch.setattr(main, "_connect", lambda: c)
    monkeypatch.delenv("SORO_RECORD_KEY", raising=False)
    return c


def test_records_step_and_check_in_one_transaction(conn):
    r = client.post("/progress/record", json=BODY)
    assert r.status_code == 200
    assert r.json() == {"ok": True, "session_id": "s-1", "steps_done": 2,
                        "unaided_check": {"result": "passed", "attempts": 1}}
    sqls = [c[0] for c in conn.calls]
    assert any(s.startswith("INSERT INTO learners") for s in sqls)
    assert any(s.startswith("INSERT INTO sessions") for s in sqls)
    assert any(s.startswith("INSERT INTO steps") and "ON CONFLICT (session_id, position)" in s for s in sqls)
    assert any(s.startswith("INSERT INTO unaided_checks") and "ON CONFLICT (session_id)" in s for s in sqls)
    assert all("%s" in s for s in sqls if "INSERT" in s)  # parameterised, never string-built


def test_defaults_to_demo_learner_and_step_only(conn):
    r = client.post("/progress/record", json={k: v for k, v in BODY.items() if k != "check"})
    assert r.status_code == 200 and r.json()["unaided_check"] is None
    assert not any(c[0].startswith("INSERT INTO unaided_checks") for c in conn.calls)
    assert conn.calls[0][1] == ("demo-learner",)


@pytest.mark.parametrize("patch", [
    {"check": {"result": "great", "attempts": 1}},          # not passed|needs_practice
    {"check": {"result": "passed", "attempts": -1}},
    {"step": 0},
    {"learner_id": "Ada Lovelace"},                          # a name, not an anonymous id
    {"learner_id": "a@b.com"},
    {"session_id": "x; DROP TABLE sessions"},
])
def test_rejects_bad_input(conn, patch):
    assert client.post("/progress/record", json={**BODY, **patch}).status_code == 422
    assert conn.calls == []                                  # nothing touched the database


def test_session_belongs_to_one_learner(monkeypatch):
    monkeypatch.setattr(main, "_connect", lambda: FakeConn(owner="someone-else"))
    r = client.post("/progress/record", json=BODY)
    assert r.status_code == 409


def test_record_key_protects_the_write(conn, monkeypatch):
    monkeypatch.setenv("SORO_RECORD_KEY", "k-test-123")
    assert client.post("/progress/record", json=BODY).status_code == 401
    assert client.post("/progress/record", json=BODY, headers={"X-Soro-Key": "nope"}).status_code == 401
    assert client.post("/progress/record", json=BODY, headers={"X-Soro-Key": "k-test-123"}).status_code == 200
