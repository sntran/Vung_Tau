"""Unit tests for the parts of the pipeline (plan 0005, R17 and R18)."""

import math

import numpy as np
import pytest
import shapely
from shapely.geometry import LineString, Polygon

from geodata import blocks, coast, homestay, landmarks, osm, pngio, roads, sea, terrain
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


def _sea_grid(size=200, step=2.0, floor=-4.0):
    """A grid of sea at the height floor, from game (0, 0), with land at x < 20 m."""
    n = int(size / step) + 1
    grid = terrain.Grid(0.0, 0.0, step, np.full((n, n), floor, dtype=np.float32))
    cols = np.arange(n) * step
    land = np.broadcast_to(cols < 20.0, (n, n)).copy()
    grid.heights[land] = 2.0
    return grid, land


def test_rock_band():
    """R8h: the path is from top - rough to top, the band has outcrops and pools, and the land does not change."""
    grid, land = _sea_grid()
    # Map y is -game z: the band goes east along game z = 100.
    line = LineString([(10.0, -100.0), (180.0, -100.0)])
    band = line.buffer(15.0, cap_style="flat")
    before = grid.heights.copy()
    stats = terrain.make_rock_band(grid, land, line, band, -1.7, 4.0, 0.08, 0.35, -0.45)
    path = grid.sample(np.linspace(30, 170, 50), np.full(50, 100.0))
    assert path.max() <= -1.7 + 1e-3 and path.min() >= -1.7 - 0.08 - 0.02
    rows = slice(int(88 / 2), int(112 / 2))
    sides = grid.heights[rows, 15:85]
    assert sides.max() > -1.7 + 0.2, "outcrops rise above the path"
    assert sides.min() < -1.7 - 0.25, "tide pools go below the path"
    assert sides.max() <= -1.7 + 0.35 + 1e-3
    assert np.array_equal(grid.heights[land], before[land])
    assert grid.heights[int(150 / 2), 50] == pytest.approx(-4.0), "far from the band, the sea floor stays"
    assert stats["band_cells"] > 0 and stats["path_cells"] > 0


def test_sand_flat():
    """R8h: a sand flat at the height near the center, and the sea floor at the radius."""
    grid, land = _sea_grid()
    cells = terrain.make_sand_flat(grid, land, (60.0, -100.0), 60.0, -1.3)
    assert grid.sample(np.array([60.0]), np.array([100.0]))[0] == pytest.approx(-1.3)
    assert grid.sample(np.array([60.0]), np.array([165.0]))[0] == pytest.approx(-4.0)
    assert grid.heights[0, 0] == 2.0 and cells > 0


def test_roadworks_chain_starts_at_the_bottom():
    """R11a: two ways of a road join at a shared node, and the cut starts at the lowest end."""
    from types import SimpleNamespace as NS

    from geodata import roadworks

    def road(refs, points, heights):
        return NS(name="Hải Đăng", refs=refs, points=np.array(points, dtype=float), heights=heights, width=6.0)

    upper = road([2, 3], [(100, 0), (200, 0)], [10.0, 30.0])
    lower = road([2, 1], [(100, 0), (0, 0)], [10.0, 2.0])
    line = roadworks.chain([upper, lower])
    assert line[0].tolist() == [0.0, 0.0, 2.0] and line[-1].tolist() == [200.0, 0.0, 30.0]
    part = roadworks.cut(line, 150.0)
    assert part[-1][0] == pytest.approx(150.0) and part[-1][2] == pytest.approx(20.0)
    record, problems = roadworks.make({"road": "Hải Đăng", "from": "bottom", "length_m": 150, "widen_m": 3.0,
                                       "planned_end": "2027", "contractor": "X", "sign": "Y", "work_hours": {}},
                                      [upper, lower])
    assert not problems and record["width_m"] == 9.0 and record["length_m"] == pytest.approx(150.0)


def test_small_island_keeps_its_height():
    """The filter of the surface model makes a small hump flat, but not a small island (Hòn Bà)."""
    n = 101
    heights = np.full((n, n), 2.0, dtype=np.float32)
    heights[45:56, 45:56] = 12.0
    no_town = np.zeros((n, n), dtype=bool)
    grid = terrain.Grid(0.0, 0.0, 2.0, heights.copy())
    terrain.remove_buildings(grid, no_town)
    assert grid.heights[50, 50] == pytest.approx(2.0, abs=0.01), "low ground: the hump goes"
    grid = terrain.Grid(0.0, 0.0, 2.0, heights.copy())
    keep = np.zeros((n, n), dtype=bool)
    keep[40:61, 40:61] = True
    terrain.remove_buildings(grid, no_town, keep)
    assert grid.heights[50, 50] == pytest.approx(12.0), "the island keeps its height"


