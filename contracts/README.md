# Soro contracts (frozen v1)

These five files are the **frozen message contracts** between the two builders
(Module A app in `app/`, Module B tutor in `agent/`/`infra/`). Both sides code
against them in parallel — **do not change them without agreement** (see
`CLAUDE.md` §5). They were frozen at checkpoint 0:00 on build day.

Each contract is a **JSON Schema** (Draft 2020-12) named `<name>.json`, plus a
mock fixture `<name>.example.json` showing real messages. If an example file
contains a JSON array, every element must validate against the schema.

Wire formats: `canvas-cmd`, `student-action`, and `session-events` travel as
**LiveKit data messages** (one JSON object per message, `v: 1`). `lesson-pack`
is the document served by `GET /packs/{topic_id}` and stored in `content/`.
`api` describes the four HTTP endpoints of the FastAPI server.

## The five contracts in plain English

### `canvas-cmd.json` — tutor → app (canvas commands)
The agent tells the app what to draw on the shared board. Envelope:
`{v, type:"canvas_cmd", sim, op, params}` (+ optional `visual`).

- `set_params` — push simulation parameters (e.g. incline angle, or quadratic
  coefficients `a, b, c`).
- `highlight` — point at an element (`params.target`, e.g. `weight_vector`).
- `draw` — free annotation (`params.shape`: arrow/circle/underline/line/text).
- `reset` — clear the board.
- `narrate_state` — ask the app to voice/describe current board state.
- `write_step` — **the worked-calculation notebook op.** Params:
  `line_id`, `author` (`tutor` or `student`), `text` (maths notation such as
  `(x - ▢)(x - ▢) = 0`), `blanks` (array of blank ids the student must fill),
  optional `step_id` and `reveal_answer` (must stay `false` for tutor ink —
  the tutor writes structure with blanks, never the answer). Ink colour is
  implied by `author`: tutor crimson `#C31E49`, student royal blue `#1B56D0`.

### `student-action.json` — app → tutor (what the student did)
Envelope: `{v, type:"student_action", actor:"student", action, t}` where `t`
is Unix epoch seconds. Throttle to ≤ 5 Hz.

- `drag` — moved a control (`target`, `value`).
- `draw` — stylus stroke (`points`: array of `{x, y}`).
- `tap` — tapped something (`target`, e.g. a term chip).
- `write_blank` — filled a notebook blank; **requires `value`** (what the
  student wrote). `blank_id`/`line_id` locate it.

### `session-events.json` — tutor → app (live session feed)
Five event types, one object each:

- `caption` — a transcript line; `role` student|tutor, `text`, `lang` `en`|`yo`
  (Yoruba is NFC-normalised with tone marks).
- `term_chip` — bilingual vocabulary chip: `term_en`, `term_yo`, `audio_url`
  (pre-recorded glossary audio), optional `tier`.
- `tier` — current scaffolding level (`level` integer).
- `transfer_check` — the unaided end-of-topic check started/finished;
  `problem_id`, `assist` (true if help was given).
- `board_visibility` — the chat-first whiteboard opened (`open`) or tucked
  back into the chat after ~10 s idle (`tucked`).

### `lesson-pack.json` — one teachable topic
Served by `GET /packs/{topic_id}`, authored in `content/`. Required top-level
keys: `topic_id`, `subject`, `lang` (`en`|`yo`), `sim`, `visual`, `glossary`,
`problems`, `transfer_check`.

- `glossary[]` — `{id, yo, en, audio}` bilingual terms with pre-rendered audio.
- `problems[]` — each has `steps[]`; every step carries `prompt_yo` (one
  scaffolding question), `misconceptions` (map of wrong answer → corrective
  prompt, either a plain string or a rich `{triggers, correction_yo,
  correction_en, canvas_ops}` object) and `hint_ladder` (ordered hints, never
  the final answer), plus optional `canvas_ops` the tutor may emit.
- `transfer_check` — `{id, variant_of, statement_yo, assist:false}`: one
  unaided variant problem that measures transfer.

### `api.json` — the HTTP surface (M5, port 8000)

- `GET /health` → `{ok: true, tier, livekit_mode?}` liveness/fallback tier.
- `GET /packs/{topic_id}` → a full `lesson-pack` document (+ audio assets).
- `POST /session/token` — request `{room, participant, topic_id}` → response
  `{livekit_url, token, room, agent_ready}`. Tokens are secrets: never commit
  real ones.
- `GET /progress` → the "My progress" record: `streak {current, longest}`
  (consecutive days with ≥1 learning step or check; a missed day resets to
  0) and `activity[]` rows of `{date, subject, topic_id, steps_completed,
  checks[{check_id, result: pass|partial|fail, assist}]}`.

## Checking the contracts

```bash
python3.11 contracts/validate.py   # or: python3 contracts/validate.py on 3.11+
```

Requires Python ≥ 3.11 and the `jsonschema` package (`pip install jsonschema`).
The script validates every `*.example.json` against its sibling schema and
prints one line per check; exit code 0 means all pass.
