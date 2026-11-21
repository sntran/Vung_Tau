#!/usr/bin/env python3
"""The lidar points of the play area from SlideRule (plan 0009, R5a and R5c).
The fetch runs in CI only: the Python package of SlideRule does not connect
from the workspace (plan 0009, D9).

    python tools/geo/lidar.py fetch [--allow-fewer] [--refetch]
    python tools/geo/lidar.py seed COMMIT ...   # the files of earlier runs in Git history to the store
    python tools/geo/lidar.py tracks            # the short form: each 20 m of a track (Git)
    python tools/geo/lidar.py report            # the report and the map of the sea floor (R5c)
    python tools/geo/lidar.py mdt               # R5c: the mean sea level over EGM2008 at Bãi Trước (D-0009-07)

The products: ATL08 (segments), ATL03 with the classes of ATL08 (the ground
photons, and the photons of the classes canopy, top of canopy, and no class
over an outline of a building: the roofs, report 0009, D-0009-02), ATL24 (the
sea floor), and GEDI L2A. For each point: the position, the date, the height
over the WGS 84 ellipsoid and over EGM2008 (the datum of Copernicus), the top
or the class, the quality, and the track (rgt, cycle, spot) where SlideRule
gives it.

The data of each product is kept by year (report 0009, D-0009-01): one file
for each product and year in the release of geostore.py, with its rows in
data/geo/raw/lidar/manifest.json. The fetch asks only for the years that are
not there, and for the current year. For each year that it asks for
(decide()):

- a year that fails, or that gets no time, keeps the data of the last good run;
- a year with fewer rows than its file keeps its file;
- a year with 0 rows where the last good run had rows is an error;
- a product with fewer points than before is an error, unless the run has
  --allow-fewer (an input of the workflow that a person sets).

After an error the command ends with 1: the job writes the report and does
not commit. The large files are not in Git (D-0009-06): Git has the manifest,
the reports, the map, and the short form (data/geo/build/lidar_tracks.json).

R5c: the report compares the sea floor of ATL24 with the heights of the
intertidal zone and of GEBCO (data/geo/raw/intertidal.tif, gebco.tif), with a
map. The build does not change the sea floor.

D-0009-07: ATL24 is over EGM2008, and the intertidal heights are over the
mean sea level. mdt() gives the mean sea level over EGM2008 at the points of
ATL24 of that comparison from two models: DTU22MDT (the mean dynamic
topography of DTU), and the mean sea surface DTU21MSS minus the geoid
EGM2008 (from the two heights of the photons of ATL03 near each point).
The command runs in the workspace and in CI (ftp.space.dtu.dk); it writes
data/geo/raw/lidar/mdt.md.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess
import sys
import time
import traceback
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import geostore  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
AREA = ROOT / "data" / "geo" / "area.json"
WORLD = ROOT / "data" / "geo" / "build" / "world.json"
RAW = ROOT / "data" / "geo" / "raw" / "lidar"
MANIFEST = RAW / "manifest.json"
TRACKS = ROOT / "data" / "geo" / "build" / "lidar_tracks.json"
REPORT = ROOT / "data" / "geo" / "build" / "lidar_report.md"
MAP = ROOT / "data" / "geo" / "build" / "lidar_seafloor.png"
T0 = "2018-10-14T00:00:00Z"  # the first data of ICESat-2
COLUMNS = ["lon", "lat", "date", "height", "height_egm2008", "top", "class", "quality", "rgt", "cycle", "spot"]
# Each product: the calls of the sliderule package to try, in turn, for one
# year. The first run in CI (2026-11-19): atl08p and gedi02ap gave their rows
# for all the years in one request; each "x" call (run) for all the years
# stopped at the server after 600 s. So each call asks for one year.
PRODUCTS = {
    "atl08": [("icesat2", "atl08p"), ("run", "atl08x")],
    "atl03_ground": [("run", "atl03x")],
    "atl03_roof": [("run", "atl03x")],
    "atl24": [("run", "atl24x")],
    "gedi02a": [("gedi", "gedi02ap"), ("run", "gedi02ax")],
}
# The columns of the heights that are over EGM2008 already (not over the WGS 84 ellipsoid).
ORTHOMETRIC = {"ortho_h"}
# The fetch stops to ask for more years after this many seconds (the job has 120 minutes).
BUDGET_S = 75 * 60
# The short form: the length of a bin along a track, and the gap across it that starts another beam (m).
BIN_M = 20.0
BEAM_GAP_M = 30.0
TRACK_ANGLES = [k * 0.5 for k in range(-24, 25)]
NOTE = ("Made by tools/geo/lidar.py (plan 0009, R5a; report 0009, D-0009-01 and D-0009-06): the files of the "
        "lidar points, one for each product and year, are assets of the release of the repository; rows is the "
        "count of points of each file. The data of NASA (ICESat-2, GEDI) is free to use.")


def polygon() -> list[dict]:
    box = json.loads(AREA.read_text(encoding="utf-8"))["bbox"]
    return [{"lon": box["west"], "lat": box["south"]}, {"lon": box["east"], "lat": box["south"]},
            {"lon": box["east"], "lat": box["north"]}, {"lon": box["west"], "lat": box["north"]},
            {"lon": box["west"], "lat": box["south"]}]


def parms_for(product: str, t0: str, t1: str) -> dict:
    parms = {"poly": polygon(), "t0": t0, "t1": t1}
    if product == "atl08":
        parms.update({"atl08_class": ["atl08_ground", "atl08_canopy", "atl08_top_of_canopy"],
                      "phoreal": {"binsize": 1.0, "geoloc": "center", "above_classifier": True}})
    if product == "atl03_ground":
        parms.update({"atl08_class": ["atl08_ground"], "cnf": 4})
    if product == "atl03_roof":
        # D-0009-02: the photons over the roofs. ATL08 has no class for a
        # building: a roof photon is canopy, top of canopy, or with no class.
        # D-0009-11: cnf 4 keeps only the photons of a high signal confidence.
        parms.update({"atl08_class": ["atl08_canopy", "atl08_top_of_canopy", "atl08_unclassified"], "cnf": 4})
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


def needs_fetch(old_rows: int | None, year: int, this_year: int, refetch: bool) -> bool:
    """A year is asked for when it has no file, when it is the current year, or with --refetch."""
    return refetch or old_rows is None or year >= this_year


def decide(old_rows: int | None, new_rows: int | None, allow_fewer: bool = False) -> str:
    """What the fetch does with the rows of one year: "keep" the file of the
    last good run, "write" the new rows, or "error" (D-0009-01)."""
    if new_rows is None:
        return "keep"  # the year failed, or got no time
    if new_rows == 0:
        return "error" if old_rows else "keep"
    if old_rows is not None and new_rows < old_rows and not allow_fewer:
        return "keep"
    return "write"


# D-0009-09: the products of ICESat-2 over the land come from the same passes
# (the ATL03 ground photons take their class from ATL08). ATL24 has passes over
# the water only, and GEDI is another satellite: they are not compared.
LAND = ("atl03_ground", "atl08", "atl03_roof")


def incomplete_products(passes: dict) -> set:
    """The products of one year that lost passes (report 0009, D-0009-09).
    passes: {product: set of the dates of its passes}. ATL08 must have each pass
    of the ATL03 ground photons, and the ground photons each pass of ATL08 and
    of the roof photons (a pass can cross no roof)."""
    found = set()
    ground = passes.get("atl03_ground")
    atl08 = passes.get("atl08")
    roof = passes.get("atl03_roof") or set()
    if ground is not None and atl08 is not None and set(ground) - set(atl08):
        found.add("atl08")
    if ground is not None and (set(atl08 or ()) | set(roof)) - set(ground):
        found.add("atl03_ground")
    return found


def passes_of(manifest: dict, key: str) -> list[str]:
    """The dates of the passes of one file of the store (from its entry, else from its points)."""
    entry = manifest.get("files", {}).get(key)
    if entry is None:
        return []
    if "passes" in entry:
        return list(entry["passes"])
    data = geostore.get(manifest, key)
    i = data["columns"].index("date")
    return sorted({p[i] for p in data["points"]})


def total(manifest: dict, product: str) -> int:
    return sum(int(e.get("rows", 0)) for k, e in manifest.get("files", {}).items() if k.split("/")[0] == product)


def by_year(manifest: dict, product: str) -> dict[int, int]:
    return {int(k.split("/")[1]): int(e.get("rows", 0)) for k, e in sorted(manifest.get("files", {}).items())
            if k.split("/")[0] == product}


def egm2008(lon, lat, h):
    """Heights over the WGS 84 ellipsoid to heights over EGM2008 (PROJ gets the grid from its CDN)."""
    import pyproj
    pyproj.network.set_network_enabled(True)
    transformer = pyproj.Transformer.from_crs("EPSG:4979", "EPSG:4326+3855", always_xy=True)
    _, _, out = transformer.transform(lon, lat, h)
    return out


def to_rows(frame) -> tuple[list, str | None]:
    """The rows (COLUMNS) of a frame of SlideRule, and the name of its height column."""
    import numpy as np
    geometry = frame.geometry if hasattr(frame, "geometry") else None
    lon = np.asarray(geometry.x if geometry is not None else frame["longitude"], dtype=float)
    lat = np.asarray(geometry.y if geometry is not None else frame["latitude"], dtype=float)
    columns = list(frame.columns)
    used = {}

    def column(key, *names):
        for name in names:
            if name in columns:
                used[key] = name
                return np.asarray(frame[name])
        return None
    # GEDI L2A of gedi02ap: elevation_lm (the lowest mode, the ground) and elevation_hr (the highest return).
    ground = column("height", "h_te_median", "h_mean", "height", "elev_lowestmode", "elevation_lm", "ortho_h", "surface_h", "h_ph")
    top = column("top", "h_max_canopy", "h_canopy", "elev_highestreturn", "elevation_hr", "bathy_h")
    klass = column("class", "atl08_class", "class_ph", "class")
    quality = column("quality", "quality_flag", "l2_quality_flag", "confidence", "quality_ph", "atl03_cnf")
    rgt = column("rgt", "rgt", "track")
    cycle = column("cycle", "cycle", "orbit")
    spot = column("spot", "spot", "beam")
    when = frame.index if "time" not in columns else frame["time"]
    dates = [str(t)[:10] for t in when]
    if ground is None:
        raise ValueError(f"no column of the height in {columns}")
    # ortho_h of ATL24 is already a height over EGM2008 (the first run turned it
    # over the geoid a second time: -0.45 m became +2.11 m).
    if used.get("height") in ORTHOMETRIC:
        ground_egm = ground.astype(float)
    else:
        ground_egm = egm2008(lon, lat, ground.astype(float))

    def value(array, i, digits=None):
        if array is None:
            return None
        v = array[i]
        if digits is None:
            return str(v)
        return round(float(v), digits)
    rows = [[round(float(lon[i]), 6), round(float(lat[i]), 6), dates[i], round(float(ground[i]), 2),
             round(float(ground_egm[i]), 2), value(top, i, 2), value(klass, i), value(quality, i),
             value(rgt, i), value(cycle, i), value(spot, i)] for i in range(len(lon))]
    return rows, used.get("height")


def over_outlines(rows: list) -> list:
    """The rows over an outline of overture.json, each with the id of its
    outline at the end (the roof photons of D-0009-02)."""
    import numpy as np
    import shapely
    sys.path.insert(0, str(ROOT / "tools" / "geo"))
    import buildings
    from geodata.projection import Projection
    outlines = buildings.outlines()
    origin = json.loads(WORLD.read_text(encoding="utf-8"))["origin"]
    proj = Projection(float(origin["utm_e"]), float(origin["utm_n"]))
    polygons = [shapely.Polygon(list(zip(flat[0::2], flat[1::2]))) for _oid, _s, _h, _f, flat in outlines]
    tree = shapely.STRtree(polygons)
    if not rows:
        return []
    xs, zs = proj.to_game(np.array([r[0] for r in rows]), np.array([r[1] for r in rows]))
    points = shapely.points(np.asarray(xs, dtype=float), np.asarray(zs, dtype=float))
    pairs = tree.query(points, predicate="within")
    kept = {}
    for point_index, polygon_index in zip(pairs[0], pairs[1]):
        kept.setdefault(int(point_index), outlines[int(polygon_index)][0])
    return [rows[i] + [kept[i]] for i in sorted(kept)]


def fetch(lines: list[str], allow_fewer: bool, refetch: bool) -> list[str]:
    """Fetches the years that are not there. Returns the errors (D-0009-01)."""
    import sliderule
    from sliderule import icesat2  # noqa: F401 - a module of the package
    try:
        from sliderule import gedi  # noqa: F401
    except Exception:  # noqa: BLE001
        gedi = None  # noqa: F841
    sliderule.init(verbose=False)
    t1 = dt.date.today().isoformat() + "T00:00:00Z"
    this_year = dt.date.today().year
    lines.append(f"- sliderule {getattr(sliderule, '__version__', '?')}, {T0} to {t1}"
                 + (", allow fewer points" if allow_fewer else "") + (", all the years again" if refetch else ""))
    manifest = geostore.load(MANIFEST)
    errors: list[str] = []
    started = time.time()
    # D-0009-09: the years whose land products do not have the same passes.
    incomplete: dict[int, set] = {}
    for t0, _t in year_spans(T0, t1):
        year = int(t0[:4])
        passes = {p: set(passes_of(manifest, f"{p}/{year}")) for p in LAND
                  if p in PRODUCTS and f"{p}/{year}" in manifest.get("files", {})}
        incomplete[year] = incomplete_products(passes)
    for product, calls in PRODUCTS.items():
        before = total(manifest, product)
        for t0, t_end in year_spans(T0, t1):
            year = int(t0[:4])
            key = f"{product}/{year}"
            old = manifest.get("files", {}).get(key, {}).get("rows")
            again = product in incomplete.get(year, set())
            if again:
                lines.append(f"- {product} {year}: not complete (it does not have the passes of the other land products "
                             "of the year): asked for again")
            if not (again or needs_fetch(old, year, this_year, refetch)):
                continue
            if time.time() - started > BUDGET_S:
                lines.append(f"- {product} {year}: no time; the file of the last good run stays ({old} rows)")
                continue
            rows = None
            height_column = None
            for module_name, call in calls:
                try:
                    parms = parms_for(product, t0, t_end)
                    if module_name == "run":
                        frame = sliderule.run(call, parms)
                    else:
                        frame = getattr(getattr(sliderule, module_name), call)(parms)
                    if frame is None:
                        raise ValueError("no frame")
                    rows, height_column = to_rows(frame) if len(frame) else ([], None)
                    if product == "atl03_roof":
                        rows = over_outlines(rows)
                    break
                except Exception as error:  # noqa: BLE001 - the next call
                    lines.append(f"- {product} {year}: {call}: {type(error).__name__}: {str(error)[:200]}")
            new = None if rows is None else len(rows)
            action = decide(old, new, allow_fewer)
            if action == "error":
                errors.append(f"{product} {year}: 0 rows, and the last good run had {old}")
                lines.append(f"- ERROR {product} {year}: 0 rows, and the last good run had {old}; the job does not commit")
            elif action == "write":
                columns = COLUMNS + (["outline"] if product == "atl03_roof" else [])
                geostore.put(manifest, key, {"product": product, "year": year, "columns": columns, "points": rows,
                                             "height_column": height_column},
                             product=product, year=year, rows=new, fetched=dt.date.today().isoformat(),
                             passes=sorted({r[2] for r in rows}))
                lines.append(f"- {product} {year}: {new} rows (it had {old})")
            else:
                lines.append(f"- {product} {year}: {new} rows; the file of the last good run stays ({old} rows)")
        after = total(manifest, product)
        if after < before and not allow_fewer:
            errors.append(f"{product}: {after} points, it had {before}")
            lines.append(f"- ERROR {product}: {after} points, it had {before}")
    if not errors:
        geostore.save(MANIFEST, manifest, NOTE)
    return errors


def seed(lines: list[str], commits: list[str]) -> list[str]:
    """The files of the products in the Git history (the runs before the store)
    to the store: for each year, the commit with the most rows (ties: the later
    commit of the list). Only for the years that the store does not have."""
    manifest = geostore.load(MANIFEST)
    old_names = {"atl03_ground": "atl03_ground", "atl08": "atl08", "atl24": "atl24", "gedi02a": "gedi02a"}
    for product, name in old_names.items():
        best: dict[int, tuple[int, str, list]] = {}
        meta = {}
        for commit in commits:
            try:
                text = subprocess.run(["git", "show", f"{commit}:data/geo/raw/lidar/{name}.json"], cwd=ROOT,
                                      capture_output=True, check=True).stdout.decode("utf-8")
            except subprocess.CalledProcessError:
                lines.append(f"- seed {product}: no file in {commit}")
                continue
            data = json.loads(text)
            meta[commit] = data.get("height_column")
            years: dict[int, list] = {}
            for row in data["points"]:
                years.setdefault(int(str(row[2])[:4]), []).append(list(row) + [None, None, None])
            lines.append(f"- seed {product} {commit}: " + ", ".join(f"{y} {len(r)}" for y, r in sorted(years.items())))
            for year, rows in years.items():
                if year not in best or len(rows) >= best[year][0]:
                    best[year] = (len(rows), commit, rows)
        for year, (count, commit, rows) in sorted(best.items()):
            key = f"{product}/{year}"
            if key in manifest.get("files", {}):
                continue
            geostore.put(manifest, key, {"product": product, "year": year, "columns": COLUMNS, "points": rows,
                                         "height_column": meta.get(commit), "from": commit},
                         product=product, year=year, rows=count, fetched=f"Git {commit}")
    geostore.save(MANIFEST, manifest, NOTE)
    return []


def track_bins(points: list[tuple], bin_m: float = BIN_M, gap_m: float = BEAM_GAP_M) -> list[dict]:
    """The short form of the photons (D-0009-06): points are (date, x, z,
    height, kind) in meters, kind "ground" or "roof". For each date, the
    direction of the track is the angle near north to south that makes the
    beams sharpest; a gap of more than
    gap_m across it starts another beam; along it, a bin has bin_m. For each
    bin: the date, the middle, the median ground, the median roof, and the
    counts."""
    import numpy as np
    by_date: dict[str, list] = {}
    for p in points:
        by_date.setdefault(p[0], []).append(p)
    out = []
    for date, group in sorted(by_date.items()):
        xz = np.array([[p[1], p[2]] for p in group], dtype=float)
        heights = np.array([p[3] for p in group], dtype=float)
        roof = np.array([p[4] == "roof" for p in group])
        middle = xz.mean(axis=0)
        # The tracks of ICESat-2 are within a few degrees of north to south at
        # 10° N (an inclination of 92°): the angle in TRACK_ANGLES that puts the
        # photons in the fewest strips of 5 m across the track.
        best = None
        for angle in TRACK_ANGLES:
            a = np.radians(angle)
            across_try = (xz - middle) @ np.array([np.cos(a), -np.sin(a)])
            strips = len(np.unique(np.floor(across_try / 5.0)))
            if best is None or strips < best[0]:
                best = (strips, a)
        along_axis = np.array([np.sin(best[1]), np.cos(best[1])])
        across_axis = np.array([np.cos(best[1]), -np.sin(best[1])])
        along = (xz - middle) @ along_axis
        across = (xz - middle) @ across_axis
        order = np.argsort(across)
        beam = np.zeros(len(group), dtype=int)
        current = 0
        for k in range(1, len(order)):
            if across[order[k]] - across[order[k - 1]] > gap_m:
                current += 1
            beam[order[k]] = current
        cells: dict[tuple[int, int], list[int]] = {}
        for i in range(len(group)):
            cells.setdefault((int(beam[i]), int(np.floor(along[i] / bin_m))), []).append(i)
        for (_b, _k), index in sorted(cells.items()):
            index = np.array(index)
            ground_h = heights[index][~roof[index]]
            roof_h = heights[index][roof[index]]
            x, z = np.median(xz[index], axis=0)
            out.append({"date": date, "x": round(float(x), 1), "z": round(float(z), 1),
                        "ground": round(float(np.median(ground_h)), 2) if len(ground_h) else None,
                        "roof": round(float(np.median(roof_h)), 2) if len(roof_h) else None,
                        "ground_count": int(len(ground_h)), "roof_count": int(len(roof_h))})
    return out


def tracks(lines: list[str]) -> None:
    """data/geo/build/lidar_tracks.json from the ATL03 photons of the store."""
    import numpy as np
    from geodata.projection import Projection
    manifest = geostore.load(MANIFEST)
    origin = json.loads(WORLD.read_text(encoding="utf-8"))["origin"]
    proj = Projection(float(origin["utm_e"]), float(origin["utm_n"]))
    points = []
    for product, kind in (("atl03_ground", "ground"), ("atl03_roof", "roof")):
        for key in sorted(k for k in manifest.get("files", {}) if k.split("/")[0] == product):
            rows = geostore.get(manifest, key)["points"]
            if not rows:
                continue
            xs, zs = proj.to_game(np.array([r[0] for r in rows]), np.array([r[1] for r in rows]))
            points += [(r[2], float(x), float(z), float(r[4]), kind) for r, x, z in zip(rows, xs, zs)]
    bins = track_bins(points)
    head = {"note": "Made by tools/geo/lidar.py tracks (plan 0009, R5a; report 0009, D-0009-06): the short form of the "
                    "ATL03 photons of the store. For each 20 m of a track (a date and a beam): the middle in the "
                    "coordinates of the game, the median height of the ground photons and of the roof photons over "
                    "EGM2008, and their counts. The data of NASA (ICESat-2) is free to use.",
            "bin_m": BIN_M, "columns": ["date", "x", "z", "ground", "roof", "ground_count", "roof_count"]}
    text = json.dumps(head, ensure_ascii=False, indent="\t")[:-2] + ',\n\t"bins": [\n' + ",\n".join(
        json.dumps([b["date"], b["x"], b["z"], b["ground"], b["roof"], b["ground_count"], b["roof_count"]])
        for b in bins) + "\n\t]\n}\n"
    TRACKS.write_text(text, encoding="utf-8")
    lines.append(f"- the short form: {len(bins)} bins of {BIN_M:.0f} m from {len(points)} photons "
                 f"({TRACKS.stat().st_size // 1024} KB, data/geo/build/lidar_tracks.json)")


def report(lines: list[str]) -> None:
    """The points at the head (the manifest), and R5c: ATL24 against the
    intertidal heights and GEBCO, with a map."""
    import numpy as np
    manifest = geostore.load(MANIFEST)
    lines += ["", "## The points in the store (the head of the branch)", "",
              "| Product | " + " | ".join(str(y) for y in range(2018, dt.date.today().year + 1)) + " | All |",
              "|---" * (dt.date.today().year - 2018 + 3) + "|"]
    for product in PRODUCTS:
        years = by_year(manifest, product)
        lines.append(f"| {product} | " + " | ".join(str(years.get(y, "–")) for y in range(2018, dt.date.today().year + 1))
                     + f" | {total(manifest, product)} |")
    # D-0009-09: the passes (the dates) of each product and year, and the years that are not complete.
    lines += ["", "## The passes of each product and year (D-0009-09)", "",
              "A year is complete when ATL08 has each pass of the ATL03 ground photons, and the ground photons each "
              "pass of ATL08 and of the roof photons. ATL24 (passes over the water only) and GEDI (another satellite) "
              "are not compared. The next run asks again for a product of a year that is not complete.", "",
              "| Product | " + " | ".join(str(y) for y in range(2018, dt.date.today().year + 1)) + " | All |",
              "|---" * (dt.date.today().year - 2018 + 3) + "|"]
    for product in PRODUCTS:
        counts = [len(passes_of(manifest, f"{product}/{y}")) if f"{product}/{y}" in manifest.get("files", {}) else None
                  for y in range(2018, dt.date.today().year + 1)]
        lines.append(f"| {product} | " + " | ".join("–" if c is None else str(c) for c in counts)
                     + f" | {sum(c or 0 for c in counts)} |")
    for y in range(2018, dt.date.today().year + 1):
        passes = {p: set(passes_of(manifest, f"{p}/{y}")) for p in LAND if f"{p}/{y}" in manifest.get("files", {})}
        missing = incomplete_products(passes)
        if missing:
            lines.append(f"- {y} is not complete: {', '.join(sorted(missing))} "
                         f"(ATL03 {sorted(passes.get('atl03_ground', []))}, ATL08 {sorted(passes.get('atl08', []))})")
    keys = sorted(k for k in manifest.get("files", {}) if k.startswith("atl24/"))
    if not keys:
        lines.append("- R5c: no points of ATL24 yet")
        return
    import rasterio
    from rasterio.warp import transform
    points = [p for k in keys for p in geostore.get(manifest, k)["points"]]
    lon = np.array([p[0] for p in points])
    lat = np.array([p[1] for p in points])
    # Plan 0009, R5b: one zero for the land and the sea. ATL24 is over EGM2008;
    # the intertidal heights and the sea of the game are over the mean sea level.
    mdt = float(json.loads((ROOT / "data" / "geo" / "ground.json").read_text(encoding="utf-8"))["mean_dynamic_topography_m"])
    depth = np.array([p[4] if p[5] is None else p[5] for p in points], dtype=float) - mdt
    out = ["", "## R5c: the sea floor", "",
           f"ATL24 over the mean sea level (its height over EGM2008 minus {mdt:.2f} m, the mean dynamic topography of "
           "DTU22, plan 0009, R5b) minus the source.", "",
           "| Source | Points | Mean difference (m) | RMSE (m) |", "|---|---|---|---|"]
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
        geostore.write_keep_import(MAP)
        lines.append(f"- the map of the depths of ATL24: {MAP.name}")
    except Exception as error:  # noqa: BLE001
        lines.append(f"- the map: {error}")


DTU_MDT = "https://ftp.space.dtu.dk/pub/DTU22/MDT/dtu22mdt.grd.gz"
DTU_MDT_ERR = "https://ftp.space.dtu.dk/pub/DTU22/MDT/dtu22mdterr.grd.gz"
DTU_MSS = "https://ftp.space.dtu.dk/pub/DTU21/1_MIN/DTU21MSS_1min_WGS84.nc.zip"
# The parts of the comparison (west, south, east, north): Bãi Trước and the bay in front of it, and Bãi Sau.
MDT_PARTS = {"Bãi Trước": (107.040, 10.315, 107.085, 10.360), "Bãi Sau": (107.085, 10.320, 107.130, 10.420)}


def download(url: str) -> Path:
    """A file of DTU in build/geodata/cache/ (it downloads one time)."""
    import urllib.request
    path = geostore.CACHE / url.rsplit("/", 1)[1]
    if not path.exists():
        geostore.CACHE.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(url, headers={"User-Agent": geostore.AGENT})
        with urllib.request.urlopen(request, timeout=900) as response, open(path.with_suffix(".part"), "wb") as out:
            while chunk := response.read(1 << 20):
                out.write(chunk)
        path.with_suffix(".part").rename(path)
    return path


def gravsoft(path: Path):
    """A grid in the GRAVSOFT text form of DTU (gzip): the header is south, north,
    west, east, the step of the latitude, the step of the longitude; the rows go
    from north to south. Returns a function (lon, lat) -> value (bilinear)."""
    import gzip
    import numpy as np
    values = np.array(gzip.decompress(path.read_bytes()).split(), dtype=float)
    south, north, west, east, dlat, dlon = values[:6]
    rows, cols = int(round((north - south) / dlat)) + 1, int(round((east - west) / dlon)) + 1
    grid = values[6:6 + rows * cols].reshape(rows, cols)

    def at(lon, lat):
        y = (north - np.asarray(lat)) / dlat
        x = (np.asarray(lon) % 360.0 - west) / dlon
        y0, x0 = np.floor(y).astype(int), np.floor(x).astype(int)
        fy, fx = y - y0, x - x0
        return (grid[y0, x0] * (1 - fx) * (1 - fy) + grid[y0, x0 + 1] * fx * (1 - fy)
                + grid[y0 + 1, x0] * (1 - fx) * fy + grid[y0 + 1, x0 + 1] * fx * fy)
    return at


def mdt(lines: list[str]) -> None:
    """D-0009-07: the mean sea level over EGM2008 at the points of ATL24 of R5c."""
    import zipfile
    import numpy as np
    import rasterio
    from rasterio.warp import transform
    from scipy.spatial import cKDTree
    manifest = geostore.load(MANIFEST)
    points = [p for k in sorted(manifest["files"]) if k.startswith("atl24/") for p in geostore.get(manifest, k)["points"]]
    lon = np.array([p[0] for p in points])
    lat = np.array([p[1] for p in points])
    depth = np.array([p[4] if p[5] is None else p[5] for p in points], dtype=float)
    with rasterio.open(ROOT / "data" / "geo" / "raw" / "intertidal.tif") as src:
        xs, ys = transform("EPSG:4326", src.crs, list(lon), list(lat))
        tidal = np.array([v[0] for v in src.sample(zip(xs, ys))], dtype=float)
        ok = np.isfinite(tidal) & (tidal != (src.nodata if src.nodata is not None else -9999))
    lon, lat, diff = lon[ok], lat[ok], (depth - tidal)[ok]
    parts = {name: (lon >= w) & (lon <= e) & (lat >= s) & (lat <= n) for name, (w, s, e, n) in MDT_PARTS.items()}
    parts["the other points"] = ~np.logical_or.reduce(list(parts.values()))
    parts["all of R5c"] = np.ones_like(lon, dtype=bool)
    model = gravsoft(download(DTU_MDT))(lon, lat)
    error = gravsoft(download(DTU_MDT_ERR))(lon, lat)
    # DTU21MSS (over the WGS 84 ellipsoid) minus EGM2008: the geoid from the photons of ATL03.
    archive = download(DTU_MSS)
    nc = archive.with_suffix("")
    if not nc.exists():
        with zipfile.ZipFile(archive) as z:
            nc.write_bytes(z.read(nc.name))
    with rasterio.open(f'netcdf:"{nc}":mean_sea_surf_sol2') as src:
        rows, cols = rasterio.transform.rowcol(src.transform, lon % 360.0, lat)
        window = rasterio.windows.Window(min(cols), min(rows), max(cols) - min(cols) + 1, max(rows) - min(rows) + 1)
        block = src.read(1, window=window).astype(float) * float(src.scales[0] or 1.0)
        mss = block[np.array(rows) - min(rows), np.array(cols) - min(cols)]
    ground = [(p[0], p[1], p[3] - p[4]) for k in sorted(manifest["files"]) if k.startswith("atl03_ground/")
              for p in geostore.get(manifest, k)["points"] if p[3] is not None and p[4] is not None]
    g = np.array(ground)
    _, near = cKDTree(g[:, :2]).query(np.c_[lon, lat], k=30)
    geoid = g[near, 2].mean(axis=1)
    msl = mss - geoid
    lines += ["## D-0009-07: the mean sea level over EGM2008 (R5c)", "",
              "ATL24 is over EGM2008 and the intertidal heights are over the mean sea level, so ATL24 minus the "
              "intertidal height is the mean sea level over EGM2008 if both sources are correct.", "",
              "| Points | ATL24 minus intertidal (m) | DTU22MDT (m) | Error of DTU22MDT (m) | DTU21MSS minus EGM2008 (m) | "
              "Rest: ATL24 minus intertidal minus DTU22MDT (m) |", "|---|---|---|---|---|---|"]
    for name, mask in parts.items():
        if mask.any():
            lines.append(f"| {name}: {int(mask.sum())} | {diff[mask].mean():.2f} (median {np.median(diff[mask]):.2f}) | "
                         f"{model[mask].mean():.2f} | {error[mask].mean():.2f} | {msl[mask].mean():.2f} | "
                         f"{(diff[mask] - model[mask]).mean():.2f} |")
    lines += ["", "- The parts (west, south, east, north): " + "; ".join(f"{k} {v}" for k, v in MDT_PARTS.items()) + ".",
              "- DTU22MDT: Knudsen and others (DTU Space), " + DTU_MDT + "; DTU21MSS: " + DTU_MSS + ".",
              "- The geoid EGM2008 at each point: the mean of height minus height_egm2008 of the 30 nearest ground "
              "photons of ATL03 (the PROJ grid of the fetch).",
              "- DTU21MSS is a mean of 1993 to 2012 and has the mean-tide system; EGM2008 and ATL24 have the "
              "tide-free system. At 10° N the two systems of the geoid differ by about (1 + 0.3) × (9.9 − 29.6 "
              "sin² 10°) cm = 0.12 m. The sea level of the South China Sea goes up about 4 mm each year, so the "
              "mean of 2018 to 2025 is about 0.06 m over the mean of 1993 to 2012."]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["fetch", "seed", "tracks", "report", "mdt"])
    parser.add_argument("commits", nargs="*")
    parser.add_argument("--allow-fewer", action="store_true", help="a product may have fewer points than before")
    parser.add_argument("--refetch", action="store_true", help="ask for all the years again")
    args = parser.parse_args()
    lines = [f"## lidar {args.command} ({dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%d %H:%M')} UTC)", ""]
    errors: list[str] = []
    try:
        if args.command == "fetch":
            errors = fetch(lines, args.allow_fewer, args.refetch)
        elif args.command == "seed":
            errors = seed(lines, args.commits)
        elif args.command == "tracks":
            tracks(lines)
        elif args.command == "mdt":
            mdt(lines)
        else:
            report(lines)
    except Exception as error:  # noqa: BLE001 - the report says what failed
        lines.append(f"- ERROR: {error}")
        lines += ["    " + t for t in traceback.format_exc().splitlines()[-6:]]
        errors.append(str(error))
    RAW.mkdir(parents=True, exist_ok=True)
    (RAW / f"{args.command}.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    parts = [(RAW / f"{c}.md").read_text(encoding="utf-8") for c in ("seed", "fetch", "tracks", "report", "mdt")
             if (RAW / f"{c}.md").exists()]
    REPORT.write_text("# The lidar points of the play area (plan 0009, R5a and R5c)\n\nMade by `tools/geo/lidar.py`. Do not change by hand.\n\n"
                      + "\n".join(parts), encoding="utf-8")
    print("\n".join(lines))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
