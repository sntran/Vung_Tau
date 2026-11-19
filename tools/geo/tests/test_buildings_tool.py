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
    first, height = buildings.first_and_height(years, 100.0)
    # 2016 has only the edge of the next house; 2020 has 3 pixels (no data).
    assert first == 2017
    assert height == 4.5
    # A small outline of 5 m² (20 pixels, 30 % is 6): at least 8 pixels.
    assert buildings.first_and_height({"2021": [7.0, 9]}, 5.0) == (2021, 7.0)
    assert buildings.first_and_height({"2021": [7.0, 7]}, 5.0) == (None, None)


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
