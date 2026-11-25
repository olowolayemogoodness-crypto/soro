# Sọ̀rọ̀ (Soro) — Module B Deep Engineering Notes

This document is the detailed reference behind [`CLAUDE.md`](../CLAUDE.md) for **Module B** (`M3` LiveKit voice tutor agent, `M4` lesson content, `M5` server & infrastructure). Load this file when designing or debugging the agent pipeline, step-graph walker, prompt assembly, TTS cache, failover switches, or build-day checkpoints.

---

## 1. Module B Architecture & Data Flow

Module B runs on **Nobus Cloud (Lagos)** (or locally via Docker Compose during development, with one-switch failover to **LiveKit Cloud** per decision `D7`).

```text
Student Phone (Flutter M1 + M2, owned by Miracle)
  │
  ├─ 1. HTTP GET /packs/math101-quadratics ─────────► M5 FastAPI (infra/)
  ├─ 2. HTTP POST /session/token ───────────────────► M5 FastAPI mints LiveKit JWT + dispatches room
  │
  ├─ 3. WebRTC Opus Audio + Data Channel ───────────► LiveKit SFU (Nobus UDP/TCP or LiveKit Cloud)
  │                                                        │
  │                                                        ▼
  │                                                   M3 Agent Worker (agent/, Python 3.12 + uv)
  │                                                     ├─ Silero VAD + End-of-Turn Detector (300–500 ms)
  │                                                     ├─ STT: Groq Whisper large-v3 / turbo (300–600 ms)
  │                                                     ├─ Step-Graph Walker (deterministic state & misconception match)
  │                                                     ├─ LLM Brain: D5 Winner / Gemini Flash fallback (400–800 ms)
  │                                                     ├─ Diacritics: yotext LexiconRestorer + NFC (< 5 ms)
  │                                                     ├─ TTS Router:
  │                                                     │    ├─ Tier A: Pre-recorded MP3/Opus cache (0 ms)
  │                                                     │    └─ Tier B: Spitch TTS clause stream (200–400 ms)
  │                                                     └─ Publishes:
  │                                                          ├─ Agent audio track (Opus)
  │                                                          ├─ lk.transcription + "caption" JSON events
  │                                                          ├─ "term_chip" JSON events (bilingual + audio_url)
  │                                                          ├─ "canvas_cmd" JSON events (notebook steps + graph params)
  │                                                          └─ "transfer_check" / "tier" JSON events
  │                                                        │
  └────────────────────────────────────────────────────────┴─► Postgres (infra/): session turns & transfer-check log
```

### Why Nobus Lagos + Data Minimisation (NDPA 2023)
- **Nigeria Data Protection Act (NDPA) 2023** applies to Nigerian student data regardless of where it is processed. Hosting the FastAPI server, LiveKit SFU, agent worker, and Postgres database on a **Nobus FCS Ubuntu VM in Lagos** gives a genuine data-residency and hackathon-sponsor story.
- **Data minimisation:** Never send student names, email addresses, or phone numbers to external LLM/STT/TTS APIs. Only anonymous utterance audio goes to Groq Whisper, and only anonymized transcript text + current step-graph context goes to the LLM.

---

## 2. The Step-Graph Walker (`agent/step_graph.py`)

The step graph is Sọ̀rọ̀'s core pedagogical asset. Instead of letting an LLM improvise an entire lesson (which risks leaking answers or drifting off-level), the Python walker tracks the exact problem and step, intercepts known misconceptions deterministically when possible, and constrains what the LLM and canvas can do on each turn.

### 2.1 Lesson Pack Step Schema (`content/lesson-pack.json`)

Each problem in `problems[]` contains an ordered list of `steps[]`:

