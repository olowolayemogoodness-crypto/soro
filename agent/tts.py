"""Spitch text-to-speech client with a disk cache (B3, D3).

Glossary terms are pre-rendered once (render_glossary.py) and served from
content/audio/*.mp3, so a term costs no live call. Novel sentences go through
synth() with a hash-keyed cache. The key comes from SPITCH_API_KEY (never logged).
"""
from __future__ import annotations

import hashlib
import os
import time
import unicodedata
from pathlib import Path

import httpx

URL = "https://api.spitch.app/v1/speech"
VOICE = os.getenv("SORO_TTS_VOICE", "sade")
CACHE = Path(os.getenv("SORO_AUDIO_CACHE_DIR", Path(__file__).parent.parent / "content" / "audio_cache"))


class TTSError(Exception):
    pass


def _clean(text: str) -> str:
    return unicodedata.normalize("NFC", text).strip()  # Yoruba must be NFC before TTS


def synth(text: str, voice: str = VOICE, language: str = "yo", timeout: float = 30, retries: int = 3) -> bytes:
    """One Spitch call. Honours Retry-After on 429; raises TTSError otherwise."""
    key = os.getenv("SPITCH_API_KEY", "")
    if not key:
        raise TTSError("SPITCH_API_KEY not set")
    body = {"text": _clean(text), "language": language, "voice": voice, "format": "mp3"}
    for attempt in range(retries + 1):
        r = httpx.post(URL, headers={"Authorization": f"Bearer {key}"}, json=body, timeout=timeout)
        if r.status_code == 200:
            return r.content
        if r.status_code in (429, 503) and attempt < retries:
            time.sleep(min(float(r.headers.get("retry-after", 2 ** attempt)), 10))
            continue
        raise TTSError(f"spitch HTTP {r.status_code}")
    raise TTSError("spitch: retries exhausted")


def cached(text: str, voice: str = VOICE, language: str = "yo") -> tuple[bytes, bool]:
    """Return (audio, was_cache_hit). Novel text is rendered once and kept."""
    h = hashlib.sha1(f"{voice}|{language}|{_clean(text)}".encode("utf-8")).hexdigest()
    path = CACHE / f"{h}.mp3"
    if path.is_file():
        return path.read_bytes(), True
    audio = synth(text, voice, language)
    CACHE.mkdir(parents=True, exist_ok=True)
    path.write_bytes(audio)
    return audio, False
