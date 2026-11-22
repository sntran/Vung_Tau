"""Report 0009, D-0009-16: the water of the land (geodata/inland_water.py)."""

import sys
from pathlib import Path

import numpy as np
import shapely
from shapely.geometry import box

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from geodata import inland_water, terrain  # noqa: E402


def _grid(height: float = 5.0):
    grid = terrain.make_grid((-100.0, -100.0, 100.0, 100.0), 256.0, 2.0)
    grid.heights[:] = height
    return grid


def test_a_small_pond_and_the_sea_are_not_water_of_the_land():
    land = box(-100, -100, 100, 0)
    records = [("way/1", {"natural": "water", "name": "Bàu Sen"}, box(-50, -50, -10, -10)),
               ("way/2", {"natural": "water"}, box(20, -30, 25, -25)),
               ("way/3", {"natural": "water"}, box(-50, 10, 50, 50))]
    water = inland_water.areas(records, land, 200.0)
    assert [a["name"] for a in water] == ["Bàu Sen"]


def test_the_level_is_the_median_of_copernicus_and_the_ground_goes_under_it():
    grid = _grid()
    copernicus = grid.heights.copy()
    lake = box(-40, -40, 0, 0)
    cells = terrain.rasterize(grid, [lake])
    copernicus[cells] = 2.0
    water = [{"osm": "way/1", "name": "", "kind": "lake", "polygon": lake}]
    inland_water.levels(grid, copernicus, water, terrain.rasterize)
    assert water[0]["level"] == 2.0
    road = terrain.rasterize(grid, [box(-40, -22, 0, -18)])
    changed = inland_water.cut(grid, water, 1.0, terrain.rasterize, road)
    assert changed > 0
    assert np.all(grid.heights[cells & ~road] == 1.0)
    # A causeway keeps its road.
    assert np.all(grid.heights[cells & road] == 5.0)


def test_the_triangles_cover_the_polygon_with_its_hole():
    lake = shapely.Polygon([(0, 0), (30, 0), (30, 20), (0, 20)], [[(10, 5), (20, 5), (20, 15), (10, 15)]])
    flat = inland_water.triangles(lake)
    area = 0.0
    for i in range(0, len(flat), 6):
        (ax, az), (bx, bz), (cx, cz) = zip(flat[i:i + 6:2], flat[i + 1:i + 6:2])
        area += abs((bx - ax) * (cz - az) - (cx - ax) * (bz - az)) / 2.0
    assert abs(area - lake.area) < 1e-6
    inside = inland_water.contains([{"polygon": lake}])
    assert inside(5, 5) and not inside(15, 10)
