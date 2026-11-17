#!/usr/bin/env python3
"""Checks the specs of the models for World (docs/world-specs.md, plan 0026, D5).

    python tools/world/specs.py          # check data/world/specs/*.json
    python tools/world/specs.py --list   # also list the values with the status Check

A spec is data/world/specs/ID.json: id, what, uses, year, photos, envelope,
parts, levels, checks, and status. Each value of the envelope and of the parts
has an entry in "status", keyed by its path ("envelope.height",
"parts.pole.sizes.height", "parts.pole.color", ...): {"status": "Confirmed",
"Source", or "Check", "how": how it was measured or why it is a guess,
"photos": the numbers of the photos it comes from}. A value with "Source"
names its photos or its page. World builds a spec with a Check value, but the
game does not use the model before I decide the value.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPECS = ROOT / "data" / "world" / "specs"
FIELDS = ("id", "what", "uses", "year", "photos", "envelope", "parts", "levels", "checks", "status")
STATUSES = ("Confirmed", "Source", "Check")
ROLES = ("concrete", "granite", "plaster", "paint", "metal", "glass", "tile", "wood", "plant", "cloth",
         "skin", "hair", "emissive", "rubber", "stone", "plastic")
SHAPES = ("box", "cylinder", "profile", "arc", "sweep", "sphere", "cone", "plane", "world")
COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")


def load() -> list[tuple[Path, dict]]:
    return [(path, json.loads(path.read_text(encoding="utf-8"))) for path in sorted(SPECS.glob("*.json"))]


def values(spec: dict) -> list[str]:
    """The paths of the values of a spec that need a status."""
    paths = []
    for key in ("width", "depth", "height"):
        if key in spec.get("envelope", {}):
            paths.append(f"envelope.{key}")
    for part in spec.get("parts", []):
        name = part.get("name", "?")
        for key in part.get("sizes", {}):
            paths.append(f"parts.{name}.sizes.{key}")
        for key in ("at", "count", "spacing", "color"):
            if key in part:
                paths.append(f"parts.{name}.{key}")
    return paths


def problems(spec: dict, name: str = "") -> list[str]:
    found = []
    where = name or spec.get("id", "?")
    for key in FIELDS:
        if key not in spec:
            found.append(f"{where}: no \"{key}\"")
    if name and spec.get("id") and Path(name).stem != spec["id"]:
        found.append(f"{where}: the file name is not the id \"{spec['id']}\"")
    if spec.get("year") != 2019:
        found.append(f"{where}: the year is not 2019")
    for number, photo in enumerate(spec.get("photos", [])):
        for key in ("url", "date", "license", "author", "open", "shows"):
            if key not in photo:
                found.append(f"{where}: photo {number} has no \"{key}\"")
        if photo.get("open") and not photo.get("file"):
            found.append(f"{where}: photo {number} is open and has no \"file\" (R17)")
        if str(photo.get("shows", "")).strip().lower() in ("", "not looked at"):
            found.append(f"{where}: photo {number}: nobody looked at it")
    envelope = spec.get("envelope", {})
    for key in ("width", "depth", "height", "tolerance"):
        if not isinstance(envelope.get(key), (int, float)):
            found.append(f"{where}: the envelope has no number \"{key}\"")
    names = set()
    for part in spec.get("parts", []):
        part_name = part.get("name", "")
        if not part_name or part_name in names:
            found.append(f"{where}: a part has no name or the same name as another part: \"{part_name}\"")
        names.add(part_name)
        if part.get("shape") not in SHAPES:
            found.append(f"{where}: part {part_name}: the shape \"{part.get('shape')}\" is not one of {SHAPES}")
        if part.get("role") not in ROLES:
            found.append(f"{where}: part {part_name}: the role \"{part.get('role')}\" is not one of {ROLES}")
        if "color" in part and not COLOR.match(str(part["color"])):
            found.append(f"{where}: part {part_name}: the color \"{part['color']}\" is not sRGB #RRGGBB")
        for key, value in part.get("sizes", {}).items():
            if not isinstance(value, (int, float)) or value <= 0:
                found.append(f"{where}: part {part_name}: the size \"{key}\" is not a number over 0")
    levels = spec.get("levels", {})
    for key in ("near", "mid", "far"):
        if not isinstance(levels.get(key), int):
            found.append(f"{where}: the levels have no triangle limit \"{key}\"")
    if isinstance(levels.get("far"), int) and levels["far"] > 300:
        found.append(f"{where}: the far level is over 300 triangles (plan 0023, D5)")
    if not spec.get("checks"):
        found.append(f"{where}: no checks for the review sheet")
    status = spec.get("status", {})
    photo_count = len(spec.get("photos", []))
    for path in values(spec):
        entry = status.get(path)
        if not isinstance(entry, dict):
            found.append(f"{where}: the value {path} has no status")
            continue
        if entry.get("status") not in STATUSES:
            found.append(f"{where}: {path}: the status \"{entry.get('status')}\" is not one of {STATUSES}")
        if not str(entry.get("how", "")).strip():
            found.append(f"{where}: {path}: no \"how\" (how it was measured, or why it is a guess)")
        if entry.get("status") == "Source" and not entry.get("photos") and not entry.get("page"):
            found.append(f"{where}: {path}: a Source value names no photo and no page")
        for number in entry.get("photos", []):
            if not isinstance(number, int) or number < 0 or number >= photo_count:
                found.append(f"{where}: {path}: there is no photo {number}")
    for path in status:
        if path not in values(spec):
            found.append(f"{where}: the status of {path} is for no value of the spec")
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true", help="list the values with the status Check")
    args = parser.parse_args()
    specs = load()
    found = []
    for path, spec in specs:
        found.extend(problems(spec, path.name))
    for line in found:
        print(f"ERROR: {line}")
    checks = 0
    for path, spec in specs:
        for key, entry in spec.get("status", {}).items():
            if isinstance(entry, dict) and entry.get("status") == "Check":
                checks += 1
                if args.list:
                    print(f"Check: {spec.get('id')}: {key}: {entry.get('how')}")
    print(f"{len(specs)} specs, {checks} values with the status Check, {len(found)} problems.")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
