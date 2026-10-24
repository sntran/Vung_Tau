"""Unit tests for the parts of the pipeline (plan 0005, R17 and R18)."""

import math

import numpy as np
import pytest
from shapely.geometry import LineString, Polygon

from geodata import blocks, coast, homestay, landmarks, pngio, roads, terrain
from geodata.config import Config, ROOT
from geodata.projection import Projection

TABLE = Config(ROOT / "data" / "geo").road_widths


def test_projection_known_point():
    # Two points 0.01 degrees apart in latitude are about 1105 m apart near 10.35 N.
    p = Projection.at(107.0728, 10.3466, 10)
    x0, z0 = p.to_game(107.0728, 10.3466)
    x1, z1 = p.to_game(107.0728, 10.3566)
    assert abs(x0) <= 5.0 and abs(z0) <= 5.0
    assert z1 < z0, "north is game -Z"
    assert math.hypot(x1 - x0, z1 - z0) == pytest.approx(1105.8, abs=2.0)


def test_projection_origin_is_rounded():
    p = Projection.at(107.0728, 10.3466, 10)
    assert p.origin_e % 10 == 0 and p.origin_n % 10 == 0


def test_projection_round_trip_below_one_centimeter():
    p = Projection.at(107.0728, 10.3466, 10)
    for lon, lat in [(107.05, 10.30), (107.13, 10.42), (107.0777, 10.3343)]:
        x, z = p.to_game(lon, lat)
        lon2, lat2 = p.game_to_lonlat(x, z)
        x2, z2 = p.to_game(lon2, lat2)
        assert math.hypot(float(x2 - x), float(z2 - z)) < 0.01


def test_height_sampling_on_a_known_grid():
    heights = np.array([[0.0, 2.0, 4.0], [10.0, 12.0, 14.0], [20.0, 22.0, 24.0]], dtype=np.float32)
    grid = terrain.Grid(x0=100.0, z0=-50.0, step=2.0, heights=heights)
    assert grid.sample(100.0, -50.0) == pytest.approx(0.0)
    assert grid.sample(102.0, -48.0) == pytest.approx(12.0)
    assert grid.sample(101.0, -50.0) == pytest.approx(1.0)
    assert grid.sample(103.0, -47.0) == pytest.approx(18.0)
    # A point out of the grid takes the height of the edge.
    assert grid.sample(200.0, -48.0) == pytest.approx(14.0)


@pytest.mark.parametrize("text, meters", [("4", 4.0), ("4.5", 4.5), ("4,5", 4.5), ("4 m", 4.0), ("13'", 3.96),
                                          ("10 ft", 3.05), ("", None), ("wide", None), ("0", None), ("200", None)])
def test_parse_width(text, meters):
    assert roads.parse_width(text) == meters


def test_width_from_tag_and_from_table():
    assert roads.width_of({"width": "3"}, "residential", TABLE) == (3.0, "tag")
    assert roads.width_of({}, "primary", TABLE) == (TABLE["types"]["primary"], "table")
    assert roads.width_of({}, "unknown_type", TABLE) == (TABLE["default"], "table")


def test_width_from_lanes_and_links():
    assert roads.width_of({"highway": "primary_link"}, "primary", TABLE) == (TABLE["link_width"], "table")
    width, source = roads.width_of({"lanes": "3", "oneway": "yes"}, "primary", TABLE)
    assert source == "lanes" and width == 3 * TABLE["lane_width"] + 2.0
    assert roads.width_of({"lanes": "2"}, "residential", TABLE) == (2 * TABLE["lane_width"], "lanes")


def test_road_types():
    assert roads.road_type({"highway": "primary_link"}) == "primary"
    assert roads.road_type({"highway": "service", "service": "alley"}) == "alley"
    assert roads.road_type({"highway": "construction"}) is None
    assert roads.road_type({"highway": "pedestrian", "area": "yes"}) is None
    assert roads.road_type({"building": "yes"}) is None


def test_hem_flag():
    assert roads.is_hem("residential", 3.0, TABLE)
    assert roads.is_hem("alley", 2.5, TABLE)
    assert roads.is_hem("footway", 2.0, TABLE)
    assert not roads.is_hem("residential", 5.0, TABLE)
    assert not roads.is_hem("tertiary", 3.0, TABLE)


