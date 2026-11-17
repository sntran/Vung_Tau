#!/usr/bin/env python3
"""Copies the open photos of the specs into docs/reference/photos/ (plan 0026, R17).

    python tools/photos/photos.py            # get the open photos that are not there, and write the credits
    python tools/photos/photos.py --check    # no network: each open photo has its copy and its credit
    python tools/photos/photos.py --other DIR  # get the photos that are not open into DIR (not the repository)

A photo is an entry of "photos" in data/world/specs/*.json and in
data/showcase/shots.json: url (the page), image (the file to get, or the page
for Wikimedia Commons), date, license, author, open, file, shows. An open photo
(CC0, CC BY, CC BY-SA, public domain) is copied to docs/reference/photos/FILE,
and docs/reference/photos/CREDITS.md lists its author, its license, its link,
and its date. A photo that is not open stays a link: with --other, CI puts it
in an artifact that it does not keep, so that the builder can look at it.

The workspace cannot reach upload.wikimedia.org, but it can reach the
thumbnails of Commons through Special:FilePath; CI can reach both.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPECS = ROOT / "data" / "world" / "specs"
SHOTS = ROOT / "data" / "showcase" / "shots.json"
OUT = ROOT / "docs" / "reference" / "photos"
OPEN_LICENSES = re.compile(r"^(CC0|CC BY(-SA)? [0-9.]+|CC BY(-SA)?|public domain|PD)", re.IGNORECASE)
NOT_OPEN = re.compile(r"\b(NC|ND)\b|all rights reserved", re.IGNORECASE)
AGENT = "vung-tau-photos/1"
WIDTH = 1920  # a standard size of the thumbnails of Commons (other sizes get HTTP 429)


def photos() -> list[dict]:
    """Each photo of the specs and the shots, with the file that names it."""
    result = []
    files = sorted(SPECS.glob("*.json")) if SPECS.exists() else []
    if SHOTS.exists():
        files.append(SHOTS)
    for path in files:
        data = json.loads(path.read_text(encoding="utf-8"))
        entries = list(data.get("photos", []))
        for shot in data.get("shots", []):
            entries.extend(shot.get("photos", []))
        for photo in entries:
            result.append({**photo, "_from": str(path.relative_to(ROOT))})
    return result


def problems(photo: dict) -> list[str]:
    """What is wrong with the record of a photo."""
    found = []
    where = f"{photo.get('_from', '?')}: {photo.get('url', '?')}"
    for key in ("url", "date", "license", "author", "open", "shows"):
        if key not in photo or photo[key] in ("", None):
            found.append(f"{where}: no \"{key}\"")
    license_text = str(photo.get("license", ""))
    is_open = bool(OPEN_LICENSES.match(license_text)) and not NOT_OPEN.search(license_text)
    if photo.get("open") and not is_open:
        found.append(f"{where}: \"open\" is true, but the license \"{license_text}\" is not open")
    if photo.get("open") and not photo.get("file"):
        found.append(f"{where}: an open photo has no \"file\" in docs/reference/photos/")
    if not photo.get("open") and photo.get("file"):
        found.append(f"{where}: a photo that is not open cannot have a copy (\"file\")")
    if str(photo.get("shows", "")).strip().lower() in ("not looked at", "?"):
        found.append(f"{where}: nobody looked at the photo (\"shows\")")
    return found


def image_url(photo: dict) -> str:
    """The URL of the file to get: a thumbnail of WIDTH px for Commons."""
    image = str(photo.get("image") or photo["url"])
    match = re.search(r"commons\.wikimedia\.org/wiki/File:(.+)$", image)
    if match:
        name = urllib.parse.unquote(match.group(1))
        return "https://commons.wikimedia.org/wiki/Special:FilePath/" + urllib.parse.quote(name) + f"?width={WIDTH}"
    return image


def get(url: str) -> bytes:
    for attempt in range(4):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": AGENT})
            with urllib.request.urlopen(request, timeout=60) as response:
                return response.read()
        except Exception as error:  # noqa: BLE001 - a network error: try again
            if attempt == 3:
                raise
            print(f"  {error}: again in {2 ** attempt} s")
            time.sleep(2 ** attempt)
    raise RuntimeError("not reached")


def credits(open_photos: list[dict]) -> str:
    lines = [
        "# Reference photos",
        "",
        "Copies of the open photos of the specs of World (`data/world/specs/`) and of the shots of plan 0026",
        "(R17). Made by `tools/photos/photos.py`; do not change by hand. Each photo keeps its license.",
        "",
        "| File | Author | License | Date | Link | Shows |",
        "|---|---|---|---|---|---|",
    ]
    seen = set()
    for photo in sorted(open_photos, key=lambda p: p["file"]):
        if photo["file"] in seen:
            continue
        seen.add(photo["file"])
        shows = str(photo["shows"]).replace("|", "/").replace("\n", " ")
        lines.append(f"| `{photo['file']}` | {photo['author']} | {photo['license']} | {photo['date']} | [page]({photo['url']}) | {shows} |")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="no network: check the records and the copies")
    parser.add_argument("--other", type=Path, help="get the photos that are not open into this folder")
    args = parser.parse_args()
    all_photos = photos()
    found = [p for photo in all_photos for p in problems(photo)]
    open_photos = [p for p in all_photos if p.get("open") and p.get("file")]
    if args.check:
        for photo in open_photos:
            if not (OUT / photo["file"]).exists():
                found.append(f"{photo['_from']}: {photo['url']}: no copy docs/reference/photos/{photo['file']}")
        if (OUT / "CREDITS.md").exists() or open_photos:
            if not (OUT / "CREDITS.md").exists() or (OUT / "CREDITS.md").read_text(encoding="utf-8") != credits(open_photos):
                found.append("docs/reference/photos/CREDITS.md does not agree with the specs: run tools/photos/photos.py")
        for line in found:
            print(f"ERROR: {line}")
        print(f"{len(all_photos)} photos, {len(open_photos)} open, {len(found)} problems.")
        return 1 if found else 0
    if found:
        for line in found:
            print(f"ERROR: {line}")
        return 1
    if args.other:
        args.other.mkdir(parents=True, exist_ok=True)
        index = []
        for number, photo in enumerate(p for p in all_photos if not p.get("open")):
            url = image_url(photo)
            name = f"{number:03d}.jpg"
            try:
                (args.other / name).write_bytes(get(url))
                index.append(f"{name}\t{photo['url']}\t{photo['_from']}")
                print(f"got {name}: {url}")
            except Exception as error:  # noqa: BLE001 - keep the others
                index.append(f"{name}\tNOT GOT ({error})\t{photo['url']}")
                print(f"NOT GOT {url}: {error}")
        (args.other / "index.tsv").write_text("\n".join(index) + "\n", encoding="utf-8")
        return 0
    OUT.mkdir(parents=True, exist_ok=True)
    for photo in open_photos:
        target = OUT / photo["file"]
        if target.exists():
            continue
        url = image_url(photo)
        print(f"get {photo['file']}: {url}")
        target.write_bytes(get(url))
    (OUT / "CREDITS.md").write_text(credits(open_photos), encoding="utf-8")
    print(f"{len(open_photos)} open photos in {OUT.relative_to(ROOT)}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
