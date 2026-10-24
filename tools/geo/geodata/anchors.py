"""Finds the town anchors by type (plan 0004, R6a): bus stations, markets,
roundabouts, and junctions where five or more roads meet. Their names in OSM
can differ from the names that people use, so build.py draws them on a map
with numbers (anchors.png) and lists them in the report."""

from collections import defaultdict

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from .config import FONT
from .mapdraw import COLORS

# The roads that count as a road at a junction.
JUNCTION_TYPES = {"motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential",
                  "living_street", "primary_link", "secondary_link", "tertiary_link"}
MIN_ARMS = 5
SCALE = 0.4  # pixels for each meter
MARGIN_M = 300.0
KIND_COLORS = {"bus_station": (30, 90, 200), "marketplace": (210, 30, 40), "roundabout": (40, 140, 60),
               "junction": (150, 60, 170)}


def _centroid(points) -> tuple[float, float]:
    array = np.asarray(points, dtype=float)
    return float(array[:, 0].mean()), float(array[:, 1].mean())


def find(data, projection, roads) -> list[dict]:
    """The anchor candidates: [{number, kind, osm, name, map: (x, y), game: [x, z]}]."""
    found = []

    def add(kind, osm, name, lon, lat):
        x, y = projection.to_map(np.array([lon]), np.array([lat]))
        found.append({"kind": kind, "osm": osm, "name": name, "map": (float(x[0]), float(y[0]))})

    for amenity in ("bus_station", "marketplace"):
        for node in data.nodes:
            if node.tags.get("amenity") == amenity:
                add(amenity, f"node/{node.id}", node.tags.get("name", ""), node.lon, node.lat)
        for area in data.areas:
            if area.tags.get("amenity") == amenity:
                c = area.geometry.centroid
                add(amenity, f"{area.kind}/{area.id}", area.tags.get("name", ""), c.x, c.y)
    # A roundabout is often more than one way: join the ways that share a node.
    rings = [w for w in data.ways if w.tags.get("junction") == "roundabout"]
    groups: list[list] = []
    for way in rings:
        joined = [g for g in groups if any(set(way.refs) & set(other.refs) for other in g)]
        merged = [way] + [w for g in joined for w in g]
        groups = [g for g in groups if g not in joined] + [merged]
    for group in groups:
        names_count = defaultdict(int)
        for way in group:
            if way.tags.get("name"):
                names_count[way.tags["name"]] += 1
        name = max(names_count, key=names_count.get) if names_count else ""
        lon, lat = _centroid([c for way in group for c in way.coords])
        add("roundabout", "way/" + ",".join(str(w.id) for w in sorted(group, key=lambda w: w.id)[:3]), name, lon, lat)
    # The arms at each node: 1 for the end of a road, 2 for a node inside a road.
    arms = defaultdict(int)
    names_at = defaultdict(set)
    where = {}
    for road in roads:
        if road.type not in JUNCTION_TYPES:
            continue
        for i, ref in enumerate(road.refs):
            arms[ref] += 1 if i in (0, len(road.refs) - 1) else 2
            names_at[ref].add(road.name)
            where[ref] = road.node_points[i]
    in_roundabout = {ref for group in groups for way in group for ref in way.refs}
    junction_names = {n.id: n.tags.get("name", "") for n in data.nodes}
    for ref, count in arms.items():
        if count >= MIN_ARMS and ref not in in_roundabout:
            name = junction_names.get(ref, "") or " / ".join(sorted(n for n in names_at[ref] if n))
            found.append({"kind": "junction", "osm": f"node/{ref}", "name": name,
                          "map": (float(where[ref][0]), float(where[ref][1]))})
    found.sort(key=lambda a: (list(KIND_COLORS).index(a["kind"]), -a["map"][1], a["map"][0]))
    for number, anchor in enumerate(found, start=1):
        anchor["number"] = number
        anchor["game"] = [round(anchor["map"][0], 1), round(-anchor["map"][1], 1)]
    return found


def draw(path, anchors: list[dict], roads, land) -> None:
    """A map of the town with each anchor candidate as a number in the color of its kind."""
    if not anchors:
        return
    xs = [a["map"][0] for a in anchors]
    ys = [a["map"][1] for a in anchors]
    x0, x1 = min(xs) - MARGIN_M, max(xs) + MARGIN_M
    y0, y1 = min(ys) - MARGIN_M, max(ys) + MARGIN_M
    width, height = int((x1 - x0) * SCALE), int((y1 - y0) * SCALE)
    image = Image.new("RGB", (width, height), COLORS["sea"])
    pen = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(FONT), 16) if FONT.exists() else ImageFont.load_default()
    big = ImageFont.truetype(str(FONT), 20) if FONT.exists() else ImageFont.load_default()

    def px(points):
        return [((x - x0) * SCALE, (y1 - y) * SCALE) for x, y in points]

    for part in getattr(land, "geoms", [land]):
        if hasattr(part, "exterior"):
            pen.polygon(px(part.exterior.coords), fill=COLORS["background"])
    for road in sorted(roads, key=lambda r: -r.importance):
        if road.hem:
            continue
        pen.line(px(road.points), fill=COLORS["road_edge"], width=max(1, int(road.width * SCALE)), joint="curve")
    for anchor in anchors:
        x, y = px([anchor["map"]])[0]
        color = KIND_COLORS[anchor["kind"]]
        pen.ellipse((x - 5, y - 5, x + 5, y + 5), fill=color)
        pen.text((x + 7, y - 10), str(anchor["number"]), fill=color, font=big, stroke_width=2,
                 stroke_fill=(255, 255, 255))
    legend = "Bus station (blue), market (red), roundabout (green), junction of 5 or more roads (purple)."
    pen.text((10, 10), legend, fill=COLORS["text"], font=font, stroke_width=2, stroke_fill=(255, 255, 255))
    image.save(path)


def report_lines(anchors: list[dict]) -> list[str]:
    lines = ["## Town anchors (R6a)", "",
             "`anchors.png` shows each candidate as a number. I write the correct Vietnamese names into `landmarks.json`.", "",
             "| Number | Kind | OSM | Name in OSM | Position (game X, Z) |", "|---|---|---|---|---|"]
    for a in anchors:
        lines.append(f"| {a['number']} | {a['kind'].replace('_', ' ')} | {a['osm']} | {a['name'] or '(no name)'} | "
                     f"{a['game'][0]}, {a['game'][1]} |")
    return lines + [""]
