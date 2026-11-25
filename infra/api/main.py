"""Soro M5 API: /health, /packs/{topic_id}, /session/token (contracts/api.json).

Secrets come only from environment variables (infra/.env, gitignored).
"""
from __future__ import annotations

import json
import os
import re
from contextlib import asynccontextmanager
from datetime import date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from livekit import api as lk
from pydantic import BaseModel, Field
from tutor_turn import router as tutor_router
import psycopg
from psycopg.rows import dict_row

TOPIC_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")
AUDIO_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}\.mp3$")
NAME_RE = re.compile(r"^[A-Za-z0-9_.-]{1,64}$")
MODES = ("nobus", "cloud")

LAGOS = ZoneInfo("Africa/Lagos")
MIGRATIONS_DIR = Path(__file__).parent / "migrations"


def database_url() -> str:
    return os.getenv("DATABASE_URL", "").strip()


def _connect() -> psycopg.Connection:
    url = database_url()
    if not url:
        raise HTTPException(503, "DATABASE_URL is not configured")
    return psycopg.connect(url, row_factory=dict_row)


def apply_migrations() -> None:
    """Apply ordered, transactional SQL migrations once per database."""
    with _connect() as conn:
        conn.execute(
            "CREATE TABLE IF NOT EXISTS schema_migrations "
            "(version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())"
        )
        for path in sorted(MIGRATIONS_DIR.glob("*.sql")):
            conn.execute("SELECT pg_advisory_xact_lock(hashtext('soro_api_schema_migrations'))")
            applied = conn.execute(
                "SELECT 1 FROM schema_migrations WHERE version = %s", (path.name,)
            ).fetchone()
            if applied:
                continue
            conn.execute(path.read_text(encoding="utf-8"), prepare=False)
            conn.execute("INSERT INTO schema_migrations (version) VALUES (%s)", (path.name,))


@asynccontextmanager
async def lifespan(_: FastAPI):
    if database_url():
        apply_migrations()
    yield


