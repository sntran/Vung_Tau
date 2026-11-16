"""The ground of the showcase of Bãi Trước (plan 0026, R3 and R4).

From the areas of OpenStreetMap that the "ground" part of
data/showcase/bai_truoc.json names, this module makes:

- a fine mask of the ground (cells of cell_m): R the lawns, G the paving of the
  squares and of the walk of the sea. The lawns are the park and the grass
  areas, less the roads and the paths, the paved areas, the water, the beach,
  the parking areas, and the buildings.
- the raised lawns (the strips of lawn in low granite borders on the walk of
  the sea, photo of S5): their outlines.
- the low wall along the beach: the edges of the walk areas that are near the
  beach.

All points are game (x, z): x east, z south (the map y is -z).
"""

import numpy as np
import shapely
import shapely.geometry.polygon
from shapely.geometry import LineString, MultiLineString, Polygon
from shapely.ops import unary_union

# The mask is made at a finer cell, then each block of FINE x FINE cells gives one mask cell (smooth edges).
FINE = 2


def _ids(values) -> set[str]:
    return {str(v) for v in values}


def _lines_of(geometry) -> list[LineString]:
    if geometry.is_empty:
        return []
    if isinstance(geometry, LineString):
        return [geometry]
    if isinstance(geometry, MultiLineString):
        return list(geometry.geoms)
    return [g for g in getattr(geometry, "geoms", []) if isinstance(g, LineString)]


def _game_ring(polygon: Polygon) -> list[list[float]]:
    return [[round(x, 2), round(-y, 2)] for x, y in polygon.exterior.coords[:-1]]


def _game_line(line: LineString) -> list[list[float]]:
    return [[round(x, 2), round(-y, 2)] for x, y in line.coords]


def _beach_edges(walk: Polygon, beach, outline: Polygon, reach: float) -> list[LineString]:
    """The edges of the walk that face the beach: each piece of its outline (1 m
    or less) within reach of the beach, whose outer side is nearer to the beach
    than the piece (or on the beach). So the wall does not turn round the corners of the walk."""
    ring = shapely.geometry.polygon.orient(walk, 1.0).exterior
    points = np.asarray(shapely.segmentize(ring, 1.0).coords)
    lines, current = [], []
    for a, b in zip(points[:-1], points[1:]):
        d = b - a
        length = float(np.hypot(*d))
        if length == 0.0:
            continue
        middle = (a + b) / 2.0
        outward = middle + np.array([d[1], -d[0]]) / length  # the ring goes counterclockwise
        here = beach.distance(shapely.Point(middle))
        out = shapely.Point(outward)
        faces = beach.contains(out) or beach.distance(out) < here
        keep = here <= reach and faces and outline.contains(shapely.Point(middle))
        if keep:
            if not current:
                current = [tuple(a)]
            current.append(tuple(b))
        elif current:
            lines.append(LineString(current))
            current = []
    if current:
        lines.append(LineString(current))
    # The ring starts at an arbitrary point: join the last line and the first when they meet.
    if len(lines) > 1 and lines[0].coords[0] == lines[-1].coords[-1]:
        lines[0] = LineString(list(lines[-1].coords) + list(lines[0].coords)[1:])
        lines.pop()
    return [line.simplify(0.05) for line in lines]


