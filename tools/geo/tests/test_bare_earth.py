"""PT-65, the tests of R5b (plan 0009): the bare earth under the trees and the
roofs, and the zero of the heights (the mean sea level)."""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from geodata import bareearth  # noqa: E402

STEP = 2.0
SIZE = 300  # cells: 600 m


def _ground() -> np.ndarray:
    """A slope from 5 m to 35 m, with a gentle wave."""
    rows, cols = np.indices((SIZE, SIZE), dtype=np.float64)
    return (5.0 + 0.05 * cols * STEP + 2.0 * np.sin(rows / 40.0)).astype(np.float32)


def _forest() -> np.ndarray:
    """The tree cover of the test area: a square of 300 m in the middle."""
    forest = np.zeros((SIZE, SIZE), dtype=bool)
    forest[75:225, 75:225] = True
    return forest


def _setup(models: dict, cop: np.ndarray):
    truth = _ground()
    forest = _forest()
    land = np.ones((SIZE, SIZE), dtype=bool)
    classes = bareearth.class_map(land, forest, np.zeros_like(forest), np.zeros_like(forest))
    zones = np.zeros((SIZE, SIZE), dtype=np.int8)
    rng = np.random.default_rng(3)
    # 400 lidar ground points, at the true ground (with 0.3 m of noise).
    x = rng.uniform(10, SIZE * STEP - 10, 400)
    z = rng.uniform(10, SIZE * STEP - 10, 400)
    ground = bareearth.bilinear(truth, x, z, 0.0, 0.0, STEP) + rng.normal(0, 0.3, 400)
    points = np.column_stack([x, z, ground])
    all_models = {bareearth.COPERNICUS: cop} | models
    result = bareearth.compare(all_models, points, classes, zones, [bareearth.LOW_LAND], 0.0, 0.0, STEP)
    choice = bareearth.choose(result, 30)
    heights = cop.copy()
    out = bareearth.apply(heights, all_models, classes, zones, [bareearth.LOW_LAND], choice,
                          np.zeros_like(forest), STEP, 2.0, 30.0, 60.0)
    return truth, forest, result, choice, heights, out


def test_a_dem_5_m_too_high_under_the_trees_is_found_and_lowered():
    truth = _ground()
    forest = _forest()
    cop = truth + np.where(forest, 5.0, 0.0).astype(np.float32)
    _t, _f, result, choice, heights, _out = _setup({"gedtm30": truth.copy()}, cop)
    tree = result["by_model"][bareearth.COPERNICUS]["class"]["tree"]
    assert abs(tree["mean"] - 5.0) < 0.5, tree
    assert choice["low_land/tree"]["model"] == "gedtm30"
    inner = np.zeros_like(forest)
    inner[110:190, 110:190] = True  # farther than the blend from the edge
    assert np.abs(heights[inner] - truth[inner]).max() < 0.5


def test_a_correct_dem_does_not_change():
    truth = _ground()
    rng = np.random.default_rng(5)
    model = truth + rng.normal(0, 0.4, truth.shape).astype(np.float32)
    _t, _f, _r, _c, heights, out = _setup({"gedtm30": model}, truth.copy())
    assert np.array_equal(heights, truth)
    assert out["numbers"]["changed_ha"] == 0.0


def test_of_two_models_the_correct_one_is_taken_with_no_step_at_the_edge():
    truth = _ground()
    forest = _forest()
    cop = truth + np.where(forest, 5.0, 0.0).astype(np.float32)
    wrong = truth + 5.0
    _t, _f, result, choice, heights, _out = _setup({"gedtm30": wrong, "deltadtm": truth.copy()}, cop)
    assert choice["low_land/tree"]["model"] == "deltadtm"
    # The DEM has its own step of 5 m at the edge of the forest; the bare earth
    # has none: no cell is more than 0.3 m from its neighbor, more than the slope.
    slope_step = 0.05 * STEP + 2.0 * STEP / 40.0
    assert bareearth.cell_steps(heights - 0.0, np.ones_like(forest)) < 0.3 + slope_step
    assert bareearth.cell_steps(heights - truth, np.ones_like(forest)) < 0.3


