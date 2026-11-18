"""Unit tests for the ground of the showcase of Bãi Trước (plan 0026, R3 and R4)."""

from types import SimpleNamespace

import numpy as np
import pytest
from shapely.geometry import Polygon, box

from geodata import showcase

CONFIG = {
    "cell_m": 0.5,
    "road_margin_m": 0.3,
    "lawns": ["way/1"],
    "paving": ["way/2"],
    "not_lawn": [["amenity", "fountain"]],
    "planters": {"osm": ["way/4"]},
    "beach_wall": {"walks": ["way/2"], "near_beach_m": 2.0, "min_length_m": 3.0},
}


def _areas():
    # Map coordinates: x east, y north (game z = -y).
    return [
        ("way/1", {"leisure": "park"}, box(0, 0, 40, 40)),
        ("way/2", {"highway": "footway", "area": "yes"}, box(-10, 0, 0, 40)),
        ("way/3", {"amenity": "fountain"}, box(30, 30, 34, 34)),
        ("way/4", {"landuse": "grass"}, box(-8, 10, -6, 20)),
        ("way/5", {"natural": "beach"}, box(-30, -10, -10, 50)),
    ]


def _path():
    return SimpleNamespace(type="footway", width=2.0, points=np.array([[20.0, 0.0], [20.0, 40.0]]))


def test_the_lawn_is_the_park_less_the_paths_the_paving_and_the_fountain():
    outline = box(-50, -50, 50, 50)
    result = showcase.make(CONFIG, _areas(), [_path()], [], outline)
    mask = result["mask"]
    step = result["step"]

    def at(x, y):
        col = int((x - result["x0"]) / step)
        row = int((-result["z0"] - y) / step)
        return mask[row, col]

    assert at(10, 20)[0] == 255, "the lawn of the park"
    assert at(20, 20)[0] == 0, "no lawn on the path"
    assert at(32, 32)[0] == 0, "no lawn on the fountain"
    assert at(-5, 5)[1] == 255 and at(-5, 5)[0] == 0, "the paving of the walk"
    assert result["areas"]["lawn_m2"] < 40 * 40


def test_the_raised_lawns_and_the_wall_along_the_beach():
    result = showcase.make(CONFIG, _areas(), [], [], box(-50, -50, 50, 50))
    assert [p["osm"] for p in result["planters"]] == ["way/4"]
    assert len(result["planters"][0]["outline"]) == 4
    # The west edge of the walk (x = -10) is on the beach: one wall line of 40 m, game z = -y.
    assert len(result["walls"]) == 1
    xs = {round(p[0]) for p in result["walls"][0]["points"]}
    zs = sorted(round(p[1]) for p in result["walls"][0]["points"])
    assert xs == {-10} and zs[0] == -40 and zs[-1] == 0


def test_an_unknown_area_is_a_problem():
    config = dict(CONFIG, lawns=["way/99"])
    result = showcase.make(config, _areas(), [], [], Polygon([(-50, -50), (50, -50), (50, 50), (-50, 50)]))
    assert any("way/99" in p for p in result["problems"])


def test_two_models_side_by_side_stand_on_their_own_level(tmp_path):
    """Plan 0026, D3: the ground under each model is level at the height at its
    front; where the margins of two models meet, the nearest model wins."""
    import json
    import sys
    from pathlib import Path

    from geodata import terrain

    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    import build

    # The ground climbs 0.1 m per meter to the east (game x).
    xs = np.arange(0, 60) * 1.0
    heights = np.tile(xs * 0.1, (40, 1)).astype(np.float32)
    grid = terrain.Grid(0.0, 0.0, 1.0, heights)
    # Two boxes 10 m wide, side by side with 1 m between them, their fronts at z = 30 to +z.
    places = [{"id": "a", "front": [20.0, 30.0], "facing": [0, 1], "front_middle_x": 0.0, "box": [-5, 5, -10, 0]},
              {"id": "b", "front": [31.0, 30.0], "facing": [0, 1], "front_middle_x": 0.0, "box": [-5, 5, -10, 0]}]
    (tmp_path / "test.json").write_text(json.dumps({"places": places}))
    build.level_world_places(grid, tmp_path)
    for place, level in (("a", 2.0), ("b", 3.1)):
        x = places[0]["front"][0] if place == "a" else places[1]["front"][0]
        # The front, and its two corners 2 m inside the sides.
        for dx in (-3.0, 0.0, 3.0):
            assert grid.sample(np.array([x + dx]), np.array([30.0]))[0] == pytest.approx(level, abs=0.05)


