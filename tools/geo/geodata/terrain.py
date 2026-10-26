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
# The rocks of the Hòn Bà band blend into the sea floor over this distance from the band edge.
BAND_BLEND_M = 4.0
# The boulders on the small islands (roughen_islands).
ISLAND_ROCK_M = 0.6
# The large boulders of the small islands (report 0005, D-0005-05): up to this
# height above the smooth hump of the DEM, about 6 m wide.
ISLAND_BOULDER_M = 1.8
ISLAND_BOULDER_SIGMA = 3.0
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
# The weight of the round join at a bend of a road, against the segments.
JOIN_WEIGHT = 0.001
# The steepest ground in the band beside a flat road (31 degrees): the player
# can walk on it. Steeper steps beside a road stopped the player in a hairpin.
ROAD_SIDE_GRADE = 0.6
# The width of that band beside the road surface.
ROAD_SIDE_M = 6.0
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


def remove_buildings(grid: Grid, town: np.ndarray, keep: np.ndarray | None = None) -> float:
    """The DEM is a surface model: it has the tops of buildings and trees. An
    opening filter (a minimum, then a maximum) removes shapes that are smaller
    than URBAN_FILTER_M. A slope stays as it is. The filter changes the towns
    and the low ground, but not the hills, and not the cells in keep (small
    islands such as Hòn Bà: they are smaller than the filter, so the filter
    makes them flat). Returns the mean change in meters where the filter
    changes the ground fully."""
    size = int(URBAN_FILTER_M / grid.step) | 1
    opened = ndimage.maximum_filter(ndimage.minimum_filter(grid.heights, size=size), size=size)
    density = ndimage.gaussian_filter(town.astype(np.float32), sigma=20.0 / grid.step)
    low = np.clip((LOW_GROUND_TOP_M - opened) / LOW_GROUND_BLEND_M, 0.0, 1.0)
    weight = np.maximum(np.clip(density * 3.0, 0.0, 1.0), low)
    if keep is not None:
        weight[keep] = 0.0
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


# The sea floor from data (plan 0005, R8g, changed on 2026-10-26, Q14, and
# report 0005, D-0005-06): beyond the edge of the intertidal data, the floor
# goes down at once, at the slope of the data at its edge, and never flatter
# than MIN_EDGE_SLOPE, to the GEBCO depth or to -SEA_FLOOR_DEPTH.
MIN_EDGE_SLOPE = 1.0 / 60.0
# The slope of the data at its edge comes from the outer EDGE_BAND_M of the data.
EDGE_BAND_M = 30.0
# Farther than this from the data, the floor has no data near: the old slope
# near the coast, then down at MIN_EDGE_SLOPE to the GEBCO depth.
DATA_REACH_M = 300.0
# The intertidal heights are smoothed over this size (the 10 m pixels are noisy).
INTERTIDAL_SMOOTH_M = 15.0
# From the coastline (LAND_MIN_HEIGHT), the floor is not lower than a ramp of
# this slope, so that there is no step at the coastline (the 10 m pixels of the
# intertidal zone near the coast are lower than the land).
COAST_RAMP = 0.1
# An intertidal group of cells counts when it comes this near to the coast,
# and when it has this many cells or more (20 pixels of 10 m): a few scattered
# pixels must not make a shelf (D-0005-06).
INTERTIDAL_COAST_M = 40.0
INTERTIDAL_MIN_GROUP_M2 = 2000.0
# The cells that keep their heights blend into the floor over this distance.
KEEP_BLEND_M = 12.0


def load_raster(grid: Grid, path, projection, resampling=Resampling.bilinear) -> np.ndarray:
    """A raster resampled to the grid. NaN where it has no value."""
    result = np.full(grid.shape, np.nan, dtype=np.float32)
    with rasterio.open(path) as src:
        source = src.read(1).astype(np.float32)
        if src.nodata is not None and not np.isnan(src.nodata):
            source[source == src.nodata] = np.nan
        transform = Affine(grid.step, 0, projection.origin_e + grid.x0 - grid.step / 2,
                           0, -grid.step, projection.origin_n - grid.z0 + grid.step / 2)
        reproject(source=source, destination=result, src_transform=src.transform, src_crs=src.crs, src_nodata=np.nan,
                  dst_transform=transform, dst_crs=f"EPSG:{projection.epsg}", resampling=resampling, dst_nodata=np.nan)
    return result