def test_a_group_with_few_lidar_points_keeps_copernicus():
    truth = _ground()
    forest = _forest()
    cop = truth + np.where(forest, 5.0, 0.0).astype(np.float32)
    land = np.ones((SIZE, SIZE), dtype=bool)
    classes = bareearth.class_map(land, forest, np.zeros_like(forest), np.zeros_like(forest))
    zones = np.zeros((SIZE, SIZE), dtype=np.int8)
    points = np.array([[300.0, 300.0, float(truth[150, 150])]] * 10)
    models = {bareearth.COPERNICUS: cop, "gedtm30": truth}
    result = bareearth.compare(models, points, classes, zones, [bareearth.LOW_LAND], 0.0, 0.0, STEP)
    choice = bareearth.choose(result, 30)
    assert choice["low_land/tree"]["model"] == bareearth.COPERNICUS
    assert "fewer than 30" in choice["low_land/tree"]["why"]


def test_the_sea_below_the_high_water_keeps_its_heights():
    truth = _ground()
    forest = np.ones((SIZE, SIZE), dtype=bool)
    cop = truth + 5.0
    land = np.ones((SIZE, SIZE), dtype=bool)
    classes = bareearth.class_map(land, forest, np.zeros_like(forest), np.zeros_like(forest))
    zones = np.zeros((SIZE, SIZE), dtype=np.int8)
    keep = np.zeros_like(forest)
    keep[:, :50] = True
    models = {bareearth.COPERNICUS: cop, "gedtm30": truth}
    choice = {"low_land/tree": {"model": "gedtm30"}}
    heights = cop.copy()
    bareearth.apply(heights, models, classes, zones, [bareearth.LOW_LAND], choice, keep, STEP, 2.0, 30.0, 60.0)
    assert np.array_equal(heights[keep], cop[keep])
    assert np.abs(heights[:, 120:] - truth[:, 120:]).max() < 0.01


def test_a_lidar_point_over_the_ellipsoid_gets_the_height_of_the_models_then_the_mean_sea_level(monkeypatch):
    """lidar.py changes a height over the WGS 84 ellipsoid to a height over
    EGM2008 (the datum of Copernicus, GEDTM30, and DeltaDTM); the build then
    takes away the mean dynamic topography (DTU22: 1.16 m)."""
    import lidar

    class Geoid:
        def transform(self, lon, lat, h):
            return lon, lat, np.asarray(h) - (-3.0)  # a geoid 3 m under the ellipsoid

    import pyproj
    monkeypatch.setattr(pyproj.Transformer, "from_crs", staticmethod(lambda *a, **k: Geoid()))
    monkeypatch.setattr(pyproj.network, "set_network_enabled", lambda *_a: None)
    over_egm = lidar.egm2008(np.array([107.07]), np.array([10.34]), np.array([10.0]))
    assert abs(float(over_egm[0]) - 13.0) < 1e-6
    assert abs(float(bareearth.msl(over_egm, 1.16)[0]) - 11.84) < 1e-6


def test_the_dem_is_on_the_grid_of_copernicus():
    """The pixels of Copernicus GLO-30 have their centers on whole arc seconds
    (the edge of a tile is half a pixel west of its degree). fetch_dem() kept
    the pixels of the tile but put its window on the edges of the box: the
    ground was half a pixel (about 15 m) west and north of its place."""
    import rasterio
    raw = Path(__file__).resolve().parents[3] / "data" / "geo" / "raw"
    with rasterio.open(raw / "dem.tif") as dem:
        res = dem.res[0]
        for edge in (dem.transform.c, dem.transform.f):
            pixels = (edge - round(edge)) / res + 0.5
            assert abs(pixels - round(pixels)) < 1e-6, f"the edge {edge} is not on the grid of Copernicus"


def test_the_merge_of_the_dem_keeps_the_grid_of_its_tiles(tmp_path):
    import rasterio
    from rasterio.transform import from_origin
    import fetch
    res = 1 / 3600
    data = np.arange(3600 * 40, dtype=np.float32).reshape(40, 3600)
    profile = {"driver": "GTiff", "height": 40, "width": 3600, "count": 1, "dtype": "float32", "crs": "EPSG:4326",
               "transform": from_origin(107.0 - res / 2, 10.5 + res / 2, res, res)}
    tile = tmp_path / "tile.tif"
    with rasterio.open(tile, "w", **profile) as dst:
        dst.write(data, 1)
    with rasterio.open(tile) as src:
        mosaic, transform = fetch.merge_on_grid([src], (107.04, 10.495, 107.05, 10.5))
    pixels = (transform.c - 107.0) / res + 0.5
    assert abs(pixels - round(pixels)) < 1e-6
    # The first pixel of the mosaic is the pixel of the tile at that place.
    col = round((transform.c - (107.0 - res / 2)) / res)
    assert mosaic[0, 0, 0] == data[round(((10.5 + res / 2) - transform.f) / res), col]


