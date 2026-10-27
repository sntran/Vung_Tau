#!/usr/bin/env python3
"""Builds data/geo/build/ from data/geo/raw/ (plan 0005, R4 to R8c).

Usage:
  python tools/geo/build.py                Build from data/geo/raw/ to data/geo/build/.
  python tools/geo/build.py --raw DIR --out DIR --geo DIR
                                           Use other folders (the tests do this).

The workspace can run this script: it needs no download.
"""

import argparse
import datetime
import shutil
import sys
import time
from pathlib import Path

import numpy as np
import shapely
import shapely.ops
from shapely.geometry import Polygon

sys.path.insert(0, str(Path(__file__).resolve().parent))

from geodata import blocks as blocks_module  # noqa: E402
from geodata import anchors as anchors_module  # noqa: E402
from geodata import clearings, coast, homestay, landcover, landmarks, mapdraw, osm, roads as roads_module, terrain  # noqa: E402
from geodata import roadworks as roadworks_module, sea as sea_module, seafloor, trees as trees_module  # noqa: E402
from geodata.config import BUILD, GEO, RAW, ROOT, Config, load_json, write_json  # noqa: E402
from geodata.projection import Projection, map_to_game  # noqa: E402

ROAD_POINT_STEP_M = 4.0
WOOD_TAGS = {("natural", "wood"), ("landuse", "forest"), ("natural", "scrub")}
SEA_ROCK_TAGS = {"rock", "reef", "bare_rock"}
# Bare rock on the land that does not rise in the sea (report 0005, D-0005-03):
# scree areas, and cliff lines with CLIFF_ROCK_M on each side.
LAND_ROCK_TAGS = {"scree"}
CLIFF_ROCK_M = 6.0
# tide.py writes these files before build.py runs. build.py keeps them.
TIDE_FILES = ("tide.json", "tide_report.md")
BUILT_LANDUSE = {"residential", "commercial", "retail", "industrial", "construction", "military", "religious"}
# A place where the roads cover more than this part of the ground (in a
# Gaussian of TOWN_ROAD_SIGMA_M) is town.
TOWN_ROAD_COVER = 0.12
TOWN_ROAD_SIGMA_M = 40.0
# A land polygon smaller than this is a small island (for example Hòn Bà).
ISLAND_MAX_M2 = 1_000_000.0
# The DEM shows an island a little larger than the OSM coastline.
ISLAND_MARGIN_M = 20.0
# The value of the low rocks with pebbles and shells in rock.png (the other bare rock is 255).
ROCK_PEBBLES = 140
KEEP_IMPORT = '[remap]\n\nimporter="keep"\n'


def log(text: str) -> None:
    print(f"[build] {text}", flush=True)


def write_keep_import(path: Path) -> None:
    """Godot must export the file as it is: Godot changes 16-bit PNG files to 8 bits when it imports them."""
    Path(str(path) + ".import").write_text(KEEP_IMPORT, encoding="utf-8")


def to_map_geometry(geometry, projection):
    return shapely.transform(geometry, lambda c: np.column_stack(projection.to_map(c[:, 0], c[:, 1])))


def find_osm_file(raw: Path) -> Path:
    for name in ("osm.pbf", "osm.osm.pbf", "osm.osm", "osm.xml"):
        if (raw / name).exists():
            return raw / name
    raise SystemExit(f"no OSM file in {raw}. Run tools/geo/fetch.py in CI first.")


def polygons_of(geometry) -> list[Polygon]:
    return [g for g in getattr(geometry, "geoms", [geometry]) if isinstance(g, Polygon) and not g.is_empty]


