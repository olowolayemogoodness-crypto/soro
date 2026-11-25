"""Tutor: step-graph walker + brain, wrapped in hard guards.

The walker decides WHAT to say (from the lesson pack). The brain only rephrases it
naturally. Every brain output is validated; on any failure the walker's own text is
used, so the pedagogy rules hold even if the LLM misbehaves.
"""
from __future__ import annotations

import unicodedata
from dataclasses import dataclass, field
from typing import Optional

from brain import Brain, BrainError
from step_graph import Turn, Walker

NFC = lambda s: unicodedata.normalize("NFC", s)
MAX_WORDS = 45  # voice budget; pack text is the fallback


@dataclass
class Reply:
    spoken_yo: str
    caption_en: str
    events: list = field(default_factory=list)  # session-events / canvas_cmd messages, in send order
    provider: str = "pack"  # which brain wrote it ("pack" = deterministic fallback)
    latency_ms: int = 0
    kind: str = ""


def one_question(t: str) -> bool:
    return t.count("?") == 1 and t.rstrip().endswith("?")


class Tutor:
    def __init__(self, pack: dict, problem_id: str = "p1", brain: Optional[Brain] = None, use_brain: bool = True):
        self.pack = pack
        self.walker = Walker(pack, problem_id)
        self.brain = brain if brain is not None else (Brain() if use_brain else None)
        self.glossary = {g["id"]: g for g in pack["glossary"]}
        self.last_student = ""

    def _events(self, turn: Turn, spoken: str, caption: str, student_text: str = "") -> list:
        ev = []
        if student_text:
            ev.append({"v": 1, "type": "caption", "role": "student", "text": student_text, "lang": "en"})
        ev += turn.canvas_ops
        ev.append({"v": 1, "type": "caption", "role": "tutor", "text": spoken, "lang": "yo"})
        for tid in turn.term_ids:
            g = self.glossary.get(tid)
            if g:
                ev.append({"v": 1, "type": "term_chip", "term_yo": g["yo"], "term_en": g["en"],
                           "audio_url": f"/packs/{self.pack['topic_id']}/audio/{g['audio']}"})
        if turn.transfer_check:
            ev.append(turn.transfer_check)
        return ev

    def _rephrase(self, turn: Turn, utterance: str) -> tuple[str, str, str, int]:
        """Brain rephrase with validation; returns (yo, en, provider, ms)."""
        if not self.brain:
            return turn.text_yo, turn.text_en, "pack", 0
        ctx = {  # no names, no ids: only the problem state and the student's words
            "problem_equation": self.walker.problem["equation"],
            "step_id": turn.step_id,
            "move": turn.kind,
            "planned_reply_yo": turn.text_yo,
            "planned_reply_en": turn.text_en,
            "student_utterance": utterance,
        }
        try:
            data, provider, ms = self.brain.respond(ctx)
        except BrainError:
            return turn.text_yo, turn.text_en, "pack", 0
        yo = NFC(str(data.get("spoken_yo", "")).strip())
        en = str(data.get("caption_en", "")).strip() or turn.text_en
        bad = (not one_question(yo) or len(yo.split()) > MAX_WORDS
               or self.walker._leaks(yo) or self.walker._leaks(en) or not one_question(en))
        if bad:  # guard tripped: keep the verified pack text
            return turn.text_yo, turn.text_en, "pack", ms
        return yo, en, provider, ms

    def start(self) -> Reply:
        turn = self.walker.open()
        yo, en, prov, ms = turn.text_yo, turn.text_en, "pack", 0  # opening line is verified pack text
        return Reply(yo, en, [{"v": 1, "type": "tier", "level": 0}] + self._events(turn, yo, en), prov, ms, turn.kind)

    def handle(self, utterance: str) -> Reply:
        turn = self.walker.submit(utterance)
        yo, en, prov, ms = self._rephrase(turn, utterance)
        # a transfer-check turn keeps the exact pack text: the statement must not be reworded
        if turn.kind == "transfer":
            yo, en = turn.text_yo, turn.text_en
        events = self._events(turn, yo, en, student_text=utterance)
        if turn.needs_analogy:
            a = self.walker.analogy("friction" if self.pack["subject"] == "physics" else "root")
            if a:
                yo, en = a.text_yo, a.text_en
                events.append({"v": 1, "type": "caption", "role": "tutor", "text": yo, "lang": "yo"})
        return Reply(yo, en, events, prov, ms, turn.kind)
