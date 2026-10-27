"""Unit tests for the land cover and the trees from public data (report 0005,
D-0005-09, correction 0; plan 0020, D8 and R10a)."""

import json
from types import SimpleNamespace

from shapely.geometry import Point

import numpy as np
import pytest

import landcover as fetch
from geodata import landcover


def grid(rows=40, cols=40, step=2.0):
    return SimpleNamespace(x0=-100, z0=-50, step=step, shape=(rows, cols))


def crown(shape, row, col, height, radius_cells):
    """A round crown: the height at the top, lower to the edge."""
    yy, xx = np.mgrid[:shape[0], :shape[1]]
    d2 = (yy - row) ** 2 + (xx - col) ** 2
    return np.where(d2 <= radius_cells ** 2, height - d2 * 0.1, 0.0).astype(np.float32)


def test_canopy_decides_tree_bush_and_grass():
    classes = np.array([[landcover.TREE, landcover.TREE, landcover.GRASS, landcover.BUILT, landcover.BARE]])
    canopy = np.array([[8.0, 1.0, 0.0, 9.0, 0.2]], dtype=np.float32)
    land = np.ones(classes.shape, dtype=bool)
    masks = landcover.cover_masks(classes, canopy, land)
    assert masks["tree"].tolist() == [[True, False, False, False, False]]
    # A low canopy in "tree cover" is a bush (WorldCover has almost no shrubland here).
    assert masks["bush"].tolist() == [[False, True, False, False, False]]
    assert masks["grass"].tolist() == [[False, False, True, False, False]]
    # The built-up class keeps the rules of the town and of trees.json.
    assert masks["bare"].tolist() == [[False, False, False, False, True]]


def test_low_canopy_on_grass_or_bare_ground_is_not_a_bush():
    # Plan 0020, R10a: grassland and bare ground show the ground.
    classes = np.array([[landcover.GRASS, landcover.BARE, landcover.SHRUB]])
    canopy = np.array([[1.5, 1.5, 0.0]], dtype=np.float32)
    masks = landcover.cover_masks(classes, canopy, np.ones(classes.shape, dtype=bool))
    assert masks["bush"].tolist() == [[False, False, True]]
    assert masks["grass"].tolist() == [[True, False, False]]
    assert masks["bare"].tolist() == [[False, True, False]]


def test_sea_has_no_cover():
    classes = np.full((2, 2), landcover.TREE, dtype=np.uint8)
    canopy = np.full((2, 2), 10.0, dtype=np.float32)
    masks = landcover.cover_masks(classes, canopy, np.zeros((2, 2), dtype=bool))
    assert not any(m.any() for m in masks.values())


def test_trees_on_the_tops_and_crowns():
    shape = (40, 40)
    canopy = np.maximum(crown(shape, 10, 10, 12.0, 4), crown(shape, 25, 28, 7.0, 3))
    rows, cols = landcover.tree_places(canopy, 2.0, np.ones(shape, dtype=bool))
    assert sorted(zip(rows.tolist(), cols.tolist())) == [(10, 10), (25, 28)]
    radii = dict(zip(zip(rows.tolist(), cols.tolist()), landcover.crown_radii(canopy, 2.0, rows, cols)))
    # The crowns are 8 m and 6 m wide in radius, less the edge of the canopy grid.
    assert radii[(10, 10)] == pytest.approx(8.0 - landcover.CROWN_EDGE_M, abs=0.6)
    assert radii[(25, 28)] == pytest.approx(6.0 - landcover.CROWN_EDGE_M, abs=0.6)


def test_low_canopy_has_no_tree():
    canopy = crown((20, 20), 10, 10, landcover.TREE_MIN_M - 0.5, 3)
    rows, _ = landcover.tree_places(canopy, 2.0, np.ones((20, 20), dtype=bool))
    assert rows.size == 0


def test_trees_fill_a_wide_patch_at_their_spacing():
    # A flat forest of 10 m on 80 m x 80 m: one height top for the whole patch.
    canopy = np.full((40, 40), 10.0, dtype=np.float32)
    rows, cols = landcover.tree_places(canopy, 2.0, np.ones((40, 40), dtype=bool))
    gap = landcover.spacing(10.0)
    assert 30 <= rows.size <= 90
    points = np.stack([rows, cols], axis=1) * 2.0
    distance = np.hypot(*(points[:, None, :] - points[None, :, :]).transpose(2, 0, 1))
    assert distance[~np.eye(rows.size, dtype=bool)].min() >= gap - 1e-6
    radii = landcover.crown_radii(canopy, 2.0, rows, cols)
    assert np.median(radii) == pytest.approx(gap / 2.0, rel=0.35)


def test_trees_are_the_same_each_time():
    canopy = np.full((30, 30), 8.0, dtype=np.float32)
    first = landcover.tree_places(canopy, 2.0, np.ones((30, 30), dtype=bool))
    second = landcover.tree_places(canopy, 2.0, np.ones((30, 30), dtype=bool))
    assert all((a == b).all() for a, b in zip(first, second))


