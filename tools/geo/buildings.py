#!/usr/bin/env python3
"""The buildings of the play area (plan 0009, R1 and R5d). CI only: the
workspace cannot reach the sources (plan 0009, D2 and D9).

    python tools/geo/buildings.py outlines   # Overture Maps (with OpenStreetMap and Google Open Buildings v3)
    python tools/geo/buildings.py temporal   # Google Open Buildings 2.5D Temporal: the rasters of 2016 to 2023
    python tools/geo/buildings.py osm2019    # OpenStreetMap on 2019-01-22 (the ohsome API, R5d)
    python tools/geo/buildings.py build      # buildings_2019.json and buildings_report.md (no network)
    python tools/geo/buildings.py all

Each part writes its files in data/geo/raw/buildings/ and its lines of the
report in data/geo/raw/buildings/<part>.md: what it found, and each error. A
part that fails does not stop the others, so that the first runs in CI show
the formats of the sources.

- The outlines (R1): the buildings theme of Overture Maps in the box of
  data/geo/area.json. It joins OpenStreetMap, Microsoft, and Google Open
  Buildings v3 (the "sources" of each outline), so an outline of Google is
  there where OpenStreetMap has none.
- The heights and the years (R1, D10): the rasters of Open Buildings 2.5D
  Temporal (the public bucket open-buildings-temporal-data, version v1) for
  each year from 2016 to 2023. For each outline: the median of building_height
  of its pixels where building_presence is more than PRESENCE (a builder value
  for the report), and the first year in which it has a building.
- OpenStreetMap of 2019 (R5d): the buildings of OpenStreetMap on 2019-01-22,
  with their tags (start_date, building=construction).

The 2.5D data and the outlines are CC BY 4.0 and ODbL (data/geo/LICENSE).
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import os
import re
import sys
import time
import traceback
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "geo"))

AREA = ROOT / "data" / "geo" / "area.json"
WORLD = ROOT / "data" / "geo" / "build" / "world.json"
RAW = ROOT / "data" / "geo" / "raw" / "buildings"
OUT = ROOT / "data" / "geo" / "build" / "buildings_2019.json"
REPORT = ROOT / "data" / "geo" / "build" / "buildings_report.md"
AGENT = "vung-tau-geodata/1"
OVERTURE = "https://overturemaps-us-west-2.s3.us-west-2.amazonaws.com"
TEMPORAL_BUCKET = "open-buildings-temporal-data"
GCS_LIST = "https://storage.googleapis.com/storage/v1/b/{bucket}/o"
GCS_FILE = "https://storage.googleapis.com/{bucket}/{name}"
OHSOME = "https://api.ohsome.org/v1/elements/geometry"
YEARS = list(range(2016, 2024))
# A pixel of the 2.5D data is a building where building_presence is more than this (a builder value, R1).
PRESENCE = 0.5
OSM_DATE = "2019-01-22"


def bbox() -> dict:
    return json.loads(AREA.read_text(encoding="utf-8"))["bbox"]


def get(url: str, data: bytes | None = None, headers: dict | None = None, tries: int = 4, timeout: int = 120) -> bytes:
    for attempt in range(tries):
        try:
            request = urllib.request.Request(url, data=data, headers={"User-Agent": AGENT, **(headers or {})})
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            if error.code in (400, 401, 403, 404) or attempt == tries - 1:
                raise
            time.sleep(2 ** attempt * 3)
        except Exception:  # noqa: BLE001 - a network error: try again
            if attempt == tries - 1:
                raise
            time.sleep(2 ** attempt * 3)
    raise RuntimeError("not reached")


class Notes:
    """The lines of the report of a part."""

    def __init__(self, part: str):
        self.part = part
        self.lines: list[str] = [f"## {part} ({dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%d %H:%M')} UTC)", ""]

    def add(self, text: str) -> None:
        print(f"[{self.part}] {text}")
        self.lines.append(f"- {text}")

    def save(self) -> None:
        RAW.mkdir(parents=True, exist_ok=True)
        (RAW / f"{self.part}.md").write_text("\n".join(self.lines) + "\n", encoding="utf-8")


def projection():
    from geodata.projection import Projection
    origin = json.loads(WORLD.read_text(encoding="utf-8"))["origin"]
    return Projection(float(origin["utm_e"]), float(origin["utm_n"]))


# ----- the outlines (Overture Maps) -----


def _s3_list(prefix: str, folders: bool = False) -> list[str]:
    found, token = [], None
    while True:
        query = {"list-type": "2", "prefix": prefix}
        if folders:
            query["delimiter"] = "/"
        if token:
            query["continuation-token"] = token
        text = get(f"{OVERTURE}/?{urllib.parse.urlencode(query)}").decode("utf-8")
        found += re.findall(r"<Prefix>([^<]+)</Prefix>" if folders else r"<Key>([^<]+)</Key>", text)
        match = re.search(r"<NextContinuationToken>([^<]+)</NextContinuationToken>", text)
        if not match:
            return found
        token = match.group(1)


def part_outlines(notes: Notes) -> None:
    import duckdb
    box = bbox()
    releases = sorted(re.findall(r"^release/([0-9]{4}-[0-9]{2}-[0-9]{2}\.[0-9]+)/$", "\n".join(_s3_list("release/", True)), re.M))
    release = releases[-1]
    notes.add(f"the release of Overture Maps: {release}")
    con = duckdb.connect()
    for statement in ("INSTALL spatial", "LOAD spatial", "INSTALL httpfs", "LOAD httpfs"):
        con.execute(statement)
    keys = _s3_list(f"release/{release}/theme=buildings/type=building/")
    urls = [f"{OVERTURE}/{key}" for key in keys if key.endswith(".parquet")]
    rows = con.execute(
        f"""
        SELECT id, height, num_floors, sources, ST_AsGeoJSON(geometry)
        FROM read_parquet({urls!r})
        WHERE bbox.xmin > {box['west']} AND bbox.xmax < {box['east']}
          AND bbox.ymin > {box['south']} AND bbox.ymax < {box['north']}
        """
    ).fetchall()
    proj = projection()
    result = []
    by_source: dict[str, int] = {}
    for overture_id, height, floors, sources, geometry in rows:
        shape = json.loads(geometry)
        if shape["type"] != "Polygon":
            continue
        ring = shape["coordinates"][0]
        xs, zs = proj.to_game([p[0] for p in ring], [p[1] for p in ring])
        datasets = sorted({str(s.get("dataset", "")) for s in (sources or []) if isinstance(s, dict)})
        for name in datasets:
            by_source[name] = by_source.get(name, 0) + 1
        result.append([overture_id, datasets, height, floors,
                       [v for x, z in zip(xs, zs) for v in (round(float(x), 1), round(float(z), 1))]])
    result.sort(key=lambda r: (r[4][1], r[4][0]))
    RAW.mkdir(parents=True, exist_ok=True)
    head = {"note": "Made by tools/geo/buildings.py outlines (plan 0009, R1). The buildings theme of Overture Maps in the box of data/geo/area.json: id, sources, height, floors, outline (x and z of the game, flat). ODbL (OpenStreetMap contributors, Overture Maps Foundation, Microsoft, Google).",
            "release": release, "bbox": box, "columns": ["id", "sources", "height", "floors", "outline"]}
    text = json.dumps(head, ensure_ascii=False, indent="\t")[:-2] + ',\n\t"buildings": [\n' + \
        ",\n".join(json.dumps(r, ensure_ascii=False) for r in result) + "\n\t]\n}\n"
    (RAW / "overture.json").write_text(text, encoding="utf-8")
    notes.add(f"{len(result)} outlines; by source: {by_source}")


# ----- the 2.5D rasters (Open Buildings 2.5D Temporal) -----


def gcs_list(prefix: str, delimiter: str | None = "/", limit: int = 20) -> tuple[list[str], list[dict]]:
    """The folders and the objects of the public bucket under a prefix (at most limit pages)."""
    folders, objects, token = [], [], None
    for _ in range(limit):
        query = {"prefix": prefix, "maxResults": "1000"}
        if delimiter:
            query["delimiter"] = delimiter
        if token:
            query["pageToken"] = token
        data = json.loads(get(GCS_LIST.format(bucket=TEMPORAL_BUCKET) + "?" + urllib.parse.urlencode(query)))
        folders += data.get("prefixes", [])
        objects += data.get("items", [])
        token = data.get("nextPageToken")
        if not token:
            break
    return folders, objects


def part_temporal(notes: Notes) -> None:
    """Finds the GeoTIFF of each year that covers the play area, reads a window
    of it, and keeps the window as a GeoTIFF in data/geo/raw/buildings/."""
    import rasterio
    from rasterio.windows import from_bounds
    from rasterio.warp import transform_bounds
    box = bbox()
    top, _ = gcs_list("")
    notes.add(f"the folders of the bucket: {top[:20]}")
    version = "v1/" if "v1/" in top else (top[0] if top else "")
    folders, objects = gcs_list(version)
    notes.add(f"the folders of {version}: {folders[:30]} ({len(objects)} objects)")
    # The manifests of the S2 cell 31 (level 2), as the download notebook of Google.
    candidates = []
    for folder in folders:
        sub_folders, sub_objects = gcs_list(folder)
        names = [o["name"] for o in sub_objects]
        notes.add(f"{folder}: {len(sub_folders)} folders, {len(names)} objects; first: {names[:5]} {sub_folders[:5]}")
        candidates += [n for n in names if re.search(r"(^|[/_])31[_./]", n) or "manifest" in n.lower()]
        for sub in sub_folders:
            if re.search(r"(^|[/_])31[_./]|/31/", sub):
                _, deeper = gcs_list(sub, None, 5)
                candidates += [o["name"] for o in deeper]
    notes.add(f"{len(candidates)} files of the cell 31 or manifests; first: {candidates[:10]}")
    tifs = [n for n in candidates if n.lower().endswith((".tif", ".tiff"))]
    manifests = [n for n in candidates if not n.lower().endswith((".tif", ".tiff"))]
    for name in manifests[:20]:
        text = get(GCS_FILE.format(bucket=TEMPORAL_BUCKET, name=urllib.parse.quote(name))).decode("utf-8", "replace")
        notes.add(f"the manifest {name}: {len(text)} bytes; the start: {text[:300]!r}")
        tifs += [t.strip() for t in re.findall(r"[\w./-]+\.tiff?", text)]
    tifs = list(dict.fromkeys(t.replace(f"gs://{TEMPORAL_BUCKET}/", "") for t in tifs))
    notes.add(f"{len(tifs)} GeoTIFF files to try")
    os.environ.setdefault("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")
    kept = 0
    for name in tifs:
        url = "/vsicurl/" + GCS_FILE.format(bucket=TEMPORAL_BUCKET, name=name)
        try:
            with rasterio.open(url) as src:
                west, south, east, north = transform_bounds("EPSG:4326", src.crs, box["west"], box["south"], box["east"], box["north"])
                b = src.bounds
                if b.right < west or b.left > east or b.top < south or b.bottom > north:
                    continue
                window = from_bounds(max(west, b.left), max(south, b.bottom), min(east, b.right), min(north, b.top), src.transform)
                data = src.read(window=window)
                profile = src.profile.copy()
                profile.update(height=data.shape[1], width=data.shape[2], transform=src.window_transform(window),
                               driver="GTiff", compress="deflate")
                year = re.search(r"(20[12][0-9])", name)
                out = RAW / f"temporal_{year.group(1) if year else 'x'}_{kept:03d}.tif"
                with rasterio.open(out, "w", **profile) as dst:
                    dst.write(data)
                    dst.descriptions = src.descriptions
                notes.add(f"kept {out.name} from {name}: bands {src.descriptions}, {data.shape}, {src.crs}")
                kept += 1
        except Exception as error:  # noqa: BLE001 - try the next file
            notes.add(f"{name}: {error}")
    notes.add(f"{kept} windows kept")


# ----- OpenStreetMap on 2019-01-22 (the ohsome API) -----


def part_osm2019(notes: Notes) -> None:
    box = bbox()
    body = urllib.parse.urlencode({
        "bboxes": f"{box['west']},{box['south']},{box['east']},{box['north']}",
        "time": OSM_DATE,
        "filter": "building=* and geometry:polygon",
        "properties": "tags,metadata",
    }).encode()
    data = json.loads(get(OHSOME, data=body, headers={"Content-Type": "application/x-www-form-urlencoded"}, timeout=600))
    features = data.get("features", [])
    proj = projection()
    rows = []
    construction = 0
    for f in features:
        props = f.get("properties", {})
        geometry = f.get("geometry", {})
        ring = geometry.get("coordinates", [[]])[0] if geometry.get("type") == "Polygon" else []
        if not ring:
            continue
        xs, zs = proj.to_game([p[0] for p in ring], [p[1] for p in ring])
        tags = {k: v for k, v in props.items() if not k.startswith("@")}
        construction += 1 if tags.get("building") == "construction" else 0
        rows.append([props.get("@osmId", ""), tags, [v for x, z in zip(xs, zs) for v in (round(float(x), 1), round(float(z), 1))]])
    RAW.mkdir(parents=True, exist_ok=True)
    head = {"note": "Made by tools/geo/buildings.py osm2019 (plan 0009, R5d): the buildings of OpenStreetMap on 2019-01-22 from the ohsome API, with their tags. (c) OpenStreetMap contributors, ODbL.",
            "date": OSM_DATE, "bbox": box, "columns": ["osm", "tags", "outline"]}
    text = json.dumps(head, ensure_ascii=False, indent="\t")[:-2] + ',\n\t"buildings": [\n' + \
        ",\n".join(json.dumps(r, ensure_ascii=False) for r in rows) + "\n\t]\n}\n"
    (RAW / "osm2019.json").write_text(text, encoding="utf-8")
    notes.add(f"{len(rows)} buildings of OpenStreetMap on {OSM_DATE}, {construction} with building=construction")


# ----- the build (no network) -----


def part_build(notes: Notes) -> None:
    """buildings_2019.json from the outlines and the windows of the 2.5D rasters,
    and the report of all parts."""
    import numpy as np
    from shapely.geometry import Polygon, box as shapely_box
    outlines_path = RAW / "overture.json"
    lines = ["# The buildings of the play area (plan 0009, R1 and R5d)", "",
             "Made by `tools/geo/buildings.py`. Do not change by hand. The parts of the last runs are below.", ""]
    if outlines_path.exists():
        outlines = json.loads(outlines_path.read_text(encoding="utf-8"))["buildings"]
        notes.add(f"{len(outlines)} outlines of Overture Maps")
        tifs = sorted(RAW.glob("temporal_*.tif"))
        heights: dict[str, dict[int, float]] = {}
        if tifs:
            import rasterio
            import rasterio.warp
            from rasterio.features import geometry_mask
            proj = projection()
            for path in tifs:
                year_match = re.search(r"temporal_(20[0-9]{2})_", path.name)
                if not year_match:
                    continue
                year = int(year_match.group(1))
                with rasterio.open(path) as src:
                    names = [str(d or "").lower() for d in src.descriptions]
                    presence = src.read(names.index("building_presence") + 1) if "building_presence" in names else src.read(1)
                    height = src.read(names.index("building_height") + 1) if "building_height" in names else src.read(min(2, src.count))
                    for oid, _sources, _h, _f, flat in outlines:
                        xs, zs = flat[0::2], flat[1::2]
                        lon, lat = proj.game_to_lonlat(np.array(xs), np.array(zs))
                        ring = list(zip(*rasterio.warp.transform("EPSG:4326", src.crs, list(lon), list(lat))))
                        poly = Polygon(ring)
                        if not poly.intersects(shapely_box(*src.bounds)):
                            continue
                        mask = ~geometry_mask([poly.__geo_interface__], out_shape=presence.shape, transform=src.transform, all_touched=False)
                        sure = mask & (presence > PRESENCE)
                        if sure.sum() > 0:
                            heights.setdefault(oid, {})[year] = float(np.median(height[sure]))
            notes.add(f"heights from {len(tifs)} windows of the 2.5D rasters for {len(heights)} outlines")
        result = []
        removed = 0
        for oid, sources, h, floors, flat in outlines:
            years = heights.get(oid, {})
            first = min(years) if years else None
            if first is not None and first > 2019:
                removed += 1
                continue
            result.append({"id": oid, "sources": sources, "outline": [flat[i:i + 2] for i in range(0, len(flat), 2)],
                           "height": round(years[2019], 1) if 2019 in years else h,
                           "height_source": "Open Buildings 2.5D Temporal 2019" if 2019 in years else ("Overture" if h else None),
                           "floors": floors, "first_year": first})
        OUT.write_text(json.dumps({"note": "Made by tools/geo/buildings.py build (plan 0009, R1). Do not change by hand. ODbL; the heights of Open Buildings 2.5D Temporal: CC BY 4.0.",
                                   "presence": PRESENCE, "buildings": result}, ensure_ascii=False) + "\n", encoding="utf-8")
        notes.add(f"{len(result)} buildings in buildings_2019.json, {removed} first show after 2019 and are out")
        lines += [f"{len(result)} buildings of 2019, {removed} removed (first year after 2019).", ""]
    for part in ("outlines", "temporal", "osm2019"):
        path = RAW / f"{part}.md"
        if path.exists():
            lines += [path.read_text(encoding="utf-8"), ""]
    notes.save()
    lines += [(RAW / "build.md").read_text(encoding="utf-8")]
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")


PARTS = {"outlines": part_outlines, "temporal": part_temporal, "osm2019": part_osm2019, "build": part_build}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("part", choices=list(PARTS) + ["all"])
    args = parser.parse_args()
    failed = 0
    for name in (list(PARTS) if args.part == "all" else [args.part]):
        notes = Notes(name)
        try:
            PARTS[name](notes)
        except Exception as error:  # noqa: BLE001 - the report says what failed, and the next part runs
            notes.add(f"ERROR: {error}")
            for line in traceback.format_exc().splitlines()[-6:]:
                notes.add(f"    {line}")
            failed += 1
        if name != "build":
            notes.save()
    return 1 if failed and args.part != "all" else 0


if __name__ == "__main__":
    sys.exit(main())
