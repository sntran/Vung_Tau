"""Finds the homestay hẻm (plan 0004, R8a and R8c)."""

import math

import numpy as np
from shapely.geometry import LineString, Point

# Road types that can be the coast road at Bãi Trước.
COAST_ROAD_TYPES = {"trunk", "primary", "secondary", "tertiary", "unclassified", "residential"}
COAST_ROAD_DISTANCE_M = 120.0
# Main roads: the lighthouse road starts where the path leaves them.
MAIN_ROAD_TYPES = {"motorway", "trunk", "primary", "secondary"}
CURVE_TURN_DEG = 45.0
CURVE_LENGTH_M = 60.0
HEM_ANGLE_DEG = 30.0
# The distance from the end of the curve where a hẻm can start.
HEM_SEARCH_M = 25.0
# The length of a hẻm that gives its direction.
HEM_DIRECTION_M = 15.0
HEADING_LENGTH_M = 10.0
RESAMPLE_M = 2.0
# Two directions with this difference or less are the same for the start and the end of a turn.
TIE_DEG = 2.0


def heading(a, b) -> float:
    """The direction from a to b in degrees, clockwise from north (map x east, y north)."""
    return math.degrees(math.atan2(b[0] - a[0], b[1] - a[1]))


def turn(a: float, b: float) -> float:
    return (b - a + 180.0) % 360.0 - 180.0


def resample(points: np.ndarray, step: float) -> tuple[np.ndarray, np.ndarray]:
    line = LineString(points)
    distances = np.arange(0.0, line.length + 0.001, step)
    return np.array([[line.interpolate(d).x, line.interpolate(d).y] for d in distances]), distances


def find_curve(points: np.ndarray) -> dict | None:
    """The first curve from the start of the line: a change of direction of more
    than 45 degrees in 60 m or less (R8a, step 3). Returns the start and the
    end of the turn, and the direction before the turn."""
    line, s = resample(points, RESAMPLE_M)
    n = int(HEADING_LENGTH_M / RESAMPLE_M)
    if len(line) < 2 * n + 2:
        return None
    # headings[k] is the direction from line[k] to line[k + n].
    headings = [heading(line[k], line[k + n]) for k in range(len(line) - n)]
    window = int(CURVE_LENGTH_M / RESAMPLE_M)
    found = None
    for j in range(1, len(headings)):
        for i in range(max(0, j - window + n), j):
            if abs(turn(headings[i], headings[j])) > CURVE_TURN_DEG:
                found = j
                break
        if found is not None:
            break
    if found is None:
        return None
    # The turn starts where the direction is the most different from the direction
    # at "found", in the 60 m before it. It ends where the direction is the most
    # different from the start, in the 60 m after "found".
    before = range(max(0, found - window), found + 1)
    most = max(abs(turn(headings[k], headings[found])) for k in before)
    start = max(k for k in before if abs(turn(headings[k], headings[found])) >= most - TIE_DEG)
    after = range(found, min(len(headings), found + window + 1))
    most = max(abs(turn(headings[start], headings[k])) for k in after)
    end = min(k for k in after if abs(turn(headings[start], headings[k])) >= most - TIE_DEG)
    start_point = min(len(line) - 1, start + n)
    return {
        "start": line[start_point].tolist(), "end": line[end].tolist(),
        "start_distance_m": float(s[start_point]), "end_distance_m": float(s[end]),
        "heading_before": headings[start], "heading_after": headings[end],
        "turn_deg": float(turn(headings[start], headings[end])),
    }


def _edge_road(network, a: int, b: int):
    return next(road for other, _length, road in network.edges[a] if other == b)


def _direction_from(road, ref_index: int):
    """Gives (step, direction) for each way along the road from one of its nodes."""
    pts = road.node_points
    for step in (1, -1):
        path = [pts[ref_index]]
        length, i = 0.0, ref_index
        while 0 <= i + step < len(pts) and length < HEM_DIRECTION_M:
            length += float(np.linalg.norm(pts[i + step] - pts[i]))
            i += step
            path.append(pts[i])
        if length >= 3.0:
            yield step, heading(path[0], path[-1])


