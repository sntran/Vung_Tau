#!/usr/bin/env python3
"""The street photos of Mapillary in the play area (plan 0009, R5e; plan 0026).

    python tools/geo/photos.py index             # the index of the images (CI, MAPILLARY_TOKEN)
    python tools/geo/photos.py report            # the report and the map of the images by year (no network)
    python tools/geo/photos.py sheets            # the contact sheets of data/showcase/photo_points.json (CI)
    python tools/geo/photos.py detail ID [ID..]  # one picture of 1 024 px (2 048 px for a 360) of each image (CI)
    python tools/geo/photos.py --check           # no network: the index, the sheets, and the credits agree

The index: the ids of the coverage tiles (the layer "image" of "mly1_public",
zoom 14) in the box of data/geo/area.json, then the fields of each image that is
not in the index yet (the API of the images, 50 ids in each request). A second
run asks only for the new ids. The index keeps the id of an image, and not the
URL of its picture: the URLs expire. It is data/geo/raw/mapillary.json.

The images are CC BY-SA 4.0. The credit of each image: its author, "Mapillary",
the license, and https://www.mapillary.com/app/?pKey=ID. The sheets and the
pictures go into docs/reference/mapillary/ with CREDITS.md next to them. Look
at each image before a value comes from it (docs/world-models.md, section 3).
Before a picture goes on a sheet, tools/geo/privacy.py blurs the number plates
and the faces, or leaves out the image (report 0026, D-0026-39).

The token goes in the header of each request of the API, so that no log has it.
The tiles take it in the URL: the tool never prints a URL of a tile.
"""

from __future__ import annotations

import argparse
import datetime as dt
import io
import json
import math
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import privacy  # noqa: E402

AREA = ROOT / "data" / "geo" / "area.json"
WORLD = ROOT / "data" / "geo" / "build" / "world.json"
ROADS = ROOT / "data" / "geo" / "build" / "roads.json"
LANDMARKS = ROOT / "data" / "geo" / "build" / "landmarks.json"
POINTS = ROOT / "data" / "showcase" / "photo_points.json"
INDEX = ROOT / "data" / "geo" / "raw" / "mapillary.json"
REPORT = ROOT / "data" / "geo" / "build" / "photos_report.md"
MAP = ROOT / "data" / "geo" / "build" / "photos_map.png"
OUT = ROOT / "docs" / "reference" / "mapillary"
CACHE = ROOT / "build" / "mapillary"

AGENT = "vung-tau-photos/1"
GRAPH = "https://graph.mapillary.com"
TILES = "https://tiles.mapillary.com/maps/vtp/mly1_public/2/{z}/{x}/{y}"
ZOOM = 14
BATCH = 50
FIELDS = "id,captured_at,computed_geometry,geometry,compass_angle,computed_compass_angle,camera_type,sequence,creator"
COLUMNS = ["id", "date", "lon", "lat", "computed", "compass", "computed_compass", "camera", "sequence", "author"]
LICENSE = "CC BY-SA 4.0"
VIETNAM = dt.timezone(dt.timedelta(hours=7))
PANO = ("spherical", "equirectangular")
TOWARD_DEG = 50.0
DIRECTION_DEG = 45.0
ROAD_M = 12.0
PLACE_M = 100.0
SHEET_COLUMNS = 3
SHEET_ROWS = 4
TILE_W = 512
SEQUENCE_SPACING_M = 10.0
PANO_VIEW_DEG = 100.0
# The time of the API in one run of the index (the job stops at 100 minutes).
INDEX_BUDGET_S = 45 * 60.0


# ----- the vector tiles (Mapbox Vector Tile 2.1, a protobuf) -----


def _varint(data: bytes, i: int) -> tuple[int, int]:
    result = shift = 0
    while True:
        b = data[i]
        i += 1
        result |= (b & 0x7F) << shift
        if not b & 0x80:
            return result, i
        shift += 7


def _fields(data: bytes):
    """Each (number, wire type, value) of a protobuf message."""
    i = 0
    while i < len(data):
        key, i = _varint(data, i)
        number, wire = key >> 3, key & 7
        if wire == 0:
            value, i = _varint(data, i)
        elif wire == 1:
            value, i = data[i:i + 8], i + 8
        elif wire == 2:
            size, i = _varint(data, i)
            value, i = data[i:i + size], i + size
        elif wire == 5:
            value, i = data[i:i + 4], i + 4
        else:
            raise ValueError(f"wire type {wire} is not known")
        yield number, wire, value


def _packed(data: bytes) -> list[int]:
    out, i = [], 0
    while i < len(data):
        v, i = _varint(data, i)
        out.append(v)
    return out


