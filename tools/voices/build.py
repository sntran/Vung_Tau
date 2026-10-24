#!/usr/bin/env python3
"""Makes the voice audio files of the game with VieNeu-TTS (plan 0003, R5 to R9).

Usage:
  python tools/voices/build.py                 Make the missing and the changed files.
  python tools/voices/build.py --check         Only check that each clip has a correct file.
  python tools/voices/build.py --audition DIR  Also make the audition page in DIR (R9).

The script writes one Ogg Vorbis file (mono, 48 kHz) for each clip in
assets/voices/, and assets/voices/manifest.json. A clip is a spoken line of a
person, a phrase of the phrasebook (the neutral phone voice), or the "say
again" phrase for each person. A file is made again only when its hash
changes: the hash is from the text that the voice reads, the voice, and the
model version. The game checks the same hash (autoload/content.gd).
"""

import argparse
import hashlib
import html
import json
import shutil
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIALOGUE = ROOT / "data" / "dialogue"
VOICES = ROOT / "data" / "voices.json"
OUT = ROOT / "assets" / "voices"
SAMPLE_RATE = 48000
LOUDNESS_LUFS = -16.0
PEAK_LIMIT = 0.98
LIMIT_WINDOW_S = 0.005
# Silence at the start and the end: the level is below SILENCE_DB for longer
# than this. A small part stays, so that the speech does not start sharply.
SILENCE_DB = -45.0
KEEP_SILENCE_S = 0.05
FRAME_S = 0.01
# The audition (R9): each voice reads these lines of the game.
AUDITION_LINES = ["batu.greet", "cosau.open", "cosau.sold_out", "nga.hello", "coc.talk.1"]
AUDITION_REGIONS = {"Nam": "Southern", "Trung": "Central", "Bắc": "Northern"}


def log(text: str) -> None:
    print(f"[voices] {text}", flush=True)


def load_json(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def model_version(voices: dict) -> str:
    return f"{voices['model']} {voices['package']}"


def clip_hash(text: str, voice: str, model: str) -> str:
    """The same hash as Content.voice_hash() in the game."""
    return hashlib.sha256(f"{text}\n{voice}\n{model}".encode("utf-8")).hexdigest()


def spoken_text(line: dict) -> str:
    """The text that the voice reads: the style tag, then "say" or "vi"."""
    text = line.get("say", line["vi"])
    style = line.get("voice_style", "")
    return f"{style} {text}" if style else text


def collect_clips(dialogue: dict, voices: dict) -> list[dict]:
    """All clips of one dialogue file. Each clip has an ID, the text, and the voice."""
    clips = []
    speakers = dialogue["speakers"]
    for line_id, line in dialogue["lines"].items():
        if "speaker" not in line:
            continue
        clips.append({"id": line_id, "text": spoken_text(line), "voice": voices["speakers"][line["speaker"]]})
        for reply in line.get("replies", []):
            if not reply.get("english", False):
                clips.append({"id": f"reply.{line_id}.{reply['id']}", "text": reply["vi"], "voice": voices["phone"]})
    template = dialogue["say_again"]["vi"]
    for speaker_id, speaker in speakers.items():
        clips.append({"id": f"say_again.{speaker_id}", "text": template.replace("{address}", speaker["address"]),
                      "voice": voices["phone"]})
    return clips


def all_clips(voices: dict) -> list[dict]:
    clips = []
    for path in sorted(DIALOGUE.glob("*.json")):
        clips += collect_clips(load_json(path), voices)
    return clips


def trim_silence(wav):
    import numpy as np
    frame = int(SAMPLE_RATE * FRAME_S)
    if len(wav) < frame * 3:
        return wav
    frames = len(wav) // frame
    rms = np.sqrt(np.mean(wav[:frames * frame].reshape(frames, frame) ** 2, axis=1) + 1e-12)
    loud = np.nonzero(20 * np.log10(rms) > SILENCE_DB)[0]
    if len(loud) == 0:
        return wav
    keep = int(SAMPLE_RATE * KEEP_SILENCE_S)
    start = max(0, loud[0] * frame - keep)
    end = min(len(wav), (loud[-1] + 1) * frame + keep)
    return wav[start:end]


def limit(wav):
    """A peak limiter: the gain goes down for some milliseconds around each peak above PEAK_LIMIT."""
    import numpy as np
    from scipy import ndimage
    gain = np.minimum(1.0, PEAK_LIMIT / (np.abs(wav) + 1e-9))
    window = int(LIMIT_WINDOW_S * SAMPLE_RATE)
    # The minimum over 2 windows, then the mean over 1 window: the gain at a
    # peak stays at or below the gain that the peak needs.
    gain = ndimage.minimum_filter1d(gain, 2 * window + 1)
    gain = ndimage.uniform_filter1d(gain, window)
    return wav * gain


def normalize(wav):
    """Sets the loudness to LOUDNESS_LUFS (R8). The limiter keeps the peaks below PEAK_LIMIT."""
    import numpy as np
    import pyloudnorm
    meter = pyloudnorm.Meter(SAMPLE_RATE)
    wav = wav.astype(np.float64)
    for _ in range(4):
        loudness = meter.integrated_loudness(wav)
        if not np.isfinite(loudness):
            break
        wav = limit(wav * (10.0 ** ((LOUDNESS_LUFS - loudness) / 20.0)))
    return np.clip(wav, -1.0, 1.0).astype(np.float32)


def make_audio(tts, text: str, voice: str, seed: str):
    import numpy as np
    np.random.seed(int(seed[:8], 16))
    wav = tts.infer(text, voice=voice)
    return normalize(trim_silence(np.asarray(wav, dtype=np.float32)))


def load_tts():
    from vieneu import Vieneu
    started = time.time()
    tts = Vieneu(mode="v3turbo", backend="onnx", precision="fp32")
    log(f"VieNeu-TTS loaded in {time.time() - started:.0f} s")
    return tts


def model_revision() -> str:
    try:
        from huggingface_hub import model_info
        return model_info("pnnbao-ump/VieNeu-TTS-v3-Turbo").sha or ""
    except Exception as error:  # noqa: BLE001 - the revision is only for the record
        return f"unknown ({error})"


def build(check_only: bool) -> int:
    import soundfile
    voices = load_json(VOICES)
    model = model_version(voices)
    clips = all_clips(voices)
    manifest_path = OUT / "manifest.json"
    old = load_json(manifest_path)["clips"] if manifest_path.exists() else {}
    todo = []
    for clip in clips:
        clip["hash"] = clip_hash(clip["text"], clip["voice"], model)
        entry = old.get(clip["id"])
        if entry is None or entry["hash"] != clip["hash"] or not (OUT / entry["file"]).exists():
            todo.append(clip)
    log(f"{len(clips)} clips, {len(todo)} to make")
    if check_only:
        for clip in todo:
            log(f"missing or changed: {clip['id']}")
        return 1 if todo else 0
    OUT.mkdir(parents=True, exist_ok=True)
    tts = load_tts() if todo else None
    entries = {}
    for clip in clips:
        file = f"{clip['id']}.ogg"
        if clip in todo:
            started = time.time()
            wav = make_audio(tts, clip["text"], clip["voice"], clip["hash"])
            soundfile.write(OUT / file, wav, SAMPLE_RATE, format="OGG", subtype="VORBIS")
            duration = len(wav) / SAMPLE_RATE
            log(f"{clip['id']}: {duration:.2f} s audio in {time.time() - started:.1f} s")
        else:
            duration = old[clip["id"]]["duration_s"]
        entries[clip["id"]] = {"file": file, "duration_s": round(duration, 3), "hash": clip["hash"],
                               "voice": clip["voice"], "text": clip["text"]}
    for path in OUT.glob("*.ogg"):
        if path.stem not in entries:
            path.unlink()
            Path(str(path) + ".import").unlink(missing_ok=True)
            log(f"removed {path.name}")
    manifest = {
        "note": "Made by tools/voices/build.py. Do not change by hand.",
        "model": model,
        "model_revision": model_revision() if todo else load_json(manifest_path).get("model_revision", ""),
        "sample_rate": SAMPLE_RATE,
        "loudness_lufs": LOUDNESS_LUFS,
        "clips": dict(sorted(entries.items())),
    }
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent="\t")
        f.write("\n")
    return 0


