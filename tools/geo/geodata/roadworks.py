"""Roadworks on a part of a road (plan 0005, R11a). The roadworks are data in
overrides.json, so a later plan can remove them when the work ends."""

import numpy as np
from shapely.geometry import LineString, Point

from .projection import map_to_game


def chain(roads: list) -> np.ndarray | None:
    """The points of the roads as one line, from the lowest end. The roads
    join at shared OSM nodes. The longest chain from the lowest end wins."""
    if not roads:
        return None
    ends: dict[int, list] = {}
    for road in roads:
        ends.setdefault(road.refs[0], []).append((road, False))
        ends.setdefault(road.refs[-1], []).append((road, True))

    def height(road, at_end: bool) -> float:
        return road.heights[-1] if at_end else road.heights[0]

    # The lowest end of all roads that is the end of only one road.
    starts = [(height(r, e), ref, r, e) for ref, items in ends.items() if len(items) == 1 for r, e in items]
    if not starts:
        starts = [(height(r, False), r.refs[0], r, False) for r in roads]
    _h, _ref, road, at_end = min(starts, key=lambda s: s[0])
    used = {id(road)}
    points = road.points[::-1] if at_end else road.points
    heights = list(road.heights[::-1] if at_end else road.heights)
    last = road.refs[0] if at_end else road.refs[-1]
    while True:
        following = [(r, e) for r, e in ends.get(last, []) if id(r) not in used]
        if not following:
            break
        road, at_end = following[0]
        used.add(id(road))
        part = road.points[::-1] if at_end else road.points
        points = np.vstack([points, part[1:]])
        heights += list(road.heights[::-1] if at_end else road.heights)[1:]
        last = road.refs[0] if at_end else road.refs[-1]
    return np.column_stack([points, heights])


def cut(line: np.ndarray, length: float) -> np.ndarray:
    """The first length meters of a line of (x, y, height) points."""
    result = [line[0]]
    done = 0.0
    for a, b in zip(line[:-1], line[1:]):
        step = float(np.linalg.norm(b[:2] - a[:2]))
        if done + step >= length:
            part = (length - done) / step if step > 0 else 0.0
            result.append(a + (b - a) * part)
            break
        result.append(b)
        done += step
    return np.array(result)


def make(spec: dict, roads: list, hem=None) -> tuple[dict | None, list[str]]:
    """The roadworks record for the build folder, or None and the problems."""
    named = [r for r in roads if r.name == spec["road"] and len(r.heights) == len(r.points)]
    line = chain(named)
    if line is None:
        return None, [f"the roadworks road {spec['road']} is not in the data"]
    part = cut(line, float(spec["length_m"]))
    road_width = max(r.width for r in named)
    widen = float(spec.get("widen_m", 0.0))
    record = {"road": spec["road"], "from": spec["from"], "length_m": round(float(LineString(part[:, :2]).length), 1),
              "width_m": round(road_width + widen, 2), "road_width_m": round(road_width, 2), "widen_m": widen,
              "planned_end": spec["planned_end"], "contractor": spec["contractor"], "sign": spec["sign"],
              "work_hours": spec["work_hours"],
              "points": [[round(float(x), 2), round(float(h), 2), round(-float(y), 2)] for x, y, h in part]}
    if hem is not None:
        line_2d = LineString(part[:, :2])
        for end in (hem.points[0], hem.points[-1]):
            if line_2d.distance(Point(end)) < 3.0:
                record["corner"] = {"hem": hem.name, "point": map_to_game([end])[0],
                                    "distance_m": round(float(line_2d.project(Point(end))), 1)}
    return record, []