```json
{
  "id": "s2",
  "title_en": "Find two numbers that multiply to +6 and add to -5",
  "prompt_yo": "Láti factorise equation yìí, àwọn nọ́mbà méjì wo ló lè multiply di plus six, tí wọ́n sì máa add up sí minus five?",
  "prompt_en": "To factorise this equation, which two numbers multiply to +6 and add up to -5?",
  "notebook_template": "(x + ?)(x + ?) = 0",
  "acceptable_concepts": ["-2 and -3", "(x-2)(x-3)", "minus two and minus three"],
  "misconceptions": {
    "+2_and_+3": {
      "triggers": ["+2", "+3", "plus two", "plus three", "(x+2)(x+3)", "(x + 2)(x + 3)"],
      "correction_yo": "Dúró náà, tí o bá expand brackets (x + 2)(x + 3) padà, ṣé middle term rẹ̀ máa fún wa ní minus five x tàbí plus five x?",
      "correction_en": "Hold on—if you expand (x + 2)(x + 3) back out, will its middle term give us -5x or +5x?",
      "canvas_ops": [
        {
          "op": "write_step",
          "params": {
            "line_id": "l2",
            "step_id": "s2_check",
            "text": "(x + 2)(x + 3) = x² + ?x + 6",
            "blanks": ["b1"],
            "author": "tutor",
            "reveal_answer": false
          }
        },
        {
          "op": "highlight",
          "params": { "target": "middle_term" }
        }
      ]
    }
  },
  "hint_ladder": [
    "Rántí pé negative times negative máa ń fún wa ní positive (+6), ṣùgbọ́n tí a bá ro wọ́n pọ̀, àmì negative máa ṣẹ́kù.",
    "Wo -2 àti -3: kí ni (-2) × (-3), kí sì ni (-2) + (-3)?"
  ],
  "on_complete_canvas_ops": [
    {
      "op": "write_step",
      "params": {
        "line_id": "l2",
        "step_id": "s2",
        "text": "(x − 2)(x − 3) = 0",
        "blanks": [],
        "author": "student",
        "reveal_answer": true
      }
    },
    {
      "op": "write_step",
      "params": {
        "line_id": "l3",
        "step_id": "s3_template",
        "text": "x − 2 = 0  tàbí  x − 3 = 0  ⇒  x = ?  tàbí  x = ?",
        "blanks": ["b2", "b3"],
        "author": "tutor",
        "reveal_answer": false
      }
    }
  ],
  "terms_introduced": ["factorise", "coefficient", "constant"]
}
```

### 2.2 Step-Graph State Machine Rules

Maintain a per-session `StepGraphSession` dataclass:

```python
from dataclasses import dataclass, field
from typing import Any

@dataclass
class StepGraphSession:
    topic_id: str
    problem_id: str
    current_step_idx: int = 0
    attempt_count_on_step: int = 0
    completed_step_ids: list[str] = field(default_factory=list)
    transfer_check_active: bool = False
    transfer_check_passed: bool | None = None
    canvas_state: dict[str, Any] = field(default_factory=lambda: {"a": 1, "b": -5, "c": 6})
    emitted_term_ids: set[str] = field(default_factory=set)
```

**Transition logic on every student turn (speech transcript OR `student_action` event):**

1. **Update canvas state first:** If a `student_action` arrived (e.g., `{"action": "drag", "target": "c", "value": 4}` or `{"action": "write_blank", "target": "step_input", "blank_id": "b1", "value": "(x+2)(x+3)=0"}`), update `session.canvas_state` and include it in the current turn context.
2. **Check fast-path misconception triggers:** Before calling the LLM, normalize the student's transcript/written math and check if it matches a deterministic misconception pattern on the current step (such as `+2` and `+3` on $x^2 - 5x + 6 = 0$).
   - If matched, pass `matched_misconception` explicitly into the LLM turn prompt (or emit `correction_yo` directly if latency is tight) and queue the misconception's `canvas_ops` (which highlight the error or write a template with `?`, **never** the corrected factor).
