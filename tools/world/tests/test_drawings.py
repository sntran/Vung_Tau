"""Tests of the models that this game makes with the tools of World (docs/world-models.md, plan 0026, D5)."""

import copy
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "photos"))

import drawings  # noqa: E402
import photos  # noqa: E402

GOOD = {
    "id": "test_lamp",
    "what": "đèn thử, a test lamp",
    "way": "drawing",
    "status": "Source",
    "levels": ["mid", "far"],
    "impostor": False,
    "uses": "a test",
    "order": {"blueprint": "drawing", "options": {"drawing": {"name": "test_lamp", "kind": "prop", "nodes": []}}},
    "sources": [{"url": "https://example.org/p", "date": "2019-01", "license": "all rights reserved", "author": "A",
                 "open": False, "file": "test.jpg", "shows": "a lamp"}],
    "sizes": {"height": {"value": 0.7, "unit": "m", "source": "58 px against a woman of 131 px (1.58 m)"},
              "foot": {"value": 0.06, "unit": "m", "source": drawings.ESTIMATE}},
    "looks": [],
}


def test_the_drawings_of_the_repository_have_no_problems():
    for model_id in drawings.all_ids():
        assert drawings.problems(drawings.load(model_id), model_id) == [], model_id


def test_the_orders_of_the_drawings_are_in_the_orders_of_the_game():
    assert drawings.order_problems(drawings.all_ids()) == []


def test_a_good_drawing_has_no_problems():
    assert drawings.problems(GOOD, "test_lamp") == []


def test_a_size_with_no_source_is_a_problem():
    bad = copy.deepcopy(GOOD)
    bad["sizes"]["height"]["source"] = ""
    assert any("sizes.height" in p for p in drawings.problems(bad, "test_lamp"))


def test_a_model_with_no_photo_is_check():
    bad = copy.deepcopy(GOOD)
    bad["sources"] = []
    assert any("no photo" in p for p in drawings.problems(bad, "test_lamp"))
    bad["status"] = "Check"
    assert drawings.problems(bad, "test_lamp") == []


def test_an_open_photo_has_its_copy():
    bad = copy.deepcopy(GOOD)
    bad["sources"][0].update({"license": "CC BY 4.0", "open": True, "file": "no_such_photo.jpg"})
    assert any("docs/reference/photos/no_such_photo.jpg" in p for p in drawings.problems(bad, "test_lamp"))


def test_an_order_of_a_blueprint_in_data_has_the_blueprint_in_it():
    drawing = copy.deepcopy(GOOD)
    drawing["way"] = "blueprint"
    drawing["order"] = {"blueprint": {"file": "data/world/blueprints/den_cong_vien.json"}, "options": {"kind": "den_cau"}}
    assert drawings.problems(drawing, "test_lamp") == []
    order = drawings.full_order(drawing)
    assert order["blueprint"]["name"] == "den_cong_vien"
    assert order["options"] == {"kind": "den_cau"}
    drawing["order"]["blueprint"] = {"file": "data/world/blueprints/no_such.json"}
    assert any("names its file" in p for p in drawings.problems(drawing, "test_lamp"))


def test_the_photos_of_the_drawings_have_no_problems():
    for photo in photos.photos():
        assert photos.problems(photo) == [], photo.get("url")


def test_an_nc_license_is_not_open():
    photo = {"url": "u", "date": "2019", "license": "CC BY-NC 2.0", "author": "a", "open": True, "file": "f.jpg", "shows": "s"}
    assert any("is not open" in p for p in photos.problems(photo))
    photo["license"] = "CC BY-SA 2.0"
    assert photos.problems(photo) == []


def test_a_photo_that_is_not_open_has_no_copy_in_the_repository():
    photo = {"url": "u", "date": "2019", "license": "all rights reserved", "author": "a", "open": False,
             "file": "CREDITS.md", "shows": "s"}
    assert any("cannot have a copy" in p for p in photos.problems(photo))
    photo["file"] = "a_name_for_the_folder_of_other_photos.jpg"
    assert photos.problems(photo) == []


def test_a_photo_that_nobody_looked_at_is_a_problem():
    photo = {"url": "u", "date": "2019", "license": "all rights reserved", "author": "a", "open": False, "shows": "not looked at"}
    assert any("looked at" in p for p in photos.problems(photo))


def test_commons_pages_become_thumbnails():
    url = photos.image_url({"url": "https://commons.wikimedia.org/wiki/File:A_b.jpg"})
    assert url.startswith("https://commons.wikimedia.org/wiki/Special:FilePath/A_b.jpg?width=")
