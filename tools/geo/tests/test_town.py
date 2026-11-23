"""Plan 0009, phase 2: the boxes of the buildings of 2019 (geodata/town.py)."""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from geodata import town  # noqa: E402

PALETTE = {
    "walls": [{"color": "#AAAAAA", "weight": 0.5}, {"color": "#BBBBBB", "weight": 0.5}],
    "far_fronts": {"dark": "#202020", "upper_openings": 0.25, "ground_openings": 0.5, "storey_m": 3.0},
    "roof_tiles": {"colors": ["#D39B83"], "share": 0.06},
    "metal_roofs": {"colors": [{"color": "#5C3E30", "weight": 0.1}]},
    "terraces": {"colors": [{"color": "#CBCAC0", "weight": 0.3}]},
}


def _box(id_, x0, z0, x1, z1, height=6.0):
    return {"id": id_, "outline": [[x0, z0], [x1, z0], [x1, z1], [x0, z1], [x0, z0]], "height": height, "first_year": 2018}


def _flat(x, z):
    return np.full(np.shape(x), 2.0)


def test_a_box_has_its_height_over_the_ground_and_a_base_under_it():
    chunks, _tall, numbers = town.make([_box("a", 10, 10, 20, 25, 9.0)], _flat, PALETTE, 256.0)
    record = chunks[(0, 0)][0]
    assert record[1] == 2.0 - town.BASE_SINK_M
    assert record[2] == 11.0
    assert numbers["buildings"] == 1


def test_the_shared_wall_of_two_row_houses_is_hidden_up_to_the_lower_roof():
    low = _box("low", 0, 0, 4, 15, 6.0)
    high = _box("high", 4, 0, 8, 15, 12.0)
    chunks, _tall, numbers = town.make([low, high], _flat, PALETTE, 256.0)
    by_id = {r[0]: r for r in chunks[(0, 0)]}
    # The wall of the low house on x = 4 is hidden to the top of the high house (all of it).
    assert max(by_id["low"][7]) >= by_id["low"][2]
    # The wall of the high house on x = 4 is hidden only to the top of the low house.
    assert max(by_id["high"][7]) == by_id["low"][2]
    assert numbers["hidden_walls"] == 1


def test_two_touching_houses_do_not_have_the_same_wall_color():
    houses = [_box(f"h{i}", 4 * i, 0, 4 * i + 4, 15) for i in range(6)]
    chunks, _tall, _ = town.make(houses, _flat, PALETTE, 256.0)
    walls = [r[4] for r in sorted(chunks[(0, 0)], key=lambda r: r[0])]
    assert all(a != b for a, b in zip(walls, walls[1:]))


def test_a_building_goes_to_the_chunk_of_its_middle_and_a_small_one_is_left_out():
    chunks, _tall, numbers = town.make([_box("far", 300, -10, 310, -2), _box("tiny", 0, 0, 2, 2)], _flat, PALETTE, 256.0)
    assert list(chunks) == [(1, -1)]
    assert numbers["left_out_small"] == 1


def test_the_roof_shares_come_from_the_palette():
    shares = town.roof_shares(PALETTE)
    assert abs(shares["tiles"] - 0.06) < 1e-9
    assert abs(sum(shares.values()) - 1.0) < 1e-9
    assert abs(shares["metal"] / shares["terrace"] - 0.1 / 0.3) < 1e-9


def test_an_outline_with_many_points_becomes_its_rectangle():
    angles = np.linspace(0, 2 * np.pi, 40, endpoint=False)
    circle = [[float(20 + 8 * np.cos(a)), float(20 + 8 * np.sin(a))] for a in angles]
    polygon = town.outline_of(circle)
    assert len(polygon.exterior.coords) - 1 <= town.MAX_POINTS
    assert polygon.exterior.is_ccw


def test_a_tall_building_goes_to_the_list_of_the_tall_buildings():
    """Report 0009, D-0009-14: a building of TALL_M or more shows to the end of
    the far range, so it is in its own list, not in its chunk."""
    chunks, tall, numbers = town.make([_box("low", 0, 0, 10, 10, 9.0), _box("tower", 20, 0, 40, 20, 30.0)],
                                      _flat, PALETTE, 256.0)
    assert [r[0] for r in chunks[(0, 0)]] == ["low"]
    assert [r[0] for r in tall[(0, 0)]] == ["tower"]
    assert numbers["tall"] == 1