def smooth_valid(values: np.ndarray, sigma_cells: float) -> np.ndarray:
    """A Gaussian smoothing of the values that are not NaN. NaN stays NaN."""
    valid = np.isfinite(values)
    filled = np.where(valid, values, 0.0).astype(np.float32)
    total = ndimage.gaussian_filter(filled, sigma_cells)
    weight = ndimage.gaussian_filter(valid.astype(np.float32), sigma_cells)
    return np.where(valid, total / np.maximum(weight, 1e-6), np.nan).astype(np.float32)


def _smoothstep(edge0: float, edge1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def edge_slopes(values: np.ndarray, valid: np.ndarray, step: float) -> np.ndarray:
    """The slope (rise for each meter) of the data in its outer EDGE_BAND_M,
    smoothed. NaN at the other cells."""
    to_edge = ndimage.distance_transform_edt(valid).astype(np.float32) * step
    band = valid & (to_edge <= EDGE_BAND_M)
    filled = np.where(valid, values, 0.0).astype(np.float32)
    rise_rows, rise_cols = np.gradient(filled, step)
    slope = np.hypot(rise_rows, rise_cols)
    # The gradient is wrong where a neighbor has no data: those cells do not count.
    inner = ndimage.binary_erosion(valid, structure=np.ones((3, 3), dtype=bool))
    slope = np.where(band & inner, slope, np.nan).astype(np.float32)
    return smooth_valid(np.where(np.isfinite(slope), slope, np.nan), EDGE_BAND_M / step / 2.0) if np.isfinite(
        slope).any() else slope


def sea_floor_from_data(grid: Grid, land: np.ndarray, intertidal: np.ndarray | None, gebco: np.ndarray | None,
                        keep: np.ndarray | None = None) -> tuple[dict, np.ndarray]:
    """The sea floor from public data (R8g, D-0005-06). The sea cells have the
    slope of shape_coast() before this step.

    - Where the intertidal zone has a height (a group of cells that touches the
      coast and is not too small), the floor has that height.
    - Beyond the edge of the data, the floor goes down at once, at the slope of
      the data at its edge (never flatter than MIN_EDGE_SLOPE), to the GEBCO
      depth or to -SEA_FLOOR_DEPTH. It never makes new shallow ground.
    - Where no data is near, the old slope stays near the coast, and then the
      floor goes down at MIN_EDGE_SLOPE to the GEBCO depth.
    - Near the coastline, the floor is not lower than a ramp of COAST_RAMP.
    - The cells of keep (the rock band of Hòn Bà) keep their heights, with a
      blend over KEEP_BLEND_M around them.
    Returns the numbers for the report, and the mask of the cells with data."""
    h = grid.heights
    sea = ~land
    old = h.copy()
    # The depth farther out: GEBCO where it is deeper than -SEA_FLOOR_DEPTH (its
    # cells near the coast have the land in them, so there it is too shallow).
    target = np.full(grid.shape, -SEA_FLOOR_DEPTH, dtype=np.float32)
    if gebco is not None:
        target = np.where(np.isfinite(gebco), np.minimum(gebco, target), target).astype(np.float32)
    to_land = ndimage.distance_transform_edt(sea).astype(np.float32) * grid.step
    beyond_slope = -SEA_FLOOR_DEPTH - np.maximum(to_land - SEA_FLOOR_SLOPE_M, 0.0) * MIN_EDGE_SLOPE
    floor = np.where(to_land <= SEA_FLOOR_SLOPE_M, old, np.maximum(beyond_slope, target)).astype(np.float32)
    stats = {"intertidal_cells": 0, "gebco": gebco is not None}
    valid = np.zeros(grid.shape, dtype=bool)
    if intertidal is not None:
        values = smooth_valid(intertidal, INTERTIDAL_SMOOTH_M / grid.step / 2.0)
        valid = np.isfinite(values) & sea
        # Only the groups of cells that touch the coast and are not too small: a
        # boat at anchor looks dry in some images, and a few scattered pixels
        # must not make a shoal or a shelf.
        groups, count = ndimage.label(valid, structure=np.ones((3, 3), dtype=bool))
        if count:
            sizes = np.bincount(groups.ravel())
            touching = np.zeros(count + 1, dtype=bool)
            touching[np.unique(groups[valid & (to_land <= INTERTIDAL_COAST_M)])] = True
            keep_group = touching & (sizes * grid.step * grid.step >= INTERTIDAL_MIN_GROUP_M2)
            keep_group[0] = False
            valid &= keep_group[groups]
        if valid.any():
            slopes = edge_slopes(values, valid, grid.step)
            distance, (rows, cols) = ndimage.distance_transform_edt(~valid, return_indices=True)
            distance = distance.astype(np.float32) * grid.step
            edge = values[rows, cols]
            slope = np.nan_to_num(slopes[rows, cols], nan=MIN_EDGE_SLOPE)
            slope = np.clip(slope, MIN_EDGE_SLOPE, 1.0)
            down = np.maximum(edge - slope * distance, target)
            near = (distance <= DATA_REACH_M) & ~valid
            floor = np.where(valid, values, np.where(near, down, floor)).astype(np.float32)
            stats["intertidal_cells"] = int(valid.sum())
            stats["intertidal_min_m"] = round(float(values[valid].min()), 2)
            stats["intertidal_max_m"] = round(float(values[valid].max()), 2)
            stats["edge_slope_median"] = round(float(np.nanmedian(slopes)), 4) if np.isfinite(slopes).any() else None
    ramp = LAND_MIN_HEIGHT - to_land * COAST_RAMP
    # A data cell that the ramp lifts is not data any more (D-0005-08).
    valid &= floor >= ramp - 0.1
    floor = np.maximum(floor, ramp)
    if keep is not None and keep.any():
        near_keep = ndimage.distance_transform_edt(~keep).astype(np.float32) * grid.step
        weight = 1.0 - _smoothstep(0.0, KEEP_BLEND_M, near_keep)
        floor = floor * (1.0 - weight) + old * weight
    h[sea] = np.minimum(floor[sea], LAND_MIN_HEIGHT)
    return stats, valid


def water_beside_path(grid: Grid, land: np.ndarray, line, band, depth: float, reach: float, from_land: float,
                      blend: float = KEEP_BLEND_M) -> np.ndarray:
    """The water beside the rock path to Hòn Bà (D-0005-06): within reach of the
    line, farther than from_land from the land, and outside the band, the floor
    is not higher than depth. It blends over blend at the edges. Returns the
    cells that changed."""
    near = rasterize(grid, [line.buffer(reach + blend)])
    in_band = rasterize(grid, polygons_of_shape(band))
    to_land = ndimage.distance_transform_edt(~land).astype(np.float32) * grid.step
    zone = near & ~land & ~in_band & (to_land >= from_land)
    if not zone.any():
        return zone
    rows, cols = np.nonzero(zone)
    window = (slice(rows.min(), rows.max() + 1), slice(cols.min(), cols.max() + 1))
    inner = rasterize(grid, [line.buffer(reach)])[window] & ~in_band[window] & (to_land[window] >= from_land + blend)
    to_inner = ndimage.distance_transform_edt(~inner).astype(np.float32) * grid.step
    weight = np.where(zone[window], 1.0 - _smoothstep(0.0, blend, to_inner), 0.0)
    h = grid.heights[window]
    lowered = np.minimum(h, depth)
    changed = weight > 0.0
    h[changed] = (h * (1.0 - weight) + lowered * weight)[changed]
    grid.heights[window] = h
    result = np.zeros(grid.shape, dtype=bool)
    result[window] = changed & (lowered < grid.heights[window] + 1e-6)
    return result


def polygons_of_shape(shape) -> list:
    return [g for g in getattr(shape, "geoms", [shape]) if not g.is_empty]


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
    rise up to top + outcrop, and tide pools go down to top + pool. The rocks
    blend into the sea floor in the first BAND_BLEND_M of the band, and they
    never go below the sea floor that was there (the slope from the beach).
    line and band are shapely shapes in map coordinates. Only the sea cells
    change. Call it after make_sand_flat."""
    rows, cols = _window(grid, band.bounds, 12.0)
    core = rasterize(grid, [line.buffer(width / 2.0)])[rows, cols]
    inside = rasterize(grid, [band])[rows, cols] | core
    rng = np.random.default_rng(seed)
    big = _smooth_noise(core.shape, rng, 2.0)
    small = _smooth_noise(core.shape, rng, 0.7)
    rocks = np.where(big > 0, big * outcrop, -big * pool) + small * 0.08
    rocks = np.minimum(top + rocks, top + outcrop)
    path = top - rough * (0.5 + 0.5 * small)
    h = grid.heights[rows, cols]
    sea = ~land[rows, cols]
    depth = ndimage.distance_transform_edt(inside).astype(np.float32) * grid.step
    weight = np.clip(depth / BAND_BLEND_M, 0.0, 1.0)
    blended = h + (rocks - h) * weight
    new = np.where(core, path, blended)
    cells = inside & sea
    h[cells] = np.maximum(new[cells], h[cells])
    grid.heights[rows, cols] = h
    return {"band_cells": int(cells.sum()), "path_cells": int((core & sea).sum()),
            "min_m": round(float(h[cells].min()), 2) if cells.any() else None,
            "max_m": round(float(h[cells].max()), 2) if cells.any() else None}


def roughen_islands(grid: Grid, islands: np.ndarray, amplitude: float = ISLAND_ROCK_M, seed: int = 9) -> int:
    """Boulders on the small islands: the DEM has a cell of 30 m, so a small
    island is a smooth hump. Large boulders (up to ISLAND_BOULDER_M, about 6 m
    wide) stand on it, with smooth noise of +/- amplitude between them, on the
    land cells above LAND_MIN_HEIGHT. Returns the number of cells."""
    rows, cols = np.nonzero(islands)
    if rows.size == 0:
        return 0
    window = (slice(rows.min(), rows.max() + 1), slice(cols.min(), cols.max() + 1))
    h = grid.heights[window]
    rng = np.random.default_rng(seed)
    noise = _smooth_noise(h.shape, rng, 1.5)
    big = _smooth_noise(h.shape, rng, ISLAND_BOULDER_SIGMA)
    # Round tops and narrow gaps: the low parts of the noise go down less.
    boulders = np.where(big > 0.0, big, big * 0.3) * ISLAND_BOULDER_M
    above = islands[window] & (h > LAND_MIN_HEIGHT + 0.3)
    fade = np.clip((h - LAND_MIN_HEIGHT - 0.3) / 2.0, 0.0, 1.0)
    h[above] = (h + (noise * amplitude + boulders) * fade)[above]
    grid.heights[window] = h
    return int(above.sum())


def make_rock_shelf(grid: Grid, land: np.ndarray, band: np.ndarray, height: float, rough: float, seed: int = 11) -> int:
    """Flat rocks in the sea (plan 0005, Q6): the sea cells of band are at
    height, with small bumps of +/- rough. Returns the number of cells."""
    cells = band & ~land
    rows, cols = np.nonzero(cells)
    if rows.size == 0:
        return 0
    window = (slice(rows.min(), rows.max() + 1), slice(cols.min(), cols.max() + 1))
    h = grid.heights[window]
    noise = _smooth_noise(h.shape, np.random.default_rng(seed), 1.0)
    inside = cells[window]
    h[inside] = (height + noise * rough)[inside]
    grid.heights[window] = h
    return int(inside.sum())


def roughen_rocks(grid: Grid, rocks: np.ndarray, amplitude: float = ISLAND_BOULDER_M, seed: int = 12) -> int:
    """Boulders on a rocky coast (D-0005-03), on the land and in the sea: up to
    amplitude above the ground, about 6 m wide. Returns the number of cells."""
    rows, cols = np.nonzero(rocks)
    if rows.size == 0:
        return 0
    window = (slice(rows.min(), rows.max() + 1), slice(cols.min(), cols.max() + 1))
    h = grid.heights[window]
    rng = np.random.default_rng(seed)
    big = _smooth_noise(h.shape, rng, ISLAND_BOULDER_SIGMA)
    small = _smooth_noise(h.shape, rng, 1.0)
    # The boulders fade out at the edge of the area.
    inside = ndimage.distance_transform_edt(rocks[window]).astype(np.float32) * grid.step
    fade = np.clip(inside / 8.0, 0.0, 1.0)
    bumps = (np.maximum(big, 0.0) * amplitude + small * ISLAND_ROCK_M * 0.5) * fade
    h[rocks[window]] = (h + bumps)[rocks[window]]
    grid.heights[window] = h
    return int(rocks.sum())


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
    limit_road_sides(grid, flat)


def limit_road_sides(grid: Grid, roads, grade: float = ROAD_SIDE_GRADE, iterations: int = 30) -> int:
    """Limits the slope of the ground in a band beside the flat roads. The
    shoulders blend into the ground before the surfaces get their last
    heights, so the ground beside a road (most between the two legs of a
    hairpin) can have steps. The road surfaces do not change. Returns the
    number of changed cells."""
    h = grid.heights
    rows, cols = h.shape
    surface = np.zeros(h.shape, dtype=bool)
    band = np.zeros(h.shape, dtype=bool)
    for road in roads:
        half = road.width / 2.0
        reach = half + ROAD_SIDE_M
        x = road.points[:, 0]
        z = -road.points[:, 1]
        for i in range(len(x) - 1):
            ax, az, bx, bz = x[i], z[i], x[i + 1], z[i + 1]
            c0 = max(0, int((min(ax, bx) - reach - grid.x0) / grid.step))
            c1 = min(cols - 1, int((max(ax, bx) + reach - grid.x0) / grid.step) + 1)
            r0 = max(0, int((min(az, bz) - reach - grid.z0) / grid.step))
            r1 = min(rows - 1, int((max(az, bz) + reach - grid.z0) / grid.step) + 1)
            if c1 < c0 or r1 < r0:
                continue
            dx, dz = bx - ax, bz - az
            length2 = dx * dx + dz * dz
            if length2 <= 0.0:
                continue
            gx, gz = np.meshgrid(grid.x0 + np.arange(c0, c1 + 1) * grid.step, grid.z0 + np.arange(r0, r1 + 1) * grid.step)
            t = np.clip(((gx - ax) * dx + (gz - az) * dz) / length2, 0.0, 1.0)
            d = np.hypot(gx - (ax + t * dx), gz - (az + t * dz))
            surface[r0:r1 + 1, c0:c1 + 1] |= d <= half + grid.step / 2.0
            band[r0:r1 + 1, c0:c1 + 1] |= d <= reach
    return _limit_slope(h, band & ~surface, grade * grid.step, iterations)


def _limit_slope(h: np.ndarray, free_mask: np.ndarray, most: float, iterations: int) -> int:
    """Changes the cells of "free_mask" so that no step to a neighbor cell is
    more than "most". Returns the number of changed cells."""
    rows, cols = h.shape
    rs, cs = np.nonzero(free_mask)
    if len(rs) == 0:
        return 0
    r0, r1, c0, c1 = max(rs.min() - 1, 0), min(rs.max() + 2, rows), max(cs.min() - 1, 0), min(cs.max() + 2, cols)
    window = h[r0:r1, c0:c1]
    free = free_mask[r0:r1, c0:c1]
    before = window.copy()
    for _ in range(iterations):
        padded = np.pad(window, 1, mode="edge")
        neighbors = np.stack([padded[:-2, 1:-1], padded[2:, 1:-1], padded[1:-1, :-2], padded[1:-1, 2:]])
        low = neighbors.max(axis=0) - most
        high = neighbors.min(axis=0) + most
        limited = np.where(low <= high, np.clip(window, low, high), (low + high) / 2.0)
        changed = free & (np.abs(limited - window) > 1e-4)
        if not changed.any():
            break
        window[changed] = limited[changed]
    return int((free & (np.abs(window - before) > 1e-3)).sum())


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
            if i > 0:
                # The outside of a bend is beside neither segment. A disc at the
                # start point has the height of that point, with a very small
                # weight, so it counts only where no segment is beside a cell.
                join = (raw_t < 0.0) & (d <= half + grid.step / 2.0)
                mix[0][r0:r1 + 1, c0:c1 + 1][join] += (target * weight * JOIN_WEIGHT)[join]
                mix[1][r0:r1 + 1, c0:c1 + 1][join] += (weight * JOIN_WEIGHT)[join]
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