def build(raw: Path, out: Path, geo: Path) -> int:
    started = time.time()
    config = Config(geo)
    area = config.area
    problems: list[str] = []
    data = osm.read(find_osm_file(raw), config.overrides)
    problems += data.problems
    if (raw / "fetch_problems.json").exists():
        problems += load_json(raw / "fetch_problems.json")["problems"]
    log(f"read {len(data.nodes)} tagged nodes, {len(data.ways)} ways, {len(data.areas)} areas")

    # The origin: the center of Bãi Trước, rounded to 10 m (D4).
    origin_def = next(l for l in config.landmarks if l["id"] == area["origin_landmark"])
    origin = landmarks.choose(origin_def, landmarks.candidates(origin_def, data))
    if origin is None:
        problems.append(f"{origin_def['name_vi']} is not in the data, so the origin is the hint position")
        lon, lat = origin_def["hint"]["lon"], origin_def["hint"]["lat"]
        beach_outline_lonlat = None
    else:
        lon, lat = origin["lonlat"]
        beach_outline_lonlat = origin["geometry"]
    projection = Projection.at(lon, lat, area["origin_round_m"], area["epsg"])
    log(f"origin at {projection.origin_lonlat()} (UTM {projection.origin_e}, {projection.origin_n})")

    box = coast.box_polygon(config.bbox, projection)
    land = coast.land_polygon(coast.coastline_lines(data.ways, projection), box, problems)
    beaches, beach_records, buildings, landuse, woods, water, rocks, parks = [], [], [], [], [], [], [], []
    land_rocks = []
    for a in data.areas:
        shape = to_map_geometry(a.geometry, projection).intersection(box)
        if shape.is_empty:
            continue
        if a.tags.get("natural") == "beach":
            beaches.append(shape)
            beach_records.append({"osm": f"{a.kind}/{a.id}", "name": a.tags.get("name", ""), "polygons": polygons_of(shape)})
        if "building" in a.tags:
            buildings.extend(polygons_of(shape))
        if a.tags.get("landuse") in BUILT_LANDUSE:
            landuse.append((a.tags["landuse"], shape))
        if any(a.tags.get(k) == v for k, v in WOOD_TAGS):
            woods.append(shape)
        if a.tags.get("natural") == "water" or "water" in a.tags:
            water.append(shape)
        if a.tags.get("natural") in SEA_ROCK_TAGS:
            rocks.append(shape)
        if a.tags.get("natural") in LAND_ROCK_TAGS:
            land_rocks.append(shape)
        if a.tags.get("leisure") == "park":
            parks.extend(polygons_of(shape))
    for n in data.nodes:
        if n.tags.get("natural") in SEA_ROCK_TAGS:
            x, y = projection.to_map(np.array([n.lon]), np.array([n.lat]))
            rocks.append(shapely.Point(float(x[0]), float(y[0])).buffer(terrain.SEA_ROCK_NODE_RADIUS_M))
    cliffs = 0
    for w in data.ways:
        if w.tags.get("natural") == "cliff" and not w.closed:
            line = to_map_geometry(shapely.LineString(w.coords), projection).intersection(box)
            if not line.is_empty:
                land_rocks.append(line.buffer(CLIFF_ROCK_M))
                cliffs += 1
    rock_coasts = []
    rock_coast_shapes = []
    for spec in data.rock_coasts:
        x, y = projection.to_map(np.array([float(spec["lon"])]), np.array([float(spec["lat"])]))
        shape = coast.rock_coast_area(land, (float(x[0]), float(y[0])), float(spec["radius_m"]), float(spec["sea_m"]))
        if shape.is_empty:
            problems.append(f"the rock coast {spec.get('name', '')} finds no land within {spec['radius_m']} m")
            continue
        land_rocks.append(shape)
        rock_coast_shapes.append(shape)
        rock_coasts.append({"name": spec.get("name", ""), "area_m2": round(shape.area)})
    shelves = []
    for spec in data.rock_shelves:
        ends = [projection.to_map(np.array([float(p[0])]), np.array([float(p[1])])) for p in (spec["from"], spec["to"])]
        band = coast.coast_band(land, (float(ends[0][0][0]), float(ends[0][1][0])),
                                (float(ends[1][0][0]), float(ends[1][1][0])), float(spec["width_m"]))
        if band.is_empty:
            problems.append(f"the rock shelf {spec.get('name', '')} has no sea")
            continue
        shelves.append((spec, band))
    log(f"land {land.area / 1e6:.2f} km2, {len(beaches)} beaches, {len(buildings)} buildings")
    log(f"{cliffs} cliffs, {len(land_rocks) - cliffs - len(rock_coasts)} scree areas, {len(rock_coasts)} rock coasts")

    ridge_way = find_ridge(config, data, problems)
    roads = roads_module.make_roads([w for w in data.ways if w is not ridge_way], projection, config.road_widths)
    for road in roads:
        road.points = roads_module.densify(road.points, ROAD_POINT_STEP_M)
    network = roads_module.Network(roads)
    log(f"{len(roads)} roads")

    # The ground.
    grid = terrain.make_grid(box.bounds, area["chunk_size_m"], area["grid_m"])
    log(f"grid {grid.shape[1]} x {grid.shape[0]} samples")
    terrain.load_dem(grid, raw / "dem.tif", projection)
    dem_max = float(grid.heights.max())
    building_mask = terrain.rasterize(grid, buildings)
    town_mask = building_mask | terrain.rasterize(grid, [p for _k, s in landuse for p in polygons_of(s)])
    # Small islands keep the heights of the DEM: the filter would make them flat.
    islands = [p for p in polygons_of(land) if p.area < ISLAND_MAX_M2]
    island_mask = terrain.rasterize(grid, [p.buffer(ISLAND_MARGIN_M) for p in islands])
    town_change = terrain.remove_buildings(grid, town_mask, island_mask)
    land_mask = terrain.rasterize(grid, polygons_of(land))
    beach_mask = terrain.rasterize(grid, [p for b in beaches for p in polygons_of(b)]) & land_mask
    terrain.shape_coast(grid, land_mask, beach_mask)
    terrain.roughen_islands(grid, island_mask & land_mask)
    ridge = None
    rock_band = None
    if ridge_way is not None:
        lon, lat = zip(*ridge_way.coords)
        x, y = projection.to_map(np.array(lon), np.array(lat))
        line = shapely.LineString(np.column_stack([x, y]))
        top, width = float(config.hon_ba["ridge_top_m"]), float(config.hon_ba["ridge_width_m"])
        ridge = {"name": config.hon_ba["ridge_name"], "osm": f"way/{ridge_way.id}", "top_m": top, "width_m": width,
                 "length_m": round(line.length, 1), "points": map_to_game(line.coords)}
        band_way = find_band(config, data)
        if band_way is None:
            ridge["sea_cells"] = terrain.make_ridge(grid, land_mask, line, top, width)
        else:
            band = to_map_geometry(Polygon(band_way.coords), projection)
            h = config.hon_ba
            beach_end = shore_end(line, h["islet"], projection)
            flat_cells = terrain.make_sand_flat(grid, land_mask, beach_end, float(h["sand_flat_radius_m"]),
                                                float(h["sand_flat_m"]))
            stats = terrain.make_rock_band(grid, land_mask, line, band, top, width, float(h["path_rough_m"]),
                                           float(h["outcrop_m"]), float(h["pool_m"]))
            sea_band = band.difference(land)
            ridge |= {"sea_cells": stats["path_cells"], "band": {
                "name": h["band_name"], "width_m": round(band.area / max(line.length, 1.0), 1),
                "polygons": [blocks_module.polygon_to_game(p) for p in polygons_of(band)],
                "sea_cells": stats["band_cells"], "min_m": stats["min_m"], "max_m": stats["max_m"]},
                "sand_flat": {"center": map_to_game([beach_end])[0], "radius_m": float(h["sand_flat_radius_m"]),
                              "height_m": float(h["sand_flat_m"]), "cells": flat_cells}}
            rock_band = sea_band
            log(f"Hòn Bà rock band {sea_band.area:.0f} m2 from {stats['min_m']:+.2f} to {stats['max_m']:+.2f} m")
        log(f"Hòn Bà ridge {line.length:.0f} m at {top:+.2f} m")
    # The sea floor from public data (R8g): the intertidal zone and GEBCO (tools/geo/intertidal.py).
    intertidal = terrain.load_raster(grid, raw / "intertidal.tif", projection) if (raw / "intertidal.tif").exists() else None
    gebco = terrain.load_raster(grid, raw / "gebco.tif", projection, terrain.Resampling.cubic) \
        if (raw / "gebco.tif").exists() else None
    # The rock band of Hòn Bà keeps its own heights (Q14).
    keep = terrain.rasterize(grid, polygons_of(rock_band)) if rock_band is not None else None
    floor_stats, floor_data = terrain.sea_floor_from_data(grid, land_mask, intertidal, gebco, keep)
    if rock_band is not None:
        h = config.hon_ba
        beside = terrain.water_beside_path(grid, land_mask, line, band, top - float(h["beside_below_top_m"]),
                                           float(h["beside_m"]), float(h["beside_from_land_m"]))
        floor_data &= ~beside
        log(f"water beside the Hòn Bà path: {int(beside.sum())} cells at {top - float(h['beside_below_top_m']):+.2f} m or lower")
    del intertidal, gebco
    log(f"sea floor: {floor_stats['intertidal_cells']} intertidal cells, GEBCO {floor_stats['gebco']}")
    # The boulders of the rocky coasts (D-0005-03): the cape is not smooth sand.
    for shape in rock_coast_shapes:
        terrain.roughen_rocks(grid, terrain.rasterize(grid, polygons_of(shape)))
    rock_cells = terrain.raise_sea_rocks(grid, land_mask, terrain.rasterize(grid, [p for r in rocks for p in polygons_of(r)]))
    rock_shelves = []
    pebble_shapes = []
    for spec, band in shelves:
        cells = terrain.make_rock_shelf(grid, land_mask, terrain.rasterize(grid, polygons_of(band)), float(spec["height_m"]),
                                        float(spec["rough_m"]))
        land_rocks.append(band)
        pebble_shapes.append(band)
        point = band.representative_point()
        rock_shelves.append({"name": spec.get("name", ""), "height_m": float(spec["height_m"]),
                             "area_m2": round(band.area), "cells": cells, "point": map_to_game([(point.x, point.y)])[0]})
        log(f"rock shelf {spec.get('name', '')}: {band.area:.0f} m2 at {float(spec['height_m']):+.2f} m")
    log(f"{len(rocks)} rocks, {rock_cells} sea rock cells")
    terrain.flatten_roads(grid, roads, ROAD_POINT_STEP_M)
    for road in roads:
        road.heights = grid.sample(road.points[:, 0], -road.points[:, 1]).tolist()
    log("ground done")

    found = landmarks.find_all(config, data, projection, grid)
    anchor_list = anchors_module.find(data, projection, roads)
    log(f"{len(anchor_list)} town anchor candidates")
    found_by_id = {r["id"]: r for r in found}
    block_list = blocks_module.make_blocks(roads, land, buildings, landuse)
    log(f"{len(block_list)} blocks")

    beach_outline = None
    if beach_outline_lonlat is not None:
        beach_outline = to_map_geometry(beach_outline_lonlat, projection)
    home = homestay.find(roads, network, found_by_id, beach_outline, block_list)

    def floor_at(x, y):
        return float(grid.sample(np.array([x]), np.array([-y]))[0])

    works = []
    for spec in data.roadworks:
        record, found_problems = roadworks_module.make(spec, roads, home.get("hem"))
        problems += found_problems
        if record is not None:
            works.append(record)
            log(f"roadworks on {record['road']}: {record['length_m']} m")
    sea_objects = None
    if config.sea_objects is not None:
        named_beaches = [(b["name"], shape) for b, shape in zip(beach_records, beaches)]
        sea_objects, found_problems = sea_module.make(config.sea_objects, data.ways, projection, land, floor_at,
                                                      named_beaches)
        problems += found_problems
        log(f"{len(sea_objects['cargo_ships'])} cargo ships, {len(sea_objects['fishing_boats'])} fishing boats, "
            f"{len(sea_objects['basket_boats'])} basket boats, {len(sea_objects['fishing_stakes']['rows'])} rows of "
            f"stakes, {len(sea_objects['groynes']['lines'])} groynes")
    # The places with no trees and no bushes, and the roads with no tree trunks (report 0020, D-0020-01).
    places = clearings.place_shapes(data.areas, lambda g: to_map_geometry(g, projection), found_by_id, config.clearings)
    place_mask = terrain.rasterize(grid, [p for shape in places for p in polygons_of(shape)])
    road_mask = terrain.rasterize(grid, clearings.road_shapes(roads, config.clearings))
    canopy = None
    tops = None
    if (raw / "canopy.tif").exists():
        canopy = terrain.load_raster(grid, raw / "canopy.tif", projection, terrain.Resampling.max)
        # The tree tops of all the land, also of the town, for the street trees (report 0020, D-0020-03).
        rows, cols = landcover.tree_places(canopy, grid.step, land_mask & ~place_mask & ~road_mask)
        tops = np.column_stack([grid.x0 + cols * grid.step, -(grid.z0 + rows * grid.step)]).astype(float)
        log(f"{len(tops)} tree tops of the canopy map on the land")
    tree_record, tree_counts, tree_groups = None, {}, {}
    if config.trees is not None:
        osm_trees, osm_rows = [], []
        for n in data.nodes:
            if n.tags.get("natural") == "tree":
                x, y = projection.to_map(np.array([n.lon]), np.array([n.lat]))
                osm_trees.append((float(x[0]), float(y[0]), n.tags))
        for w in data.ways:
            if w.tags.get("natural") == "tree_row":
                lon, lat = zip(*w.coords)
                x, y = projection.to_map(np.array(lon), np.array(lat))
                osm_rows.append((shapely.LineString(np.column_stack([x, y])), w.tags))
        near = found_by_id.get(config.trees["parks"]["near_landmark"])
        near_point = shapely.Point(near["position"][0], -near["position"][1]) if near and near.get("found") else None
        tree_record, tree_counts, tree_groups = trees_module.make(
            config.trees, roads, land, beaches, parks, osm_trees, osm_rows, home.get("coast_road", ""), beach_outline,
            near_point, lambda x, y: grid.sample(np.asarray(x), -np.asarray(y)), tops)
        log(f"{sum(len(v) for v in tree_record['types'].values())} trees: {tree_counts}")

    # Write the files. Keep the files of tide.py.
    kept = {name: (out / name).read_bytes() for name in TIDE_FILES if (out / name).exists()}
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    for name, content in kept.items():
        (out / name).write_bytes(content)
    (out / "height").mkdir(parents=True)
    chunks = terrain.write_chunks(grid, land_mask, area["chunk_size_m"], area["sea_chunk_margin_m"],
                                  area["height_offset_m"], area["height_step_m"], out / "height")
    overview = terrain.write_overview(grid, int(area["overview_grid_m"] / area["grid_m"]), area["height_offset_m"],
                                      area["height_step_m"], out / "height" / "overview.png")
    for png in (out / "height").glob("*.png"):
        write_keep_import(png)
    rock_mask = terrain.rasterize(grid, [p for r in rocks + land_rocks + [rock_band] + islands if r is not None
                                         for p in polygons_of(r)])
    pebble_mask = terrain.rasterize(grid, [p for r in pebble_shapes + [rock_band] if r is not None
                                           for p in polygons_of(r)])
    surface = write_surface(grid, land_mask, beach_mask, building_mask, block_list, woods, landuse, roads, area,
                            out / "surface.png", rock_mask, out / "rock.png", pebble_mask)
    write_keep_import(out / "surface.png")
    write_keep_import(out / "rock.png")
    cover_record = write_cover(grid, raw, out, projection, land_mask, area, found_by_id, place_mask, road_mask, canopy)

    lon_min, lat_min = projection.map_to_lonlat(box.bounds[0], box.bounds[1])
    lon_max, lat_max = projection.map_to_lonlat(box.bounds[2], box.bounds[3])
    origin_lon, origin_lat = projection.origin_lonlat()
    world = {
        "note": "Made by tools/geo/build.py. Do not change by hand.",
        "epsg": projection.epsg,
        "origin": {"lon": round(origin_lon, 8), "lat": round(origin_lat, 8), "utm_e": projection.origin_e,
                   "utm_n": projection.origin_n},
        "bbox": area["bbox"],
        "data_extents": {"lon": list(data.lon_range), "lat": list(data.lat_range)},
        "map_extents_m": {"x": [round(box.bounds[0], 1), round(box.bounds[2], 1)],
                          "z": [round(-box.bounds[3], 1), round(-box.bounds[1], 1)]},
        "chunk_size": area["chunk_size_m"],
        "grid": area["grid_m"],
        "height": {"offset": area["height_offset_m"], "step": area["height_step_m"]},
        "chunks": chunks,
        "overview": overview,
        "surface": surface,
        "cover": (cover_record or {}).get("world", {}),
        "sea_floor": {"coast_m": terrain.LAND_MIN_HEIGHT, "depth_m": -terrain.SEA_FLOOR_DEPTH,
                      "slope_m": terrain.SEA_FLOOR_SLOPE_M, "rock_m": terrain.SEA_ROCK_HEIGHT},
    }
    if ridge is not None:
        world["hon_ba_ridge"] = ridge
    # The small islands, for the trees on their tops (report 0005, D-0005-05).
    world["islands"] = [dict(area_m2=round(p.area), **blocks_module.polygon_to_game(p.simplify(1.0))) for p in islands]
    world["rock_coasts"] = rock_coasts
    world["rock_shelves"] = rock_shelves
    # The sea floor report (R8g): the dry land at the lowest tide, and the line out from the main beach.
    tide_path = out / "tide.json"
    if tide_path.exists():
        tide = load_json(tide_path)
        day_one = datetime.date.fromisoformat(load_json(ROOT / "data" / "calendar.json")["day_one"])
        lowest, highest = seafloor.tide_range(tide, day_one)
        # From the center of Bãi Trước (the game origin) to the nearest point of the coastline.
        water = shapely.ops.nearest_points(land.boundary, shapely.Point(0.0, 0.0))[0]
        line = seafloor.profile(grid, land_mask, floor_data, (0.0, 0.0), (water.x, water.y))
        dry = seafloor.draw_dry_map(out / "intertidal_dry.png", grid, land_mask, floor_data, lowest)
        images = {}
        if (raw / "intertidal.json").exists():
            info = load_json(raw / "intertidal.json")["sentinel"]
            images = dict(info.get("low_tide_images", {}), count=len(info.get("images", [])))
        write_keep_import(out / "intertidal_dry.png")
        (out / "intertidal_report.md").write_text(
            seafloor.report(floor_stats, lowest, highest, line, dry, images, "intertidal_dry.png"), encoding="utf-8")
        world["sea_floor"] |= {"source": "intertidal and GEBCO" if floor_stats["intertidal_cells"] else "slope",
                               "game_tide_m": [round(lowest, 2), round(highest, 2)], "bai_truoc_profile": line,
                               "check_distances_m": list(seafloor.CHECK_DISTANCES_M),
                               "dry_at_lowest_m2": {k: round(v) for k, v in dry.items()}}
    write_json(out / "world.json", world)
    write_json(out / "coastline.json", {"lines": [map_to_game(l.coords) for l in coast.coastline_lines(data.ways, projection)]}, None)
    write_json(out / "land.json", {"polygons": [blocks_module.polygon_to_game(p.simplify(1.0)) for p in polygons_of(land)]}, None)
    write_json(out / "beaches.json", {"beaches": [
        {"osm": b["osm"], "name": b["name"], "polygons": [blocks_module.polygon_to_game(p) for p in b["polygons"]]}
        for b in beach_records]}, None)
    write_json(out / "roads.json", {"roads": [road_record(r) for r in roads]}, None)
    write_json(out / "blocks.json", {"blocks": [
        dict(id=i, buildings=b["buildings"], has_buildings=b["buildings"] > 0, landuse=b["landuse"],
             area_m2=round(b["polygon"].area, 1), **blocks_module.polygon_to_game(b["polygon"]))
        for i, b in enumerate(block_list)]}, None)
    write_json(out / "buildings.json", {"buildings": [blocks_module.polygon_to_game(b.simplify(0.2)) for b in buildings]}, None)
    write_json(out / "landmarks.json", {"landmarks": found})
    write_json(out / "homestay.json", homestay_record(home))
    write_json(out / "roadworks.json", {"note": "Made by tools/geo/build.py from overrides.json (R11a). Do not change by hand.",
                                        "roadworks": works})
    if sea_objects is not None:
        write_json(out / "sea_objects.json", sea_objects)
    if tree_record is not None:
        write_json(out / "trees.json", tree_record, None)
        if cover_record is not None:
            # Report 0020, D-0020-03: the share of the street and park trees of each group that the canopy map shows.
            canopy_values = cover_record.pop("canopy_values")
            cover_record["street"] = {
                group: {"count": len(points), "snapped": tree_counts.get(group + "_snapped", 0),
                        "missing": len(landcover.street_trees_without_canopy(
                            [[x, 0.0, -y] for x, y in points], grid, canopy_values))}
                for group, points in sorted(tree_groups.items())}
    center = mapdraw.center_of(home)
    if center is not None:
        mapdraw.draw(out / "homestay_area.png", center, roads, land, beaches, block_list, buildings, home)
        write_keep_import(out / "homestay_area.png")
    anchors_module.draw(out / "anchors.png", anchor_list, roads, land)
    write_keep_import(out / "anchors.png")
    write_json(out / "anchors.json", {"anchors": [{k: v for k, v in a.items() if k != "map"} for a in anchor_list]})
    if cover_record is not None:
        cover_record.pop("canopy_values", None)
    write_report(out / "report.md", world, data, roads, block_list, buildings, found, home, problems,
                 town_change, dem_max, raw, rock_cells, out, anchor_list, works, sea_objects, tree_record, tree_counts,
                 cover_record)
    log(f"done in {time.time() - started:.0f} s")
    return 0


