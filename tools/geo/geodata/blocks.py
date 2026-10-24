"""Blocks: the areas between the roads, without the road surfaces (plan 0005, R4)."""

import numpy as np
from shapely import STRtree, ops
from shapely.geometry import LineString, Point, Polygon
from shapely.geometry.base import BaseGeometry

# Roads that do not cut the land into blocks.
NOT_BLOCK_EDGES = {"footway", "path", "steps", "track", "cycleway"}
MIN_BLOCK_M2 = 30.0


def road_surfaces(roads) -> list[BaseGeometry]:
    """The surface of each road."""
    return [LineString(r.points).buffer(r.width / 2.0, cap_style="flat", join_style="round")
            for r in roads if len(r.points) >= 2]


def make_blocks(roads, land: BaseGeometry, buildings: list[Polygon], landuse: list[tuple[str, BaseGeometry]]) -> list[dict]:
    """Returns the blocks in map coordinates, with the number of OSM buildings in each block."""
    edges = [LineString(r.points) for r in roads if r.type not in NOT_BLOCK_EDGES and len(r.points) >= 2]
    if land.is_empty:
        return []
    noded = ops.unary_union(edges + [land.boundary])
    faces = [f for f in ops.polygonize(noded) if f.area >= MIN_BLOCK_M2]
    surfaces = road_surfaces(roads)
    surface_tree = STRtree(surfaces) if surfaces else None
    centers = [b.representative_point() for b in buildings]
    building_tree = STRtree(centers) if centers else None
    landuse_tree = STRtree([g for _k, g in landuse]) if landuse else None
    blocks = []
    for face in faces:
        if not land.contains(face.representative_point()):
            continue
        shape = face.intersection(land)
        if surface_tree is not None:
            near = surface_tree.query(face)
            if len(near):
                shape = shape.difference(ops.unary_union([surfaces[int(i)] for i in near]))
        parts = list(shape.geoms) if hasattr(shape, "geoms") else [shape]
        for part in parts:
            if not isinstance(part, Polygon) or part.area < MIN_BLOCK_M2:
                continue
            count = 0
            if building_tree is not None:
                count = sum(1 for i in building_tree.query(part, predicate="contains"))
            use = ""
            if landuse_tree is not None:
                inside = landuse_tree.query(part.representative_point(), predicate="within")
                if len(inside):
                    use = landuse[int(inside[0])][0]
            blocks.append({"polygon": part, "buildings": count, "landuse": use})
    return blocks


def polygon_to_game(polygon: Polygon) -> dict:
    def ring(coords):
        return [[round(float(x), 2), round(-float(y), 2)] for x, y in coords]
    return {"outline": ring(polygon.exterior.coords), "holes": [ring(r.coords) for r in polygon.interiors]}


def points_in(points: np.ndarray, polygon: Polygon) -> int:
    return sum(1 for p in points if polygon.contains(Point(p)))
