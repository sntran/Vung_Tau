"""Tests for build.py with the small test extract (plan 0003, R18)."""

import json

import numpy as np
import pytest

from geodata import pngio, terrain


def load(build, name):
    return json.loads((build / name).read_text(encoding="utf-8"))


def test_all_files_exist(small_build):
    for name in ["world.json", "roads.json", "blocks.json", "buildings.json", "landmarks.json", "homestay.json",
                 "coastline.json", "land.json", "beaches.json", "report.md", "surface.png", "homestay_area.png",
                 "height/overview.png"]:
        assert (small_build / name).exists(), name


def test_png_files_are_kept_as_they_are(small_build):
    for png in small_build.rglob("*.png"):
        assert (png.parent / (png.name + ".import")).read_text() == '[remap]\n\nimporter="keep"\n'


def test_origin_is_the_center_of_bai_truoc(small_build):
    world = load(small_build, "world.json")
    assert world["origin"]["utm_e"] % 10 == 0
    found = {l["id"]: l for l in load(small_build, "landmarks.json")["landmarks"]}
    x, z = found["bai_truoc"]["position"]
    assert abs(x) <= 10 and abs(z) <= 10


def test_landmarks(small_build):
    found = {l["id"]: l for l in load(small_build, "landmarks.json")["landmarks"]}
    assert found["hai_dang"]["found"] and found["hai_dang"]["osm"].startswith("node/")
    assert found["nui_nho"]["found"] and found["nui_nho"]["ele_tag"] == 180.0
    assert found["nui_nho"]["height"] > 140.0
    assert not found["bai_sau"]["found"] and found["bai_sau"]["reason"]
    assert "outline" in found["bai_truoc"]


def test_chunks_decode_to_the_ground(small_build):
    world = load(small_build, "world.json")
    assert world["chunks"], "the build writes chunks"
    size = world["chunk_size"] // world["grid"] + 1
    for chunk in world["chunks"]:
        values = pngio.read_gray16(small_build / "height" / f"{chunk['x']}_{chunk['z']}.png")
        assert values.shape == (size, size)
        heights = values * world["height"]["step"] + world["height"]["offset"]
        assert heights.min() == pytest.approx(chunk["min"], abs=0.02)
        assert heights.max() == pytest.approx(chunk["max"], abs=0.02)


def test_sea_floor_and_land(small_build):
    world = load(small_build, "world.json")
    lowest = min(c["min"] for c in world["chunks"])
    highest = max(c["max"] for c in world["chunks"])
    assert -16.0 < lowest < -1.0, "the sea floor goes down from the coast"
    assert 140.0 < highest < 160.0, "the hill is there"


def test_roads(small_build):
    roads = {r["name"]: r for r in load(small_build, "roads.json")["roads"] if r["name"]}
    assert roads["Quang Trung"]["type"] == "primary" and roads["Quang Trung"]["sidewalk"] == "both"
    assert roads["Hẻm 42"]["hem"] and roads["Hẻm 42"]["width"] == 3.0
    assert roads["Lê Lợi"]["width"] == 6.0 and roads["Lê Lợi"]["width_source"] == "tag", "the override sets the width"
    assert roads["Lối đi thử"]["source"] == "override"
    # The road points have heights, and no part is longer than 4 m.
    pts = np.array(roads["Quang Trung"]["points"])
    assert pts.shape[1] == 3
    assert np.max(np.linalg.norm(np.diff(pts[:, [0, 2]], axis=0), axis=1)) <= 4.01


