"""Report 0009, Q14: the land around the play area on the horizon (Long Hải,
Núi Dinh, Cần Giờ): a far grid of the Copernicus DEM (data/geo/raw/mainland.tif,
fetch.py --only mainland) in game coordinates, for one far mesh of the game
(scenes/world/mainland_far.gd).

The grid has the step grid_m of data/geo/mainland.json, to radius_m from the
middle of the box of the play area. A cell has land when one of its corners is
higher than land_m, and the game draws only the cells out of the box (the
ground of the game is in the box). The heights are over the mean sea level, and
each point is lower by the curve of the earth from the middle of the box (less
the part that the air gives back: refraction): at 25 km, about 43 m.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from . import terrain

EARTH_RADIUS_M = 6_371_000.0


def curve_drop(distance_m, refraction: float) -> np.ndarray:
    """The drop of a point at the distance under the plane of the eye (m)."""
    d = np.asarray(distance_m, dtype=np.float64)
    return d * d / (2.0 * EARTH_RADIUS_M) * (1.0 - refraction)


def make(dem_path: Path, projection, box: tuple[float, float, float, float], spec: dict, mdt: float) -> dict:
    """box: x0, z0, x1, z1 of the play area in game coordinates."""
    step = float(spec["grid_m"])
    radius = float(spec["radius_m"])
    cx, cz = (box[0] + box[2]) / 2.0, (box[1] + box[3]) / 2.0
    n = int(np.ceil(radius / step))
    grid = terrain.Grid(cx - n * step, cz - n * step, step, np.zeros((2 * n + 1, 2 * n + 1), dtype=np.float32))
    terrain.load_dem(grid, dem_path, projection)
    sea = grid.heights <= terrain.DEM_SEA_VALUE
    heights = grid.heights.astype(np.float64) - mdt
    rows, cols = np.indices(heights.shape)
    xs = grid.x0 + cols * step
    zs = grid.z0 + rows * step
    heights -= curve_drop(np.hypot(xs - cx, zs - cz), float(spec["refraction"]))
    land = (grid.heights - mdt > float(spec["land_m"])) & ~sea
    # A cell (r, c) has the corners (r, c) to (r + 1, c + 1).
    any_land = land[:-1, :-1] | land[1:, :-1] | land[:-1, 1:] | land[1:, 1:]
    mid_x = grid.x0 + (np.arange(heights.shape[1] - 1) + 0.5) * step
    mid_z = grid.z0 + (np.arange(heights.shape[0] - 1) + 0.5) * step
    in_box = ((mid_z[:, None] >= box[1]) & (mid_z[:, None] <= box[3]) & (mid_x[None, :] >= box[0])
              & (mid_x[None, :] <= box[2]))
    inside = np.hypot(mid_x[None, :] - cx, mid_z[:, None] - cz) <= radius
    cells = any_land & ~in_box & inside
    # The sea corners of a land cell: a little under the sea, so that the coast meets the water.
    heights[sea] = np.minimum(heights[sea], -1.0)
    return {"step": step, "x0": round(grid.x0, 1), "z0": round(grid.z0, 1), "cols": int(heights.shape[1]),
            "rows": int(heights.shape[0]), "heights": [round(float(h), 1) for h in heights.ravel()],
            "cells": "".join("1" if c else "0" for c in cells.ravel()),
            "numbers": {"cells": int(cells.sum()), "triangles": int(cells.sum()) * 2,
                        "highest_m": round(float((grid.heights - mdt).max()), 1)}}


def write(path: Path, record: dict, spec: dict) -> None:
    data = {"note": "Made by tools/geo/build.py (report 0009, Q14) from data/geo/raw/mainland.tif (Copernicus DEM, "
                    "see data/geo/raw/manifest.json) and data/geo/mainland.json. heights: rows of cols, over the mean "
                    "sea level, less the curve of the earth from the middle of the play area; cells: one character "
                    "for each cell of (rows - 1) x (cols - 1), 1 where the game draws it.",
            **{k: v for k, v in record.items() if k != "numbers"}, "numbers": record["numbers"]}
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