3. **Evaluate step completion via structured LLM decision:** The LLM returns a structured JSON/tool decision:
   - `decision = "advance_step"`: Student stated the current step's concept accurately.
     - Record current step's `on_complete_canvas_ops` (credits the student's solved line in `author: "student"` ink and writes the **next** step's blank template in `author: "tutor"` ink with `reveal_answer: false`).
     - Increment `current_step_idx`, reset `attempt_count_on_step = 0`.
     - Emit `term_chip` events for any new terms in `terms_introduced` not yet in `emitted_term_ids`.
   - `decision = "correct_misconception"`: Student made an error.
     - Increment `attempt_count_on_step += 1`.
     - Emit targeted misconception question + optional blank-check `canvas_cmd`.
   - `decision = "give_hint"`: Student asked for help or is stuck.
     - Select `hint_ladder[min(attempt_count_on_step, len(hint_ladder) - 1)]`, increment `attempt_count_on_step += 1`, and turn the hint into a single scaffolding question.
4. **Enforce the No-Answer Guardrail in Code (`sanitize_canvas_cmd`):**
   - Never allow the LLM to emit a `canvas_cmd` with `author: "tutor"` that contains the next step's solved numbers (`x = 2`, `x = 3`, `(x - 2)(x - 3)`). Only `on_complete_canvas_ops` (triggered *after* the student states the answer) may set `reveal_answer: true` with `author: "student"`.
5. **Transition to Transfer Check:**
   - When the final step of the problem completes, emit:
     `{"v": 1, "type": "transfer_check", "problem_id": "quad-tc-01", "assist": false}`
   - Set `transfer_check_active = True`. During the transfer check, the tutor states the variant problem ($x^2 - 7x + 12 = 0$) and **withholds all hints on the first attempt**. If the student fails the first attempt, the tutor still does not solve it—it asks one guiding question (*"Which two numbers multiply to +12 and add to -7?"*).

---

## 3. Tutor Brain Prompt Structure & Provider Switching (`agent/brain.py`)

### 3.1 System Prompt Template

Keep the base system prompt stable across turns so provider prompt caching hits, and inject the per-turn step-graph state in the user/context message:

```text
You are Sọ̀rọ̀ (Soro), a warm, sharp English- and Yorùbá-speaking STEM co-solving voice tutor for Nigerian university students.
Current topic pack: {topic_title} ({topic_id}).
Current shared canvas: {sim_description} (worked calculation on a ruled notebook page alongside a parabola graph).
Equations stay visible on screen — refer to them naturally instead of reciting long symbol strings.

NON-NEGOTIABLE PEDAGOGY RULES (follow on every turn):
1. Ask EXACTLY ONE focused scaffolding question per turn. Never stack two questions.
2. NEVER give the final answer, the correct factors, the roots, or solve the next step for the student.
3. If the student makes a misconception (such as a sign error when factorising), address THAT SPECIFIC error directly with a concrete check — no generic praise or vague textbook filler.
4. On the notebook page, you may only write what the student has already said OR the structure of the next step with a blank ("?") to fill — never the answer itself.
5. Reply in natural, conversational Yorùbá (2–3 short spoken sentences, 20–35 words max for low-latency voice playback) while code-switching English maths terms naturally (quadratic, equation, coefficient, constant, factorise, brackets, roots, parabola, x-axis, vertex) and pairing them with bilingual term chips.
6. Write all Yorùbá in Unicode NFC with accurate tone marks (à, á) and sub-dots (ẹ, ọ, ṣ).

Return your turn as strict JSON matching this schema:
{
  "decision": "stay_on_step" | "correct_misconception" | "give_hint" | "advance_step" | "start_transfer_check",
  "spoken_yo": "<2-3 short NFC Yorùbá sentences ending with EXACTLY ONE question>",
  "caption_en": "<1-2 sentence English gloss of what you just asked>",
  "notebook_step_template": "<optional next-step math structure with ? blanks, or null>",
  "highlight_target": "<optional canvas target to highlight, or null>",
  "term_ids": ["<optional glossary term id to surface as a TermChip>"]
}
```

### 3.2 Dynamic Turn Context Injection