def find_ridge(config: Config, data, problems: list[str]):
    """The way of the Hòn Bà ridge (R8h): the OSM way in hon_ba.json, or a way of overrides.json with that name."""
    if config.hon_ba is None:
        return None
    for way in data.ways:
        if way.id == config.hon_ba["ridge_way"] or (way.source != "osm" and way.tags.get("name") == config.hon_ba["ridge_name"]):
            return way
    problems.append(f"the Hòn Bà ridge (way {config.hon_ba['ridge_way']}) is not in the data. Put it in overrides.json.")
    return None


def find_band(config: Config, data):
    """The band of rocks around the Hòn Bà path (R8h): an area of overrides.json with the band name."""
    name = config.hon_ba.get("band_name")
    for way in data.ways:
        if name and way.closed and way.tags.get("name") == name:
            return way
    return None


def shore_end(line, islet: dict, projection) -> tuple[float, float]:
    """The end of the path line that is farther from the islet: the beach end."""
    x, y = projection.to_map(np.array([islet["lon"]]), np.array([islet["lat"]]))
    point = shapely.Point(float(x[0]), float(y[0]))
    first, last = shapely.Point(line.coords[0]), shapely.Point(line.coords[-1])
    end = first if first.distance(point) > last.distance(point) else last
    return (end.x, end.y)


