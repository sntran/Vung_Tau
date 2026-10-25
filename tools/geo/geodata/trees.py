"""The street trees and the park trees (plan 0005, R12a)."""

import math

import numpy as np
import shapely
from shapely import STRtree
from shapely.geometry import LineString, Point
from shapely.prepared import prep

from . import blocks as blocks_module


def _pick(mix: dict, rng: np.random.Generator) -> str:
    kinds = list(mix)
    weights = np.array([float(mix[k]) for k in kinds])
    return kinds[int(rng.choice(len(kinds), p=weights / weights.sum()))]


def _along(line: LineString, spacing: float, jitter: float, rng: np.random.Generator):
    """Points along a line: (point, unit direction) at about each spacing meters."""
    if line.length < spacing:
        return
    distance = spacing / 2.0
    while distance < line.length:
        d = min(max(distance + rng.uniform(-jitter, jitter), 0.0), line.length)
        a = line.interpolate(max(d - 1.0, 0.0))
        b = line.interpolate(min(d + 1.0, line.length))
        direction = np.array([b.x - a.x, b.y - a.y])
        norm = float(np.linalg.norm(direction))
        if norm > 0:
            yield np.array(line.interpolate(d).coords[0]), direction / norm
        distance += spacing


class _Place:
    """Checks that a point is free: on land, not on a beach, not on a road, and not too near another tree."""

    def __init__(self, land, beaches, roads, near_road: float):
        self.land = prep(land)
        self.beach = prep(shapely.union_all(beaches)) if beaches else None
        with_points = [r for r in roads if len(r.points) >= 2]
        self.road_ids = [id(r) for r in with_points]
        surfaces = blocks_module.road_surfaces(with_points)
        self.surfaces = STRtree(surfaces) if surfaces else None
        self.near_road = near_road
        self.taken: dict[tuple[int, int], list] = {}

    def free(self, point: np.ndarray, gap: float, check_road=True, own_road=None) -> bool:
        """own_road: a tree on the sidewalk of this road can be on its surface, but not near another road."""
        p = Point(float(point[0]), float(point[1]))
        if not self.land.contains(p) or (self.beach is not None and self.beach.contains(p)):
            return False
        if check_road and self.surfaces is not None:
            near = 0.5 if own_road is not None else self.near_road
            hits = self.surfaces.query(p, predicate="dwithin", distance=near)
            if any(self.road_ids[i] != id(own_road) for i in hits):
                return False
        cell = (int(point[0] // 10), int(point[1] // 10))
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for q in self.taken.get((cell[0] + dx, cell[1] + dy), []):
                    if math.hypot(q[0] - point[0], q[1] - point[1]) < gap:
                        return False
        self.taken.setdefault(cell, []).append((float(point[0]), float(point[1])))
        return True


def make(spec: dict, roads: list, land, beaches: list, parks: list, osm_trees: list, osm_rows: list,
         coast_road: str, beach_outline, near_point, sample_height) -> tuple[dict, dict]:
    """The trees for the build folder and the counts for the report.
    parks: park shapes (map). osm_trees: (x, y, tags). osm_rows: (LineString, tags).
    near_point: the map point of the landmark for the parks near it.
    sample_height(x, y): the ground height at map points (arrays)."""
    rng = np.random.default_rng(int(spec.get("seed", 1)))
    street = spec["street"]
    place = _Place(land, beaches, roads, float(street["skip_near_road_m"]))
    found: dict[str, list] = {}
    counts: dict[str, int] = {}

    def add(kind: str, point, source: str) -> None:
        found.setdefault(kind, []).append((float(point[0]), float(point[1])))
        counts[source] = counts.get(source, 0) + 1

    genus = spec["osm_trees"]["genus"]

    def osm_kind(tags: dict) -> str:
        name = tags.get("genus", "") or tags.get("species", "").split(" ")[0]
        return genus.get(name, spec["osm_trees"]["default"])

    # OSM trees first: they are real trees.
    for x, y, tags in osm_trees:
        if place.free(np.array([x, y]), 2.0, check_road=False):
            add(osm_kind(tags), (x, y), "osm")
    for line, tags in osm_rows:
        for point, _direction in _along(line, float(spec["osm_trees"]["row_spacing_m"]), 0.5, rng):
            if place.free(point, 3.0, check_road=False):
                add(osm_kind(tags), point, "osm")

    def side_trees(road, spacing: float, mix: dict, source: str, sides=(1, -1), sea_side=False) -> None:
        line = LineString(road.points)
        half = road.width / 2.0
        offset = half - float(street["in_from_edge_m"]) if road.sidewalk else half + float(street["out_from_edge_m"])
        for point, direction in _along(line, spacing, float(street["jitter_m"]), rng):
            normal = np.array([-direction[1], direction[0]])
            chosen = sides
            if sea_side and beach_outline is not None:
                left, right = point + normal * offset, point - normal * offset
                chosen = (1,) if beach_outline.distance(Point(left)) < beach_outline.distance(Point(right)) else (-1,)
            for side in chosen:
                tree = point + normal * offset * side
                # A tree on a sidewalk is on the road surface of its own road.
                if place.free(tree, spacing * 0.6, own_road=road if road.sidewalk else None):
                    add(_pick(mix, rng), tree, source)

    coast = spec["coast_roads"]
    bai_truoc = spec["bai_truoc_road"]
    for road in roads:
        if road.name == coast_road:
            side_trees(road, float(bai_truoc["spacing_m"]), bai_truoc["mix"], "bai_truoc_road", sea_side=True)
        elif road.name in coast["names"]:
            side_trees(road, float(coast["spacing_m"]), coast["mix"], "coast_roads")
    for road in roads:
        if road.type in street["road_types"] and road.name != coast_road and road.name not in coast["names"]:
            side_trees(road, float(street["spacing_m"]), street["mix"], "street")

    park_spec = spec["parks"]
    spacing = float(park_spec["spacing_m"])
    for park in parks:
        near = near_point is not None and park.distance(near_point) <= float(park_spec["near_m"])
        mix = park_spec["mix_near"] if near else park_spec["mix"]
        min_x, min_y, max_x, max_y = park.bounds
        prepared = prep(park)
        for x in np.arange(min_x + spacing / 2, max_x, spacing):
            for y in np.arange(min_y + spacing / 2, max_y, spacing):
                point = np.array([x + rng.uniform(-2, 2), y + rng.uniform(-2, 2)])
                if prepared.contains(Point(*point)) and place.free(point, spacing * 0.6):
                    add(_pick(mix, rng), point, "parks")

    result = {"note": "Made by tools/geo/build.py from data/geo/trees.json and OSM. Do not change by hand. "
                      "Each point is [X, height, Z] in game coordinates.", "types": {}}
    for kind, points in sorted(found.items()):
        xy = np.array(points)
        h = sample_height(xy[:, 0], xy[:, 1])
        result["types"][kind] = [[round(float(x), 1), round(float(hh), 2), round(-float(y), 1)]
                                 for (x, y), hh in zip(points, h)]
    return result, counts
