"""Roads: the road types, the widths (plan 0004, R5), and the road network."""

import heapq
import math
import re
from dataclasses import dataclass, field

import numpy as np

# Highway values that are not roads on the ground.
NOT_ROADS = {"proposed", "construction", "platform", "bus_stop", "elevator", "corridor", "raceway", "abandoned", "razed", "rest_area", "services"}
# The order of importance. A more important road sets the ground height at a junction.
IMPORTANCE = ["motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential", "living_street",
              "pedestrian", "service", "alley", "track", "cycleway", "footway", "steps", "path"]
_LINK = re.compile(r"_link$")
# The width of a sidewalk. It is the same in scripts/geo/road_builder.gd.
SIDEWALK_WIDTH_M = 2.0


@dataclass
class Road:
    id: int
    type: str
    name: str
    width: float
    width_source: str
    surface: str
    hem: bool
    sidewalk: str
    oneway: bool
    lanes: int
    bridge: bool
    tunnel: bool
    refs: list[int]
    node_points: np.ndarray  # map (x, y) in meters of the OSM nodes, one for each ref
    points: np.ndarray = None  # map (x, y) of the line, with more points than the nodes
    source: str = "osm"
    heights: list[float] = field(default_factory=list)

    @property
    def length(self) -> float:
        return float(np.sum(np.linalg.norm(np.diff(self.points, axis=0), axis=1)))

    @property
    def importance(self) -> int:
        """The rank of the road: 0 is the most important. A hẻm has the rank of an alley."""
        kind = "alley" if self.hem and self.type not in ("footway", "path", "steps", "track", "cycleway") else self.type
        return IMPORTANCE.index(kind) if kind in IMPORTANCE else len(IMPORTANCE)


def road_type(tags: dict) -> str | None:
    """The road type of a way, or None when the way is not a road."""
    highway = tags.get("highway")
    if not highway or highway in NOT_ROADS or tags.get("area") == "yes":
        return None
    highway = _LINK.sub("", highway)
    if highway == "service" and tags.get("service") == "alley":
        return "alley"
    return highway


def parse_width(value: str | None) -> float | None:
    """Reads an OSM width tag in meters: "4", "4.5", "4 m", "4,5", or "13'"."""
    if not value:
        return None
    text = value.strip().lower().replace(",", ".")
    feet = re.fullmatch(r"([0-9.]+)\s*(ft|')", text)
    if feet:
        return round(float(feet.group(1)) * 0.3048, 2)
    meters = re.fullmatch(r"([0-9.]+)\s*(m|meter|meters)?", text)
    if meters:
        try:
            width = float(meters.group(1))
        except ValueError:
            return None
        return width if 0.3 <= width <= 80.0 else None
    return None


def has_hem_name(tags: dict, table: dict) -> bool:
    """In Vietnam, the name of a hẻm starts with "Hẻm" (in the center "Kiệt", in the north "Ngõ")."""
    name = tags.get("name", "")
    return any(name.startswith(prefix + " ") for prefix in table.get("hem_name_prefixes", []))


def width_of(tags: dict, kind: str, table: dict) -> tuple[float, str]:
    """The width of a road and where it comes from: "tag" or "table"."""
    tagged = parse_width(tags.get("width")) or parse_width(tags.get("est_width"))
    if tagged is not None:
        return tagged, "tag"
    if has_hem_name(tags, table):
        return float(table["hem_name_width"]), "table"
    if tags.get("highway", "").endswith("_link"):
        return float(table["link_width"]), "table"
    lanes = tags.get("lanes", "")
    if lanes.isdigit() and int(lanes) > 0:
        side = sidewalk_side(tags, kind, table)
        sidewalks = {"both": 2, "left": 1, "right": 1}.get(side, 0)
        return int(lanes) * float(table["lane_width"]) + sidewalks * SIDEWALK_WIDTH_M, "lanes"
    width = float(table["types"].get(kind, table["default"]))
    if is_oneway(tags):
        width = round(width * table.get("oneway_factor", 1.0), 2)
    return width, "table"


def is_oneway(tags: dict) -> bool:
    return tags.get("oneway") in ("yes", "1", "-1", "true")


def is_hem(kind: str, width: float, table: dict, tags: dict | None = None) -> bool:
    """A hẻm is a small road of a hẻm type with a width of 4 m or less (R5), or
    a road with a hẻm name."""
    if tags is not None and has_hem_name(tags, table):
        return True
    return kind in table["hem_types"] and width <= table["hem_max_width"]


