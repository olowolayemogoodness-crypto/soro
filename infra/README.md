# infra

## POST /tutor/turn (issue #39)

Text turn of the tutor brain for the app. Always HTTP 200 with a valid body. Optional `X-Soro-Key` (same `SORO_RECORD_KEY` as `/progress/record`). CORS follows `SORO_CORS_ORIGINS`.

```
curl -X POST http://<vm>:8000/tutor/turn -H 'content-type: application/json' \
  -d '{"session_id":"s1","lang":"en","mode":"guide","problem":"x^2 - 5x + 6 = 0","text":"Help me solve this"}'
# {"session_id":"s1","step_id":"s1","say":"What are the values of coefficient a, b, and constant c?","board":[{"op":"write","text":"x² − 5x + 6 = 0"},{"op":"blank","text":"a = [ ], b = [ ], c = [ ]"}],"done":false,"source":"script"}

curl -X POST http://<vm>:8000/tutor/turn -H 'content-type: application/json' \
  -d '{"session_id":"s2","lang":"en","mode":"solve","problem":"x^2 - 5x + 6 = 0","text":"solve this"}'
# board: full worked write ops, then the try-it problem; plus additive "steps":[{"say","board"}] with a say per step
```

Modes: pack (typed problem or topic matches quadratics or friction), solve (`mode":"solve"`), general (no pack match: one Gemini call, Groq fallback, 6 s budget, validated plan; otherwise an honest "quadratics and friction for now" reply, `source":"script"`).
Optional audio: with `SPITCH_API_KEY` set, `audio_url` and `audio_ms` are added (and per step), served from `GET /tutor/audio/<hash>.mp3`. Env: `GEMINI_API_KEY`, `GROQ_API_KEY`, `SORO_AGENT_DIR`, `SORO_TUTOR_AUDIO_DIR`.
