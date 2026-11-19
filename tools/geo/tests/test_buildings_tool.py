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


def test_heights_by_year_needs_enough_pixels():
    rows = [["a", {"2019": [7.5, 40], "2021": [8.0, 3]}], ["b", {"2021": [12.0, 50]}]]
    heights = buildings.heights_by_year(rows)
    # Three pixels at the edge of the outline are not a building of 2021.
    assert heights == {"a": {2019: 7.5}, "b": {2021: 12.0}}


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
