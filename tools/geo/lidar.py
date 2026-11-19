#!/usr/bin/env python3
"""The lidar points of the play area from SlideRule (plan 0009, R5a and R5c).
CI only: the workspace cannot reach slideruleearth.io (plan 0009, D9).

    python tools/geo/lidar.py fetch     # ICESat-2 ATL08, ATL03 with the classes of ATL08, ATL24, GEDI L2A
    python tools/geo/lidar.py report    # the report and the map of the sea floor (R5c), no network

The fetch asks the public service of SlideRule (the Python package
sliderule, no account) for the points in the box of data/geo/area.json, of
all the years, and keeps only the points of good quality (the quality flags
of each product). Each product goes to data/geo/raw/lidar/PRODUCT.json: for
each point, the position, the date, the height of the ground or of the
photon, the height of the top (or the class), and the height over EGM2008
(the vertical datum of Copernicus and DeltaDTM: SlideRule gives the height
over the WGS 84 ellipsoid). A product that fails does not stop the others,
and the report says what each product gave, so that the first runs in CI
show the formats. The fallback is the NASA Earthdata access (plan 0009, Q5).

R5c: the report compares the depths of ATL24 with the heights of the
intertidal zone and of GEBCO (data/geo/raw/intertidal.tif, gebco.tif), with a
map. The build does not change the sea floor.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import traceback
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AREA = ROOT / "data" / "geo" / "area.json"
RAW = ROOT / "data" / "geo" / "raw" / "lidar"
REPORT = ROOT / "data" / "geo" / "build" / "lidar_report.md"
MAP = ROOT / "data" / "geo" / "build" / "lidar_seafloor.png"
T0 = "2018-10-14T00:00:00Z"  # the first data of ICESat-2
T1 = dt.date.today().isoformat() + "T00:00:00Z"
# Each product: the names of the calls of the sliderule package to try, in turn.
# The first run in CI (2026-11-19): atl08p and gedi02ap gave their rows for all
# the years in one request; each "x" call (run) for all the years stopped at the
# server after 600 s ("timed-out ... waiting for endpoint proxy") and gave
# nothing. So a "run" call asks for one year at a time (BY_YEAR).
PRODUCTS = {
    "atl08": [("icesat2", "atl08p"), ("run", "atl08x")],
    "atl03_ground": [("run", "atl03x")],
    "atl24": [("run", "atl24x")],
    "gedi02a": [("gedi", "gedi02ap"), ("run", "gedi02ax")],
}
BY_YEAR = {"run"}
# The fetch stops to ask for more years after this many seconds (the job has 120 minutes).
BUDGET_S = 75 * 60


def polygon() -> list[dict]:
    box = json.loads(AREA.read_text(encoding="utf-8"))["bbox"]
    return [{"lon": box["west"], "lat": box["south"]}, {"lon": box["east"], "lat": box["south"]},
            {"lon": box["east"], "lat": box["north"]}, {"lon": box["west"], "lat": box["north"]},
            {"lon": box["west"], "lat": box["south"]}]


def parms_for(product: str) -> dict:
    parms = {"poly": polygon(), "t0": T0, "t1": T1}
    if product == "atl08":
        parms.update({"atl08_class": ["atl08_ground", "atl08_canopy", "atl08_top_of_canopy"],
                      "phoreal": {"binsize": 1.0, "geoloc": "center", "above_classifier": True}})
    if product == "atl03_ground":
        parms.update({"atl08_class": ["atl08_ground"], "cnf": 4})
    if product == "gedi02a":
        parms.update({"degrade_filter": True, "l2_quality_filter": True})
    return parms


def year_spans(t0: str, t1: str) -> list[tuple[str, str]]:
    """The spans of one calendar year from t0 to t1 (ISO times), in order."""
    start, end = dt.date.fromisoformat(t0[:10]), dt.date.fromisoformat(t1[:10])
    spans = []
    while start < end:
        stop = min(dt.date(start.year + 1, 1, 1), end)
        spans.append((start.isoformat() + "T00:00:00Z", stop.isoformat() + "T00:00:00Z"))
        start = stop
    return spans


def egm2008(lon, lat, h):
    """Heights over the WGS 84 ellipsoid to heights over EGM2008 (PROJ gets the grid from its CDN)."""
    import pyproj
    pyproj.network.set_network_enabled(True)
    transformer = pyproj.Transformer.from_crs("EPSG:4979", "EPSG:4326+3855", always_xy=True)
    _, _, out = transformer.transform(lon, lat, h)
    return out


def fetch(lines: list[str]) -> None:
    import sliderule
    from sliderule import icesat2  # noqa: F401 - a module of the package
    try:
        from sliderule import gedi  # noqa: F401
    except Exception:  # noqa: BLE001
        gedi = None  # noqa: F841
    sliderule.init(verbose=False)
    lines.append(f"- sliderule {getattr(sliderule, '__version__', '?')}, {T0} to {T1}")
    RAW.mkdir(parents=True, exist_ok=True)
    import time
    import pandas as pd
    started = time.time()
    for product, calls in PRODUCTS.items():
        frame = None
        for module_name, call in calls:
            try:
                if module_name in BY_YEAR:
                    parts = []
                    for t0, t1 in year_spans(T0, T1):
                        if time.time() - started > BUDGET_S:
                            lines.append(f"- {product}: {call}: no time for {t0[:4]} and later")
                            break
                        parms = {**parms_for(product), "t0": t0, "t1": t1}
                        try:
                            part = sliderule.run(call, parms)
                        except Exception as error:  # noqa: BLE001 - the next year
                            lines.append(f"- {product}: {call} {t0[:4]}: {type(error).__name__}: {str(error)[:200]}")
                            continue
                        lines.append(f"- {product}: {call} {t0[:4]}: {0 if part is None else len(part)} rows")
                        if part is not None and len(part) > 0:
                            parts.append(part)
                    if not parts:
                        continue
                    frame = pd.concat(parts)
                else:
                    module = getattr(sliderule, module_name)
                    frame = getattr(module, call)(parms_for(product))
                lines.append(f"- {product}: {call} gave {len(frame)} rows; the columns: {list(frame.columns)[:30]}")
                break
            except Exception as error:  # noqa: BLE001 - try the next call
                lines.append(f"- {product}: {call}: {type(error).__name__}: {str(error)[:300]}")
        if frame is None or len(frame) == 0:
            continue
        try:
            write_points(product, frame, lines)
        except Exception as error:  # noqa: BLE001
            lines.append(f"- {product}: ERROR when it writes the points: {error}")
            lines += ["    " + t for t in traceback.format_exc().splitlines()[-4:]]


def write_points(product: str, frame, lines: list[str]) -> None:
    import numpy as np
    geometry = frame.geometry if hasattr(frame, "geometry") else None
    lon = np.asarray(geometry.x if geometry is not None else frame["longitude"], dtype=float)
    lat = np.asarray(geometry.y if geometry is not None else frame["latitude"], dtype=float)
    columns = list(frame.columns)
    def column(*names):
        for name in names:
            if name in columns:
                return np.asarray(frame[name])
        return None
    # GEDI L2A of gedi02ap: elevation_lm (the lowest mode, the ground) and elevation_hr (the highest return).
    ground = column("h_te_median", "h_mean", "height", "elev_lowestmode", "elevation_lm", "ortho_h", "surface_h", "h_ph")
    top = column("h_max_canopy", "h_canopy", "elev_highestreturn", "elevation_hr", "bathy_h")
    klass = column("atl08_class", "class_ph", "class")
    quality = column("quality_flag", "l2_quality_flag", "confidence", "quality_ph")
    when = frame.index if "time" not in columns else frame["time"]
    dates = [str(t)[:10] for t in when]
    if ground is None:
        lines.append(f"- {product}: no column of the height in {columns}")
        return
    ground_egm = egm2008(lon, lat, ground.astype(float))
    rows = []
    for i in range(len(lon)):
        rows.append([round(float(lon[i]), 6), round(float(lat[i]), 6), dates[i], round(float(ground[i]), 2),
                     round(float(ground_egm[i]), 2), None if top is None else round(float(top[i]), 2),
                     None if klass is None else str(klass[i]), None if quality is None else str(quality[i])])
    head = {"note": f"Made by tools/geo/lidar.py fetch (plan 0009, R5a): the points of {product} from SlideRule (public). height: over the WGS 84 ellipsoid; height_egm2008: over EGM2008. top: the top of the canopy, or the height of the sea floor (ATL24). The data of NASA (ICESat-2, GEDI) is free to use.",
            "product": product, "columns": ["lon", "lat", "date", "height", "height_egm2008", "top", "class", "quality"]}
    text = json.dumps(head, ensure_ascii=False, indent="\t")[:-2] + ',\n\t"points": [\n' + \
        ",\n".join(json.dumps(r) for r in rows) + "\n\t]\n}\n"
    (RAW / f"{product}.json").write_text(text, encoding="utf-8")
    lines.append(f"- {product}: {len(rows)} points in data/geo/raw/lidar/{product}.json")


def report(lines: list[str]) -> None:
    """R5c: the depths of ATL24 against the intertidal heights and GEBCO, with a map."""
    path = RAW / "atl24.json"
    if not path.exists():
        lines.append("- R5c: no points of ATL24 yet")
        return
    import numpy as np
    import rasterio
    from rasterio.warp import transform
    points = json.loads(path.read_text(encoding="utf-8"))["points"]
    lon = np.array([p[0] for p in points])
    lat = np.array([p[1] for p in points])
    depth = np.array([p[4] if p[5] is None else p[5] for p in points], dtype=float)
    out = ["", "## R5c: the sea floor", "", "| Source | Points | Mean difference (m) | RMSE (m) |", "|---|---|---|---|"]
    for name in ("intertidal.tif", "gebco.tif"):
        raster = ROOT / "data" / "geo" / "raw" / name
        if not raster.exists():
            continue
        with rasterio.open(raster) as src:
            xs, ys = transform("EPSG:4326", src.crs, list(lon), list(lat))
            values = np.array([v[0] for v in src.sample(zip(xs, ys))], dtype=float)
            ok = np.isfinite(values) & (values != (src.nodata if src.nodata is not None else -9999))
            diff = depth[ok] - values[ok]
            if ok.any():
                out.append(f"| {name} | {int(ok.sum())} | {diff.mean():.2f} | {np.sqrt((diff ** 2).mean()):.2f} |")
    lines += out
    try:
        from PIL import Image, ImageDraw
        img = Image.new("RGB", (800, 800), (250, 250, 246))
        draw = ImageDraw.Draw(img)
        box = json.loads(AREA.read_text(encoding="utf-8"))["bbox"]
        for x, y, d in zip(lon, lat, depth):
            px = (x - box["west"]) / (box["east"] - box["west"]) * 800
            py = (box["north"] - y) / (box["north"] - box["south"]) * 800
            c = int(max(0, min(255, 128 + d * 12)))
            draw.point((px, py), fill=(0, c, 255 - c))
        img.save(MAP)
        lines.append(f"- the map of the depths of ATL24: {MAP.name}")
    except Exception as error:  # noqa: BLE001
        lines.append(f"- the map: {error}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["fetch", "report"])
    args = parser.parse_args()
    lines = [f"## lidar {args.command} ({dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%d %H:%M')} UTC)", ""]
    try:
        fetch(lines) if args.command == "fetch" else report(lines)
    except Exception as error:  # noqa: BLE001 - the report says what failed
        lines.append(f"- ERROR: {error}")
        lines += ["    " + t for t in traceback.format_exc().splitlines()[-6:]]
    RAW.mkdir(parents=True, exist_ok=True)
    (RAW / f"{args.command}.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    parts = [(RAW / f"{c}.md").read_text(encoding="utf-8") for c in ("fetch", "report") if (RAW / f"{c}.md").exists()]
    REPORT.write_text("# The lidar points of the play area (plan 0009, R5a and R5c)\n\nMade by `tools/geo/lidar.py`. Do not change by hand.\n\n"
                      + "\n".join(parts), encoding="utf-8")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
