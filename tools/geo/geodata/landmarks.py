"""Finds the landmarks of data/geo/landmarks.json in the OSM data (plan 0005, R1 and R4)."""

import math
import unicodedata

import numpy as np
import shapely
from shapely.geometry import Point

from .osm import names


def fold(text: str) -> str:
    """Lower case text without diacritics, for name comparison. "đ" becomes "d"."""
    text = text.lower().replace("đ", "d")
    return "".join(c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn").strip()


def _matches_tags(tags: dict, wanted: dict) -> bool:
    return all(key in tags and (value == "*" or tags[key] == value) for key, value in wanted.items())


def _matches_name(tags: dict, landmark: dict) -> bool:
    wanted = [fold(landmark["name_vi"])] + [fold(n) for n in landmark.get("other_names", [])]
    exact = landmark.get("exact_name", False)
    for name in names(tags):
        folded = fold(name)
        if any(w == folded or (not exact and w in folded) for w in wanted):
            return True
    return False


def candidates(landmark: dict, data) -> list[dict]:
    """All OSM objects that match one search of the landmark and one of its names."""
    result = []
    for rank, search in enumerate(landmark["search"]):
        wanted = search["tags"]
        for node in data.nodes:
            if _matches_tags(node.tags, wanted) and _matches_name(node.tags, landmark):
                result.append({"rank": rank, "kind": "node", "id": node.id, "tags": node.tags,
                               "lonlat": (node.lon, node.lat), "geometry": None})
        for area in data.areas:
            if _matches_tags(area.tags, wanted) and _matches_name(area.tags, landmark):
                c = area.geometry.centroid
                result.append({"rank": rank, "kind": area.kind, "id": area.id, "tags": area.tags,
                               "lonlat": (c.x, c.y), "geometry": area.geometry})
        for way in data.ways:
            if way.closed and any(k in way.tags for k in ("natural", "tourism", "historic", "man_made", "building")):
                continue  # The area has this way already.
            if _matches_tags(way.tags, wanted) and _matches_name(way.tags, landmark):
                lon, lat = way.coords[len(way.coords) // 2]
                result.append({"rank": rank, "kind": "way", "id": way.id, "tags": way.tags,
                               "lonlat": (lon, lat), "geometry": None})
    unique, seen = [], set()
    for c in result:
        if (c["kind"], c["id"]) not in seen:
            seen.add((c["kind"], c["id"]))
            unique.append(c)
    return unique


def _distance_m(a, b) -> float:
    lat = math.radians((a[1] + b[1]) / 2)
    return math.hypot((a[0] - b[0]) * 111320 * math.cos(lat), (a[1] - b[1]) * 110540)


def choose(landmark: dict, found: list[dict]) -> dict | None:
    """The best candidate: the first search that matches, then an area before a
    node, then the nearest to the hint."""
    if not found:
        return None
    hint = landmark.get("hint")
    best_rank = min(c["rank"] for c in found)
    found = [c for c in found if c["rank"] == best_rank]

    def key(c):
        shape_order = 0 if c["geometry"] is not None else 1
        d = _distance_m(c["lonlat"], (hint["lon"], hint["lat"])) if hint else 0.0
        return (shape_order, d)

    return min(found, key=key)


def find_all(config, data, projection, grid=None) -> list[dict]:
    """Returns one record for each landmark, found or not found."""
    result = []
    for landmark in config.landmarks:
        found = candidates(landmark, data)
        best = choose(landmark, found)
        record = {"id": landmark["id"], "name_vi": landmark["name_vi"], "found": best is not None}
        if best is None:
            record["reason"] = "no OSM object has these tags and one of these names"
            if landmark.get("hint"):
                hx, hz = projection.to_game(landmark["hint"]["lon"], landmark["hint"]["lat"])
                record["hint_position"] = [round(float(hx), 1), round(float(hz), 1)]
            result.append(record)
            continue
        x, z = projection.to_game(*best["lonlat"])
        record.update({
            "osm": f"{best['kind']}/{best['id']}",
            "osm_name": best["tags"].get("name", ""),
            "lonlat": [round(best["lonlat"][0], 7), round(best["lonlat"][1], 7)],
            "position": [round(float(x), 2), round(float(z), 2)],
            "candidates": len(found),
        })
        if "ele" in best["tags"]:
            try:
                record["ele_tag"] = float(best["tags"]["ele"].split()[0].replace(",", "."))
            except ValueError:
                pass
        if grid is not None:
            record["height"] = round(float(grid.sample(x, z)), 2)
        if best["geometry"] is not None:
            outline = shapely.transform(best["geometry"],
                                        lambda c: np.column_stack(projection.to_game(c[:, 0], c[:, 1])))
            polygon = max(outline.geoms, key=lambda g: g.area) if hasattr(outline, "geoms") else outline
            record["outline"] = [[round(float(px), 2), round(float(pz), 2)] for px, pz in polygon.exterior.coords]
            record["area_m2"] = round(float(polygon.area), 1)
        if landmark.get("hint"):
            record["distance_to_hint_m"] = round(_distance_m(best["lonlat"], (landmark["hint"]["lon"], landmark["hint"]["lat"])), 1)
        result.append(record)
    return result


def in_box(lonlat, bbox) -> bool:
    west, south, east, north = bbox
    return west <= lonlat[0] <= east and south <= lonlat[1] <= north


def point_in_box(point: Point, bbox) -> bool:
    return in_box((point.x, point.y), bbox)