def test_outside_of_a_sharp_bend_is_flat():
    # A road with a bend of 90 degrees on a slope. The cells at the outside of
    # the bend are beside neither segment, and the road must be flat there too.
    cols, rows = 51, 51
    gx = np.arange(cols) * 2.0
    heights = np.tile((0.3 * gx).astype(np.float32), (rows, 1))
    grid = terrain.Grid(x0=0.0, z0=-100.0, step=2.0, heights=heights)
    road = _road(1, "residential", [(20.0, 20.0), (50.0, 50.0), (20.0, 80.0)], width=6.0)
    terrain.flatten_roads(grid, [road], 2.0)
    apex = grid.sample([50.0], [-50.0])[0]
    outside = grid.sample([52.5], [-50.0])[0]
    assert outside == pytest.approx(apex, abs=0.15)


def test_rock_coast_covers_the_tip_and_the_sea_in_front():
    """A rocky cape (report 0005, D-0005-03): the land near the point and the
    sea in front of it are rock, and the land far from the point is not."""
    box = Polygon([(-200, -200), (200, -200), (200, 200), (-200, 200)])
    # A cape: land at the east of x = 0, with a point that goes west to x = -50.
    cape = Polygon([(0, -200), (200, -200), (200, 200), (0, 200), (0, 20), (-50, 0), (0, -20)])
    land = cape.intersection(box)
    rock = coast.rock_coast_area(land, (-50.0, 0.0), 40.0, 15.0)
    assert rock.contains(Polygon([(-45, -1), (-40, -1), (-40, 1), (-45, 1)])), "the tip is rock"
    assert rock.contains(Polygon([(-60, -1), (-58, -1), (-58, 1), (-60, 1)])), "the sea in front of the tip is rock"
    assert not rock.intersects(Polygon([(100, -5), (110, -5), (110, 5), (100, 5)])), "the land far away is not rock"
    assert coast.rock_coast_area(land, (-150.0, 150.0), 20.0, 10.0).is_empty, "no land near the point"


def test_rock_coast_correction():
    data = osm.OsmData()
    osm.apply_corrections(data, [{"action": "rock_coast", "name": "Mũi", "lon": 107.08, "lat": 10.32,
                                  "radius_m": 150, "sea_m": 30, "reason": "a rocky cape"},
                                 {"action": "rock_coast", "lon": 107.0, "lat": 10.0, "radius_m": 1, "sea_m": 1}])
    assert len(data.rock_coasts) == 1 and data.rock_coasts[0]["radius_m"] == 150
    assert len(data.problems) == 1, "a correction without a reason is not used"


def test_island_boulders_are_large():
    """The small islands have large boulders, not only small bumps (report 0005, D-0005-05)."""
    n = 121
    heights = np.full((n, n), 8.0, dtype=np.float32)
    grid = terrain.Grid(0.0, 0.0, 2.0, heights.copy())
    island = np.zeros((n, n), dtype=bool)
    island[10:111, 10:111] = True
    cells = terrain.roughen_islands(grid, island)
    assert cells > 0
    inside = grid.heights[10:111, 10:111] - 8.0
    assert inside.max() > terrain.ISLAND_BOULDER_M * 0.8, "boulders rise more than a meter"
    assert inside.min() > -terrain.ISLAND_BOULDER_M, "the gaps are not deep holes"
    assert np.all(grid.heights[0:5, :] == 8.0), "the ground outside the island does not change"


def test_coast_band_is_the_sea_along_the_coast_between_two_points():
    """The flat rocks along the sea wall (plan 0005, Q6)."""
    land = Polygon([(0, -200), (200, -200), (200, 200), (0, 200)])
    band = coast.coast_band(land, (-5.0, -50.0), (-5.0, 50.0), 20.0)
    assert not band.intersects(Polygon([(1, -1), (5, -1), (5, 1), (1, 1)])), "no land in the band"
    assert band.contains(Polygon([(-15, -1), (-10, -1), (-10, 1), (-15, 1)])), "the sea in front of the coast"
    assert not band.intersects(Polygon([(-15, 100), (-10, 100), (-10, 105), (-15, 105)])), "not past the end point"
    assert band.bounds[0] == pytest.approx(-20.0, abs=0.5)


