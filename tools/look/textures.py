"""The texture sets of the showcase of Bãi Trước (plan 0026, R12).

Reads data/look/textures.json and gets the maps of each Poly Haven asset
(CC0): diffuse, normal (OpenGL), and roughness, as JPEG files of the size of
the file, to assets/textures/look/ID/. Writes assets/textures/look/manifest.json:
for each set, the asset, its page, its authors, its side on the ground (m), and
the SHA-256 of each file.

    python tools/look/textures.py           # get the sets that are not there or changed
    python tools/look/textures.py --check   # no network: the files agree with the manifest
"""

import argparse
import hashlib
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "look" / "textures.json"
OUT = ROOT / "assets" / "textures" / "look"
MANIFEST = OUT / "manifest.json"
FILES = "https://api.polyhaven.com/files/{asset}"
INFO = "https://api.polyhaven.com/info/{asset}"
MAPS = {"diffuse": "Diffuse", "normal": "nor_gl", "roughness": "Rough"}
USER_AGENT = "vung-tau-textures/1"
LICENSE = "CC0 (Poly Haven)"
# The import of a map: as the ground textures (assets/textures/ground/), with
# mipmaps, and the normal map as a normal map.
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
compress/normal_map={normal}
mipmaps/generate=true
detect_3d/compress_to=1
"""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def get(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def check(config: dict, manifest: dict) -> list[str]:
    """The problems: a set that is not in the manifest, a file that is not there or not its hash."""
    problems = []
    sets = manifest.get("sets", {})
    for entry in config["sets"]:
        record = sets.get(entry["id"])
        if record is None or record.get("asset") != entry["asset"] or record.get("size") != config["size"]:
            problems.append(f"{entry['id']}: not in {MANIFEST.relative_to(ROOT)} as {entry['asset']}")
            continue
        for name, digest in record["files"].items():
            path = OUT / entry["id"] / name
            if not path.exists():
                problems.append(f"{entry['id']}/{name}: not there")
            elif sha256(path.read_bytes()) != digest:
                problems.append(f"{entry['id']}/{name}: not the file of the manifest")
    for set_id in sets:
        if set_id not in {e["id"] for e in config["sets"]}:
            problems.append(f"{set_id}: in the manifest, but not in {DATA.relative_to(ROOT)}")
    return problems


def fetch(entry: dict, size: str) -> dict:
    files = json.loads(get(FILES.format(asset=entry["asset"])))
    info = json.loads(get(INFO.format(asset=entry["asset"])))
    folder = OUT / entry["id"]
    folder.mkdir(parents=True, exist_ok=True)
    record = {"asset": entry["asset"], "size": size, "page": f"https://polyhaven.com/a/{entry['asset']}",
              "authors": sorted(info.get("authors", {})), "license": LICENSE,
              "size_m": round(float(info.get("dimensions", [1000])[0]) / 1000.0, 3), "files": {}}
    for name, key in MAPS.items():
        choice = files[key][size]
        kind = "jpg" if "jpg" in choice else "png"
        url = choice[kind]["url"]
        data = get(url)
        if "md5" in choice[kind] and hashlib.md5(data).hexdigest() != choice[kind]["md5"]:
            raise SystemExit(f"ERROR: the MD5 of {url} is not correct")
        file_name = f"{name}.{kind}"
        (folder / file_name).write_bytes(data)
        import_path = folder / f"{file_name}.import"
        if not import_path.exists():
            import_path.write_text(IMPORT.format(normal=1 if name == "normal" else 0), encoding="utf-8")
        record["files"][file_name] = sha256(data)
        print(f"{entry['id']}: {file_name} ({len(data) // 1024} KB) from {url}")
    return record


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    config = json.loads(DATA.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {"sets": {}}
    problems = check(config, manifest)
    if args.check:
        for problem in problems:
            print(f"ERROR: {problem}")
        if not problems:
            print(f"The {len(config['sets'])} texture sets agree with the manifest.")
        return 1 if problems else 0
    wanted = {p.split(":")[0].split("/")[0] for p in problems}
    sets = {k: v for k, v in manifest.get("sets", {}).items() if k in {e["id"] for e in config["sets"]}}
    for entry in config["sets"]:
        if entry["id"] in wanted or entry["id"] not in sets:
            sets[entry["id"]] = fetch(entry, config["size"])
    manifest = {"note": "Made by tools/look/textures.py from data/look/textures.json. Do not change by hand.",
                "sets": dict(sorted(sets.items()))}
    OUT.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