On each turn, construct a compact JSON context block:

```json
{
  "problem_equation": "x² − 5x + 6 = 0",
  "current_step_id": "s2",
  "current_step_goal_en": "Find two numbers that multiply to +6 and add to -5",
  "acceptable_concepts": ["-2 and -3", "(x-2)(x-3)"],
  "detected_misconception_hint": "Student used +2 and +3; ask what expanding (x+2)(x+3) gives for the middle term (+5x vs -5x).",
  "hint_to_use_if_stuck": "Rántí pé negative times negative máa ń fún wa ní positive (+6)...",
  "attempt_count_on_step": 1,
  "canvas_state": { "a": 1, "b": -5, "c": 6, "last_student_action": "wrote (x+2)(x+3)=0" },
  "student_utterance": "Mo ti rí i! Two times three jẹ́ six, so mo kọ (x + 2)(x + 3) = 0. Ṣé ó tọ́?"
}
```

### 3.3 Provider & Model Failover (`D5`)

Configure the brain via environment variables in `agent/.env` so you can switch models in 5 seconds based on the test-kit results or mid-demo rate limits:

| Env Var | Recommended / Options | Notes |
|---|---|---|
| `SORO_BRAIN_PROVIDER` | `gemini` (default) \| `groq` \| `anthropic` | Controls primary brain adapter. |
| `SORO_BRAIN_MODEL` | `gemini-2.5-flash` (or `gemini-2.5-pro`, `llama-3.3-70b-versatile`, `claude-sonnet-4-5`) | Set to the D5 head-to-head winner. |
| `SORO_BRAIN_FALLBACK_PROVIDER` | `gemini` (with `gemini-2.5-flash`) or `groq` | Automatically invoked if primary times out (`> 2.5 s`) or returns HTTP `429`/`5xx`. |
| `SORO_ANTHROPIC_API_KEY` | Optional API key if Claude wins D5 | **Never name this `ANTHROPIC_API_KEY` in your shell**; keep `ANTHROPIC_API_KEY` unset so Claude Code CLI uses your Claude Pro subscription! |

---

## 4. Tone Marks (`yotext` NFC) & Two-Tier TTS Caching (`agent/tts_cache.py`)

### 4.1 Safe `yotext` Wrapper (Python 3.11/3.12 + NFC + Code-Switch Protection)

1. **Always normalize to NFC:** `yotext` restores tone marks using NFD combining characters. Always normalize with `unicodedata.normalize("NFC", text)` before sending to Spitch TTS or `lk.transcription` captions.
2. **Protect English maths terms and algebraic tokens:** Do not pass raw algebraic expressions (`x² − 5x + 6 = 0`, `(x - 2)(x - 3)`) or English loanwords (`quadratic`, `equation`, `coefficient`, `constant`, `factorise`, `brackets`, `roots`, `parabola`, `x-axis`, `vertex`, `slider`, `minus`, `plus`) through `yotext.restore()`, or it may rewrite short tokens like `a`, `b`, `x`, `so`, `to` into Yorùbá words.

```python
import re
import unicodedata
from yotext import LexiconRestorer

PROTECTED_EN_TOKENS = {
    "quadratic", "equation", "coefficient", "constant", "factorise", "factorisation",
    "factors", "brackets", "expand", "middle", "term", "roots", "root", "solutions",
    "solution", "parabola", "vertex", "discriminant", "formula", "graph", "curve",
    "slider", "screen", "plus", "minus", "times", "equals", "zero", "one", "two",
    "three", "four", "five", "six", "seven", "twelve", "x-axis", "y-axis", "a", "b", "c", "x", "y"
}

_WORD_RE = re.compile(r"\b[a-zA-ZÀ-ÿẹọṣẸỌṢ]+\b")

class SafeYorubaDiacritizer:
    def __init__(self) -> None:
        self._restorer = LexiconRestorer()

    def restore_nfc(self, text: str) -> str:
        # If the string already has rich tone marks (from hand-checked prompts), just NFC-normalize it
        nfc_in = unicodedata.normalize("NFC", text)
        if any(ch in nfc_in for ch in "àáèéìíòóùúẹọṣǹ"):
            return nfc_in

        def _replace_word(match: re.Match[str]) -> str:
            word = match.group(0)
            if word.lower() in PROTECTED_EN_TOKENS:
                return word
            restored = self._restorer.restore(word)
            return unicodedata.normalize("NFC", restored)

        return unicodedata.normalize("NFC", _WORD_RE.sub(_replace_word, nfc_in))
```

