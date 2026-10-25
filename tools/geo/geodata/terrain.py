"""The ground height grid (plan 0005, D6 and D7).

The grid has one sample each grid_m meters in game coordinates. Row r is at
game Z = z0 + r * grid_m, and column c is at game X = x0 + c * grid_m. The
grid starts and stops at chunk edges.
"""

import math
from dataclasses import dataclass

import numpy as np
import rasterio
from affine import Affine
from rasterio import features
from rasterio.warp import Resampling, reproject
from scipy import ndimage

from . import pngio

# The ground slope of a beach from the water line.
BEACH_SLOPE = 1.0 / 20.0
# The DEM has no sea floor (R8g). From the coastline, the sea floor slopes
# down to SEA_FLOOR_DEPTH over SEA_FLOOR_SLOPE_M, then stays at that depth.
SEA_FLOOR_DEPTH = 4.0
SEA_FLOOR_SLOPE_M = 80.0
# Rocks in the sea (natural=rock, reef, bare_rock) rise to this height.
SEA_ROCK_HEIGHT = 0.5
# A rock that is only a node in OSM has this radius.
SEA_ROCK_NODE_RADIUS_M = 3.0
# The side slope of the Hòn Bà ridge (1 m down for each meter out).
RIDGE_SIDE_SLOPE = 1.0
# The width of the band at the land side of a beach, where the beach slope meets the ground.
BEACH_BLEND_M = 10.0
# The lowest ground height on land. The OSM coastline is the line of the
# mean high water, so the land is above most high tides (D12).
LAND_MIN_HEIGHT = 1.2
# The width at each side of a road where the flat road meets the ground.
ROAD_SHOULDER_M = 1.5
# The length of the moving average of the road height along a road.
ROAD_SMOOTH_M = 16.0
# The steepest road: 25 % (14 degrees). Steep streets in Vũng Tàu are near this value.
MAX_ROAD_GRADE = 0.25
# The most that a road goes into the ground or above it.
MAX_ROAD_CUT_M = 4.0
# Road types that follow the natural ground: the pipeline does not make them flat.
# A footway and steps are for walking, so they are flat like the other roads.
NATURAL_ROADS = {"path", "track"}
# The size of the filter that removes buildings and trees from the surface model in towns.
URBAN_FILTER_M = 60.0
# Below LOW_GROUND_TOP_M - LOW_GROUND_BLEND_M, the filter changes the ground fully. Above
# LOW_GROUND_TOP_M, it changes only the towns.
LOW_GROUND_TOP_M = 25.0
LOW_GROUND_BLEND_M = 10.0


@dataclass
class Grid:
    x0: float
    z0: float
    step: float
    heights: np.ndarray  # float32 [rows, cols]

    @property
    def shape(self):
        return self.heights.shape

    def map_transform(self) -> Affine:
        """The rasterio transform from map (x east, y north) to cells. The cell centers are the samples."""
        return Affine(self.step, 0, self.x0 - self.step / 2, 0, -self.step, -self.z0 + self.step / 2)

    def sample(self, x, z) -> np.ndarray:
        """Bilinear height at game (X, Z) points."""
        col = (np.asarray(x, dtype=np.float64) - self.x0) / self.step
        row = (np.asarray(z, dtype=np.float64) - self.z0) / self.step
        rows, cols = self.heights.shape
        c0 = np.clip(np.floor(col).astype(int), 0, cols - 2)
        r0 = np.clip(np.floor(row).astype(int), 0, rows - 2)
        fc = np.clip(col - c0, 0.0, 1.0)
        fr = np.clip(row - r0, 0.0, 1.0)
        h = self.heights
        top = h[r0, c0] * (1 - fc) + h[r0, c0 + 1] * fc
        bottom = h[r0 + 1, c0] * (1 - fc) + h[r0 + 1, c0 + 1] * fc
        return top * (1 - fr) + bottom * fr


def chunk_range(bounds, chunk: float) -> tuple[int, int, int, int]:
    """The chunk indices (cx0, cz0, cx1, cz1), with cx1 and cz1 not included, that cover the map bounds."""
    min_x, min_y, max_x, max_y = bounds
    return (math.floor(min_x / chunk), math.floor(-max_y / chunk), math.ceil(max_x / chunk), math.ceil(-min_y / chunk))


def make_grid(bounds, chunk: float, step: float) -> Grid:
    cx0, cz0, cx1, cz1 = chunk_range(bounds, chunk)
    per = int(round(chunk / step))
    rows = (cz1 - cz0) * per + 1
    cols = (cx1 - cx0) * per + 1
    return Grid(cx0 * chunk, cz0 * chunk, step, np.zeros((rows, cols), dtype=np.float32))