def sidewalk_side(tags: dict, kind: str, table: dict) -> str:
    """The sides with a curb and a sidewalk: "both", "left", "right", or "".
    Main roads have them when OSM does not say otherwise (R11). A one-way main
    road is one carriageway of a divided road. Traffic in Vietnam keeps to the
    right, so the sidewalk of a carriageway is at its right side."""
    value = tags.get("sidewalk", tags.get("sidewalk:both"))
    if value in ("no", "none", "separate"):
        return ""
    if value in ("both", "left", "right"):
        return value
    if value == "yes":
        return "both"
    if kind not in table["sidewalk_types"]:
        return ""
    return "right" if is_oneway(tags) else "both"


def has_sidewalk(tags: dict, kind: str, table: dict) -> bool:
    return sidewalk_side(tags, kind, table) != ""


def make_roads(ways, projection, table: dict) -> list[Road]:
    roads = []
    for way in ways:
        kind = road_type(way.tags)
        if kind is None:
            continue
        width, source = width_of(way.tags, kind, table)
        lon, lat = zip(*way.coords)
        x, y = projection.to_map(np.array(lon), np.array(lat))
        lanes = way.tags.get("lanes", "")
        roads.append(Road(
            id=way.id, type=kind, name=way.tags.get("name", ""), width=width, width_source=source,
            surface=way.tags.get("surface", ""), hem=is_hem(kind, width, table, way.tags),
            sidewalk=sidewalk_side(way.tags, kind, table), oneway=is_oneway(way.tags),
            lanes=int(lanes) if lanes.isdigit() else 0, bridge=way.tags.get("bridge", "no") != "no",
            tunnel=way.tags.get("tunnel", "no") != "no", refs=list(way.refs),
            node_points=np.column_stack([x, y]), points=np.column_stack([x, y]), source=way.source))
    return roads


def densify(points: np.ndarray, step: float) -> np.ndarray:
    """Adds points so that no part of the line is longer than step."""
    result = [points[0]]
    for a, b in zip(points[:-1], points[1:]):
        length = float(np.linalg.norm(b - a))
        parts = max(1, math.ceil(length / step))
        for i in range(1, parts + 1):
            result.append(a + (b - a) * (i / parts))
    return np.array(result)


class Network:
    """The road network: a graph of the OSM nodes, with the road lengths."""

    def __init__(self, roads: list[Road]):
        self.edges: dict[int, list[tuple[int, float, Road]]] = {}
        self.position: dict[int, np.ndarray] = {}
        for road in roads:
            if road.type in ("steps",):
                continue
            for i, ref in enumerate(road.refs):
                self.position[ref] = road.node_points[i]
            for i in range(len(road.refs) - 1):
                a, b = road.refs[i], road.refs[i + 1]
                length = float(np.linalg.norm(road.node_points[i + 1] - road.node_points[i]))
                self.edges.setdefault(a, []).append((b, length, road))
                self.edges.setdefault(b, []).append((a, length, road))

    def nearest(self, point, allowed=None) -> int | None:
        best, best_d = None, math.inf
        for ref, pos in self.position.items():
            if allowed is not None and ref not in allowed:
                continue
            d = float(np.linalg.norm(pos - point))
            if d < best_d:
                best, best_d = ref, d
        return best

    def shortest_path(self, sources: set[int], target: int) -> list[int]:
        """Dijkstra from a set of source nodes. Returns the node list, or an empty list."""
        dist = {s: 0.0 for s in sources}
        previous: dict[int, int] = {}
        queue = [(0.0, s) for s in sources]
        heapq.heapify(queue)
        while queue:
            d, node = heapq.heappop(queue)
            if node == target:
                path = [node]
                while path[-1] in previous:
                    path.append(previous[path[-1]])
                return path[::-1]
            if d > dist.get(node, math.inf):
                continue
            for other, length, _road in self.edges.get(node, []):
                nd = d + length
                if nd < dist.get(other, math.inf):
                    dist[other] = nd
                    previous[other] = node
                    heapq.heappush(queue, (nd, other))
        return []

    def roads_at(self, ref: int) -> list[Road]:
        return [road for _other, _length, road in self.edges.get(ref, [])]
