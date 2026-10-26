"""The objects on the sea (plan 0005, R13a): ships at anchor, fishing boats,
basket boats (thúng), rows of fishing stakes, the pier, and the groynes."""

import math

import numpy as np
import shapely
from shapely import ops
from shapely.geometry import Polygon

from .projection import map_to_game


def _points_in(area: Polygon, count: int, spacing: float, rng: np.random.Generator, accept) -> list[tuple[float, float]]:
    """Random points in the area, at least spacing apart, where accept(x, y) is true."""
    min_x, min_y, max_x, max_y = area.bounds
    result: list[tuple[float, float]] = []
    for _ in range(count * 200):
        if len(result) >= count:
            break
        x, y = rng.uniform(min_x, max_x), rng.uniform(min_y, max_y)
        if not area.contains(shapely.Point(x, y)) or not accept(x, y):
            continue
        if all(math.hypot(x - px, y - py) >= spacing for px, py in result):
            result.append((x, y))
    return result


def _area(points: list, projection) -> Polygon:
    lon, lat = zip(*points)
    x, y = projection.to_map(np.array(lon), np.array(lat))
    return Polygon(np.column_stack([x, y]))


def _boats(spec: dict, projection, rng: np.random.Generator, accept, kinds: list[str], beaches=None, floor_at=None,
           placed: list | None = None) -> list[dict]:
    """The ships or the boats of spec in their areas. An area can keep away
    from a beach: "away_from_beach": {"name": ..., "m": ...} (plan 0005, Q6:
    the boats are farther out in front of the swimmers of the main beach).
    placed has the points of the boats of the other areas, for the spacing."""
    result = []
    total = int(spec["count"])
    placed = [] if placed is None else placed
    for index, area_spec in enumerate(spec["areas"]):
        area = _area(area_spec["polygon"], projection)
        share = float(area_spec.get("share", 1.0))
        count = total - len(result) if index == len(spec["areas"]) - 1 else int(round(total * share))
        floor = float(area_spec.get("min_floor_m", spec["min_floor_m"]))
        away = area_spec.get("away_from_beach")
        keep_off = None
        if away is not None:
            shapes = [b for name, b in (beaches or []) if name == away["name"]]
            keep_off = ops.unary_union(shapes).buffer(float(away["m"])) if shapes else None

        def ok(a: float, b: float) -> bool:
            if keep_off is not None and keep_off.contains(shapely.Point(a, b)):
                return False
            spacing = float(spec["min_spacing_m"])
            return accept(a, b, floor) and all(math.hypot(a - px, b - py) >= spacing for px, py in placed)

        for px, py in _points_in(area, count, float(spec["min_spacing_m"]), rng, ok):
            placed.append((px, py))
            heading = float(spec.get("heading_deg", rng.uniform(0, 360))) + rng.uniform(-1, 1) * float(
                spec.get("heading_spread_deg", 180))
            low, high = spec["length_m"]
            record = {"position": map_to_game([(px, py)])[0], "heading_deg": round(heading % 360, 1),
                      "length_m": round(float(rng.uniform(low, high)), 1), "kind": kinds[int(rng.integers(len(kinds)))],
                      "seed": int(rng.integers(1 << 30)), "area": area_spec["name"]}
            if floor_at is not None:
                record["floor_m"] = round(float(floor_at(px, py)), 2)
            result.append(record)
    return result


def _basket_boats(spec: dict, boats: list[dict], projection, rng: np.random.Generator, accept, floor_at) -> list[dict]:
    """The round basket boats (thúng) of the fishermen (plan 0005, Q6): some
    near the sand at the ends of the beach, and some tied beside the fishing
    boats of the areas in spec["tied_areas"]."""
    result = []
    low, high = spec["diameter_m"]
    for area_spec in spec.get("near_sand", []):
        area = _area(area_spec["polygon"], projection)
        floor = float(area_spec.get("min_floor_m", 0.0))
        for px, py in _points_in(area, int(area_spec["count"]), float(spec["min_spacing_m"]), rng,
                                 lambda a, b: accept(a, b, floor)):
            result.append({"position": map_to_game([(px, py)])[0], "heading_deg": round(float(rng.uniform(0, 360)), 1),
                           "diameter_m": round(float(rng.uniform(low, high)), 2), "floor_m": round(float(floor_at(px, py)), 2),
                           "tied_to": -1, "area": area_spec["name"]})
    for index, boat in enumerate(boats):
        if boat["area"] not in spec.get("tied_areas", []) or rng.uniform() > float(spec["tied_share"]):
            continue
        # Beside the stern of the boat, on the side.
        angle = math.radians(boat["heading_deg"])
        side = 1.0 if rng.uniform() < 0.5 else -1.0
        bx, bz = boat["position"]
        beam = boat["length_m"] * 0.3
        x = bx + math.cos(angle) * side * (beam / 2.0 + 1.4) + math.sin(angle) * boat["length_m"] * 0.3
        z = bz + math.sin(angle) * side * (beam / 2.0 + 1.4) - math.cos(angle) * boat["length_m"] * 0.3
        result.append({"position": [round(x, 2), round(z, 2)], "heading_deg": round(float(rng.uniform(0, 360)), 1),
                       "diameter_m": round(float(rng.uniform(low, high)), 2), "floor_m": boat.get("floor_m", -4.0),
                       "tied_to": index, "area": boat["area"]})
    return result