app = FastAPI(title="Soro API", version="0.1.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in os.getenv("SORO_CORS_ORIGINS", "*").split(",") if o.strip()],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

app.include_router(tutor_router)


def content_dir() -> Path:
    return Path(os.getenv("SORO_CONTENT_DIR", "../content")).resolve()


def livekit_mode() -> str:
    mode = os.getenv("LIVEKIT_MODE", "nobus").strip().lower()
    if mode not in MODES:
        raise HTTPException(500, f"LIVEKIT_MODE must be one of {MODES}, got {mode!r}")
    return mode


def livekit_creds() -> tuple[str, str, str]:
    """Return (url, key, secret) for the active mode. Never logs values."""
    prefix = "NOBUS" if livekit_mode() == "nobus" else "CLOUD"
    url = os.getenv(f"{prefix}_LIVEKIT_URL", "")
    key = os.getenv(f"{prefix}_LIVEKIT_API_KEY", "")
    secret = os.getenv(f"{prefix}_LIVEKIT_API_SECRET", "")
    missing = [n for n, v in (("URL", url), ("API_KEY", key), ("API_SECRET", secret)) if not v]
    if missing:
        raise HTTPException(503, f"{prefix}_LIVEKIT_{', '.join(missing)} not configured")
    return url, key, secret


@app.get("/health")
def health() -> dict:
    return {
        "ok": True,
        "tier": int(os.getenv("SORO_TIER", "0")),
        "livekit_mode": livekit_mode(),
    }


def _load_pack(topic_id: str) -> dict:
    if not TOPIC_RE.fullmatch(topic_id):
        raise HTTPException(400, "invalid topic_id")
    base = content_dir()
    for candidate in (base / "packs" / f"{topic_id}.json", base / "lesson-pack.json"):
        if candidate.is_file():
            pack = json.loads(candidate.read_text(encoding="utf-8"))
            if pack.get("topic_id") == topic_id:
                return pack
    raise HTTPException(404, f"no lesson pack for {topic_id}")


@app.get("/packs/{topic_id}")
def get_pack(topic_id: str) -> dict:
    return _load_pack(topic_id)


@app.get("/packs/{topic_id}/audio/{filename}")
def get_audio(topic_id: str, filename: str) -> FileResponse:
    if not TOPIC_RE.fullmatch(topic_id) or not AUDIO_RE.fullmatch(filename):
        raise HTTPException(400, "invalid path")
    path = content_dir() / "audio" / filename
    if not path.is_file():
        raise HTTPException(404, "audio not found")
    return FileResponse(path, media_type="audio/mpeg")


class TokenRequest(BaseModel):
    room: str = Field(pattern=NAME_RE.pattern)
    participant: str = Field(pattern=NAME_RE.pattern)
    topic_id: str = Field(pattern=TOPIC_RE.pattern)
    lang: str | None = Field(default=None, pattern=r"^(en|yo)$")  # what the TUTOR says; the student speaks English


@app.post("/session/token")
def session_token(req: TokenRequest) -> dict:
    url, key, secret = livekit_creds()
    token = (
        lk.AccessToken(key, secret)
        .with_identity(req.participant)
        .with_name(req.participant)
        .with_metadata(json.dumps({"topic_id": req.topic_id, **({"lang": req.lang} if req.lang else {})}))
        .with_grants(
            lk.VideoGrants(
                room_join=True,
                room=req.room,
                can_publish=True,
                can_subscribe=True,
                can_publish_data=True,
            )
        )
        .to_jwt()
    )
    return {
        "livekit_url": url,
        "token": token,
        "room": req.room,
        # No agent worker exists yet (B2). Flip via env once it is running.
        "agent_ready": os.getenv("SORO_AGENT_READY", "false").lower() == "true",
    }


def streak_from_dates(
    session_dates: list[date], today: date | None = None, timezone_name: str = "Africa/Lagos"
) -> dict:
    """Calculate unique-day streaks in Lagos time; a gap makes current zero."""
    unique_days = sorted(set(session_dates))
    today = today or datetime.now(ZoneInfo(timezone_name)).date()
    last_active = unique_days[-1] if unique_days else None

    longest = run = 0
    previous = None
    for active_day in unique_days:
        run = run + 1 if previous and active_day == previous + timedelta(days=1) else 1
        longest = max(longest, run)
        previous = active_day

    current = 0
    if last_active and 0 <= (today - last_active).days <= 1:
        current = 1
        cursor = last_active
        for active_day in reversed(unique_days[:-1]):
            if active_day == cursor - timedelta(days=1):
                current += 1
                cursor = active_day
            else:
                break
    return {
        "current": current,
        "longest": longest,
        "last_active_date": last_active.isoformat() if last_active else None,
    }


def load_streak(conn: psycopg.Connection, learner_id: str) -> dict:
    row = conn.execute(
        "SELECT current_streak, longest_streak, last_active_date FROM soro_learning_streak(%s)",
        (learner_id,),
    ).fetchone()
    return {
        "current": row["current_streak"],
        "longest": row["longest_streak"],
        "last_active_date": row["last_active_date"].isoformat() if row["last_active_date"] else None,
    }


def load_progress() -> dict:
    """Read the demo learner's activity and assemble the frozen API shape."""
    with _connect() as conn:
        learner = conn.execute(
            "SELECT id, display_name FROM learners WHERE id = 'demo-learner'"
        ).fetchone()
        if not learner:
            raise HTTPException(404, "progress learner not found")
        streak = load_streak(conn, learner["id"])
        rows = conn.execute(
            """SELECT s.id AS session_id,
                      (s.started_at AT TIME ZONE 'Africa/Lagos')::date AS activity_date,
                      s.subject, s.topic, s.lesson,
                      count(st.id) FILTER (WHERE st.completed)::int AS steps_done,
                      COALESCE(uc.result, 'not_taken') AS check_result,
                      COALESCE(uc.attempts, 0) AS attempts
                 FROM sessions s
                 LEFT JOIN steps st ON st.session_id = s.id
                 LEFT JOIN unaided_checks uc ON uc.session_id = s.id
                WHERE s.learner_id = %s
                GROUP BY s.id, s.started_at, s.subject, s.topic, s.lesson, uc.result, uc.attempts
                ORDER BY activity_date DESC, s.started_at DESC""",
            (learner["id"],),
        ).fetchall()
    return assemble_progress(learner, rows, streak=streak)


def assemble_progress(
    learner: dict, rows: list[dict], today: date | None = None, streak: dict | None = None
) -> dict:
    """Build the response shape from learner and session query rows."""
    days_by_date: dict[date, list[dict]] = {}
    topic_totals: dict[tuple[str, str], dict] = {}
    for row in rows:
        day = row["activity_date"]
        check = {"result": row["check_result"], "attempts": row["attempts"]}
        days_by_date.setdefault(day, []).append({
            "session_id": row["session_id"], "subject": row["subject"], "topic": row["topic"],
            "lesson": row["lesson"], "steps_done": row["steps_done"], "unaided_check": check,
        })
        topic_key = (row["subject"], row["topic"])
        totals = topic_totals.setdefault(
            topic_key,
            {
                "subject": row["subject"],
                "topic": row["topic"],
                "attempts": 0,
                "passed": 0,
                "needs_practice": 0,
            },
        )
        totals["attempts"] += row["attempts"]
        if row["check_result"] in ("passed", "needs_practice"):
            totals[row["check_result"]] += 1
    dates = [row["activity_date"] for row in rows]
    return {
        "learner": learner,
        "streak": streak if streak is not None else streak_from_dates(dates, today),
        "days": [
            {"date": day.isoformat(), "sessions": sessions}
            for day, sessions in sorted(days_by_date.items(), reverse=True)
        ],
        "topics": sorted(topic_totals.values(), key=lambda topic: (topic["subject"], topic["topic"])),
    }


@app.get("/progress")
def get_progress() -> dict:
    return load_progress()


# --- recording (B6 follow-up): save a session step and an unaided-check result ---
class CheckResult(BaseModel):
    result: str = Field(pattern=r"^(passed|needs_practice)$")
    attempts: int = Field(ge=0, le=50)


class RecordRequest(BaseModel):
    """Anonymous ids only: never put a student name in learner_id."""
    learner_id: str = Field(default="demo-learner", pattern=NAME_RE.pattern)
    session_id: str = Field(pattern=NAME_RE.pattern)
    subject: str = Field(min_length=1, max_length=64)
    topic: str = Field(min_length=1, max_length=64)
    lesson: str = Field(min_length=1, max_length=120)
    time: datetime | None = None  # when the session started; defaults to now
    step: int | None = Field(default=None, ge=1, le=100)
    completed: bool = True
    check: CheckResult | None = None


def _check_record_key(header_value: str | None) -> None:
    """If SORO_RECORD_KEY is set, writes must send it in X-Soro-Key (stops anonymous spam)."""
    want = os.getenv("SORO_RECORD_KEY", "")
    if want and header_value != want:
        raise HTTPException(401, "missing or wrong X-Soro-Key")


def save_record(conn, req: RecordRequest) -> dict:
    """One transaction: learner, session, step and check are upserted, never duplicated."""
    conn.execute(
        "INSERT INTO learners (id, display_name) VALUES (%s, 'Learner') ON CONFLICT (id) DO NOTHING",
        (req.learner_id,),
    )
    conn.execute(
        "INSERT INTO sessions (id, learner_id, started_at, subject, topic, lesson) "
        "VALUES (%s, %s, COALESCE(%s, now()), %s, %s, %s) ON CONFLICT (id) DO NOTHING",
        (req.session_id, req.learner_id, req.time, req.subject, req.topic, req.lesson),
    )
    owner = conn.execute("SELECT learner_id FROM sessions WHERE id = %s", (req.session_id,)).fetchone()
    if owner["learner_id"] != req.learner_id:  # a session id belongs to one learner
        raise HTTPException(409, "session_id belongs to another learner")
    if req.step is not None:
        conn.execute(
            "INSERT INTO steps (session_id, position, completed) VALUES (%s, %s, %s) "
            "ON CONFLICT (session_id, position) DO UPDATE SET completed = steps.completed OR EXCLUDED.completed",
            (req.session_id, req.step, req.completed),
        )
    if req.check is not None:
        conn.execute(
            "INSERT INTO unaided_checks (session_id, result, attempts) VALUES (%s, %s, %s) "
            "ON CONFLICT (session_id) DO UPDATE SET result = EXCLUDED.result, attempts = EXCLUDED.attempts",
            (req.session_id, req.check.result, req.check.attempts),
        )
    done = conn.execute(
        "SELECT count(*)::int AS n FROM steps WHERE session_id = %s AND completed", (req.session_id,)
    ).fetchone()["n"]
    return {"ok": True, "session_id": req.session_id, "steps_done": done,
            "unaided_check": req.check.model_dump() if req.check else None}


@app.post("/progress/record")
def record_progress(req: RecordRequest, x_soro_key: str | None = Header(default=None)) -> dict:
    _check_record_key(x_soro_key)
    with _connect() as conn:  # commits on success, rolls back on error
        return save_record(conn, req)
