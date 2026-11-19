#!/usr/bin/env python3
"""The buildings of the play area (plan 0009, R1 and R5d). The workflow
"Buildings and lidar" runs it in CI and commits the files; on 2026-11-19 the
workspace also reached Overture Maps, the bucket of the 2.5D data, and the
ohsome API (pip install duckdb).

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
  each year from 2016 to 2023, read from the tiles of the manifests of the
  UTM zone of the area. For each outline: the median of building_height of its
  pixels where building_presence is more than PRESENCE (a builder value for the
  report), with the outlines moved by the shift of the raster of the year, and
  the first year in which it has a building (at least MIN_PIXELS pixels).
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
OHSOME = "https://api.ohsome.org/v1/elementsFullHistory/geometry"
YEARS = list(range(2016, 2024))
# A pixel of the 2.5D data is a building where building_presence is more than this (a builder value, R1).
PRESENCE = 0.5
OSM_DATE = "2019-01-22"
# The cells of the map of 2019 of the buildings with no outline (m), and the blocks of a read of a tile (pixels).
UNMATCHED_M = 5.0
BLOCK_PX = 1024
# An outline has a building in a year when at least this many of its pixels have a building (a builder value, R1).
MIN_PIXELS = 8
# The shift of the outlines on the rasters of a year: found in a window of SHIFT_WINDOW_M round MIDDLE (lon, lat:
# Bãi Trước and Xóm Lưới), at most SHIFT_M each way.
MIDDLE = (107.0787, 10.3455)
SHIFT_WINDOW_M = 400.0
SHIFT_M = 8.0


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


def utm_epsg(box: dict) -> int:
    """The EPSG code of the UTM zone of the middle of the box (the CRS of the 2.5D tiles)."""
    lon = (box["west"] + box["east"]) / 2.0
    lat = (box["south"] + box["north"]) / 2.0
    return (32600 if lat >= 0 else 32700) + int((lon + 180.0) // 6.0) + 1


def manifest_tiles(manifest: dict, area: tuple[float, float, float, float]) -> list[tuple[str, tuple]]:
    """The GeoTIFF files of a manifest of the 2.5D data that meet the area
    (west, south, east, north in the CRS of the tiles), each with its bounds.
    The name of a file is the uriPrefix of the manifest (without the bucket)
    and its uri, with no "/" between them: the prefix "v1/geotiffs/31" and the
    uri "754_2019_06_30/tile_X.tif" give the folder "31754_2019_06_30" (the
    first run in CI used the uri alone and got HTTP 404 for each file)."""
    prefix = str(manifest.get("uriPrefix", "")).replace(f"gs://{TEMPORAL_BUCKET}/", "")
    west, south, east, north = area
    found = []
    for tileset in manifest.get("tilesets", []):
        for source in tileset.get("sources", []):
            a = source["affineTransform"]
            size = source["dimensions"]
            left, top = float(a["translateX"]), float(a["translateY"])
            right = left + size["width"] * float(a["scaleX"])
            bottom = top + size["height"] * float(a["scaleY"])
            bottom, top = min(bottom, top), max(bottom, top)
            if right > west and left < east and top > south and bottom < north:
                found.append((prefix + source["uris"][0], (left, bottom, right, top)))
    return found


def medians_by_label(labels, heights) -> dict[int, tuple[float, int]]:
    """For each label: the median of its heights and the number of pixels."""
    import numpy as np
    labels = np.asarray(labels)
    heights = np.asarray(heights, dtype=float)
    if labels.size == 0:
        return {}
    order = np.argsort(labels, kind="stable")
    labels, heights = labels[order], heights[order]
    keys, starts, counts = np.unique(labels, return_index=True, return_counts=True)
    return {int(k): (float(np.median(heights[s:s + c])), int(c)) for k, s, c in zip(keys, starts, counts)}


def best_shift(sure, labels, radius: int) -> tuple[int, int, float]:
    """The shift (rows, columns) of the outlines (labels > 0) that puts most of
    them on the pixels with a building (sure), in radius pixels, and the part of
    the pixels of the outlines with a building at that shift."""
    import numpy as np
    inside = labels > 0
    best = (0, 0, -1.0)
    total = max(int(inside.sum()), 1)
    for dr in range(-radius, radius + 1):
        for dc in range(-radius, radius + 1):
            moved = np.roll(np.roll(inside, dr, axis=0), dc, axis=1)
            score = float((moved & sure).sum()) / total
            if score > best[2]:
                best = (dr, dc, score)
    return best


def part_temporal(notes: Notes) -> None:
    """For each outline of overture.json and each year of the 2.5D data: the
    median building_height of its pixels where building_presence is more than
    PRESENCE, and the number of such pixels (temporal.json). The rasters stay
    in the bucket: a window of the play area at 0.5 m is about 5 GB for each
    year. Also a map of 2019 at UNMATCHED_M: the part of each cell where the
    raster has a building and no outline is (temporal_2019_unmatched.tif).
    The rasters are about 3 m south of the outlines (the first run in the
    workspace: red bands of the raster under each outline, and a third of the
    pixels of the buildings out of the outlines), so for each year the part
    finds the shift of the outlines with the best overlap near the middle of the
    town (best_shift(), in SHIFT_M) and moves the outlines by it."""
    import numpy as np
    import rasterio
    import rasterio.warp
    from affine import Affine
    from rasterio.features import rasterize
    from rasterio.transform import from_origin
    from rasterio.warp import transform_bounds
    from rasterio.windows import Window, from_bounds
    from shapely.geometry import Polygon, box as shapely_box
    from shapely.strtree import STRtree
    box = bbox()
    epsg = utm_epsg(box)
    area = transform_bounds("EPSG:4326", f"EPSG:{epsg}", box["west"], box["south"], box["east"], box["north"])
    _, items = gcs_list("v1/manifests/", None, 60)
    names = sorted(i["name"] for i in items if f"_EPSG_{epsg}_" in i["name"])
    notes.add(f"{len(items)} manifests in the bucket; {len(names)} of EPSG:{epsg}: {[n.rsplit('/', 1)[-1] for n in names]}")
    tiles: dict[int, list] = {}
    for name in names:
        year_match = re.search(r"_(20[0-9]{2})_[0-9]{2}_[0-9]{2}\.json$", name)
        if not year_match or int(year_match.group(1)) not in YEARS:
            continue
        manifest = json.loads(get(GCS_FILE.format(bucket=TEMPORAL_BUCKET, name=name), timeout=300))
        tiles.setdefault(int(year_match.group(1)), []).extend(manifest_tiles(manifest, area))
    notes.add("the tiles of the play area: " + ", ".join(f"{y}: {len(t)}" for y, t in sorted(tiles.items())))
    outlines = json.loads((RAW / "overture.json").read_text(encoding="utf-8"))["buildings"]
    proj = projection()
    polygons, ids = [], []
    for oid, _sources, _h, _f, flat in outlines:
        lon, lat = proj.game_to_lonlat(np.array(flat[0::2], dtype=float), np.array(flat[1::2], dtype=float))
        xs, ys = rasterio.warp.transform("EPSG:4326", f"EPSG:{epsg}", list(lon), list(lat))
        poly = Polygon(zip(xs, ys))
        if poly.is_valid and poly.area > 0.5:
            polygons.append(poly)
            ids.append(oid)
    tree = STRtree(polygons)
    notes.add(f"{len(polygons)} outlines in EPSG:{epsg}")
    os.environ.setdefault("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")
    os.environ.setdefault("GDAL_HTTP_MAX_RETRY", "5")
    os.environ.setdefault("GDAL_HTTP_RETRY_DELAY", "3")
    cells = int(UNMATCHED_M / 0.5)
    unmatched_shape = (int(math.ceil((area[3] - area[1]) / UNMATCHED_M)), int(math.ceil((area[2] - area[0]) / UNMATCHED_M)))
    unmatched = np.zeros(unmatched_shape, dtype=np.float32)
    result: dict[str, dict[int, list]] = {}
    started = time.time()
    middle = rasterio.warp.transform("EPSG:4326", f"EPSG:{epsg}", [MIDDLE[0]], [MIDDLE[1]])
    middle = (middle[0][0], middle[1][0])
    shifts = {}
    for year in sorted(tiles):
        all_labels, all_heights = [], []
        read = 0
        # The shift of the outlines of the year: in a window of SHIFT_WINDOW_M round the middle of the town.
        shift = (0, 0, 0.0)
        for name, (left, bottom, right, top) in tiles[year]:
            if not (left <= middle[0] < right and bottom <= middle[1] < top):
                continue
            try:
                with rasterio.open("/vsicurl/" + GCS_FILE.format(bucket=TEMPORAL_BUCKET, name=name)) as src:
                    bands = [str(d or "").lower() for d in src.descriptions]
                    presence_band = bands.index("building_presence") + 1 if "building_presence" in bands else 3
                    half = SHIFT_WINDOW_M / 2.0
                    window = from_bounds(middle[0] - half, middle[1] - half, middle[0] + half, middle[1] + half, src.transform)
                    window = window.round_offsets().round_lengths()
                    transform = src.window_transform(window)
                    shape = (int(window.height), int(window.width))
                    near = tree.query(shapely_box(middle[0] - half, middle[1] - half, middle[0] + half, middle[1] + half))
                    labels = rasterize(((polygons[i], 1) for i in near), out_shape=shape, transform=transform, fill=0, dtype="uint8")
                    shift = best_shift(src.read(presence_band, window=window) > PRESENCE, labels, int(SHIFT_M / 0.5))
            except Exception as error:  # noqa: BLE001 - no shift for the year
                notes.add(f"{year}: the shift: {type(error).__name__}: {str(error)[:200]}")
        shifts[year] = shift
        notes.add(f"{year}: the outlines move {shift[0] * 0.5:+.1f} m down and {shift[1] * 0.5:+.1f} m right on the raster "
                  f"(at that shift {shift[2] * 100:.0f} % of the pixels of the outlines near the middle have a building)")
        # A label at pixel p goes to pixel p + shift: the transform of the rasterize takes the shift away.
        moved = Affine.translation(-shift[1], -shift[0])
        for name, _bounds in tiles[year]:
            try:
                with rasterio.open("/vsicurl/" + GCS_FILE.format(bucket=TEMPORAL_BUCKET, name=name)) as src:
                    bands = [str(d or "").lower() for d in src.descriptions]
                    presence_band = bands.index("building_presence") + 1 if "building_presence" in bands else 3
                    height_band = bands.index("building_height") + 1 if "building_height" in bands else 2
                    b = src.bounds
                    full = from_bounds(max(area[0], b.left), max(area[1], b.bottom), min(area[2], b.right), min(area[3], b.top), src.transform)
                    full = full.round_offsets().round_lengths()
                    for row in range(int(full.row_off), int(full.row_off + full.height), BLOCK_PX):
                        for col in range(int(full.col_off), int(full.col_off + full.width), BLOCK_PX):
                            window = Window(col, row, min(BLOCK_PX, int(full.col_off + full.width) - col), min(BLOCK_PX, int(full.row_off + full.height) - row))
                            left, top = src.transform * (window.col_off, window.row_off)
                            right, bottom = src.transform * (window.col_off + window.width, window.row_off + window.height)
                            near = tree.query(shapely_box(left, bottom, right, top))
                            if len(near) == 0:
                                continue
                            transform = src.window_transform(window)
                            shape = (int(window.height), int(window.width))
                            labels = rasterize(((polygons[i], int(i) + 1) for i in near), out_shape=shape, transform=transform * moved,
                                               fill=0, dtype="int32")
                            presence = src.read(presence_band, window=window)
                            sure = presence > PRESENCE
                            if not sure.any():
                                continue
                            height = src.read(height_band, window=window)
                            take = sure & (labels > 0) & (height > -90.0)
                            all_labels.append(labels[take] - 1)
                            all_heights.append(height[take])
                            read += 1
                            if year == 2019:
                                lone = (sure & (labels == 0)).astype(np.float32)
                                h, w = (lone.shape[0] // cells) * cells, (lone.shape[1] // cells) * cells
                                if h and w:
                                    part = lone[:h, :w].reshape(h // cells, cells, w // cells, cells).mean(axis=(1, 3))
                                    r0 = int((area[3] - top) / UNMATCHED_M)
                                    c0 = int((left - area[0]) / UNMATCHED_M)
                                    r1, c1 = min(unmatched.shape[0], r0 + part.shape[0]), min(unmatched.shape[1], c0 + part.shape[1])
                                    if r1 > max(r0, 0) and c1 > max(c0, 0):
                                        unmatched[max(r0, 0):r1, max(c0, 0):c1] = np.maximum(
                                            unmatched[max(r0, 0):r1, max(c0, 0):c1], part[max(0, -r0):r1 - r0, max(0, -c0):c1 - c0])
            except Exception as error:  # noqa: BLE001 - the next tile
                notes.add(f"{year} {name}: {type(error).__name__}: {str(error)[:300]}")
        found = medians_by_label(np.concatenate(all_labels) if all_labels else [], np.concatenate(all_heights) if all_heights else [])
        for index, (median, count) in found.items():
            result.setdefault(ids[index], {})[year] = [round(median, 1), count]
        notes.add(f"{year}: {len(tiles[year])} tiles, {read} blocks with buildings, {len(found)} outlines with a building "
                  f"({time.time() - started:.0f} s)")
    RAW.mkdir(parents=True, exist_ok=True)
    head = {"note": "Made by tools/geo/buildings.py temporal (plan 0009, R1): for each outline of overture.json, for each year of Open Buildings 2.5D Temporal, the median building_height (m) of its pixels where building_presence is more than presence, and the number of these pixels of 0.5 m, with the outlines moved by the shift of the year (m down and right on the raster). CC BY 4.0 (Google).",
            "presence": PRESENCE, "crs": f"EPSG:{epsg}",
            "shifts": {str(y): [v[0] * 0.5, v[1] * 0.5, round(v[2], 3)] for y, v in sorted(shifts.items())},
            "columns": ["id", "years: [height, pixels]"]}
    rows = [[oid, {str(y): v for y, v in sorted(years.items())}] for oid, years in sorted(result.items())]
    text = json.dumps(head, ensure_ascii=False, indent="\t")[:-2] + ',\n\t"heights": [\n' + \
        ",\n".join(json.dumps(r, ensure_ascii=False) for r in rows) + "\n\t]\n}\n"
    (RAW / "temporal.json").write_text(text, encoding="utf-8")
    profile = {"driver": "GTiff", "dtype": "uint8", "count": 1, "width": unmatched.shape[1], "height": unmatched.shape[0],
               "crs": f"EPSG:{epsg}", "transform": from_origin(area[0], area[3], UNMATCHED_M, UNMATCHED_M), "compress": "deflate"}
    with rasterio.open(RAW / "temporal_2019_unmatched.tif", "w", **profile) as dst:
        dst.write((unmatched * 100.0).round().astype(np.uint8), 1)
    notes.add(f"{len(rows)} outlines with a building in a year; the map of 2019 of the buildings with no outline: "
              f"{int((unmatched > 0.5).sum())} cells of {UNMATCHED_M:.0f} m more than half building")


# ----- OpenStreetMap on 2019-01-22 (the ohsome API) -----


def osm_rows(features: list[dict], start: str) -> list[dict]:
    """The features of elementsFullHistory/geometry that are valid at the start
    of the time span (their @validFrom is the start): the buildings on that day."""
    return [f for f in features if str(f.get("properties", {}).get("@validFrom", "")).startswith(start)]


def part_osm2019(notes: Notes) -> None:
    """The ohsome API answers HTTP 403 at elements/geometry (from CI and the
    workspace, 2026-11-19), and elementsFullHistory/geometry works: the versions
    of each building in the span from OSM_DATE to the next day; a building of
    that day has a version that is valid from the start of the span."""
    box = bbox()
    day = dt.date.fromisoformat(OSM_DATE)
    body = urllib.parse.urlencode({
        "bboxes": f"{box['west']},{box['south']},{box['east']},{box['north']}",
        "time": f"{OSM_DATE},{(day + dt.timedelta(days=1)).isoformat()}",
        "filter": "building=* and geometry:polygon",
        "properties": "tags,metadata",
    }).encode()
    data = json.loads(get(OHSOME, data=body, headers={"Content-Type": "application/x-www-form-urlencoded"}, timeout=600))
    all_features = data.get("features", [])
    features = osm_rows(all_features, OSM_DATE + "T00:00")
    notes.add(f"{len(all_features)} versions from the ohsome API, {len(features)} valid on {OSM_DATE}")
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


def heights_by_year(rows: list) -> dict[str, dict[int, float]]:
    """The rows of temporal.json to {id: {year: height}}: a year counts when at
    least MIN_PIXELS pixels of the outline have a building (two pixels of
    0.5 m at the edge of an outline are the next house)."""
    result: dict[str, dict[int, float]] = {}
    for oid, years in rows:
        for year, (height, pixels) in years.items():
            if int(pixels) >= MIN_PIXELS:
                result.setdefault(oid, {})[int(year)] = float(height)
    return result


def part_build(notes: Notes) -> None:
    """buildings_2019.json from the outlines and the heights of temporal.json,
    and the report of all parts."""
    outlines_path = RAW / "overture.json"
    lines = ["# The buildings of the play area (plan 0009, R1 and R5d)", "",
             "Made by `tools/geo/buildings.py`. Do not change by hand. The parts of the last runs are below.", ""]
    if outlines_path.exists():
        outlines = json.loads(outlines_path.read_text(encoding="utf-8"))["buildings"]
        notes.add(f"{len(outlines)} outlines of Overture Maps")
        heights: dict[str, dict[int, float]] = {}
        temporal_path = RAW / "temporal.json"
        if temporal_path.exists():
            heights = heights_by_year(json.loads(temporal_path.read_text(encoding="utf-8"))["heights"])
            notes.add(f"the heights of the 2.5D data of {len(heights)} outlines (at least {MIN_PIXELS} pixels in a year)")
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
