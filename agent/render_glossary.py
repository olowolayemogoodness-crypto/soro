"""Pre-render glossary audio: content/audio/<id>.mp3 (one Spitch call per term).

  python render_glossary.py                 # all terms not yet rendered
  python render_glossary.py --only root,vertex
  python render_glossary.py --force         # re-render existing files
Spitch credit is limited (about 700 s): files that exist are skipped, so reruns are free.
These clips use DRAFT Yoruba except gbonbo/ogogo iyipada: have a native speaker check them.
"""
import argparse
import json
import os
import time
from pathlib import Path

from brain import load_env
from tts import TTSError, synth

load_env()
ROOT = Path(__file__).parent.parent / "content"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--lang", choices=("yo", "en"), default="yo", help="en renders <id>_en.mp3 from the English term")
    ap.add_argument("--pack", default=str(ROOT / "lesson-pack.json"))
    a = ap.parse_args()
    pack = json.loads(Path(a.pack).read_text(encoding="utf-8"))
    only = {x for x in a.only.split(",") if x}
    out = ROOT / "audio"
    out.mkdir(exist_ok=True)
    done = chars = 0
    t_all = time.perf_counter()
    for g in pack["glossary"]:
        if only and g["id"] not in only:
            continue
        fname = g["audio"] if a.lang == "yo" else g["audio"].replace(".mp3", "_en.mp3")
        path = out / fname
        if path.exists() and not a.force:
            print(f"skip   {g['id']:20} (exists)")
            continue
        t0 = time.perf_counter()
        try:
            audio = synth(g["yo"]) if a.lang == "yo" else synth(g["en"], voice=os.getenv("SORO_TTS_VOICE_EN", "lucy"), language="en")
        except TTSError as e:
            print(f"FAIL   {g['id']:20} {e}")
            continue
        path.write_bytes(audio)
        done += 1
        chars += len(g["yo"])
        print(f"ok     {g['id']:20} {(g['yo'] if a.lang == 'yo' else g['en'])!r:24} {len(audio):6d} B  {int((time.perf_counter()-t0)*1000):5d} ms")
    print(f"rendered {done} clips, {chars} characters, {time.perf_counter()-t_all:.1f}s total")


if __name__ == "__main__":
    main()
