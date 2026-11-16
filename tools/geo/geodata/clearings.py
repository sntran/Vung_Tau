"""The places with no trees (report 0020, D-0020-01): the paved tops and the
platforms of the known places, the OSM areas of data/geo/clearings.json, and
the roads and the paths. The hill trees and the bushes do not stand there."""

from shapely.geometry import LineString, Point, Polygon


def place_shapes(areas, to_map, found_by_id: dict, config: dict) -> list[Polygon]:
    """The places with no trees and no bushes, in map meters: the OSM areas with
    one of the keys (not larger than max_area_m2), the pedestrian areas, and a
    circle around each landmark of the list. Each one has a margin of margin_m."""
    keys = config.get("osm_keys", [])
    largest = float(config.get("max_area_m2", 30000.0))
    margin = float(config.get("margin_m", 2.0))
    result = []
    for a in areas:
        tags = a.tags
        pedestrian = config.get("osm_pedestrian_areas", True) and "highway" in tags and tags.get("area") == "yes"
        if not pedestrian and not any(k in tags for k in keys):
            continue
        shape = to_map(a.geometry)
        if shape.is_empty or shape.area > largest:
            continue
        result.append(shape.buffer(margin))
    for landmark_id, radius in config.get("landmarks", {}).items():
        record = found_by_id.get(landmark_id)
        if not record or not record.get("found"):
            continue
        x, z = record["position"]
        result.append(Point(x, -z).buffer(float(radius)))
    return result


def inside_shapes(roads, config: dict, found_by_id: dict | None = None) -> list[Polygon]:
    """The areas inside a ring of a way (report 0020, the re-check of
    2026-11-05: the trees inside the road around the top of Núi Nhỏ). Each
    entry of "inside_ways" has the OSM id of the way ("way"), and can have a
    landmark ("near") and a distance ("within_m"): only the points of the way
    within that distance of the landmark make the ring. The ring closes from
    its last point to its first point."""
    margin = float(config.get("margin_m", 2.0))
    by_id = {road.id: road for road in roads}
    result = []
    for entry in config.get("inside_ways", []):
        if not isinstance(entry, dict):
            entry = {"way": entry}
        road = by_id.get(int(entry["way"]))
        if road is None or road.points is None:
            continue
        points = [tuple(p) for p in road.points]
        near = (found_by_id or {}).get(entry.get("near", ""))
        if near and near.get("found") and "within_m" in entry:
            x, z = near["position"]
            limit = float(entry["within_m"])
            points = [p for p in points if ((p[0] - x) ** 2 + (p[1] + z) ** 2) ** 0.5 <= limit]
        if len(points) < 3:
            continue
        shape = Polygon(points).buffer(0)
        if not shape.is_empty:
            result.append(shape.buffer(margin + road.width / 2.0))
    return result


def road_shapes(roads, config: dict) -> list[Polygon]:
    """The roads and the paths with a margin: no tree trunk stands on them."""
    margin = float(config.get("road_margin_m", 1.5))
    result = []
    for road in roads:
        if road.points is None or len(road.points) < 2:
            continue
        result.append(LineString(road.points).buffer(road.width / 2.0 + margin))
    return result

