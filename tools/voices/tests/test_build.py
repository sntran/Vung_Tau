import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import build  # noqa: E402


def test_hash_is_from_the_text_the_voice_and_the_model():
    # The game test tests/unit/test_voices.gd checks the same value.
    assert build.clip_hash("Dạ, chưa ạ.", "Mai Anh", "VieNeu-TTS-v3-Turbo vieneu==3.8.3") == \
        "1264a4278e2d8c788c4537d24b974a8d7e290f7618357d25a5643d26b7249ca3"
    assert build.clip_hash("a", "b", "c") != build.clip_hash("a", "b", "d")


def test_clips_of_a_dialogue():
    dialogue = {
        "speakers": {"batu": {"name": "Bà Tư", "address": "bà"}, "cosau": {"name": "Cô Sáu", "address": "cô"}},
        "say_again": {"vi": "Dạ, {address} nói lại được không ạ?"},
        "lines": {
            "a": {"speaker": "batu", "vi": "Ăn sáng chưa con?", "replies": [
                {"id": "chua", "vi": "Dạ, chưa ạ."}, {"id": "en", "english": True, "en": "Good morning!"}]},
            "b": {"speaker": "cosau", "vi": "Một trăm", "say": "Một trăm ngàn", "voice_style": "[cười]"},
            "c": {"text": "A description, no voice."},
        },
    }
    voices = {"speakers": {"batu": "V1", "cosau": "V2"}, "phone": "P"}
    clips = {c["id"]: c for c in build.collect_clips(dialogue, voices)}
    assert set(clips) == {"a", "reply.a.chua", "b", "say_again.batu", "say_again.cosau"}
    assert clips["a"]["voice"] == "V1"
    assert clips["reply.a.chua"]["voice"] == "P"
    assert clips["b"]["text"] == "[cười] Một trăm ngàn"
    assert clips["say_again.batu"]["text"] == "Dạ, bà nói lại được không ạ?"


def test_trim_and_loudness():
    rate = build.SAMPLE_RATE
    t = np.arange(rate) / rate
    tone = (0.3 * np.sin(2 * np.pi * 220 * t)).astype(np.float32)
    wav = np.concatenate([np.zeros(rate // 2, np.float32), tone, np.zeros(rate // 2, np.float32)])
    trimmed = build.trim_silence(wav)
    assert len(trimmed) == pytest.approx(rate + 2 * build.KEEP_SILENCE_S * rate, abs=2 * build.FRAME_S * rate)
    import pyloudnorm
    out = build.normalize(trimmed)
    assert pyloudnorm.Meter(rate).integrated_loudness(out.astype(np.float64)) == pytest.approx(build.LOUDNESS_LUFS, abs=0.3)
    assert np.max(np.abs(out)) <= build.PEAK_LIMIT + 1e-6


def test_each_clip_of_the_game_has_a_file():
    voices = build.load_json(build.VOICES)
    manifest = build.load_json(build.OUT / "manifest.json")
    model = build.model_version(voices)
    assert manifest["model"] == model
    for clip in build.all_clips(voices):
        entry = manifest["clips"].get(clip["id"])
        assert entry is not None, f"{clip['id']} has no file. Run tools/voices/build.py."
        assert entry["hash"] == build.clip_hash(clip["text"], clip["voice"], model), f"{clip['id']} changed"
        assert (build.OUT / entry["file"]).exists()