def test_rock_shelf_is_flat_at_its_height():
    n = 51
    heights = np.full((n, n), -3.0, dtype=np.float32)
    grid = terrain.Grid(0.0, 0.0, 2.0, heights)
    land = np.zeros((n, n), dtype=bool)
    land[:, 40:] = True
    band = np.zeros((n, n), dtype=bool)
    band[10:30, 30:45] = True
    cells = terrain.make_rock_shelf(grid, land, band, -1.0, 0.15)
    assert cells == 20 * 10
    assert np.all(np.abs(grid.heights[10:30, 30:40] + 1.0) <= 0.15 + 1e-6)
    assert np.all(grid.heights[10:30, 40:45] == -3.0), "the land does not change"
    assert np.all(grid.heights[0:10, :] == -3.0)


def test_boats_keep_away_from_the_beach_and_thung_and_stakes():
    """Plan 0005, Q6: boats at least 100 m from the main beach, thúng near the
    sand and beside the boats, and rows of stakes that go away from the coast."""
    projection = Projection.at(107.0, 10.0, 10)
    land = Polygon([(0, -2000), (2000, -2000), (2000, 2000), (0, 2000)])
    beach = Polygon([(0, -200), (40, -200), (40, 200), (0, 200)])

    def ll(x, y):
        lon, lat = projection.map_to_lonlat(x, y)
        return [float(lon), float(lat)]

    square = lambda x0, y0, x1, y1: [ll(x0, y0), ll(x1, y0), ll(x1, y1), ll(x0, y1), ll(x0, y0)]
    spec = {"seed": 3,
            "cargo_ships": {"count": 0, "length_m": [100, 200], "kinds": ["bulk"], "min_spacing_m": 100,
                            "min_floor_m": -3.0, "areas": [{"name": "far", "polygon": square(-3000, -500, -2000, 500)}]},
            "fishing_boats": {"count": 20, "length_m": [8, 12], "min_spacing_m": 10, "min_floor_m": -1.0,
                              "areas": [{"name": "bay", "share": 1.0, "away_from_beach": {"name": "Main", "m": 100},
                                         "polygon": square(-300, -150, -1, 150)}]},
            "basket_boats": {"diameter_m": [1.8, 2.2], "min_spacing_m": 4, "tied_areas": ["bay"], "tied_share": 0.5,
                             "near_sand": [{"name": "sand", "count": 3, "min_floor_m": 0.0,
                                            "polygon": square(-30, -20, -1, 20)}]},
            "fishing_stakes": {"height_m": 1.8, "spacing_m": 2.0, "row_length_m": [30, 40], "min_row_spacing_m": 50,
                               "min_from_coast_m": 20, "max_floor_m": -1.0,
                               "areas": [{"name": "off", "rows": 3, "polygon": square(-200, 500, -30, 900)}]},
            "ferry_pier": {"name": "P", "osm_ways": [], "width_m": 6, "deck_m": 2.8},
            "groynes": {"tags": [["man_made", "groyne"]], "width_m": 4, "height_m": 1.6}}
    floor_at = lambda x, y: max(-4.0, x * 0.05)
    record, problems = sea.make(spec, [], projection, land, floor_at, [("Main", beach)])
    boats = record["fishing_boats"]
    assert len(boats) == 20 and not problems
    for boat in boats:
        x, z = boat["position"]
        assert beach.distance(shapely.Point(x, -z)) >= 100.0 - 0.5, "100 m or more from the beach"
        assert boat["floor_m"] <= -1.0
    baskets = record["basket_boats"]
    assert sum(1 for b in baskets if b["tied_to"] < 0) == 3
    assert any(b["tied_to"] >= 0 for b in baskets), "some thúng are tied beside the boats"
    rows = record["fishing_stakes"]["rows"]
    assert len(rows) == 3
    for row in rows:
        first, last = row["stakes"][0], row["stakes"][-1]
        assert last[0] < first[0], "the row goes away from the coast (west)"
        assert all(p[2] <= 0.0 for p in row["stakes"])


