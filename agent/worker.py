"""Soro LiveKit Agents worker (B2): VAD -> Groq STT -> guarded Tutor -> text events.

Run:   cd agent && uv run python worker.py dev        (joins any room on the active server)
       lk agent console   /  uv run python worker.py console
LIVEKIT_MODE=nobus|cloud picks NOBUS_LIVEKIT_* or CLOUD_LIVEKIT_* (D7 failover).
Voice output is out of scope here (B3): the tutor reply goes out as text events.
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import uuid
from pathlib import Path

from brain import load_env

load_env()
log = logging.getLogger("soro.worker")

PACK = Path(os.getenv("SORO_PACK", Path(__file__).parent.parent / "content" / "lesson-pack.json"))
STT_HINT = ("Quadratic equation, coefficient, constant, factorise, brackets, roots, parabola, "
            "x-axis, vertex, expand, product, sum. x squared minus 5x plus 6 equals 0.")
TOPICS = {"canvas_cmd": "soro.canvas_cmd"}  # everything else goes on soro.session_events


def apply_livekit_mode() -> str:
    """Map the active NOBUS_*/CLOUD_* triple onto the names livekit-agents reads."""
    mode = os.getenv("LIVEKIT_MODE", "nobus").lower()
    if mode not in ("nobus", "cloud"):
        raise SystemExit(f"LIVEKIT_MODE must be nobus or cloud, got {mode!r}")
    prefix = mode.upper()
    for src, dst in (("URL", "LIVEKIT_URL"), ("API_KEY", "LIVEKIT_API_KEY"), ("API_SECRET", "LIVEKIT_API_SECRET")):
        val = os.getenv(f"{prefix}_LIVEKIT_{src}", "")
        if not val:
            raise SystemExit(f"{prefix}_LIVEKIT_{src} is not set")
        os.environ[dst] = val
    return mode


async def publish(room, events: list, spoken: str | None = None) -> None:
    """Send contract events as data messages, plus the tutor text on lk.transcription."""
    lp = room.local_participant
    for e in events:
        topic = TOPICS.get(e["type"], "soro.session_events")
        await lp.publish_data(json.dumps(e, ensure_ascii=False).encode("utf-8"), reliable=True, topic=topic)
    if spoken:
        try:
            await lp.send_text(spoken, topic="lk.transcription",
                               attributes={"lk.segment_id": uuid.uuid4().hex, "lk.transcription_final": "true"})
        except Exception as e:  # captions are best-effort; the data messages above are the contract
            log.warning("lk.transcription send failed: %s", e)


def speak(session, text: str) -> None:
    """Speak a tutor line (Spitch). Interruptible: the student can barge in. Never raises."""
    if session is None or not text:
        return
    try:
        session.say(text, allow_interruptions=True, add_to_chat_ctx=False)
    except Exception as e:  # voice is best-effort; captions and ink are the contract
        log.warning("speech failed: %s", e)


def build_agent(tutor, room):
    from livekit.agents import Agent, StopResponse

    class SoroAgent(Agent):
        def __init__(self) -> None:
            super().__init__(instructions="Soro step-graph tutor. Replies come from the step graph, not the LLM.")

        async def on_user_turn_completed(self, turn_ctx, new_message) -> None:
            text = (new_message.text_content or "").strip()
            if text:
                reply = await asyncio.to_thread(tutor.handle, text)  # blocking HTTP: keep off the loop
                log.info("turn kind=%s provider=%s %dms", reply.kind, reply.provider, reply.latency_ms)
                await publish(room, reply.events, reply.spoken_yo)
                speak(self.session, reply.spoken_yo)
            raise StopResponse()  # suppress the default LLM reply

    return SoroAgent()


async def entrypoint(ctx) -> None:
    from livekit.agents import AgentSession
    from livekit.plugins import groq, silero

    from tutor import Tutor

    await ctx.connect()
    tutor = Tutor(json.loads(PACK.read_text(encoding="utf-8")))
    room = ctx.room
    holder: dict = {"session": None}

    def on_data(pkt) -> None:  # typed or tapped answers: client -> agent (student-action contract)
        if pkt.topic != "soro.student_action":
            return
        try:
            msg = json.loads(pkt.data.decode("utf-8"))
        except ValueError:
            return
        if msg.get("type") == "student_action" and msg.get("action") == "write_math" and msg.get("value"):
            async def go() -> None:
                reply = await asyncio.to_thread(tutor.handle, str(msg["value"]))
                await publish(room, reply.events, reply.spoken_yo)
                speak(holder["session"], reply.spoken_yo)
            asyncio.create_task(go())

    room.on("data_received", on_data)

    tts = None
    if os.getenv("SORO_TTS_MODE", "spitch_with_cache") != "off" and os.getenv("SPITCH_API_KEY"):
        from livekit.plugins import spitch
        tts = spitch.TTS(language="yo", voice=os.getenv("SORO_TTS_VOICE", "sade"))
    session = AgentSession(
        tts=tts,
        stt=groq.STT(model=os.getenv("SORO_STT_MODEL", "whisper-large-v3-turbo"),
                     language=os.getenv("SORO_STT_LANGUAGE") or "en", prompt=STT_HINT),
        vad=silero.VAD.load(),
        turn_detection="vad",
    )
    await session.start(agent=build_agent(tutor, room), room=room)
    holder["session"] = session if tts else None
    opening = tutor.start()
    await publish(room, opening.events, opening.spoken_yo)
    speak(holder["session"], opening.spoken_yo)


if __name__ == "__main__":
    from livekit.agents import WorkerOptions, cli

    logging.basicConfig(level=logging.INFO)
    print(f"LiveKit mode: {apply_livekit_mode()}")
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint))
