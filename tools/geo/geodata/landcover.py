"""The land cover and the trees from public data (report 0005, D-0005-09,
correction 0; plan 0020, D8 and R10a): ESA WorldCover 2021 (the class of each
10 m pixel) and the Meta and WRI canopy height maps (the height of the trees).

WorldCover has almost no shrubland in Vũng Tàu: the bushes of the hills are in
"tree cover" and "grassland". So the bushes come from the canopy height too:
a canopy from BUSH_MIN_M to TREE_MIN_M is a bush, and a canopy of TREE_MIN_M or
more is a tree."""

import json

import numpy as np
from PIL import Image
from scipy import ndimage

TREE, SHRUB, GRASS, CROP, BUILT, BARE, WATER, WETLAND, MANGROVE = 10, 20, 30, 40, 50, 60, 80, 90, 95
NAMES = {TREE: "tree cover", SHRUB: "shrubland", GRASS: "grassland", CROP: "cropland", BUILT: "built-up",
         BARE: "bare or sparse", WATER: "water", WETLAND: "herbaceous wetland", MANGROVE: "mangroves"}
# The colors of the cover map of the report (the WorldCover legend).
COLORS = {TREE: (0, 100, 0), SHRUB: (255, 187, 34), GRASS: (255, 255, 76), CROP: (240, 150, 255),
          BUILT: (250, 0, 0), BARE: (180, 180, 180), WATER: (0, 100, 200), WETLAND: (0, 150, 160),
          MANGROVE: (0, 207, 117)}
TREE_MIN_M = 3.0
BUSH_MIN_M = 0.6
# canopy.png: the height in steps of CANOPY_SCALE m.
CANOPY_SCALE = 0.2
# A street tree is checked when the canopy map has nothing of STREET_MIN_M or
# more within STREET_RADIUS_M of it (plan 0020, R10a: a gap of 5 m or more).
STREET_RADIUS_M = 5.0
STREET_MIN_M = 2.0
# The trees of the game on the canopy map: the highest canopy first, then the
# lower canopy, with a tree on each cell that is not nearer to a placed tree
# than the spacing of that tree: SPACING_PER_M of its height, from
# SPACING_MIN_M to SPACING_MAX_M. The map has about one height top for each
# 300 m² of the forest, a group of crowns, so the spacing fills each patch.
SPACING_PER_M = 0.9
SPACING_MIN_M = 5.0
SPACING_MAX_M = 12.0
# The crown of a tree: the canopy of TREE_MIN_M or more that is nearer to it
# than to another tree, not farther than CROWN_MAX_M. The canopy grid keeps
# the highest value of each cell, so the crowns are about CROWN_EDGE_M too wide.
CROWN_MAX_M = 10.0
CROWN_EDGE_M = 0.5
# The crowns are found in tiles of this many cells (less memory).
CROWN_TILE = 1024


def cover_masks(classes: np.ndarray, canopy: np.ndarray, land: np.ndarray) -> dict:
    """Boolean masks on the grid: "tree", "bush", "grass", and "bare". The
    built-up and the cropland classes have none of them (the town and the
    street trees have their own rules)."""
    open_land = land & ~np.isin(classes, (BUILT, CROP, WATER))
    # The canopy height decides: the classes of 10 m mix trees, bushes, and grass.
    tree = open_land & ((canopy >= TREE_MIN_M) | (classes == MANGROVE))
    bush = open_land & ~tree & ((classes == SHRUB) | (canopy >= BUSH_MIN_M))
    grass = open_land & ~tree & ~bush & np.isin(classes, (GRASS, TREE, WETLAND))
    bare = open_land & ~tree & ~bush & (classes == BARE)
    return {"tree": tree, "bush": bush, "grass": grass, "bare": bare}


def write_cover(masks: dict, every: int, path) -> None:
    """An RGBA image on the grid of surface.png (one pixel for each `every`
    cells): R the part of tree cover, G of bushes, B of grass, A of bare ground."""
    def channel(mask):
        smooth = ndimage.gaussian_filter(mask.astype(np.float32), sigma=every / 2.0)
        return np.clip(np.round(smooth[::every, ::every] * 255), 0, 255).astype(np.uint8)
    image = np.dstack([channel(masks["tree"]), channel(masks["bush"]), channel(masks["grass"]), channel(masks["bare"])])
    Image.fromarray(image, "RGBA").save(path)


