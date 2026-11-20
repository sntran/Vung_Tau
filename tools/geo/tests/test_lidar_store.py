"""Unit tests for the store of the lidar (report 0009, D-0009-01 and D-0009-06)."""

import sys
import types
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import geostore  # noqa: E402
import lidar  # noqa: E402


@pytest.fixture
def store(tmp_path, monkeypatch):
    """The store and the manifest in a temporary folder."""
    monkeypatch.setattr(geostore, "CACHE", tmp_path / "cache")
    monkeypatch.setattr(geostore, "UPLOAD", tmp_path / "upload")
    monkeypatch.setattr(lidar, "MANIFEST", tmp_path / "manifest.json")
    monkeypatch.setattr(lidar, "egm2008", lambda lon, lat, h: h)
    return tmp_path


def frame_of(count: int, year: int) -> pd.DataFrame:
    times = pd.to_datetime([f"{year}-03-0{1 + i % 9}" for i in range(count)])
    return pd.DataFrame({"longitude": np.full(count, 107.08), "latitude": np.full(count, 10.35),
                         "h_ph": np.arange(count, dtype=float), "atl08_class": np.ones(count)}, index=times)


def fake_sliderule(rows_of_year: dict, failed: set) -> types.ModuleType:
    """A module in the place of sliderule: run() gives rows_of_year[year] rows, and raises for a year in failed."""
    module = types.ModuleType("sliderule")

    def run(_call, parms):
        year = int(parms["t0"][:4])
        if year in failed:
            raise TimeoutError("timed-out after 600 seconds waiting for endpoint proxy")
        return frame_of(rows_of_year.get(year, 0), year)
    module.run = run
    module.init = lambda **_kw: None
    module.icesat2 = types.ModuleType("sliderule.icesat2")
    module.gedi = types.ModuleType("sliderule.gedi")
    return module


def run_fetch(monkeypatch, rows_of_year, failed, allow_fewer=False, refetch=False):
    module = fake_sliderule(rows_of_year, failed)
    monkeypatch.setitem(sys.modules, "sliderule", module)
    monkeypatch.setitem(sys.modules, "sliderule.icesat2", module.icesat2)
    monkeypatch.setitem(sys.modules, "sliderule.gedi", module.gedi)
    monkeypatch.setattr(lidar, "PRODUCTS", {"atl03_ground": [("run", "atl03x")]})
    lines = []
    errors = lidar.fetch(lines, allow_fewer, refetch)
    return errors, lines


def test_a_fetch_with_one_failed_year_keeps_the_rows_of_that_year(store, monkeypatch):
    errors, _ = run_fetch(monkeypatch, {2019: 5, 2020: 7, 2021: 3}, failed=set())
    assert errors == []
    first = geostore.load(lidar.MANIFEST)
    assert lidar.by_year(first, "atl03_ground")[2021] == 3
    # The second run asks for all the years again: 2021 fails, and the others give more rows.
    errors, lines = run_fetch(monkeypatch, {2019: 6, 2020: 8}, failed={2021}, refetch=True)
    assert errors == []
    second = geostore.load(lidar.MANIFEST)
    assert lidar.by_year(second, "atl03_ground")[2021] == 3
    assert second["files"]["atl03_ground/2021"]["sha256"] == first["files"]["atl03_ground/2021"]["sha256"]
    assert lidar.by_year(second, "atl03_ground")[2019] == 6
    assert any("2021" in line and "stays" in line for line in lines)
    assert len(geostore.get(second, "atl03_ground/2021")["points"]) == 3


def test_a_year_with_0_rows_where_the_last_run_had_rows_is_an_error(store, monkeypatch):
    run_fetch(monkeypatch, {2019: 5, 2020: 7}, failed=set())
    errors, _ = run_fetch(monkeypatch, {2019: 5, 2020: 0}, failed=set(), refetch=True)
    assert errors and "2020" in errors[0]
    # The job does not commit: the manifest on disk is the one of the first run.
    assert lidar.by_year(geostore.load(lidar.MANIFEST), "atl03_ground")[2020] == 7


def test_a_product_with_fewer_points_fails_unless_a_person_allows_it():
    assert lidar.decide(7, 4) == "keep"
    assert lidar.decide(7, 4, allow_fewer=True) == "write"
    assert lidar.decide(7, None) == "keep"
    assert lidar.decide(None, 0) == "keep"
    assert lidar.decide(7, 0) == "error"
    assert lidar.decide(None, 3) == "write"


def test_only_the_missing_years_and_the_current_year_are_fetched():
    assert lidar.needs_fetch(None, 2019, 2026, False)
    assert not lidar.needs_fetch(5, 2019, 2026, False)
    assert lidar.needs_fetch(5, 2026, 2026, False)
    assert lidar.needs_fetch(5, 2019, 2026, True)


def test_the_store_checks_the_sha256(store):
    manifest = {"files": {}}
    geostore.put(manifest, "x/2019", {"points": [[1, 2]]}, rows=1)
    assert geostore.get(manifest, "x/2019")["points"] == [[1, 2]]
    manifest["files"]["x/2019"]["sha256"] = "0" * 64
    (geostore.CACHE / manifest["files"]["x/2019"]["name"]).write_bytes(b"other")
    with pytest.raises(Exception):
        geostore.get(manifest, "x/2019", tries=1)


def test_the_short_form_bins_each_beam_along_its_track():
    points = []
    for beam_x in (0.0, 90.0):  # two beams 90 m apart
        for k in range(100):  # one photon every 0.5 m along the track (north)
            points.append(("2019-03-01", beam_x, k * 0.5, 10.0 + k * 0.01, "ground"))
    points += [("2019-03-01", 0.0, 5.0, 16.0, "roof"), ("2019-03-01", 0.0, 6.0, 18.0, "roof")]
    bins = lidar.track_bins(points)
    # 50 m of track from -25 m to +25 m round its middle: four bins of 20 m, for each of the two beams.
    assert len(bins) == 8
    assert sorted({b["x"] for b in bins}) == [0.0, 90.0]
    roofed = [b for b in bins if b["roof_count"]]
    assert len(roofed) == 1 and roofed[0]["roof"] == 17.0 and roofed[0]["ground_count"] > 0


def test_the_grid_of_dtu_is_read_from_north_to_south(tmp_path):
    import gzip
    # south 10, north 11, west 107, east 108, steps 0.5: three rows (11, 10.5, 10) of three values.
    text = "10 11 107 108 0.5 0.5\n" + "1 2 3\n4 5 6\n7 8 9\n"
    path = tmp_path / "grid.grd.gz"
    path.write_bytes(gzip.compress(text.encode()))
    at = lidar.gravsoft(path)
    assert at(107.0, 11.0) == pytest.approx(1.0)
    assert at(108.0 - 1e-9, 10.0 + 1e-9) == pytest.approx(9.0, abs=1e-6)
    assert at(107.25, 10.75) == pytest.approx(3.0)
