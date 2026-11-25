# Soro

Soro is an English-first STEM tutor that solves problems with students, out loud, in their own language, launching with Yoruba. Built for the Ogun Digital Summit 2026 hackathon (EdTech track).

Folders: app/ (Flutter web app), agent/ (voice tutor), content/ (lesson packs), infra/ (server), contracts/ (message formats), docs/.

Work is tracked as GitHub issues; see the pinned handoff note.

## Progress API demo

The API applies ordered SQL migrations from `infra/api/migrations/` on startup when `DATABASE_URL` is set. The compose stack wires the API to its Postgres 16 service and the migrations seed an anonymous demo learner with six days of activity, including a gap. Run the stack from `infra/` with `docker compose up --build`; then request `GET http://localhost:8000/progress`. For a local API process, configure `DATABASE_URL` to point at the same Postgres database. The streak uses unique session dates in `Africa/Lagos`; no real learner names are stored.