class Ground:
    """Reads the height chunks of a build and gives the bilinear height at a game point."""

    def __init__(self, build):
        self.world = load(build, "world.json")
        self.build = build
        self.cache = {}

    def height(self, x, z):
        size, step = self.world["chunk_size"], self.world["grid"]
        cx, cz = int(np.floor(x / size)), int(np.floor(z / size))
        if (cx, cz) not in self.cache:
            values = pngio.read_gray16(self.build / "height" / f"{cx}_{cz}.png")
            self.cache[(cx, cz)] = values * self.world["height"]["step"] + self.world["height"]["offset"]
        h = self.cache[(cx, cz)]
        col, row = (x - cx * size) / step, (z - cz * size) / step
        c0, r0 = min(int(col), h.shape[1] - 2), min(int(row), h.shape[0] - 2)
        fc, fr = col - c0, row - r0
        top = h[r0, c0] * (1 - fc) + h[r0, c0 + 1] * fc
        bottom = h[r0 + 1, c0] * (1 - fc) + h[r0 + 1, c0 + 1] * fc
        return top * (1 - fr) + bottom * fr


def test_road_is_flat_across(small_build):
    """The ground under a road is at the height of the road (D7)."""
    ground = Ground(small_build)
    roads = {r["name"]: r for r in load(small_build, "roads.json")["roads"] if r["name"]}
    for name in ["Quang Trung", "Đường lên Hải Đăng", "Hẻm 42"]:
        road = roads[name]
        pts = np.array(road["points"])
        for i in range(2, len(pts) - 2, 7):
            x, h, z = pts[i]
            if ground.world["map_extents_m"]["z"][0] + 20 > z or z > ground.world["map_extents_m"]["z"][1] - 20:
                continue
            direction = pts[i + 1][[0, 2]] - pts[i - 1][[0, 2]]
            side = np.array([-direction[1], direction[0]]) / np.linalg.norm(direction)
            # In a curve on a slope, the inner edge is near parts of the road at other heights.
            grade = abs(pts[i + 1][1] - pts[i - 1][1]) / np.linalg.norm(direction)
            for offset in (-(road["width"] / 2 - 0.5), 0.0, road["width"] / 2 - 0.5):
                gx, gz = np.array([x, z]) + side * offset
                tolerance = 0.15 + 1.5 * grade * abs(offset)
                assert ground.height(gx, gz) == pytest.approx(h, abs=tolerance), (name, i, offset)
    # The lighthouse road goes up the hill.
    heights = np.array(roads["Đường lên Hải Đăng"]["points"])[:, 1]
    assert heights[-1] - heights[0] > 100.0


def test_beach_slopes_to_the_water(small_build):
    ground = Ground(small_build)
    found = {l["id"]: l for l in load(small_build, "landmarks.json")["landmarks"]}
    x, z = found["bai_truoc"]["position"]
    # The beach is from about x = -23 (the water line) to x = +27 near the origin.
    assert ground.height(x - 20, z) < ground.height(x + 10, z)
    assert terrain.LAND_MIN_HEIGHT <= ground.height(x - 20, z) < terrain.LAND_MIN_HEIGHT + 0.6
    # The sea floor slopes down to SEA_FLOOR_DEPTH over 80 m (R8g).
    assert ground.height(x - 40, z) < ground.height(x - 23, z) - 0.5
    assert ground.height(x - 120, z) == pytest.approx(-terrain.SEA_FLOOR_DEPTH, abs=0.05)


def test_blocks(small_build):
    blocks = load(small_build, "blocks.json")["blocks"]
    assert len(blocks) >= 4
    assert any(b["has_buildings"] for b in blocks)
    assert all(b["area_m2"] >= 30 for b in blocks)


def test_homestay_hem(small_build):
    home = load(small_build, "homestay.json")
    assert home["found"], home["problems"]
    assert home["homestay_hem"]["name"] == "Hẻm 42"
    assert home["coast_road"] == "Quang Trung"
    assert home["curve"]["turn_deg"] == pytest.approx(-90.0, abs=5.0)
    assert len(home["candidates"]) == 1
    assert home["blocks"], "the blocks along the hẻm are in the record"


def test_report(small_build):
    report = (small_build / "report.md").read_text(encoding="utf-8")
    for text in ["## Extents", "## Roads", "## Blocks and buildings", "## Landmarks", "## Homestay hẻm",
                 "## Problems with the data", "Bãi Sau | **no**", "has no reason", "finds no way"]:
        assert text in report, text