def _stakes(spec: dict, projection, rng: np.random.Generator, land, floor_at) -> list[dict]:
    """Rows of fishing stakes in the sea (plan 0005, Q6: off Hạ Long). Each row
    starts at a random point of the area and goes away from the nearest coast."""
    rows = []
    boundary = land.boundary
    for area_spec in spec["areas"]:
        area = _area(area_spec["polygon"], projection)
        floor = float(spec["max_floor_m"])

        def ok(a: float, b: float) -> bool:
            point = shapely.Point(a, b)
            return (not land.contains(point) and floor_at(a, b) <= floor
                    and boundary.distance(point) >= float(spec["min_from_coast_m"]))

        for px, py in _points_in(area, int(area_spec["rows"]), float(spec["min_row_spacing_m"]), rng, ok):
            near = ops.nearest_points(boundary, shapely.Point(px, py))[0]
            away = np.array([px - near.x, py - near.y])
            away /= max(float(np.linalg.norm(away)), 1e-6)
            # A row is a little turned from the line to the coast.
            turn = math.radians(float(rng.uniform(-20, 20)))
            direction = np.array([away[0] * math.cos(turn) - away[1] * math.sin(turn),
                                  away[0] * math.sin(turn) + away[1] * math.cos(turn)])
            length = float(rng.uniform(*spec["row_length_m"]))
            count = int(length / float(spec["spacing_m"])) + 1
            points = []
            for i in range(count):
                x, y = np.array([px, py]) + direction * i * float(spec["spacing_m"])
                if land.contains(shapely.Point(x, y)):
                    break
                game = map_to_game([(x, y)])[0]
                points.append([game[0], game[1], round(float(floor_at(x, y)), 2)])
            if len(points) >= 2:
                rows.append({"area": area_spec["name"], "stakes": points})
    return rows


def make(spec: dict, ways: list, projection, land, floor_at, beaches=None) -> tuple[dict, list[str]]:
    """The sea objects of sea_objects.json. floor_at(x, y) is the ground height
    at a map point, and beaches is a list of (name, map polygon). Returns the
    record for the build folder and the problems."""
    problems: list[str] = []
    rng = np.random.default_rng(int(spec.get("seed", 1)))

    def accept(x: float, y: float, floor: float) -> bool:
        return not land.contains(shapely.Point(x, y)) and floor_at(x, y) <= floor

    ships = _boats(spec["cargo_ships"], projection, rng, accept, spec["cargo_ships"]["kinds"])
    boats = _boats(spec["fishing_boats"], projection, rng, accept, ["ghe"], beaches, floor_at)
    baskets = _basket_boats(spec["basket_boats"], boats, projection, rng, accept, floor_at) \
        if "basket_boats" in spec else []
    stakes = _stakes(spec["fishing_stakes"], projection, rng, land, floor_at) if "fishing_stakes" in spec else []
    for name, found, wanted in (("cargo ships", ships, spec["cargo_ships"]["count"]),
                                ("fishing boats", boats, spec["fishing_boats"]["count"])):
        if len(found) < int(wanted):
            problems.append(f"only {len(found)} of {wanted} {name} have a place in their areas")
    by_id = {w.id: w for w in ways}
    pier_spec = spec["ferry_pier"]
    piers = []
    for way_id in pier_spec["osm_ways"]:
        way = by_id.get(int(way_id))
        if way is None:
            problems.append(f"the pier way {way_id} is not in the OSM data")
            continue
        lon, lat = zip(*way.coords)
        x, y = projection.to_map(np.array(lon), np.array(lat))
        piers.append({"osm": f"way/{way_id}", "points": map_to_game(zip(x, y))})
    groyne_spec = spec["groynes"]
    wanted_tags = {tuple(t) for t in groyne_spec["tags"]}
    groynes = []
    for way in ways:
        if any(way.tags.get(k) == v for k, v in wanted_tags):
            lon, lat = zip(*way.coords)
            x, y = projection.to_map(np.array(lon), np.array(lat))
            groynes.append({"osm": f"way/{way.id}", "name": way.tags.get("name", ""),
                            "kind": way.tags.get("man_made", ""), "points": map_to_game(zip(x, y))})
    record = {"note": "Made by tools/geo/build.py from data/geo/sea_objects.json and OSM. Do not change by hand.",
              "cargo_ships": ships, "fishing_boats": boats, "basket_boats": baskets,
              "fishing_stakes": {"height_m": spec.get("fishing_stakes", {}).get("height_m", 2.5), "rows": stakes},
              "ferry_pier": {"name": pier_spec["name"], "width_m": pier_spec["width_m"], "deck_m": pier_spec["deck_m"],
                             "parts": piers},
              "groynes": {"width_m": groyne_spec["width_m"], "height_m": groyne_spec["height_m"], "lines": groynes}}
    return record, problems