def road_record(road) -> dict:
    record = {"id": road.id, "type": road.type, "name": road.name, "width": road.width,
              "width_source": road.width_source, "surface": road.surface, "hem": road.hem,
              "sidewalk": road.sidewalk, "oneway": road.oneway, "lanes": road.lanes,
              "points": [[round(float(x), 2), round(float(h), 2), round(-float(y), 2)]
                         for (x, y), h in zip(road.points, road.heights)]}
    if road.bridge:
        record["bridge"] = True
    if road.tunnel:
        record["tunnel"] = True
    if road.source != "osm":
        record["source"] = road.source
    return record


def write_surface(grid, land_mask, beach_mask, building_mask, block_list, woods, landuse, roads, area, path,
                  rock_mask, rock_path, pebble_mask=None) -> dict:
    """An RGBA image for the ground materials: R is sand, G is town, B is wood,
    A is the distance to the coastline (positive on land). A second gray
    image (rock_path) is bare rock: the Hòn Bà rock path, the rocks in the
    sea, the rocky coasts, and the small islands (R8h). Its value is 255 for
    boulders, and ROCK_PEBBLES for the low rocks with pebbles and shells (the
    Hòn Bà band and the flat rocks along the sea wall, D-0005-03).

    OSM has few building outlines in Vũng Tàu, so a place with many roads is
    also town: there, the roads cover more than TOWN_ROAD_COVER of the ground."""
    from PIL import Image
    from scipy import ndimage
    every = int(area["land_mask_grid_m"] / grid.step)
    town_shapes = [b["polygon"] for b in block_list if b["buildings"] > 0] + [g for _k, g in landuse]
    town = terrain.rasterize(grid, [p for s in town_shapes for p in polygons_of(s)]) | building_mask
    road_cover = terrain.rasterize(grid, blocks_module.road_surfaces(
        [r for r in roads if r.type not in blocks_module.NOT_BLOCK_EDGES]))
    density = ndimage.gaussian_filter(road_cover.astype(np.float32), sigma=TOWN_ROAD_SIGMA_M / grid.step)
    town |= (density > TOWN_ROAD_COVER) & land_mask
    wood = terrain.rasterize(grid, [p for s in woods for p in polygons_of(s)])
    to_sea = ndimage.distance_transform_edt(land_mask).astype(np.float32) * grid.step
    to_land = ndimage.distance_transform_edt(~land_mask).astype(np.float32) * grid.step
    signed = np.where(land_mask, to_sea, -to_land)
    limit = area["land_mask_range_m"]

    def channel(mask):
        smooth = ndimage.gaussian_filter(mask.astype(np.float32), sigma=every / 2.0)
        return np.clip(np.round(smooth[::every, ::every] * 255), 0, 255).astype(np.uint8)

    alpha = np.clip(np.round((signed[::every, ::every] + limit) / (2 * limit) * 255), 0, 255).astype(np.uint8)
    # The sea floor is sand: the low tide shows it.
    image = np.dstack([channel((beach_mask | ~land_mask) & ~rock_mask), channel(town), channel(wood & ~rock_mask), alpha])
    Image.fromarray(image, "RGBA").save(path)
    pebbles = np.zeros(grid.shape, dtype=bool) if pebble_mask is None else pebble_mask
    rock = np.maximum(channel(rock_mask & ~pebbles), (channel(pebbles).astype(np.float32) * ROCK_PEBBLES / 255).astype(np.uint8))
    Image.fromarray(rock, "L").save(rock_path)
    return {"x0": grid.x0, "z0": grid.z0, "step": grid.step * every, "columns": image.shape[1], "rows": image.shape[0],
            "coast_range_m": limit, "rock": rock_path.name}


