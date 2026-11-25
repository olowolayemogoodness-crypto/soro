"""Text console for the tutor loop (no audio, no LiveKit).

  cd agent && uv run python console.py [--no-brain] [--pack ../content/lesson-pack.json]
Type student answers; blank line quits. Set SORO_BRAIN_PROVIDER=gemini|groq to switch brain.
"""
import argparse
import json
from pathlib import Path

from tutor import Tutor


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack", default=str(Path(__file__).parent.parent / "content" / "lesson-pack.json"))
    ap.add_argument("--no-brain", action="store_true", help="use verified pack text only")
    args = ap.parse_args()
    pack = json.loads(Path(args.pack).read_text(encoding="utf-8"))
    t = Tutor(pack, use_brain=not args.no_brain)
    r = t.start()
    print(f"\nTUTOR [{r.provider}]: {r.spoken_yo}\n       ({r.caption_en})")
    while True:
        try:
            said = input("\nSTUDENT> ").strip()
        except EOFError:
            break
        if not said:
            break
        r = t.handle(said)
        print(f"\nTUTOR [{r.kind} via {r.provider} {r.latency_ms}ms]: {r.spoken_yo}\n       ({r.caption_en})")
        for e in r.events:
            if e["type"] in ("canvas_cmd", "term_chip", "transfer_check"):
                print("   event:", json.dumps(e, ensure_ascii=False)[:150])


if __name__ == "__main__":
    main()
