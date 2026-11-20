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

import geostore  # noqa: E402

AREA = ROOT / "data" / "geo" / "area.json"
WORLD = ROOT / "data" / "geo" / "build" / "world.json"
RAW = ROOT / "data" / "geo" / "raw" / "buildings"
# The large files (overture, temporal, the map of 2019 of the buildings with no
# outline, buildings_2019, and the heights of 3D-GloBFP and GHS-BUILT-H) are in
# the release of geostore.py; Git has this manifest (report 0009, D-0009-06).
MANIFEST = RAW / "manifest.json"
MANIFEST_NOTE = ("Made by tools/geo/buildings.py (plan 0009, R1 and R5d; report 0009, D-0009-06): the large files of "
                 "the buildings are assets of the release of the repository. ODbL (OpenStreetMap contributors, Overture "
                 "Maps Foundation, Microsoft, Google); Open Buildings 2.5D Temporal, 3D-GloBFP, and GHS-BUILT-H: CC BY 4.0.")
REPORT = ROOT / "data" / "geo" / "build" / "buildings_report.md"
AGENT = "vung-tau-geodata/1"
OVERTURE = "https://overturemaps-us-west-2.s3.us-west-2.amazonaws.com"
TEMPORAL_BUCKET = "open-buildings-temporal-data"
GCS_LIST = "https://storage.googleapis.com/storage/v1/b/{bucket}/o"
GCS_FILE = "https://storage.googleapis.com/{bucket}/{name}"
OHSOME = "https://api.ohsome.org/v1/elementsFullHistory/geometry"
OHSOME_METADATA = "https://api.ohsome.org/v1/metadata"
YEARS = list(range(2016, 2024))
# A pixel of the 2.5D data is a building where building_presence is more than this (a builder value, R1).
PRESENCE = 0.5
OSM_DATE = "2019-01-22"
# The cells of the map of 2019 of the buildings with no outline (m), and the blocks of a read of a tile (pixels).
UNMATCHED_M = 5.0
BLOCK_PX = 1024
# An outline has a building in a year when at least this many of its pixels have a building (a builder value, R1).
MIN_PIXELS = 8
# D-0009-05: the first year of an outline: its pixels with a building are at least this part of its area.
FIRST_PART = 0.3
# D-0009-04: the groups of cells with a building and no outline: at least this far from an outline, at least this many cells.
GROUP_DISTANCE_M = 3.0
GROUP_CELLS = 4
BUILD = ROOT / "data" / "geo" / "build"
# The right half of the maps: the middle of the town (Bãi Trước, Xóm Lưới, and the town east of Quang Trung), x0, z0, x1, z1.
CENTER_CROP = (-600.0, -700.0, 1400.0, 1300.0)
# The rows of each list of R5d in the report.
LIST_ROWS = 40
# A roof photon: the ground photons of the same pass within this distance (m).
ROOF_GROUND_M = 40.0
# 3D-GloBFP: the grid of Vũng Tàu (106.25 to 107.5 E, 10.0 to 11.25 N) and its file on figshare.
GLOBFP_GRID = 2108
GLOBFP_URL = "https://ndownloader.figshare.com/files/54098810"
# GHS-BUILT-H R2023A, AGBH, 3 arc seconds, the tile R8_C29 (100 to 110 E, 10 to 20 N; the play area is at its south edge).
GHS_URL = ("/vsizip//vsicurl/https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_BUILT_H_GLOBE_R2023A/"
           "GHS_BUILT_H_AGBH_E2018_GLOBE_R2023A_4326_3ss/V1-0/tiles/GHS_BUILT_H_AGBH_E2018_GLOBE_R2023A_4326_3ss_V1_0_R8_C29.zip/"
           "GHS_BUILT_H_AGBH_E2018_GLOBE_R2023A_4326_3ss_V1_0_R8_C29.tif")
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
    manifest = geostore.load(MANIFEST)
    geostore.put(manifest, "overture", {**head, "buildings": result}, rows=len(result))
    geostore.save(MANIFEST, manifest, MANIFEST_NOTE)
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
    outline_rows = outlines()
    proj = projection()
    polygons, ids = [], []
    for oid, _sources, _h, _f, flat in outline_rows:
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
    manifest = geostore.load(MANIFEST)
    geostore.put(manifest, "temporal", {**head, "heights": rows}, rows=len(rows))
    # The map of 2019 of the buildings with no outline: the cells with a part of more than 0, in percent.
    cells = [[int(r), int(c), int(round(float(unmatched[r, c]) * 100.0))] for r, c in zip(*np.nonzero(unmatched > 0.0))]
    geostore.put(manifest, "unmatched_2019", {"note": "The part of each cell of the 2.5D raster of 2019 with a building and no outline (percent).",
                                              "crs": f"EPSG:{epsg}", "west": area[0], "north": area[3], "cell_m": UNMATCHED_M,
                                              "shape": list(unmatched.shape), "columns": ["row", "column", "percent"],
                                              "cells": cells}, rows=len(cells))
    geostore.save(MANIFEST, manifest, MANIFEST_NOTE)
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
    # R5d: the buildings of OpenStreetMap of today (the last day of the ohsome
    # data) with a start_date, for the list of the buildings after 2019.
    meta = json.loads(get(OHSOME_METADATA))
    last = str(meta["extractRegion"]["temporalExtent"]["toTimestamp"])[:10]
    before = (dt.date.fromisoformat(last) - dt.timedelta(days=1)).isoformat()
    body = urllib.parse.urlencode({
        "bboxes": f"{box['west']},{box['south']},{box['east']},{box['north']}",
        "time": f"{before},{last}",
        "filter": "building=* and start_date=* and geometry:polygon",
        "properties": "tags,metadata",
    }).encode()
    data = json.loads(get(OHSOME, data=body, headers={"Content-Type": "application/x-www-form-urlencoded"}, timeout=600))
    dated = []
    for f in osm_rows(data.get("features", []), before + "T00:00"):
        ring = f.get("geometry", {}).get("coordinates", [[]])[0] if f.get("geometry", {}).get("type") == "Polygon" else []
        if not ring:
            continue
        props = f.get("properties", {})
        xs, zs = proj.to_game([p[0] for p in ring], [p[1] for p in ring])
        dated.append([props.get("@osmId", ""), {k: v for k, v in props.items() if not k.startswith("@")},
                      [v for x, z in zip(xs, zs) for v in (round(float(x), 1), round(float(z), 1))]])
    (RAW / "osm_start_dates.json").write_text(json.dumps({
        "note": f"Made by tools/geo/buildings.py osm2019 (plan 0009, R5d): the buildings of OpenStreetMap on {before} with a start_date, with their tags. (c) OpenStreetMap contributors, ODbL.",
        "date": before, "columns": ["osm", "tags", "outline"], "buildings": dated}, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    notes.add(f"{len(dated)} buildings of OpenStreetMap on {before} with a start_date")


# ----- the checks of the heights: 3D-GloBFP and GHS-BUILT-H (R1) -----


def part_checks(notes: Notes) -> None:
    """The heights of 3D-GloBFP (the grid 2108 of the part of Asia: a file of
    332 MB on figshare; only the buildings in the box stay) and of GHS-BUILT-H
    (the average gross building height of 2018, 3 arc seconds, the tile R8_C29:
    a window over HTTP), to the store."""
    import numpy as np
    import rasterio
    from rasterio.windows import from_bounds
    box = bbox()
    proj = projection()
    manifest = geostore.load(MANIFEST)
    # 3D-GloBFP
    tmp = ROOT / "build" / "geodata" / "tmp"
    tmp.mkdir(parents=True, exist_ok=True)
    zipped = tmp / f"globfp_{GLOBFP_GRID}.zip"
    if not zipped.exists() or zipped.stat().st_size < 1_000_000:
        zipped.write_bytes(get(GLOBFP_URL, timeout=1800))
    import geopandas as gpd
    import zipfile
    shp = [n for n in zipfile.ZipFile(zipped).namelist() if n.endswith(".shp")]
    frame = gpd.read_file(f"zip://{zipped}!{shp[0]}", bbox=(box["west"], box["south"], box["east"], box["north"]))
    columns = list(frame.columns)
    height_column = next((c for c in columns if c.lower() in ("height", "h", "bh", "build_h", "mean_h")), None)
    notes.add(f"3D-GloBFP grid {GLOBFP_GRID}: {len(frame)} buildings in the box; the columns {columns}; the height {height_column}")
    if height_column:
        frame = frame.to_crs("EPSG:4326")
        centers = frame.geometry.representative_point()
        xs, zs = proj.to_game(np.array(centers.x), np.array(centers.y))
        areas = frame.to_crs("EPSG:32648").geometry.area
        rows = [[round(float(x), 1), round(float(z), 1), round(float(h), 1), round(float(a), 1)]
                for x, z, h, a in zip(xs, zs, frame[height_column], areas) if np.isfinite(h)]
        geostore.put(manifest, "globfp", {"note": "3D-GloBFP (Che and others, 2024; CC BY 4.0): the buildings of the grid "
                                          f"{GLOBFP_GRID} in the box: a point in the footprint (x, z of the game), the height (m), the area (m²).",
                                          "columns": ["x", "z", "height", "area"], "buildings": rows}, rows=len(rows))
    # GHS-BUILT-H
    with rasterio.open(GHS_URL) as src:
        window = from_bounds(box["west"], box["south"], box["east"], box["north"], src.transform).round_offsets().round_lengths()
        values = src.read(1, window=window)
        transform = src.window_transform(window)
    geostore.put(manifest, "ghs_built_h", {"note": "GHS-BUILT-H R2023A, AGBH (the average gross building height, m) of 2018, "
                                           "3 arc seconds (European Commission, JRC; CC BY 4.0): the window of the box.",
                                           "west": transform.c, "north": transform.f, "cell_deg": transform.a,
                                           "values": np.round(values, 2).tolist()}, rows=int((values > 0).sum()))
    notes.add(f"GHS-BUILT-H: a window of {values.shape[1]} × {values.shape[0]} cells, {int((values > 0).sum())} with a height")
    geostore.save(MANIFEST, manifest, MANIFEST_NOTE)


# ----- the build (no network but the release) -----


def outlines() -> list:
    """The rows of the outlines of Overture Maps (id, sources, height, floors, flat outline)."""
    return geostore.get(geostore.load(MANIFEST), "overture")["buildings"]


def first_and_height(years: dict, area_m2: float) -> tuple[int | None, float | None, str | None]:
    """D-0009-05 and D-0009-08: the first year of an outline is the first year
    in which its pixels with a building are at least FIRST_PART of its area
    (and at least MIN_PIXELS): the rule "part". If no year has that part, it
    is the first year with at least MIN_PIXELS pixels: the rule "pixels". Its
    height is the median of the heights of the years from that year on (each
    with at least MIN_PIXELS pixels). With fewer than MIN_PIXELS pixels in each
    year, the 2.5D data does not see it: (None, None, None).
    years: {year: [height, pixels]}."""
    import numpy as np
    need = max(MIN_PIXELS, int(math.ceil(FIRST_PART * area_m2 / 0.25)))
    found = sorted(int(y) for y, (_h, px) in years.items() if int(px) >= need)
    rule = "part"
    if not found:
        found = sorted(int(y) for y, (_h, px) in years.items() if int(px) >= MIN_PIXELS)
        rule = "pixels"
    if not found:
        return None, None, None
    first = found[0]
    heights = [float(h) for y, (h, px) in years.items() if int(y) >= first and int(px) >= MIN_PIXELS]
    return first, round(float(np.median(heights)), 1), rule


def sort_buildings(rows: list, years_of: dict) -> tuple[list, list, list, dict]:
    """D-0009-08: the buildings of 2019 (a first year up to 2019), the buildings
    that are out (a first year after 2019), and the buildings that the 2.5D data
    does not see (fewer than MIN_PIXELS pixels in each year: status Check, not in
    the game), with the count of each kind. rows: the rows of outlines()."""
    import shapely
    kept, out, unseen = [], [], []
    counts = {"part_2019": 0, "part_after_2019": 0, "pixels_2019": 0, "pixels_after_2019": 0, "unseen": 0}
    for oid, sources, h, floors, flat in rows:
        area = shapely.Polygon(list(zip(flat[0::2], flat[1::2]))).area
        first, height, rule = first_and_height(years_of.get(oid, {}), area)
        item = {"id": oid, "sources": sources, "outline": [flat[i:i + 2] for i in range(0, len(flat), 2)],
                "height": height, "height_source": "Open Buildings 2.5D Temporal", "floors": floors,
                "first_year": first, "first_rule": rule}
        if first is None:
            item.update({"height": h or None, "height_source": "Overture" if h else None, "status": "Check",
                         "area_m2": round(area, 1)})
            unseen.append(item)
            counts["unseen"] += 1
        elif first > 2019:
            out.append(item)
            counts[f"{rule}_after_2019"] += 1
        else:
            kept.append(item)
            counts[f"{rule}_2019"] += 1
    return kept, out, unseen, counts


def groups_of_cells(building, distance, min_distance: float = GROUP_DISTANCE_M, min_cells: int = GROUP_CELLS) -> list[list]:
    """D-0009-04: the groups (4-connected) of the cells with a building and no
    outline that are at least min_distance from an outline, with at least
    min_cells cells. building and distance: arrays of the cells. Returns the
    cells of each group, largest first."""
    import numpy as np
    from scipy import ndimage
    keep = np.asarray(building, dtype=bool) & (np.asarray(distance, dtype=float) >= min_distance)
    labels, count = ndimage.label(keep)
    groups = []
    for label in range(1, count + 1):
        cells = np.argwhere(labels == label)
        if len(cells) >= min_cells:
            groups.append([tuple(int(v) for v in c) for c in cells])
    groups.sort(key=len, reverse=True)
    return groups


def draw_map(path: Path, layers: list, title: str, crop: tuple | None = None, size: int = 1400) -> None:
    """A PNG map of polygons in the coordinates of the game: layers are
    (polygons as flat lists, the fill color, the name). The left half is the
    whole box; the right half is the crop (x0, z0, x1, z1) of the middle of the town."""
    from PIL import Image, ImageDraw
    import numpy as np
    box = bbox()
    proj = projection()
    xs, zs = proj.to_game(np.array([box["west"], box["east"]]), np.array([box["north"], box["south"]]))
    full = (float(min(xs)), float(min(zs)), float(max(xs)), float(max(zs)))
    panels = [full] + ([crop] if crop else [])
    width = size * len(panels)
    image = Image.new("RGB", (width, size + 40), (250, 250, 246))
    draw = ImageDraw.Draw(image)
    for k, (x0, z0, x1, z1) in enumerate(panels):
        scale = (size - 20) / max(x1 - x0, z1 - z0)
        ox = k * size + 10
        for polygons, color, _name in layers:
            for flat in polygons:
                points = [(ox + (flat[i] - x0) * scale, 30 + (flat[i + 1] - z0) * scale) for i in range(0, len(flat), 2)]
                if len(points) >= 3:
                    draw.polygon(points, fill=color)
        draw.rectangle([ox, 30, ox + (x1 - x0) * scale, 30 + (z1 - z0) * scale], outline=(120, 120, 120))
        if crop and k == 0:
            cx0, cz0, cx1, cz1 = crop
            draw.rectangle([ox + (cx0 - x0) * scale, 30 + (cz0 - z0) * scale, ox + (cx1 - x0) * scale,
                            30 + (cz1 - z0) * scale], outline=(0, 0, 0))
    legend = "   ".join(f"{name}" for _p, _c, name in layers)
    draw.text((10, 8), f"{title}. {legend}. North is up.", fill=(0, 0, 0))
    x = 10
    for _p, color, name in layers:
        draw.rectangle([x, 22, x + 10, 28], fill=color)
        x += 10 + 7 * len(name) + 20
    image.save(path)
    geostore.write_keep_import(path)


def part_build(notes: Notes) -> None:
    """buildings_2019 (the store), the maps, the groups of D-0009-04, the lists
    of R5d, the checks of the heights, and the report of all parts."""
    import numpy as np
    import shapely
    manifest = geostore.load(MANIFEST)
    lines = ["# The buildings of the play area (plan 0009, R1 and R5d)", "",
             "Made by `tools/geo/buildings.py`. Do not change by hand. The large files are assets of the release "
             f"`{geostore.RELEASE}` (`data/geo/raw/buildings/manifest.json`).", ""]
    rows = outlines()
    temporal = geostore.get(manifest, "temporal") if "temporal" in manifest.get("files", {}) else {"heights": [], "shifts": {}}
    years_of = {oid: years for oid, years in temporal["heights"]}
    polygons = [shapely.Polygon(list(zip(flat[0::2], flat[1::2]))) for _oid, _s, _h, _f, flat in rows]
    result, out, unseen, kinds = sort_buildings(rows, years_of)
    firsts = {i["id"]: i["first_year"] for i in result + out + unseen}
    geostore.put(manifest, "buildings_2019", {"note": "Made by tools/geo/buildings.py build (plan 0009, R1). The first year is the "
                                              "first year with 30 % of the outline, else the first year with 8 pixels or more "
                                              "(first_rule: part or pixels, D-0009-08); the height is the median of the years of "
                                              "the 2.5D data from the first year on (D-0009-05). ODbL; the heights of Open "
                                              "Buildings 2.5D Temporal: CC BY 4.0.",
                                              "presence": PRESENCE, "first_part": FIRST_PART, "buildings": result}, rows=len(result))
    # D-0009-08: the outlines that the 2.5D data does not see (fewer than 8 pixels in each year): status Check.
    geostore.put(manifest, "buildings_unseen", {"note": "Made by tools/geo/buildings.py build (report 0009, D-0009-08). The "
                                                "outlines of Overture Maps with fewer than 8 pixels of building in each year of "
                                                "the 2.5D data: it does not see them. Status Check: not in the game until a person "
                                                "decides. ODbL.", "buildings": unseen}, rows=len(unseen))
    nulls = sum(1 for i in result + out if i["height"] is None)
    if nulls:
        raise SystemExit(f"D-0009-08: {nulls} buildings with a first year have no height")
    notes.add(f"D-0009-08: the first year by 30 % of the outline: {kinds['part_2019']} up to 2019, {kinds['part_after_2019']} "
              f"after; by 8 pixels (no year with 30 %): {kinds['pixels_2019']} up to 2019, {kinds['pixels_after_2019']} after; "
              f"fewer than 8 pixels in each year: {kinds['unseen']} (buildings_unseen, Check)")
    by_first: dict = {}
    for item in result:
        by_first[item["first_year"]] = by_first.get(item["first_year"], 0) + 1
    heights = np.array([i["height"] for i in result if i["height"] is not None], dtype=float)
    notes.add(f"{len(result)} buildings of 2019, {len(out)} out (the first year is after 2019); the first years: "
              + ", ".join(f"{k}: {v}" for k, v in sorted(by_first.items(), key=lambda kv: (kv[0] is None, kv[0] or 0))))
    if len(heights):
        notes.add(f"the heights: median {np.median(heights):.1f} m, 90 % under {np.percentile(heights, 90):.1f} m, "
                  f"the highest {heights.max():.1f} m")
    unseen_area = [i["area_m2"] for i in unseen]
    lines += [f"{len(result)} buildings of 2019, {len(out)} out (their first year is after 2019), and {len(unseen)} that the "
              "2.5D data does not see (Check).", "",
              "## The first year of each outline (D-0009-05, D-0009-08)", "",
              "| Kind | Up to 2019 | After 2019 |", "|---|---|---|",
              f"| A year with 30 % of the outline | {kinds['part_2019']} | {kinds['part_after_2019']} |",
              f"| No year with 30 %: the first year with 8 pixels or more | {kinds['pixels_2019']} | {kinds['pixels_after_2019']} |",
              "",
              f"Fewer than 8 pixels in each year: {len(unseen)} outlines (median area "
              f"{float(np.median(unseen_area)) if unseen_area else 0:.0f} m²). They are not in `buildings_2019`: the list "
              "`buildings_unseen` of the store and the map `buildings_unseen.png`, with the status Check. Each building of "
              f"2019 and each building that is out has a height (no null).", ""]

    # D-0009-04: the groups of cells with a building and no outline.
    group_flats, group_cells, group_area = [], 0, 0.0
    if "unmatched_2019" in manifest.get("files", {}):
        grid = geostore.get(manifest, "unmatched_2019")
        shape = tuple(grid["shape"])
        part = np.zeros(shape, dtype=float)
        for r, c, v in grid["cells"]:
            part[r, c] = v / 100.0
        cell = float(grid["cell_m"])
        proj = projection()
        shift = temporal.get("shifts", {}).get("2019", [0.0, 0.0, 0.0])
        building = part > 0.5
        distance = np.full(shape, np.inf)
        idx = np.argwhere(building)
        # The middle of each cell in the coordinates of the game, with the shift of 2019 (D-0009-01 of temporal).
        east = grid["west"] + (idx[:, 1] + 0.5) * cell - float(shift[1])
        north = grid["north"] - (idx[:, 0] + 0.5) * cell + float(shift[0])
        lon, lat = utm_to_lonlat(east, north, grid["crs"])
        gx, gz = proj.to_game(lon, lat)
        tree = shapely.STRtree(polygons)
        squares = [shapely.box(x - cell / 2, z - cell / 2, x + cell / 2, z + cell / 2) for x, z in zip(gx, gz)]
        nearest = tree.query_nearest(squares, return_distance=True, all_matches=False)
        for (square_index, _poly_index), d in zip(nearest[0].T, nearest[1]):
            r, c = idx[square_index]
            distance[r, c] = d
        groups = groups_of_cells(building, distance)
        center_of = {tuple(i): (x, z) for i, x, z in zip(map(tuple, idx), gx, gz)}
        for g in groups:
            group_cells += len(g)
            for rc in g:
                x, z = center_of[rc]
                group_flats.append([x - cell / 2, z - cell / 2, x + cell / 2, z - cell / 2, x + cell / 2, z + cell / 2, x - cell / 2, z + cell / 2])
        group_area = group_cells * cell * cell
        sizes = [len(g) for g in groups]
        notes.add(f"D-0009-04: {int(building.sum())} cells of {cell:.0f} m more than half building with no outline; "
                  f"{len(groups)} groups of at least {GROUP_CELLS} cells at least {GROUP_DISTANCE_M:.0f} m from an outline: "
                  f"{group_cells} cells, {group_area / 1e6:.3f} km²; the largest groups {sizes[:5]} cells")
        lines += ["## The buildings with no outline (D-0009-04)", "",
                  f"{len(groups)} groups, {group_cells} cells of {cell:.0f} m, {group_area / 1e4:.1f} ha "
                  f"(`buildings_no_outline.png`, the groups in orange).", ""]

    # D-0009-03: the maps.
    flat_of = {oid: flat for oid, _s, _h, _f, flat in rows}
    gray, red, orange, blue = (110, 110, 110), (210, 40, 40), (240, 140, 20), (40, 90, 200)
    crop = CENTER_CROP
    draw_map(BUILD / "buildings_all.png", [([flat_of[i["id"]] for i in result + out + unseen], gray, "all the outlines")],
             "All the outlines of Overture Maps", crop)
    draw_map(BUILD / "buildings_2019.png", [([flat_of[i["id"]] for i in result], gray, "a building of 2019")],
             "The buildings of 2019", crop)
    draw_map(BUILD / "buildings_out.png", [([flat_of[i["id"]] for i in result], (200, 200, 200), "2019"),
                                           ([flat_of[i["id"]] for i in out], red, "out: first year after 2019")],
             "The buildings that are out", crop)
    draw_map(BUILD / "buildings_no_outline.png", [([flat_of[i["id"]] for i in result], (200, 200, 200), "an outline of 2019"),
                                                  (group_flats, orange, "a group of cells with a building and no outline")],
             "The buildings of the raster of 2019 with no outline (D-0009-04)", crop)
    draw_map(BUILD / "buildings_unseen.png", [([flat_of[i["id"]] for i in result], (200, 200, 200), "2019"),
                                              ([flat_of[i["id"]] for i in unseen], blue, "fewer than 8 pixels in each year (Check)")],
             "The outlines that the 2.5D data does not see (D-0009-08)", crop)
    lines += ["## The maps (D-0009-03)", "", "`buildings_all.png`, `buildings_2019.png`, `buildings_out.png`, "
              "`buildings_no_outline.png`, and `buildings_unseen.png`: the whole box at the left, the middle of the town "
              "at the right.", ""]

    # D-0009-03: the lists of R5d.
    lines += r5d_lists(notes, rows, polygons, firsts)
    # D-0009-03: the checks of the heights.
    lines += height_checks(notes, manifest, rows, polygons, result)
    geostore.save(MANIFEST, manifest, MANIFEST_NOTE)
    for part in ("outlines", "temporal", "osm2019", "checks"):
        path = RAW / f"{part}.md"
        if path.exists():
            lines += [path.read_text(encoding="utf-8"), ""]
    notes.save()
    lines += [(RAW / "build.md").read_text(encoding="utf-8")]
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")


def utm_to_lonlat(east, north, crs: str):
    import pyproj
    transformer = pyproj.Transformer.from_crs(crs, "EPSG:4326", always_xy=True)
    return transformer.transform(east, north)


def overlap_part(a, b) -> float:
    """The part of the area of a that b covers."""
    return float(a.intersection(b).area / a.area) if a.area > 0 else 0.0


def r5d_lists(notes: Notes, rows: list, polygons: list, firsts: dict) -> list[str]:
    """R5d: the buildings of OpenStreetMap on 2019-01-22 that the 2.5D data does
    not have in 2019; the outlines of OpenStreetMap of today that the 2.5D data
    has in 2019 and OpenStreetMap did not have on 2019-01-22; and the buildings
    with a start_date after 2019. The lists go to buildings_r5d.json."""
    import shapely
    path = RAW / "osm2019.json"
    if not path.exists():
        return []
    osm = json.loads(path.read_text(encoding="utf-8"))
    osm_polys = [shapely.Polygon(list(zip(flat[0::2], flat[1::2]))) for _id, _tags, flat in osm["buildings"]]
    tree = shapely.STRtree(polygons)
    in_2019 = {i for i, (oid, *_r) in enumerate(rows) if firsts.get(oid) is not None and firsts[oid] <= 2019}
    not_in_25d = []
    for (osm_id, tags, flat), poly in zip(osm["buildings"], osm_polys):
        if not poly.is_valid or poly.area <= 0:
            continue
        covered = sum(overlap_part(poly, polygons[j]) for j in tree.query(poly) if j in in_2019)
        if covered < 0.5:
            c = poly.centroid
            not_in_25d.append([osm_id, round(c.x, 1), round(c.y, 1), tags.get("building", ""), tags.get("name", "")])
    osm_tree = shapely.STRtree([p for p in osm_polys if p.is_valid])
    valid_osm = [p for p in osm_polys if p.is_valid]
    not_in_osm = []
    for i, (oid, sources, _h, _f, _flat) in enumerate(rows):
        if "OpenStreetMap" not in sources or i not in in_2019:
            continue
        poly = polygons[i]
        covered = sum(overlap_part(poly, valid_osm[j]) for j in osm_tree.query(poly))
        if covered < 0.5:
            c = poly.centroid
            not_in_osm.append([oid, round(c.x, 1), round(c.y, 1), firsts.get(oid)])
    later = []
    now_path = RAW / "osm_start_dates.json"
    if now_path.exists():
        for osm_id, tags, flat in json.loads(now_path.read_text(encoding="utf-8"))["buildings"]:
            year = re.match(r"\s*(\d{4})", str(tags.get("start_date", "")))
            if year and int(year.group(1)) > 2019:
                poly = shapely.Polygon(list(zip(flat[0::2], flat[1::2])))
                c = poly.centroid
                later.append([osm_id, round(c.x, 1), round(c.y, 1), tags.get("start_date"), tags.get("building", ""), tags.get("name", "")])
    (BUILD / "buildings_r5d.json").write_text(json.dumps({
        "note": "Made by tools/geo/buildings.py build (plan 0009, R5d). x, z: a point of the building in the coordinates of the game.",
        "osm_2019_not_in_2_5d_2019": {"columns": ["osm", "x", "z", "building", "name"], "rows": not_in_25d},
        "in_2_5d_2019_not_in_osm_2019": {"columns": ["overture", "x", "z", "first_year"], "rows": not_in_osm},
        "start_date_after_2019": {"columns": ["osm", "x", "z", "start_date", "building", "name"], "rows": later},
    }, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    notes.add(f"R5d: {len(not_in_25d)} buildings of OpenStreetMap on {OSM_DATE} not in the 2.5D data of 2019; "
              f"{len(not_in_osm)} outlines of OpenStreetMap of today in the 2.5D data of 2019 and not in OpenStreetMap on {OSM_DATE}; "
              f"{len(later)} buildings with a start_date after 2019")
    out = ["## The lists of R5d", "", "All the rows are in `buildings_r5d.json`.", "",
           f"### In OpenStreetMap on {OSM_DATE}, not in the 2.5D data of 2019 ({len(not_in_25d)})", "",
           "| OSM | x | z | building | name |", "|---|---|---|---|---|"]
    out += [f"| {r[0]} | {r[1]} | {r[2]} | {r[3]} | {r[4]} |" for r in not_in_25d[:LIST_ROWS]]
    out += ["", f"### In the 2.5D data of 2019, not in OpenStreetMap on {OSM_DATE} ({len(not_in_osm)})", "",
            "Only the outlines that OpenStreetMap has today: the other outlines of 2019 (Microsoft, Google) were never in OpenStreetMap.", "",
            "| Overture | x | z | first year |", "|---|---|---|---|"]
    out += [f"| {r[0]} | {r[1]} | {r[2]} | {r[3]} |" for r in not_in_osm[:LIST_ROWS]]
    out += ["", f"### A start_date after 2019 ({len(later)})", "", "| OSM | x | z | start_date | building | name |", "|---|---|---|---|---|---|"]
    out += [f"| {r[0]} | {r[1]} | {r[2]} | {r[3]} | {r[4]} | {r[5]} |" for r in later[:LIST_ROWS]]
    if max(len(not_in_25d), len(not_in_osm), len(later)) > LIST_ROWS:
        out += ["", f"(The tables show the first {LIST_ROWS} rows.)"]
    return out + [""]


def stats_line(name: str, diff, extra: str = "") -> str:
    import numpy as np
    diff = np.asarray(diff, dtype=float)
    if not len(diff):
        return f"| {name} | 0 | | | | {extra} |"
    return (f"| {name} | {len(diff)} | {np.mean(diff):+.2f} | {np.median(diff):+.2f} | {np.sqrt(np.mean(diff ** 2)):.2f} | {extra} |")


def height_checks(notes: Notes, manifest: dict, rows: list, polygons: list, result: list) -> list[str]:
    """R1: the heights of the 2.5D data against 3D-GloBFP, GHS-BUILT-H, the
    building:levels of OpenStreetMap, and the roof photons of ATL03 (D-0009-02)."""
    import numpy as np
    import shapely
    height_of = {i["id"]: i["height"] for i in result if i["height_source"] == "Open Buildings 2.5D Temporal"}
    ids = [r[0] for r in rows]
    tree = shapely.STRtree(polygons)
    out = ["## The checks of the heights (R1)", "",
           "The difference is the height of the 2.5D data minus the height of the check (m).", "",
           "| Check | Buildings | Mean | Median | RMSE | Note |", "|---|---|---|---|---|---|"]
    files = manifest.get("files", {})
    if "globfp" in files:
        g = geostore.get(manifest, "globfp")["buildings"]
        points = shapely.points(np.array([r[0] for r in g]), np.array([r[1] for r in g]))
        pairs = tree.query(points, predicate="within")
        diff = [height_of[ids[j]] - g[i][2] for i, j in zip(pairs[0], pairs[1]) if ids[j] in height_of]
        out.append(stats_line("3D-GloBFP", diff, f"a building of 3D-GloBFP in an outline ({len(g)} in the box)"))
    if "ghs_built_h" in files:
        ghs = geostore.get(manifest, "ghs_built_h")
        values = np.array(ghs["values"], dtype=float)
        proj = projection()
        sums: dict = {}
        for oid, poly in zip(ids, polygons):
            if oid not in height_of:
                continue
            c = poly.centroid
            lon, lat = proj.game_to_lonlat(np.array([c.x]), np.array([c.y]))
            col = int((float(lon[0]) - ghs["west"]) / ghs["cell_deg"])
            row = int((ghs["north"] - float(lat[0])) / ghs["cell_deg"])
            if 0 <= row < values.shape[0] and 0 <= col < values.shape[1]:
                s = sums.setdefault((row, col), [0.0, 0.0])
                s[0] += height_of[oid] * poly.area
                s[1] += poly.area
        diff = [s[0] / s[1] - values[r, c] for (r, c), s in sums.items() if s[1] > 0 and values[r, c] > 0]
        out.append(stats_line("GHS-BUILT-H", diff, "for each cell of 90 m: the mean of the 2.5D heights, weighted by area, against AGBH"))
    osm_path = RAW / "osm2019.json"
    levels_note = ""
    if osm_path.exists():
        per_level: dict = {}
        for _osm, tags, flat in json.loads(osm_path.read_text(encoding="utf-8"))["buildings"]:
            levels = re.match(r"\s*(\d+)", str(tags.get("building:levels", "")))
            if not levels:
                continue
            poly = shapely.Polygon(list(zip(flat[0::2], flat[1::2])))
            if not poly.is_valid:
                continue
            for j in tree.query(poly):
                if ids[j] in height_of and overlap_part(poly, polygons[j]) > 0.5:
                    per_level.setdefault(int(levels.group(1)), []).append(height_of[ids[j]])
                    break
        count = sum(len(v) for v in per_level.values())
        out.append(stats_line("building:levels of OpenStreetMap", [h - 3.3 * n for n, hs in per_level.items() for h in hs],
                              f"{count} buildings; the check is 3.3 m a storey"))
        levels_note = ("The median 2.5D height for each number of storeys of OpenStreetMap: "
                       + ", ".join(f"{n}: {np.median(v):.1f} m ({len(v)})" for n, v in sorted(per_level.items())) + ".")
    lidar_manifest = geostore.load(ROOT / "data" / "geo" / "raw" / "lidar" / "manifest.json")
    roof_keys = sorted(k for k in lidar_manifest.get("files", {}) if k.startswith("atl03_roof/"))
    tracks_path = BUILD / "lidar_tracks.json"
    if roof_keys and tracks_path.exists():
        bins = json.loads(tracks_path.read_text(encoding="utf-8"))["bins"]
        proj = projection()
        by_date: dict = {}
        for date, x, z, ground, _roof, gc, _rc in bins:
            if ground is not None and gc >= 3:
                by_date.setdefault(date, []).append((x, z, ground))
        per_outline: dict = {}
        for key in roof_keys:
            data = geostore.get(lidar_manifest, key)
            col = data["columns"].index("outline")
            for r in data["points"]:
                ground_bins = by_date.get(r[2])
                if not ground_bins:
                    continue
                gx, gz = proj.to_game(np.array([r[0]]), np.array([r[1]]))
                arr = np.array(ground_bins)
                d = np.hypot(arr[:, 0] - gx[0], arr[:, 1] - gz[0])
                k = int(np.argmin(d))
                if d[k] <= ROOF_GROUND_M:
                    per_outline.setdefault(r[col], []).append(float(r[4]) - float(arr[k, 2]))
        diff = [height_of[o] - float(np.median(v)) for o, v in per_outline.items() if o in height_of and len(v) >= 3]
        photons = sum(len(v) for v in per_outline.values())
        out.append(stats_line("ATL03 roof photons", diff, f"{photons} photons over {len(per_outline)} outlines; the median of at "
                              f"least 3 photons over the median of the ground photons of the same pass within {ROOF_GROUND_M:.0f} m"))
    else:
        out.append("| ATL03 roof photons | 0 | | | | no roof photons in the store yet |")
    if levels_note:
        out += ["", levels_note]
    notes.add("the checks of the heights: " + "; ".join(line.split("|")[1].strip() + " " + line.split("|")[2].strip()
                                                        for line in out if line.startswith("| ") and not line.startswith("| Check")))
    return out + [""]


PARTS = {"outlines": part_outlines, "temporal": part_temporal, "osm2019": part_osm2019, "checks": part_checks, "build": part_build}


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