# The hills of the cover report: the landmark, the radius (m), and the lowest height (m).
COVER_HILLS = {"nui_lon": (1100.0, 20.0), "nui_nho": (700.0, 20.0)}


def write_cover(grid, raw, out, projection, land_mask, area, found_by_id, place_mask=None, road_mask=None,
                canopy=None) -> dict | None:
    """The land cover and the canopy heights (report 0005, D-0005-09; plan 0020,
    D8): cover.png (on the grid of surface.png: R tree cover, G bushes, B grass,
    A bare ground), canopy.png (the canopy height for the trees and the bushes
    of the game), and two maps for the report. None when landcover.py did not run."""
    if not ((raw / "worldcover.tif").exists() and (raw / "canopy.tif").exists()):
        return None
    classes = terrain.load_raster(grid, raw / "worldcover.tif", projection, terrain.Resampling.nearest)
    classes = np.nan_to_num(classes, nan=0.0).astype(np.uint8)
    if canopy is None:
        canopy = terrain.load_raster(grid, raw / "canopy.tif", projection, terrain.Resampling.max)
    masks = landcover.cover_masks(classes, canopy, land_mask)
    if place_mask is not None:
        # No trees and no bushes on the paved places: the ground there is the town ground.
        for name in masks:
            masks[name] &= ~place_mask
    every = int(area["land_mask_grid_m"] / grid.step)
    landcover.write_cover(masks, every, out / "cover.png")
    write_keep_import(out / "cover.png")
    canopy_place = landcover.write_canopy(grid, canopy, land_mask, out / "canopy.png")
    write_keep_import(out / "canopy.png")
    landcover.draw_cover_map(out / "cover_map.png", classes, every * 2)
    landcover.draw_canopy_map(out / "canopy_map.png", canopy, land_mask, every * 2)
    write_keep_import(out / "cover_map.png")
    write_keep_import(out / "canopy_map.png")
    allowed = masks["tree"] & ~road_mask if road_mask is not None else masks["tree"]
    rows, cols = landcover.tree_places(canopy, grid.step, allowed)
    tops = landcover.write_trees(out / "canopy_trees.json", grid, canopy, rows, cols)
    hills = {}
    for hill_id, (radius, lowest) in COVER_HILLS.items():
        record = found_by_id.get(hill_id)
        if not record or not record.get("found"):
            continue
        cx = (record["position"][0] - grid.x0) / grid.step
        cz = (record["position"][1] - grid.z0) / grid.step
        r = radius / grid.step
        r0, r1 = max(int(cz - r), 0), min(int(cz + r) + 1, grid.shape[0])
        c0, c1 = max(int(cx - r), 0), min(int(cx + r) + 1, grid.shape[1])
        yy, xx = np.mgrid[r0:r1, c0:c1]
        area_mask = np.zeros(grid.shape, dtype=bool)
        area_mask[r0:r1, c0:c1] = ((yy - cz) ** 2 + (xx - cx) ** 2 <= r * r) & (grid.heights[r0:r1, c0:c1] > lowest)
        area_mask &= land_mask
        inside = area_mask[rows, cols] if rows.size else np.zeros(0, dtype=bool)
        hills[hill_id] = landcover.shares(masks, classes, area_mask) | {
            "name": record.get("name_vi", hill_id), "area_m2": round(float(area_mask.sum()) * grid.step ** 2),
            "trees": int(inside.sum())}
    info = load_json(raw / "landcover.json") if (raw / "landcover.json").exists() else {}
    log(f"cover: {int(rows.size)} trees on the open land; " +
        ", ".join(f"{k} {v['tree'] * 100:.0f} % trees, {v['bush'] * 100:.0f} % bushes" for k, v in hills.items()))
    return {"world": {"file": "cover.png", "canopy": canopy_place, "trees": "canopy_trees.json"},
            "hills": hills, "trees": tops,
            "clear_m2": round(float(place_mask.sum()) * grid.step ** 2) if place_mask is not None else 0, "info": info, "canopy_values": canopy}


