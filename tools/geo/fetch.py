#!/usr/bin/env python3
"""Downloads the source data to data/geo/raw/ (plan 0004, R2 and R3). CI only.

Usage:
  python tools/geo/fetch.py                 Download the OSM data, the DEM, and the textures.
  python tools/geo/fetch.py --only dem      Download one part: osm, dem, or textures.

The OSM data comes from the Overpass API. If all Overpass servers fail, the
script downloads the Vietnam extract from Geofabrik and clips it with
"osmium extract" (package osmium-tool). The DEM comes from the public AWS
bucket of Copernicus GLO-30. The textures come from Poly Haven (CC0).
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

from geodata import landmarks  # noqa: E402
from geodata.config import RAW, TEXTURES, Config, load_json, write_json  # noqa: E402

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
}
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


def dem_tiles(bbox) -> list[str]:
    west, south, east, north = bbox
    names = []
    for lat in range(math.floor(south - DEM_MARGIN_DEG), math.floor(north + DEM_MARGIN_DEG) + 1):
        for lon in range(math.floor(west - DEM_MARGIN_DEG), math.floor(east + DEM_MARGIN_DEG) + 1):
            ns = f"N{lat:02d}" if lat >= 0 else f"S{-lat:02d}"
            ew = f"E{lon:03d}" if lon >= 0 else f"W{-lon:03d}"
            names.append(f"Copernicus_DSM_COG_10_{ns}_00_{ew}_00_DEM")
    return names


def fetch_dem(config: Config, raw: Path) -> dict:
    import rasterio
    from rasterio.merge import merge
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
        mosaic, transform = merge(sources, bounds=bounds)
        profile = sources[0].profile
        profile.update(driver="GTiff", height=mosaic.shape[1], width=mosaic.shape[2], transform=transform,
                       compress="deflate", predictor=3, tiled=False)
        profile.pop("blockxsize", None), profile.pop("blockysize", None)
        with rasterio.open(raw / "dem.tif", "w", **profile) as dst:
            dst.write(mosaic)
        for s in sources:
            s.close()
    return {"file": "dem.tif", "url": " ".join(urls), "license": LICENSES["dem"]}


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
    parser.add_argument("--only", choices=["osm", "dem", "textures"])
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
    steps = {"osm": fetch_osm, "dem": fetch_dem, "textures": fetch_textures}
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
    elif (raw / "fetch_problems.json").exists():
        (raw / "fetch_problems.json").unlink()
    return 0


if __name__ == "__main__":
    sys.exit(main())
