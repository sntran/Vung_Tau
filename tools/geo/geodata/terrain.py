"""The ground height grid (plan 0003, D6 and D7).

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

# The ground slope of a beach from the water line, and of the sea floor.
BEACH_SLOPE = 1.0 / 20.0
SEA_SLOPE_BEACH = 1.0 / 25.0
SEA_SLOPE_ROCK = 1.0 / 6.0
SEA_MAX_DEPTH = 15.0
# The width of the band at the land side of a beach, where the beach slope meets the ground.
BEACH_BLEND_M = 10.0
# The lowest ground height on land, so that the sea does not cover the land.
LAND_MIN_HEIGHT = 0.25
# The width at each side of a road where the flat road meets the ground.
ROAD_SHOULDER_M = 1.5
# The length of the moving average of the road height along a road.
ROAD_SMOOTH_M = 16.0
# Road types that follow the natural ground: the pipeline does not make them flat.
NATURAL_ROADS = {"path", "footway", "steps", "track"}
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
    """Makes the land higher than the sea, the beaches slope down to the water, and the sea floor (D7)."""
    h = grid.heights
    to_sea = ndimage.distance_transform_edt(land).astype(np.float32) * grid.step
    to_land = ndimage.distance_transform_edt(~land).astype(np.float32) * grid.step
    to_beach = ndimage.distance_transform_edt(~beach).astype(np.float32) * grid.step
    np.maximum(h, LAND_MIN_HEIGHT, out=h, where=land)
    # A beach: the slope from the water line, with a blend band at the land side.
    to_dry_land = ndimage.distance_transform_edt(beach | ~land).astype(np.float32) * grid.step
    weight = np.clip(to_dry_land / BEACH_BLEND_M, 0.0, 1.0)
    slope = np.minimum(h, LAND_MIN_HEIGHT + to_sea * BEACH_SLOPE)
    shaped = h * (1 - weight) + slope * weight
    h[beach & land] = shaped[beach & land]
    # The sea floor: a gentle slope near a beach, a steep slope near rocks.
    near_beach = np.clip(1.0 - to_beach / 150.0, 0.0, 1.0)
    sea_slope = SEA_SLOPE_ROCK * (1 - near_beach) + SEA_SLOPE_BEACH * near_beach
    sea = ~land
    h[sea] = -np.minimum(SEA_MAX_DEPTH, to_land[sea] * sea_slope[sea])


def smooth_profile(heights: np.ndarray, spacing: float, length: float) -> np.ndarray:
    n = max(1, int(round(length / max(spacing, 0.1))))
    if n <= 1 or len(heights) < 3:
        return heights
    padded = np.pad(heights, (n // 2, n - 1 - n // 2), mode="edge")
    return np.convolve(padded, np.ones(n) / n, mode="valid")


def flatten_roads(grid: Grid, roads, step: float) -> None:
    """Makes the ground flat across each road (D7). A more important road is
    the last to change the ground, so it sets the height at a junction."""
    h = grid.heights
    rows, cols = h.shape
    for road in sorted(roads, key=lambda r: -r.importance):
        if road.type in NATURAL_ROADS or road.bridge or road.tunnel:
            continue
        x = road.points[:, 0]
        z = -road.points[:, 1]
        profile = smooth_profile(grid.sample(x, z), step, ROAD_SMOOTH_M if not road.hem else ROAD_SMOOTH_M / 2)
        profile = np.maximum(profile, LAND_MIN_HEIGHT + 0.05)
        half = road.width / 2.0
        reach = half + ROAD_SHOULDER_M
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
            t = np.clip(((gx - ax) * dx + (gz - az) * dz) / length2, 0.0, 1.0) if length2 > 0 else np.zeros_like(gx)
            d = np.hypot(gx - (ax + t * dx), gz - (az + t * dz))
            weight = np.clip((reach - d) / ROAD_SHOULDER_M, 0.0, 1.0)
            if not weight.any():
                continue
            target = profile[i] + t * (profile[i + 1] - profile[i])
            block = h[r0:r1 + 1, c0:c1 + 1]
            block[:] = block * (1 - weight) + target * weight


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