GROUP_NAMES = {"bai_truoc_road": "Quang Trung (Bãi Trước)", "coast_roads": "Thùy Vân, Hạ Long, Trần Phú",
               "named_roads": "Trần Hưng Đạo, Ba Cu", "street": "The other main roads",
               "park_bai_truoc": "The park of Bãi Trước", "parks": "The other parks", "osm": "The trees of OSM"}


def cover_report_lines(cover: dict) -> list[str]:
    info = cover.get("info", {})
    years = info.get("canopy", {}).get("image_years", {})
    lines = ["## Land cover and trees (report 0005, D-0005-09; plan 0020, D8)", "",
             f"- Sources: {info.get('worldcover', {}).get('name', 'ESA WorldCover 2021')} (10 m classes) and "
             f"{info.get('canopy', {}).get('name', 'the Meta and WRI canopy height maps')} (about 1 m, kept on a grid of "
             f"{info.get('canopy', {}).get('step_m', 2)} m with the highest value). Both CC BY 4.0.",
             f"- The canopy images over the play area are from {years.get('first', '?')} to {years.get('last', '?')} "
             f"(decimal years, mean {years.get('mean', '?')}).",
             f"- A canopy of {landcover.TREE_MIN_M:.0f} m or more is a tree, and a canopy of {landcover.BUSH_MIN_M} m to "
             f"{landcover.TREE_MIN_M:.0f} m in tree cover is a bush (WorldCover has almost no shrubland here). Grassland "
             f"and bare ground show the ground (R10a). The built-up and the cropland classes keep the rules of the town "
             f"and of `trees.json`.",
             f"- {cover['trees']['count']} trees on the open land, with a mean height of {cover['trees']['mean_height_m']} m "
             f"and a mean crown radius of {cover['trees']['mean_radius_m']} m (`canopy_trees.json`, R10a). A tree stands on "
             f"the highest canopy first, then on the lower canopy, at a spacing of {landcover.SPACING_PER_M} of its height "
             f"({landcover.SPACING_MIN_M:.0f} m to {landcover.SPACING_MAX_M:.0f} m): the map has one height top for each "
             f"group of crowns. The crown of a tree is the canopy that is nearer to it than to another tree.",
             f"- No trees and no bushes on {cover.get('clear_m2', 0) / 1e4:.1f} ha of paved places and platforms (the OSM "
             f"areas and the landmarks of `data/geo/clearings.json`), and no tree trunks on the roads and the paths "
             f"(report 0020, D-0020-01).",
             "", "| Hill | Area (km²) | Tree cover | Bushes | Grass | Bare | Trees | WorldCover classes |", "|---|---|---|---|---|---|---|---|"]
    for hill in cover.get("hills", {}).values():
        classes = ", ".join(f"{k} {v * 100:.0f} %" for k, v in sorted(hill["classes"].items(), key=lambda kv: -kv[1]))
        lines.append(f"| {hill['name']} | {hill['area_m2'] / 1e6:.2f} | {hill['tree'] * 100:.0f} % | {hill['bush'] * 100:.0f} % | "
                     f"{hill['grass'] * 100:.0f} % | {hill['bare'] * 100:.0f} % | {hill['trees']} | {classes} |")
    lines += ["", "The hills: the land within 1.1 km of the top of Núi Lớn and 0.7 km of the top of Núi Nhỏ, higher than 20 m.",
              "", "![The WorldCover classes](cover_map.png)", "",
              "Dark green: tree cover. Yellow: grassland. Red: built-up. Gray: bare. Blue: water. Light green: mangroves.",
              "", "![The canopy height](canopy_map.png)", "",
              "Light green (1 m) to dark green (25 m or more): the canopy height. Gray: land with no canopy. Blue: the sea."]
    street = cover.get("street")
    if street:
        lines += ["", "The street and park trees and the canopy map (report 0020, D-0020-03): on the roads of my photos "
                  "and in the park of Bãi Trước the rows stay, and a tree moves to the nearest tree top of the canopy "
                  "map within 6 m; on the other roads and in the other parks, a tree stands only on a tree top of the map. "
                  f"\"Not in the map\": no canopy of {landcover.STREET_MIN_M:.0f} m or more within "
                  f"{landcover.STREET_RADIUS_M:.0f} m.", "",
                  "| Group | Trees | Moved to a tree top | Not in the map |", "|---|---|---|---|"]
        for group, values in street.items():
            n = max(values["count"], 1)
            lines.append(f"| {GROUP_NAMES.get(group, group)} | {values['count']} | {values['snapped'] * 100 / n:.0f} % | "
                         f"{values['missing'] * 100 / n:.0f} % |")
    return lines


