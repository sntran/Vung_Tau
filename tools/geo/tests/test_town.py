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
    chunks, numbers = town.make([_box("a", 10, 10, 20, 25, 9.0)], _flat, PALETTE, 256.0)
    record = chunks[(0, 0)][0]
    assert record[1] == 2.0 - town.BASE_SINK_M
    assert record[2] == 11.0
    assert numbers["buildings"] == 1


def test_the_shared_wall_of_two_row_houses_is_hidden_up_to_the_lower_roof():
    low = _box("low", 0, 0, 4, 15, 6.0)
    high = _box("high", 4, 0, 8, 15, 12.0)
    chunks, numbers = town.make([low, high], _flat, PALETTE, 256.0)
    by_id = {r[0]: r for r in chunks[(0, 0)]}
    # The wall of the low house on x = 4 is hidden to the top of the high house (all of it).
    assert max(by_id["low"][7]) >= by_id["low"][2]
    # The wall of the high house on x = 4 is hidden only to the top of the low house.
    assert max(by_id["high"][7]) == by_id["low"][2]
    assert numbers["hidden_walls"] == 1


def test_two_touching_houses_do_not_have_the_same_wall_color():
    houses = [_box(f"h{i}", 4 * i, 0, 4 * i + 4, 15) for i in range(6)]
    chunks, _ = town.make(houses, _flat, PALETTE, 256.0)
    walls = [r[4] for r in sorted(chunks[(0, 0)], key=lambda r: r[0])]
    assert all(a != b for a, b in zip(walls, walls[1:]))


def test_a_building_goes_to_the_chunk_of_its_middle_and_a_small_one_is_left_out():
    chunks, numbers = town.make([_box("far", 300, -10, 310, -2), _box("tiny", 0, 0, 2, 2)], _flat, PALETTE, 256.0)
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
