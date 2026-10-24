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


def land_polygon(lines: list[LineString], box: Polygon, problems: list[str]) -> BaseGeometry:
    """Returns the land inside the box."""
    if not lines:
        problems.append("the data has no coastline, so all of the box is land")
        return box
    merged = ops.linemerge(MultiLineString(lines))
    parts = list(merged.geoms) if hasattr(merged, "geoms") else [merged]
    clipped = [p.intersection(box) for p in parts]
    pieces = list(ops.polygonize(ops.unary_union([box.boundary] + [c for c in clipped if not c.is_empty])))
    land = []
    for piece in pieces:
        if piece.area < 1.0:
            continue
        point = piece.representative_point()
        nearest = min(parts, key=lambda p: p.distance(point))
        if _side(nearest, point) > 0:
            land.append(piece)
    if not land:
        problems.append("the coastline gives no land in the box")
        return Polygon()
    return ops.unary_union(land).intersection(box)
