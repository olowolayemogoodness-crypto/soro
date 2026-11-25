# CLAUDE.md — Sọ̀rọ̀ (Soro) Engineering Guide (Module B)

You are working on **Module B** (`agent/`, `content/`, `infra/`) of **Sọ̀rọ̀ (Soro)** on Olowolayemo Goodness Olusore's laptop. Repository: **`https://github.com/olowolayemogoodness-crypto/soro` (PUBLIC)**. Read this file first on every session. For deep architecture, prompt templates, step-graph walker code patterns, fallback ladders, and debugging checklists, read [`docs/engineering-notes.md`](docs/engineering-notes.md).

---

## 1. What Sọ̀rọ̀ Is (Plain Words)

**Sọ̀rọ̀** is a live voice co-solving STEM tutor with an **English-first interface and multilingual support** (**Yorùbá** is the only additional language in scope).
- **The product loop:** The student speaks or selects a STEM problem in Yorùbá mixed with English technical terms → Sọ̀rọ̀ restates the problem and asks **one** scaffolding question → the student works each step out loud and on a shared visual canvas → bilingual term chips appear with tap-to-hear audio → the session concludes with **one unaided transfer-check problem** → results feed a static lecturer dashboard view.
- **Subject-agnostic engine, Quadratics demo:** A topic pack defines its subject, glossary, step graph, and visual plug-in. The hackathon demo pack is **Quadratics (`math101-quadratics`)**, anchored on solving $x^2 - 5x + 6 = 0$.
- **Worked-calculation experience (locked 2026-11-24):** The core of the quadratics session is the **worked calculation on a ruled notebook page**, written step by step in proper maths notation ($x^2$, factorising, $(x - 2)(x - 3) = 0$, $x = 2 \text{ or } x = 3$). The parabola graph sits beside the working as a supporting view to check the roots.

---

## 2. Non-Negotiable Pedagogy Rules

Enforce these four rules in the system prompt, the step-graph walker, and every tool call:

1. **Exactly ONE question per turn:** Every tutor reply must end with one focused scaffolding question—never two stacked questions, never a lecture.
2. **NEVER give the final answer:** Never emit the factors $(x - 2)(x - 3)$, the roots $x = 2, 3$, the vertex coordinates, or solve the next algebraic step for the student.
3. **Correct the SPECIFIC misconception:** When the student makes a known error (e.g., factorising $x^2 - 5x + 6 = 0$ as $(x + 2)(x + 3) = 0$), target that exact sign mismatch (*"If you expand $(x + 2)(x + 3)$, does the middle term give $-5x$ or $+5x$?"*). No generic textbook hints or empty praise.
4. **Notebook writing rule:** When the tutor writes maths onto the shared notebook canvas (`canvas_cmd`), it may **only** write what the student has already stated OR the structure of the next step with a blank (`?`) to fill (e.g., `(x - ?)(x - ?) = 0`) — **never** the answer itself.

---

## 3. Language, Yorùbá NFC & Tone-Mark Rules

- **English-first + Yorùbá code-switching:** Spoken university maths has no single settled Yorùbá register. Keep equations visible on screen; speak natural conversational Yorùbá (2–3 short sentences, ~20–35 words per turn) while naturally code-switching English maths terms (`quadratic`, `equation`, `coefficient`, `constant`, `factorise`, `brackets`, `roots`, `parabola`, `x-axis`, `vertex`) and emitting bilingual `term_chip` events.
- **Strict Unicode NFC:** Every Yorùbá string in JSON, captions, or TTS input must pass `unicodedata.normalize("NFC", text)` with full tone marks (`à` low, `a` mid, `á` high) and sub-dots (`ẹ`, `ọ`, `ṣ`). Note: `yotext` outputs NFD by default—**always wrap `yotext` output in `unicodedata.normalize("NFC", ...)`**.
- **Tone-collision guardrails:** Never send unmarked Yorùbá words that flip meaning to TTS (e.g., `ìlà títẹ̀` = curve vs `tẹ́` = flat; `pín` = divide vs `pin` = end; `ìgun` = angle vs `igún` = vulture). Never reuse rejected audit words (`ìpalu`, `ìlosìwájú`). Override PhET's mistranslated vertex string (`Igún anígunpúpọ̀`) with our verified glossary (`ògógó ìyípadà` / `ojú-àmì ìyípadà`).

---

## 4. Locked Technical Stack (Decisions D1–D11)