def test_intertidal_height_is_the_sea_level_where_the_pixel_becomes_wet():
    """R8g, R18: made-up images and tide levels. A pixel at the height e is wet
    when the sea is above e. Clouds hide some images. The method finds e."""
    from geodata import intertidal
    rng = np.random.default_rng(4)
    tides = rng.uniform(-2.2, 1.4, 120)
    truth = np.array([-1.5, -0.4, 0.3, 0.9, 5.0, -9.0])  # the last two are always dry and always wet
    observations = np.where(tides[:, None] > truth[None, :], intertidal.WET, intertidal.DRY).astype(np.int8)
    observations[rng.uniform(size=observations.shape) < 0.3] = intertidal.UNCLEAR  # clouds
    # Some wrong observations (a wave, a wet sand).
    wrong = rng.uniform(size=observations.shape) < 0.04
    observations[wrong & (observations != intertidal.UNCLEAR)] ^= 1
    heights, clear = intertidal.elevations(tides, observations)
    assert np.all(clear > 60)
    assert np.allclose(heights[:4], truth[:4], atol=0.12), heights
    assert np.isnan(heights[4]) and np.isnan(heights[5]), "no value above the highest or below the lowest tide"
    few = observations.copy()
    few[:-10, 0] = intertidal.UNCLEAR
    assert np.isnan(intertidal.elevations(tides, few)[0][0]), "too few clear images"


def test_intertidal_observation_and_clouds():
    from geodata import intertidal
    green = np.array([[1000, 1000, 1000]], dtype=np.uint16)
    nir = np.array([[200, 3000, 200]], dtype=np.uint16)
    scl = np.array([[6, 4, 9]], dtype=np.uint8)  # water, vegetation, cloud
    assert intertidal.observe(green, nir, scl).tolist() == [[intertidal.WET, intertidal.DRY, intertidal.UNCLEAR]]


def test_sea_floor_from_data():
    """R8g: the intertidal heights near the coast, then a smooth slope down to the GEBCO depth."""
    n = 400
    grid = terrain.Grid(0.0, 0.0, 2.0, np.zeros((n, n), dtype=np.float32))
    land = np.zeros((n, n), dtype=bool)
    land[:, :20] = True
    terrain.shape_coast(grid, land, np.zeros((n, n), dtype=bool))
    intertidal = np.full((n, n), np.nan, dtype=np.float32)
    intertidal[:, 20:120] = -1.6  # a flat to 200 m from the coast
    gebco = np.full((n, n), -8.0, dtype=np.float32)
    stats = terrain.sea_floor_from_data(grid, land, intertidal, gebco)
    assert stats["intertidal_cells"] == n * 100
    row = grid.heights[200]
    assert row[60] == pytest.approx(-1.6, abs=0.05), "the flat of the intertidal zone"
    assert row[300] < -6.0, "far out, the GEBCO depth"
    assert np.all(np.diff(row[120:400]) <= 1e-4), "the floor goes down from the low-tide edge"
    assert np.all(grid.heights[:, :20] >= terrain.LAND_MIN_HEIGHT), "the land does not change"
    step = np.abs(np.diff(grid.heights[200, 15:40]))
    assert step.max() <= terrain.COAST_RAMP * grid.step + 0.05, "no step at the coastline"


def test_sea_floor_ignores_far_spots_and_shallow_gebco():
    """A boat at anchor looks dry in some images: a spot far out makes no shoal.
    GEBCO near the coast has the land in its cells: it does not make the floor shallow."""
    n = 400
    grid = terrain.Grid(0.0, 0.0, 2.0, np.zeros((n, n), dtype=np.float32))
    land = np.zeros((n, n), dtype=bool)
    land[:, :20] = True
    terrain.shape_coast(grid, land, np.zeros((n, n), dtype=bool))
    intertidal = np.full((n, n), np.nan, dtype=np.float32)
    intertidal[200:204, 250:254] = -1.0  # a boat 460 m out
    gebco = np.full((n, n), -1.0, dtype=np.float32)
    stats = terrain.sea_floor_from_data(grid, land, intertidal, gebco)
    assert stats["intertidal_cells"] == 0
    assert grid.heights[202, 252] <= -terrain.SEA_FLOOR_DEPTH + 0.01, "no shoal at the boat"


def test_sea_floor_keeps_the_rock_band():
    """Q14: the rock band of Hòn Bà keeps its own heights in the floor from data."""
    n = 200
    grid = terrain.Grid(0.0, 0.0, 2.0, np.zeros((n, n), dtype=np.float32))
    land = np.zeros((n, n), dtype=bool)
    land[:, :10] = True
    terrain.shape_coast(grid, land, np.zeros((n, n), dtype=bool))
    keep = np.zeros((n, n), dtype=bool)
    keep[90:110, 40:60] = True
    grid.heights[keep] = -1.7
    intertidal = np.full((n, n), -0.5, dtype=np.float32)
    terrain.sea_floor_from_data(grid, land, intertidal, None, keep)
    assert np.allclose(grid.heights[keep], -1.7), "the band keeps its heights"
    assert grid.heights[20, 50] == pytest.approx(-0.5, abs=0.05), "the data elsewhere"
