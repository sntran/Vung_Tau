"""The street trees and the park trees (plan 0005, R12a). With the tree tops
of the canopy map (report 0020, D-0020-03): on the confirmed roads and in the
park of Bãi Trước, the rows of the photos stay, and each tree moves to the
nearest free tree top within snap_m; on the other roads and in the other
parks, a tree stands only on a tree top of the map."""

import math

import numpy as np
import shapely
from shapely import STRtree
from shapely.geometry import LineString, Point
from shapely.prepared import prep
from scipy.spatial import cKDTree

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


class _Tops:
    """The tree tops of the canopy map (map x, y): each one takes one tree."""

    def __init__(self, points):
        self.points = np.asarray(points, dtype=float) if points is not None and len(points) else np.zeros((0, 2))
        self.tree = cKDTree(self.points) if len(self.points) else None
        self.used = np.zeros(len(self.points), dtype=bool)

    def nearest(self, point, radius: float):
        """The index of the nearest free tree top within radius, or -1."""
        if self.tree is None:
            return -1
        for i in sorted(self.tree.query_ball_point(point, radius), key=lambda i: np.hypot(*(self.points[i] - point))):
            if not self.used[i]:
                return i
        return -1

    def within(self, shape) -> list[int]:
        """The free tree tops in a shape."""
        if self.tree is None:
            return []
        min_x, min_y, max_x, max_y = shape.bounds
        box = np.nonzero((self.points[:, 0] >= min_x) & (self.points[:, 0] <= max_x)
                         & (self.points[:, 1] >= min_y) & (self.points[:, 1] <= max_y) & ~self.used)[0]
        prepared = prep(shape)
        return [int(i) for i in box if prepared.contains(Point(*self.points[i]))]