def find(roads, network, landmarks: dict, beach_outline, blocks) -> dict:
    """Returns the record of homestay.json."""
    result = {"found": False, "candidates": [], "problems": []}
    lighthouse = landmarks.get("hai_dang")
    if not lighthouse or not lighthouse.get("found"):
        result["problems"].append("the lighthouse (hai_dang) is not in the data")
        return result
    light = np.array([lighthouse["position"][0], -lighthouse["position"][1]])
    target = network.nearest(light)
    if target is None:
        result["problems"].append("the road network is empty")
        return result
    result["lighthouse_node"] = target
    result["lighthouse_node_distance_m"] = round(float(np.linalg.norm(network.position[target] - light)), 1)
    beach = beach_outline if beach_outline is not None else None
    if beach is None:
        result["problems"].append("Bãi Trước has no outline, so the coast road is not known")
        return result
    # The coast road is the road (by name) that runs near Bãi Trước for the longest distance.
    near_length: dict[str, float] = {}
    for road in roads:
        if road.type not in COAST_ROAD_TYPES or road.hem:
            continue
        line = LineString(road.points)
        inside = line.intersection(beach.buffer(COAST_ROAD_DISTANCE_M))
        key = road.name or f"way {road.id}"
        near_length[key] = near_length.get(key, 0.0) + inside.length
    if not near_length or max(near_length.values()) <= 0.0:
        result["problems"].append("no road is near Bãi Trước")
        return result
    coast_name = max(near_length, key=near_length.get)
    result["coast_road"] = coast_name
    sources = set()
    for road in roads:
        if (road.name or f"way {road.id}") != coast_name:
            continue
        for ref, point in zip(road.refs, road.node_points):
            if beach.distance(Point(point)) <= COAST_ROAD_DISTANCE_M * 3:
                sources.add(ref)
    path = network.shortest_path(sources, target)
    if len(path) < 2:
        result["problems"].append("no road goes from Bãi Trước to the lighthouse")
        return result
    # The lighthouse road starts where the path leaves the coast road and the
    # other main roads along the coast (for example a coast road with another name).
    start = max(i for i, ref in enumerate(path) if ref in sources)
    while start + 1 < len(path) and _edge_road(network, path[start], path[start + 1]).type in MAIN_ROAD_TYPES:
        start += 1
    path = path[start:]
    if len(path) < 2:
        result["problems"].append("the lighthouse is on the coast road")
        return result
    path_points = np.array([network.position[r] for r in path])
    result["lighthouse_road"] = {"nodes": len(path), "length_m": round(float(LineString(path_points).length), 1),
                                 "points": path_points}
    curve = find_curve(path_points)
    if curve is None:
        result["problems"].append("the lighthouse road has no curve of more than 45 degrees in 60 m")
        return result
    result["curve"] = curve
    end = np.array(curve["end"])
    on_path = set(path)
    for road in roads:
        if not road.hem:
            continue
        for index, ref in enumerate(road.refs):
            point = road.node_points[index]
            if np.linalg.norm(point - end) > HEM_SEARCH_M:
                continue
            joined = ref in on_path or LineString(path_points).distance(Point(point)) < 3.0
            if not joined:
                continue
            for _step, direction in _direction_from(road, index):
                diff = abs(turn(curve["heading_before"], direction))
                if diff <= HEM_ANGLE_DEG and not any(c["road"] is road for c in result["candidates"]):
                    result["candidates"].append({"road": road, "angle_diff_deg": round(diff, 1),
                                                 "junction": point.tolist(),
                                                 "distance_to_curve_end_m": round(float(np.linalg.norm(point - end)), 1)})
    if len(result["candidates"]) == 1:
        hem = result["candidates"][0]["road"]
        result["found"] = True
        result["hem"] = hem
        line = LineString(hem.points)
        result["blocks"] = [i for i, b in enumerate(blocks) if b["polygon"].distance(line) < 20.0]
    elif not result["candidates"]:
        result["problems"].append("no hẻm leaves the road at the end of the curve in the direction before the curve")
    else:
        result["problems"].append(f"{len(result['candidates'])} hẻm leave the road at the end of the curve")
    return result
