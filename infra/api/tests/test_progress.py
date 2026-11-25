from datetime import date

from fastapi.testclient import TestClient

import main
import progress

T = date(2026, 11, 25)
ev = lambda *ds: [{"date": d, "kind": "step", "subject": "m", "topic_id": "t"} for d in ds]


def test_consecutive_days_count():
    assert progress.streak(ev("2026-11-23", "2026-11-24", "2026-11-25"), T)["current"] == 3


def test_missed_day_resets_to_zero():
    assert progress.streak(ev("2026-11-21", "2026-11-22", "2026-11-23"), T)["current"] == 0


def test_alive_if_only_yesterday_and_today_not_counted():
    s = progress.streak(ev("2026-11-23", "2026-11-24"), T)
    assert s["current"] == 2 and s["today_counted"] is False


def test_same_day_events_count_once_and_longest_tracked():
    s = progress.streak(ev("2026-11-10", "2026-11-11", "2026-11-12", "2026-11-25", "2026-11-25"), T)
    assert s["current"] == 1 and s["longest"] == 3


def test_seed_shape_and_endpoint():
    r = TestClient(main.app).get("/progress?today=2026-11-25").json()
    assert r["streak"] == {"current": 5, "longest": 5, "today_counted": True} and r["source"] == "seeded"
    assert r["days"][0]["date"] == "2026-11-25"
    math = next(s for s in r["subjects"] if s["subject"] == "mathematics")["topics"][0]
    assert math["topic_id"] == "math101-quadratics" and math["checks"][0]["passed"] in (True, False)
    assert "name" not in str(r).lower()
