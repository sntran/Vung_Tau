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
- the colors of the wall and of the roof (D8: a wall does not have the color of
  a touching neighbor).
The buildings with no first year (buildings_unseen, Check) are not in the
store of buildings_2019, so they are not here.
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


def make(buildings: list, sample, palette: dict, chunk_m: float) -> tuple[dict, dict]:
    """The records of each chunk {(cx, cz): [record]} and the numbers for the report.
    sample(x, z) gives the height of the ground at game points (arrays)."""
    shares = roof_shares(palette)
    walls = palette["walls"]
    wall_colors = [w["color"] for w in walls]
    wall_weights = [float(w["weight"]) for w in walls]
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
    colors_of: dict = {}
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
        # D8: not the color of a touching neighbor that has its color already.
        taken = {colors_of[j] for j in neighbors if j in colors_of}
        wall = _pick(wall_colors, wall_weights, _unit(str(b["id"]) + "w"))
        step = 0
        while wall in taken and step < len(wall_colors):
            wall = wall_colors[(wall_colors.index(wall) + 1) % len(wall_colors)]
            step += 1
        colors_of[index] = wall
        center = polygon.centroid
        key = (math.floor(center.x / chunk_m), math.floor(-center.y / chunk_m))
        record = [str(b["id"])[:12], round(bases[index], 2), round(tops[index], 2), ROOF_KINDS.index(roof),
                  wall, roof_color, [round(v, 2) for x, y in coords for v in (x, -y)],
                  [round(h, 2) for h in hidden]]
        if roof == "tiles":
            record.append(round(min(width * 0.5 * TILE_PITCH, 3.0), 2))
        chunks.setdefault(key, []).append(record)
    numbers["chunks"] = len(chunks)
    numbers["roof_shares"] = {k: round(v, 3) for k, v in shares.items()}
    return chunks, numbers


COLUMNS = ["id", "base", "top", "roof", "wall", "roof_color", "outline", "hidden", "tile_rise"]


def write(folder: Path, chunks: dict, chunk_m: float) -> int:
    """One file for each chunk: town/CX_CZ.json."""
    folder.mkdir(parents=True, exist_ok=True)
    for (cx, cz), records in chunks.items():
        data = {"chunk_m": chunk_m, "columns": COLUMNS, "roofs": list(ROOF_KINDS), "buildings": records}
        (folder / f"{cx}_{cz}.json").write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    index = {"note": "Made by tools/geo/build.py (plan 0009, phase 2): the boxes of the buildings of 2019 in each "
                     "chunk. Outlines: Overture Maps (ODbL); heights: Open Buildings 2.5D Temporal (CC BY 4.0).",
             "chunk_m": chunk_m, "chunks": sorted([[cx, cz, len(r)] for (cx, cz), r in chunks.items()])}
    (folder / "index.json").write_text(json.dumps(index, separators=(",", ":")), encoding="utf-8")
    return sum(len(r) for r in chunks.values())