def _zigzag(v: int) -> int:
    return (v >> 1) ^ -(v & 1)


def _value(data: bytes):
    import struct
    for number, _wire, v in _fields(data):
        if number == 1:
            return v.decode("utf-8")
        if number == 2:
            return struct.unpack("<f", v)[0]
        if number == 3:
            return struct.unpack("<d", v)[0]
        if number in (4, 5):
            return v
        if number == 6:
            return _zigzag(v)
        if number == 7:
            return bool(v)
    return None


def decode_tile(data: bytes) -> dict[str, list[dict]]:
    """The points of each layer of a tile: {"layer": [{"x", "y", "extent", "properties"}]}."""
    layers: dict[str, list[dict]] = {}
    for number, _wire, layer_bytes in _fields(data):
        if number != 3:
            continue
        name, extent, keys, values, features = "", 4096, [], [], []
        for n, _w, v in _fields(layer_bytes):
            if n == 1:
                name = v.decode("utf-8")
            elif n == 2:
                features.append(v)
            elif n == 3:
                keys.append(v.decode("utf-8"))
            elif n == 4:
                values.append(_value(v))
            elif n == 5:
                extent = v
        out = []
        for feature in features:
            tags, geometry, fid, kind = [], [], None, 0
            for n, _w, v in _fields(feature):
                if n == 1:
                    fid = v
                elif n == 2:
                    tags = _packed(v)
                elif n == 3:
                    kind = v
                elif n == 4:
                    geometry = _packed(v)
            if kind != 1 or len(geometry) < 3:
                continue
            properties = {keys[tags[k]]: values[tags[k + 1]] for k in range(0, len(tags) - 1, 2)}
            if fid is not None:
                properties.setdefault("id", fid)
            x, y = _zigzag(geometry[1]), _zigzag(geometry[2])
            out.append({"x": x, "y": y, "extent": extent, "properties": properties})
        layers[name] = out
    return layers


