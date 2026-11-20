#!/usr/bin/env python3
"""Puts the areas that a photo shows next to the photo (report 0026, D-0026-30).

    python tools/showcase/lawn_sheet.py

Each item of "drawn" in data/showcase/bai_truoc.json (part "ground": a lawn
or a bed that a photo shows and OpenStreetMap does not have) has an outline in
game (x, z), the photo, the points of the outline on the photo, and the camera
of the photo (its eye in game meters, heading, pitch, roll, and the horizontal
field of view in degrees; a heading of 0 looks to +Z). The sheet
docs/showcase/south_end_lawns.jpg has two parts:

- left: the photo with the outline (red) and the ways of OpenStreetMap (the
  edges of the roads in magenta, the paths in orange) through the camera, then
  the part of the photo round the outline at a larger size;
- right: the map with the lawns (green), the paving (grey), and the beds
  (brown) of the build (data/geo/build/showcase_ground.png), the same ways,
  and the outline (red).

The outline is on the ways of OpenStreetMap and the shore of the build; the
photo shows what the area is. The check (--check) says how far each point of
the outline goes through the camera from its point on the photo. (A point of
the photo does not give a place: a pixel of an edge over the water, such as a
parapet, goes down past the edge to the sea floor.)
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "geo"))
from geodata.pngio import read_gray16  # noqa: E402

CONFIG = ROOT / "data" / "showcase" / "bai_truoc.json"
PHOTOS = ROOT / "docs" / "reference" / "photos"
BUILD = ROOT / "data" / "geo" / "build"
OUT = ROOT / "docs" / "showcase" / "south_end_lawns.jpg"
PATHS = {"footway", "path", "pedestrian", "steps"}
MAP_SCALE = 5  # pixels for each meter
MAP_MARGIN = 25.0  # meters round the outlines

_heights: dict = {}


def ground(x: float, z: float) -> float:
    """The height of the ground of the build (chunks of 256 m, cells of 2 m)."""
    key = (math.floor(x / 256), math.floor(z / 256))
    if key not in _heights:
        path = BUILD / "height" / f"{key[0]}_{key[1]}.png"
        _heights[key] = read_gray16(path).astype(np.float64) * 0.01 - 20.0 if path.exists() else None
    grid = _heights[key]
    if grid is None:
        return 0.0
    col = (x - key[0] * 256) / 2.0
    row = (z - key[1] * 256) / 2.0
    c0 = min(max(int(math.floor(col)), 0), grid.shape[1] - 2)
    r0 = min(max(int(math.floor(row)), 0), grid.shape[0] - 2)
    fc = min(max(col - c0, 0.0), 1.0)
    fr = min(max(row - r0, 0.0), 1.0)
    top = grid[r0, c0] * (1 - fc) + grid[r0, c0 + 1] * fc
    bottom = grid[r0 + 1, c0] * (1 - fc) + grid[r0 + 1, c0 + 1] * fc
    return float(top * (1 - fr) + bottom * fr)


class Camera:
    def __init__(self, cfg: dict, width: int, height: int):
        self.eye = np.array(cfg["eye"], dtype=float)
        h, p, r = (math.radians(cfg[k]) for k in ("heading", "pitch", "roll"))
        f = np.array([math.sin(h) * math.cos(p), math.sin(p), math.cos(h) * math.cos(p)])
        right = np.cross(f, [0.0, 1.0, 0.0])
        right /= np.linalg.norm(right)
        up = np.cross(right, f)
        self.f = f
        self.right = math.cos(r) * right + math.sin(r) * up
        self.up = -math.sin(r) * right + math.cos(r) * up
        self.w, self.h = width, height
        self.k = (width / 2) / math.tan(math.radians(cfg["hfov"] / 2))

    def project(self, point) -> tuple[float, float] | None:
        d = np.asarray(point, dtype=float) - self.eye
        depth = d @ self.f
        if depth <= 1.0:
            return None
        return (self.w / 2 + (d @ self.right) / depth * self.k, self.h / 2 - (d @ self.up) / depth * self.k)

    def down(self, px: float, py: float) -> tuple[float, float]:  # for a look at a point of a photo
        """The game (x, z) where the ray of a pixel meets the ground of the build."""
        ray = self.f + ((px - self.w / 2) / self.k) * self.right - ((py - self.h / 2) / self.k) * self.up
        t = 0.0
        point = self.eye
        for _ in range(80):
            point = self.eye + ray * t
            over = point[1] - ground(point[0], point[2])
            if over < 0.05 or ray[1] >= 0:
                break
            t += over / -ray[1]
        return float(point[0]), float(point[2])


def roads() -> list[dict]:
    return json.loads((BUILD / "roads.json").read_text(encoding="utf-8"))["roads"]


def _edges(road: dict) -> list[list[tuple[float, float]]]:
    from shapely.geometry import LineString
    line = LineString([(p[0], p[2]) for p in road["points"]])
    out = []
    for side in (1, -1):
        edge = line.offset_curve(side * float(road["width"]) / 2)
        for part in getattr(edge, "geoms", [edge]):
            if not part.is_empty:
                out.append(list(part.coords))
    return out


def _ways(near: tuple[float, float, float, float]):
    """(points in game (x, z), is a path) for each way near the box."""
    x0, z0, x1, z1 = near
    for road in roads():
        xs = [p[0] for p in road["points"]]
        zs = [p[2] for p in road["points"]]
        if max(xs) < x0 or min(xs) > x1 or max(zs) < z0 or min(zs) > z1:
            continue
        if road["type"] in PATHS:
            yield [(p[0], p[2]) for p in road["points"]], True
        else:
            for edge in _edges(road):
                yield edge, False


def photo_part(items: list[dict], near) -> Image.Image:
    """The photo of the items (the same photo and camera) with their outlines."""
    image = Image.open(PHOTOS / items[0]["photo"]).convert("RGB")
    camera = Camera(items[0]["camera"], *image.size)
    draw = ImageDraw.Draw(image)
    for points, path in _ways(near):
        q = [camera.project((x, ground(x, z) + 0.1, z)) for x, z in points]
        for a, b in zip(q, q[1:]):
            if a and b and all(-5000 < v < 5000 for v in a + b):
                draw.line([a, b], fill=(255, 140, 0) if path else (255, 0, 255), width=2)
    for item in items:
        draw.polygon([tuple(p) for p in item["photo_points"]], outline=(255, 0, 0), width=3)
    return image


def map_part(items: list[dict], near) -> Image.Image:
    x0, z0, x1, z1 = near
    s = MAP_SCALE
    image = Image.new("RGB", (int((x1 - x0) * s), int((z1 - z0) * s)), (233, 226, 208))
    meta = json.loads((BUILD / "showcase.json").read_text(encoding="utf-8"))["ground"]
    mask = np.asarray(Image.open(BUILD / meta["file"]).convert("RGB"))
    pixels = np.asarray(image).copy()
    zs = z0 + (np.arange(pixels.shape[0]) + 0.5) / s
    xs = x0 + (np.arange(pixels.shape[1]) + 0.5) / s
    rows = ((zs - meta["z0"]) / meta["step"]).astype(int)
    cols = ((xs - meta["x0"]) / meta["step"]).astype(int)
    rr, cc = np.meshgrid(rows, cols, indexing="ij")
    inside = (rr >= 0) & (rr < mask.shape[0]) & (cc >= 0) & (cc < mask.shape[1])
    cells = mask[np.clip(rr, 0, mask.shape[0] - 1), np.clip(cc, 0, mask.shape[1] - 1)]
    pixels[inside & (cells[..., 1] >= 128)] = (185, 178, 168)
    pixels[inside & (cells[..., 0] >= 128)] = (112, 165, 84)
    pixels[inside & (cells[..., 2] >= 128)] = (120, 92, 66)
    image = Image.fromarray(pixels)
    draw = ImageDraw.Draw(image)

    def m(x, z):
        return ((x - x0) * s, (z - z0) * s)

    for x in range(int(math.ceil(x0 / 10) * 10), int(x1) + 1, 10):
        draw.line([m(x, z0), m(x, z1)], fill=(255, 255, 255), width=1)
        draw.text((m(x, z0)[0] + 2, 2), str(x), fill=(120, 0, 0))
    for z in range(int(math.ceil(z0 / 10) * 10), int(z1) + 1, 10):
        draw.line([m(x0, z), m(x1, z)], fill=(255, 255, 255), width=1)
        draw.text((2, m(x0, z)[1] + 2), str(z), fill=(120, 0, 0))
    for points, path in _ways(near):
        draw.line([m(x, z) for x, z in points], fill=(220, 110, 0) if path else (200, 0, 200), width=2)
    for item in items:
        draw.polygon([m(x, z) for x, z in item["outline"]], outline=(255, 0, 0), width=3)
    return image


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="only the distance of each point")
    args = parser.parse_args()
    items = json.loads(CONFIG.read_text(encoding="utf-8"))["ground"].get("drawn", [])
    if not items:
        print("lawn_sheet.py: no drawn areas")
        return 0
    worst = 0.0
    for item in items:
        size = Image.open(PHOTOS / item["photo"]).size
        camera = Camera(item["camera"], *size)
        for (px, py), (x, z) in zip(item["photo_points"], item["outline"]):
            q = camera.project((x, ground(x, z), z))
            worst = max(worst, math.hypot(q[0] - px, q[1] - py) if q else math.inf)
    print(f"lawn_sheet.py: {len(items)} drawn areas; the outlines through the cameras are at most "
          f"{worst:.1f} px from the points of the photos")
    if args.check:
        return 0 if worst < 2.0 else 1
    xs = [p[0] for item in items for p in item["outline"]]
    zs = [p[1] for item in items for p in item["outline"]]
    near = (min(xs) - MAP_MARGIN, min(zs) - MAP_MARGIN, max(xs) + MAP_MARGIN, max(zs) + MAP_MARGIN)
    photos = []
    by_photo: dict[str, list[dict]] = {}
    for item in items:
        by_photo.setdefault(item["photo"], []).append(item)
    for group in by_photo.values():
        photo = photo_part(group, near)
        photos.append(photo)
        # The outlines near: their box on the photo with a margin.
        xs = [p[0] for item in group for p in item["photo_points"]]
        ys = [p[1] for item in group for p in item["photo_points"]]
        pad = max(max(xs) - min(xs), max(ys) - min(ys)) * 0.3
        photos.append(photo.crop((int(max(min(xs) - pad, 0)), int(max(min(ys) - pad * 0.5, 0)),
                                  int(min(max(xs) + pad, photo.width)), int(min(max(ys) + pad * 0.5, photo.height)))))
    plan = map_part(items, near)
    height = 900
    parts = [p.resize((int(p.width * height / p.height), height)) for p in photos + [plan]]
    sheet = Image.new("RGB", (sum(p.width for p in parts) + 20 * (len(parts) - 1), height), (255, 255, 255))
    x = 0
    for part in parts:
        sheet.paste(part, (x, 0))
        x += part.width + 20
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT, quality=88)
    print(f"lawn_sheet.py: {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
