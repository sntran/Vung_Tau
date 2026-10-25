"""The objects on the sea (plan 0005, R13a): ships at anchor, fishing boats,
the ferry pier, and the groynes."""

import math

import numpy as np
import shapely
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


def _boats(spec: dict, projection, rng: np.random.Generator, accept, kinds: list[str]) -> list[dict]:
    result = []
    floor = float(spec["min_floor_m"])
    total = int(spec["count"])
    for index, area_spec in enumerate(spec["areas"]):
        lon, lat = zip(*area_spec["polygon"])
        x, y = projection.to_map(np.array(lon), np.array(lat))
        area = Polygon(np.column_stack([x, y]))
        share = float(area_spec.get("share", 1.0))
        count = total - len(result) if index == len(spec["areas"]) - 1 else int(round(total * share))
        for px, py in _points_in(area, count, float(spec["min_spacing_m"]), rng, lambda a, b: accept(a, b, floor)):
            heading = float(spec.get("heading_deg", rng.uniform(0, 360))) + rng.uniform(-1, 1) * float(
                spec.get("heading_spread_deg", 180))
            low, high = spec["length_m"]
            result.append({"position": map_to_game([(px, py)])[0], "heading_deg": round(heading % 360, 1),
                           "length_m": round(float(rng.uniform(low, high)), 1), "kind": kinds[int(rng.integers(len(kinds)))],
                           "seed": int(rng.integers(1 << 30)), "area": area_spec["name"]})
    return result


def make(spec: dict, ways: list, projection, land, floor_at) -> tuple[dict, list[str]]:
    """The sea objects of sea_objects.json. floor_at(x, y) is the ground height
    at a map point. Returns the record for the build folder and the problems."""
    problems: list[str] = []
    rng = np.random.default_rng(int(spec.get("seed", 1)))

    def accept(x: float, y: float, floor: float) -> bool:
        return not land.contains(shapely.Point(x, y)) and floor_at(x, y) <= floor

    ships = _boats(spec["cargo_ships"], projection, rng, accept, spec["cargo_ships"]["kinds"])
    boats = _boats(spec["fishing_boats"], projection, rng, accept, ["ghe"])
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
              "cargo_ships": ships, "fishing_boats": boats,
              "ferry_pier": {"name": pier_spec["name"], "width_m": pier_spec["width_m"], "deck_m": pier_spec["deck_m"],
                             "parts": piers},
              "groynes": {"width_m": groyne_spec["width_m"], "height_m": groyne_spec["height_m"], "lines": groynes}}
    return record, problems