def tile_range(bbox: dict, zoom: int = ZOOM) -> list[tuple[int, int]]:
    def xy(lon: float, lat: float) -> tuple[int, int]:
        n = 2 ** zoom
        x = int((lon + 180.0) / 360.0 * n)
        y = int((1.0 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2.0 * n)
        return x, y
    x0, y0 = xy(bbox["west"], bbox["north"])
    x1, y1 = xy(bbox["east"], bbox["south"])
    return [(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1)]


def tile_lonlat(tx: int, ty: int, px: float, py: float, extent: int, zoom: int = ZOOM) -> tuple[float, float]:
    n = 2 ** zoom
    lon = (tx + px / extent) / n * 360.0 - 180.0
    lat = math.degrees(math.atan(math.sinh(math.pi * (1.0 - 2.0 * (ty + py / extent) / n))))
    return lon, lat


def in_box(lon: float, lat: float, bbox: dict) -> bool:
    return bbox["west"] <= lon <= bbox["east"] and bbox["south"] <= lat <= bbox["north"]


# ----- the network -----


def token() -> str:
    value = os.environ.get("MAPILLARY_TOKEN", "").strip()
    if not value:
        raise SystemExit("ERROR: no MAPILLARY_TOKEN (the secret of the repository; the tool runs in CI)")
    return value


def get(url: str, headers: dict | None = None, tries: int = 5, show: str | None = None) -> bytes:
    """The bytes at the URL. "show" is what a log says in place of the URL."""
    for attempt in range(tries):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": AGENT, **(headers or {})})
            with urllib.request.urlopen(request, timeout=60) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            if error.code in (400, 401, 403, 404) or attempt == tries - 1:
                raise
            wait = 30 if error.code == 429 else 2 ** attempt
            print(f"  {show or url}: HTTP {error.code}, again in {wait} s")
            time.sleep(wait)
        except Exception as error:  # noqa: BLE001 - a network error: try again
            if attempt == tries - 1:
                raise
            print(f"  {show or url}: {error}, again in {2 ** attempt} s")
            time.sleep(2 ** attempt)
    raise RuntimeError("not reached")


def graph(path: str, params: dict) -> dict:
    url = f"{GRAPH}/{path}?" + urllib.parse.urlencode(params)
    return json.loads(get(url, {"Authorization": f"OAuth {token()}"}))


# ----- the index -----


def row(image: dict) -> list:
    """One row of the index (COLUMNS) from a record of the API."""
    computed = image.get("computed_geometry") or {}
    geometry = computed or image.get("geometry") or {}
    lon, lat = (geometry.get("coordinates") or [None, None])[:2]
    when = dt.datetime.fromtimestamp(int(image["captured_at"]) / 1000.0, tz=dt.timezone.utc).astimezone(VIETNAM)
    sequence = image.get("sequence")
    if isinstance(sequence, dict):
        sequence = sequence.get("id")
    creator = image.get("creator") or {}
    def angle(value):
        return None if value is None else round(float(value) % 360.0, 1)
    return [str(image["id"]), when.strftime("%Y-%m-%dT%H:%M"), round(lon, 7) if lon is not None else None,
            round(lat, 7) if lat is not None else None, 1 if computed else 0, angle(image.get("compass_angle")),
            angle(image.get("computed_compass_angle")), image.get("camera_type") or "", sequence or "",
            creator.get("username") or str(creator.get("id") or "")]


def records(index: dict) -> list[dict]:
    return [dict(zip(index["columns"], r)) for r in index["images"]]


def load_index() -> dict:
    if INDEX.exists():
        return json.loads(INDEX.read_text(encoding="utf-8"))
    return {"columns": COLUMNS, "images": []}


def write_index(index: dict) -> None:
    head = {k: v for k, v in index.items() if k != "images"}
    lines = [json.dumps(r, ensure_ascii=False) for r in sorted(index["images"], key=lambda r: (r[1], r[0]))]
    text = json.dumps(head, ensure_ascii=False, indent="\t")[:-2] + ',\n\t"images": [\n' + ",\n".join(lines) + "\n\t]\n}\n"
    INDEX.write_text(text, encoding="utf-8")


def tile_ids(bbox: dict) -> dict[str, tuple[dict, tuple[float, float]]]:
    """The id of each image of the coverage tiles in the box, with the values and the position of the tile."""
    found: dict[str, dict] = {}
    secret = token()
    tiles = tile_range(bbox)
    for k, (tx, ty) in enumerate(tiles):
        url = TILES.format(z=ZOOM, x=tx, y=ty) + "?" + urllib.parse.urlencode({"access_token": secret})
        try:
            data = get(url, show=f"tile {ZOOM}/{tx}/{ty}")
        except urllib.error.HTTPError as error:
            if error.code == 404:
                continue
            raise SystemExit(f"ERROR: tile {ZOOM}/{tx}/{ty}: HTTP {error.code}")
        points = decode_tile(data).get("image", [])
        kept = 0
        for p in points:
            lon, lat = tile_lonlat(tx, ty, p["x"], p["y"], p["extent"])
            if in_box(lon, lat, bbox) and p["properties"].get("id") is not None:
                found[str(p["properties"]["id"])] = (p["properties"], (lon, lat))
                kept += 1
        print(f"tile {k + 1}/{len(tiles)} {ZOOM}/{tx}/{ty}: {len(points)} images, {kept} in the box")
        time.sleep(0.2)
    return found


def fetch_images(ids: list[str]) -> list[dict]:
    """The fields of the images, BATCH ids in each request (one by one if the API refuses a batch)."""
    out = []
    for k in range(0, len(ids), BATCH):
        part = ids[k:k + BATCH]
        try:
            data = graph("images", {"image_ids": ",".join(part), "fields": FIELDS})
            got = data.get("data", [])
        except urllib.error.HTTPError as error:
            print(f"  a batch: HTTP {error.code}, one by one")
            got = []
            for one in part:
                try:
                    got.append(graph(one, {"fields": FIELDS}))
                except urllib.error.HTTPError as e:
                    print(f"  image {one}: HTTP {e.code}")
        out.extend(g for g in got if g.get("captured_at") is not None)
        print(f"images {min(k + BATCH, len(ids))}/{len(ids)}")
        time.sleep(0.1)
    return out


def tile_row(image_id: str, props: dict, lonlat: tuple[float, float]) -> list:
    """A row of the index from the values of a coverage tile only (computed null:
    no computed position or direction, and the id of the author, not the name)."""
    when = dt.datetime.fromtimestamp(int(props.get("captured_at", 0)) / 1000.0, tz=dt.timezone.utc).astimezone(VIETNAM)
    compass = props.get("compass_angle")
    return [image_id, when.strftime("%Y-%m-%dT%H:%M"), round(lonlat[0], 7), round(lonlat[1], 7), None,
            None if compass is None else round(float(compass) % 360.0, 1), None,
            "spherical" if props.get("is_pano") else "", str(props.get("sequence_id") or ""),
            str(props.get("creator_id") or "")]


def command_index(budget_s: float = INDEX_BUDGET_S) -> int:
    """The index: each image of the tiles in the box. An image that is new
    gets a row from its tile; then the API gives the fields of the rows that
    have no answer yet (computed None), first the images of 2017 to 2021, in
    a time budget: the index is written after each part, and the next run goes
    on from there."""
    area = json.loads(AREA.read_text(encoding="utf-8"))["bbox"]
    index = load_index()
    known = {r[0]: r for r in index["images"]}
    in_tiles = tile_ids(area)
    rows = {i: known[i] for i in in_tiles if i in known}
    for image_id, (props, lonlat) in in_tiles.items():
        if image_id not in rows:
            rows[image_id] = tile_row(image_id, props, lonlat)
    gone = len(set(known) - set(in_tiles))
    def save() -> None:
        write_index({
            "note": "Made by tools/geo/photos.py index (plan 0009, R5e). Do not change by hand. One row for each image of Mapillary in the play area (data/geo/raw/mapillary.json, the box of data/geo/area.json). date: the time of Vietnam (UTC+7). lon, lat: computed_geometry (computed 1), the position of the camera (computed 0), or the position in the coverage tile (computed null: the API did not answer for the image yet). compass: compass_angle; computed_compass: computed_compass_angle (degrees from the north to the east). camera: camera_type (spherical and equirectangular are 360). author: the username of the creator (or the id of the creator, from the tile). The link of an image: https://www.mapillary.com/app/?pKey=ID. The images are CC BY-SA 4.0: the credit is the author, Mapillary, and the license.",
            "license": LICENSE,
            "updated": dt.date.today().isoformat(),
            "bbox": area,
            "tiles": f"mly1_public, zoom {ZOOM}",
            "columns": COLUMNS,
            "images": list(rows.values()),
        })
    save()
    waiting = sorted((r for r in rows.values() if r[4] is None),
                     key=lambda r: (0 if 2017 <= int(r[1][:4]) <= 2021 else 1, r[1]))
    print(f"{len(in_tiles)} images in the tiles, {len(known)} in the index before, {gone} not in the tiles now, "
          f"{len(waiting)} wait for the API")
    start = time.monotonic()
    ids = [r[0] for r in waiting]
    done = 0
    for k in range(0, len(ids), BATCH * 20):
        if time.monotonic() - start > budget_s:
            print(f"the time budget ({budget_s:.0f} s) is over: {len(ids) - done} images wait for the next run")
            break
        part = ids[k:k + BATCH * 20]
        for image in fetch_images(part):
            r = row(image)
            if r[2] is not None:
                rows[r[0]] = r
        done += len(part)
        save()
    print(f"{len(rows)} images in {INDEX.name}")
    return 0


# ----- the places and the report -----


class Places:
    """The projection of the game (data/geo/build/world.json): degrees to game meters (x east, z south)."""

    def __init__(self):
        from geodata.projection import Projection
        origin = json.loads(WORLD.read_text(encoding="utf-8"))["origin"]
        self.projection = Projection(origin["utm_e"], origin["utm_n"])

    def game(self, lon: float, lat: float) -> tuple[float, float]:
        x, z = self.projection.to_game(lon, lat)
        return float(x), float(z)


def bearing(dx: float, dz: float) -> float:
    """The compass direction (from the north to the east) of a game vector."""
    return math.degrees(math.atan2(dx, -dz)) % 360.0


def angle_between(a: float, b: float) -> float:
    return abs((a - b + 180.0) % 360.0 - 180.0)


def year(r: dict) -> int:
    return int(str(r["date"])[:4])


def segment_distance(px, pz, ax, az, bx, bz) -> float:
    dx, dz = bx - ax, bz - az
    length = dx * dx + dz * dz
    t = 0.0 if length == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / length))
    return math.hypot(px - ax - t * dx, pz - az - t * dz)