def make(spec: dict, roads: list, land, beaches: list, parks: list, osm_trees: list, osm_rows: list,
         coast_road: str, beach_outline, near_point, sample_height, tops=None) -> tuple[dict, dict, dict]:
    """The trees for the build folder, the counts for the report, and the
    points of each group (map x, y) for the report.
    parks: park shapes (map). osm_trees: (x, y, tags). osm_rows: (LineString, tags).
    near_point: the map point of the landmark for the parks near it.
    sample_height(x, y): the ground height at map points (arrays).
    tops: the tree tops of the canopy map (map x, y), or None for the rules alone."""
    rng = np.random.default_rng(int(spec.get("seed", 1)))
    street = spec["street"]
    place = _Place(land, beaches, roads, float(street["skip_near_road_m"]))
    found: dict[str, list] = {}
    counts: dict[str, int] = {}
    groups: dict[str, list] = {}
    canopy = spec.get("canopy", {})
    use_tops = tops is not None and canopy.get("use", True)
    tree_tops = _Tops(tops if use_tops else None)
    snap_m = float(canopy.get("snap_m", 6.0))
    edge_m = float(canopy.get("edge_m", 6.0))

    def add(kind: str, point, source: str) -> None:
        found.setdefault(kind, []).append((float(point[0]), float(point[1])))
        groups.setdefault(source, []).append((float(point[0]), float(point[1])))
        counts[source] = counts.get(source, 0) + 1

    def snapped(point, source: str):
        """The point, or the nearest free tree top within snap_m."""
        i = tree_tops.nearest(point, snap_m)
        if i < 0:
            return point, -1
        return tree_tops.points[i], i

    def take(i: int, source: str) -> None:
        if i >= 0:
            tree_tops.used[i] = True
            counts[source + "_snapped"] = counts.get(source + "_snapped", 0) + 1

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
                # A tree moves to the nearest tree top of the canopy map, where there is a free one.
                moved, top = snapped(tree, source)
                # A tree on a sidewalk is on the road surface of its own road.
                if top >= 0 and place.free(moved, spacing * 0.6, own_road=road if road.sidewalk else None):
                    take(top, source)
                    add(_pick(mix, rng), moved, source)
                elif place.free(tree, spacing * 0.6, own_road=road if road.sidewalk else None):
                    add(_pick(mix, rng), tree, source)

    def top_trees(road, mix: dict, source: str) -> None:
        """A tree on each free tree top of the canopy map within edge_m of the road
        edge, out of the road surface: no tree where the map has none."""
        line = LineString(road.points)
        half = road.width / 2.0
        offset = half - float(street["in_from_edge_m"]) if road.sidewalk else half + float(street["out_from_edge_m"])
        gap = float(street["spacing_m"]) * 0.5
        for i in tree_tops.within(line.buffer(half + edge_m)):
            point = tree_tops.points[i]
            along = line.project(Point(*point))
            on_line = np.array(line.interpolate(along).coords[0])
            out = point - on_line
            distance = float(np.linalg.norm(out))
            if distance < offset:
                # A crown over the road: the trunk stands at the edge, on the same side.
                if distance < 0.01:
                    continue
                point = on_line + out / distance * offset
            if place.free(point, gap, own_road=road if road.sidewalk else None):
                take(i, source)
                add(_pick(mix, rng), point, source)

    coast = spec["coast_roads"]
    bai_truoc = spec["bai_truoc_road"]
    for road in roads:
        if road.name == coast_road:
            side_trees(road, float(bai_truoc["spacing_m"]), bai_truoc["mix"], "bai_truoc_road", sea_side=True)
        elif road.name in coast["names"]:
            side_trees(road, float(coast["spacing_m"]), coast["mix"], "coast_roads")
    named = spec.get("named_roads", {})
    for road in roads:
        if road.name == coast_road or road.name in coast["names"]:
            continue
        if road.name in named:
            # A road with its own trees (plan 0020, Q1): for example the tall shade trees of Trần Hưng Đạo.
            side_trees(road, float(named[road.name]["spacing_m"]), named[road.name]["mix"], "named_roads")
        elif road.type in street["road_types"]:
            if use_tops:
                top_trees(road, street["mix"], "street")
            else:
                side_trees(road, float(street["spacing_m"]), street["mix"], "street")

    park_spec = spec["parks"]
    spacing = float(park_spec["spacing_m"])
    for park in parks:
        near = near_point is not None and park.distance(near_point) <= float(park_spec["near_m"])
        mix = park_spec["mix_near"] if near else park_spec["mix"]
        source = "park_bai_truoc" if near else "parks"
        if use_tops and not near:
            # The other parks: a tree on each tree top of the canopy map in the park.
            for i in tree_tops.within(park):
                if place.free(tree_tops.points[i], spacing * 0.5):
                    take(i, source)
                    add(_pick(mix, rng), tree_tops.points[i], source)
            continue
        min_x, min_y, max_x, max_y = park.bounds
        prepared = prep(park)
        for x in np.arange(min_x + spacing / 2, max_x, spacing):
            for y in np.arange(min_y + spacing / 2, max_y, spacing):
                point = np.array([x + rng.uniform(-2, 2), y + rng.uniform(-2, 2)])
                if not prepared.contains(Point(*point)):
                    continue
                moved, top = snapped(point, source)
                if top >= 0 and prepared.contains(Point(*moved)) and place.free(moved, spacing * 0.6):
                    take(top, source)
                    add(_pick(mix, rng), moved, source)
                elif place.free(point, spacing * 0.6):
                    add(_pick(mix, rng), point, source)

    result = {"note": "Made by tools/geo/build.py from data/geo/trees.json and OSM. Do not change by hand. "
                      "Each point is [X, height, Z] in game coordinates.", "types": {}}
    for kind, points in sorted(found.items()):
        xy = np.array(points)
        h = sample_height(xy[:, 0], xy[:, 1])
        result["types"][kind] = [[round(float(x), 1), round(float(hh), 2), round(-float(y), 1)]
                                 for (x, y), hh in zip(points, h)]
    return result, counts, groups
