"""The water of the land (report 0009, D-0009-16): the water areas of
OpenStreetMap (natural=water, and the areas with a key "water") on the land of
the play area, of at least min_area_m2 (data/geo/inland_water.json), as flat
water at their level: Bàu Sen, Bàu Trũng, the lakes of Hồ Mây, the ponds, the
salt pans, and Rạch Bến Đình.

- The level of an area is the median of Copernicus (over the mean sea level,
  before the bare earth) in its outline: Copernicus has each water body flat
  at the height of its water.
- The ground in the outline goes depth_m under the level, but not under a road
  (a bridge or a causeway keeps its road).
- data/geo/build/inland_water.json has each area with its level and its
  triangles (game x, z), for the mesh of the game.
- No trees and no boxes of the town stand on the water (build.py).
The water of a creek that the tide fills (Rạch Bến Đình) is flat at its level
too: the game does not move it with the tide.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import shapely
from shapely.geometry import Polygon


def areas(records: list, land, min_area_m2: float) -> list[dict]:
    """The water areas on the land: records are (osm id, tags, shape in map
    coordinates). Each area is a polygon of at least min_area_m2."""
    out = []
    for osm_id, tags, shape in records:
        on_land = shape.intersection(land)
        parts = [on_land] if isinstance(on_land, Polygon) else list(getattr(on_land, "geoms", []))
        for part in parts:
            if isinstance(part, Polygon) and part.area >= min_area_m2:
                out.append({"osm": osm_id, "name": tags.get("name", ""), "kind": tags.get("water", tags.get("natural", "")),
                            "polygon": part})
    return out


def levels(grid, heights: np.ndarray, water: list[dict], rasterize) -> None:
    """The level of each area: the median of heights (Copernicus over the mean
    sea level) in its cells, or at its middle when it has no cell."""
    for area in water:
        cells = rasterize(grid, [area["polygon"]])
        if cells.any():
            area["level"] = float(np.median(heights[cells]))
        else:
            middle = area["polygon"].representative_point()
            col = int(round((middle.x - grid.x0) / grid.step))
            row = int(round((-middle.y - grid.z0) / grid.step))
            row = min(max(row, 0), heights.shape[0] - 1)
            col = min(max(col, 0), heights.shape[1] - 1)
            area["level"] = float(heights[row, col])


def cut(grid, water: list[dict], depth_m: float, rasterize, keep: np.ndarray | None = None) -> int:
    """The ground in each area goes depth_m under its level (not the cells of
    keep: the roads). The count of the cells that change."""
    changed = 0
    for area in water:
        cells = rasterize(grid, [area["polygon"]])
        if keep is not None:
            cells &= ~keep
        bottom = area["level"] - depth_m
        lower = cells & (grid.heights > bottom)
        grid.heights[lower] = bottom
        changed += int(lower.sum())
    return changed


def triangles(polygon: Polygon) -> list[float]:
    """The triangles of a polygon (with its holes), as a flat list of game
    points x, z (z = -north), each triangle clockwise seen from above in the
    game (the front of a face up, AGENTS.md section 5f)."""
    flat = []
    for tri in shapely.constrained_delaunay_triangles(polygon).geoms:
        coords = list(tri.exterior.coords)[:3]
        # Counterclockwise on the map (x east, y north) is clockwise in the game (z = -north).
        if shapely.Polygon(coords).exterior.is_ccw is False:
            coords = coords[::-1]
        for x, y in coords:
            flat += [round(x, 2), round(-y, 2)]
    return flat


def contains(water: list[dict]):
    """A test of a map point (x, y): True on the water."""
    tree = shapely.STRtree([a["polygon"] for a in water]) if water else None

    def inside(x: float, y: float) -> bool:
        if tree is None:
            return False
        point = shapely.Point(x, y)
        return any(water[i]["polygon"].contains(point) for i in tree.query(point))
    return inside


def write(path: Path, water: list[dict], config: dict) -> dict:
    """data/geo/build/inland_water.json, and the numbers for the report."""
    records = [{"osm": a["osm"], "name": a["name"], "kind": a["kind"], "level": round(a["level"], 2),
                "area_m2": round(a["polygon"].area), "triangles": triangles(a["polygon"])} for a in water]
    data = {"note": "Made by tools/geo/build.py (geodata/inland_water.py, report 0009, D-0009-16): the water areas of "
                    "OpenStreetMap (ODbL) on the land, flat at their level (m over the mean sea level).",
            "color": config["color"], "roughness": config["roughness"], "areas": records}
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    named = sorted([(a["name"], round(a["polygon"].area), round(a["level"], 2)) for a in water if a["name"]],
                   key=lambda n: -n[1])
    return {"areas": len(records), "area_m2": round(sum(a["polygon"].area for a in water)), "named": named}