def load_dem(grid: Grid, dem_path, projection) -> None:
    """Resamples the DEM to the grid with bicubic interpolation (D7)."""
    with rasterio.open(dem_path) as src:
        transform = Affine(grid.step, 0, projection.origin_e + grid.x0 - grid.step / 2,
                           0, -grid.step, projection.origin_n - grid.z0 + grid.step / 2)
        reproject(source=rasterio.band(src, 1), destination=grid.heights, src_transform=src.transform,
                  src_crs=src.crs, dst_transform=transform, dst_crs=f"EPSG:{projection.epsg}",
                  resampling=Resampling.cubic, dst_nodata=0.0)
    np.nan_to_num(grid.heights, copy=False, nan=0.0)


def rasterize(grid: Grid, geometries, value: int = 1) -> np.ndarray:
    shapes = [(g, value) for g in geometries if g is not None and not g.is_empty]
    if not shapes:
        return np.zeros(grid.shape, dtype=bool)
    return features.rasterize(shapes, out_shape=grid.shape, transform=grid.map_transform(), fill=0,
                              dtype=np.uint8, all_touched=False).astype(bool)


def remove_buildings(grid: Grid, town: np.ndarray) -> float:
    """The DEM is a surface model: it has the tops of buildings and trees. An
    opening filter (a minimum, then a maximum) removes shapes that are smaller
    than URBAN_FILTER_M. A slope stays as it is. The filter changes the towns
    and the low ground, but not the hills. Returns the mean change in meters
    where the filter changes the ground fully."""
    size = int(URBAN_FILTER_M / grid.step) | 1
    opened = ndimage.maximum_filter(ndimage.minimum_filter(grid.heights, size=size), size=size)
    density = ndimage.gaussian_filter(town.astype(np.float32), sigma=20.0 / grid.step)
    low = np.clip((LOW_GROUND_TOP_M - opened) / LOW_GROUND_BLEND_M, 0.0, 1.0)
    weight = np.maximum(np.clip(density * 3.0, 0.0, 1.0), low)
    change = (grid.heights - opened) * weight
    grid.heights -= change
    full = weight > 0.99
    return float(change[full].mean()) if full.any() else 0.0


def shape_coast(grid: Grid, land: np.ndarray, beach: np.ndarray) -> None:
    """Makes the land higher than the sea, the beaches slope down to the water, and the sea floor (D7, R8g)."""
    h = grid.heights
    to_sea = ndimage.distance_transform_edt(land).astype(np.float32) * grid.step
    to_land = ndimage.distance_transform_edt(~land).astype(np.float32) * grid.step
    np.maximum(h, LAND_MIN_HEIGHT, out=h, where=land)
    # A beach: the slope from the water line, with a blend band at the land side.
    to_dry_land = ndimage.distance_transform_edt(beach | ~land).astype(np.float32) * grid.step
    weight = np.clip(to_dry_land / BEACH_BLEND_M, 0.0, 1.0)
    slope = np.minimum(h, LAND_MIN_HEIGHT + to_sea * BEACH_SLOPE)
    shaped = h * (1 - weight) + slope * weight
    h[beach & land] = shaped[beach & land]
    # The sea floor: from the coastline down to SEA_FLOOR_DEPTH, then flat.
    sea = ~land
    part = np.minimum(1.0, to_land[sea] / SEA_FLOOR_SLOPE_M)
    h[sea] = LAND_MIN_HEIGHT - (LAND_MIN_HEIGHT + SEA_FLOOR_DEPTH) * part


def raise_sea_rocks(grid: Grid, land: np.ndarray, rocks: np.ndarray) -> int:
    """Rocks in the sea rise to SEA_ROCK_HEIGHT (R8g). Returns the number of grid cells."""
    cells = rocks & ~land
    np.maximum(grid.heights, SEA_ROCK_HEIGHT, out=grid.heights, where=cells)
    return int(cells.sum())


def make_ridge(grid: Grid, land: np.ndarray, line, top: float, width: float) -> int:
    """The rock ridge to Hòn Bà (R8h): a flat top at the height top, with sides
    down to the sea floor. line is a shapely LineString in map coordinates.
    Returns the number of grid cells at the top height."""
    core = rasterize(grid, [line.buffer(width / 2.0 + grid.step / 2.0)])
    distance = ndimage.distance_transform_edt(~core).astype(np.float32) * grid.step
    ridge = top - distance * RIDGE_SIDE_SLOPE
    sea = ~land
    np.maximum(grid.heights, ridge, out=grid.heights, where=sea)
    return int((core & sea).sum())