### 4.2 Two-Tier TTS Caching Strategy (`D3`)

Spitch TTS costs `$0.0014 / second` (`$1` free credit ≈ `700 seconds` of speech). To make `$1` last through Tuesday tests, Wednesday rehearsals, and the live judges' demo while keeping latency `< 3.0 s`:

1. **Tier A — Pre-recorded Audio Cache (`content/audio/*.mp3` + SHA-256 phrase cache, `0 ms`, `$0`):**
   - Pre-generate all 20–150 glossary terms (`content/audio/<term_id>.mp3`) and the 5 opening step prompts (`Q01`–`Q05`, stored as `content/audio/prompt_<step_id>.mp3`) before the build window.
   - Expose `content/audio/` via FastAPI static files at `/packs/{topic_id}/audio/{filename}` so Flutter's `TermChip` tap-to-hear player loads them directly over HTTP.
   - In the M3 agent, compute a normalized cache key `sha256(unicodedata.normalize("NFC", text.strip().lower()))`. Every time Spitch synthesizes a novel sentence, save the resulting PCM/Opus/MP3 frame buffer to `content/audio/cache/<sha256>.opus` on disk. Rehearsals and repeated misconceptions hit the disk cache in `< 2 ms` at zero Spitch credit cost!
2. **Tier B — Clause-Chunked Live Spitch TTS (`200–400 ms`):**
   - For a novel LLM reply, split `spoken_yo` at the first major pause (`;`, `.`, `—`, or after ~8–12 words).
   - Send Clause 1 to Spitch TTS immediately so the student hears the tutor start speaking within `200–400 ms`, while Clause 2 (the scaffolding question) synthesizes in parallel.

---

## 5. Failure & Fallback Ladder

Build every fallback as an environment variable or runtime toggle so you never rewrite code under stage pressure:

