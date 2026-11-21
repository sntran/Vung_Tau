"""The bare earth under the trees and the roofs (plan 0009, R5b, D9).

Copernicus GLO-30 is a model of the surface: it has the tops of the trees and
the roofs. GEDTM30 and DeltaDTM are models of the ground under them. The
lidar ground of ICESat-2 (the bins of data/geo/build/lidar_tracks.json)
checks the three models:

1. compare() gives, for each model, the mean difference and the RMSE against
   the lidar ground, by land cover and on each hill.
2. choose() takes, for each group (a hill or the low land, and a class of
   the land cover), the model with the smallest RMSE. A group with fewer
   than min_points lidar points keeps Copernicus.
3. apply() uses that model where it differs from Copernicus by more than
   min_difference_m on average (a mean over difference_mean_m), with a smooth
   change to Copernicus over blend_m at the edge. Elsewhere Copernicus stays.
4. The cells of keep (the sea of the coastline: below the line of the high
   water, the heights of plan 0005, R8g) do not change.

All the heights here are over the mean sea level: the heights over EGM2008
take away the mean dynamic topography (msl()).
"""

from __future__ import annotations

import numpy as np
from scipy import ndimage

COPERNICUS = "copernicus"
CLASSES = ("tree", "bush", "town", "open")
CLASS_NAMES = {"tree": "tree cover", "bush": "bushes", "town": "town", "open": "bare ground and grass"}
LOW_LAND = "low_land"


def msl(heights, mdt: float):
    """Heights over EGM2008 to heights over the mean sea level."""
    return heights - mdt


def class_map(land: np.ndarray, tree: np.ndarray, bush: np.ndarray, town: np.ndarray) -> np.ndarray:
    """The class of each cell (an index of CLASSES, -1 for the sea): the town
    first, then the tree cover, the bushes, and the open land."""
    out = np.full(land.shape, -1, dtype=np.int8)
    out[land] = CLASSES.index("open")
    out[land & bush] = CLASSES.index("bush")
    out[land & tree] = CLASSES.index("tree")
    out[land & town] = CLASSES.index("town")
    return out


def zone_map(shape, step: float, x0: float, z0: float, heights: np.ndarray, hills: dict) -> tuple[np.ndarray, list]:
    """The zone of each cell: a hill (in its radius of its point, and at least
    its lowest height) or the low land. Returns the map and the names in order."""
    names = [LOW_LAND] + list(hills)
    out = np.zeros(shape, dtype=np.int8)
    rows, cols = np.indices(shape)
    for i, (_hill_id, hill) in enumerate(hills.items(), start=1):
        cx = (hill["position"][0] - x0) / step
        cz = (hill["position"][1] - z0) / step
        r = hill["radius_m"] / step
        out[((cols - cx) ** 2 + (rows - cz) ** 2 <= r * r) & (heights >= hill["lowest_m"])] = i
    return out, names


def _cells(x, z, x0: float, z0: float, step: float, shape) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    col = np.rint((np.asarray(x) - x0) / step).astype(int)
    row = np.rint((np.asarray(z) - z0) / step).astype(int)
    inside = (row >= 0) & (row < shape[0]) & (col >= 0) & (col < shape[1])
    return np.clip(row, 0, shape[0] - 1), np.clip(col, 0, shape[1] - 1), inside


def bilinear(values: np.ndarray, x, z, x0: float, z0: float, step: float) -> np.ndarray:
    """Bilinear sample of a grid at game points (NaN where a corner is NaN)."""
    col = (np.asarray(x, dtype=np.float64) - x0) / step
    row = (np.asarray(z, dtype=np.float64) - z0) / step
    rows, cols = values.shape
    c0 = np.clip(np.floor(col).astype(int), 0, cols - 2)
    r0 = np.clip(np.floor(row).astype(int), 0, rows - 2)
    fc = np.clip(col - c0, 0.0, 1.0)
    fr = np.clip(row - r0, 0.0, 1.0)
    top = values[r0, c0] * (1 - fc) + values[r0, c0 + 1] * fc
    bottom = values[r0 + 1, c0] * (1 - fc) + values[r0 + 1, c0 + 1] * fc
    return top * (1 - fr) + bottom * fr


def compare(models: dict, points: np.ndarray, classes: np.ndarray, zones: np.ndarray, zone_names: list,
            x0: float, z0: float, step: float) -> dict:
    """For each model, each class, each zone, and each group (zone, class):
    the count of lidar points, the mean difference (the model minus the lidar),
    and the RMSE. points: rows of (x, z, ground height over the mean sea level)."""
    x, z, ground = points[:, 0], points[:, 1], points[:, 2]
    row, col, inside = _cells(x, z, x0, z0, step, classes.shape)
    klass = np.where(inside, classes[row, col], -1)
    zone = np.where(inside, zones[row, col], -1)
    out = {"by_model": {}, "points": int(np.count_nonzero(klass >= 0))}
    for name, values in models.items():
        h = bilinear(values, x, z, x0, z0, step)
        diff = h - ground
        good = np.isfinite(diff) & (klass >= 0)

        def stats(sel: np.ndarray) -> dict:
            d = diff[sel & good]
            if d.size == 0:
                return {"n": 0, "mean": None, "rmse": None}
            return {"n": int(d.size), "mean": round(float(d.mean()), 2), "rmse": round(float(np.sqrt((d * d).mean())), 2)}

        by = {"all": stats(np.ones_like(good)), "class": {}, "zone": {}, "group": {}}
        for ci, cname in enumerate(CLASSES):
            by["class"][cname] = stats(klass == ci)
        for zi, zname in enumerate(zone_names):
            by["zone"][zname] = stats(zone == zi)
            for ci, cname in enumerate(CLASSES):
                by["group"][f"{zname}/{cname}"] = stats((zone == zi) & (klass == ci))
        out["by_model"][name] = by
    return out