def _window(grid: Grid, bounds, margin: float) -> tuple[slice, slice]:
    """The rows and the columns of the grid around map bounds (min_x, min_y, max_x, max_y)."""
    min_x, min_y, max_x, max_y = bounds
    rows, cols = grid.shape
    c0 = max(0, int((min_x - margin - grid.x0) / grid.step))
    c1 = min(cols, int((max_x + margin - grid.x0) / grid.step) + 2)
    r0 = max(0, int((-max_y - margin - grid.z0) / grid.step))
    r1 = min(rows, int((-min_y + margin - grid.z0) / grid.step) + 2)
    return slice(r0, r1), slice(c0, c1)


def _smooth_noise(shape, rng: np.random.Generator, sigma: float) -> np.ndarray:
    """Smooth noise from -1 to 1, with the detail size sigma in cells."""
    noise = ndimage.gaussian_filter(rng.standard_normal(shape), sigma=sigma, mode="nearest")
    scale = float(np.percentile(np.abs(noise), 97)) or 1.0
    return np.clip(noise / scale, -1.0, 1.0).astype(np.float32)


def make_rock_band(grid: Grid, land: np.ndarray, line, band, top: float, width: float, rough: float,
                   outcrop: float, pool: float, seed: int = 8) -> dict:
    """The rock path to Hòn Bà (R8h): a rough band of rocks in the sea. On
    the path (width around line), the rocks are from top - rough to top, so the
    path is dry when the sea is below top. In the rest of the band, outcrops
    rise up to top + outcrop, and tide pools go down to top + pool. Out of the
    band, the rocks slope down to the sea floor. line and band are shapely
    shapes in map coordinates. Only the sea cells change."""
    rows, cols = _window(grid, band.bounds, 12.0)
    core = rasterize(grid, [line.buffer(width / 2.0)])[rows, cols]
    inside = rasterize(grid, [band])[rows, cols]
    rng = np.random.default_rng(seed)
    big = _smooth_noise(core.shape, rng, 2.0)
    small = _smooth_noise(core.shape, rng, 0.7)
    rocks = np.where(big > 0, big * outcrop, -big * pool) + small * 0.08
    rocks = np.minimum(top + rocks, top + outcrop)
    path = top - rough * (0.5 + 0.5 * small)
    heights = np.where(core, path, np.where(inside, rocks, -np.inf)).astype(np.float32)
    distance = ndimage.distance_transform_edt(~(inside | core)).astype(np.float32) * grid.step
    side = np.where(inside | core, heights, top - 0.3 - distance * RIDGE_SIDE_SLOPE)
    h = grid.heights[rows, cols]
    sea = ~land[rows, cols]
    band_cells = (inside | core) & sea
    h[band_cells] = side[band_cells]
    outer = ~(inside | core) & sea
    h[outer] = np.maximum(h[outer], side[outer])
    grid.heights[rows, cols] = h
    return {"band_cells": int(band_cells.sum()), "path_cells": int((core & sea).sum()),
            "min_m": round(float(h[band_cells].min()), 2) if band_cells.any() else None,
            "max_m": round(float(h[band_cells].max()), 2) if band_cells.any() else None}


def make_sand_flat(grid: Grid, land: np.ndarray, center: tuple[float, float], radius: float, height: float) -> int:
    """A sand flat in the sea around a map point (R8h): flat at height to 60 %
    of the radius, then down to the sea floor at the radius. Returns the
    number of sea cells at the flat height."""
    x, y = center
    rows, cols = _window(grid, (x - radius, y - radius, x + radius, y + radius), 4.0)
    r_index, c_index = np.mgrid[rows, cols]
    gx = grid.x0 + c_index * grid.step
    gz = grid.z0 + r_index * grid.step
    d = np.hypot(gx - x, gz + y)
    part = np.clip((d - radius * 0.6) / (radius * 0.4), 0.0, 1.0)
    flat = height - part * (height + SEA_FLOOR_DEPTH)
    h = grid.heights[rows, cols]
    sea = ~land[rows, cols]
    np.maximum(h, flat, out=h, where=sea)
    grid.heights[rows, cols] = h
    return int((sea & (part == 0)).sum())


