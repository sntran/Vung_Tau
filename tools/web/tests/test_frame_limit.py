"""Plan 0031, R18 (changed 2026-11-27): the longest frame while a pack loads is
at most the median frame of the same run plus 250 ms (tools/web/frame_limit.js,
used by check.js --measure and by PT-85)."""
import json
import pathlib
import subprocess

MODULE = pathlib.Path(__file__).resolve().parents[1] / "frame_limit.js"


def run(expression):
    script = f"const f = require({json.dumps(str(MODULE))}); console.log(JSON.stringify({expression}));"
    out = subprocess.run(["node", "-e", script], check=True, capture_output=True, text=True).stdout
    return json.loads(out)


def test_the_limit_is_the_median_frame_plus_250_ms():
    assert run("f.packFrameLimitMs({count: 40, medianMs: 530.4, longestMs: 1300})") == 780.4
    assert run("f.OVER_MEDIAN_MS") == 250


def test_no_limit_without_frames():
    assert run("f.packFrameLimitMs(undefined)") is None
    assert run("f.packFrameLimitMs({count: 0, medianMs: 0, longestMs: 0})") is None


def test_the_failures_of_a_row():
    row = {"label": "720x1280_25mbps_empty", "frames": {"count": 100, "medianMs": 600, "longestMs": 2000},
           "packs": {"models": {"times": {"longestFrameMs": 900}}, "people": {"times": {"longestFrameMs": 820}}}}
    failures = run(f"f.packFrameFailures({json.dumps(row)})")
    assert failures == ["720x1280_25mbps_empty: the pack models, a frame of 900 ms (the median frame 600 ms, the limit 850 ms)"]


def test_a_row_without_the_median_frame_fails():
    row = {"label": "a", "packs": {"models": {"times": {"longestFrameMs": 100}}}}
    assert run(f"f.packFrameFailures({json.dumps(row)})") == ["a: no median frame of the run"]
