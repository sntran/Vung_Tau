#!/usr/bin/env python3
"""The sources of the sea floor (plan 0005, R8g). CI only, like fetch.py.

Usage:
  python tools/geo/intertidal.py              Read the images and GEBCO, and write the files.
  python tools/geo/intertidal.py --limit 20   Use only the first 20 images (a quick test).

The intertidal zone: the heights of each 10 m pixel between the lowest and
the highest tide, with the pixel method of DEA Intertidal (geodata/intertidal.py),
from the Sentinel-2 L2A images of 2017 to 2020 (Earth Search on AWS) and the
EOT20 sea level at the time of each image (data/geo/build/tide.json, so run
tide.py first). The deeper water: a window of the GEBCO 2025 grid.

It writes data/geo/raw/intertidal.tif (heights in meters above mean sea
level, NaN where a pixel has no value), data/geo/raw/gebco.tif (heights in
meters), and data/geo/raw/intertidal.json (the images, the sources, and the
licenses). build.py reads them.
"""

import argparse
import datetime
import hashlib
import json
import sys
import time
import urllib.request
from pathlib import Path

import numpy as np
import rasterio
from rasterio.warp import transform_bounds
from rasterio.windows import from_bounds

sys.path.insert(0, str(Path(__file__).resolve().parent))

from geodata import intertidal, tidecalc  # noqa: E402
from geodata.config import BUILD, GEO, RAW, Config, write_json  # noqa: E402

STAC = "https://earth-search.aws.element84.com/v1/search"
COLLECTION = "sentinel-2-l2a"
YEARS = ("2017-01-01T00:00:00Z", "2020-12-31T23:59:59Z")
MAX_CLOUD = 60
GEBCO_URL = ("https://dap.ceda.ac.uk/bodc/gebco/global/gebco_2025/ice_surface_elevation/geotiff/"
             "gebco_2025_n90.0_s0.0_w90.0_e180.0.tif")
GEBCO_CITATION = ("GEBCO Compilation Group (2025) GEBCO 2025 Grid (doi:10.5285/37c52e96-24ea-67ce-e063-7086abc05f29). "
                  "Public domain, with the GEBCO terms of use.")
SENTINEL_NOTICE = "Contains modified Copernicus Sentinel data 2017–2020"
METHOD = ("The pixel method of DEA Intertidal (Geoscience Australia, "
          "https://knowledge.dea.ga.gov.au/data/product/dea-intertidal)")
# The tide point of tide.json for the images.
TIDE_POINT = "bai_truoc"
RETRIES = 4


def log(text: str) -> None:
    print(f"[intertidal] {text}", flush=True)


def _post(url: str, body: dict) -> dict:
    request = urllib.request.Request(url, json.dumps(body).encode(), {"Content-Type": "application/json"})
    for attempt in range(RETRIES):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                return json.load(response)
        except OSError as error:
            if attempt == RETRIES - 1:
                raise
            log(f"retry after {error}")
            time.sleep(2 ** (attempt + 1))
    return {}


def search(bbox: dict) -> list[dict]:
    """The Sentinel-2 L2A images over the box, with less than MAX_CLOUD % cloud,
    of the tile that has the most images."""
    body = {"collections": [COLLECTION], "bbox": [bbox["west"], bbox["south"], bbox["east"], bbox["north"]],
            "datetime": f"{YEARS[0]}/{YEARS[1]}", "limit": 200, "query": {"eo:cloud_cover": {"lt": MAX_CLOUD}}}
    items = []
    while True:
        page = _post(STAC, body)
        items += page.get("features", [])
        following = [link for link in page.get("links", []) if link.get("rel") == "next"]
        if not following:
            break
        body = following[0].get("body", body)
    tiles: dict[str, list[dict]] = {}
    for item in items:
        p = item["properties"]
        tile = f"{p.get('mgrs:utm_zone')}{p.get('mgrs:latitude_band')}{p.get('mgrs:grid_square')}"
        tiles.setdefault(tile, []).append(item)
    tile, chosen = max(tiles.items(), key=lambda kv: len(kv[1]))
    log(f"{len(items)} images, {len(chosen)} on the tile {tile}")
    return sorted(chosen, key=lambda item: item["properties"]["datetime"])


def _read(href: str, bounds_lonlat: tuple, shape=None):
    for attempt in range(RETRIES):
        try:
            with rasterio.open("/vsicurl/" + href) as src:
                bounds = transform_bounds("EPSG:4326", src.crs, *bounds_lonlat)
                window = from_bounds(*bounds, transform=src.transform).round_offsets().round_lengths()
                data = src.read(1, window=window, boundless=True, fill_value=0)
                return data, src.window_transform(window), src.crs
        except rasterio.errors.RasterioIOError as error:
            if attempt == RETRIES - 1:
                raise
            log(f"retry after {error}")
            time.sleep(2 ** (attempt + 1))
    return None


