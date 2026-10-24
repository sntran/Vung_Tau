#!/usr/bin/env python3
"""Computes the tide constituents of Vũng Tàu (plan 0003, D12, R8d to R8j).

Usage:
  python tools/geo/tide.py                      Download EOT20 (if necessary) and write the tide files.
  python tools/geo/tide.py --eot DIR            The folder of EOT20 (DIR/EOT20/ocean_tides/).
  python tools/geo/tide.py --from 2026-11-01    The first day of the 12 months of dry times.

CI runs this script after fetch.py and before build.py. It writes
data/geo/build/tide.json and data/geo/build/tide_report.md.
"""

import argparse
import datetime
import math
import sys
from pathlib import Path

import h5py
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from geodata import eot20, lunar, tidecalc  # noqa: E402
from geodata.config import BUILD, GEO, ROOT, load_json, write_json  # noqa: E402

CONSTITUENTS = ["2n2", "j1", "k1", "k2", "m2", "m4", "mf", "mm", "n2", "o1", "p1", "q1", "s1", "s2", "sa", "ssa", "t2"]
# The published amplitudes for the Vũng Tàu station (R8e), in meters.
PUBLISHED = {"m2": 0.778, "k1": 0.574, "o1": 0.421, "s2": 0.302}
PUBLISHED_SOURCE = "https://jmst.vimaru.edu.vn/index.php/jmst/article/download/891/646/1911"
MAX_DIFFERENCE = 0.20
# The grid cells of EOT20 near the coast have no value. Use the nearest
# cells with a value, with weights 1/d², in this distance.
NEAREST = 4
MAX_DISTANCE_KM = 40.0
LOCAL = datetime.timezone(datetime.timedelta(hours=7))
TESTS = 200
STEP_S = 300
DAY_START_H = 5
DAY_END_H = 18
MIN_DRY_H = 2.0
DRY_SEASON = (12, 1, 2, 3, 4)


def log(text: str) -> None:
    print(f"[tide] {text}", flush=True)


def read_constants(folder: Path, points: dict[str, tuple[float, float]]) -> dict:
    """The amplitude (m) and the phase (degrees) of each constituent at each point."""
    out = {name: {} for name in points}
    for c in CONSTITUENTS:
        with h5py.File(folder / f"{c.upper()}_ocean_eot20.nc", "r") as f:
            lat = f["lat"][:]
            lon = f["lon"][:]
            for name, (plat, plon) in points.items():
                rows = np.nonzero(np.abs(lat - plat) < 0.6)[0]
                cols = np.nonzero(np.abs(lon - plon) < 0.6)[0]
                amp = f["amplitude"][rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]
                ph = f["phase"][rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]
                glat, glon = np.meshgrid(lat[rows], lon[cols], indexing="ij")
                valid = np.isfinite(amp) & np.isfinite(ph) & (amp != 0) & (ph != 0)
                dy = (glat - plat) * 111.32
                dx = (glon - plon) * 111.32 * math.cos(math.radians(plat))
                d = np.hypot(dx, dy)
                d[~valid] = np.inf
                order = np.argsort(d, axis=None)[:NEAREST]
                dist = d.flat[order]
                if not np.isfinite(dist[0]) or dist[0] > MAX_DISTANCE_KM:
                    raise SystemExit(f"EOT20 has no {c} value in {MAX_DISTANCE_KM} km of {name}")
                keep = dist <= MAX_DISTANCE_KM
                w = 1.0 / np.maximum(dist[keep], 0.1) ** 2
                z = amp.flat[order][keep] * np.exp(-1j * np.radians(ph.flat[order][keep]))
                value = np.sum(w * z) / np.sum(w) / 100.0  # cm to m
                out[name][c] = {"amplitude": round(float(abs(value)), 5),
                                "phase": round(float(-math.degrees(np.angle(value)) % 360.0), 3),
                                "nearest_km": round(float(dist[0]), 1)}
    return out


def pytmd_levels(constants: dict, unix: np.ndarray) -> tuple[np.ndarray, float]:
    """The sea levels from pyTMD (FES corrections, no minor constituents), and TT − UT1 in seconds."""
    import pyTMD
    import timescale
    ts = timescale.time.Timescale().from_deltatime(unix, epoch=(1970, 1, 1, 0, 0, 0), standard="UTC")
    deltat = np.asarray(ts.tt_ut1)
    pu, pf, g = pyTMD.constituents.arguments(ts.tide + 48622.0, CONSTITUENTS, deltat=deltat, corrections="FES")
    total = np.zeros(len(unix))
    for k, c in enumerate(CONSTITUENTS):
        a = constants[c]["amplitude"]
        p = math.radians(constants[c]["phase"])
        total += pf[:, k] * a * np.cos(np.radians(g[:, k]) + pu[:, k] - p)
    return total, float(np.mean(deltat) * 86400.0)