def test_the_level_sides_of_a_place_on_a_hill(tmp_path):
    """Report 0026, PT-71: a model against a hill ("keep_higher") keeps the
    higher ground next to its sides, and the grid of 2 m mixed it into the
    corners of its front. With "level_sides_m" the ground is level past the
    sides too."""
    import json
    import sys
    from pathlib import Path

    from geodata import terrain

    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    import build

    # The ground climbs 0.3 m per meter to the east (game x), a grid of 2 m.
    xs = np.arange(0, 40) * 2.0
    heights = np.tile(xs * 0.3, (30, 1)).astype(np.float32)
    place = {"id": "a", "front": [40.0, 40.0], "facing": [0, 1], "front_middle_x": 0.0, "box": [-9, 9, -20, 0],
             "forecourt_m": 3.0, "keep_higher": True}
    for sides, ok in ((0.0, False), (2.5, True)):
        grid = terrain.Grid(0.0, 0.0, 2.0, heights.copy())
        folder = tmp_path / str(sides)
        folder.mkdir()
        (folder / "test.json").write_text(json.dumps({"places": [dict(place, level_sides_m=sides)]}))
        build.level_world_places(grid, folder)
        level = 12.0
        # The ground 1 m past the uphill side, at the front: higher than the
        # level unless the sides are level.
        past = grid.sample(np.array([49.0]), np.array([39.0]))[0]
        assert (abs(past - level) <= 0.1) == ok
        assert grid.sample(np.array([40.0]), np.array([40.0]))[0] == pytest.approx(level, abs=0.05)


def test_the_ground_beside_a_sidewalk_is_at_its_top():
    """Report 0026, D-0026-11: the ground under a sidewalk of the showcase and
    past its outer edge is at its top less UNDER_TOP_M; lower ground past it
    rises to it; the road does not change."""
    from geodata import roads as roads_module
    from geodata import terrain

    cols, rows = 41, 41
    heights = np.full((rows, cols), 5.0, dtype=np.float32)
    heights[:, 26:] = 4.0  # the park, 1 m lower, from x 52
    grid = terrain.Grid(x0=0.0, z0=-80.0, step=2.0, heights=heights)
    pts = np.array([(40.0, 0.0), (40.0, 80.0)])  # map y 0 to 80: game z 0 to -80, forward -z
    road = roads_module.Road(id=7, type="primary", name="", width=10.0, width_source="table", surface="", hem=False,
                             sidewalk="", oneway=False, lanes=0, bridge=False, tunnel=False, refs=[1, 2],
                             node_points=pts, points=pts)
    config = {"outline": [[0.0, -100.0], [100.0, -100.0], [100.0, 100.0], [0.0, 100.0]],
              # Forward -z: the right side (-forward.z, forward.x) is +x.
              "sidewalks": [{"way": 7, "side": "right", "width": 3.0, "height": 0.15}]}
    result = showcase.level_walks(grid, config, [road])
    top = 5.0 + showcase.ROAD_LIFT_M + 0.15
    assert result["cells"] > 0
    assert grid.sample([40.0], [-40.0])[0] == pytest.approx(5.0), "the road does not change"
    edge = grid.sample([48.3], [-40.0])[0]
    assert edge == pytest.approx(top - showcase.UNDER_TOP_M, abs=0.02), "the ground at the outer edge"
    past = grid.sample([56.0], [-40.0])[0]
    assert 4.0 < past < top, "the park rises to the sidewalk"
    # The cells of the sidewalk itself (x 48), not the road (x 40) and not the park (x 52).
    assert result["walks"][20, 24] and not result["walks"][20, 20] and not result["walks"][20, 26]


def test_the_footways_of_a_park_are_paved():
    """Report 0026, D-0026-17: a footway in a park for half of its length or
    more has tiles; a footway out of the parks and a road do not."""
    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    import build

    park = box(0, 0, 40, 40)
    inside = SimpleNamespace(id=1, type="footway", points=np.array([[5.0, 5.0], [35.0, 5.0]]))
    half_out = SimpleNamespace(id=2, type="footway", points=np.array([[30.0, 20.0], [70.0, 20.0]]))
    outside = SimpleNamespace(id=3, type="footway", points=np.array([[50.0, 50.0], [80.0, 50.0]]))
    road = SimpleNamespace(id=4, type="residential", points=np.array([[5.0, 10.0], [35.0, 10.0]]))
    assert build.paved_paths([inside, half_out, outside, road], [park]) == {1}
    assert build.paved_paths([inside], []) == set()
