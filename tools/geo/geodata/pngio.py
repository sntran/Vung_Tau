"""A small PNG writer and reader for 16-bit gray height files.

The game reads these files with its own decoder (scripts/geo/png16.gd),
because Godot changes 16-bit PNG files to 8 bits when it loads them. The
writer uses only the PNG filters "None" and "Up", so the game decoder can be
simple and fast.
"""

import struct
import zlib

import numpy as np


def _chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def write_gray16(path, values: np.ndarray) -> None:
    """Writes a 2D uint16 array. Row 0 is the top of the image."""
    values = np.ascontiguousarray(values, dtype=">u2")
    height, width = values.shape
    rows = values.view(np.uint8).reshape(height, width * 2)
    filtered = np.empty((height, width * 2 + 1), dtype=np.uint8)
    filtered[0, 0] = 0
    filtered[0, 1:] = rows[0]
    if height > 1:
        filtered[1:, 0] = 2
        filtered[1:, 1:] = rows[1:] - rows[:-1]  # The "Up" filter. uint8 wraps like PNG.
    header = struct.pack(">IIBBBBB", width, height, 16, 0, 0, 0, 0)
    data = b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", header) + _chunk(b"IDAT", zlib.compress(filtered.tobytes(), 9)) \
        + _chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(data)


def read_gray16(path) -> np.ndarray:
    """Reads a file of write_gray16(). The tests use it."""
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG file"
    pos, idat, width, height = 8, b"", 0, 0
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, color = struct.unpack(">IIBB", body[:10])
            assert depth == 16 and color == 0, "not a 16-bit gray PNG"
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    raw = np.frombuffer(zlib.decompress(idat), dtype=np.uint8).reshape(height, width * 2 + 1)
    rows = np.empty((height, width * 2), dtype=np.uint8)
    for r in range(height):
        kind = raw[r, 0]
        if kind == 0:
            rows[r] = raw[r, 1:]
        elif kind == 2:
            rows[r] = raw[r, 1:] + (rows[r - 1] if r > 0 else 0)
        else:
            raise ValueError(f"PNG filter {kind} is not supported")
    return rows.view(">u2").reshape(height, width).astype(np.uint16)
