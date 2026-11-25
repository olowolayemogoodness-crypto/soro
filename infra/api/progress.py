"""Progress + daily streak (B6). Pure logic; storage is a list of event dicts.

An event: {"date": "YYYY-MM-DD", "kind": "step"|"check", "subject", "topic_id",
"problem_id"?, "passed"?}. No student names or ids ever appear here.
A day counts once it has at least one event. A missed day resets the streak to 0.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import date, timedelta


def _d(s: str) -> date:
    return date.fromisoformat(s)


def streak(events: list[dict], today: date) -> dict:
    days = sorted({_d(e["date"]) for e in events})
    dayset = set(days)
    # Alive if today OR yesterday has activity (today may simply not have happened yet).
    end = today if today in dayset else today - timedelta(days=1)
    current = 0
    while end in dayset:
        current += 1
        end -= timedelta(days=1)
    longest = run = 0
    prev = None
    for d in days:
        run = run + 1 if prev and d - prev == timedelta(days=1) else 1
        longest, prev = max(longest, run), d
    return {"current": current, "longest": longest, "today_counted": today in dayset}


def summary(events: list[dict], today: date) -> dict:
    by_day: dict[str, dict] = defaultdict(lambda: {"steps": 0, "checks": 0})
    topics: dict[tuple, dict] = {}
    for e in events:
        row = by_day[e["date"]]
        row["steps" if e["kind"] == "step" else "checks"] += 1
        t = topics.setdefault((e["subject"], e["topic_id"]), {"topic_id": e["topic_id"], "attempts": 0, "checks": []})
        if e["kind"] == "check":
            t["attempts"] += 1
            t["checks"].append({"problem_id": e.get("problem_id"), "date": e["date"], "passed": bool(e.get("passed"))})
    subjects: dict[str, list] = defaultdict(list)
    for (subject, _), t in sorted(topics.items()):
        subjects[subject].append(t)
    return {
        "streak": streak(events, today),
        "days": [{"date": d, **v} for d, v in sorted(by_day.items(), reverse=True)],
        "subjects": [{"subject": s, "topics": ts} for s, ts in subjects.items()],
    }


def seed(today: date) -> list[dict]:
    """Demo data: a 5-day run ending today, an older gap, then an older 2-day run."""
    ev = []
    for back in (0, 1, 2, 3, 4):
        d = (today - timedelta(days=back)).isoformat()
        ev += [{"date": d, "kind": "step", "subject": "mathematics", "topic_id": "math101-quadratics"}] * (2 + back % 3)
    ev += [{"date": (today - timedelta(days=1)).isoformat(), "kind": "check", "subject": "mathematics",
            "topic_id": "math101-quadratics", "problem_id": "quad-tc-01", "passed": False},
           {"date": today.isoformat(), "kind": "check", "subject": "mathematics",
            "topic_id": "math101-quadratics", "problem_id": "quad-tc-01", "passed": True},
           {"date": (today - timedelta(days=3)).isoformat(), "kind": "check", "subject": "physics",
            "topic_id": "physics-friction", "problem_id": "fric-tc-01", "passed": True}]
    for back in (9, 10):
        ev.append({"date": (today - timedelta(days=back)).isoformat(), "kind": "step", "subject": "mathematics",
                   "topic_id": "math101-quadratics"})
    return ev
