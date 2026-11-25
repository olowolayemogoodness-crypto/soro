# Soro architecture

This page goes deeper than the [README](../README.md). Status words match the README: **Built**, **Partly built**, **Planned**.

## 1. Who talks to whom

```mermaid
flowchart TB
  subgraph Device["Student device: Flutter web app"]
    CHAT["Home chat"]
    BOARD["Notebook board and graph"]
    DOCK["Voice dock"]
    PROG["My progress"]
  end

  subgraph Nobus["Nobus Cloud instance, Lagos (Docker compose)"]
    LK["LiveKit server"]
    API["FastAPI"]
    PG[("Postgres 16")]
    PK[["content/ lesson packs, read-only"]]
    AG["Tutor agent (Python)"]
  end

  GROQ["Groq: Whisper speech to text, fallback brain"]
  GEM["Gemini: main brain"]
  SP["Spitch voice"]
  GL[["Recorded glossary audio"]]
  YT["yotext, in-process"]
  LC["LiveKit Cloud"]

  CHAT --> API
  PROG --> API
  BOARD --> API
  DOCK <--> LK
  API --> PG
  API --> PK
  LK <--> AG
  AG --> PK
  AG --> GROQ
  AG --> GEM
  AG --> SP
  AG --> GL
  AG --> YT
  DOCK -. failover .-> LC
  AG -. failover .-> LC
```

What is real today: the app screens (home, progress, graph and friction), the API with `/health`, `/packs/{id}`, `/session/token`, `/progress`, Postgres, the lesson packs, and the step walker. The voice dock and board session are in open PR #29. The agent's voice worker and brain switch are drafts. Spitch voice, yotext wiring and the real Cloud failover are not done.

## 2. The API

| Route | Purpose |
|---|---|
| `GET /health` | Is the server up. |
| `POST /session/token` | Issues a LiveKit token. `LIVEKIT_MODE=nobus` or `cloud` picks which server the token is for. |
| `GET /packs/{topic_id}` | Returns a lesson pack from `content/`. |
| `GET /packs/{topic_id}/audio/{filename}` | Serves recorded glossary audio. |
| `GET /progress` | Activity by day, unaided check results and the streak. |

Migrations in `infra/api/migrations/` run on startup when `DATABASE_URL` is set. The streak counts unique session dates in `Africa/Lagos`.

## 3. One spoken turn in detail

```mermaid
sequenceDiagram
  participant S as Student
  participant A as App
  participant G as Agent
  participant T as Speech to text
  participant W as Step walker
  participant B as Brain
  participant V as Voice
  S->>A: speaks
  A->>G: audio over LiveKit
  G->>T: audio
  T-->>G: transcript
  G->>A: transcript as a caption, so a wrong word can be fixed
  G->>W: transcript
  W-->>G: move: question, hint or misconception correction, with board ink
  G->>B: rephrase this move
  B-->>G: wording
  G->>G: guards: one question, no leaked answer
  alt a guard fails
    G->>G: use the verified pack text instead
  end
  G->>G: add tone marks, normalise to NFC
  G->>V: speak
  V-->>G: audio
  G-->>A: voice, caption, board command
```

### Latency budget (target, not measured)

| Stage | Aim |
|---|---|
| Speech to text | about 0.7 s |
| Step walker | a few ms (plain code) |
| Brain, first words | about 0.8 s |
| Guards and tone marks | well under 0.1 s (yotext restore took about 0.1 ms per sentence in our research) |
| Voice, first audio | about 0.8 s |
| Network | the rest |
| **Total** | **under about 3 s** |

Spitch is expected to limit concurrent calls on one account, so glossary audio is pre-rendered ahead of time and used as the live fallback.

## 4. The step graph

Every lesson pack follows the same shape:

```text
pack -> problems[] -> steps[]
step -> prompt, acceptable answers, misconception map (wrong answer -> targeted correction),
        hint ladder, board ink
pack -> glossary (English and Yoruba terms), transfer_check (one fresh problem, no help)
```

Why this design: the tutor is consistent, a teacher can read and audit it, and a small free model is enough, because the model never decides the move.

## 5. Failover

Both the app token and the agent connection are chosen by `LIVEKIT_MODE`. If the Nobus server is down, switching to `cloud` points both at LiveKit Cloud. **The switch exists; no real Cloud project is configured, so it has not been tested for real.**

## 6. Where each part lives

| Part | Folder |
|---|---|
| App | [`app/`](../app/) |
| Tutor logic | [`agent/`](../agent/) |
| Lesson packs and validator | [`content/`](../content/) |
| Server stack | [`infra/`](../infra/) |
| Message formats | [`contracts/`](../contracts/) (freeze in open PR #28) |
| Screenshots | [`docs/screenshots/`](screenshots/) |
