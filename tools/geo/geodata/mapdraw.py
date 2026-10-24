"""Draws data/geo/build/homestay_area.png: a top-down map around the homestay hẻm (plan 0004, R8b)."""

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from .config import FONT

SCALE = 2.0  # pixels for each meter
RADIUS_M = 300.0
COLORS = {
    "background": (246, 241, 228), "sea": (170, 205, 230), "beach": (240, 222, 170), "block": (232, 226, 210),
    "building": (200, 180, 160),
    "road": (255, 255, 255), "road_edge": (150, 140, 120), "hem": (205, 196, 176), "path": (196, 120, 60),
    "candidate": (230, 120, 20), "homestay": (210, 30, 40), "text": (40, 40, 40), "light": (20, 20, 20),
}


def draw(path, center, roads, land, beaches, blocks, buildings, homestay: dict) -> None:
    size = int(RADIUS_M * 2 * SCALE)
    image = Image.new("RGB", (size, size), COLORS["sea"])
    pen = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(FONT), 15) if FONT.exists() else ImageFont.load_default()
    small = ImageFont.truetype(str(FONT), 22) if FONT.exists() else ImageFont.load_default()
    cx, cy = center

    def px(points):
        return [((x - cx) * SCALE + size / 2, (cy - y) * SCALE + size / 2) for x, y in points]

    def polygon(shape, color):
        for part in getattr(shape, "geoms", [shape]):
            if part.is_empty or not hasattr(part, "exterior"):
                continue
            pen.polygon(px(part.exterior.coords), fill=color)
            for hole in part.interiors:
                pen.polygon(px(hole.coords), fill=COLORS["sea"])

    polygon(land, COLORS["background"])
    for block in blocks:
        polygon(block["polygon"], COLORS["block"])
    for beach in beaches:
        polygon(beach, COLORS["beach"])
    for building in buildings:
        polygon(building, COLORS["building"])
    for road in sorted(roads, key=lambda r: -r.importance):
        width = max(2, int(road.width * SCALE))
        color = COLORS["hem"] if road.hem else COLORS["road"]
        pen.line(px(road.points), fill=COLORS["road_edge"], width=width + 2, joint="curve")
        pen.line(px(road.points), fill=color, width=width, joint="curve")
    if "lighthouse_road" in homestay:
        pen.line(px(homestay["lighthouse_road"]["points"]), fill=COLORS["path"], width=5, joint="curve")
    for number, candidate in enumerate(homestay.get("candidates", []), start=1):
        road = candidate["road"]
        color = COLORS["homestay"] if homestay.get("found") else COLORS["candidate"]
        pen.line(px(road.points), fill=color, width=max(6, int(road.width * SCALE)), joint="curve")
        if not homestay.get("found"):
            x, y = px([candidate["junction"]])[0]
            pen.text((x + 8, y - 8), str(number), fill=color, font=small)
    if "curve" in homestay:
        for key in ("start", "end"):
            x, y = px([homestay["curve"][key]])[0]
            pen.ellipse((x - 6, y - 6, x + 6, y + 6), outline=COLORS["light"], width=3)
    # Road names, one time for each name, at the middle of the longest road with the name.
    longest: dict[str, object] = {}
    for road in roads:
        if road.name and (road.name not in longest or road.length > longest[road.name].length):
            longest[road.name] = road
    for name, road in longest.items():
        mid = road.points[len(road.points) // 2]
        x, y = px([mid])[0]
        if 0 <= x < size and 0 <= y < size:
            pen.text((x + 4, y + 4), name, fill=COLORS["text"], font=font)
    pen.text((12, 12), "Homestay hẻm (red), lighthouse road (brown). 1 px = 0.5 m.", fill=COLORS["text"], font=small)
    image.save(path)


def center_of(homestay: dict) -> np.ndarray | None:
    if homestay.get("found"):
        pts = homestay["hem"].points
        middle = pts[len(pts) // 2]
        if "curve" in homestay:
            return (middle + np.array(homestay["curve"]["end"])) / 2.0
        return middle
    if "curve" in homestay:
        return np.array(homestay["curve"]["end"])
    return None
