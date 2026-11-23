"""The houses of World on the streets of plan 0009, phase 3 (R7 to R9).

For each street of data/geo/streets.json the build puts lots along both sides
of the road, with their fronts at the edge of the road (the sidewalk is in the
width of the road), and a tube house of World on each lot:

- A box of the town (an outline of 2019, or a box of the raster) whose front
  is on the street is cut into lots along the street: the lots of a box of
  BLOCK_M2 or more are a row of houses (report 0009, section 10.4). These
  houses have the status "Source": the data has a building there.
- Where the data has no building on the front (report 0009, Q12, the rule of
  phase 3), a row of tube houses fills the front, with the status "Check". The
  street photos of Mapillary nearest to each such lot are its source.
- No lot goes on the surface of a road (a side street or a hẻm stays open),
  on the water of the land, on a part that draws its own building (the
  showcase of plan 0026 and the known places), or on another building that is
  not on the front.

Each house is a model of World (blueprint tube_house) by its width class, the
variant by the id of the lot (D4), scaled to the lot. The town leaves out each
box that a lot covers (TownField keep-out), and the game draws the houses near
and mid, and a box of each lot from far (scenes/world/street_houses.gd).
"""

from __future__ import annotations

import hashlib
import math

import shapely
from shapely.geometry import LineString, Point, Polygon
from shapely.strtree import STRtree

# The models of World by width class: (id, width, depth) of the lot of the model.
MODELS = [
    ("nha_ong_4x16", 4.0, 16.0),
    ("nha_ong_cu_4x18", 4.2, 18.45),
    ("nha_ong_5x20", 5.0, 20.3),
]
# A lot is from LOT_MIN_M to LOT_MAX_M wide; a new lot of Q12 is 4 m or 5 m.
LOT_MIN_M = 3.2
LOT_MAX_M = 6.5
Q12_WIDTHS = (4.0, 4.0, 5.0)
# The depth of a lot: from the box (Source), else the depth of a tube house.
DEPTH_MIN_M = 8.0
DEPTH_MAX_M = 20.0
Q12_DEPTH_M = 16.0
# A box is on the front when it comes this near to the edge of the road (m).
FRONT_M = 6.0
# A box of this area or more is a row of houses as one block (section 10.4).
BLOCK_M2 = 1000.0
# The scale of a model to its lot: at most this far from 1 (else another
# model of the class fits better).
SCALE_RANGE = (0.75, 1.35)
# The steps along the street to find the free fronts (m).
STEP_M = 0.5
# The gap between the edge of the road and the front of a house (m).
FRONT_GAP_M = 0.2


def unit(text: str) -> float:
    """A number from 0 to 1 from a text (the same on each build)."""
    return int(hashlib.sha1(text.encode("utf-8")).hexdigest()[:8], 16) / 0xFFFFFFFF


def model_for(lot_id: str, width: float, depth: float) -> tuple[str, float, float]:
    """The model of a lot and its scale across and along: the class of the
    width (4 m or 5 m), the variant by the id of the lot (D4)."""
    if width < 4.5:
        choices = [m for m in MODELS if m[1] < 4.5]
    else:
        choices = [m for m in MODELS if m[1] >= 4.5]
    model = choices[min(int(unit(lot_id + "m") * len(choices)), len(choices) - 1)]
    sx = min(max(width / model[1], SCALE_RANGE[0]), SCALE_RANGE[1])
    sz = min(max(depth / model[2], SCALE_RANGE[0]), SCALE_RANGE[1])
    return model[0], sx, sz


def street_line(roads: list, ways: list) -> LineString:
    """The line of a street from its ways of roads.json (game x, z), in order."""
    lines = [LineString([(p[0], p[2]) for p in r["points"]]) for r in roads if r["id"] in ways]
    merged = shapely.line_merge(shapely.union_all(lines))
    if merged.geom_type == "MultiLineString":
        merged = max(merged.geoms, key=lambda g: g.length)
    return merged


def road_surfaces(roads: list) -> list:
    """The surface of each road (its width), game x, z."""
    return [LineString([(p[0], p[2]) for p in r["points"]]).buffer(float(r.get("width", 4.0)) / 2.0, cap_style="flat")
            for r in roads if len(r.get("points", [])) >= 2]


def _frame(line: LineString, s: float) -> tuple[tuple[float, float], tuple[float, float]]:
    """The point at s along the line and the unit direction there."""
    a = line.interpolate(max(s - 0.5, 0.0))
    b = line.interpolate(min(s + 0.5, line.length))
    dx, dz = b.x - a.x, b.y - a.y
    n = math.hypot(dx, dz) or 1.0
    p = line.interpolate(s)
    return (p.x, p.y), (dx / n, dz / n)


