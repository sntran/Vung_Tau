#!/usr/bin/env python3
"""The sources of the land cover and the trees (report 0005, D-0005-09,
correction 0; plan 0020, D8). It runs in CI (the "Geodata" workflow) and in
the workspace. It reads only the play area.

Usage:
  python tools/geo/landcover.py

- ESA WorldCover 2021 (v200, 10 m): what grows on each place (tree cover,
  shrubland, grassland, cropland, built-up, bare or sparse, water, wetland,
  mangrove). It writes data/geo/raw/worldcover.tif (the classes, in degrees).
- The Meta and WRI canopy height maps (about 1 m, from Maxar images): where
  the trees stand and how tall they are. It writes data/geo/raw/canopy.tif:
  the height in meters on a grid of CANOPY_STEP_M in UTM, with the highest
  value of the cells in each grid cell, so that the tree tops stay.
- data/geo/raw/landcover.json: the sources, the licenses, the notices, the
  dates of the canopy images over the play area, and the share of each class.
build.py reads them.
"""

import json
import sys
import time
from pathlib import Path

import numpy as np
import rasterio
from rasterio.enums import Resampling
from rasterio.transform import from_origin
from rasterio.warp import reproject, transform_bounds
from rasterio.windows import from_bounds

sys.path.insert(0, str(Path(__file__).resolve().parent))

from geodata.config import GEO, RAW, write_json  # noqa: E402

WORLDCOVER_URL = ("https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/"
                  "ESA_WorldCover_10m_2021_v200_{tile}_Map.tif")
CANOPY_ROOT = "https://dataforgood-fb-data.s3.amazonaws.com/forests/v1/alsgedi_global_v6_float/"
WORLDCOVER_NOTICE = ("© ESA WorldCover project 2021 / Contains modified Copernicus Sentinel data (2021) processed by "
                     "ESA WorldCover consortium. CC BY 4.0.")
CANOPY_NOTICE = ("High Resolution Canopy Height Maps by WRI and Meta (Tolan et al. 2024), from Maxar images. "
                 "CC BY 4.0.")
CLASSES = {10: "tree cover", 20: "shrubland", 30: "grassland", 40: "cropland", 50: "built-up", 60: "bare or sparse",
           70: "snow and ice", 80: "water", 90: "herbaceous wetland", 95: "mangroves", 100: "moss and lichen"}
# The canopy heights go to this grid (m), in the UTM zone of the game.
CANOPY_STEP_M = 2.0
# A margin around the play box (degrees), for the edges of the grids.
MARGIN_DEG = 0.004
RETRIES = 4


def log(text: str) -> None:
    print(f"[landcover] {text}", flush=True)


def worldcover_tile(lon: float, lat: float) -> str:
    """The name of the 3° tile of WorldCover with the point, for example N09E105."""
    south = int(np.floor(lat / 3.0) * 3)
    west = int(np.floor(lon / 3.0) * 3)
    return f"{'N' if south >= 0 else 'S'}{abs(south):02d}{'E' if west >= 0 else 'W'}{abs(west):03d}"


def quadkey(lon: float, lat: float, zoom: int) -> str:
    """The Bing quadkey of the Web Mercator tile with the point (the names of the canopy files)."""
    x = int((lon + 180.0) / 360.0 * 2 ** zoom)
    s = np.sin(np.radians(lat))
    y = int((0.5 - np.log((1 + s) / (1 - s)) / (4 * np.pi)) * 2 ** zoom)
    key = ""
    for i in range(zoom, 0, -1):
        mask = 1 << (i - 1)
        key += str((1 if x & mask else 0) + (2 if y & mask else 0))
    return key


def _open(url: str):
    for attempt in range(RETRIES):
        try:
            return rasterio.open("/vsicurl/" + url)
        except rasterio.errors.RasterioIOError as error:
            if attempt == RETRIES - 1:
                raise
            log(f"retry after {error}")
            time.sleep(2 ** (attempt + 1))
    return None


def read_worldcover(box: tuple, out: Path) -> dict:
    """The classes in the box (west, south, east, north), as they are (10 m, degrees)."""
    tiles = {worldcover_tile(box[0], box[1]), worldcover_tile(box[2], box[3])}
    if len(tiles) != 1:
        raise SystemExit(f"the play area is on more than one WorldCover tile: {sorted(tiles)}")
    url = WORLDCOVER_URL.format(tile=tiles.pop())
    with _open(url) as src:
        window = from_bounds(*box, transform=src.transform).round_offsets().round_lengths()
        data = src.read(1, window=window)
        profile = {"driver": "GTiff", "height": data.shape[0], "width": data.shape[1], "count": 1, "dtype": "uint8",
                   "crs": src.crs, "transform": src.window_transform(window), "compress": "deflate", "nodata": 0}
    with rasterio.open(out, "w", **profile) as dst:
        dst.write(data, 1)
    values, counts = np.unique(data, return_counts=True)
    shares = {CLASSES.get(int(v), str(int(v))): round(float(c) / data.size, 4) for v, c in zip(values, counts) if v}
    log(f"WorldCover {url.rsplit('/', 1)[-1]}: {data.shape[1]} x {data.shape[0]} pixels, {shares}")
    return {"url": url, "shares": shares}