def test_hem_name():
    tags = {"name": "Hẻm 2 Hải Đăng"}
    assert roads.is_hem("unclassified", 6.0, TABLE, tags)
    assert roads.width_of(tags, "unclassified", TABLE) == (TABLE["hem_name_width"], "table")
    assert roads.width_of({"name": "Hẻm 5", "width": "5"}, "unclassified", TABLE) == (5.0, "tag")
    assert not roads.is_hem("unclassified", 6.0, TABLE, {"name": "Hẻmx"})
    assert not roads.is_hem("primary", 12.0, TABLE, {"name": "Hạ Long"})


def test_oneway_road_is_one_carriageway():
    width, source = roads.width_of({"oneway": "yes"}, "primary", TABLE)
    assert source == "table" and width == pytest.approx(TABLE["types"]["primary"] * TABLE["oneway_factor"])
    assert roads.width_of({"oneway": "yes", "width": "9"}, "primary", TABLE) == (9.0, "tag")
    assert roads.sidewalk_side({"oneway": "yes"}, "primary", TABLE) == "right"
    assert roads.sidewalk_side({}, "primary", TABLE) == "both"
    assert roads.sidewalk_side({"oneway": "yes", "sidewalk": "left"}, "primary", TABLE) == "left"


def test_sidewalk():
    assert roads.has_sidewalk({}, "primary", TABLE)
    assert not roads.has_sidewalk({"sidewalk": "no"}, "primary", TABLE)
    assert roads.has_sidewalk({"sidewalk": "both"}, "residential", TABLE)
    assert not roads.has_sidewalk({}, "residential", TABLE)


def _road(rid, kind, points, width=6.0):
    pts = np.array(points, dtype=float)
    return roads.Road(id=rid, type=kind, name="", width=width, width_source="table", surface="", hem=False,
                      sidewalk="", oneway=False, lanes=0, bridge=False, tunnel=False,
                      refs=list(range(rid * 100, rid * 100 + len(pts))), node_points=pts, points=pts)


def test_blocks_from_a_small_set_of_roads():
    # Two roads across a square of land make four blocks.
    land = Polygon([(0, 0), (200, 0), (200, 200), (0, 200)])
    network = [_road(1, "residential", [(-10, 100), (210, 100)]), _road(2, "residential", [(100, -10), (100, 210)])]
    result = blocks.make_blocks(network, land, [Polygon([(10, 10), (20, 10), (20, 20), (10, 20)])], [])
    assert len(result) == 4
    for block in result:
        # Each block is 100 m x 100 m without half of each road (3 m).
        assert block["polygon"].area == pytest.approx(97.0 * 97.0, rel=0.01)
    assert sorted(b["buildings"] for b in result) == [0, 0, 0, 1]


def test_footways_do_not_cut_blocks():
    land = Polygon([(0, 0), (200, 0), (200, 200), (0, 200)])
    result = blocks.make_blocks([_road(1, "footway", [(-10, 100), (210, 100)], 2.0)], land, [], [])
    assert len(result) == 2 or len(result) == 1
    assert sum(b["polygon"].area for b in result) == pytest.approx(200 * 200 - 2 * 200, rel=0.01)


def test_land_is_at_the_left_of_the_coastline():
    box = Polygon([(-100, -100), (100, -100), (100, 100), (-100, 100)])
    # The line goes south at x = 0: the land is at the east (the left side).
    problems = []
    land = coast.land_polygon([LineString([(0, 200), (0, -200)])], box, problems)
    assert land.area == pytest.approx(200 * 100, rel=0.001)
    assert land.centroid.x > 0
    assert problems == []


def test_island_is_land():
    box = Polygon([(-100, -100), (100, -100), (100, 100), (-100, 100)])
    island = LineString([(-10, -10), (10, -10), (10, 10), (-10, 10), (-10, -10)])  # counterclockwise
    land = coast.land_polygon([island], box, [])
    assert land.area == pytest.approx(400.0, rel=0.001)


def test_png16_round_trip(tmp_path):
    values = (np.arange(129 * 129, dtype=np.uint32).reshape(129, 129) * 7 % 65536).astype(np.uint16)
    pngio.write_gray16(tmp_path / "h.png", values)
    assert np.array_equal(pngio.read_gray16(tmp_path / "h.png"), values)


def test_height_encoding():
    encoded = terrain.encode(np.array([-20.0, 0.0, 12.345, 700.0]), -20.0, 0.01)
    assert encoded.tolist() == [0, 2000, 3234, 65535]


def test_fold_names():
    assert landmarks.fold("Hải Đăng Vũng Tàu") == "hai dang vung tau"


