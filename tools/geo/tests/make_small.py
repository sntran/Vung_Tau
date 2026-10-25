#!/usr/bin/env python3
"""Makes the small test extract in tools/geo/tests/data/ (plan 0005, R18).

The place is not real. It is a design in meters around the point B
(10.3466 N, 107.0728 E): x is east and y is north from B. Run this script
again only when the design changes, and commit the files.

- The sea is at the west of the coastline x = -200.
- "Bãi Trước" is a beach from x = -205 to -150, y = -150 to 150.
- The coast road "Quang Trung" is at x = -140.
- A hill with the lighthouse and the peak "Núi Nhỏ" is at (245, 0).
- The lighthouse road goes east from (-140, -200), turns north in a curve
  near (20, -180), and goes up to the lighthouse.
- "Hẻm 42" leaves the curve end (42, -150) to the east: it is the homestay hẻm.
  Two other hẻm are wrong candidates.
- Plan 0005, R12a and R13a: a pier (way 1012) and a groyne (way 1013) in the
  sea, a park near the beach (way 1014), an OSM tree, and a tree row (way 1015).
"""

import math
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np
import rasterio
from pyproj import Transformer
from rasterio.transform import from_origin

HERE = Path(__file__).resolve().parent / "data"
BASE = (107.0728, 10.3466)
BOX_DEG = 0.006
_to_utm = Transformer.from_crs(4326, 32648, always_xy=True)
_to_lonlat = Transformer.from_crs(32648, 4326, always_xy=True)
BASE_E, BASE_N = _to_utm.transform(*BASE)


def lonlat(x: float, y: float) -> tuple[float, float]:
    return _to_lonlat.transform(BASE_E + x, BASE_N + y)


class Writer:
    def __init__(self):
        self.root = ET.Element("osm", version="0.6", generator="make_small.py")
        self.next_node = 1
        self.next_way = 1000
        self.nodes: dict[tuple[float, float], int] = {}
        self._ways: list = []

    def node(self, x, y, tags=None) -> int:
        key = (round(x, 3), round(y, 3))
        if key in self.nodes and not tags:
            return self.nodes[key]
        lon, lat = lonlat(x, y)
        nid = self.next_node
        self.next_node += 1
        element = ET.SubElement(self.root, "node", id=str(nid), version="1", lat=f"{lat:.8f}", lon=f"{lon:.8f}")
        for k, v in (tags or {}).items():
            ET.SubElement(element, "tag", k=k, v=v)
        if not tags:
            self.nodes[key] = nid
        return nid

    def way(self, points, tags, closed=False) -> int:
        refs = [self.node(x, y) for x, y in points]
        if closed:
            refs.append(refs[0])
        wid = self.next_way
        self.next_way += 1
        self._ways.append((wid, refs, tags))
        return wid

    def write(self, path: Path):
        for wid, refs, tags in self._ways:
            element = ET.SubElement(self.root, "way", id=str(wid), version="1")
            for ref in refs:
                ET.SubElement(element, "nd", ref=str(ref))
            for k, v in tags.items():
                ET.SubElement(element, "tag", k=k, v=v)
        ET.indent(self.root)
        ET.ElementTree(self.root).write(path, encoding="utf-8", xml_declaration=True)


def line(*points, step=50.0):
    """The points with more points between them, so that crossing roads share nodes."""
    result = [points[0]]
    for a, b in zip(points[:-1], points[1:]):
        length = math.dist(a, b)
        parts = max(1, round(length / step))
        for i in range(1, parts + 1):
            result.append((a[0] + (b[0] - a[0]) * i / parts, a[1] + (b[1] - a[1]) * i / parts))
    return result


def make_osm(path: Path):
    w = Writer()
    w.way(line((-200, 900), (-200, -900), step=100), {"natural": "coastline"})
    w.way([(-205, -150), (-150, -150), (-150, 150), (-205, 150)], {"natural": "beach", "name": "Bãi Trước"}, closed=True)
    w.way(line((-140, -800), (-140, 800)), {"highway": "primary", "name": "Quang Trung"})
    w.way(line((-140, 100), (300, 100)), {"highway": "residential", "name": "Lê Lợi"})
    w.way(line((300, -800), (300, 800)), {"highway": "secondary", "name": "Trần Phú"})
    curve = [(0, -200), (20, -193), (33, -180), (40, -163), (42, -150)]
    w.way(line((-140, -200), (0, -200)) + curve[1:] + [(42, -100), (42, -50), (100, -20), (180, -5), (245, 0)],
          {"highway": "tertiary", "name": "Đường lên Hải Đăng"})
    w.way([(42, -150), (100, -150), (200, -150)], {"highway": "residential", "name": "Hẻm 42", "width": "3"})
    w.way([(42, -150), (-30, -90)], {"highway": "service", "service": "alley"})
    w.way([(42, -100), (150, -100)], {"highway": "footway"})
    w.way([(100, 200), (120, 200), (120, 220), (100, 220)], {"building": "yes"}, closed=True)
    w.way([(0, -300), (15, -300), (15, -285), (0, -285)], {"building": "house"}, closed=True)
    w.way([(60, -140), (75, -140), (75, -125), (60, -125)], {"building": "house"}, closed=True)
    w.node(245, 0, {"natural": "peak", "name": "Núi Nhỏ", "ele": "180"})
    w.node(250, 5, {"man_made": "lighthouse", "name": "Hải đăng Vũng Tàu"})
    w.way([(-200, 200), (-260, 200)], {"man_made": "pier"})
    w.way([(-200, -250), (-240, -250)], {"man_made": "groyne"})
    w.way([(-130, 180), (-60, 180), (-60, 260), (-130, 260)], {"leisure": "park", "name": "Công viên thử"}, closed=True)
    w.way([(150, 300), (250, 300)], {"natural": "tree_row"})
    w.node(-100, 320, {"natural": "tree", "genus": "Delonix"})
    w.write(path)


def height(x, y):
    """The ground of the test place in meters."""
    h = 2.0 + 150.0 * np.exp(-((x - 245.0) ** 2 + y ** 2) / (2 * 120.0 ** 2))
    h = h + np.where((x > 100) & (x < 120) & (y > 200) & (y < 220), 12.0, 0.0)  # a building in the surface model
    return np.where(x < -200, 0.0, h)


def make_dem(path: Path):
    res = 1.0 / 3600.0
    west, south = BASE[0] - BOX_DEG - 0.002, BASE[1] - BOX_DEG - 0.002
    east, north = BASE[0] + BOX_DEG + 0.002, BASE[1] + BOX_DEG + 0.002
    cols, rows = int((east - west) / res), int((north - south) / res)
    lon = west + (np.arange(cols) + 0.5) * res
    lat = north - (np.arange(rows) + 0.5) * res
    glon, glat = np.meshgrid(lon, lat)
    e, n = _to_utm.transform(glon, glat)
    values = height(e - BASE_E, n - BASE_N).astype(np.float32)
    profile = {"driver": "GTiff", "height": rows, "width": cols, "count": 1, "dtype": "float32",
               "crs": "EPSG:4326", "transform": from_origin(west, north, res, res), "compress": "deflate"}
    with rasterio.open(path, "w", **profile) as dst:
        dst.write(values, 1)


def main():
    HERE.mkdir(parents=True, exist_ok=True)
    make_osm(HERE / "osm.osm")
    make_dem(HERE / "dem.tif")
    print("wrote", HERE / "osm.osm", HERE / "dem.tif")


if __name__ == "__main__":
    main()