def lot_polygon(line: LineString, side: int, s0: float, s1: float, front: float, depth: float) -> Polygon:
    """The lot from s0 to s1 along the line, on a side (+1 left, -1 right of the
    way of the line), from the front (distance from the line) to front + depth."""
    (x0, z0), (dx0, dz0) = _frame(line, s0)
    (x1, z1), (dx1, dz1) = _frame(line, s1)
    # The normal to the left of the way: (dz, -dx) in x, z.
    n0 = (dz0 * side, -dx0 * side)
    n1 = (dz1 * side, -dx1 * side)
    return Polygon([
        (x0 + n0[0] * front, z0 + n0[1] * front),
        (x1 + n1[0] * front, z1 + n1[1] * front),
        (x1 + n1[0] * (front + depth), z1 + n1[1] * (front + depth)),
        (x0 + n0[0] * (front + depth), z0 + n0[1] * (front + depth)),
    ])


def _cut_widths(length: float, key: str) -> list[float]:
    """The widths of the lots of a front of this length (each LOT_MIN_M to LOT_MAX_M)."""
    if length < LOT_MIN_M:
        return []
    count = max(1, round(length / 4.5))
    while length / count > LOT_MAX_M:
        count += 1
    while count > 1 and length / count < LOT_MIN_M:
        count -= 1
    return [length / count] * count


def _q12_widths(length: float, key: str) -> list[float]:
    """The widths of the lots of Q12 on a free front: 4 m or 5 m by the id, the
    rest spread on all lots."""
    widths = []
    used = 0.0
    i = 0
    while length - used >= LOT_MIN_M:
        w = Q12_WIDTHS[min(int(unit(f"{key}:{i}") * len(Q12_WIDTHS)), len(Q12_WIDTHS) - 1)]
        if length - used - w < LOT_MIN_M:
            w = length - used if length - used <= LOT_MAX_M else w
        widths.append(w)
        used += w
        i += 1
    if widths and used < length:
        extra = (length - used) / len(widths)
        widths = [w + extra for w in widths]
    return widths


