#!/usr/bin/env python3
"""Downloads the source data to data/geo/raw/ (plan 0005, R2 and R3). CI only.

Usage:
  python tools/geo/fetch.py                 Download the OSM data, the DEM, and the textures.
  python tools/geo/fetch.py --only dem      Download one part: osm, dem, textures, bare_earth, or mainland.

The OSM data comes from the Overpass API. If all Overpass servers fail, the
script downloads the Vietnam extract from Geofabrik and clips it with
"osmium extract" (package osmium-tool). The DEM comes from the public AWS
bucket of Copernicus GLO-30. The textures come from Poly Haven (CC0).

The bare earth (plan 0009, R5b): a window of GEDTM30 v1.2 (OpenGeoHub, a COG
read over HTTP) and the tile of DeltaDTM v1.1 (4TU.ResearchData, the file of
Asia, read with range requests). Both are over EGM2008, as Copernicus. These
two sources answer from the workspace too (2026-11-21).
"""

import argparse
import datetime
import hashlib
import json
import math
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from geodata import httpzip, landmarks  # noqa: E402
from geodata.config import GEO, RAW, TEXTURES, Config, load_json, write_json  # noqa: E402

OVERPASS = ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter",
            "https://overpass.private.coffee/api/interpreter"]
GEOFABRIK = "https://download.geofabrik.de/asia/vietnam-latest.osm.pbf"
DEM_URL = "https://copernicus-dem-30m.s3.amazonaws.com/{name}/{name}.tif"
POLYHAVEN_FILES = "https://api.polyhaven.com/files/{id}"
# The ground textures (R12). Each one is a Poly Haven asset (CC0).
TEXTURE_SET = {"sand": "coast_sand_01", "grass": "leafy_grass", "rock": "rocky_terrain_02",
               "asphalt": "asphalt_02", "concrete": "brushed_concrete"}
TEXTURE_MAPS = {"diffuse": "Diffuse", "normal": "nor_gl", "roughness": "Rough"}
TEXTURE_SIZE = "1k"
LICENSES = {
    "osm": "ODbL 1.0, © OpenStreetMap contributors",
    "dem": "Copernicus DEM license, © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018",
    "texture": "CC0 (Poly Haven)",
    "gedtm30": "CC BY 4.0, GEDTM30 v1.2 (Ho et al., OpenGeoHub, DOI 10.5281/zenodo.18887460)",
    "deltadtm": "CC BY 4.0, DeltaDTM v1.1 (Pronk et al., Deltares, DOI 10.4121/21997565); "
                "from Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018",
}
# Plan 0009, R5b (D9): the models of the bare earth.
GEDTM30_URL = ("https://s3.opengeohub.org/global/dtm/v1.2/"
               "gedtm_rf_m_30m_s_20060101_20151231_go_epsg.4326.3855_v1.2.tif")
DELTADTM_ZIP = ("https://data.4tu.nl/file/1da2e70f-6c4d-4b03-86bd-b53e789cc629/"
                "672eba4c-1334-44c6-8119-8879ded25912")  # Asia.zip of DOI 10.4121/21997565 (v1.1)
DELTADTM_NODATA = -9999.0
# DeltaDTM has only the land below 30 m over EGM2008: a cell over it has the
# value 30 (the clip of its mask, 255), and no ground.
DELTADTM_CLIP_M = 30.0
USER_AGENT = "VungTau-game-geodata/1.0 (https://github.com/sntran/Vung_Tau)"
DEM_MARGIN_DEG = 0.01


def log(text: str) -> None:
    print(f"[fetch] {text}", flush=True)


def download(url: str, path: Path, data: bytes | None = None, tries: int = 3, timeout: int = 900) -> None:
    for attempt in range(1, tries + 1):
        try:
            request = urllib.request.Request(url, data=data, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=timeout) as response, open(path, "wb") as f:
                while True:
                    block = response.read(1 << 20)
                    if not block:
                        break
                    f.write(block)
            return
        except Exception as error:
            log(f"{url} failed ({error}), attempt {attempt} of {tries}")
            if attempt == tries:
                raise
            time.sleep(10 * attempt)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def overpass_query(bbox) -> str:
    west, south, east, north = bbox
    box = f"{south},{west},{north},{east}"
    return (f"[out:xml][timeout:900][maxsize:2000000000];"
            f"(node({box});way({box});relation[\"type\"=\"multipolygon\"]({box}););"
            f"(._;>;);out meta;")