def test_the_far_color_is_the_mean_of_the_roofs_and_the_walls():
    """Report 0009, D-0009-14: the far pattern of the ground takes the mean color of the boxes."""
    palette = {**PALETTE, "walls": [{"color": "#000000", "weight": 1.0}],
               "terraces": {"colors": [{"color": "#FFFFFF", "weight": 1.0}]},
               "roof_tiles": {"colors": ["#FFFFFF"], "share": 0.0}, "metal_roofs": {"colors": [{"color": "#FFFFFF", "weight": 0.0}]}}
    _chunks, _tall, numbers = town.make([_box("a", 0, 0, 10, 10, 10.0)], _flat, palette, 256.0)
    value = int(numbers["far_color"][1:3], 16)
    # A roof of 100 m2 (white) and the half of 400 m2 of walls (black) that faces the eye.
    assert 0 < value < 255


def test_the_far_color_of_a_wall_has_the_dark_of_its_openings():
    """Report 0009, D-0009-15: from far a front is its paint with the dark of its
    windows, and a low house has more of the dark of its open ground floor."""
    paint = "#C8C8C8"
    low = town.front_color(paint, 3.0, PALETTE["far_fronts"])
    high = town.front_color(paint, 30.0, PALETTE["far_fronts"])
    value = lambda c: int(c[1:3], 16)
    assert value(low) < value(high) < value(paint)
    chunks, _tall, _numbers = town.make([_box("a", 0, 0, 10, 10, 9.0)], _flat, PALETTE, 256.0)
    assert chunks[(0, 0)][0][4] not in ("#AAAAAA", "#BBBBBB")


def test_a_far_roof_takes_the_light_of_the_palette():
    """Report 0009, D-0009-15: the measured roof colors have the light of the sun in them."""
    palette = {**PALETTE, "far_roofs": {"light": 0.5}, "roof_tiles": {"colors": ["#D39B83"], "share": 0.0},
               "metal_roofs": {"colors": [{"color": "#5C3E30", "weight": 0.0}]},
               "terraces": {"colors": [{"color": "#CCCCCC", "weight": 1.0}]}}
    chunks, _tall, _numbers = town.make([_box("a", 0, 0, 10, 10, 9.0)], _flat, palette, 256.0)
    assert chunks[(0, 0)][0][5] == "#666666"