def choose(result: dict, min_points: int) -> dict:
    """For each group, the model with the smallest RMSE; Copernicus when the
    group has fewer than min_points lidar points with Copernicus."""
    choice = {}
    groups = result["by_model"][COPERNICUS]["group"]
    for group, cop in groups.items():
        if cop["n"] < min_points:
            choice[group] = {"model": COPERNICUS, "why": f"{cop['n']} lidar points (fewer than {min_points})"}
            continue
        best, best_rmse = COPERNICUS, cop["rmse"]
        for name, by in result["by_model"].items():
            g = by["group"][group]
            if g["n"] >= min_points and g["rmse"] is not None and g["rmse"] < best_rmse:
                best, best_rmse = name, g["rmse"]
        choice[group] = {"model": best, "why": f"the smallest RMSE ({best_rmse:.2f} m)"}
    return choice


def coast_keep(land: np.ndarray, step: float, band: float) -> np.ndarray:
    """The cells that keep Copernicus: the sea of the coastline (below the line
    of the high water, plan 0005, R8g) and the land within band of it (a cell of
    30 m of a model there has the sea in it)."""
    to_sea = ndimage.distance_transform_edt(land) * step
    return ~land | (to_sea < band)


def _fill_nan(values: np.ndarray) -> np.ndarray:
    """NaN cells take the value of the nearest cell with a value."""
    bad = ~np.isfinite(values)
    if not bad.any():
        return values
    if bad.all():
        return np.zeros_like(values)
    _d, (rows, cols) = ndimage.distance_transform_edt(bad, return_indices=True)
    return values[rows, cols]


def _ramp(distance: np.ndarray, length: float) -> np.ndarray:
    t = np.clip(1.0 - distance / length, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def apply(heights: np.ndarray, models: dict, classes: np.ndarray, zones: np.ndarray, zone_names: list,
          choice: dict, keep: np.ndarray, step: float, min_difference: float, difference_mean: float,
          blend: float) -> dict:
    """Changes heights (Copernicus) in place to the bare earth. Returns the
    numbers for the report and the weight of each model (0 to 1)."""
    group_index = {}
    for zi, zname in enumerate(zone_names):
        for ci, cname in enumerate(CLASSES):
            group_index[(zi, ci)] = f"{zname}/{cname}"
    total = np.zeros(heights.shape, dtype=np.float64)
    weights = np.zeros(heights.shape, dtype=np.float64)
    numbers = {"models": {}}
    sigma = difference_mean / step / 2.0
    for name, values in models.items():
        if name == COPERNICUS:
            continue
        chosen = np.zeros(heights.shape, dtype=bool)
        for (zi, ci), group in group_index.items():
            if choice.get(group, {}).get("model") == name:
                chosen |= (zones == zi) & (classes == ci)
        if not chosen.any():
            continue
        valid = np.isfinite(values)
        diff = _fill_nan(np.where(valid, values - heights, np.nan)).astype(np.float64)
        # The mean difference over difference_mean: a model that differs from
        # Copernicus by its noise only does not change the ground.
        mean = ndimage.gaussian_filter(np.where(chosen & valid, diff, 0.0), sigma)
        count = ndimage.gaussian_filter((chosen & valid).astype(np.float64), sigma)
        mean = np.divide(mean, count, out=np.zeros_like(mean), where=count > 1e-6)
        used = chosen & valid & (np.abs(mean) > min_difference) & ~keep
        if not used.any():
            numbers["models"][name] = {"cells": 0}
            continue
        distance = ndimage.distance_transform_edt(~used).astype(np.float64) * step
        weight = _ramp(distance, blend)
        weight[keep] = 0.0
        total += weight * diff
        weights += weight
        numbers["models"][name] = {"cells": int(used.sum()), "area_ha": round(float(used.sum()) * step * step / 1e4, 1),
                                   "mean_change_m": round(float(diff[used].mean()), 2)}
    change = np.divide(total, np.maximum(weights, 1.0))
    change[keep] = 0.0
    heights += change.astype(heights.dtype)
    changed = np.abs(change) > 0.05
    numbers["changed_ha"] = round(float(changed.sum()) * step * step / 1e4, 1)
    numbers["mean_change_m"] = round(float(change[changed].mean()), 2) if changed.any() else 0.0
    numbers["largest_lowering_m"] = round(float(-change.min()), 2) if change.size else 0.0
    numbers["largest_raising_m"] = round(float(change.max()), 2) if change.size else 0.0
    return {"numbers": numbers, "change": change.astype(np.float32)}


def cell_steps(heights: np.ndarray, area: np.ndarray) -> float:
    """The largest change from a cell to its neighbor in area (for the test of the edge)."""
    dx = np.abs(np.diff(heights, axis=1))[area[:, 1:] & area[:, :-1]]
    dz = np.abs(np.diff(heights, axis=0))[area[1:, :] & area[:-1, :]]
    return float(max(dx.max() if dx.size else 0.0, dz.max() if dz.size else 0.0))