def houses_of_street(street: dict, roads: list, boxes: list, blocked: list, photos: list | None = None) -> dict:
    """The lots and the houses of one street.

    boxes: the boxes of the town [{"id", "ring": [(x, z)], "height", "base"}] (game x, z).
    blocked: polygons (game x, z) where no lot goes (the water, the showcase, the known places).
    photos: [(image_id, x, z, date)] of Mapillary, for the source of the lots of Q12.
    """
    line = street_line(roads, street["ways"])
    width = max(float(r.get("width", 4.0)) for r in roads if r["id"] in street["ways"])
    front = width / 2.0 + FRONT_GAP_M
    surfaces = road_surfaces(roads)
    surface_tree = STRtree(surfaces)
    box_polys = [Polygon(b["ring"]).buffer(0) for b in boxes]
    box_tree = STRtree(box_polys)
    blocked_tree = STRtree(blocked) if blocked else None
    photo_points = [Point(p[1], p[2]) for p in (photos or [])]
    photo_tree = STRtree(photo_points) if photo_points else None
    houses = []
    replaced = set()

    def own_area(poly: Polygon) -> float:
        """The area of the rectangle of the lot (its front times its depth)."""
        c = list(poly.exterior.coords)
        return math.dist(c[0], c[1]) * math.dist(c[1], c[2])

    def clear(poly: Polygon, own: set) -> bool:
        """No road, no blocked part, and no other box under the lot (a box of the lot itself is its own)."""
        # A lot on a bend of the street is not a rectangle: it must keep most of its area.
        if not poly.is_valid or poly.area < 0.8 * own_area(poly):
            return False
        inner = poly.buffer(-0.3)
        if inner.is_empty:
            return False
        for i in surface_tree.query(inner):
            if surfaces[i].intersection(inner).area > 0.05 * inner.area:
                return False
        if blocked_tree is not None:
            for i in blocked_tree.query(inner):
                if blocked[i].intersects(inner):
                    return False
        for i in box_tree.query(inner):
            if boxes[i]["id"] not in own and box_polys[i].intersection(inner).area > 0.15 * box_polys[i].area:
                return False
        return True

    for side in (1, -1):
        name = "left" if side > 0 else "right"
        # The boxes on the front of this side: their part along the street.
        spans = []
        for i, poly in enumerate(box_polys):
            if poly.is_empty or line.distance(poly) > front + FRONT_M:
                continue
            c = poly.representative_point()
            s = line.project(c)
            (px, pz), (dx, dz) = _frame(line, s)
            if ((c.x - px) * dz * side - (c.y - pz) * dx * side) <= 0:
                continue
            coords = list(poly.exterior.coords)
            ss = [line.project(Point(p)) for p in coords]
            s0, s1 = max(min(ss), 0.0), min(max(ss), line.length)
            if s1 - s0 < 1.0:
                continue
            dists = [line.distance(Point(p)) for p in coords]
            depth = min(max(max(dists) - front, DEPTH_MIN_M), DEPTH_MAX_M)
            spans.append({"s0": s0, "s1": s1, "box": boxes[i], "depth": depth, "area": poly.area})
        spans.sort(key=lambda sp: sp["s0"])
        # The lots of the boxes (Source): a box is one house, or a row of lots.
        taken = []
        for sp in spans:
            s0 = max(sp["s0"], taken[-1][1] if taken else 0.0)
            s1 = sp["s1"]
            if s1 - s0 < LOT_MIN_M:
                continue
            widths = _cut_widths(s1 - s0, sp["box"]["id"])
            at = s0
            for k, w in enumerate(widths):
                lot_id = f"{street['id']}-{name}-{sp['box']['id']}-{k}"
                poly = lot_polygon(line, side, at, at + w, front, sp["depth"])
                if clear(poly, {sp["box"]["id"]}):
                    houses.append(_house(lot_id, street, name, poly, line, side, at, w, sp["depth"], front,
                                         float(sp["box"]["height"]), "box", "Source", [sp["box"]["id"]],
                                         block=sp["area"] >= BLOCK_M2))
                    replaced.add(sp["box"]["id"])
                at += w
            taken.append((s0, s1))
        # The free fronts (Q12): no box on the front.
        free = []
        s = 0.0
        start = None
        while s <= line.length:
            busy = any(a - 0.25 <= s <= b + 0.25 for a, b in taken)
            if not busy and start is None:
                start = s
            if (busy or s + STEP_M > line.length) and start is not None:
                free.append((start, s))
                start = None
            s += STEP_M
        for a, b in free:
            at = a
            for k, w in enumerate(_q12_widths(b - a, f"{street['id']}-{name}-{round(a)}")):
                lot_id = f"{street['id']}-{name}-q12-{round(at * 10)}"
                poly = lot_polygon(line, side, at, at + w, front, Q12_DEPTH_M)
                if clear(poly, set()):
                    house = _house(lot_id, street, name, poly, line, side, at, w, Q12_DEPTH_M, front, 0.0, "q12",
                                   "Check", [])
                    if photo_tree is not None:
                        middle = poly.centroid
                        near = sorted(photo_tree.query(middle.buffer(25.0)),
                                      key=lambda i: photo_points[i].distance(middle))[:3]
                        house["photos"] = [photos[i][0] for i in near]
                    houses.append(house)
                at += w
    return {"houses": houses, "replaced": sorted(replaced), "length_m": round(line.length, 1), "width_m": width}


def _house(lot_id: str, street: dict, side: str, poly: Polygon, line: LineString, sign: int, s0: float, w: float,
           depth: float, front: float, height: float, source: str, status: str, replaces: list, block: bool = False) -> dict:
    """The record of a house on a lot."""
    model, sx, sz = model_for(lot_id, w, depth)
    model_depth = next(m[2] for m in MODELS if m[0] == model)
    (x, z), (dx, dz) = _frame(line, s0 + w / 2.0)
    nx, nz = dz * sign, -dx * sign
    # The front of the house (its +z in the game: the balcony) faces the
    # street; the origin of the model is the middle of its lot.
    fx, fz = x + nx * front, z + nz * front
    cx, cz = fx + nx * model_depth * sz / 2.0, fz + nz * model_depth * sz / 2.0
    yaw = math.degrees(math.atan2(-nx, -nz))
    record = {"id": lot_id, "street": street["id"], "side": side, "model": model, "x": round(cx, 2), "z": round(cz, 2),
              "front": [round(fx, 2), round(fz, 2)], "yaw": round(yaw, 2), "width": round(w, 2), "depth": round(depth, 2),
              "scale": [round(sx, 3), 1.0, round(sz, 3)], "height": round(height, 2), "source": source, "status": status,
              "replaces": replaces, "outline": [[round(p[0], 2), round(p[1], 2)] for p in list(poly.exterior.coords)[:4]]}
    if block:
        record["block"] = True
    return record
