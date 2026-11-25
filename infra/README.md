# infra: Soro server (B1)

LiveKit SFU + Postgres + FastAPI in Docker on the Nobus Lagos VM.

## Deploy
1. Copy `infra/` and `content/` to the VM (`/opt/soro/infra`, `/opt/soro/content`).
2. Create `infra/.env` from `.env.example` on the VM (never commit it). Generate the LiveKit key/secret and Postgres password there.
3. `cd /opt/soro/infra && docker compose up -d --build`
4. Check: `curl http://<host>:8000/health` -> `{"ok":true,"tier":0,"livekit_mode":"nobus"}`

Ports to open: 22/tcp (restrict to your IP), 7880/tcp, 7881/tcp, 8000/tcp, 3478/udp, 50000-60000/udp.

## API
- `GET /health`, `GET /packs/{topic_id}` (+ `/packs/{topic_id}/audio/{file}.mp3`), `POST /session/token`.
- `POST /session/token {"room","participant","topic_id"}` returns `{livekit_url, token, room, agent_ready}`.

## Failover to LiveKit Cloud (D7)
Fill `CLOUD_LIVEKIT_URL/API_KEY/API_SECRET` with a real LiveKit Cloud project, set `LIVEKIT_MODE=cloud`, then
`docker compose up -d --force-recreate api`. The API refuses placeholder URLs with a 503 that says so.

## Status
Verified: stack runs, API reachable from outside, a WebRTC client joined a Nobus room with an issued token.
Not done: HTTPS (needs a domain), phone join, Postgres on a block volume, failover through a real LiveKit Cloud project
(no real Cloud project configured yet; the switch itself is unit-tested and the server flips modes).
