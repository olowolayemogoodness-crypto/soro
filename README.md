# Soro

Soro is an English-first STEM tutor that solves problems with students, out loud, in their own language, launching with Yoruba. Built for the Ogun Digital Summit 2026 hackathon (EdTech track).

Folders: app/ (Flutter web app), agent/ (voice tutor), content/ (lesson packs), infra/ (server), contracts/ (message formats), docs/.

Work is tracked as GitHub issues; see the pinned handoff note.

## Progress API demo

The API applies ordered SQL migrations from `infra/api/migrations/` on startup when `DATABASE_URL` is set. The compose stack wires the API to its Postgres 16 service and the migrations seed an anonymous demo learner with six days of activity, including a gap. Run the stack from `infra/` with `docker compose up --build`; then request `GET http://localhost:8000/progress`. For a local API process, configure `DATABASE_URL` to point at the same Postgres database. The streak uses unique session dates in `Africa/Lagos`; no real learner names are stored.

## Status (25 Nov 2026)

| Part | State |
|---|---|
| Server (`infra/`) | LiveKit v1.13.11, Postgres 16 and FastAPI in Docker. `/health`, `/packs/{id}`, `/session/token` with a `LIVEKIT_MODE=nobus\|cloud` switch. A WebRTC client joined a room with an issued token. |
| Lesson packs (`content/`) | 10 quadratics problems with step graphs, misconception corrections and hint ladders, a transfer check, and a friction pack. `python3 content/validate.py` checks NFC, one question per prompt and no leaked answers. |
| Tutor logic (`agent/`) | Step-graph walker plus a Gemini-main / Groq-fallback brain. The walker picks the move; the brain only rephrases it, and any output that breaks a rule falls back to verified pack text. |
| Voice worker | Draft in PR #21 (VAD, Groq speech-to-text, events on LiveKit topics). **Not run yet; untested.** |
| Voice output (B3) | **Not built.** |
| Yoruba speech-to-text (B7) | **Not built.** The model named in the handoff note is non-commercial; needs a decision. |

### Not verified or not done
- HTTPS (needs a domain), a phone join, Postgres on a block volume.
- Failover through LiveKit Cloud: the switch exists, but no real Cloud project is configured.
- Only `gbòǹgbò` and `ògógó ìyípadà` are verified Yoruba. Every other Yoruba string is a draft: see `content/NATIVE-CHECK.md`.

## Run the pieces
```bash
# lesson packs
python3 content/validate.py
# tutor logic tests (Python 3.11/3.12 with uv)
cd agent && uv run pytest
# text tutor loop (needs GEMINI_API_KEY / GROQ_API_KEY in agent/.env)
cd agent && uv run python console.py
# API tests
cd infra/api && uv run pytest
```
Secrets live only in `.env` files, which are gitignored. Copy `.env.example` and fill it in. Working model names on our accounts: `SORO_BRAIN_MODEL=gemini-3.5-flash`, `SORO_BRAIN_FALLBACK_MODEL=openai/gpt-oss-20b` (the kit's older names return 404).

## Tutor rules (enforced in code, not only in the prompt)
One question per reply; never the final answer; correct the specific misconception; on the notebook the tutor only writes what the student said or a next step with blanks.