def smooth_profile(heights: np.ndarray, spacing: float, length: float) -> np.ndarray:
    n = max(1, int(round(length / max(spacing, 0.1))))
    if n <= 1 or len(heights) < 3:
        return heights
    padded = np.pad(heights, (n // 2, n - 1 - n // 2), mode="edge")
    return np.convolve(padded, np.ones(n) / n, mode="valid")


def limit_grade(profile: np.ndarray, spacing: np.ndarray, grade: float, max_change: float = MAX_ROAD_CUT_M,
                fixed: np.ndarray | None = None) -> np.ndarray:
    """Makes the steep parts of a road less steep: a short steep part (for
    example trees in the surface model) becomes a ramp of "grade". The road
    goes not more than "max_change" above or below the first profile, so a road
    that is steep for a long distance stays steep."""
    original = profile.astype(np.float64)
    h = original.copy()
    limit = spacing * grade
    for _ in range(200):
        diff = np.diff(h)
        excess = np.abs(diff) - limit
        if excess.max(initial=0.0) <= 0.005:
            break
        change = np.where(excess > 0, np.sign(diff) * excess / 2.0, 0.0)
        h[:-1] += change
        h[1:] -= change
        np.clip(h, original - max_change, original + max_change, out=h)
        if fixed is not None:
            h[fixed] = original[fixed]
    return h


def _profile(grid: Grid, road, step: float, locked: np.ndarray | None = None):
    """The height profile of a road. A point on a surface that is set already
    (a junction with a more important road) keeps the height of that surface."""
    x = road.points[:, 0]
    z = -road.points[:, 1]
    raw = grid.sample(x, z)
    profile = smooth_profile(raw, step, ROAD_SMOOTH_M if not road.hem else ROAD_SMOOTH_M / 2)
    fixed = None
    if locked is not None:
        cols = np.clip(np.round((x - grid.x0) / grid.step).astype(int), 0, grid.shape[1] - 1)
        rows = np.clip(np.round((z - grid.z0) / grid.step).astype(int), 0, grid.shape[0] - 1)
        fixed = locked[rows, cols]
        profile = np.where(fixed, raw, profile)
    spacing = np.hypot(np.diff(x), np.diff(z))
    profile = limit_grade(np.maximum(profile, LAND_MIN_HEIGHT + 0.05), spacing, MAX_ROAD_GRADE, fixed=fixed)
    return profile, x, z


def flatten_roads(grid: Grid, roads, step: float) -> None:
    """Makes the ground flat across each road (D7).

    1. The shoulders of all roads blend into the ground.
    2. The road surfaces are set, the most important road first, and a set cell
       does not change again. Each road takes its height profile from this
       ground, so a side road starts at the height of the main road.
    3. All road surfaces are set again with these profiles, without locks, the
       least important first. So each road surface is continuous, and a more
       important road wins only where the two surfaces really cover the same cells."""
    flat = [r for r in sorted(roads, key=lambda r: r.importance)
            if r.type not in NATURAL_ROADS and not r.bridge and not r.tunnel]
    for road in reversed(flat):
        profile, x, z = _profile(grid, road, step)
        _flatten(grid, road, profile, x, z, "shoulder")
    locked = np.zeros(grid.shape, dtype=bool)
    profiles = []
    for road in flat:
        profile, x, z = _profile(grid, road, step, locked)
        _flatten(grid, road, profile, x, z, "surface", locked)
        profiles.append((road, profile, x, z))
    mix = (np.zeros(grid.shape, dtype=np.float32), np.zeros(grid.shape, dtype=np.float32))
    for road, profile, x, z in reversed(profiles):
        _flatten(grid, road, profile, x, z, "mix", mix=mix)


def _flatten(grid: Grid, road, profile, x, z, mode: str, locked: np.ndarray | None = None, mix=None) -> None:
    """"shoulder" blends the shoulders. "surface" sets the surface cells; with
    "locked", only the cells that are not locked, and then it locks them.
    "mix" sets the surface cells to a mean of the parts of the road that cover
    them, with more weight for a nearer part: the two legs of a hairpin then join
    with a slope, not with a step. "mix" needs two empty arrays for the sums."""
    h = grid.heights
    rows, cols = h.shape
    half = road.width / 2.0
    reach = half + ROAD_SHOULDER_M
    new_lock = []
    touched = []
    for i in range(len(x) - 1):
        ax, az, bx, bz = x[i], z[i], x[i + 1], z[i + 1]
        c0 = max(0, int((min(ax, bx) - reach - grid.x0) / grid.step))
        c1 = min(cols - 1, int((max(ax, bx) + reach - grid.x0) / grid.step) + 1)
        r0 = max(0, int((min(az, bz) - reach - grid.z0) / grid.step))
        r1 = min(rows - 1, int((max(az, bz) + reach - grid.z0) / grid.step) + 1)
        if c1 < c0 or r1 < r0:
            continue
        px = grid.x0 + np.arange(c0, c1 + 1) * grid.step
        pz = grid.z0 + np.arange(r0, r1 + 1) * grid.step
        gx, gz = np.meshgrid(px, pz)
        dx, dz = bx - ax, bz - az
        length2 = dx * dx + dz * dz
        if length2 <= 0.0:
            continue
        raw_t = ((gx - ax) * dx + (gz - az) * dz) / length2
        t = np.clip(raw_t, 0.0, 1.0)
        d = np.hypot(gx - (ax + t * dx), gz - (az + t * dz))
        target = profile[i] + t * (profile[i + 1] - profile[i])
        block = h[r0:r1 + 1, c0:c1 + 1]
        # A segment changes only the cells that are beside it. Else the round end of
        # each segment puts the height of one point on the slope of the next segment.
        # The first and the last segment also change the cells at the ends of the road.
        beside = (raw_t >= (-np.inf if i == 0 else -0.02)) & (raw_t <= (np.inf if i == len(x) - 2 else 1.02))
        if mode == "mix":
            core = (d <= half + grid.step / 2.0) & beside
            weight = 1.0 / (d + 0.5) ** 2
            mix[0][r0:r1 + 1, c0:c1 + 1][core] += (target * weight)[core]
            mix[1][r0:r1 + 1, c0:c1 + 1][core] += weight[core]
            touched.append((r0, r1, c0, c1))
        elif mode == "surface":
            # The road surface and a band of half a grid step, so that the edge sample is flat too.
            core = (d <= half + grid.step / 2.0) & beside
            if locked is not None:
                core &= ~locked[r0:r1 + 1, c0:c1 + 1]
                new_lock.append((r0, r1, c0, c1, core))
            block[core] = target[core]
        else:
            weight = np.clip((reach - d) / ROAD_SHOULDER_M, 0.0, 1.0)
            shoulder = (d > half) & (weight > 0.0) & beside
            block[shoulder] = block[shoulder] * (1 - weight[shoulder]) + target[shoulder] * weight[shoulder]
    if mode == "mix":
        for r0, r1, c0, c1 in touched:
            total, weights = mix[0][r0:r1 + 1, c0:c1 + 1], mix[1][r0:r1 + 1, c0:c1 + 1]
            covered = weights > 0.0
            h[r0:r1 + 1, c0:c1 + 1][covered] = total[covered] / weights[covered]
        for r0, r1, c0, c1 in touched:
            mix[0][r0:r1 + 1, c0:c1 + 1] = 0.0
            mix[1][r0:r1 + 1, c0:c1 + 1] = 0.0
    # The cells lock after the whole road, so that the parts of one road join.
    if locked is not None:
        for r0, r1, c0, c1, core in new_lock:
            locked[r0:r1 + 1, c0:c1 + 1] |= core


def encode(heights: np.ndarray, offset: float, step: float) -> np.ndarray:
    return np.clip(np.round((heights - offset) / step), 0, 65535).astype(np.uint16)


def write_chunks(grid: Grid, land: np.ndarray, chunk: float, margin: float, offset: float, step: float, folder) -> list[dict]:
    """Writes one 16-bit PNG for each chunk that has land or is near land. Returns the chunk list."""
    folder.mkdir(parents=True, exist_ok=True)
    per = int(round(chunk / grid.step))
    to_land = ndimage.distance_transform_edt(~land).astype(np.float32) * grid.step
    rows, cols = grid.shape
    cx0 = int(round(grid.x0 / chunk))
    cz0 = int(round(grid.z0 / chunk))
    result = []
    for r in range(0, rows - 1, per):
        for c in range(0, cols - 1, per):
            near = to_land[r:r + per + 1, c:c + per + 1]
            if near.min() > margin:
                continue
            block = grid.heights[r:r + per + 1, c:c + per + 1]
            cx, cz = cx0 + c // per, cz0 + r // per
            pngio.write_gray16(folder / f"{cx}_{cz}.png", encode(block, offset, step))
            result.append({"x": cx, "z": cz, "min": round(float(block.min()), 2), "max": round(float(block.max()), 2),
                           "land": bool(land[r:r + per + 1, c:c + per + 1].any())})
    return result


def write_overview(grid: Grid, every: int, offset: float, step: float, path) -> dict:
    """Writes the whole grid with one sample each "every" samples, for the far ground."""
    small = grid.heights[::every, ::every]
    pngio.write_gray16(path, encode(small, offset, step))
    return {"x0": grid.x0, "z0": grid.z0, "step": grid.step * every, "columns": small.shape[1], "rows": small.shape[0]}