def dry_windows(tide: dict, top: float, start: datetime.date, days: int) -> list[dict]:
    """The times when the sea level is below the ridge top for MIN_DRY_H hours between DAY_START_H and DAY_END_H."""
    t0 = datetime.datetime(start.year, start.month, start.day, tzinfo=LOCAL).timestamp()
    times = t0 + np.arange(0, days * 86400, STEP_S, dtype=float)
    levels = tidecalc.level(tide, "hon_ba", times)
    dry = levels < top
    out = []
    edges = np.flatnonzero(np.diff(np.concatenate([[0], dry.astype(np.int8), [0]])))
    for a, b in zip(edges[::2], edges[1::2]):
        begin = datetime.datetime.fromtimestamp(times[a], LOCAL)
        end = datetime.datetime.fromtimestamp(times[b - 1] + STEP_S, LOCAL)
        day_a = begin.replace(hour=DAY_START_H, minute=0)
        day_b = begin.replace(hour=DAY_END_H, minute=0)
        inside = (min(end, day_b) - max(begin, day_a)).total_seconds() / 3600.0
        if inside >= MIN_DRY_H:
            low = float(levels[a:b].min())
            d, m, _, leap = lunar.solar_to_lunar(begin.day, begin.month, begin.year)
            out.append({"start": begin.isoformat(timespec="minutes"), "end": end.isoformat(timespec="minutes"),
                        "hours": round((end - begin).total_seconds() / 3600.0, 1), "lowest_m": round(low, 2),
                        "lunar": f"{d}/{m}{' nhuận' if leap else ''}"})
    return out


def propose_days(windows: list[dict]) -> list[dict]:
    """Three day-1 dates in the dry season: the ridge is dry in the morning of day 2 or day 3 (R8j)."""
    out = []
    months = set()
    for w in windows:
        begin = datetime.datetime.fromisoformat(w["start"])
        if begin.month not in DRY_SEASON or begin.hour >= 12:
            continue
        day_one = begin.date() - datetime.timedelta(days=1)
        key = (begin.year, begin.month)
        if key in months:
            continue
        months.add(key)
        d, m, _, leap = lunar.solar_to_lunar(day_one.day, day_one.month, day_one.year)
        out.append({"day_one": day_one.isoformat(), "lunar": f"{d}/{m}{' nhuận' if leap else ''}",
                    "dry": w, "day": 2})
        if len(out) == 3:
            break
    return out


