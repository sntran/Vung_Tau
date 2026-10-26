"""The land and the coastline from the OSM coastline ways.

OSM draws each coastline way with the land on the left side and the sea on
the right side. The pipeline cuts the box with the coastline lines and keeps
each part that is on the left side.
"""

import numpy as np
from shapely import ops
from shapely.geometry import LineString, MultiLineString, Point, Polygon
from shapely.geometry.base import BaseGeometry


def box_polygon(bbox, projection, step_deg: float = 0.002) -> Polygon:
    """The box (west, south, east, north) in map coordinates. The edges are curves in UTM."""
    west, south, east, north = bbox
    lons, lats = [], []
    for lon in np.arange(west, east, step_deg):
        lons.append(lon), lats.append(south)
    for lat in np.arange(south, north, step_deg):
        lons.append(east), lats.append(lat)
    for lon in np.arange(east, west, -step_deg):
        lons.append(lon), lats.append(north)
    for lat in np.arange(north, south, -step_deg):
        lons.append(west), lats.append(lat)
    x, y = projection.to_map(np.array(lons), np.array(lats))
    return Polygon(np.column_stack([x, y]))


def coastline_lines(ways, projection) -> list[LineString]:
    lines = []
    for way in ways:
        if way.tags.get("natural") != "coastline":
            continue
        lon, lat = zip(*way.coords)
        x, y = projection.to_map(np.array(lon), np.array(lat))
        lines.append(LineString(np.column_stack([x, y])))
    return lines


def _side(line: LineString, point: Point) -> float:
    """Positive when the point is on the left side of the line."""
    d = line.project(point)
    a = line.interpolate(max(0.0, d - 1.0))
    b = line.interpolate(min(line.length, d + 1.0))
    return (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)


def rock_coast_area(land: BaseGeometry, center: tuple[float, float], radius: float, sea: float) -> BaseGeometry:
    """A rocky coast (report 0005, D-0005-03): the land within radius of the
    map point center, and the sea up to sea meters from that land. The sea
    floor near a rocky cape is rock too, so it is not sand at low tide."""
    circle = Point(center).buffer(radius)
    near = land.intersection(circle)
    if near.is_empty:
        return near
    return near.buffer(sea).intersection(Point(center).buffer(radius + sea))


def coast_band(land: BaseGeometry, start: tuple[float, float], end: tuple[float, float], width: float) -> BaseGeometry:
    """The sea along the coast between the map points start and end, up to
    width meters from the coast (plan 0005, Q6: the flat rocks along the sea
    wall). The coast is the shorter way along the land boundary between the
    nearest points to start and end."""
    rings = [ring for p in getattr(land, "geoms", [land]) for ring in [p.exterior, *p.interiors]]
    ring = min(rings, key=lambda r: r.distance(Point(start)) + r.distance(Point(end)))
    line = LineString(ring.coords)
    a, b = sorted((line.project(Point(start)), line.project(Point(end))))
    if b - a <= line.length / 2.0:
        part = ops.substring(line, a, b)
    else:
        part = ops.linemerge(MultiLineString([ops.substring(line, b, line.length), ops.substring(line, 0.0, a)]))
    return part.buffer(width).difference(land)


def land_polygon(lines: list[LineString], box: Polygon, problems: list[str]) -> BaseGeometry:
    """Returns the land inside the box."""
    if not lines:
        problems.append("the data has no coastline, so all of the box is land")
        return box
    merged = ops.linemerge(MultiLineString(lines))
    parts = list(merged.geoms) if hasattr(merged, "geoms") else [merged]
    # The full lines cross the edge of the box, so the union cuts the box at the
    # crossings. Lines clipped to the box end near the edge, but not exactly on
    # it, so they do not cut the box.
    near = [p for p in parts if p.intersects(box)]
    pieces = list(ops.polygonize(ops.unary_union([box.boundary] + near)))
    land = []
    for piece in pieces:
        point = piece.representative_point()
        if piece.area < 1.0 or not box.contains(point):
            continue
        nearest = min(parts, key=lambda p: p.distance(point))
        if _side(nearest, point) > 0:
            land.append(piece)
    if not land:
        problems.append("the coastline gives no land in the box")
        return Polygon()
    return ops.unary_union(land).intersection(box)
