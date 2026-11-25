#!/usr/bin/env python3
"""Plan 0031, D4 (step 1): before the export of the web build.

From data/web/web.json: writes the include and exclude filters of the preset
Web of export_presets.cfg (the near level of each building, data/geo/raw, and
the files of the build that the game does not read stay out; the JSON of the
build goes as PATH.gz), and makes the gzip copies of that JSON. The other
presets do not change: the desktop builds keep one whole pack.

Usage: python3 tools/web/prepare.py [--check]   (--check: only check the preset)
"""
import fnmatch
import gzip
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE_INCLUDE = ["data/*.json", "data/dialogue/*.json", "data/world/*.json"]
BASE_EXCLUDE = ["addons/gut/*", "tests/*", "playtests/*", "build/*", "docs/*", "tools/*"]


def config():
    return json.loads((ROOT / "data/web/web.json").read_text(encoding="utf-8"))


def packs():
    """Plan 0031, D5: the packs of data/web/packs.json."""
    path = ROOT / "data/web/packs.json"
    return json.loads(path.read_text(encoding="utf-8")).get("packs", []) if path.exists() else []


def pack_files():
    """The files of the packs, as paths of the project (with no res://)."""
    return [f.removeprefix("res://") for pack in packs() for f in pack["files"]]


def filters(cfg):
    include = BASE_INCLUDE + [g + ".gz" for g in cfg["gzip"]]
    exclude = BASE_EXCLUDE + cfg["left_out"] + cfg["gzip"] + [f"assets/world/{b}.glb" for b in cfg["buildings"]] + pack_files()
    return ", ".join(include), ", ".join(exclude)


def web_section(text):
    match = re.search(r'(\[preset\.(\d+)\]\s*\nname="Web".*?)(?=\n\[preset\.\d+\.options\])', text, re.S)
    if not match:
        sys.exit("export_presets.cfg has no preset Web")
    return match


def gzip_copies(cfg):
    left_out = cfg["left_out"]
    count = 0
    for path in sorted((ROOT / "data/geo/build").rglob("*.json")):
        rel = path.relative_to(ROOT).as_posix()
        if any(fnmatch.fnmatch(rel, pattern) for pattern in left_out):
            continue
        if not any(fnmatch.fnmatch(rel, pattern) for pattern in cfg["gzip"]):
            continue
        target = path.with_name(path.name + ".gz")
        data = path.read_bytes()
        # mtime=0: the same bytes for the same JSON.
        target.write_bytes(gzip.compress(data, compresslevel=9, mtime=0))
        count += 1
    return count


def main():
    cfg = config()
    include, exclude = filters(cfg)
    path = ROOT / "export_presets.cfg"
    text = path.read_text(encoding="utf-8")
    match = web_section(text)
    section = match.group(1)
    new = re.sub(r'^include_filter=".*"$', f'include_filter="{include}"', section, flags=re.M)
    new = re.sub(r'^exclude_filter=".*"$', f'exclude_filter="{exclude}"', new, flags=re.M)
    if "--check" in sys.argv:
        if new != section:
            sys.exit("The filters of the preset Web are not those of data/web/web.json: run python3 tools/web/prepare.py")
        print("The preset Web agrees with data/web/web.json.")
        return
    path.write_text(text[:match.start(1)] + new + text[match.end(1):], encoding="utf-8")
    print(f"The preset Web: {len(cfg['buildings'])} near levels, {len(cfg['left_out'])} patterns, and {len(pack_files())} files of packs out; {gzip_copies(cfg)} gzip copies.")
    if "--packs" in sys.argv:
        # One line for each pack: the id and its files (tools/web/deploy.sh makes them).
        for pack in packs():
            print("PACK " + pack["id"] + " " + " ".join(pack["files"]))


if __name__ == "__main__":
    main()
