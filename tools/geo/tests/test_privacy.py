"""Tests for privacy.py, the privacy step of the street photos (report 0026, D-0026-39). No network."""

import json
from pathlib import Path

import pytest

import privacy

ROOT = Path(__file__).resolve().parents[3]
SHEETS = ROOT / "docs" / "reference" / "mapillary"
# A box that a person can read has a sharpness of about 1 000 to 7 000 on the
# sheets; a blurred box is under 50.
BLURRED = 150.0


def test_each_box_of_the_list_is_blurred_on_its_sheets():
    from PIL import Image
    listed = json.loads(privacy.LIST.read_text(encoding="utf-8"))["images"]
    where = privacy.tiles_of_ids(SHEETS / "CREDITS.md")
    points = [p["id"] for p in json.loads((ROOT / "data" / "showcase" / "photo_points.json").read_text())["points"]]
    found = []
    for image_id, entry in listed.items():
        for sheet_name, k in where.get(image_id, []):
            if entry.get("leave_out"):
                found.append(f"{sheet_name}: the image {image_id} is on the sheet, but the list leaves it out")
                continue
            sheet = Image.open(SHEETS / sheet_name).convert("RGB")
            tile = privacy.tiles(sheet)[k]
            img = sheet.crop(tile)
            w, h = img.size
            for a, b, c, d in entry.get("blur", {}).get(privacy.point_of(sheet_name, points), []):
                value = privacy.sharpness(img, (a * w, b * h, c * w, d * h))
                if value > BLURRED:
                    found.append(f"{sheet_name}: the image {image_id}: the box {[a, b, c, d]} is sharp ({value:.0f})")
    assert found == []


def test_blur_makes_a_box_not_readable():
    from PIL import Image, ImageDraw
    img = Image.new("RGB", (400, 300), (200, 200, 200))
    draw = ImageDraw.Draw(img)
    draw.rectangle((100, 120, 260, 160), fill=(240, 240, 240), outline=(0, 0, 0))
    draw.text((110, 130), "72C-036.25", fill=(0, 0, 80))
    box = (100, 120, 260, 160)
    assert privacy.sharpness(img, box) > BLURRED
    privacy.blur(img, [box])
    assert privacy.sharpness(img, box) < BLURRED


def test_clean_leaves_out_an_image_of_the_list(monkeypatch, tmp_path):
    from PIL import Image
    listed = tmp_path / "privacy.json"
    listed.write_text(json.dumps({"images": {"1": {"leave_out": True}, "2": {"blur": {"p": [[0.1, 0.1, 0.5, 0.5]]}}}}))
    monkeypatch.setattr(privacy, "LIST", listed)
    monkeypatch.setattr(privacy, "plate_boxes", lambda img: [])
    monkeypatch.setattr(privacy, "face_boxes", lambda img: [])
    img = Image.new("RGB", (100, 100), (0, 0, 0))
    for x in range(0, 100, 2):
        img.paste((255, 255, 255), (x, 0, x + 1, 100))
    assert privacy.clean(img, "1", "p") == (None, 0)
    cleaned, count = privacy.clean(img, "2", "p")
    assert count == 1
    assert privacy.sharpness(cleaned, (10, 10, 50, 50)) < BLURRED
    assert privacy.sharpness(cleaned, (60, 60, 95, 95)) > BLURRED


@pytest.mark.parametrize("w,h", [(1024, 768), (568, 1146), (381, 385)])
def test_the_windows_cover_the_picture(w, h):
    boxes = privacy.windows(w, h)
    assert boxes[0] == (0, 0, w, h)
    assert all(0 <= x0 < x1 <= w and 0 <= y0 < y1 <= h for x0, y0, x1, y1 in boxes)
