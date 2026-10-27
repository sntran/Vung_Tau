"""The land cover and the trees from public data (report 0005, D-0005-09,
correction 0; plan 0020, D8 and R10a): ESA WorldCover 2021 (the class of each
10 m pixel) and the Meta and WRI canopy height maps (the height of the trees).

WorldCover has almost no shrubland in Vũng Tàu: the bushes of the hills are in
"tree cover" and "grassland". So the bushes come from the canopy height too:
a canopy from BUSH_MIN_M to TREE_MIN_M is a bush, and a canopy of TREE_MIN_M or
more is a tree."""

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
# The tree tops for the report: a canopy of TREE_MIN_M or more that is the highest within TOP_RADIUS_M.
TOP_RADIUS_M = 4.0


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


def tree_tops(canopy: np.ndarray, step: float, allowed: np.ndarray, radius_m: float = TOP_RADIUS_M):
    """The rows and the columns of the tree tops: a canopy of TREE_MIN_M or more
    that is the highest within radius_m (the first cell of a flat top)."""
    size = max(3, int(round(2 * radius_m / step)) | 1)
    values = np.where(np.isfinite(canopy), canopy, 0.0)
    highest = ndimage.maximum_filter(values, size=size, mode="constant")
    top = (values >= TREE_MIN_M) & (values >= highest) & allowed
    # A flat top has many cells with the same height: keep one of each group.
    labels, count = ndimage.label(top)
    if count == 0:
        return np.zeros(0, dtype=int), np.zeros(0, dtype=int)
    centers = ndimage.center_of_mass(top, labels, range(1, count + 1))
    rows = np.array([int(round(c[0])) for c in centers])
    cols = np.array([int(round(c[1])) for c in centers])
    return rows, cols


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