def street_counts(images: list[dict], roads: list[dict]) -> dict[str, dict[int, int]]:
    """For each named road, the images in ROAD_M of it, by year (an image counts once, on its nearest road)."""
    cell = 50.0
    grid: dict[tuple[int, int], list] = {}
    for road in roads:
        if not road.get("name"):
            continue
        points = road["points"]
        for a, b in zip(points, points[1:]):
            for gx in range(int(math.floor(min(a[0], b[0]) / cell)) - 1, int(math.floor(max(a[0], b[0]) / cell)) + 2):
                for gz in range(int(math.floor(min(a[2], b[2]) / cell)) - 1, int(math.floor(max(a[2], b[2]) / cell)) + 2):
                    grid.setdefault((gx, gz), []).append((road["name"], a[0], a[2], b[0], b[2]))
    counts: dict[str, dict[int, int]] = {}
    for r in images:
        best, best_d = None, ROAD_M
        for name, ax, az, bx, bz in grid.get((int(math.floor(r["x"] / cell)), int(math.floor(r["z"] / cell))), []):
            d = segment_distance(r["x"], r["z"], ax, az, bx, bz)
            if d <= best_d:
                best, best_d = name, d
        if best:
            counts.setdefault(best, {})
            counts[best][year(r)] = counts[best].get(year(r), 0) + 1
    return counts