def test_a_share_of_the_walls_is_bold():
    """Report 0009, audit 4 (PT-33): the house kit of plan 0004 makes about 30 %
    of the walls bold (D-0004-09); the boxes too."""
    palette = {**PALETTE, "bold_share": 0.3, "bold_walls": [{"color": "#06ACC0"}, {"color": "#F0D98A"}],
               "far_fronts": {"dark": "#000000", "upper_openings": 0.0, "ground_openings": 0.0, "storey_m": 3.0}}
    houses = [_box(f"h{i}", 20 * (i % 20), 20 * (i // 20), 20 * (i % 20) + 8, 20 * (i // 20) + 8) for i in range(400)]
    chunks, _tall, _ = town.make(houses, _flat, palette, 1024.0)
    walls = [r[4] for records in chunks.values() for r in records]
    bold = sum(1 for w in walls if w in ("#06ACC0", "#F0D98A")) / len(walls)
    assert 0.24 < bold < 0.36


def test_the_far_color_has_the_shade_of_the_street_at_the_foot_of_the_walls():
    """Report 0009, audit 4 (PT-33): the walls of the boxes are darker at their
    foot (foot_shade), so the far color of the ground is darker too."""
    base = {**PALETTE, "walls": [{"color": "#FFFFFF", "weight": 1.0}],
            "terraces": {"colors": [{"color": "#FFFFFF", "weight": 1.0}]},
            "roof_tiles": {"colors": ["#FFFFFF"], "share": 0.0}, "metal_roofs": {"colors": [{"color": "#FFFFFF", "weight": 0.0}]}}
    lit = {**base, "far_fronts": {"dark": "#000000", "upper_openings": 0.0, "ground_openings": 0.0, "storey_m": 3.0}}
    shaded = {**base, "far_fronts": {**lit["far_fronts"], "foot_shade": 0.5}}
    value = lambda p: int(town.make([_box("a", 0, 0, 10, 10, 10.0)], _flat, p, 256.0)[2]["far_color"][1:3], 16)
    assert value(shaded) < value(lit)


def test_a_tower_takes_a_color_of_the_towers():
    """Report 0009, D-0009-24: 92 of the 166 towers had a bold color of the
    house kit (teal, green, blue, brown). A building of TALL_M or more takes a
    color of the towers of the photos (white, cream, grey, glass), as its far
    color: the photos give the color of the whole front, with the windows."""
    towers = ["#D8D9D6", "#6B838D"]
    palette = {**PALETTE, "bold_walls": [{"color": "#1894A5"}], "bold_share": 1.0,
               "towers": {"colors": [{"color": c, "weight": 1.0} for c in towers]}}
    boxes = [_box(f"t{i}", i * 30, 0, i * 30 + 20, 20, 40.0) for i in range(8)] + [_box("low", 0, 40, 10, 50, 9.0)]
    chunks, tall, _numbers = town.make(boxes, _flat, palette, 256.0)
    fronts = {r[4] for rows in tall.values() for r in rows}
    assert fronts <= set(towers) and len(fronts) == 2
    assert chunks[(0, 0)][0][4] != "#D8D9D6", "a low house keeps the colors of the house kit"


def test_the_colors_of_the_towers_are_not_bold():
    import json
    palette = json.loads((Path(__file__).resolve().parents[3] / "data" / "world" / "palette.json").read_text())
    for c in palette["towers"]["colors"]:
        r, g, b = (int(c["color"][k:k + 2], 16) / 255.0 for k in (1, 3, 5))
        saturation = (max(r, g, b) - min(r, g, b)) / max(r, g, b)
        assert saturation <= 0.25, c


def test_no_box_of_the_raster_stands_on_a_road():
    """Report 0009, D-0009-27: in the built town, no box of the raster (its
    outline as the town keeps it) has more than 10 % of its area on the surface
    of a road (roads.json with the width of each road)."""
    import glob
    import json
    import shapely
    from shapely import STRtree
    import buildings as tool
    build = Path(__file__).resolve().parents[3] / "data" / "geo" / "build"
    surfaces = tool.road_surfaces(json.loads((build / "roads.json").read_text(encoding="utf-8"))["roads"])
    tree = STRtree(surfaces)
    on_roads = []
    count = 0
    for path in glob.glob(str(build / "town" / "*.json")):
        if path.endswith("index.json"):
            continue
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        # A chunk file has "buildings"; tall.json has "chunks": [cx, cz, [records]].
        records = data["buildings"] if "buildings" in data else [r for chunk in data.get("chunks", []) for r in chunk[2]]
        for record in records:
            if not str(record[0]).startswith("raster-"):
                continue
            count += 1
            flat = record[6]
            polygon = shapely.Polygon(list(zip(flat[0::2], flat[1::2]))).buffer(0)
            near = [surfaces[i] for i in tree.query(polygon)]
            share = polygon.intersection(shapely.union_all(near)).area / polygon.area if near else 0.0
            if share > 0.10:
                on_roads.append((record[0], round(share, 2), round(polygon.area)))
    assert count > 1000, f"the town has {count} boxes of the raster"
    assert not on_roads, f"{len(on_roads)} boxes of the raster stand on a road: {sorted(on_roads, key=lambda r: -r[1])[:8]}"


def test_an_outline_that_goes_out_and_back_is_a_valid_polygon():
    """Report 0009, D-0009-27: two squares of the raster that touch at a
    corner, and a spike out and back: the outline keeps the area of the larger
    square, with no spike, and is not the rectangle around both."""
    ring = [(0, 0), (10, 0), (10, 10), (20, 10), (20, 14), (10, 10), (0, 10), (0, 0)]
    polygon = town.outline_of([(x, -y) for x, y in ring])
    assert polygon is not None and polygon.is_valid
    assert abs(polygon.area - 100.0) < 1.0
    spike = [(0, 0), (10, 0), (10, 5), (25, 5), (10, 5.001), (10, 10), (0, 10), (0, 0)]
    polygon = town.outline_of([(x, -y) for x, y in spike])
    assert polygon is not None and polygon.is_valid
    assert polygon.bounds[2] <= 10.5 and abs(polygon.area - 100.0) < 1.0


def test_the_road_cut_comes_after_the_simplification():
    """Report 0009, D-0009-27: a box of the raster loses the part on a road
    after its outline is simplified, so the simplification cannot put it back."""
    import shapely
    road = shapely.box(-5, 8, 30, 20)
    polygon = town.outline_of([(0, 0), (20, 0), (20, -15), (0, -15)], cut=lambda p: p.difference(road))
    assert polygon is not None and polygon.intersection(road).area < 1.0
    assert abs(polygon.area - 160.0) < 2.0
