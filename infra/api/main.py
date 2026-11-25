"""Soro M5 API: /health, /packs/{topic_id}, /session/token (contracts/api.json).

Secrets come only from environment variables (infra/.env, gitignored).
"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from livekit import api as lk
from pydantic import BaseModel, Field

import progress

TOPIC_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")
AUDIO_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}\.mp3$")
NAME_RE = re.compile(r"^[A-Za-z0-9_.-]{1,64}$")
MODES = ("nobus", "cloud")

app = FastAPI(title="Soro API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in os.getenv("SORO_CORS_ORIGINS", "*").split(",") if o.strip()],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


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
    if any(m in url.lower() for m in ("your_project", "<", "example.")):
        raise HTTPException(503, f"{prefix}_LIVEKIT_URL is still a placeholder; set the real URL")
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


@app.post("/session/token")
def session_token(req: TokenRequest) -> dict:
    url, key, secret = livekit_creds()
    token = (
        lk.AccessToken(key, secret)
        .with_identity(req.participant)
        .with_name(req.participant)
        .with_metadata(json.dumps({"topic_id": req.topic_id}))
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


@app.get("/progress")
def get_progress(today: str | None = None) -> dict:
    """Seeded demo data for now (B6); persistence in Postgres is not wired yet."""
    from datetime import date
    t = date.fromisoformat(today) if today else date.today()
    return {**progress.summary(progress.seed(t), t), "source": "seeded"}