def homestay_record(home: dict) -> dict:
    record = {"found": home["found"], "problems": home["problems"], "coast_road": home.get("coast_road", "")}
    if "lighthouse_road" in home:
        record["lighthouse_road"] = {"length_m": home["lighthouse_road"]["length_m"],
                                     "points": map_to_game(home["lighthouse_road"]["points"])}
    if "curve" in home:
        c = home["curve"]
        record["curve"] = {"start": map_to_game([c["start"]])[0], "end": map_to_game([c["end"]])[0],
                           "start_distance_m": round(c["start_distance_m"], 1),
                           "end_distance_m": round(c["end_distance_m"], 1), "turn_deg": round(c["turn_deg"], 1)}
    record["candidates"] = [{"number": i + 1, "osm": f"way/{c['road'].id}", "name": c["road"].name,
                             "type": c["road"].type, "width": c["road"].width, "angle_diff_deg": c["angle_diff_deg"],
                             "junction": map_to_game([c["junction"]])[0]} for i, c in enumerate(home["candidates"])]
    if home["found"]:
        hem = home["hem"]
        record["homestay_hem"] = {"osm": f"way/{hem.id}", "name": hem.name, "type": hem.type, "width": hem.width,
                                  "length_m": round(hem.length, 1), "points": map_to_game(hem.points)}
        record["blocks"] = home["blocks"]
    return record


