"""Tutor brain adapters (D5): Gemini main, Groq-hosted model fallback.

Provider and model come from env (agent/.env, gitignored): SORO_BRAIN_PROVIDER,
SORO_BRAIN_MODEL, SORO_BRAIN_FALLBACK_PROVIDER, SORO_BRAIN_FALLBACK_MODEL.
Keys: GEMINI_API_KEY, GROQ_API_KEY. Never log keys; never send student names.
"""
from __future__ import annotations

import json
import os
import time
from pathlib import Path

import httpx

# Verified against this account on 2026-11-25 (gemini-2.5-flash and llama-3.3 both 404 here).
DEFAULTS = {"gemini": "gemini-3.5-flash", "groq": "openai/gpt-oss-20b"}

PROMPT_BASE = """You are Soro, a warm, sharp STEM co-solving tutor for Nigerian university students. The student always speaks English. {language_rule}

NON-NEGOTIABLE RULES, every turn:
1. Ask EXACTLY ONE focused scaffolding question, at the very end. Never two questions.
2. NEVER give the final answer, the correct factors, the roots or the vertex, and never solve the next step.
3. If the student made a known misconception, correct THAT specific error with one concrete check. No generic praise.
4. You may only mention what the student already said, or the structure of the next step with blanks. Never the answer.
5. 20 to 35 words. Use one everyday analogy only if asked to; drop it if the student says it does not help.
{extra_rule}
You are given a JSON context that already contains the correct pedagogical move (field `planned_reply`). Rephrase it naturally for this student's last message, keeping its meaning and its single final question. Return strict JSON only:
{{"spoken": "<{language_name}, ends with exactly one question>", "caption_en": "<English version, ends with exactly one question>"}}"""

LANGUAGE_RULES = {
    "yo": ("Speak natural, short conversational Yoruba, code-switching English maths terms (quadratic, equation, coefficient, constant, factorise, brackets, roots, parabola, x-axis, vertex).",
           "6. Write Yoruba in Unicode NFC with full tone marks and under-dots.\n", "Yoruba"),
    "en": ("Speak clear, friendly, plain English.", "", "English"),
}


def system_prompt(lang: str = "yo") -> str:
    rule, extra, name = LANGUAGE_RULES.get(lang, LANGUAGE_RULES["yo"])
    return PROMPT_BASE.format(language_rule=rule, extra_rule=extra, language_name=name)


SYSTEM_PROMPT = system_prompt("yo")  # kept for callers that import the old name


def load_env() -> None:
    """Load KEY=VALUE lines from agent/.env then ../.env without overriding the shell."""
    for p in (Path(__file__).parent / ".env", Path(__file__).parent.parent / ".env"):
        if p.is_file():
            for line in p.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, _, v = line.partition("=")
                    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


class BrainError(Exception):
    pass


def _parse_json(text: str) -> dict:
    text = text.strip()
    if text.startswith("```"):
        text = text.strip("`").removeprefix("json").strip()
    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        raise BrainError(f"non-JSON reply: {e}") from e
    if not isinstance(data, dict) or not (data.get("spoken") or data.get("spoken_yo")):
        raise BrainError("reply missing spoken")
    return data


def call_gemini(model: str, system: str, user: str, timeout: float) -> dict:
    key = os.getenv("GEMINI_API_KEY", "")
    if not key:
        raise BrainError("GEMINI_API_KEY not set")
    r = httpx.post(
        f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        headers={"x-goog-api-key": key},
        json={
            "systemInstruction": {"parts": [{"text": system}]},
            "contents": [{"role": "user", "parts": [{"text": user}]}],
            "generationConfig": {"responseMimeType": "application/json", "temperature": 0.4,
                                 "thinkingConfig": ({"thinkingLevel": "minimal"} if model.startswith("gemini-3")
                                                    else {"thinkingBudget": 0})},
        },
        timeout=timeout,
    )
    if r.status_code != 200:
        raise BrainError(f"gemini HTTP {r.status_code}")
    return _parse_json(r.json()["candidates"][0]["content"]["parts"][0]["text"])


def call_groq(model: str, system: str, user: str, timeout: float) -> dict:
    key = os.getenv("GROQ_API_KEY", "")
    if not key:
        raise BrainError("GROQ_API_KEY not set")
    r = httpx.post(
        "https://api.groq.com/openai/v1/chat/completions",
        headers={"Authorization": f"Bearer {key}"},
        json={"model": model, "temperature": 0.4, "response_format": {"type": "json_object"},
              **({"reasoning_effort": "low"} if "gpt-oss" in model else {}),
              "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}]},
        timeout=timeout,
    )
    if r.status_code != 200:
        raise BrainError(f"groq HTTP {r.status_code}")
    return _parse_json(r.json()["choices"][0]["message"]["content"])


ADAPTERS = {"gemini": call_gemini, "groq": call_groq}


class Brain:
    """Primary with automatic failover on timeout, 429, 5xx, bad JSON or missing key."""

    def __init__(self) -> None:
        load_env()
        self.primary = os.getenv("SORO_BRAIN_PROVIDER", "gemini").lower()
        self.fallback = os.getenv("SORO_BRAIN_FALLBACK_PROVIDER", "groq").lower()
        self.models = {
            self.primary: os.getenv("SORO_BRAIN_MODEL", DEFAULTS.get(self.primary, "")),
        }
        self.models.setdefault(self.fallback, os.getenv("SORO_BRAIN_FALLBACK_MODEL", DEFAULTS.get(self.fallback, "")))
        self.timeout = float(os.getenv("SORO_BRAIN_TIMEOUT", "4"))
        for p in (self.primary, self.fallback):
            if p not in ADAPTERS:
                raise BrainError(f"unknown provider {p!r}; use one of {sorted(ADAPTERS)}")

    def respond(self, context: dict) -> tuple[dict, str, int]:
        """Return (reply, provider_used, latency_ms). Raises BrainError if both fail."""
        user = json.dumps(context, ensure_ascii=False)
        errors = []
        for provider in dict.fromkeys((self.primary, self.fallback)):
            t0 = time.perf_counter()
            try:
                data = ADAPTERS[provider](self.models[provider], system_prompt(context.get("tutor_language", "yo")), user, self.timeout)
                return data, provider, int((time.perf_counter() - t0) * 1000)
            except (BrainError, httpx.HTTPError, KeyError, IndexError) as e:
                errors.append(f"{provider}: {type(e).__name__} {e}")
        raise BrainError("; ".join(errors))
