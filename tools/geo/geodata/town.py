"""The far level of the town (plan 0009, phase 2, R6, R10): each building of
buildings_2019 as a box of its outline and its height, with a roof, in the
chunks of 256 m of plan 0005 (data/geo/build/town/X_Z.json).

For each building the build gives:
- the outline (simplified to SIMPLIFY_M; with more than MAX_POINTS points, the
  smallest rectangle around it), counterclockwise seen from above in the
  coordinates of the map, written as game points (x, z);
- the base (the lowest ground under the outline, minus BASE_SINK_M) and the top
  (the median ground under it plus the height of the 2.5D data);
- for each wall, the height to which a touching neighbor hides it (a row of
  houses with shared walls draws only the parts over the neighbor, R4, W17);
- the roof: a flat terrace, a metal roof, or tiles (a hip roof), by the shares
  of the palette of plan 0004 (R10a, R10c) and the id of the building (D4);
- the colors of the wall and of the roof (D8: a wall does not have the paint of
  a touching neighbor). Report 0009, D-0009-15: the color of a wall is the mean
  of its front from far: its paint, with the dark of the windows and the
  balconies of each storey and of the open ground floor of the shops
  ("far_fronts" of data/world/palette.json, front_color()). The roof colors of
  the palette are measured from aerial photos with the light of the sun in
  them, so a far roof takes "far_roofs" (the factor of the far roofs of the
  ground shader). A wall from the street is darker at its foot ("foot_shade":
  the shade of the street, as the far roofs of the ground shader of plan 0005,
  0.46), and about 30 % of the walls are bold, as in the house kit (D-0004-09).
The buildings with no first year (buildings_unseen, Check) are not in the
store of buildings_2019, so they are not here.

Report 0009, D-0009-14: a building of TALL_M or more is in town/tall.json, not
in its chunk: the game shows it to the end of the far range on each preset.
index.json has "far_color", the mean color of the boxes seen from far (each
roof by its area, and the half of each wall that is not hidden that faces the
eye): the far pattern of the town on the ground takes it past the range of
the boxes, so that no line shows there.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np
import shapely
from shapely.geometry import Polygon
from shapely.geometry.polygon import orient
from shapely.strtree import STRtree

SIMPLIFY_M = 0.6
MAX_POINTS = 12
MIN_AREA_M2 = 8.0
BASE_SINK_M = 0.3
NEIGHBOR_GAP_M = 0.6
# A hip roof of tiles: the slope, and only on buildings this small and low.
TILE_PITCH = 0.55
TILE_MAX_AREA_M2 = 250.0
TILE_MAX_HEIGHT_M = 9.0
ROOF_KINDS = ("terrace", "metal", "tiles")
# Report 0009, D-0009-14: the towers show to the end of the far range.
TALL_M = 25.0


def _unit(seed: str) -> float:
    """A number from 0 to 1 from a text (the same each time, D4)."""
    return int(hashlib.sha1(seed.encode()).hexdigest()[:8], 16) / 0xFFFFFFFF


def _pick(colors: list, weights: list, value: float) -> str:
    total = float(sum(weights))
    acc = 0.0
    for color, weight in zip(colors, weights):
        acc += weight / total
        if value <= acc:
            return color
    return colors[-1]


def roof_shares(palette: dict) -> dict:
    """The share of each roof kind: tiles from the palette (roof_tiles.share);
    the metal roofs and the terraces share the rest by the weights of their
    clusters in the same top-down photo (R10c, D-0004-03)."""
    tiles = float(palette["roof_tiles"]["share"])
    metal = sum(float(c["weight"]) for c in palette["metal_roofs"]["colors"])
    terrace = sum(float(c["weight"]) for c in palette["terraces"]["colors"])
    rest = 1.0 - tiles
    return {"tiles": tiles, "metal": rest * metal / (metal + terrace), "terrace": rest * terrace / (metal + terrace)}


def outline_of(points) -> Polygon | None:
    """The outline of a building as a clean polygon in map coordinates (x, -z),
    simplified; None when it is too small."""
    ring = [(float(x), -float(z)) for x, z in points]
    polygon = Polygon(ring).buffer(0)
    if polygon.geom_type == "MultiPolygon":
        polygon = max(polygon.geoms, key=lambda g: g.area)
    if polygon.is_empty or polygon.area < MIN_AREA_M2:
        return None
    simple = polygon.simplify(SIMPLIFY_M, preserve_topology=True)
    if simple.is_empty or not simple.is_valid or simple.area < MIN_AREA_M2:
        simple = polygon.minimum_rotated_rectangle
    if len(simple.exterior.coords) - 1 > MAX_POINTS:
        simple = polygon.minimum_rotated_rectangle
    return orient(Polygon(list(simple.exterior.coords)), sign=1.0)


def _rect_axes(polygon: Polygon) -> tuple[float, float]:
    rect = polygon.minimum_rotated_rectangle
    pts = np.array(rect.exterior.coords)[:4]
    a = np.linalg.norm(pts[1] - pts[0])
    b = np.linalg.norm(pts[2] - pts[1])
    return float(min(a, b)), float(max(a, b))


def _linear(color: str) -> np.ndarray:
    c = np.array([int(color[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _srgb_hex(linear: np.ndarray) -> str:
    c = np.clip(linear, 0.0, 1.0)
    c = np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)
    return "#" + "".join(f"{int(round(v * 255)):02X}" for v in c)


def _scaled(color: str, factor: float) -> str:
    """The sRGB values of a color times a factor (D-0009-15: the light of the sun in a measured roof color)."""
    return "#" + "".join(f"{min(255, int(round(int(color[i:i + 2], 16) * factor))):02X}" for i in (1, 3, 5))


def front_color(paint: str, height: float, fronts: dict) -> str:
    """The mean color of a front of this height from far (D-0009-15): the paint,
    with the share of the dark of the openings, in linear light. The ground
    floor (one storey) has the share of the open shops, the other storeys the
    share of the windows and the balconies."""
    ground = min(1.0, float(fronts["storey_m"]) / max(height, 0.1))
    share = float(fronts["upper_openings"]) * (1.0 - ground) + float(fronts["ground_openings"]) * ground
    return _srgb_hex(_linear(paint) * (1.0 - share) + _linear(fronts["dark"]) * share)


def make(buildings: list, sample, palette: dict, chunk_m: float) -> tuple[dict, dict, dict]:
    """The records of each chunk {(cx, cz): [record]}, the records of the tall
    buildings by chunk, and the numbers for the report. sample(x, z) gives the
    height of the ground at game points (arrays)."""
    shares = roof_shares(palette)
    walls = palette["walls"]
    # The measured colors: the colors of the palette are 10 % lighter for the
    # haze of the house kit (R10a), and a far level has the haze of the scene.
    wall_colors = [w.get("measured", w["color"]) for w in walls]
    wall_weights = [float(w["weight"]) for w in walls]
    # The bold walls (one color each; a two-color front from far is its main color).
    bold_colors = list(dict.fromkeys(w["color"] for w in palette.get("bold_walls", [])))
    bold_share = float(palette.get("bold_share", 0.0))
    # The shade of the street at the foot of a wall (1 at its top).
    foot_shade = float(palette.get("far_fronts", {}).get("foot_shade", 1.0))
    metal = palette["metal_roofs"]["colors"]
    terraces = palette["terraces"]["colors"]
    tiles = palette["roof_tiles"]["colors"]
    items = []
    for b in buildings:
        polygon = outline_of(b["outline"])
        if polygon is None or not b.get("height"):
            continue
        items.append((b, polygon))
    tree = STRtree([p for _b, p in items])
    numbers = {"buildings": len(items), "left_out_small": len(buildings) - len(items),
               "roofs": {k: 0 for k in ROOF_KINDS}, "hidden_walls": 0, "walls": 0}
    tops = []
    bases = []
    for b, polygon in items:
        coords = np.array(polygon.exterior.coords)[:-1]
        inner = polygon.representative_point()
        xs = np.append(coords[:, 0], inner.x)
        zs = -np.append(coords[:, 1], inner.y)
        ground = np.asarray(sample(xs, zs), dtype=np.float64)
        bases.append(float(ground.min()) - BASE_SINK_M)
        tops.append(float(np.median(ground)) + float(b["height"]))
    chunks: dict = {}
    tall: dict = {}
    colors_of: dict = {}
    far_sum = np.zeros(3)
    far_weight = 0.0
    for index, (b, polygon) in enumerate(items):
        coords = np.array(polygon.exterior.coords)[:-1]
        n = len(coords)
        # The height to which a touching neighbor hides each wall.
        hidden = [0.0] * n
        near = tree.query(polygon.buffer(NEIGHBOR_GAP_M))
        neighbors = [j for j in near if j != index]
        for e in range(n):
            a, c = coords[e], coords[(e + 1) % n]
            edge = np.array(c) - np.array(a)
            length = float(np.hypot(*edge))
            if length < 0.3:
                continue
            outward = np.array([edge[1], -edge[0]]) / length  # the outline is counterclockwise
            middle = (np.array(a) + np.array(c)) / 2.0 + outward * (NEIGHBOR_GAP_M / 2.0)
            point = shapely.Point(middle)
            for j in neighbors:
                if items[j][1].buffer(0.05).contains(point):
                    hidden[e] = max(hidden[e], tops[j])
        numbers["walls"] += n
        numbers["hidden_walls"] += sum(1 for e in range(n) if hidden[e] >= tops[index] - 0.05)
        area = polygon.area
        width, _length = _rect_axes(polygon)
        unit = _unit(str(b["id"]))
        if unit < shares["tiles"] and area <= TILE_MAX_AREA_M2 and float(b["height"]) <= TILE_MAX_HEIGHT_M:
            roof = "tiles"
            roof_color = tiles[int(_unit(str(b["id"]) + "r") * len(tiles)) % len(tiles)]
        elif unit < shares["tiles"] + shares["metal"] and float(b["height"]) <= TILE_MAX_HEIGHT_M * 1.5:
            roof = "metal"
            roof_color = _pick([c["color"] for c in metal], [float(c["weight"]) for c in metal], _unit(str(b["id"]) + "r"))
        else:
            roof = "terrace"
            roof_color = _pick([c["color"] for c in terraces], [float(c["weight"]) for c in terraces], _unit(str(b["id"]) + "r"))
        numbers["roofs"][roof] += 1
        if "far_roofs" in palette:
            roof_color = _scaled(roof_color, float(palette["far_roofs"]["light"]))
        # D8: not the color of a touching neighbor that has its color already.
        # A share of the walls is bold, as the house kit of plan 0004 (D-0004-09).
        taken = {colors_of[j] for j in neighbors if j in colors_of}
        choices = wall_colors
        if bold_colors and _unit(str(b["id"]) + "b") < bold_share:
            choices = bold_colors
            wall = bold_colors[int(_unit(str(b["id"]) + "w") * len(bold_colors)) % len(bold_colors)]
        else:
            wall = _pick(wall_colors, wall_weights, _unit(str(b["id"]) + "w"))
        step = 0
        while wall in taken and step < len(choices):
            wall = choices[(choices.index(wall) + 1) % len(choices)]
            step += 1
        colors_of[index] = wall
        front = front_color(wall, float(b["height"]), palette["far_fronts"]) if "far_fronts" in palette else wall
        if float(b["height"]) >= TALL_M and "towers" in palette:
            # Report 0009, D-0009-24: a tower takes a color of the towers of the
            # photos, as its far color (the photos have the windows in it).
            towers = palette["towers"]["colors"]
            front = _pick([c["color"] for c in towers], [float(c["weight"]) for c in towers], _unit(str(b["id"]) + "t"))
        center = polygon.centroid
        key = (math.floor(center.x / chunk_m), math.floor(-center.y / chunk_m))
        # The id (12 characters; a box of the raster keeps its whole id, "raster-ROW-COLUMN": the game tags
        # each box by its id, and the start of the ids of the raster is the same).
        box_id = str(b["id"]) if str(b["id"]).startswith("raster-") else str(b["id"])[:12]
        record = [box_id, round(bases[index], 2), round(tops[index], 2), ROOF_KINDS.index(roof),
                  front, roof_color, [round(v, 2) for x, y in coords for v in (x, -y)],
                  [round(h, 2) for h in hidden]]
        if roof == "tiles":
            record.append(round(min(width * 0.5 * TILE_PITCH, 3.0), 2))
        (tall if float(b["height"]) >= TALL_M else chunks).setdefault(key, []).append(record)
        # The far color: the roof by its area, and the half of the walls that faces the eye.
        wall_area = 0.0
        wall_light = 0.0
        for e in range(n):
            a, c = coords[e], coords[(e + 1) % n]
            part = float(np.hypot(*(np.array(c) - np.array(a)))) * max(tops[index] - max(bases[index], hidden[e]), 0.0)
            wall_area += part
            # A wall from the street has the shade at its foot; a wall over a neighbor has not.
            wall_light += part * ((foot_shade + 1.0) / 2.0 if hidden[e] <= bases[index] + 0.05 else 1.0)
        far_sum += _linear(roof_color) * area + _linear(front) * wall_light * 0.5
        far_weight += area + wall_area * 0.5
    numbers["chunks"] = len(chunks)
    numbers["tall"] = sum(len(r) for r in tall.values())
    numbers["roof_shares"] = {k: round(v, 3) for k, v in shares.items()}
    numbers["far_color"] = _srgb_hex(far_sum / max(far_weight, 1e-9))
    numbers["foot_shade"] = foot_shade
    return chunks, tall, numbers


COLUMNS = ["id", "base", "top", "roof", "wall", "roof_color", "outline", "hidden", "tile_rise"]


def write(folder: Path, chunks: dict, chunk_m: float, tall: dict | None = None, far_color: str = "#808080",
          foot_shade: float = 1.0) -> int:
    """One file for each chunk (town/CX_CZ.json), the tall buildings
    (town/tall.json, by chunk), and town/index.json."""
    folder.mkdir(parents=True, exist_ok=True)
    tall = tall or {}
    data = {"chunk_m": chunk_m, "columns": COLUMNS, "roofs": list(ROOF_KINDS), "tall_m": TALL_M,
            "chunks": sorted([[cx, cz, records] for (cx, cz), records in tall.items()], key=lambda c: (c[0], c[1]))}
    (folder / "tall.json").write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    for (cx, cz), records in chunks.items():
        data = {"chunk_m": chunk_m, "columns": COLUMNS, "roofs": list(ROOF_KINDS), "buildings": records}
        (folder / f"{cx}_{cz}.json").write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    index = {"note": "Made by tools/geo/build.py (plan 0009, phase 2): the boxes of the buildings of 2019 in each "
                     "chunk. Outlines: Overture Maps (ODbL); heights: Open Buildings 2.5D Temporal (CC BY 4.0). A box whose "
                     "id starts with \"raster-\" has the source raster: a group of cells of the 2.5D raster of 2019 with a "
                     "building and no outline that touches a street (report 0009, D-0009-22; data/geo/raw/buildings/"
                     "raster_2019.json).",
             "chunk_m": chunk_m, "far_color": far_color, "foot_shade": foot_shade, "tall": sum(len(r) for r in tall.values()),
             "chunks": sorted([[cx, cz, len(r)] for (cx, cz), r in chunks.items()])}
    (folder / "index.json").write_text(json.dumps(index, separators=(",", ":")), encoding="utf-8")
    return sum(len(r) for r in chunks.values()) + sum(len(r) for r in tall.values())