| ID | Area | Locked Choice |
|---|---|---|
| **D2** | App platform | Flutter (Android + Web from one codebase; owned by Module A). |
| **D3** | Voice output (TTS) | **Spitch TTS** (`livekit-plugins-spitch` / REST) for novel tutor sentences (`$1` free credit ≈ 700 s; budget carefully) + **pre-recorded audio** (`content/audio/*.mp3`) for every glossary term (`0 ms` cache hit). Fallback: `aspmirlab/YoruTTS-1.5` (Apache-2.0) or pre-recorded step prompts. |
| **D4** | Speech-to-text (STT) | **Groq Whisper API** (`whisper-large-v3` or `whisper-large-v3-turbo`, free tier ~20 RPM / 2K RPD, `language="yo"` + prompt bias for English maths terms). |
| **D5** | Tutor brain (LLM) | Winner of head-to-head test kit (`Gemini Flash` vs `Gemini Pro` vs `Claude`) selectable via `SORO_BRAIN_PROVIDER` / `SORO_BRAIN_MODEL`, with **Gemini Flash** (free tier) as automatic fallback and Groq open models as secondary fallback. |
| **D6** | Tone marks | **`yotext`** live in Python (MIT, ~0.1 ms/sentence after 2 ms load) + `NFC` normalization; all glossary terms hand-checked by a native speaker. |
| **D7** | Media server | **Self-hosted LiveKit SFU on Nobus Cloud (Lagos)** (NDPA 2023 residency + sponsor) with **LiveKit Cloud** wired as a tested one-env-var failover (`LIVEKIT_MODE=nobus\|cloud`). |
| **D8** | Demo visual | Worked calculation on the notebook page + **PhET Graphing Quadratics (`?locale=yo`)** with glossary label overrides (custom parabola graph as backup). |
| **D9** | Offline mode | Only if time allows after Checkpoint 3 (`T+3:15`); otherwise static download screen + stage mention. |
| **D10** | Team ownership | **Captain (Ezechukwu Miracle) = Module A** (`M1` app shell, `M2` canvas bridge, `cap/...` branches). **Friend (Olowolayemo Goodness Olusore) = Module B** (`M3` voice agent, `M4` lesson content, `M5` server & infra, `fr/...` branches). |
| **D11** | Laptop sharing | **GitHub (`https://github.com/olowolayemogoodness-crypto/soro`)**: push `fr/...` and `cap/...` branches and merge via pull requests into `main` at each checkpoint (`0:00` contracts, `1:00` CP1, `2:30` CP2, `3:15` CP3 freeze). USB git bundle only if venue network fails. |

---

## 5. Directory Ownership & Checkpoint Merge Routine

```text
soro/
├── contracts/   # FROZEN JSON schemas (Miracle owns; NEVER edit without explicit agreement)
├── app/         # Module A: Flutter M1 shell + M2 canvas bridge (Miracle owns; NEVER edit)
├── agent/       # Module B (M3): LiveKit Agents Python worker, step-graph walker, STT/LLM/yotext/TTS (YOU OWN)
├── content/     # Module B (M4): lesson-pack.json, glossary audio/*.mp3, system prompts (YOU OWN)
├── infra/       # Module B (M5): docker-compose.yml, FastAPI (/health, /packs, /session/token), Nobus scripts (YOU OWN)
└── docs/        # Engineering notes and runbooks (YOU OWN)
```

- **Hard boundary:** Never modify files in `app/` or `contracts/` unless an issue explicitly authorizes it under **Owned paths**.
- **Checkpoint merge routine (`0:00`, `1:00`, `2:30`, `3:15` on `olowolayemogoodness-crypto/soro`):**
  ```bash
  git push -u origin "fr/<issue-or-module>"
  gh pr create --repo olowolayemogoodness-crypto/soro --base main --head "fr/<issue-or-module>" --title "..." --body "Closes #<n> ..."
  # After PR checks pass & merge to main, sync main and active worktrees:
  git -C ~/work/soro pull --ff-only origin main
  ```

---

## 6. Frozen JSON Contracts (Do Not Drift)

Both laptops build in parallel against these exact wire formats (see [`docs/engineering-notes.md`](docs/engineering-notes.md) for full lifecycle details):

The authoritative shapes are the JSON Schemas in `contracts/*.json` (validated by `contracts/validate.py`, plain-English guide in `contracts/README.md`). Sketch:

