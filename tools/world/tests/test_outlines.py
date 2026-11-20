"""Report 0026, D-0026-32: the mid and the far level of each model of the lock
have about the outline of its near level from the side. No network."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import outlines  # noqa: E402


def test_the_levels_of_each_model_have_the_outline_of_the_near_level():
    assert outlines.problems() == []


def test_a_cone_in_place_of_a_pole_is_found(tmp_path, monkeypatch):
    import numpy as np
    pole = np.array([[[0, 0, -0.05], [0, 10, -0.05], [0, 10, 0.05]], [[0, 0, -0.05], [0, 10, 0.05], [0, 0, 0.05]]], float)
    cone = np.array([[[0, 0, -0.05], [0, 10, -1.0], [0, 10, 1.0]], [[0, 0, -0.05], [0, 10, 1.0], [0, 0, 0.05]]], float)
    box = (-1.0, 0.0, 1.0, 10.0)
    near = np.asarray(outlines.outline(pole, outlines.SIDE, box)).astype(bool).sum()
    far = np.asarray(outlines.outline(cone, outlines.SIDE, box)).astype(bool).sum()
    assert far / near > 1.0 + outlines.MAX_CHANGE
