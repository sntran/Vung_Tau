"""Report 0009, D-0009-19: the ground of a place with stairs (build.py:
level_approaches() and cut_stairs())."""

import sys
from pathlib import Path
from types import SimpleNamespace

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import build  # noqa: E402
from geodata import terrain  # noqa: E402


def _islet():
    """An islet: the ground climbs to the east at 25 %, with a crest of 3 m at x
    = 40 m; stairs from x = 0 to x = 40 (map coordinates), and a shrine at x =
    52 to 60 whose base is at 5 m."""
    grid = terrain.make_grid((-20.0, -40.0, 100.0, 40.0), 256.0, 1.0)
    xs = grid.x0 + np.arange(grid.shape[1]) * grid.step
    ground = np.clip(xs * 0.25, 0.0, 10.0)
    crest = 3.0 * np.exp(-((xs - 46.0) / 3.0) ** 2)
    grid.heights[:] = (np.minimum(ground, 5.0) + crest)[None, :]
    road = SimpleNamespace(id=7, points=np.array([[0.0, 0.0], [40.0, 0.0]]), width=2.0)
    landmarks = [{"id": "shrine", "place": {"kind": "shrine", "stairs": [7]}}]
    outline = [[52.0, -4.0], [60.0, -4.0], [60.0, 4.0], [52.0, 4.0], [52.0, -4.0]]
    found = {"shrine": {"found": True, "position": [56.0, 0.0], "outline": outline, "base_height": 5.1}}
    return grid, road, landmarks, found


def test_the_ground_from_the_top_of_the_stairs_to_the_place_is_not_over_its_base():
    grid, road, landmarks, found = _islet()
    assert grid.sample(np.array([46.0]), np.array([0.0]))[0] > 7.0, "the crest is there before"
    build.level_approaches(grid, landmarks, found, [road])
    xs = np.arange(40.0, 56.0, 0.5)
    assert np.all(grid.sample(xs, np.zeros_like(xs)) <= 5.0 + 1e-3)


def test_the_band_of_the_stairs_joins_the_ground_with_no_edge_of_a_saw():
    """A diagonal stairs line: across the line, the ground changes smoothly
    (no step of more than the cut of the band between two cells)."""
    grid = terrain.make_grid((-20.0, -60.0, 60.0, 20.0), 256.0, 1.0)
    rows, cols = np.indices(grid.shape)
    # A side slope of 50 % across the line, flat along it (the band cuts into it on one side).
    grid.heights[:] = ((cols + rows) * 0.5 * grid.step).astype(np.float32)
    road = SimpleNamespace(id=3, points=np.array([[0.0, 0.0], [30.0, 30.0]]), width=2.0)
    landmarks = [{"id": "p", "place": {"kind": "shrine", "stairs": [3]}}]
    found = {"p": {"found": True, "position": [40.0, -40.0]}}
    before = grid.heights.copy()
    build.cut_stairs(grid, landmarks, found, [road])
    change = grid.heights - before
    assert np.abs(change).max() > 0.5, "the band changes the ground"
    # Across the edge of the band (in the middle of the line) the change goes
    # down over the blend, not in one cell: a hard edge has jumps of the full cut.
    row = int(round((-15.0 - grid.z0) / grid.step))
    col = int(round((15.0 - grid.x0) / grid.step))
    middle = change[row - 4:row + 5, col - 10:col + 11]
    jumps = np.abs(np.diff(middle, axis=1))
    assert np.abs(middle).max() > 1.0
    assert jumps.max() < 0.6 * np.abs(middle).max()
