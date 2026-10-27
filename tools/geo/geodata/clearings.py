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


def road_shapes(roads, config: dict) -> list[Polygon]:
    """The roads and the paths with a margin: no tree trunk stands on them."""
    margin = float(config.get("road_margin_m", 1.5))
    result = []
    for road in roads:
        if road.points is None or len(road.points) < 2:
            continue
        result.append(LineString(road.points).buffer(road.width / 2.0 + margin))
    return result