### 5.1 Network & Duplex Degradation Tiers (`tier` session event)
- **Tier 0 (`level: 0` — Full Live):** Full-duplex LiveKit WebRTC voice + Silero VAD barge-in + bidirectional `canvas_cmd` / `student_action` JSON data channel (`~0.3 MB/min`, `~₦3` per 20-min session).
- **Tier 1 (`level: 1` — Voice + Text State):** Drop verbose canvas telemetry; only discrete step updates cross the data channel.
- **Tier 2 (`level: 2` — Push-to-Talk Half-Duplex):**
  - **Trigger:** Noisy hackathon hall causes Silero VAD false triggers, OR mobile hotspot RTT exceeds `3.5 s`.
  - **Switch:** Set `SORO_DUPLEX_MODE=ptt` (or receive `{"type": "client_mode", "mode": "ptt"}` from the app's `VoiceOrb` press-and-hold). Disable automatic VAD turn-end; transcribe only the audio buffer between `ptt_start` and `ptt_end`.
- **Tier 3 (`level: 3` — Pre-Recorded Voice + Live Captions):**
  - **Trigger:** Spitch API unreachable, credit exhausted, or TTS latency `> 3.0 s`.
  - **Switch:** Set `SORO_TTS_MODE=cache_only` (or `yorutts`). The agent plays the pre-recorded step prompt / acknowledgement clip from `content/audio/` and publishes the exact personalized response in the live bilingual caption bar (`lk.transcription` + `caption` event).
- **Tier 4 (`level: 4` — Offline Cached Pack, `D9`):**
  - Only built if Checkpoint 3 (`T+3:15`) passes ahead of schedule; otherwise shown via the app's pack-download screen.

### 5.2 LiveKit Server Failover: Nobus Self-Host → LiveKit Cloud (`D7`)
Self-hosting LiveKit on Nobus is our primary path, but WebRTC UDP ports (`50000–60000/udp`, `7880/tcp`, `7881/tcp`, `3478/udp`) can be blocked by venue firewalls or NAT.

Wire `infra/` and `agent/` to read a single switch in `.env`:

```ini
# Primary: self-hosted LiveKit SFU on Nobus Lagos VM
LIVEKIT_MODE=nobus
NOBUS_LIVEKIT_URL=ws://<nobus-public-ip>:7880
NOBUS_LIVEKIT_API_KEY=devkey
NOBUS_LIVEKIT_API_SECRET=<secret>

# Failover: LiveKit Cloud (free Build tier, pre-tested Tuesday)
CLOUD_LIVEKIT_URL=wss://<your-project>.livekit.cloud
CLOUD_LIVEKIT_API_KEY=<cloud-key>
CLOUD_LIVEKIT_API_SECRET=<cloud-secret>
```

In `infra/main.py` (`POST /session/token`) and `agent/config.py`:
- When `LIVEKIT_MODE=nobus`, use `NOBUS_LIVEKIT_*`.
- When `LIVEKIT_MODE=cloud`, use `CLOUD_LIVEKIT_*`.
- **To fail over on build day:** Change `LIVEKIT_MODE=cloud` in `.env` and restart `FastAPI` + `agent.worker` (`< 15 seconds`). FastAPI and Postgres remain on Nobus Lagos so the sponsor and data-residency story stays intact.

---

## 6. Module B Four-Hour Build Schedule, Checkpoint PR Routine & Cut List (Wed 25 Nov 2026)

Per updated decision **D11**, both laptops sync through **[`https://github.com/olowolayemogoodness-crypto/soro`](https://github.com/olowolayemogoodness-crypto/soro) (PUBLIC repository)** by pushing branches (`fr/...` for Goodness, `cap/...` for Miracle) and merging via Pull Requests into `main` at each checkpoint (`0:00` contracts, `1:00` CP1, `2:30` CP2, `3:15` CP3 freeze). USB git bundles are kept strictly as an emergency fallback if the venue network fails.

Drive Claude Code **sequentially** (one session at a time on **Sonnet**, running `/clear` at every boundary):

| Window | Session & Branch (`fr/...`) | Module B Deliverables (Goodness) | Verification & Checkpoint Merge Gate |
|---|---|---|---|
| **0:00–0:15** | `main` | Clone/pull `https://github.com/olowolayemogoodness-crypto/soro.git` after Miracle merges `T+0:00` frozen `contracts/*.json`; copy kit files and `.env` (from `.env.example`, never committed); run `/next-task`. | `ls contracts/*.json` matches Miracle's `main` branch identically. |
| **0:15–0:45** | **CC Session 1 (Sonnet)**<br>`fr/<n>-m5-infra` + `fr/<n>-m4-content` | **M5:** Stand up Docker Compose (LiveKit SFU + Postgres) + FastAPI (`GET /health`, `GET /packs/{id}`, `POST /session/token` with `LIVEKIT_MODE` switch).<br>**M4:** Validate `content/lesson-pack.json` (NFC check + audio file paths). | `curl -sS http://localhost:8000/health \| jq .`<br>`curl -sS http://localhost:8000/packs/math101-quadratics \| jq .glossary[0]` |
| **0:45–1:15** | `/clear` → **CC Session 2 (Sonnet)**<br>`fr/<n>-m3-text-loop` | **M3 Text Loop:** LiveKit Agents worker joins room, Silero VAD → Groq Whisper STT (`yo`) → Brain (D5 winner / Gemini Flash) → publishes `lk.transcription` & `caption` JSON event. | **CP1 (T+1:00):** `lk agent console` mic → STT → tutor text reply works end to end (`< 2.5 s`). Push `fr/...` & merge PR to `main`. |
| **1:15–2:30** | `/clear` → **CC Session 3 (Sonnet)**<br>`fr/<n>-m3-voice-graph` | **M3 Voice + Step Graph + Canvas:** Wire `SafeYorubaDiacritizer` (`yotext` + NFC), two-tier TTS (pre-recorded `content/audio/*.mp3` + Spitch live), step-graph walker, `term_chip` emission, and `canvas_cmd` emission (`write_step` with `?` blanks + `set_params`). | **CP2 (T+2:30):** Tutor speaks Yorùbá in room, emits `term_chip` and `canvas_cmd`, never leaks the answer. Push `fr/...` & merge PR to `main`. |
| **2:30–3:15** | `/clear` → **CC Session 4 (Sonnet)**<br>`fr/<n>-m3-cosolve-tc` | **Co-Solve & Transfer Check:** Handle incoming `student_action` JSON events (student drags `a, b, c` or writes step → tutor reacts on next turn); wire `transfer_check` variant (`quad-tc-01`, `assist: false`). | **CP3 / FEATURE FREEZE (T+3:15):** Full demo loop runs once from problem statement to transfer check. Push `fr/...` & merge PR to `main`. |
| **3:15–4:00** | Integrated `main` (No new features) | Bugfixes only (`3:15–3:30`). Run **2× full live rehearsals** on mobile hotspot, record backup video on both laptop and phone, verify Spitch remaining credit (`> 150 s`). | **CP4 (T+4:00):** Two clean rehearsals + backup recording saved on laptop & phone. |

### 6.1 Checkpoint Merge Routine (`gh` Commands on `olowolayemogoodness-crypto/soro`)

At `0:00`, `1:00` (CP1), `2:30` (CP2), and `3:15` (CP3 freeze), run this routine to merge your `fr/...` branch into `main` and pull Miracle's merged `cap/...` changes:

```bash
# 1. Verify no .env or secrets are staged (PUBLIC REPO), then push branch:
git -C ../soro-wt/fr-<n>-<slug> status -s
git -C ../soro-wt/fr-<n>-<slug> push -u origin "fr/<n>-<slug>"

# 2. Open Pull Request against main (if /next-task has not already opened it):
gh pr create --repo olowolayemogoodness-crypto/soro --base main --head "fr/<n>-<slug>" \
  --title "cp(module-b): <summary> (#<n>)" \
  --body "Closes #<n> — verified locally with curl /health and lk agent console."

# 3. Merge the PR into main once checks pass:
gh pr merge "fr/<n>-<slug>" --repo olowolayemogoodness-crypto/soro --merge --delete-branch

# 4. Sync local main (picking up Miracle's merged cap/... branches as well):
git -C ~/work/soro checkout main
git -C ~/work/soro pull --ff-only origin main
```

### 6.2 Emergency Offline Fallback: USB Git Bundle Swap

Only if venue Wi-Fi and mobile hotspots fail completely, exchange a single git bundle file on the `SORO_USB` stick:
```bash
git -C ~/work/soro bundle create /Volumes/SORO_USB/soro-cp-fr.bundle main
git -C ~/work/soro bundle verify /Volumes/SORO_USB/soro-cp-fr.bundle
# To pull Miracle's merged bundle from USB:
git -C ~/work/soro fetch /Volumes/SORO_USB/soro-cp-merged.bundle main:refs/remotes/captain/main
git -C ~/work/soro merge --no-ff refs/remotes/captain/main -m "sync merged checkpoint from USB"
```

### 6.3 Binding Cut List for Module B (Cut in Order If Behind)
1. **Behind at T+0:45 or WebRTC ICE blocked on Nobus:** Flip `LIVEKIT_MODE=cloud` immediately. Keep FastAPI + Postgres on Nobus.
2. **Noisy hall false-triggering VAD at CP2:** Switch to Tier-2 Push-to-Talk (`SORO_DUPLEX_MODE=ptt`).
3. **Spitch latency `> 3.0 s` or credit error:** Switch `SORO_TTS_MODE=cache_only` (play pre-recorded glossary + step prompts + live bilingual captions).
4. **Behind at CP3 (`T+2:45`):** Keep transfer check to one hardcoded variant (`quad-tc-01: x² − 7x + 12 = 0`) and skip dynamic Postgres dashboard aggregation (Miracle's M1 has a static lecturer dashboard card ready).

---

## 7. Debugging Checklist (Symptom → Cause → Exact Fix)

| Symptom | Likely Cause | Exact Verification & Fix |
|---|---|---|
| **`yotext` crashes on import with `ImportError` / `importlib.resources` error** | Running with system `/usr/bin/python3` (Python 3.9). | Run `uv run python --version`. Must be `3.11.x` or `3.12.x`. Recreate venv with `uv venv --python 3.12 && uv sync`. |
| **Yorùbá tone marks render as detached boxes or Spitch mispronounces vowels** | String is in Unicode NFD instead of NFC. | Run `python3 -c 'import unicodedata, sys; s=open(sys.argv[1]).read(); print("NFC?", unicodedata.is_normalized("NFC", s))' content/lesson-pack.json`. Pass all strings through `unicodedata.normalize("NFC", text)`. |
| **Groq Whisper transcribes English maths words (`factorise`, `parabola`, `minus five`) as garbled Yorùbá** | Whisper `language="yo"` forces Yorùbá orthography without context. | Pass `prompt="Yorùbá and English maths tutoring: quadratic equation, x squared, minus five x, plus six, coefficient a b c, factorise, brackets, roots, parabola, x-axis, vertex."` in the Groq STT request. |
| **Phone connects to `/session/token` but LiveKit room hangs at `connecting` / ICE failure** | Nobus VM firewall blocking UDP `50000–60000` or venue Wi-Fi blocking UDP. | Wait at most 10 minutes debugging Nobus firewall (`sudo ufw allow 7880,7881/tcp && sudo ufw allow 3478,50000:60000/udp`). If still blocked, set `LIVEKIT_MODE=cloud` in `.env` and restart `/session/token` + agent worker. |
| **Agent joins room (`lk agent console` works) but Flutter app hears no tutor audio** | Agent publishes audio track before participant subscribes, or wrong track source (`MICROPHONE`), or Spitch sample rate mismatch (`24000 Hz` vs `48000 Hz`). | Ensure LiveKit Agent uses `AgentSession` / `VoicePipelineAgent` standard audio output track and resamples TTS PCM to the track's expected sample rate (`24000` or `48000` Hz mono `int16`). Check `lk room list-participants <room>`. |
| **Tutor reply latency exceeds `3.0 s` on mobile data** | Waiting for full 3-sentence LLM completion before starting Spitch TTS. | Stream LLM tokens, split at first punctuation (`;`, `.`, `?`), and dispatch Clause 1 to TTS or play a cached 1-second acknowledgement (`"Ó dára…"` / `"Dúró náà…"`) while Clause 2 synthesizes. |
| **Tutor leaks the final answer `(x - 2)(x - 3)` on the notebook canvas** | LLM emitted `write_step` with solved numbers under `author: "tutor"`. | In `agent/step_graph.py`, strip or reject any LLM-generated `canvas_cmd` where `author == "tutor"` and `text` contains the current step's `acceptable_concepts`; force `notebook_template` (`(x - ?)(x - ?) = 0`) instead. |
| **Claude Code CLI says "Credit balance too low" or bills Console API instead of Claude Pro** | `ANTHROPIC_API_KEY` is exported in your shell environment. | Run `unset ANTHROPIC_API_KEY` in your terminal, remove `export ANTHROPIC_API_KEY=...` from `~/.zshrc` / `~/.bashrc`, and run `claude` → `/status` to confirm `Subscription: Claude Pro`. |