def test_curve_is_found():
    # East for 100 m, a quarter circle of radius 30 m to the north, then north for 100 m.
    angles = np.linspace(-math.pi / 2, 0, 12)
    arc = [(100 + 30 * math.cos(a), 30 + 30 * math.sin(a)) for a in angles]
    points = np.array([(0, 0)] + arc + [(130, 130)])
    curve = homestay.find_curve(points)
    assert curve is not None
    assert curve["turn_deg"] == pytest.approx(-90.0, abs=5.0)
    assert curve["heading_before"] == pytest.approx(90.0, abs=3.0)
    assert 90.0 <= curve["start_distance_m"] <= 110.0


def test_straight_road_has_no_curve():
    assert homestay.find_curve(np.array([(0, 0), (500, 0), (900, 100)])) is None


def test_grade_limit():
    profile = np.array([0.0, 0.0, 3.0, 3.0, 3.0])
    spacing = np.full(4, 2.0)
    limited = terrain.limit_grade(profile, spacing, 0.25)
    assert np.all(np.abs(np.diff(limited)) <= 0.5 + 0.01)
    assert limited.mean() == pytest.approx(profile.mean(), abs=0.01)


# The lunar calendar (D13): Tết (1/1), mid-autumn (15/8), and leap months.
LUNAR_DATES = [
    ((2019, 2, 5), (1, 1, False)), ((2020, 1, 25), (1, 1, False)), ((2021, 2, 12), (1, 1, False)),
    ((2022, 2, 1), (1, 1, False)), ((2023, 1, 22), (1, 1, False)), ((2024, 2, 10), (1, 1, False)),
    ((2025, 1, 29), (1, 1, False)), ((2026, 2, 17), (1, 1, False)), ((2027, 2, 6), (1, 1, False)),
    ((2024, 9, 17), (15, 8, False)), ((2025, 10, 6), (15, 8, False)), ((2023, 9, 29), (15, 8, False)),
    ((2023, 3, 22), (1, 2, True)), ((2020, 5, 23), (1, 4, True)), ((2025, 7, 25), (1, 6, True)),
    ((2025, 8, 23), (1, 7, False)), ((2026, 10, 24), (15, 9, False)), ((2000, 2, 5), (1, 1, False)),
    ((2033, 12, 22), (1, 11, True)), ((2024, 2, 9), (30, 12, False)),
]


@pytest.mark.parametrize("solar, expected", LUNAR_DATES)
def test_lunar_date(solar, expected):
    from geodata import lunar
    year, month, day = solar
    d, m, _y, leap = lunar.solar_to_lunar(day, month, year)
    assert (d, m, leap) == expected


def test_town_anchors():
    """A bus station, a market, a roundabout of two ways, and a junction of 5 arms (R6a)."""
    from types import SimpleNamespace as NS

    import numpy as np

    from geodata import anchors

    class Identity:
        def to_map(self, lon, lat):
            return np.asarray(lon, dtype=float), np.asarray(lat, dtype=float)

    def road(ref_list, points, kind="residential", name="A"):
        return NS(type=kind, refs=ref_list, node_points=np.array(points, dtype=float), name=name)

    data = NS(
        nodes=[NS(id=1, lon=0.0, lat=0.0, tags={"amenity": "bus_station", "name": "Bến xe"}),
               NS(id=2, lon=10.0, lat=0.0, tags={"amenity": "marketplace", "name": "Chợ"}),
               NS(id=50, lon=100.0, lat=100.0, tags={"junction": "yes", "name": "Ngã Năm"})],
        areas=[],
        ways=[NS(id=7, tags={"junction": "roundabout", "name": "Vòng xoay"}, refs=[20, 21, 22], coords=[(0, 50), (5, 55), (10, 50)]),
              NS(id=8, tags={"junction": "roundabout"}, refs=[22, 23, 20], coords=[(10, 50), (5, 45), (0, 50)])],
    )
    roads = [road([40, 50, 41], [(90, 100), (100, 100), (110, 100)]),
             road([42, 50, 43], [(100, 90), (100, 100), (100, 110)], name="B"),
             road([50, 44], [(100, 100), (120, 120)], name="C"),
             road([60, 61, 62], [(0, 0), (1, 1), (2, 2)])]
    found = anchors.find(data, Identity(), roads)
    kinds = [a["kind"] for a in found]
    assert kinds == ["bus_station", "marketplace", "roundabout", "junction"]
    assert found[2]["name"] == "Vòng xoay"
    assert found[3]["name"] == "Ngã Năm" and found[3]["osm"] == "node/50"
    assert [a["number"] for a in found] == [1, 2, 3, 4]