def report(tide: dict, top: float, windows: list[dict], days: list[dict], check: float) -> str:
    lines = ["# The tide report (plan 0003, R8d to R8j)", "",
             f"Made by `tools/geo/tide.py` on {datetime.date.today().isoformat()}. Source: {tide['source']}", "",
             "## The constituents at Hòn Bà", "",
             "| Constituent | Amplitude (m) | Phase (°) | Nearest EOT20 cell (km) |", "|---|---|---|---|"]
    hon_ba = tide["points"]["hon_ba"]["constituents"]
    for c in CONSTITUENTS:
        v = hon_ba[c]
        lines.append(f"| {c.upper()} | {v['amplitude']:.3f} | {v['phase']:.1f} | {v['nearest_km']} |")
    lines += ["", f"## The comparison with the Vũng Tàu station (R8e, [source]({PUBLISHED_SOURCE}))", "",
              "| Constituent | Published (m) | EOT20 at Bãi Trước (m) | Difference | Result |", "|---|---|---|---|---|"]
    problems = []
    for c, value in PUBLISHED.items():
        ours = tide["points"]["bai_truoc"]["constituents"][c]["amplitude"]
        diff = (ours - value) / value
        ok = abs(diff) <= MAX_DIFFERENCE
        if not ok:
            problems.append(f"{c.upper()} differs by {diff:+.0%} from the station")
        lines.append(f"| {c.upper()} | {value:.3f} | {ours:.3f} | {diff:+.1%} | {'ok' if ok else 'PROBLEM'} |")
    lines += ["", "## The checks", "",
              f"- The game calculation (`geodata/tidecalc.py`, the same as `scripts/geo/tide.gd`) agrees with pyTMD "
              f"within {check * 1000:.2f} mm for the {TESTS} test values.",
              "- The test values have no minor constituents (pyTMD can infer them from the major constituents). "
              "The game uses only the 17 constituents of EOT20."]
    lines += ["", "## The Hòn Bà ridge (R8h, R8i)", "",
              f"The ridge top is {top:+.2f} m (from `data/geo/hon_ba.json`). The ridge is dry when the sea level is "
              f"below this height. These are the times in the next 12 months when the ridge is dry for at least "
              f"{MIN_DRY_H:.0f} hours between {DAY_START_H:02d}:00 and {DAY_END_H:02d}:00 (UTC+7).", "",
              "| Start | End | Hours | Lowest sea level (m) | Lunar date |", "|---|---|---|---|---|"]
    for w in windows:
        lines.append(f"| {w['start'][:16].replace('T', ' ')} | {w['end'][11:16]} | {w['hours']} | "
                     f"{w['lowest_m']:+.2f} | {w['lunar']} |")
    lunar_days = sorted({int(w["lunar"].split("/")[0]) for w in windows})
    lines += ["", f"{len(windows)} dry times. Lunar days: {', '.join(str(d) for d in lunar_days)}.", "",
              "## Day 1 proposals (R8j)", "",
              "| Day 1 | Lunar date | Dry time on day 2 |", "|---|---|---|"]
    for d in days:
        w = d["dry"]
        lines.append(f"| {d['day_one']} | {d['lunar']} | {w['start'][11:16]} to {w['end'][11:16]} ({w['hours']} h) |")
    if len(days) < 3:
        problems.append(f"only {len(days)} day 1 proposals in the dry season")
    lines += ["", "## Problems", ""] + ([f"- {p}" for p in problems] or ["None."])
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--eot", type=Path, default=ROOT / "build" / "eot")
    parser.add_argument("--out", type=Path, default=BUILD)
    parser.add_argument("--geo", type=Path, default=GEO)
    parser.add_argument("--from", dest="start", default=None, help="The first day (YYYY-MM-DD) of the dry times.")
    args = parser.parse_args()
    hon_ba = load_json(args.geo / "hon_ba.json")
    folder = args.eot / "EOT20" / "ocean_tides"
    if len(list(folder.glob("*_ocean_eot20.nc"))) != 17:
        log(f"download EOT20 to {args.eot}")
        folder = eot20.download(args.eot)
    points = {"hon_ba": (hon_ba["islet"]["lat"], hon_ba["islet"]["lon"]),
              "bai_truoc": (hon_ba["bai_truoc"]["lat"], hon_ba["bai_truoc"]["lon"])}
    constants = read_constants(folder, points)
    import pyTMD
    rng = np.random.default_rng(79489)
    first = datetime.datetime(2024, 1, 1, tzinfo=datetime.timezone.utc).timestamp()
    last = datetime.datetime(2036, 1, 1, tzinfo=datetime.timezone.utc).timestamp()
    tests_t = np.sort(np.round(rng.uniform(first, last, TESTS)))
    expected, deltat_s = pytmd_levels(constants["hon_ba"], tests_t)
    coefficients = pyTMD.constituents.coefficients_table(CONSTITUENTS, corrections="FES")
    tide = {
        "note": "The tide at Vũng Tàu (plan 0003, D12). The sea level is the sum of f · A · cos(G + u − g) for each "
                "constituent. See tools/geo/geodata/tidecalc.py and scripts/geo/tide.gd.",
        "source": f"EOT20 (Hart-Davis et al., 2021) with pyTMD {pyTMD.__version__}, FES nodal corrections",
        "license": eot20.LICENSE,
        "datum": "mean sea level",
        "units": "m",
        "time_zone_h": 7,
        "tt_minus_ut1_s": round(deltat_s, 1),
        "point": "hon_ba",
        "points": {name: {"lat": lat, "lon": lon, "constituents": constants[name]} for name, (lat, lon) in points.items()},
        "constituents": [{"name": c, "doodson": [int(round(v)) for v in coefficients[:, k]], "nodal": tidecalc.NODAL[c]}
                         for k, c in enumerate(CONSTITUENTS)],
    }
    ours = tidecalc.level(tide, "hon_ba", tests_t)
    check = float(np.max(np.abs(ours - expected)))
    if check > 0.001:
        raise SystemExit(f"tidecalc.py differs from pyTMD by {check:.4f} m")
    tide["tests"] = [[int(t), round(float(v), 4)] for t, v in zip(tests_t, expected)]
    top = float(hon_ba["ridge_top_m"])
    start = datetime.date.fromisoformat(args.start) if args.start else datetime.datetime.now(LOCAL).date()
    windows = dry_windows(tide, top, start, 365)
    days = propose_days(windows)
    tide["ridge_top_m"] = top
    tide["dry_times"] = windows
    tide["day_one_proposals"] = [d["day_one"] for d in days]
    write_json(args.out / "tide.json", tide)
    (args.out / "tide_report.md").write_text(report(tide, top, windows, days, check), encoding="utf-8")
    log(f"wrote tide.json: M2 {constants['hon_ba']['m2']['amplitude']:.3f} m, {len(windows)} dry times, "
        f"day 1 proposals {tide['day_one_proposals']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