def make(config: dict, areas: list[tuple[str, dict, object]], roads, buildings: list[Polygon], outline: Polygon,
         road_widths: dict | None = None) -> dict:
    """config: the "ground" part of the showcase file. areas: (osm id
    "way/ID", tags, map geometry) for each area of OSM. roads: the roads of the
    build (map points and width). buildings: map polygons. outline: the area of
    the showcase as a map polygon. Returns {"mask": RGBA uint8 array, "x0",
    "z0" (the game point of the corner of the first cell), "step",
    "planters", "walls", "areas"}."""
    by_id = {osm: (tags, geometry) for osm, tags, geometry in areas}
    problems = []

    def shapes(ids) -> list:
        result = []
        for osm in ids:
            if osm not in by_id:
                problems.append(f"the showcase ground names {osm}, but OSM has no such area")
                continue
            result.append(by_id[osm][1])
        return result

    lawn_ids = _ids(config.get("lawns", []))
    paving_ids = _ids(config.get("paving", []))
    lawn = unary_union(shapes(lawn_ids)).intersection(outline) if lawn_ids else Polygon()
    paving = unary_union(shapes(paving_ids)).intersection(outline) if paving_ids else Polygon()
    # The paths and the walk of the sea (the lines of OSM) are paving too: the
    # game draws them as roads, and the mask keeps the lawn off them.
    margin = float(config.get("road_margin_m", 0.3))
    path_types = set(config.get("path_types", ["footway", "pedestrian", "path", "steps"]))
    road_shapes, path_shapes = [], []
    for road in roads:
        if road.points is None or len(road.points) < 2:
            continue
        line = LineString(road.points)
        if not line.intersects(outline):
            continue
        shape = line.buffer(float(road.width) / 2.0 + margin, cap_style="flat")
        (path_shapes if road.type in path_types else road_shapes).append(shape)
    keys = [tuple(k) for k in config.get("not_lawn", [])]
    not_lawn = [geometry for osm, (tags, geometry) in by_id.items()
                if osm not in lawn_ids and any(tags.get(k) == v for k, v in keys)]
    near = outline.buffer(50.0)
    not_lawn = [g for g in not_lawn if g.intersects(near)] + [b for b in buildings if b.intersects(near)]
    lawn = lawn.difference(unary_union(road_shapes + path_shapes + not_lawn + [paving]))
    paving = paving.difference(unary_union(road_shapes))

    # The raised lawns: the grass areas of the walk of the sea.
    planter_cfg = config.get("planters", {})
    planters = []
    for osm in _ids(planter_cfg.get("osm", [])):
        for geometry in shapes([osm]):
            for part in getattr(geometry, "geoms", [geometry]):
                if isinstance(part, Polygon) and not part.is_empty:
                    planters.append({"osm": osm, "outline": _game_ring(part.simplify(0.05))})

    # The low wall along the beach: the edges of the walk areas within near_beach_m of the beach.
    wall_cfg = config.get("beach_wall", {})
    walls = []
    beach = unary_union([g for _osm, (tags, g) in by_id.items() if tags.get("natural") == "beach" and g.intersects(near)])
    reach = float(wall_cfg.get("near_beach_m", 4.0))
    min_length = float(wall_cfg.get("min_length_m", 3.0))
    for osm in _ids(wall_cfg.get("walks", [])):
        for geometry in shapes([osm]):
            for part in getattr(geometry, "geoms", [geometry]):
                if not isinstance(part, Polygon) or beach.is_empty:
                    continue
                for line in _beach_edges(part, beach, outline, reach):
                    if line.length >= min_length:
                        walls.append({"osm": osm, "points": _game_line(line)})

    # The mask: its box is the box of the lawns and the paving, and a margin of two cells.
    step = float(config.get("cell_m", 0.5))
    both = unary_union([lawn, paving])
    if both.is_empty:
        return {"mask": None, "planters": planters, "walls": walls, "problems": problems}
    x_min, y_min, x_max, y_max = both.bounds
    x0 = np.floor(x_min / step) * step - 2 * step
    x1 = np.ceil(x_max / step) * step + 2 * step
    top = np.ceil(y_max / step) * step + 2 * step  # the map y of the first row (the north edge)
    bottom = np.floor(y_min / step) * step - 2 * step
    columns = int(round((x1 - x0) / step))
    rows = int(round((top - bottom) / step))
    from rasterio import features
    from rasterio.transform import Affine

    fine = step / FINE
    transform = Affine(fine, 0, x0, 0, -fine, top)

    def channel(geometry) -> np.ndarray:
        if geometry.is_empty:
            return np.zeros((rows, columns), dtype=np.uint8)
        cells = features.rasterize([(geometry, 1)], out_shape=(rows * FINE, columns * FINE), transform=transform,
                                   fill=0, dtype=np.uint8)
        share = cells.reshape(rows, FINE, columns, FINE).mean(axis=(1, 3))
        return np.round(share * 255).astype(np.uint8)

    mask = np.dstack([channel(lawn), channel(paving), np.zeros((rows, columns), np.uint8),
                      np.full((rows, columns), 255, np.uint8)])
    return {"mask": mask, "x0": float(x0), "z0": float(-top), "step": step, "columns": columns, "rows": rows,
            "planters": planters, "walls": walls, "problems": problems,
            "areas": {"lawn_m2": round(lawn.area), "paving_m2": round(paving.area)}}