def audition(folder: Path) -> None:
    """A web page where each Southern, Central, and Northern preset voice reads the same five lines (R9)."""
    import soundfile
    import vieneu
    from vieneu.v3turbo import sorted_voices
    tts = load_tts()
    dialogue = load_json(DIALOGUE / "hem.json")
    voices = load_json(VOICES)
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    # The region of each voice is only in the voice file of the package.
    presets = sorted_voices(load_json(Path(vieneu.__file__).parent / "assets" / "voices_v3_turbo.json")["presets"])
    rows = {region: [] for region in AUDITION_REGIONS}
    for name, info in presets:
        region = info.get("region", "")
        if region not in rows:
            continue
        files = []
        for k, line_id in enumerate(AUDITION_LINES):
            line = dialogue["lines"][line_id]
            text = spoken_text(line)
            wav = make_audio(tts, text, name, clip_hash(text, name, model_version(voices)))
            file = f"{len(rows[region]) + 1:02d}_{region}_{k + 1}.mp3"
            soundfile.write(folder / file, wav, SAMPLE_RATE, format="MP3", subtype="MPEG_LAYER_III")
            files.append((file, line["vi"]))
        rows[region].append((name, info, files))
        log(f"audition: {name}")
    used = {v: k for k, v in voices["speakers"].items()}
    parts = ["<!doctype html><html lang=\"vi\"><head><meta charset=\"utf-8\">",
             "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
             "<title>Voice audition</title><style>body{font-family:sans-serif;margin:16px;max-width:760px}"
             "h2{margin-top:32px}.voice{border:1px solid #ccc;border-radius:12px;padding:12px;margin:12px 0}"
             "audio{width:100%;margin:4px 0 10px}small{color:#555}</style></head><body>",
             "<h1>Voice audition (plan 0003, R9)</h1>",
             f"<p>Each preset voice of {html.escape(model_version(voices))} reads the same five lines from the game. "
             "The voice of each person is in <code>data/voices.json</code>.</p>"]
    for region, label in AUDITION_REGIONS.items():
        parts.append(f"<h2>{label} voices ({html.escape(region)})</h2>")
        for name, info, files in rows[region]:
            now = f" · now the voice of <b>{html.escape(used[name])}</b>" if name in used else ""
            parts.append(f"<div class=\"voice\"><h3>{html.escape(name)}</h3>"
                         f"<small>{html.escape(info.get('description', ''))}{now}</small>")
            for file, text in files:
                parts.append(f"<div>{html.escape(text)}</div><audio controls preload=\"none\" src=\"{file}\"></audio>")
            parts.append("</div>")
    parts.append("</body></html>")
    (folder / "index.html").write_text("\n".join(parts) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--audition", type=Path, default=None)
    args = parser.parse_args()
    result = build(args.check)
    if args.audition and not args.check:
        audition(args.audition)
    return result


if __name__ == "__main__":
    sys.exit(main())
