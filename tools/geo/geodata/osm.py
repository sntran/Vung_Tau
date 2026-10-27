"""Reads the OSM extract with pyosmium and applies the corrections of overrides.json."""

from dataclasses import dataclass, field

import osmium
import shapely.wkb
from shapely.geometry.base import BaseGeometry

# Area tags that the pipeline uses. Other closed ways do not become areas.
AREA_KEYS = ("natural", "landuse", "leisure", "building", "tourism", "historic", "man_made", "amenity", "place", "water")


@dataclass
class Node:
    id: int
    lon: float
    lat: float
    tags: dict


@dataclass
class Way:
    id: int
    tags: dict
    refs: list[int]
    coords: list[tuple[float, float]]
    source: str = "osm"

    @property
    def closed(self) -> bool:
        return len(self.refs) > 3 and self.refs[0] == self.refs[-1]


@dataclass
class Area:
    """A closed way or a multipolygon relation. The geometry is in degrees."""

    id: int
    kind: str
    tags: dict
    geometry: BaseGeometry


@dataclass
class OsmData:
    nodes: list[Node] = field(default_factory=list)
    ways: list[Way] = field(default_factory=list)
    areas: list[Area] = field(default_factory=list)
    lon_range: tuple[float, float] = (0.0, 0.0)
    lat_range: tuple[float, float] = (0.0, 0.0)
    problems: list[str] = field(default_factory=list)
    corrections: list[str] = field(default_factory=list)
    # The roadworks of overrides.json (R11a). They are not shapes.
    roadworks: list[dict] = field(default_factory=list)
    # The rocky coasts of overrides.json (report 0005, D-0005-03): lon, lat, radius_m, sea_m.
    rock_coasts: list[dict] = field(default_factory=list)
    # The flat rocks along a coast of overrides.json (plan 0005, Q6): from, to, width_m, height_m, rough_m.
    rock_shelves: list[dict] = field(default_factory=list)


class _Handler(osmium.SimpleHandler):
    def __init__(self, data: OsmData):
        super().__init__()
        self.data = data
        self.wkb = osmium.geom.WKBFactory()
        self.min_lon = self.min_lat = 1e9
        self.max_lon = self.max_lat = -1e9

    def node(self, n):
        if not n.location.valid():
            return
        lon, lat = n.location.lon, n.location.lat
        self.min_lon = min(self.min_lon, lon)
        self.max_lon = max(self.max_lon, lon)
        self.min_lat = min(self.min_lat, lat)
        self.max_lat = max(self.max_lat, lat)
        if len(n.tags):
            self.data.nodes.append(Node(n.id, lon, lat, dict(n.tags)))

    def way(self, w):
        try:
            coords = [(nd.lon, nd.lat) for nd in w.nodes]
        except osmium.InvalidLocationError:
            self.data.problems.append(f"way {w.id} has nodes without a position")
            return
        if len(coords) < 2:
            return
        self.data.ways.append(Way(w.id, dict(w.tags), [nd.ref for nd in w.nodes], coords))

    def area(self, a):
        # A pedestrian area (highway=pedestrian, area=yes) is a place with no
        # trees (report 0020, D-0020-01). Other closed roads are not areas.
        pedestrian = "highway" in a.tags and a.tags.get("area") == "yes"
        if not pedestrian and not any(k in a.tags for k in AREA_KEYS):
            return
        try:
            geometry = shapely.wkb.loads(self.wkb.create_multipolygon(a), hex=True)
        except Exception as error:  # pyosmium gives a RuntimeError for a bad ring.
            self.data.problems.append(f"area {a.orig_id()} is not a correct polygon: {error}")
            return
        self.data.areas.append(Area(a.orig_id(), "way" if a.from_way() else "relation", dict(a.tags), geometry))


def read(path, corrections: list[dict] | None = None) -> OsmData:
    """Reads an .osm or .osm.pbf file."""
    data = OsmData()
    handler = _Handler(data)
    handler.apply_file(str(path), locations=True, idx="flex_mem")
    data.lon_range = (handler.min_lon, handler.max_lon)
    data.lat_range = (handler.min_lat, handler.max_lat)
    apply_corrections(data, corrections or [])
    return data


def apply_corrections(data: OsmData, corrections: list[dict]) -> None:
    """Applies the corrections of overrides.json (plan 0005, R7)."""
    by_id = {w.id: w for w in data.ways}
    added = 0
    for c in corrections:
        action = c.get("action")
        reason = c.get("reason", "")
        if not reason:
            data.problems.append(f"the correction {c} has no reason, so it is not used")
            continue
        if action == "add_node":
            added += 1
            node = Node(-added, float(c["lon"]), float(c["lat"]), dict(c["tags"]))
            data.nodes.append(node)
            data.corrections.append(f"add node {node.id} ({c['tags']}): {reason}")
        elif action == "add_way":
            added += 1
            coords = [tuple(p) for p in c["coords"]]
            # Corrections have negative IDs, so that they cannot be the same as an OSM ID.
            way = Way(-added, dict(c["tags"]), [-(added * 100000 + i) for i in range(len(coords))], coords, "override")
            if c.get("closed"):
                way.refs[-1] = way.refs[0]
            data.ways.append(way)
            data.corrections.append(f"add way {way.id} ({c['tags']}): {reason}")
        elif action == "roadworks":
            data.roadworks.append(c)
            data.corrections.append(f"roadworks on {c['road']} ({c['length_m']} m from the {c['from']}): {reason}")
        elif action == "rock_coast":
            data.rock_coasts.append(c)
            data.corrections.append(f"rock coast {c.get('name', '')} ({c['radius_m']} m around {c['lon']}, {c['lat']}): "
                                    f"{reason}")
        elif action == "rock_shelf":
            data.rock_shelves.append(c)
            data.corrections.append(f"rock shelf {c.get('name', '')} ({c['width_m']} m wide at {c['height_m']:+} m): {reason}")
        elif action in ("set_tags", "remove_way"):
            way = by_id.get(int(c["way"]))
            if way is None:
                data.problems.append(f"the correction for way {c['way']} finds no way")
                continue
            if action == "remove_way":
                data.ways.remove(way)
                data.corrections.append(f"remove way {way.id}: {reason}")
            else:
                for key, value in c["tags"].items():
                    if value is None:
                        way.tags.pop(key, None)
                    else:
                        way.tags[key] = value
                data.corrections.append(f"set tags of way {way.id} to {c['tags']}: {reason}")
        else:
            data.problems.append(f"the correction action {action!r} is not known")


def names(tags: dict) -> list[str]:
    """All the names of an OSM object."""
    keys = ("name", "name:vi", "name:en", "alt_name", "old_name", "official_name", "short_name", "alt_name:vi", "name:fr")
    result = []
    for key in keys:
        for value in tags.get(key, "").split(";"):
            value = value.strip()
            if value:
                result.append(value)
    return result
