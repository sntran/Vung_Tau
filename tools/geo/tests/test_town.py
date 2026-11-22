"""Plan 0009, phase 2: the boxes of the buildings of 2019 (geodata/town.py)."""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from geodata import town  # noqa: E402

PALETTE = {
    "walls": [{"color": "#AAAAAA", "weight": 0.5}, {"color": "#BBBBBB", "weight": 0.5}],
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
