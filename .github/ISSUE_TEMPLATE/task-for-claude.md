---
name: "Task for Goodness (Module B / Claude Code)"
about: "Assign a bounded Module B task (M3 voice agent, M4 lesson content, or M5 server/infra) for Claude Code to pick up via /next-task."
title: "[M3/M4/M5] "
labels: ["for:goodness"]
assignees: []
---

## Goal
<!-- One short paragraph: what user-facing or checkpoint outcome this task achieves (e.g., CP1 text loop, CP2 Spitch TTS + step-graph walker, CP3 student_action reaction + transfer check). -->

- **Module & Checkpoint:** `M3 Voice Agent | M4 Lesson Content | M5 Server & Infra` · `CP1 (1:00) | CP2 (2:30) | CP3 (3:15)`

## Owned paths
<!-- Exact directories or files Claude Code is allowed to create or edit for this task. -->
- `agent/`
- `content/`
- `infra/`
- `docs/`

## Contracts touched
<!-- Exact frozen JSON contracts in contracts/*.json that this task reads, serves, or emits. Do not modify contracts/*.json without explicit cross-team agreement. -->
- [ ] `contracts/api.json` (`GET /health`, `GET /packs/{topic_id}`, `POST /session/token`)
- [ ] `contracts/lesson-pack.json` (`topic_id`, `glossary[]`, `problems[].steps[]`, `transfer_check`)
- [ ] `contracts/session-events.json` (`caption`, `term_chip`, `tier`, `transfer_check` + `lk.transcription`)
- [ ] `contracts/canvas-cmd.json` (`write_step` with `?` blanks, `set_params`, `highlight`, `draw`, `reset`)
- [ ] `contracts/student-action.json` (`drag`, `draw`, `tap`, `write_math` at `<= 5 Hz`)

## Acceptance checks
<!-- Exact commands Claude Code must run and see pass before opening a PR. Paste real outputs in the PR body. -->
1. [ ] `uv run python -c "import unicodedata, json; ..."` (all Yorùbá strings normalized to Unicode NFC)
2. [ ] `curl -sS http://localhost:8000/health | jq .` returns `{"ok": true, ...}`
3. [ ] `lk agent console` (or `uv run pytest ...`) verifies one question per turn, no leaked answer, and specific misconception correction

## Out of scope
<!-- Explicit boundaries so Claude Code stays focused and preserves Claude Pro context quota. -->
- Do **not** edit `app/` (Module A Flutter shell and canvas bridge) or `contracts/` (frozen schemas).
- Do **not** emit final answers, solved factors `(x − 2)(x − 3)`, or roots `x = 2, 3` from the tutor; on the notebook canvas, write only what the student stated or the structure of the next step with a blank (`?`).
- Do **not** add `CC-BY-NC` or `N-ATLaS` model weights (`SBPN`, `MMS`, `NCAIR1`) to the repository or containers.
- Do **not** commit `.env` files or API keys.