```jsonc
// 1. contracts/canvas-cmd.json — Agent → Client (LiveKit data message)
{ "v": 1, "type": "canvas_cmd", "sim": "quadratic-notebook", "visual": "quadratic-graph",
  "op": "write_step", "params": { "line_id": "l1", "step_id": "s1", "author": "tutor",
    "text": "a = ?, b = ?, c = ?", "blanks": ["b1","b2","b3"], "reveal_answer": false } }
// ops: write_step | set_params | highlight {target} | draw {shape} | reset | narrate_state
// write_step ink colour is implied by author: tutor #C31E49, student #1B56D0

// 2. contracts/student-action.json — Client → Agent (<= 5 Hz)
{ "v": 1, "type": "student_action", "actor": "student",
  "action": "drag|draw|tap|write_blank", "target": "angle", "value": 30, "t": 1764060000 }
// write_blank requires "value" (what the student wrote into the blank)

// 3. contracts/session-events.json — Agent → Client (one object per event)
{ "v": 1, "type": "caption", "role": "student|tutor", "text": "…", "lang": "yo|en" }
{ "v": 1, "type": "term_chip", "term_en": "…", "term_yo": "…", "audio_url": "/packs/…/audio/….mp3", "tier": 0 }
{ "v": 1, "type": "tier", "level": 0 }
{ "v": 1, "type": "transfer_check", "problem_id": "quad-tc-01", "assist": false }
{ "v": 1, "type": "board_visibility", "state": "open|tucked" }   // whiteboard tuck-away

// 4. contracts/lesson-pack.json — Served by GET /packs/{topic_id}, stored in content/
{ "topic_id": "math101-quadratics", "subject": "mathematics", "lang": "yo",
  "sim": "quadratic-notebook", "visual": "quadratic-graph",
  "glossary": [{ "id": "root", "yo": "gbòǹgbò", "en": "root of an equation", "audio": "root.mp3" }],
  "problems": [{ "id": "p1", "statement_yo": "…", "steps": [
    { "id": "s1", "prompt_yo": "…", "misconceptions": {"…": "…"}, "hint_ladder": ["…"], "canvas_ops": […] } ] }],
  "transfer_check": { "id": "quad-tc-01", "variant_of": "p1", "statement_yo": "…", "assist": false } }

// 5. contracts/api.json — FastAPI HTTP endpoints (M5, default port 8000)
// GET  /health           -> {"ok": true, "tier": 0, "livekit_mode": "nobus"}
// GET  /packs/{topic_id} -> lesson-pack.json (+ static audio files under /packs/{topic_id}/audio/{file}.mp3)
// POST /session/token    -> req: {"room": "soro-demo", "participant": "student-1", "topic_id": "math101-quadratics"}
//                        -> res: {"livekit_url": "wss://...", "token": "<jwt>", "room": "soro-demo", "agent_ready": true}
// GET  /progress         -> {"streak": {"current": 0, "longest": 0}, "activity": [{"date", "subject", "topic_id", "checks": [{"check_id", "result", "assist"}]}]}
```

---

## 7. Latency Budget (< 3.0 s Target)

Speech-end to first tutor audio **must stay under 3.0 seconds** (target **1.3–2.6 s**):
- **Turn-end detection** (Silero VAD + turn detector): `300–500 ms`
- **STT** (Groq Whisper on 3–6 s utterance): `300–600 ms`
- **LLM first token** (Gemini Flash / winner): `400–800 ms`
- **Tone marks** (`yotext` local CPU + NFC): `< 5 ms` (or server model `100–300 ms`)
- **TTS first audio** (Spitch streaming on first clause / pre-recorded cache hit): `200–400 ms` / `~0 ms`

**Speed rules:** Keep tutor turns under 35 words, split on the first clause boundary (`;`, `.`, `?`) to start TTS early, and serve all glossary terms from pre-recorded `content/audio/*.mp3`.

---

## 8. Licence, Public-Repo Secret Rules & Environment