def test_crowns_in_tiles_are_the_same(monkeypatch):
    shape = (60, 60)
    canopy = np.maximum(crown(shape, 20, 29, 10.0, 5), crown(shape, 31, 30, 9.0, 5))
    rows, cols = landcover.tree_places(canopy, 2.0, np.ones(shape, dtype=bool))
    whole = landcover.crown_radii(canopy, 2.0, rows, cols)
    monkeypatch.setattr(landcover, "CROWN_TILE", 16)
    assert landcover.crown_radii(canopy, 2.0, rows, cols) == pytest.approx(whole)


def test_write_trees(tmp_path):
    shape = (40, 40)
    canopy = crown(shape, 10, 20, 12.0, 4)
    rows, cols = landcover.tree_places(canopy, 2.0, np.ones(shape, dtype=bool))
    summary = landcover.write_trees(tmp_path / "canopy_trees.json", grid(), canopy, rows, cols)
    record = json.loads((tmp_path / "canopy_trees.json").read_text())
    assert summary["count"] == record["count"] == 1
    x, z, height, radius = record["trees"]
    assert (x, z, height) == (-100 + 20 * 2.0, -50 + 10 * 2.0, 12.0)
    assert 6.0 < radius < 8.0


def test_street_tree_without_canopy_is_listed():
    canopy = crown((40, 40), 10, 10, 9.0, 3)
    g = grid()
    near = [g.x0 + 11 * g.step, 0.0, g.z0 + 10 * g.step]
    far = [g.x0 + 30 * g.step, 0.0, g.z0 + 30 * g.step]
    assert landcover.street_trees_without_canopy([near, far], g, canopy) == [far]


def test_write_canopy_place(tmp_path):
    g = grid(8, 8)
    canopy = np.zeros((8, 8), dtype=np.float32)
    canopy[1, 3] = 10.0
    place = landcover.write_canopy(g, canopy, np.ones((8, 8), dtype=bool), tmp_path / "canopy.png")
    assert (place["columns"], place["rows"], place["step"]) == (4, 4, 4.0)
    # The center of the first pixel of 2 x 2 cells.
    assert (place["x0"], place["z0"]) == (-99.0, -49.0)
    from PIL import Image
    image = np.array(Image.open(tmp_path / "canopy.png"))
    assert image[0, 1] == round(10.0 / landcover.CANOPY_SCALE) and image.sum() == image[0, 1]


def test_worldcover_tile_and_quadkey():
    assert fetch.worldcover_tile(107.08, 10.35) == "N09E105"
    assert fetch.quadkey(107.08, 10.35, 9) == "132231002"


def test_clearings_keep_trees_off_places_and_roads():
    from shapely.geometry import box
    from geodata import clearings
    area = SimpleNamespace(tags={"highway": "pedestrian", "area": "yes"}, geometry=box(0, 0, 10, 10))
    road_area = SimpleNamespace(tags={"highway": "residential"}, geometry=box(20, 0, 30, 10))
    huge = SimpleNamespace(tags={"tourism": "attraction"}, geometry=box(0, 0, 1000, 1000))
    temple = SimpleNamespace(tags={"amenity": "place_of_worship"}, geometry=box(40, 0, 50, 10))
    config = {"osm_keys": ["amenity", "tourism"], "max_area_m2": 30000, "margin_m": 2.0,
              "landmarks": {"top": 25.0, "missing": 10.0}, "road_margin_m": 1.5}
    found = {"top": {"found": True, "position": [100.0, -200.0]}}
    shapes = clearings.place_shapes([area, road_area, huge, temple], lambda g: g, found, config)
    # The pedestrian area and the temple with their margin, and the circle of the landmark (game z is map -y).
    assert len(shapes) == 3
    assert shapes[0].area == pytest.approx(14 * 14, rel=0.05)
    assert shapes[2].centroid.x == pytest.approx(100.0) and shapes[2].centroid.y == pytest.approx(200.0, abs=0.01)
    road = SimpleNamespace(points=np.array([[0.0, 0.0], [100.0, 0.0]]), width=6.0)
    (strip,) = clearings.road_shapes([road], config)
    assert strip.contains(Point(50.0, 4.4)) and not strip.contains(Point(50.0, 4.6))


def test_osm_pedestrian_area_is_read(tmp_path):
    from geodata import osm
    xml = tmp_path / "small.osm"
    xml.write_text("""<?xml version='1.0' encoding='UTF-8'?>
<osm version="0.6">
  <node id="1" lat="10.0" lon="107.0"/><node id="2" lat="10.0" lon="107.001"/>
  <node id="3" lat="10.001" lon="107.001"/><node id="4" lat="10.001" lon="107.0"/>
  <way id="10"><nd ref="1"/><nd ref="2"/><nd ref="3"/><nd ref="4"/><nd ref="1"/>
    <tag k="highway" v="pedestrian"/><tag k="area" v="yes"/></way>
  <way id="11"><nd ref="1"/><nd ref="2"/><nd ref="3"/><nd ref="1"/>
    <tag k="highway" v="residential"/></way>
</osm>""")
    data = osm.read(xml)
    assert [a.id for a in data.areas] == [10]