def fetch_osm(config: Config, raw: Path) -> dict:
    target = raw / "osm.pbf"
    with tempfile.TemporaryDirectory() as tmp:
        xml = Path(tmp) / "osm.osm"
        query = urllib.parse.urlencode({"data": overpass_query(config.bbox)}).encode()
        source = None
        for server in OVERPASS:
            try:
                download(server, xml, data=query, tries=2)
                if xml.stat().st_size < 10000 or b"<remark>" in xml.read_bytes()[-2000:]:
                    raise RuntimeError("the answer is too small or has a remark (a timeout or an error)")
                source = server
                break
            except Exception as error:
                log(f"Overpass server {server} failed: {error}")
        if source is not None:
            subprocess.run(["osmium", "cat", "--overwrite", "-o", str(target), str(xml)], check=True)
        else:
            log("all Overpass servers failed, so use Geofabrik")
            pbf = Path(tmp) / "vietnam.osm.pbf"
            download(GEOFABRIK, pbf)
            west, south, east, north = config.bbox
            subprocess.run(["osmium", "extract", "--overwrite", "-s", "smart", "-b", f"{west},{south},{east},{north}",
                            "-o", str(target), str(pbf)], check=True)
            source = GEOFABRIK
    return {"file": "osm.pbf", "url": source, "license": LICENSES["osm"]}


def dem_tiles(bbox, margin: float = DEM_MARGIN_DEG) -> list[str]:
    west, south, east, north = bbox
    names = []
    for lat in range(math.floor(south - margin), math.floor(north + margin) + 1):
        for lon in range(math.floor(west - margin), math.floor(east + margin) + 1):
            ns = f"N{lat:02d}" if lat >= 0 else f"S{-lat:02d}"
            ew = f"E{lon:03d}" if lon >= 0 else f"W{-lon:03d}"
            names.append(f"Copernicus_DSM_COG_10_{ns}_00_{ew}_00_DEM")
    return names


def merge_on_grid(sources, bounds):
    """The mosaic of the tiles in bounds, on the grid of the tiles (plan 0009,
    R5b): merge() with the bounds of the box put the pixels of the tiles on the
    edges of the box, half a pixel (about 15 m) west and north of their place."""
    from rasterio.merge import merge
    first = sources[0].transform
    res_x, res_y = first.a, -first.e
    west, south, east, north = bounds
    west = first.c + math.floor((west - first.c) / res_x) * res_x
    east = first.c + math.ceil((east - first.c) / res_x) * res_x
    north = first.f - math.floor((first.f - north) / res_y) * res_y
    south = first.f - math.ceil((first.f - south) / res_y) * res_y
    return merge(sources, bounds=(west, south, east, north))


def fetch_dem(config: Config, raw: Path) -> dict:
    import rasterio
    west, south, east, north = config.bbox
    with tempfile.TemporaryDirectory() as tmp:
        files, urls = [], []
        for name in dem_tiles(config.bbox):
            url = DEM_URL.format(name=name)
            path = Path(tmp) / f"{name}.tif"
            download(url, path)
            files.append(path)
            urls.append(url)
        sources = [rasterio.open(f) for f in files]
        bounds = (west - DEM_MARGIN_DEG, south - DEM_MARGIN_DEG, east + DEM_MARGIN_DEG, north + DEM_MARGIN_DEG)
        mosaic, transform = merge_on_grid(sources, bounds)
        profile = sources[0].profile
        profile.update(driver="GTiff", height=mosaic.shape[1], width=mosaic.shape[2], transform=transform,
                       compress="deflate", predictor=3, tiled=False)
        profile.pop("blockxsize", None), profile.pop("blockysize", None)
        with rasterio.open(raw / "dem.tif", "w", **profile) as dst:
            dst.write(mosaic)
        for s in sources:
            s.close()
    return {"file": "dem.tif", "url": " ".join(urls), "license": LICENSES["dem"]}