def read_images(items: list[dict], bounds_lonlat: tuple, tide: dict) -> tuple:
    """The observations (WET, DRY, UNCLEAR) and the sea level of each image."""
    observations, levels, used = [], [], []
    transform = crs = None
    for index, item in enumerate(items):
        assets = item["assets"]
        green, transform, crs = _read(assets["green"]["href"], bounds_lonlat)
        nir, _, _ = _read(assets["nir"]["href"], bounds_lonlat)
        scl, _, _ = _read(assets["scl"]["href"], bounds_lonlat)
        # The scene classes have 20 m pixels.
        scl = np.repeat(np.repeat(scl, 2, axis=0), 2, axis=1)[:green.shape[0], :green.shape[1]]
        if scl.shape != green.shape or nir.shape != green.shape:
            log(f"{item['id']}: the bands have different sizes, not used")
            continue
        when = datetime.datetime.fromisoformat(item["properties"]["datetime"].replace("Z", "+00:00"))
        level = float(tidecalc.level(tide, TIDE_POINT, np.array([when.timestamp()]))[0])
        seen = intertidal.observe(green, nir, scl)
        clear = float((seen != intertidal.UNCLEAR).mean())
        observations.append(seen)
        levels.append(level)
        used.append({"id": item["id"], "time": item["properties"]["datetime"], "sea_level_m": round(level, 3),
                     "cloud_cover": item["properties"].get("eo:cloud_cover"), "clear": round(clear, 3)})
        log(f"{index + 1}/{len(items)} {item['id']}: sea {level:+.2f} m, {clear:.0%} clear")
    return np.stack(observations), np.array(levels), used, transform, crs


def read_gebco(bounds_lonlat: tuple, path: Path) -> None:
    data, transform, crs = _read(GEBCO_URL, bounds_lonlat)
    profile = {"driver": "GTiff", "dtype": "int16", "width": data.shape[1], "height": data.shape[0], "count": 1,
               "crs": crs, "transform": transform, "compress": "deflate"}
    with rasterio.open(path, "w", **profile) as out:
        out.write(data.astype(np.int16), 1)
    log(f"GEBCO {data.shape[1]} x {data.shape[0]} cells, from {data.min()} to {data.max()} m")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--raw", type=Path, default=RAW)
    parser.add_argument("--tide", type=Path, default=BUILD / "tide.json")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--cache", type=Path, default=None,
                        help="A .npz file for the observations: read it when it is there, or write it.")
    args = parser.parse_args()
    bbox = Config(GEO).area["bbox"]
    bounds = (bbox["west"], bbox["south"], bbox["east"], bbox["north"])
    tide = json.loads(args.tide.read_text(encoding="utf-8"))
    args.raw.mkdir(parents=True, exist_ok=True)
    read_gebco(bounds, args.raw / "gebco.tif")
    if args.cache is not None and args.cache.exists():
        cached = np.load(args.cache, allow_pickle=True)
        observations, levels = cached["observations"], cached["levels"]
        used, transform, crs = list(cached["used"]), rasterio.Affine(*cached["transform"]), str(cached["crs"])
        log(f"{len(levels)} images from the cache {args.cache}")
    else:
        items = search(bbox)
        if args.limit:
            items = items[:args.limit]
        observations, levels, used, transform, crs = read_images(items, bounds, tide)
        if args.cache is not None:
            np.savez_compressed(args.cache, observations=observations, levels=levels, used=np.array(used, dtype=object),
                                transform=np.array(list(transform)[:6]), crs=str(crs))
    # In blocks of rows, so that the sums of all images fit in the memory.
    heights = np.full(observations.shape[1:], np.nan, dtype=np.float32)
    for row in range(0, heights.shape[0], 64):
        heights[row:row + 64], _ = intertidal.elevations(levels, observations[:, row:row + 64])
    profile = {"driver": "GTiff", "dtype": "float32", "width": heights.shape[1], "height": heights.shape[0], "count": 1,
               "crs": crs, "transform": transform, "nodata": float("nan"), "compress": "deflate", "predictor": 3}
    with rasterio.open(args.raw / "intertidal.tif", "w", **profile) as out:
        out.write(heights, 1)
    valid = np.isfinite(heights)
    if not valid.any():
        raise SystemExit("no pixel has a height: too few clear images")
    log(f"{int(valid.sum())} pixels with a height, from {np.nanmin(heights):+.2f} to {np.nanmax(heights):+.2f} m")
    write_json(args.raw / "intertidal.json", {
        "note": "Made by tools/geo/intertidal.py (plan 0005, R8g). Do not change by hand.",
        "date": datetime.date.today().isoformat(),
        "method": METHOD,
        "parameters": {"min_clear": intertidal.MIN_CLEAR, "min_share": intertidal.MIN_SHARE,
                       "max_error": intertidal.MAX_ERROR, "water_index": "NDWI (green, near infrared) > 0",
                       "not_clear": list(intertidal.NOT_CLEAR), "max_cloud_cover": MAX_CLOUD, "tide_point": TIDE_POINT},
        "sentinel": {"notice": SENTINEL_NOTICE, "stac": STAC, "collection": COLLECTION, "years": list(YEARS),
                     "images": used},
        "gebco": {"citation": GEBCO_CITATION, "url": GEBCO_URL},
        "files": [{"file": name, "sha256": sha256(args.raw / name)} for name in ("intertidal.tif", "gebco.tif")],
        "pixels": {"with_height": int(valid.sum()), "total": int(valid.size),
                   "min_m": round(float(np.nanmin(heights)), 2), "max_m": round(float(np.nanmax(heights)), 2)},
    })
    return 0


if __name__ == "__main__":
    sys.exit(main())
