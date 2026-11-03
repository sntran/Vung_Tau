"""Write instancing.glb: the test file of the EXT_mesh_gpu_instancing import.

Run: python3 tests/data/world/make_instancing.py

The file has the layout of a World GLB (World `docs/format.md`, "GLB"):

- Node "row": a box mesh with 16 instances in a row along x. Each
  instance has a TRANSLATION and a ROTATION (a quarter turn on y for
  the odd instances).
- Node "mirror": the same mesh with a node scale of [-1, 1, 1] and 2
  instances. World puts a mirror on the node, not on each instance.
- Node "scaled": the same mesh with 2 instances that have a SCALE, and
  a ROTATION of normalized 16-bit integers.
- Node "plain": the same mesh with no instances.

The same script gives the same bytes each time.
"""

import json
import math
import struct
from pathlib import Path

OUT = Path(__file__).with_name("instancing.glb")

# A box of 0.2 x 0.1 x 0.06 m: 8 points, 12 triangles.
HX, HY, HZ = 0.1, 0.03, 0.05
POINTS = [(x, y, z) for x in (-HX, HX) for y in (-HY, HY) for z in (-HZ, HZ)]
FACES = [
    (0, 1, 3), (0, 3, 2), (4, 6, 7), (4, 7, 5),  # -x, +x
    (0, 4, 5), (0, 5, 1), (2, 3, 7), (2, 7, 6),  # -y, +y
    (0, 2, 6), (0, 6, 4), (1, 5, 7), (1, 7, 3),  # -z, +z
]

binary = bytearray()
views = []
accessors = []


def add(data, count, kind, component=5126, target=None, bounds=None):
    """Add a buffer view and its accessor. Give the index of the accessor."""
    while len(binary) % 4:
        binary.append(0)
    view = {"buffer": 0, "byteOffset": len(binary), "byteLength": len(data)}
    if target:
        view["target"] = target
    binary.extend(data)
    views.append(view)
    accessor = {"bufferView": len(views) - 1, "componentType": component, "count": count, "type": kind}
    if bounds:
        accessor["min"], accessor["max"] = bounds
    if component == 5122:
        accessor["normalized"] = True
    accessors.append(accessor)
    return len(accessors) - 1


def floats(rows):
    return b"".join(struct.pack("<%df" % len(r), *r) for r in rows)


position = add(floats(POINTS), len(POINTS), "VEC3", target=34962,
               bounds=([-HX, -HY, -HZ], [HX, HY, HZ]))
indices = add(b"".join(struct.pack("<3H", *f) for f in FACES), 3 * len(FACES), "SCALAR", 5123, 34963)

quarter = (0.0, math.sin(math.pi / 4), 0.0, math.cos(math.pi / 4))
row_moves = [(0.25 * i, 0.0, 0.0) for i in range(16)]
row_turns = [quarter if i % 2 else (0.0, 0.0, 0.0, 1.0) for i in range(16)]
row = {
    "TRANSLATION": add(floats(row_moves), 16, "VEC3"),
    "ROTATION": add(floats(row_turns), 16, "VEC4"),
}
mirror = {"TRANSLATION": add(floats([(1.0, 0.0, 1.0), (1.5, 0.0, 1.0)]), 2, "VEC3")}
shorts = [tuple(round(c * 32767) for c in q) for q in [(0.0, 0.0, 0.0, 1.0), quarter]]
scaled = {
    "TRANSLATION": add(floats([(0.0, 0.0, 2.0), (0.5, 0.0, 2.0)]), 2, "VEC3"),
    "ROTATION": add(b"".join(struct.pack("<4h", *q) for q in shorts), 2, "VEC4", 5122),
    "SCALE": add(floats([(1.0, 1.0, 1.0), (2.0, 1.0, 0.5)]), 2, "VEC3"),
}

instancing = "EXT_mesh_gpu_instancing"
gltf = {
    "asset": {"version": "2.0", "generator": "Vũng Tàu test"},
    "extensionsUsed": [instancing],
    "scene": 0,
    "scenes": [{"name": "instancing", "nodes": [0]}],
    "nodes": [
        {"name": "instancing", "children": [1, 2, 3, 4]},
        {"name": "row", "mesh": 0, "extensions": {instancing: {"attributes": row}}},
        {"name": "mirror", "mesh": 0, "scale": [-1.0, 1.0, 1.0], "extensions": {instancing: {"attributes": mirror}}},
        {"name": "scaled", "mesh": 0, "extensions": {instancing: {"attributes": scaled}}},
        {"name": "plain", "mesh": 0, "translation": [0.0, 0.0, -1.0]},
    ],
    "meshes": [{"name": "brick", "primitives": [{"attributes": {"POSITION": position}, "indices": indices, "material": 0}]}],
    "materials": [{"name": "brick", "pbrMetallicRoughness": {"baseColorFactor": [0.6, 0.25, 0.15, 1.0]}}],
    "accessors": accessors,
    "bufferViews": views,
    "buffers": [{"byteLength": len(binary)}],
}

text = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode()
text += b" " * (-len(text) % 4)
binary.extend(b"\0" * (-len(binary) % 4))
total = 12 + 8 + len(text) + 8 + len(binary)
OUT.write_bytes(
    b"glTF" + struct.pack("<II", 2, total)
    + struct.pack("<I", len(text)) + b"JSON" + text
    + struct.pack("<I", len(binary)) + b"BIN\0" + bytes(binary)
)
print(f"{OUT}: {total} bytes")