def write_report(path, world, data, roads, block_list, buildings, found, home, problems, town_change, dem_max, raw,
                 rock_cells=0, out=None, anchor_list=None, works=None, sea_objects=None, tree_record=None,
                 tree_counts=None, cover_record=None):
    manifest = load_json(raw / "manifest.json") if (raw / "manifest.json").exists() else {"files": []}
    lines = ["# Geodata report", "", f"Made by `tools/geo/build.py` on {datetime.date.today().isoformat()}.", ""]
    lines += ["## Extents", "", "| Item | Value |", "|---|---|",
              f"| Box (degrees) | {world['bbox']['south']}° to {world['bbox']['north']}° N, {world['bbox']['west']}° to {world['bbox']['east']}° E |",
              f"| OSM data (degrees) | {data.lat_range[0]:.5f}° to {data.lat_range[1]:.5f}° N, {data.lon_range[0]:.5f}° to {data.lon_range[1]:.5f}° E |",
              f"| Game X (m) | {world['map_extents_m']['x'][0]} to {world['map_extents_m']['x'][1]} |",
              f"| Game Z (m) | {world['map_extents_m']['z'][0]} to {world['map_extents_m']['z'][1]} |",
              f"| Origin | {world['origin']['lat']}° N, {world['origin']['lon']}° E (UTM 48N {world['origin']['utm_e']:.0f} E, {world['origin']['utm_n']:.0f} N) |",
              f"| Height chunks | {len(world['chunks'])} ({sum(1 for c in world['chunks'] if c['land'])} with land) |",
              f"| Highest DEM sample | {dem_max:.1f} m |",
              f"| Mean height change in towns (buildings removed) | {town_change:.2f} m |", ""]
    counts: dict[str, list] = {}
    for r in roads:
        counts.setdefault(r.type, []).append(r)
    total = sum(r.length for r in roads)
    lines += ["## Roads", "", f"Total road length: {total / 1000:.1f} km. Roads with a width tag: "
              f"{sum(1 for r in roads if r.width_source == 'tag')} of {len(roads)}. Hẻm: {sum(1 for r in roads if r.hem)}.", "",
              "| Type | Roads | Length (km) |", "|---|---|---|"]
    for kind in sorted(counts, key=lambda k: -sum(r.length for r in counts[k])):
        lines.append(f"| {kind} | {len(counts[kind])} | {sum(r.length for r in counts[kind]) / 1000:.2f} |")
    with_buildings = sum(1 for b in block_list if b["buildings"] > 0)
    lines += ["", "## Blocks and buildings", "", f"- Blocks: {len(block_list)}.",
              f"- Blocks with OSM building outlines: {with_buildings}.", f"- Buildings: {len(buildings)}.", ""]
    lines += ["## Landmarks", "", "| Landmark | Found | OSM | Position (game X, Z) | Height (m) | Note |", "|---|---|---|---|---|---|"]
    for r in found:
        if r["found"]:
            note = f"{r['candidates']} candidates" + (f", {r['distance_to_hint_m']} m from the hint" if "distance_to_hint_m" in r else "")
            lines.append(f"| {r['name_vi']} | yes | {r['osm']} | {r['position'][0]}, {r['position'][1]} | {r.get('height', '')} | {note} |")
        else:
            lines.append(f"| {r['name_vi']} | **no** | | | | {r['reason']} |")
    lines += ["", "## Homestay hẻm", ""]
    if home["found"]:
        hem = home["hem"]
        lines.append(f"Found: way {hem.id} ({hem.name or 'no name'}, {hem.type}, {hem.width} m wide, {hem.length:.0f} m long). "
                     f"Check it on `homestay_area.png`.")
    else:
        lines.append("Not found. See `homestay_area.png`.")
    if "curve" in home:
        lines.append(f"The first curve of the lighthouse road turns {home['curve']['turn_deg']:.0f}° between "
                     f"{home['curve']['start_distance_m']:.0f} m and {home['curve']['end_distance_m']:.0f} m from the bottom.")
    for i, c in enumerate(home["candidates"], start=1):
        lines.append(f"- Candidate {i}: way {c['road'].id} ({c['road'].name or 'no name'}), {c['angle_diff_deg']}° from the direction before the curve.")
    for p in home["problems"]:
        lines.append(f"- Problem: {p}")
    floor = world["sea_floor"]
    lines += ["", "## The sea floor, the rocks, and the Hòn Bà ridge (R8g, R8h)", "",
              (f"- The sea floor comes from the intertidal zone of the Sentinel-2 images and from GEBCO 2025: see "
               f"`intertidal_report.md`. Where both have no value near the coast, it slopes from {floor['coast_m']:+.1f} m "
               f"at the coastline to {floor['depth_m']:+.1f} m over {floor['slope_m']:.0f} m."
               if floor.get("source") == "intertidal and GEBCO" else
               f"- The sea floor slopes from {floor['coast_m']:+.1f} m at the coastline to {floor['depth_m']:+.1f} m "
               f"over {floor['slope_m']:.0f} m, then stays at {floor['depth_m']:+.1f} m."),
              f"- Rocks in the sea: {rock_cells} grid cells at {floor['rock_m']:+.1f} m."]
    for rock_coast in world.get("rock_coasts", []):
        lines.append(f"- The rocky coast {rock_coast['name']} (overrides.json): {rock_coast['area_m2']} m² of bare rock, "
                     "on the land and in the sea in front of it.")
    for shelf in world.get("rock_shelves", []):
        lines.append(f"- The flat rocks {shelf['name']} (overrides.json): {shelf['area_m2']} m² at "
                     f"{shelf['height_m']:+.2f} m, dry when the tide is lower.")
    if world.get("islands"):
        lines.append(f"- {len(world['islands'])} small islands with large boulders (up to "
                     f"{terrain.ISLAND_BOULDER_M:.1f} m) and trees on their tops.")
    ridge = world.get("hon_ba_ridge")
    if ridge:
        lines.append(f"- The ridge {ridge['name']} ({ridge['osm']}): {ridge['length_m']:.0f} m long, "
                     f"{ridge['width_m']:.0f} m wide, top at {ridge['top_m']:+.2f} m.")
        band = ridge.get("band")
        if band:
            lines.append(f"- The band of rocks {band['name']}: about {band['width_m']:.0f} m wide, {band['sea_cells']} "
                         f"grid cells in the sea, from {band['min_m']:+.2f} m (tide pools) to {band['max_m']:+.2f} m "
                         f"(outcrops).")
            flat = ridge["sand_flat"]
            lines.append(f"- The sand flat in front of the path: {flat['radius_m']:.0f} m around the beach end, at "
                         f"{flat['height_m']:+.2f} m ({flat['cells']} grid cells).")
    else:
        lines.append("- The Hòn Bà ridge is not in the data.")
    tide_report = out / "tide_report.md" if out else None
    if tide_report and tide_report.exists():
        lines.append("- The tide: see `tide_report.md`.")
        text = tide_report.read_text(encoding="utf-8")
        tide_problems = text.split("## Problems", 1)[1].strip().splitlines() if "## Problems" in text else []
        problems = problems + [f"tide: {p[2:]}" for p in tide_problems if p.startswith("- ")]
    else:
        lines.append("- The tide: `tide.json` is not there. Run tools/geo/tide.py before build.py.")
        problems = problems + ["tide.json is not there"]
    lines += ["", "## Roadworks (R11a)", ""]
    for w in works or []:
        corner = f" The homestay hẻm ({w['corner']['hem']}) is at {w['corner']['distance_m']:.0f} m." if "corner" in w else ""
        lines.append(f"- {w['road']}: the first {w['length_m']:.0f} m from the {w['from']}, {w['width_m']:.1f} m wide, "
                     f"planned to end in {w['planned_end']}.{corner}")
    if not works:
        lines.append("None.")
    if sea_objects is not None:
        pier = sea_objects["ferry_pier"]
        lines += ["", "## Objects on the sea (R13a)", "",
                  f"- {len(sea_objects['cargo_ships'])} cargo ships at anchor and "
                  f"{len(sea_objects['fishing_boats'])} fishing boats.",
                  f"- The ferry pier {pier['name']}: {', '.join(p['osm'] for p in pier['parts']) or 'not found'}.",
                  f"- Groynes and breakwaters from OSM: "
                  f"{', '.join(g['osm'] for g in sea_objects['groynes']['lines']) or 'none'}."]
    if tree_record is not None:
        lines += ["", "## Trees (R12a)", ""]
        lines += [f"- {kind}: {len(points)}" for kind, points in tree_record["types"].items()]
        lines.append("- From: " + ", ".join(f"{k} {v}" for k, v in sorted((tree_counts or {}).items())) + ".")
    if cover_record is not None:
        lines += [""] + cover_report_lines(cover_record)
    lines += [""] + anchors_module.report_lines(anchor_list or [])
    lines += ["## Corrections from overrides.json", ""]
    lines += [f"- {c}" for c in data.corrections] or ["None."]
    lines += ["", "## Problems with the data", ""]
    lines += [f"- {p}" for p in problems[:200]] or ["None."]
    if len(problems) > 200:
        lines.append(f"- And {len(problems) - 200} more.")
    lines += ["", "## Source files", "", "| File | Source | Date | SHA-256 | License |", "|---|---|---|---|---|"]
    for f in manifest.get("files", []):
        lines.append(f"| {f['file']} | {f['url']} | {f['date']} | `{f['sha256'][:16]}…` | {f['license']} |")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--raw", type=Path, default=RAW)
    parser.add_argument("--out", type=Path, default=BUILD)
    parser.add_argument("--geo", type=Path, default=GEO)
    args = parser.parse_args()
    return build(args.raw, args.out, args.geo)


if __name__ == "__main__":
    sys.exit(main())