def write_canopy(grid, canopy: np.ndarray, land: np.ndarray, path, pool: int = 2) -> dict:
    """A gray image of the canopy height on land, with the highest value of each
    `pool` x `pool` cells, in steps of CANOPY_SCALE m. The game finds the tree
    tops and the bushes in it. Returns its place: the center of the first
    pixel, the step, and the size."""
    values = np.where(land & np.isfinite(canopy), canopy, 0.0)
    rows = values.shape[0] // pool * pool
    cols = values.shape[1] // pool * pool
    pooled = values[:rows, :cols].reshape(rows // pool, pool, cols // pool, pool).max(axis=(1, 3))
    image = np.clip(np.round(pooled / CANOPY_SCALE), 0, 255).astype(np.uint8)
    Image.fromarray(image, "L").save(path)
    half = (pool - 1) / 2.0 * grid.step
    return {"file": path.name, "x0": round(grid.x0 + half, 2), "z0": round(grid.z0 + half, 2), "step": grid.step * pool,
            "columns": image.shape[1], "rows": image.shape[0], "scale_m": CANOPY_SCALE,
            "tree_min_m": TREE_MIN_M, "bush_min_m": BUSH_MIN_M}


def spacing(height: float) -> float:
    return min(max(height * SPACING_PER_M, SPACING_MIN_M), SPACING_MAX_M)


def tree_places(canopy: np.ndarray, step: float, allowed: np.ndarray, seed: int = 1):
    """The rows and the columns of the trees: on the cells with a canopy of
    TREE_MIN_M or more, the highest first (in a random order for the same
    height), each one at the spacing of the higher trees or farther."""
    values = np.where(np.isfinite(canopy), canopy, 0.0)
    rows, cols = np.nonzero((values >= TREE_MIN_M) & allowed)
    heights = values[rows, cols]
    rng = np.random.default_rng(seed)
    order = np.lexsort((rng.random(rows.size), -heights))
    blocked = np.zeros(values.shape, dtype=bool)
    disks = {}
    kept = []
    rows_l, cols_l, heights_l = rows.tolist(), cols.tolist(), heights.tolist()
    for i in order.tolist():
        row, col = rows_l[i], cols_l[i]
        if blocked[row, col]:
            continue
        kept.append(i)
        reach = spacing(heights_l[i]) / step
        k = int(np.ceil(reach)) - 1
        if k not in disks:
            yy, xx = np.mgrid[-k:k + 1, -k:k + 1]
            disks[k] = yy * yy + xx * xx < reach * reach
        disk = disks[k]
        r0, r1 = max(row - k, 0), min(row + k + 1, values.shape[0])
        c0, c1 = max(col - k, 0), min(col + k + 1, values.shape[1])
        blocked[r0:r1, c0:c1] |= disk[r0 - row + k:r1 - row + k, c0 - col + k:c1 - col + k]
    kept = np.array(sorted(kept), dtype=int)
    return (rows[kept], cols[kept]) if kept.size else (np.zeros(0, dtype=int), np.zeros(0, dtype=int))


def crown_radii(canopy: np.ndarray, step: float, rows: np.ndarray, cols: np.ndarray) -> np.ndarray:
    """The crown radius (m) of each tree: the radius of a circle with the
    area of its crown."""
    values = np.where(np.isfinite(canopy), canopy, 0.0)
    markers = np.zeros(values.shape, dtype=np.int32)
    markers[rows, cols] = np.arange(1, rows.size + 1, dtype=np.int32)
    reach = int(np.ceil(CROWN_MAX_M / step))
    area = np.zeros(rows.size + 1, dtype=np.int64)
    for r0 in range(0, values.shape[0], CROWN_TILE):
        for c0 in range(0, values.shape[1], CROWN_TILE):
            r1, c1 = min(r0 + CROWN_TILE, values.shape[0]), min(c0 + CROWN_TILE, values.shape[1])
            er0, ec0 = max(r0 - reach, 0), max(c0 - reach, 0)
            er1, ec1 = min(r1 + reach, values.shape[0]), min(c1 + reach, values.shape[1])
            window = markers[er0:er1, ec0:ec1]
            if not window.any():
                continue
            distance, (ir, ic) = ndimage.distance_transform_edt(window == 0, return_indices=True)
            nearest = window[ir, ic]
            core = (slice(r0 - er0, r1 - er0), slice(c0 - ec0, c1 - ec0))
            inside = (values[r0:r1, c0:c1] >= TREE_MIN_M) & (distance[core] * step <= CROWN_MAX_M)
            area += np.bincount(nearest[core][inside], minlength=rows.size + 1)
    radius = np.sqrt(area[1:] * step * step / np.pi) - CROWN_EDGE_M
    return np.maximum(radius, step / 2.0)


def write_trees(path, grid, canopy: np.ndarray, rows: np.ndarray, cols: np.ndarray) -> dict:
    """canopy_trees.json: each tree of the open land as x, z (game meters), the
    height, and the crown radius (m), in one flat list. The game puts a hill
    tree on each one (plan 0020, R10a)."""
    values = np.where(np.isfinite(canopy), canopy, 0.0)
    radii = crown_radii(canopy, grid.step, rows, cols)
    flat = []
    for row, col, radius in zip(rows, cols, radii):
        flat += [round(float(grid.x0 + col * grid.step), 1), round(float(grid.z0 + row * grid.step), 1),
                 round(float(values[row, col]), 1), round(float(radius), 1)]
    record = {"note": "Made by tools/geo/build.py from the canopy height maps (plan 0020, R10a): x, z, height (m), "
                      "crown radius (m) of each tree.", "count": int(rows.size), "trees": flat}
    path.write_text(json.dumps(record, separators=(",", ":")), encoding="utf-8")
    return {"count": int(rows.size), "mean_height_m": round(float(values[rows, cols].mean()), 1) if rows.size else 0.0,
            "mean_radius_m": round(float(radii.mean()), 1) if rows.size else 0.0}


def shares(masks: dict, classes: np.ndarray, area: np.ndarray) -> dict:
    """The part of the area of each mask and of each WorldCover class."""
    total = max(int(area.sum()), 1)
    result = {name: round(float((mask & area).sum()) / total, 3) for name, mask in masks.items()}
    result["classes"] = {NAMES[c]: round(float(((classes == c) & area).sum()) / total, 3)
                         for c in NAMES if ((classes == c) & area).any()}
    return result


def street_trees_without_canopy(points: list, grid, canopy: np.ndarray) -> list:
    """The street and park trees (game [x, height, z]) with no canopy of
    STREET_MIN_M or more within STREET_RADIUS_M: the map shows no tree there."""
    reach = int(np.ceil(STREET_RADIUS_M / grid.step))
    offsets = [(dr, dc) for dr in range(-reach, reach + 1) for dc in range(-reach, reach + 1)
               if (dr * dr + dc * dc) * grid.step ** 2 <= STREET_RADIUS_M ** 2]
    values = np.where(np.isfinite(canopy), canopy, 0.0)
    rows_n, cols_n = values.shape
    result = []
    for p in points:
        col = int(round((p[0] - grid.x0) / grid.step))
        row = int(round((p[2] - grid.z0) / grid.step))
        if not (0 <= row < rows_n and 0 <= col < cols_n):
            continue
        best = 0.0
        for dr, dc in offsets:
            r, c = row + dr, col + dc
            if 0 <= r < rows_n and 0 <= c < cols_n:
                best = max(best, float(values[r, c]))
        if best < STREET_MIN_M:
            result.append(p)
    return result


def draw_cover_map(path, classes: np.ndarray, every: int) -> None:
    small = classes[::every, ::every]
    image = np.zeros(small.shape + (3,), dtype=np.uint8)
    for value, color in COLORS.items():
        image[small == value] = color
    Image.fromarray(image).save(path)


def draw_canopy_map(path, canopy: np.ndarray, land: np.ndarray, every: int) -> None:
    """Dark gray for land with no canopy, then green from light (1 m) to dark (25 m and more); the sea is blue."""
    small = np.where(np.isfinite(canopy), canopy, 0.0)[::every, ::every]
    on_land = land[::every, ::every]
    t = np.clip(small / 25.0, 0.0, 1.0)[..., None]
    green = (np.array([200, 230, 140]) * (1 - t) + np.array([0, 70, 20]) * t)
    image = np.where((small >= 1.0)[..., None], green, np.array([90, 90, 90]))
    image = np.where(on_land[..., None], image, np.array([40, 80, 140]))
    Image.fromarray(image.astype(np.uint8)).save(path)