def with_positions(index: dict, places: Places) -> list[dict]:
    out = []
    for r in records(index):
        if r["lon"] is None:
            continue
        r["x"], r["z"] = places.game(r["lon"], r["lat"])
        out.append(r)
    return out


def draw_map(images: list[dict], roads: list[dict], path: Path) -> None:
    from PIL import Image, ImageDraw
    years = sorted({year(r) for r in images}) or [2019]
    xs = [r["x"] for r in images] or [0.0]
    zs = [r["z"] for r in images] or [0.0]
    x0, x1, z0, z1 = min(xs) - 50, max(xs) + 50, min(zs) - 50, max(zs) + 50
    panel_w = 360
    scale = panel_w / max(x1 - x0, 1.0)
    panel_h = int((z1 - z0) * scale) + 24
    columns = min(4, len(years))
    rows = math.ceil(len(years) / columns)
    sheet = Image.new("RGB", (columns * panel_w, rows * panel_h), (250, 250, 246))
    draw = ImageDraw.Draw(sheet)
    for k, y in enumerate(years):
        ox, oz = (k % columns) * panel_w, (k // columns) * panel_h
        def at(x, z):
            return ox + (x - x0) * scale, oz + 24 + (z - z0) * scale
        for road in roads:
            pts = [at(p[0], p[2]) for p in road["points"]]
            if len(pts) > 1:
                draw.line(pts, fill=(205, 205, 200), width=1)
        mine = [r for r in images if year(r) == y]
        good = 2017 <= y <= 2021
        for r in mine:
            px, pz = at(r["x"], r["z"])
            draw.rectangle([px - 1, pz - 1, px + 1, pz + 1], fill=(200, 40, 30) if good else (40, 90, 170))
        draw.text((ox + 6, oz + 4), f"{y}: {len(mine)} images", fill=(0, 0, 0), font=font(15))
        draw.rectangle([ox, oz, ox + panel_w - 1, oz + panel_h - 1], outline=(160, 160, 160))
    sheet.save(path, optimize=True)


def command_report() -> int:
    index = load_index()
    places = Places()
    images = with_positions(index, places)
    roads = json.loads(ROADS.read_text(encoding="utf-8"))["roads"]
    landmarks = json.loads(LANDMARKS.read_text(encoding="utf-8"))["landmarks"]
    by_year: dict[int, int] = {}
    pano_by_year: dict[int, int] = {}
    for r in images:
        by_year[year(r)] = by_year.get(year(r), 0) + 1
        if r["camera"] in PANO:
            pano_by_year[year(r)] = pano_by_year.get(year(r), 0) + 1
    good = [r for r in images if 2017 <= year(r) <= 2021]
    lines = [
        "# The street photos of Mapillary in the play area",
        "",
        f"Made by `tools/geo/photos.py report` (plan 0009, R5e) from `data/geo/raw/mapillary.json` ({index.get('updated', '?')}). Do not change by hand.",
        "The images are CC BY-SA 4.0 (the author, Mapillary). The map: `photos_map.png` (red: 2017 to 2021).",
        "",
        f"{len(images)} images, {len({r['sequence'] for r in images})} sequences, {len({r['author'] for r in images})} authors. "
        f"{len(good)} images of 2017 to 2021.",
        "",
        "## The images by year",
        "",
        "| Year | Images | 360 | Sequences |",
        "|---|---|---|---|",
    ]
    for y in sorted(by_year):
        seqs = len({r["sequence"] for r in images if year(r) == y})
        lines.append(f"| {y} | {by_year[y]} | {pano_by_year.get(y, 0)} | {seqs} |")
    years = list(range(2017, 2022))
    lines += ["", f"## The images of 2017 to 2021 on each street (in {ROAD_M:.0f} m of the line of the road)", "",
              "| Street | " + " | ".join(str(y) for y in years) + " | All |", "|---|" + "---|" * (len(years) + 1)]
    counts = street_counts(good, roads)
    for name, by in sorted(counts.items(), key=lambda t: -sum(t[1].values())):
        lines.append(f"| {name} | " + " | ".join(str(by.get(y, 0)) for y in years) + f" | {sum(by.values())} |")
    lines += ["", f"## The images of 2017 to 2021 at each known place (in {PLACE_M:.0f} m of its position)", "",
              "| Place | " + " | ".join(str(y) for y in years) + " | All |", "|---|" + "---|" * (len(years) + 1)]
    for place in landmarks:
        position = place.get("position")
        if not position:
            continue
        near = [r for r in good if math.hypot(r["x"] - position[0], r["z"] - position[1]) <= PLACE_M]
        by = {y: sum(1 for r in near if year(r) == y) for y in years}
        lines.append(f"| {place['name_vi']} | " + " | ".join(str(by[y]) for y in years) + f" | {len(near)} |")
    points = json.loads(POINTS.read_text(encoding="utf-8"))
    lines += ["", "## The points of the contact sheets (`data/showcase/photo_points.json`)", "",
              "| Point | For | Years | Images that match | On the sheets |", "|---|---|---|---|---|"]
    for point, window, years in [(p, w, y) for p in points["points"] for w, y in windows(p, points)]:
        chosen, matched = choose(images, dict(point, years=years) if window else point, points["years"])
        span = "the weeks before Tết" if point.get("dates") else f"{years[0]} to {years[1]}"
        lines.append(f"| `{point['id']}` | {', '.join(point['for'])} | {span} | {matched} | {len(chosen)} |")
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    draw_map(images, roads, MAP)
    print(f"wrote {REPORT.name} and {MAP.name}")
    return 0


# ----- the sheets -----


def in_dates(r: dict, point: dict, years: list[int]) -> bool:
    """The image is in the days of the point, or in the years (the first and the last)."""
    day = str(r["date"])[:10]
    if point.get("dates"):
        return any(a <= day <= b for a, b in point["dates"])
    first, last = point.get("years", years)
    return first <= year(r) <= last


def windows(point: dict, points: dict) -> list[tuple[str, list[int]]]:
    """The windows of years of the sheets of a point: 2017 to 2021, and with
    "rule1" also the years before and after (report 0026, Q17, rule 1: a look
    that a photo before 2017 and a photo after 2021 both show was the look in 2019)."""
    out = [("", list(point.get("years", points["years"])))]
    if point.get("rule1") and not point.get("dates"):
        for name, span in points.get("rule1_years", {}).items():
            out.append((name, list(span)))
    return out


def direction(r: dict) -> float | None:
    value = r.get("computed_compass") if r.get("computed_compass") is not None else r.get("compass")
    return None if value is None else float(value)


def looks(r: dict, point: dict) -> bool:
    look = point.get("look", "any")
    if look == "any" or r["camera"] in PANO:
        return True
    heading = direction(r)
    if heading is None:
        return False
    if look == "toward":
        tx, tz = point.get("target", point["at"])
        if math.hypot(tx - r["x"], tz - r["z"]) < 3.0:
            return True
        return angle_between(heading, bearing(tx - r["x"], tz - r["z"])) <= TOWARD_DEG
    return any(angle_between(heading, float(b)) <= DIRECTION_DEG for b in look)


def choose(images: list[dict], point: dict, years: list[int]) -> tuple[list[dict], int]:
    """The images of a point (near first), spread over the years and the
    sequences: in one sequence, the images are SEQUENCE_SPACING_M apart or more."""
    ax, az = point["at"]
    matched = [r for r in images if math.hypot(r["x"] - ax, r["z"] - az) <= point["radius_m"]
               and in_dates(r, point, years) and looks(r, point)]
    matched.sort(key=lambda r: math.hypot(r["x"] - ax, r["z"] - az))
    by_year: dict[int, list[dict]] = {}
    taken: dict[str, list[dict]] = {}
    for r in matched:
        same = taken.setdefault(r["sequence"], [])
        if any(math.hypot(r["x"] - o["x"], r["z"] - o["z"]) < SEQUENCE_SPACING_M for o in same):
            continue
        same.append(r)
        by_year.setdefault(year(r), []).append(r)
    chosen: list[dict] = []
    limit = int(point.get("max", 12))
    while len(chosen) < limit and any(by_year.values()):
        for y in sorted(by_year):
            if by_year[y] and len(chosen) < limit:
                chosen.append(by_year[y].pop(0))
    chosen.sort(key=lambda r: (r["date"], r["id"]))
    return chosen, len(matched)


def font(size: int):
    from PIL import ImageFont
    for name in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default(size=size)


def picture(image_id: str, pano: bool) -> bytes:
    """The thumbnail of an image (1 024 px, or 2 048 px for a 360), from the cache or the API."""
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"{image_id}_{2048 if pano else 1024}.jpg"
    if path.exists():
        return path.read_bytes()
    field = "thumb_2048_url" if pano else "thumb_1024_url"
    url = graph(image_id, {"fields": field}).get(field)
    if not url:
        raise RuntimeError(f"image {image_id}: no {field}")
    data = get(url, show=f"the picture of {image_id}")
    path.write_bytes(data)
    return data


def view(r: dict, data: bytes, toward: float | None):
    """The picture of an image; for a 360, the part of PANO_VIEW_DEG toward the direction."""
    from PIL import Image
    img = Image.open(io.BytesIO(data)).convert("RGB")
    if r["camera"] in PANO and toward is not None and direction(r) is not None:
        w, h = img.size
        center = ((toward - direction(r)) / 360.0 + 0.5) % 1.0 * w
        half = PANO_VIEW_DEG / 360.0 * w / 2.0
        strip = Image.new("RGB", (w * 2, h))
        strip.paste(img, (0, 0))
        strip.paste(img, (w, 0))
        left = int(center - half) % w
        img = strip.crop((left, int(h * 0.22), left + int(2 * half), int(h * 0.78)))
    return img


def label(r: dict, toward: float | None) -> str:
    heading = direction(r)
    text = f"{r['id']}  {r['date'].replace('T', ' ')}  "
    if r["camera"] in PANO:
        text += f"360, the view to {toward:.0f}°" if toward is not None else "360"
    else:
        text += f"to {heading:.0f}°" if heading is not None else "no direction"
    return text + f"  {r['author']}"


def make_sheet(entries: list[tuple[dict, object, str]], title: str, width: int = TILE_W):
    from PIL import Image, ImageDraw
    rows = math.ceil(len(entries) / SHEET_COLUMNS)
    tile_h = int(width * 0.75)
    band = 22
    sheet = Image.new("RGB", (SHEET_COLUMNS * width, 30 + rows * (tile_h + band)), (20, 20, 20))
    draw = ImageDraw.Draw(sheet)
    draw.text((8, 6), title, fill=(255, 255, 255), font=font(16))
    for k, (_r, img, text) in enumerate(entries):
        x, y = (k % SHEET_COLUMNS) * width, 30 + (k // SHEET_COLUMNS) * (tile_h + band)
        fit = img.copy()
        fit.thumbnail((width, tile_h))
        sheet.paste(fit, (x + (width - fit.width) // 2, y + (tile_h - fit.height) // 2))
        draw.text((x + 4, y + tile_h + 3), text, fill=(255, 255, 210), font=font(12))
    return sheet


def credit_line(r: dict, file: str) -> str:
    return (f"| `{file}` | `{r['id']}` | {r['date'].replace('T', ' ')} | {r['author']}, Mapillary | {LICENSE} | "
            f"[link](https://www.mapillary.com/app/?pKey={r['id']}) |")


def write_credits(entries: list[str]) -> None:
    lines = [
        "# The street photos of Mapillary",
        "",
        "The contact sheets of `data/showcase/photo_points.json` and the pictures of single images (`detail_ID.jpg`),",
        "made by `tools/geo/photos.py` (plan 0009, R5e). Do not change by hand. Each image is CC BY-SA 4.0:",
        "its author, Mapillary, and the link of the image. A sheet keeps the license of its images.",
        "",
        "| File | Image | Date (UTC+7) | Author | License | Link |",
        "|---|---|---|---|---|---|",
    ]
    (OUT / "CREDITS.md").write_text("\n".join(lines + sorted(set(entries))) + "\n", encoding="utf-8")


def old_credits() -> list[str]:
    path = OUT / "CREDITS.md"
    if not path.exists():
        return []
    return [line for line in path.read_text(encoding="utf-8").splitlines() if line.startswith("| `")]


def command_sheets() -> int:
    index = load_index()
    images = with_positions(index, Places())
    points = json.loads(POINTS.read_text(encoding="utf-8"))
    # The images near the points that have only the values of their tile get
    # their fields from the API first (the position after processing, the
    # direction, and the name of the author for the credit).
    near = set()
    for point in points["points"]:
        ax, az = point["at"]
        for r in images:
            if r["computed"] is None and math.hypot(r["x"] - ax, r["z"] - az) <= point["radius_m"] + 30.0 \
                    and any(in_dates(r, dict(point, years=y) if w else point, points["years"]) for w, y in windows(point, points)):
                near.add(r["id"])
    if near:
        print(f"{len(near)} images near the points get their fields from the API")
        by_id = {r[0]: r for r in index["images"]}
        for image in fetch_images(sorted(near)):
            r = row(image)
            if r[2] is not None:
                by_id[r[0]] = r
        index["images"] = list(by_id.values())
        write_index(index)
        images = with_positions(index, Places())
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("sheet_*.jpg"):
        old.unlink()
    credits = [c for c in old_credits() if c.startswith("| `detail_")]
    per_sheet = SHEET_COLUMNS * SHEET_ROWS
    for point, window, years in [(p, w, y) for p in points["points"] for w, y in windows(p, points)]:
        chosen, matched = choose(images, dict(point, years=years) if window else point, points["years"])
        entries = []
        for r in chosen:
            toward = None
            if r["camera"] in PANO:
                tx, tz = point.get("target", point["at"])
                toward = bearing(tx - r["x"], tz - r["z"]) if math.hypot(tx - r["x"], tz - r["z"]) > 3.0 else direction(r)
            try:
                # The privacy step (report 0026, D-0026-39): no plate or face that a person can read.
                img, blurred = privacy.clean(view(r, picture(r["id"], r["camera"] in PANO), toward), r["id"], point["id"])
            except Exception as error:  # noqa: BLE001 - keep the others
                print(f"  {point['id']}: image {r['id']}: {error}")
                continue
            if img is None:
                print(f"  {point['id']}: image {r['id']}: left out (data/showcase/photo_privacy.json)")
                continue
            if blurred:
                print(f"  {point['id']}: image {r['id']}: {blurred} boxes blurred")
            entries.append((r, img, label(r, toward)))
        label_years = f"{years[0]} to {years[1]}" if not point.get("dates") else "the weeks before Tết"
        print(f"{point['id']} {label_years}: {matched} images match, {len(entries)} on the sheets")
        for k in range(0, len(entries), per_sheet):
            part = entries[k:k + per_sheet]
            name = f"sheet_{point['id']}{'_' + window if window else ''}_{k // per_sheet + 1}.jpg"
            title = f"{point['id']} ({', '.join(point['for'])}), {label_years}: {k + 1} to {k + len(part)} of {len(entries)}. CC BY-SA 4.0, Mapillary: see CREDITS.md"
            make_sheet(part, title).save(OUT / name, quality=78, optimize=True)
            credits.extend(credit_line(r, name) for r, _img, _t in part)
    write_credits(credits)
    return 0


def command_detail(ids: list[str]) -> int:
    index = load_index()
    by_id = {r["id"]: r for r in records(index)}
    OUT.mkdir(parents=True, exist_ok=True)
    credits = old_credits()
    for image_id in ids:
        r = by_id.get(image_id)
        if r is None:
            print(f"ERROR: image {image_id} is not in the index")
            continue
        from PIL import Image
        img, _blurred = privacy.clean(Image.open(io.BytesIO(picture(image_id, r["camera"] in PANO))).convert("RGB"),
                                      image_id, "detail")
        if img is None:
            print(f"the image {image_id} is left out (data/showcase/photo_privacy.json)")
            continue
        name = f"detail_{image_id}.jpg"
        img.save(OUT / name, quality=85, optimize=True)
        credits = [c for c in credits if not c.startswith(f"| `{name}`")] + [credit_line(r, name)]
        print(f"wrote {name}")
    write_credits(credits)
    return 0


def check() -> int:
    found = []
    if INDEX.exists():
        index = load_index()
        if index.get("columns") != COLUMNS:
            found.append(f"{INDEX.relative_to(ROOT)}: the columns are not {COLUMNS}")
        ids = [r[0] for r in index["images"]]
        if len(ids) != len(set(ids)):
            found.append(f"{INDEX.relative_to(ROOT)}: an id is two times in the index")
        for r in index["images"]:
            if len(r) != len(COLUMNS) or not str(r[0]).isdigit() or "http" in json.dumps(r):
                found.append(f"{INDEX.relative_to(ROOT)}: the row {r[:2]} is not correct (no URL in the index)")
                break
    points = json.loads(POINTS.read_text(encoding="utf-8"))
    names = set()
    for point in points["points"]:
        for key in ("id", "for", "about", "at", "radius_m", "look"):
            if key not in point:
                found.append(f"{POINTS.relative_to(ROOT)}: {point.get('id', '?')}: no \"{key}\"")
        if point.get("id") in names:
            found.append(f"{POINTS.relative_to(ROOT)}: the id {point['id']} is two times")
        names.add(point.get("id"))
    if OUT.exists():
        credited = {line.split("`")[1] for line in old_credits()}
        for picture_file in sorted(OUT.glob("*.jpg")):
            if picture_file.name not in credited:
                found.append(f"docs/reference/mapillary/{picture_file.name} has no credit in CREDITS.md")
        for name in sorted(credited):
            if not (OUT / name).exists():
                found.append(f"docs/reference/mapillary/CREDITS.md: {name} is not there")
    for line in found:
        print(f"ERROR: {line}")
    print(f"{len(found)} problems.")
    return 1 if found else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", nargs="?", choices=["index", "report", "sheets", "detail"])
    parser.add_argument("ids", nargs="*")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        return check()
    if args.command == "index":
        return command_index()
    if args.command == "report":
        return command_report()
    if args.command == "sheets":
        return command_sheets()
    if args.command == "detail":
        return command_detail(args.ids)
    parser.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
