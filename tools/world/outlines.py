#!/usr/bin/env python3
"""The outline of each level of a model of World seen from the side (report
0026, D-0026-32). The mid level of a blue pole showed a large cone, and the far
level of the fence of the Grand Hotel showed wedges: a collapse to a small
budget can join thin parts. The outline of the mid and the far level covers
about the same area as the outline of the near level (MAX_CHANGE).

    python tools/world/outlines.py            # each model of the lock with a near level
    python tools/world/outlines.py ID --png build/look/ID_outlines.png

No network and no Godot: it reads the GLB files of assets/world/.
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets" / "world"
LOCK = ROOT / "data" / "world" / "lock.json"
SUFFIX = {"near": ".glb", "mid": ".mid.glb", "far": ".far.glb"}
# The side: the z axis of the model (its front looks to +z) across, y up.
SIDE = (2, 1)
FRONT = (0, 1)
MAX_CHANGE = 0.3
PIXELS = 300


def _glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    length = struct.unpack_from("<I", data, 8)[0]
    offset, doc, binary = 12, {}, b""
    while offset < length:
        size, kind = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8:offset + 8 + size]
        if kind == 0x4E4F534A:
            doc = json.loads(chunk)
        else:
            binary = chunk
        offset += 8 + size
    return doc, binary


def _accessor(doc: dict, binary: bytes, index: int):
    import numpy as np
    a = doc["accessors"][index]
    view = doc["bufferViews"][a["bufferView"]]
    kind = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[a["componentType"]]
    count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    item = np.dtype(kind).itemsize * count
    stride = view.get("byteStride", 0) or item
    raw = np.frombuffer(binary, dtype=np.uint8, count=stride * (a["count"] - 1) + item, offset=start)
    rows = np.lib.stride_tricks.as_strided(raw, shape=(a["count"], item), strides=(stride, 1))
    return np.frombuffer(rows.copy().tobytes(), dtype=kind).reshape(a["count"], count).astype(float)


def _matrix(node: dict):
    import numpy as np
    if "matrix" in node:
        return np.array(node["matrix"], dtype=float).reshape(4, 4).T
    x, y, z, w = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    turn = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    m = np.eye(4)
    m[:3, :3] = turn * np.array(node.get("scale", [1.0, 1.0, 1.0]))
    m[:3, 3] = node.get("translation", [0.0, 0.0, 0.0])
    return m


def triangles(path: Path):
    """The triangles of a GLB (n x 3 x 3) in the axes of the model. A node with
    EXT_mesh_gpu_instancing counts one time (its outline is the same shape)."""
    import numpy as np
    doc, binary = _glb(path)
    found = []

    def walk(index: int, parent) -> None:
        node = doc["nodes"][index]
        m = parent @ _matrix(node)
        if "mesh" in node:
            for primitive in doc["meshes"][node["mesh"]]["primitives"]:
                points = _accessor(doc, binary, primitive["attributes"]["POSITION"])
                points = (m @ np.c_[points, np.ones(len(points))].T).T[:, :3]
                if "indices" in primitive:
                    order = _accessor(doc, binary, primitive["indices"]).astype(int).ravel()
                else:
                    order = np.arange(len(points))
                found.append(points[order].reshape(-1, 3, 3))
        for child in node.get("children", []):
            walk(child, m)

    for root in doc["scenes"][doc.get("scene", 0)]["nodes"]:
        walk(root, np.eye(4))
    return np.concatenate(found) if found else np.zeros((0, 3, 3))


def outline(tris, axes: tuple[int, int], box: tuple[float, float, float, float], pixels: int = PIXELS):
    """The outline as a picture (L): the triangles drawn on the plane of the axes."""
    from PIL import Image, ImageDraw
    u0, v0, u1, v1 = box
    scale = pixels / max(u1 - u0, v1 - v0, 1e-6)
    img = Image.new("L", (int((u1 - u0) * scale) + 2, int((v1 - v0) * scale) + 2), 0)
    pen = ImageDraw.Draw(img)
    a, b = axes
    for t in tris:
        pen.polygon([((p[a] - u0) * scale, (v1 - p[b]) * scale) for p in t], fill=255)
    return img


def levels_of(model_id: str) -> list[str]:
    return [level for level in ("near", "mid", "far") if (ASSETS / f"{model_id}{SUFFIX[level]}").exists()]


def areas(model_id: str, axes: tuple[int, int] = SIDE) -> tuple[dict[str, float], dict]:
    """The area of the outline of each level (a part of the area of the near level), and the pictures."""
    import numpy as np
    tris = {level: triangles(ASSETS / f"{model_id}{SUFFIX[level]}") for level in levels_of(model_id)}
    points = np.concatenate([t.reshape(-1, 3) for t in tris.values() if len(t)])
    a, b = axes
    box = (points[:, a].min(), points[:, b].min(), points[:, a].max(), points[:, b].max())
    pictures = {level: outline(t, axes, box) for level, t in tris.items()}
    counts = {level: float(np.asarray(p).astype(bool).sum()) for level, p in pictures.items()}
    first = max(counts[next(iter(counts))], 1.0)
    return {level: c / first for level, c in counts.items()}, pictures


def problems(ids: list[str] | None = None) -> list[str]:
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    found = []
    for model_id in ids or sorted(lock["models"]):
        if "near" not in levels_of(model_id) or len(levels_of(model_id)) < 2:
            continue
        parts, _ = areas(model_id)
        for level, part in parts.items():
            if abs(part - 1.0) > MAX_CHANGE:
                found.append(f"{model_id}: the outline of the {level} level from the side is {part:.2f} of the near level "
                             f"(from {1 - MAX_CHANGE:.2f} to {1 + MAX_CHANGE:.2f})")
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("ids", nargs="*")
    parser.add_argument("--png", help="the outlines of the levels of one model side by side")
    args = parser.parse_args()
    if args.png and args.ids:
        from PIL import Image
        _, pictures = areas(args.ids[0])
        pics = list(pictures.values())
        page = Image.new("L", (sum(p.width + 10 for p in pics), max(p.height for p in pics)), 40)
        x = 0
        for p in pics:
            page.paste(p, (x, 0))
            x += p.width + 10
        Path(args.png).parent.mkdir(parents=True, exist_ok=True)
        page.save(args.png)
    found = problems(args.ids or None)
    for line in found:
        print(f"ERROR: {line}")
    print(f"{len(found)} levels with another outline.")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
