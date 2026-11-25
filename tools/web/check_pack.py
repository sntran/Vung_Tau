#!/usr/bin/env python3
"""Plan 0031, R2: check the web pack after the export. It fails when a near
level of a building of World, a file of data/geo/raw, or another file that
data/web/web.json leaves out is in the pack. It also gives the sizes by part.

Usage: python3 tools/web/check_pack.py build/web/index.pck
"""
import collections
import fnmatch
import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def files_of(pck):
    """The files of a pack of Godot 4 (format 2 to 4): [(path, size)]."""
    with open(pck, "rb") as f:
        if f.read(4) != b"GDPC":
            raise SystemExit(f"{pck} is not a pack of Godot")
        version, _major, _minor, _patch = struct.unpack("<4I", f.read(16))
        directory = 0
        if version >= 2:
            struct.unpack("<IQ", f.read(12))
        if version >= 3:
            directory, = struct.unpack("<Q", f.read(8))
            f.seek(directory)
        else:
            f.read(64)
        count, = struct.unpack("<I", f.read(4))
        out = []
        for _ in range(count):
            n, = struct.unpack("<I", f.read(4))
            name = f.read(n).rstrip(b"\0").decode("utf-8", "replace")
            _offset, size = struct.unpack("<QQ", f.read(16))
            f.read(16 + 4)
            out.append((name, size))
        return out


def main():
    pck = sys.argv[1] if len(sys.argv) > 1 else "build/web/index.pck"
    cfg = json.loads((ROOT / "data/web/web.json").read_text(encoding="utf-8"))
    files = files_of(pck)
    bad = []
    parts = collections.Counter()
    for name, size in files:
        level = re.match(r"\.godot/imported/([^/]+?)\.(mid\.|far\.)?glb-", name)
        if level and not level.group(2) and level.group(1) in cfg["buildings"]:
            bad.append(f"the near level of the building {level.group(1)}: {name}")
        if any(fnmatch.fnmatch(name, pattern) for pattern in cfg["left_out"] + cfg["gzip"]):
            bad.append(f"a file that the web pack leaves out: {name}")
        if level:
            parts["models of World, " + (level.group(2) or "near.").rstrip(".") + " levels"] += size
        elif name.startswith("data/geo/build"):
            parts["data/geo/build"] += size
        elif ".ctex" in name or ".image" in name:
            parts["textures"] += size
        else:
            parts["other"] += size
    total = sum(size for _, size in files)
    print(f"{pck}: {len(files)} files, {total / 1e6:.1f} MB")
    for part, size in parts.most_common():
        print(f"  {size / 1e6:7.1f} MB  {part}")
    if bad:
        print("\n".join(bad[:20]))
        sys.exit(f"The web pack has {len(bad)} files that it must leave out (plan 0031, R2).")


if __name__ == "__main__":
    main()