def fetch_mainland(config: Config, raw: Path) -> dict:
    """Report 0009, Q14: the Copernicus DEM around the play area (data/geo/mainland.json:
    radius_m around the middle of the box), averaged to pixel_arcsec, to mainland.tif."""
    import numpy as np
    import rasterio
    from rasterio.enums import Resampling
    spec = load_json(GEO / "mainland.json")
    west, south, east, north = config.bbox
    lat, lon = (south + north) / 2.0, (west + east) / 2.0
    d_lat = float(spec["radius_m"]) / 111_320.0
    d_lon = d_lat / math.cos(math.radians(lat))
    box = (lon - d_lon, lat - d_lat, lon + d_lon, lat + d_lat)
    with tempfile.TemporaryDirectory() as tmp:
        files, urls = [], []
        for name in dem_tiles(box, margin=0.0):
            url = DEM_URL.format(name=name)
            path = Path(tmp) / f"{name}.tif"
            download(url, path)
            files.append(path)
            urls.append(url)
        sources = [rasterio.open(f) for f in files]
        mosaic, transform = merge_on_grid(sources, box)
        for s in sources:
            s.close()
    factor = max(1, int(round(float(spec["pixel_arcsec"]))))
    rows, cols = mosaic.shape[1] // factor, mosaic.shape[2] // factor
    data = mosaic[0, :rows * factor, :cols * factor].astype(np.float32)
    data = data.reshape(rows, factor, cols, factor).mean(axis=(1, 3))
    _write_window(raw / "mainland.tif", data, transform * transform.scale(factor, factor))
    return {"file": "mainland.tif", "url": " ".join(urls), "license": LICENSES["dem"],
            "note": f"Report 0009, Q14: {spec['radius_m'] / 1000:.0f} km around the middle of the box, "
                    f"the mean of {factor} x {factor} pixels"}


def _write_window(path: Path, data, transform) -> None:
    import rasterio
    profile = {"driver": "GTiff", "height": data.shape[0], "width": data.shape[1], "count": 1, "dtype": "float32",
               "crs": "EPSG:4326", "transform": transform, "nodata": float("nan"), "compress": "deflate", "predictor": 3}
    with rasterio.open(path, "w", **profile) as dst:
        dst.write(data, 1)


def fetch_bare_earth(config: Config, raw: Path) -> list[dict]:
    """Plan 0009, R5b: the windows of GEDTM30 and DeltaDTM over the box of the DEM, in meters
    over EGM2008, with NaN where a model has no value (the sea; DeltaDTM over 30 m)."""
    import numpy as np
    import rasterio
    from rasterio.windows import from_bounds
    west, south, east, north = config.bbox
    bounds = (west - DEM_MARGIN_DEG, south - DEM_MARGIN_DEG, east + DEM_MARGIN_DEG, north + DEM_MARGIN_DEG)
    records = []
    with rasterio.Env(GDAL_HTTP_USERAGENT=USER_AGENT, GDAL_DISABLE_READDIR_ON_OPEN="EMPTY_DIR"):
        with rasterio.open("/vsicurl/" + GEDTM30_URL) as src:
            window = from_bounds(*bounds, src.transform).round_offsets().round_lengths()
            data = src.read(1, window=window).astype("float32")
            if np.issubdtype(src.dtypes[0], np.integer):
                data /= 10.0  # GEDTM30 v1.1 and before: decimeters
            data[(data > 1e4) | (data < -1e3)] = np.nan
            _write_window(raw / "gedtm30.tif", data, src.window_transform(window))
    records.append({"file": "gedtm30.tif", "url": GEDTM30_URL, "license": LICENSES["gedtm30"]})
    tiles = [f"DeltaDTM_v1_1_{'N' if lat >= 0 else 'S'}{abs(lat):02d}{'E' if lon >= 0 else 'W'}{abs(lon):03d}.tif"
             for lat in range(math.floor(bounds[1]), math.floor(bounds[3]) + 1)
             for lon in range(math.floor(bounds[0]), math.floor(bounds[2]) + 1)]
    if len(tiles) != 1:
        raise RuntimeError(f"the box needs {len(tiles)} tiles of DeltaDTM; fetch_bare_earth reads one")
    with tempfile.TemporaryDirectory() as tmp:
        tile = Path(tmp) / tiles[0]
        httpzip.extract(DELTADTM_ZIP, tiles[0], tile, USER_AGENT)
        with rasterio.open(tile) as src:
            window = from_bounds(*bounds, src.transform).round_offsets().round_lengths()
            data = src.read(1, window=window).astype("float32")
            data[(data == DELTADTM_NODATA) | (data >= DELTADTM_CLIP_M - 0.01)] = np.nan
            _write_window(raw / "deltadtm.tif", data, src.window_transform(window))
    records.append({"file": "deltadtm.tif", "url": f"{DELTADTM_ZIP} ({tiles[0]})", "license": LICENSES["deltadtm"]})
    return records


