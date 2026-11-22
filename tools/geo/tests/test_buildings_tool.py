"""Unit tests for the parts of tools/geo/buildings.py with no network (plan 0009, R1 and R5d)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import buildings  # noqa: E402


def test_utm_zone_of_vung_tau():
    assert buildings.utm_epsg({"west": 107.05, "east": 107.13, "south": 10.3, "north": 10.42}) == 32648


def test_manifest_tiles_join_the_prefix_and_keep_the_tiles_of_the_area():
    manifest = {
        "uriPrefix": "gs://open-buildings-temporal-data/v1/geotiffs/31",
        "tilesets": [{"sources": [
            {"uris": ["754_2019_06_30/tile_a.tif"],
             "affineTransform": {"scaleX": 0.5, "translateX": 1000.0, "scaleY": -0.5, "translateY": 2000.0},
             "dimensions": {"width": 1000, "height": 1000}},
            {"uris": ["754_2019_06_30/tile_far.tif"],
             "affineTransform": {"scaleX": 0.5, "translateX": 9000.0, "scaleY": -0.5, "translateY": 2000.0},
             "dimensions": {"width": 1000, "height": 1000}},
        ]}],
    }
    tiles = buildings.manifest_tiles(manifest, (1200.0, 1600.0, 1300.0, 1700.0))
    # The prefix and the uri with no "/" between them (the folder of the S2 cell 31754).
    assert tiles == [("v1/geotiffs/31754_2019_06_30/tile_a.tif", (1000.0, 1500.0, 1500.0, 2000.0))]


def test_medians_by_label():
    found = buildings.medians_by_label([2, 0, 2, 2, 0], [9.0, 3.0, 6.0, 30.0, 5.0])
    assert found == {0: (4.0, 2), 2: (9.0, 3)}
    assert buildings.medians_by_label([], []) == {}


def test_the_first_year_needs_a_part_of_the_area_and_the_height_is_the_median_of_the_years():
    # An outline of 100 m² (400 pixels): a year needs 30 % of it, 120 pixels.
    years = {"2016": [5.5, 40], "2017": [4.0, 150], "2018": [4.5, 300], "2019": [5.0, 310], "2020": [6.0, 3]}
    first, height, rule = buildings.first_and_height(years, 100.0)
    # 2016 has only the edge of the next house; 2020 has 3 pixels (no data).
    assert (first, height, rule) == (2017, 4.5, "part")
    # A small outline of 5 m² (20 pixels, 30 % is 6): at least 8 pixels.
    assert buildings.first_and_height({"2021": [7.0, 9]}, 5.0) == (2021, 7.0, "part")


# Report 0009, D-0009-08: 7 904 buildings of 2019 had no first year (no year
# with 30 % of the outline), and 7 902 of them no height. One test for each kind.

def test_no_year_with_a_part_takes_the_first_year_with_8_pixels_up_to_2019():
    # An outline of 200 m² (800 pixels, 30 % is 240): no year has 240 pixels.
    years = {"2016": [3.0, 5], "2017": [6.0, 60], "2018": [5.0, 90], "2019": [7.0, 100], "2020": [6.5, 120]}
    first, height, rule = buildings.first_and_height(years, 200.0)
    assert (first, rule) == (2017, "pixels")
    # The median of 2017 to 2020 (2016 has fewer than 8 pixels).
    assert height == 6.2
    assert height is not None


def test_no_year_with_a_part_and_8_pixels_only_after_2019_is_out():
    years = {"2018": [4.0, 6], "2019": [4.0, 7], "2021": [9.0, 30], "2022": [9.5, 40]}
    first, height, rule = buildings.first_and_height(years, 200.0)
    assert (first, height, rule) == (2021, 9.2, "pixels")
    assert first > 2019


def test_fewer_than_8_pixels_in_each_year_is_not_seen():
    assert buildings.first_and_height({"2018": [4.0, 7], "2019": [4.0, 5]}, 30.0) == (None, None, None)
    assert buildings.first_and_height({}, 30.0) == (None, None, None)


def test_the_buildings_of_each_kind_go_to_their_lists():
    rows = [("a", [], 0.0, None, [0, 0, 20, 0, 20, 10, 0, 10]),   # 200 m²
            ("b", [], 0.0, None, [0, 0, 20, 0, 20, 10, 0, 10]),
            ("c", [], 0.0, None, [0, 0, 20, 0, 20, 10, 0, 10]),
            ("d", [], 5.0, None, [0, 0, 6, 0, 6, 5, 0, 5])]        # 30 m²
    years_of = {"a": {"2017": [6.0, 300]}, "b": {"2018": [5.0, 50]}, "c": {"2022": [8.0, 40]}, "d": {"2019": [4.0, 6]}}
    kept, out, unseen, counts = buildings.sort_buildings(rows, years_of)
    assert [i["id"] for i in kept] == ["a", "b"]
    assert [i["id"] for i in out] == ["c"]
    assert [i["id"] for i in unseen] == ["d"]
    assert all(i["height"] is not None for i in kept + out)
    assert unseen[0]["status"] == "Check"
    assert counts == {"part_2019": 1, "part_after_2019": 0, "pixels_2019": 1, "pixels_after_2019": 1, "unseen": 1}


def test_the_groups_with_no_outline_are_far_from_the_outlines_and_large():
    import numpy as np
    building = np.zeros((8, 8), dtype=bool)
    distance = np.full((8, 8), 10.0)
    building[0:2, 0:2] = True  # a group of 4 cells, far from each outline
    building[5, 5:8] = True  # a group of 3 cells: too small
    building[0:3, 6] = True  # a band along an outline: 1 m from it
    distance[0:3, 6] = 1.0
    groups = buildings.groups_of_cells(building, distance)
    assert [len(g) for g in groups] == [4]


def test_osm_rows_keep_the_versions_of_the_day():
    features = [
        {"properties": {"@osmId": "way/1", "@validFrom": "2019-01-22T00:00:00Z", "@validTo": "2019-01-23T00:00:00Z"}},
        {"properties": {"@osmId": "way/2", "@validFrom": "2019-01-22T15:00:00Z", "@validTo": "2019-01-23T00:00:00Z"}},
    ]
    # way/2 was made in the afternoon: it was not there on the morning of 2019-01-22.
    assert [f["properties"]["@osmId"] for f in buildings.osm_rows(features, "2019-01-22T00:00")] == ["way/1"]


def test_lidar_year_spans():
    import lidar
    assert lidar.year_spans("2018-10-14T00:00:00Z", "2020-03-01T00:00:00Z") == [
        ("2018-10-14T00:00:00Z", "2019-01-01T00:00:00Z"),
        ("2019-01-01T00:00:00Z", "2020-01-01T00:00:00Z"),
        ("2020-01-01T00:00:00Z", "2020-03-01T00:00:00Z"),
    ]


def test_best_shift_finds_the_offset_of_the_raster():
    import numpy as np
    labels = np.zeros((40, 40), dtype=np.uint8)
    labels[10:20, 10:18] = 1
    sure = np.zeros((40, 40), dtype=bool)
    # The building of the raster is 6 pixels (3 m) south and 2 pixels east of its outline.
    sure[16:26, 12:20] = True
    assert buildings.best_shift(sure, labels, 8) == (6, 2, 1.0)


def test_the_roof_photons_of_clouds_are_out_of_the_check():
    # D-0009-11: 5 photons at 758 m over a roof of 6 m (2025-08-30) made the
    # RMSE of the roof photons 17.55 m.
    height_of = {"a": 6.0, "b": 9.0}
    photons = {"a": [758.0] * 5 + [5.5, 6.2, 5.9], "b": [8.0, 8.5, 9.1]}
    low, towers, out = buildings.roof_differences(photons, height_of)
    assert out == 5
    assert towers == []
    assert sorted(round(d, 2) for d in low) == [0.1, 0.5]


def test_an_outline_with_only_photons_of_clouds_has_no_difference():
    low, towers, out = buildings.roof_differences({"a": [758.0] * 5}, {"a": 6.0})
    assert (low, towers, out) == ([], [], 5)


def test_the_towers_have_a_row_of_their_own():
    height_of = {"house": 12.0, "tower": 75.0}
    photons = {"house": [11.0, 12.0, 13.0], "tower": [20.0, 22.0, 24.0]}
    low, towers, _out = buildings.roof_differences(photons, height_of)
    assert low == [0.0]
    assert towers == [53.0]


def test_the_check_rows_give_the_median_absolute_difference():
    row = buildings.stats_line("x", [1.0, -3.0, 2.0])
    cells = [c.strip() for c in row.split("|")[1:-1]]
    assert cells[:6] == ["x", "3", "+0.00", "+1.00", "2.00", "2.16"]


def test_the_roof_photons_are_of_a_high_signal_confidence():
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    import lidar
    assert lidar.parms_for("atl03_roof", "2025-01-01T00:00:00Z", "2026-01-01T00:00:00Z")["cnf"] == 4


def test_a_group_of_cells_touches_a_street_near_the_edge_of_its_surface():
    """Report 0009, D-0009-22: a group of the raster with no outline gets a box
    when it is at most STREET_TOUCH_M from the edge of a street; an alley or a
    footway is not a street."""
    import shapely
    roads = [{"type": "residential", "width": 8.0, "points": [[0.0, 0.0, 0.0], [100.0, 0.0, 0.0]]},
             {"type": "footway", "width": 2.0, "points": [[0.0, 0.0, 50.0], [100.0, 0.0, 50.0]]}]
    streets = buildings.street_lines(roads)
    assert len(streets) == 1
    cell = 5.0
    center_of = {(0, 0): (50.0, 4.0 + buildings.STREET_TOUCH_M + 2.5 - 0.5), (0, 1): (55.0, 4.0 + buildings.STREET_TOUCH_M + 2.5 - 0.5)}
    near = buildings.group_polygon([(0, 0), (0, 1)], center_of, cell)
    assert near.area == 50.0
    assert buildings.touches_street(near, streets)
    far = shapely.box(40.0, 30.0, 50.0, 40.0)
    assert not buildings.touches_street(far, streets)
    on_footway = shapely.box(40.0, 52.0, 50.0, 57.0)
    assert not buildings.touches_street(on_footway, streets)


def test_the_street_fronts_count_each_point_once_by_its_kind():
    """Report 0009, D-0009-22: each 5 m, each side, the first kind in the band of 2 m to 14 m past the edge."""
    import shapely
    roads = [{"name": "A", "type": "residential", "width": 6.0, "points": [[0.0, 0.0, 0.0], [100.0, 0.0, 0.0]]}]
    box = [shapely.box(0.0, 5.0, 50.0, 15.0)]  # north side, first half
    raster_box = [shapely.box(50.0, 5.0, 100.0, 15.0)]  # north side, second half
    cells = [shapely.box(0.0, -15.0, 30.0, -5.0)]  # south side, first 30 m
    fronts = buildings.street_fronts(roads, ["A"], box, raster_box, cells)["A"]
    assert fronts == {"box": 10, "raster_box": 10, "raster_cell": 6, "none": 14}
    table = "\n".join(buildings.fronts_table({"A": fronts}))
    assert "| A | 40 | 25 % | 40 % | 35 % | 50 % | 15 % | 35 % |" in table


def test_a_box_of_the_raster_is_not_on_a_road():
    """Report 0009, D-0009-22: the part of a group on the surface of a road goes."""
    import shapely
    roads = [{"type": "residential", "width": 8.0, "points": [[0.0, 0.0, 0.0], [100.0, 0.0, 0.0]]}]
    surfaces = buildings.road_surfaces(roads)
    group = shapely.box(40.0, 2.0, 60.0, 14.0)  # 2 m on the road (its edge at 4 m)
    rest = buildings.off_roads(group, surfaces)
    assert rest.bounds[1] == 4.0 and rest.area == 200.0
    assert buildings.off_roads(shapely.box(40.0, -3.0, 60.0, 3.0), surfaces) is None