- **Strict licence gate:** **NEVER** add `CC-BY-NC` or `N-ATLaS` models/weights to the product repo or containers. Specifically banned: `ogunlao/SBPN_multilingual_*` (CC-BY-NC-SA), `facebook/mms-1b-all` and `facebook/mms-tts-yor` (CC-BY-NC), `NCAIR1/Yoruba-ASR` and `NCAIR1/N-ATLaS` (non-commercial, ≤1,000 active users/30 days). Use only clean-licence tools: LiveKit (`Apache-2.0`), Silero VAD (`MIT`), `yotext` (`MIT`), `YoruTTS-1.5` (`Apache-2.0`), and commercial/free-tier APIs (Groq, Gemini, Spitch).
- **PUBLIC REPO SECRET RULE (`https://github.com/olowolayemogoodness-crypto/soro` is PUBLIC):** **NEVER** put API keys, tokens, passwords, or `.env` values in code, commit messages, GitHub issue comments, or PR text. Keep secrets strictly in local `.env` / `agent/.env` / `infra/.env` (gitignored via `.gitignore`); commit only `.env.example` with placeholder key names.
- **Python 3.11 or 3.12 with `uv`:** Always run Python via `uv` (`uv venv --python 3.12`, `uv run ...`). Never use Python 3.9 (`yotext` has an `importlib.resources` bug on 3.9 and `livekit-agents` requires `>=3.11`) or 3.14 (wheel incompatibilities).

---

## 9. Testing, Honest Reporting & Claude Pro Discipline

- **Test M3 & M5 without blocking on Flutter:**
  - Verify M5 API: `curl -sS http://localhost:8000/health | jq .` and `curl -sS http://localhost:8000/packs/math101-quadratics | jq .`
  - Verify M3 voice/text loop: `lk agent console` (or `uv run python -m agent.worker console`) and synthetic `student_action` events.
- **Honest reporting:** Never claim an endpoint or audio loop works without running the check and reporting exact command output (redacting any secrets). If a check fails twice, use `/report` or mark the issue `status:blocked` with the exact error.
- **Claude Pro usage discipline (critical on build day):**
  1. **`ANTHROPIC_API_KEY` must be UNSET** in the terminal running `claude` (`echo "$ANTHROPIC_API_KEY"` must be empty) so Claude Code uses the Pro subscription. If testing Claude as the Soro tutor brain (D5), name that variable `SORO_ANTHROPIC_API_KEY` inside `agent/.env`.
  2. **One session at a time:** Never run parallel Claude Code terminals on Pro.
  3. **Use Sonnet (`/model sonnet`):** Switch to Haiku for trivial JSON linting; **never use Opus**.
  4. **Clear context between tasks:** Run `/clear` after finishing each issue or checkpoint (`CP1`, `CP2`, `CP3`), and `/compact` if a debug session exceeds 10 turns.
  5. **Task queue workflow:** Run `/next-task` to pick up the oldest open unblocked `for:goodness` GitHub issue on `olowolayemogoodness-crypto/soro` in an isolated worktree (`fr/<issue-number>-<slug>`), and `/report` to post concise status updates.

---

## 10. Locked Decisions Since the Kit (GitHub issue #16 — this wins on conflict)

Decisions locked on 2026-11-24 that update the D-table in section 4:

- **Platforms & demo device:** one Flutter web app serves laptop, Android tablet and phones. Demo runs on an **Android tablet with stylus** (pointer events, palm rejection, large tap targets). No native iOS build.
- **STT (supersedes D4):** switch by selected language — Groq Whisper for English, `NCAIR1/Yoruba-ASR` (gated, N-ATLaS licence: non-commercial, attribution) for Yoruba, with Groq as fallback. Two checks gate the Yoruba model: CPU latency on a ~1.5 s budget and accuracy vs Groq on the test clips.
- **Tutor brain (supersedes D5):** DECIDED — **Gemini main** (best Flash/Pro-class free-tier model in AI Studio), **Groq open model fallback**. Never send student names or voices to the brain; demo data only.
- **Worked-calculation rule (locked):** the quadratics session is the worked calculation on a ruled notebook page, not the graph. Tutor ink crimson `#C31E49`, student ink royal blue `#1B56D0`. The tutor writes the structure of the next step with a blank (e.g. `(x - ▢)(x - ▢) = 0`) and never the next answer; the graph is a small supporting view with `?` markers.
- **Analogies are core:** explain abstract ideas with everyday local examples (roots = where a thrown ball meets the ground; friction = a danfo skidding on a wet road). The analogy never gives the answer, one at a time, drop it if the student says it does not help.
- **Chat-first app; whiteboard tucks away:** default screen is chat. When Soro explains or solves, the board opens; after ~10 s with no touch/pen/voice activity (once the tutor finishes speaking) it tucks back into chat. Never collapse while the student is writing or speaking; keep a "Working" card, a pin button, and a configurable delay.
- **My progress & streak:** "My progress" dashboard shows activity by day, subject, topic, and each unaided check result, plus a normal daily streak (one learning step or check counts a day; missing a day resets to zero; encouragement only, never in reports). MVP uses the read endpoint `GET /progress` and seeded data where real scoring is not ready.