def read_canopy(box: tuple, epsg: int, out: Path) -> dict:
    """The canopy heights in the box on a UTM grid of CANOPY_STEP_M, with the highest value."""
    keys = sorted({quadkey(lon, lat, 9) for lon in (box[0], box[2]) for lat in (box[1], box[3])})
    left, bottom, right, top = transform_bounds("EPSG:4326", f"EPSG:{epsg}", *box)
    left, bottom = np.floor(left / CANOPY_STEP_M) * CANOPY_STEP_M, np.floor(bottom / CANOPY_STEP_M) * CANOPY_STEP_M
    right, top = np.ceil(right / CANOPY_STEP_M) * CANOPY_STEP_M, np.ceil(top / CANOPY_STEP_M) * CANOPY_STEP_M
    width = int(round((right - left) / CANOPY_STEP_M))
    height = int(round((top - bottom) / CANOPY_STEP_M))
    transform = from_origin(left, top, CANOPY_STEP_M, CANOPY_STEP_M)
    result = np.zeros((height, width), dtype=np.uint8)
    for key in keys:
        url = f"{CANOPY_ROOT}chm/{key}.tif"
        with _open(url) as src:
            bounds = transform_bounds("EPSG:4326", src.crs, *box)
            window = from_bounds(*bounds, transform=src.transform).round_offsets().round_lengths()
            data = src.read(1, window=window, boundless=True, fill_value=0)
            part = np.zeros_like(result)
            reproject(source=data, destination=part, src_transform=src.window_transform(window), src_crs=src.crs,
                      dst_transform=transform, dst_crs=f"EPSG:{epsg}", resampling=Resampling.max, src_nodata=None)
            result = np.maximum(result, part)
        log(f"canopy tile {key}: {data.shape[1]} x {data.shape[0]} pixels")
    profile = {"driver": "GTiff", "height": height, "width": width, "count": 1, "dtype": "uint8",
               "crs": f"EPSG:{epsg}", "transform": transform, "compress": "deflate", "predictor": 2, "tiled": True}
    with rasterio.open(out, "w", **profile) as dst:
        dst.write(result, 1)
    # The dates of the images: a grid of 0.01° with the decimal year.
    with _open(CANOPY_ROOT + "CHM_acquisition_date.tif") as src:
        window = from_bounds(*box, transform=src.transform).round_offsets().round_lengths()
        dates = src.read(1, window=window, boundless=True, fill_value=0)
    dates = dates[dates > 0]
    log(f"canopy: {width} x {height} cells of {CANOPY_STEP_M} m, {float((result >= 3).mean()) * 100:.1f} % at 3 m or more, "
        f"images of {2000 + dates.min():.2f} to {2000 + dates.max():.2f}")
    return {"tiles": keys, "step_m": CANOPY_STEP_M, "share_3m": round(float((result >= 3).mean()), 4),
            # The file gives the years after 2000.
            "image_years": {"first": round(2000 + float(dates.min()), 2), "last": round(2000 + float(dates.max()), 2),
                            "mean": round(2000 + float(dates.mean()), 2)} if dates.size else {}}


def main() -> int:
    area = json.loads((GEO / "area.json").read_text(encoding="utf-8"))
    b = area["bbox"]
    box = (b["west"] - MARGIN_DEG, b["south"] - MARGIN_DEG, b["east"] + MARGIN_DEG, b["north"] + MARGIN_DEG)
    RAW.mkdir(parents=True, exist_ok=True)
    cover = read_worldcover(box, RAW / "worldcover.tif")
    canopy = read_canopy(box, int(area["epsg"]), RAW / "canopy.tif")
    write_json(RAW / "landcover.json", {
        "note": "Made by tools/geo/landcover.py (report 0005, D-0005-09; plan 0020, D8). Do not change by hand.",
        "worldcover": {"name": "ESA WorldCover 2021 v200", "license": "CC BY 4.0", "notice": WORLDCOVER_NOTICE,
                       "file": "worldcover.tif"} | cover,
        "canopy": {"name": "Meta and WRI High Resolution Canopy Height Maps (v1)", "license": "CC BY 4.0",
                   "notice": CANOPY_NOTICE, "file": "canopy.tif"} | canopy,
    })
    return 0


if __name__ == "__main__":
    sys.exit(main())