def fetch_textures(_config: Config, _raw: Path) -> list[dict]:
    records = []
    for kind, asset in TEXTURE_SET.items():
        listing = Path(tempfile.mkdtemp()) / "files.json"
        download(POLYHAVEN_FILES.format(id=asset), listing)
        files = json.loads(listing.read_text())
        folder = TEXTURES / kind
        folder.mkdir(parents=True, exist_ok=True)
        for map_name, key in TEXTURE_MAPS.items():
            entry = files[key][TEXTURE_SIZE]["jpg" if "jpg" in files[key][TEXTURE_SIZE] else "png"]
            suffix = Path(urllib.parse.urlparse(entry["url"]).path).suffix
            path = folder / f"{map_name}{suffix}"
            download(entry["url"], path)
            if "md5" in entry and hashlib.md5(path.read_bytes()).hexdigest() != entry["md5"]:
                raise RuntimeError(f"the MD5 of {path} is not correct")
            records.append({"file": str(path.relative_to(TEXTURES.parents[2])), "url": entry["url"],
                            "license": LICENSES["texture"], "asset": asset,
                            "page": f"https://polyhaven.com/a/{asset}"})
    return records


def check_box(config: Config) -> list[str]:
    """The landmarks must be in the box (D5)."""
    problems = []
    for landmark in config.landmarks:
        hint = landmark.get("hint")
        if hint and not landmarks.in_box((hint["lon"], hint["lat"]), config.bbox):
            problems.append(f"{landmark['name_vi']} ({hint['lat']}, {hint['lon']}) is not in the box")
    return problems


def check_found(config: Config, raw: Path) -> list[str]:
    """After the download: each landmark that the data has must be in the box."""
    from geodata import osm
    data = osm.read(raw / "osm.pbf")
    problems = []
    log(f"the OSM data is from {data.lat_range[0]:.5f} to {data.lat_range[1]:.5f} N, "
        f"{data.lon_range[0]:.5f} to {data.lon_range[1]:.5f} E")
    for landmark in config.landmarks:
        best = landmarks.choose(landmark, landmarks.candidates(landmark, data))
        if best is None:
            problems.append(f"{landmark['name_vi']} is not in the OSM data of the box")
        elif not landmarks.in_box(best["lonlat"], config.bbox):
            problems.append(f"{landmark['name_vi']} at {best['lonlat']} is not in the box")
        else:
            log(f"found {landmark['name_vi']} at {best['lonlat']}")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", choices=["osm", "dem", "textures", "bare_earth", "mainland"])
    parser.add_argument("--raw", type=Path, default=RAW)
    args = parser.parse_args()
    config = Config()
    raw = args.raw
    raw.mkdir(parents=True, exist_ok=True)
    problems = check_box(config)
    for p in problems:
        log(f"problem: {p}")
    manifest_path = raw / "manifest.json"
    manifest = load_json(manifest_path) if manifest_path.exists() else {"files": []}
    by_file = {f["file"]: f for f in manifest["files"]}
    today = datetime.date.today().isoformat()
    steps = {"osm": fetch_osm, "dem": fetch_dem, "textures": fetch_textures, "bare_earth": fetch_bare_earth,
             "mainland": fetch_mainland}
    for name, step in steps.items():
        if args.only and args.only != name:
            continue
        log(f"download {name}")
        result = step(config, raw)
        for record in result if isinstance(result, list) else [result]:
            path = raw / record["file"] if name != "textures" else TEXTURES.parents[2] / record["file"]
            record["date"] = today
            record["sha256"] = sha256(path)
            record["bytes"] = path.stat().st_size
            by_file[record["file"]] = record
    manifest = {"note": "Made by tools/geo/fetch.py. Each file has its source, its date, its SHA-256, and its license.",
                "bbox": config.area["bbox"], "files": sorted(by_file.values(), key=lambda f: f["file"])}
    write_json(manifest_path, manifest)
    if not args.only or args.only == "osm":
        for p in check_found(config, raw):
            log(f"problem: {p}")
            problems.append(p)
    if problems:
        log(f"{len(problems)} problems. build.py writes them in the report.")
        write_json(raw / "fetch_problems.json", {"problems": problems})
    elif (raw / "fetch_problems.json").exists() and (not args.only or args.only == "osm"):
        # Only a fetch that checks the OSM extract knows that its problems are gone.
        (raw / "fetch_problems.json").unlink()
    return 0


if __name__ == "__main__":
    sys.exit(main())