def test_the_land_at_the_coast_keeps_its_height_where_the_dem_has_the_sea(tmp_path):
    """Copernicus has 0 on the sea. The cubic sample of the land cells next to
    the coastline mixed that 0 in: the walk on the sea wall of S1 fell from
    4.6 m to 1.4 m. The land takes the nearest land value of the DEM."""
    import rasterio
    from rasterio.transform import from_origin
    from geodata import terrain
    from geodata.projection import Projection
    res = 1 / 3600
    data = np.full((60, 60), 5.0, dtype=np.float32)
    data[:, :30] = 0.0  # the sea, west of 107.0 + 30 cells
    path = tmp_path / "dem.tif"
    profile = {"driver": "GTiff", "height": 60, "width": 60, "count": 1, "dtype": "float32", "crs": "EPSG:4326",
               "transform": from_origin(107.0 - res / 2, 10.35 + res / 2, res, res)}
    with rasterio.open(path, "w", **profile) as dst:
        dst.write(data, 1)
    from pyproj import Transformer
    e, n = Transformer.from_crs(4326, 32648, always_xy=True).transform(107.0 + 29.5 * res, 10.35 - 30 * res)
    projection = Projection(e, n)
    grid = terrain.make_grid((-200.0, -200.0, 200.0, 200.0), 256.0, 2.0)
    land = np.zeros(grid.shape, dtype=bool)
    cols = np.arange(grid.shape[1]) * grid.step + grid.x0
    land[:, cols >= 0.0] = True  # the coastline at x = 0, the edge of the sea pixels
    terrain.load_dem(grid, path, projection, land)
    assert grid.heights[land].min() > 4.5, grid.heights[land].min()


def test_the_band_of_the_coast_keeps_copernicus():
    truth = _ground()
    land = np.ones((SIZE, SIZE), dtype=bool)
    land[:, :20] = False  # the sea
    forest = np.ones((SIZE, SIZE), dtype=bool)
    classes = bareearth.class_map(land, forest, np.zeros_like(forest), np.zeros_like(forest))
    zones = np.zeros((SIZE, SIZE), dtype=np.int8)
    cop = truth.copy()
    model = truth - 4.0  # too low everywhere, as a model of 30 m with the sea in its pixels
    keep = bareearth.coast_keep(land, STEP, 30.0)
    heights = cop.copy()
    bareearth.apply(heights, {bareearth.COPERNICUS: cop, "gedtm30": model}, classes, zones, [bareearth.LOW_LAND],
                    {"low_land/tree": {"model": "gedtm30"}}, keep, STEP, 2.0, 30.0, 60.0)
    band = land.copy()
    band[:, 20 + 14:] = False  # the land within 30 m of the sea (the cells at 2 m to 28 m)
    assert np.array_equal(heights[band], cop[band])


def test_a_hill_with_few_lidar_points_takes_the_choice_of_the_nearest_hill():
    """Report 0009, D-0009-17: Núi Nhỏ has 3 lidar points; its tree cover takes
    the choice of the tree cover of the nearest hill with enough points (Núi
    Lớn), not Copernicus."""
    def stats(n, rmse):
        return {"n": n, "rmse": rmse, "mean": 0.0}
    groups_cop = {"low_land/tree": stats(100, 4.0), "nui_lon/tree": stats(200, 8.0), "nui_nho/tree": stats(3, 9.0),
                  "far_hill/tree": stats(300, 2.0)}
    groups_ged = {"low_land/tree": stats(100, 5.0), "nui_lon/tree": stats(200, 3.0), "nui_nho/tree": stats(3, 1.0),
                  "far_hill/tree": stats(300, 6.0)}
    result = {"by_model": {bareearth.COPERNICUS: {"group": groups_cop}, "gedtm30": {"group": groups_ged}}}
    positions = {"nui_lon": (0.0, 0.0), "nui_nho": (1000.0, 2000.0), "far_hill": (9000.0, 9000.0)}
    choice = bareearth.choose(result, 30, positions)
    assert choice["nui_lon/tree"]["model"] == "gedtm30"
    assert choice["nui_nho/tree"]["model"] == "gedtm30"
    assert choice["nui_nho/tree"]["from"] == "nui_lon/tree"
    assert "nui_lon" in choice["nui_nho/tree"]["why"]
    # The low land keeps its own choice, and with no positions a group with few points keeps Copernicus.
    assert choice["low_land/tree"]["model"] == bareearth.COPERNICUS
    assert bareearth.choose(result, 30)["nui_nho/tree"]["model"] == bareearth.COPERNICUS
