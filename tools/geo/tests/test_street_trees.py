"""Tests for the street trees with the tree tops of the canopy map (report 0020, D-0020-03)."""

import numpy as np
from shapely.geometry import Point, Polygon

from geodata import roads, trees

SPEC = {
    "seed": 1,
    "canopy": {"use": True, "snap_m": 6.0, "edge_m": 6.0},
    "street": {"road_types": ["primary"], "spacing_m": 9.0, "jitter_m": 0.0, "in_from_edge_m": 0.8,
               "out_from_edge_m": 1.5, "skip_near_road_m": 1.0, "mix": {"shade": 1.0}},
    "coast_roads": {"names": [], "spacing_m": 7.0, "mix": {"casuarina": 1.0}},
    "bai_truoc_road": {"spacing_m": 10.0, "mix": {"bang": 1.0}},
    "named_roads": {"Trần Hưng Đạo": {"spacing_m": 10.0, "mix": {"tall_shade": 1.0}}},
    "parks": {"near_landmark": "x", "near_m": 100.0, "spacing_m": 10.0, "mix_near": {"coconut": 1.0},
              "mix": {"shade": 1.0}},
    "osm_trees": {"row_spacing_m": 8.0, "genus": {}, "default": "shade"},
}
LAND = Polygon([(-50, -100), (450, -100), (450, 100), (-50, 100)])


def _road(rid, name, kind, y):
    pts = np.array([(0.0, y), (400.0, y)])
    return roads.Road(id=rid, type=kind, name=name, width=8.0, width_source="table", surface="", hem=False,
                      sidewalk="", oneway=False, lanes=0, bridge=False, tunnel=False, refs=[rid * 10, rid * 10 + 1],
                      node_points=pts, points=pts)


def _make(road_list, tops, parks=()):
    return trees.make(SPEC, road_list, LAND, [], list(parks), [], [], "Quang Trung", None, None,
                      lambda x, y: np.zeros(len(x)), tops)


def test_other_road_has_trees_only_on_tree_tops():
    road = _road(1, "Đường A", "primary", 0.0)
    tops = np.array([[100.0, 8.0], [200.0, -7.0], [300.0, 30.0]])  # the last one is too far from the road
    _record, counts, groups = _make([road], tops)
    points = groups["street"]
    assert len(points) == 2
    assert {round(p[0]) for p in points} == {100, 200}


def test_crown_over_the_road_puts_the_trunk_at_the_edge():
    road = _road(1, "Đường A", "primary", 0.0)
    _record, _counts, groups = _make([road], np.array([[150.0, 1.0]]))
    (point,) = groups["street"]
    assert abs(point[1]) >= 4.0 + 1.5 - 1e-6


def test_confirmed_road_keeps_its_rows_and_moves_to_tree_tops():
    road = _road(1, "Trần Hưng Đạo", "primary", 0.0)
    without = _make([road], np.zeros((0, 2)))[2]["named_roads"]
    # Tops 3 m along the road and 2 m farther out from it.
    tops = np.array([[p[0] + 3.0, p[1] + np.sign(p[1]) * 2.0] for p in without[:4]])
    _record, counts, groups = _make([road], tops)
    assert len(groups["named_roads"]) == len(without)
    assert counts["named_roads_snapped"] == 4
    moved = {(round(p[0], 1), round(p[1], 1)) for p in groups["named_roads"]}
    assert all((round(t[0], 1), round(t[1], 1)) in moved for t in tops)


def test_other_park_has_trees_only_on_tree_tops():
    park = Polygon([(0, 20), (100, 20), (100, 90), (0, 90)])
    tops = np.array([[50.0, 50.0], [80.0, 60.0], [200.0, 60.0]])
    _record, _counts, groups = _make([], tops, [park])
    assert sorted(round(p[0]) for p in groups["parks"]) == [50, 80]


def test_without_tree_tops_the_rules_stay():
    road = _road(1, "Đường A", "primary", 0.0)
    _record, _counts, groups = _make([road], None)
    assert len(groups["street"]) > 50


def _make_in_showcase(spec, parks, keep_out=None):
    showcase = Polygon([(-50, -100), (450, -100), (450, 100), (-50, 100)])
    return trees.make(spec, [], LAND, [], list(parks), [], [], "Quang Trung", None, Point(50, 50),
                      lambda x, y: np.zeros(len(x)), np.zeros((0, 2)), keep_out, showcase)


def test_in_the_showcase_a_rule_tree_needs_a_photo():
    # Report 0026, D-0026-35: in the showcase a tree of a rule stands only on a
    # tree top or where a photo shows the trees of the rule. PT-53 found no
    # coconut palm at Bãi Trước when the park of the landmark had no photos.
    park = Polygon([(0, 20), (100, 20), (100, 90), (0, 90)])
    _record, counts, groups = _make_in_showcase(SPEC, [park])
    assert "park_bai_truoc" not in groups
    assert counts["no_data_in_showcase"] > 10
    with_photos = dict(SPEC, parks=dict(SPEC["parks"], photos_near=["docs/reference/photos/drone_2021_park.jpg"]))
    record, counts, groups = _make_in_showcase(with_photos, [park])
    assert len(groups["park_bai_truoc"]) > 10
    assert "no_data_in_showcase" not in counts
    assert len(record["types"]["coconut"]) == len(groups["park_bai_truoc"])


def test_a_rule_with_photos_keeps_off_the_walks():
    park = Polygon([(0, 20), (100, 20), (100, 90), (0, 90)])
    with_photos = dict(SPEC, parks=dict(SPEC["parks"], photos_near=["docs/reference/photos/drone_2021_park.jpg"]))
    _record, counts, groups = _make_in_showcase(with_photos, [park], keep_out=lambda x, y: 40.0 <= x <= 60.0)
    assert counts["kept_off_walks"] > 0
    assert all(not 40.0 <= p[0] <= 60.0 for p in groups["park_bai_truoc"])
