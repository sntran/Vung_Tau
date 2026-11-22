"""Report 0009, Q14: the far grid of the land around the play area (geodata/mainland.py)."""

import sys
from pathlib import Path

import numpy as np
import pytest
import rasterio
from rasterio.transform import from_origin

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from geodata import mainland  # noqa: E402
from geodata.projection import Projection  # noqa: E402


def test_the_curve_of_the_earth_at_25_km_is_about_43_m():
    assert mainland.curve_drop(25_000.0, 0.13) == pytest.approx(42.7, abs=0.5)
    assert mainland.curve_drop(0.0, 0.13) == 0.0


def test_the_grid_has_the_land_out_of_the_box_only(tmp_path):
    # A DEM of 0.6 degrees: the sea (0), and a hill of 300 m in the north-east corner.
    lon0, lat0 = 106.8, 10.65
    size = 0.6 / 240
    data = np.zeros((240, 240), dtype=np.float32)
    data[:60, 180:] = 300.0
    data[100:140, 100:140] = 20.0  # the play area, in the box
    path = tmp_path / "mainland.tif"
    with rasterio.open(path, "w", driver="GTiff", height=240, width=240, count=1, dtype="float32", crs="EPSG:4326",
                       transform=from_origin(lon0, lat0, size, size)) as dst:
        dst.write(data, 1)
    from pyproj import Transformer
    projection = Projection(*Transformer.from_crs(4326, 32648, always_xy=True).transform(107.1, 10.35))
    x, z = projection.to_game(107.1, 10.35)
    box = (x - 2000.0, z - 2000.0, x + 2000.0, z + 2000.0)
    record = mainland.make(path, projection, box, {"grid_m": 400, "radius_m": 30000, "refraction": 0.13, "land_m": 0.5}, 1.0)
    rows, cols = record["rows"], record["cols"]
    cells = np.array([c == "1" for c in record["cells"]]).reshape(rows - 1, cols - 1)
    assert cells.any(), "the hill of the north-east has cells"
    # No cell in the box (the land of the play area is the ground of the game).
    mid_r, mid_c = (rows - 1) // 2, (cols - 1) // 2
    assert not cells[mid_r - 3:mid_r + 3, mid_c - 3:mid_c + 3].any()
    # The heights are over the mean sea level, less the curve.
    heights = np.array(record["heights"]).reshape(rows, cols)
    assert heights.max() < 300.0 - 1.0 and heights.max() > 250.0
    assert record["numbers"]["highest_m"] == pytest.approx(299.0, abs=0.5)
