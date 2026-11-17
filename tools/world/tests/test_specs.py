"""Tests of the specs of the models for World (docs/world-specs.md, plan 0026, D5)."""

import copy
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "photos"))

import photos  # noqa: E402
import specs  # noqa: E402

GOOD = {
    "id": "test_lamp",
    "what": "đèn thử, a test lamp",
    "uses": "a test",
    "year": 2019,
    "photos": [{"url": "https://example.org/p", "date": "2019-01", "license": "CC BY-SA 4.0", "author": "A",
                "open": True, "file": "test.jpg", "shows": "a lamp"}],
    "envelope": {"width": 1.0, "depth": 1.0, "height": 9.0, "tolerance": 0.2},
    "parts": [{"name": "pole", "shape": "cylinder", "sizes": {"height": 9.0, "diameter": 0.2},
               "at": [0, 0, 0], "role": "paint", "color": "#7FB4CF"}],
    "levels": {"near": 2000, "mid": 600, "far": 120},
    "checks": ["the height to the top is 9.0 m ± 0.2 m"],
    "status": {
        "envelope.width": {"status": "Source", "how": "the arm", "photos": [0]},
        "envelope.depth": {"status": "Source", "how": "the arm", "photos": [0]},
        "envelope.height": {"status": "Source", "how": "5.6 times a person", "photos": [0]},
        "parts.pole.sizes.height": {"status": "Source", "how": "5.6 times a person", "photos": [0]},
        "parts.pole.sizes.diameter": {"status": "Check", "how": "a guess"},
        "parts.pole.at": {"status": "Confirmed", "how": "the base point"},
        "parts.pole.color": {"status": "Source", "how": "the color of the pole in the photo", "photos": [0]},
    },
}


def test_the_specs_of_the_repository_have_no_problems():
    for path, spec in specs.load():
        assert specs.problems(spec, path.name) == [], path.name


def test_a_good_spec_has_no_problems():
    assert specs.problems(GOOD, "test_lamp.json") == []


def test_a_value_with_no_status_is_a_problem():
    spec = copy.deepcopy(GOOD)
    del spec["status"]["parts.pole.color"]
    assert any("parts.pole.color has no status" in p for p in specs.problems(spec))


def test_a_source_value_names_its_photo():
    spec = copy.deepcopy(GOOD)
    spec["status"]["parts.pole.color"] = {"status": "Source", "how": "the photo"}
    assert any("names no photo" in p for p in specs.problems(spec))
    spec["status"]["parts.pole.color"]["photos"] = [3]
    assert any("there is no photo 3" in p for p in specs.problems(spec))


def test_the_far_level_has_at_most_300_triangles():
    spec = copy.deepcopy(GOOD)
    spec["levels"]["far"] = 400
    assert any("far level" in p for p in specs.problems(spec))


def test_a_photo_that_nobody_looked_at_is_a_problem():
    spec = copy.deepcopy(GOOD)
    spec["photos"][0]["shows"] = "not looked at"
    assert any("nobody looked at it" in p for p in specs.problems(spec))


def test_an_nc_license_is_not_open():
    photo = {"url": "u", "date": "2019", "license": "CC BY-NC 2.0", "author": "A", "open": True, "file": "a.jpg",
             "shows": "x"}
    assert any("is not open" in p for p in photos.problems(photo))
    photo = {**photo, "license": "CC BY-SA 2.0"}
    assert photos.problems(photo) == []


def test_a_photo_that_is_not_open_has_no_copy():
    photo = {"url": "u", "date": "2019", "license": "all rights reserved", "author": "A", "open": False,
             "file": "a.jpg", "shows": "x"}
    assert any("cannot have a copy" in p for p in photos.problems(photo))


def test_commons_pages_become_thumbnails():
    url = photos.image_url({"url": "https://commons.wikimedia.org/wiki/File:A_b.jpg"})
    assert url == "https://commons.wikimedia.org/wiki/Special:FilePath/A_b.jpg?width=1920"
