"""The ground of the showcase of Bãi Trước (plan 0026, R3 and R4).

From the areas of OpenStreetMap that the "ground" part of
data/showcase/bai_truoc.json names, this module makes:

- a fine mask of the ground (cells of cell_m): R the lawns, G the paving of the
  squares and of the walk of the sea, B the beds of soil with low plants that
  a photo shows (the part "drawn", report 0026, D-0026-30). The lawns are the park and the grass
  areas, less the roads and the paths, the paved areas, the water, the beach,
  the parking areas, and the buildings.
- the raised lawns (the strips of lawn in low granite borders on the walk of
  the sea, photo of S5): their outlines.
- the low wall along the beach: the edges of the walk areas that are near the
  beach.

All points are game (x, z): x east, z south (the map y is -z).
"""

import numpy as np
import shapely
import shapely.geometry.polygon
from shapely.geometry import LineString, MultiLineString, Polygon
from shapely.ops import unary_union

# The mask is made at a finer cell, then each block of FINE x FINE cells gives one mask cell (smooth edges).
FINE = 2


def _ids(values) -> set[str]:
    return {str(v) for v in values}


def _lines_of(geometry) -> list[LineString]:
    if geometry.is_empty:
        return []
    if isinstance(geometry, LineString):
        return [geometry]
    if isinstance(geometry, MultiLineString):
        return list(geometry.geoms)
    return [g for g in getattr(geometry, "geoms", []) if isinstance(g, LineString)]


def _game_ring(polygon: Polygon) -> list[list[float]]:
    return [[round(x, 2), round(-y, 2)] for x, y in polygon.exterior.coords[:-1]]


def _game_line(line: LineString) -> list[list[float]]:
    return [[round(x, 2), round(-y, 2)] for x, y in line.coords]


def _beach_edges(walk: Polygon, beach, outline: Polygon, reach: float) -> list[LineString]:
    """The edges of the walk that face the beach: each piece of its outline (1 m
    or less) within reach of the beach, whose outer side is nearer to the beach
    than the piece (or on the beach). So the wall does not turn round the corners of the walk."""
    ring = shapely.geometry.polygon.orient(walk, 1.0).exterior
    points = np.asarray(shapely.segmentize(ring, 1.0).coords)
    lines, current = [], []
    for a, b in zip(points[:-1], points[1:]):
        d = b - a
        length = float(np.hypot(*d))
        if length == 0.0:
            continue
        middle = (a + b) / 2.0
        outward = middle + np.array([d[1], -d[0]]) / length  # the ring goes counterclockwise
        here = beach.distance(shapely.Point(middle))
        out = shapely.Point(outward)
        faces = beach.contains(out) or beach.distance(out) < here
        keep = here <= reach and faces and outline.contains(shapely.Point(middle))
        if keep:
            if not current:
                current = [tuple(a)]
            current.append(tuple(b))
        elif current:
            lines.append(LineString(current))
            current = []
    if current:
        lines.append(LineString(current))
    # The ring starts at an arbitrary point: join the last line and the first when they meet.
    if len(lines) > 1 and lines[0].coords[0] == lines[-1].coords[-1]:
        lines[0] = LineString(list(lines[-1].coords) + list(lines[0].coords)[1:])
        lines.pop()
    return [line.simplify(0.05) for line in lines]


def make(config: dict, areas: list[tuple[str, dict, object]], roads, buildings: list[Polygon], outline: Polygon,
         road_widths: dict | None = None) -> dict:
    """config: the "ground" part of the showcase file. areas: (osm id
    "way/ID", tags, map geometry) for each area of OSM. roads: the roads of the
    build (map points and width). buildings: map polygons. outline: the area of
    the showcase as a map polygon. Returns {"mask": RGBA uint8 array, "x0",
    "z0" (the game point of the corner of the first cell), "step",
    "planters", "walls", "areas"}."""
    by_id = {osm: (tags, geometry) for osm, tags, geometry in areas}
    problems = []

    def shapes(ids) -> list:
        result = []
        for osm in ids:
            if osm not in by_id:
                problems.append(f"the showcase ground names {osm}, but OSM has no such area")
                continue
            result.append(by_id[osm][1])
        return result

    lawn_ids = _ids(config.get("lawns", []))
    paving_ids = _ids(config.get("paving", []))
    lawn = unary_union(shapes(lawn_ids)).intersection(outline) if lawn_ids else Polygon()
    # The areas that a photo shows and OSM does not have (report 0026,
    # D-0026-30): outlines in game (x, z), drawn on a photo with the ways of
    # OSM as the reference. A "lawn" adds to the lawns, a "paving" to the
    # paving; a "bed" (soil with low plants in a low border) is the channel B
    # of the mask. The roads, the
    # paths, the paving, and the areas of not_lawn come off them as off the
    # lawns of OSM.
    drawn: dict[str, list] = {"lawn": [], "paving": [], "bed": []}
    for item in config.get("drawn", []):
        if len(item.get("outline", [])) >= 3:
            drawn.setdefault(item.get("kind", "lawn"), []).append(
                Polygon([(float(x), -float(z)) for x, z in item["outline"]]))
    if drawn["lawn"]:
        lawn = unary_union([lawn] + drawn["lawn"]).intersection(outline)
    bed = unary_union(drawn["bed"]).intersection(outline) if drawn["bed"] else Polygon()
    paving = unary_union(shapes(paving_ids)).intersection(outline) if paving_ids else Polygon()
    if drawn.get("paving"):
        paving = unary_union([paving] + drawn["paving"]).intersection(outline)
    # The paths and the walk of the sea (the lines of OSM) are paving too: the
    # game draws them as roads, and the mask keeps the lawn off them.
    margin = float(config.get("road_margin_m", 0.3))
    path_types = set(config.get("path_types", ["footway", "pedestrian", "path", "steps"]))
    road_shapes, path_shapes = [], []
    for road in roads:
        if road.points is None or len(road.points) < 2:
            continue
        line = LineString(road.points)
        if not line.intersects(outline):
            continue
        shape = line.buffer(float(road.width) / 2.0 + margin, cap_style="flat")
        (path_shapes if road.type in path_types else road_shapes).append(shape)
    keys = [tuple(k) for k in config.get("not_lawn", [])]
    not_lawn = [geometry for osm, (tags, geometry) in by_id.items()
                if osm not in lawn_ids and any(tags.get(k) == v for k, v in keys)]
    near = outline.buffer(50.0)
    not_lawn = [g for g in not_lawn if g.intersects(near)] + [b for b in buildings if b.intersects(near)]
    lawn = lawn.difference(unary_union(road_shapes + path_shapes + not_lawn + [paving]))
    bed = bed.difference(unary_union(road_shapes + path_shapes + not_lawn + [paving]))
    lawn = lawn.difference(bed)
    paving = paving.difference(unary_union(road_shapes))

    # The raised lawns: the grass areas of the walk of the sea.
    planter_cfg = config.get("planters", {})
    planters = []
    for osm in sorted(_ids(planter_cfg.get("osm", []))):
        for geometry in shapes([osm]):
            for part in getattr(geometry, "geoms", [geometry]):
                if isinstance(part, Polygon) and not part.is_empty:
                    planters.append({"osm": osm, "outline": _game_ring(part.simplify(0.05))})

    # The low wall along the beach: the edges of the walk areas within near_beach_m of the beach.
    wall_cfg = config.get("beach_wall", {})
    walls = []
    beach = unary_union([g for _osm, (tags, g) in by_id.items() if tags.get("natural") == "beach" and g.intersects(near)])
    reach = float(wall_cfg.get("near_beach_m", 4.0))
    min_length = float(wall_cfg.get("min_length_m", 3.0))
    for osm in sorted(_ids(wall_cfg.get("walks", []))):
        for geometry in shapes([osm]):
            for part in getattr(geometry, "geoms", [geometry]):
                if not isinstance(part, Polygon) or beach.is_empty:
                    continue
                for line in _beach_edges(part, beach, outline, reach):
                    if line.length >= min_length:
                        walls.append({"osm": osm, "points": _game_line(line)})

    # The mask: its box is the box of the lawns, the paving, and the beds, and a margin of two cells.
    step = float(config.get("cell_m", 0.5))
    both = unary_union([lawn, paving, bed])
    if both.is_empty:
        return {"mask": None, "planters": planters, "walls": walls, "problems": problems}
    x_min, y_min, x_max, y_max = both.bounds
    x0 = np.floor(x_min / step) * step - 2 * step
    x1 = np.ceil(x_max / step) * step + 2 * step
    top = np.ceil(y_max / step) * step + 2 * step  # the map y of the first row (the north edge)
    bottom = np.floor(y_min / step) * step - 2 * step
    columns = int(round((x1 - x0) / step))
    rows = int(round((top - bottom) / step))
    from rasterio import features
    from rasterio.transform import Affine

    fine = step / FINE
    transform = Affine(fine, 0, x0, 0, -fine, top)

    def channel(geometry) -> np.ndarray:
        if geometry.is_empty:
            return np.zeros((rows, columns), dtype=np.uint8)
        cells = features.rasterize([(geometry, 1)], out_shape=(rows * FINE, columns * FINE), transform=transform,
                                   fill=0, dtype=np.uint8)
        share = cells.reshape(rows, FINE, columns, FINE).mean(axis=(1, 3))
        return np.round(share * 255).astype(np.uint8)

    mask = np.dstack([channel(lawn), channel(paving), channel(bed),
                      np.full((rows, columns), 255, np.uint8)])
    return {"mask": mask, "x0": float(x0), "z0": float(-top), "step": step, "columns": columns, "rows": rows,
            "planters": planters, "walls": walls, "problems": problems,
            "areas": {"lawn_m2": round(lawn.area), "paving_m2": round(paving.area), "bed_m2": round(bed.area)}}


# Report 0026, D-0026-11: the ground under and beside the parts of the showcase
# that a player walks on. The game puts a road this much over its line
# (RoadBuilder.LIFT) and the walk on the sea wall this much over its sidewalk
# (Showcase.OVER_SIDEWALK_LIFT); its sidewalk is 0.15 m high (RoadBuilder.CURB).
ROAD_LIFT_M = 0.04
SEA_WALK_OVER_M = 0.15 + 0.02
# The ground under a part is this much under its top, so that it does not show through.
UNDER_TOP_M = 0.03
# Past the outer edge of a sidewalk, lower ground rises to the sidewalk with this
# grade, over this width: the paths of the park meet the sidewalk at its level.
SIDE_RAMP_GRADE = 0.2
SIDE_RAMP_M = 10.0
# The ways that a band of a walk part can cover. The ground of other roads does not change.
WALK_WAY_TYPES = {"footway", "path", "steps", "pedestrian", "cycleway", "track"}


# Report 0026, D-0026-30 (audit 6): a platform is level to the highest ground
# of its outline within this distance (m) of each cell.
PLATFORM_REACH_M = 12.0


def level_platforms(grid, config: dict) -> int:
    """Fills the ground under each area of the part "drawn" of the ground with
    "platform" (the square of the south end: a platform over the water with
    its parapet, the drone photo of 2021) to the height of its land side: each
    cell in the outline takes at least the highest ground of the outline
    within PLATFORM_REACH_M of it. The ground that is higher stays. Returns
    the count of cells that changed."""
    from .terrain import rasterize
    changed = 0
    for item in config.get("ground", {}).get("drawn", []):
        if not item.get("platform"):
            continue
        # One grid step past the outline: the ground between two cells mixes
        # their heights, and the parapet at the edge stood on the slope to the sea.
        outline = Polygon([(float(x), -float(z)) for x, z in item["outline"]]).buffer(grid.step, join_style=2)
        mask = rasterize(grid, [outline])
        if not mask.any():
            continue
        heights = np.where(mask, grid.heights, -np.inf)
        reach = int(round(PLATFORM_REACH_M / grid.step))
        level = np.full(grid.heights.shape, -np.inf)
        rows, cols = np.nonzero(mask)
        r0, r1 = max(rows.min() - reach, 0), min(rows.max() + reach + 1, mask.shape[0])
        c0, c1 = max(cols.min() - reach, 0), min(cols.max() + reach + 1, mask.shape[1])
        window = heights[r0:r1, c0:c1]
        top = np.full(window.shape, -np.inf)
        for dr in range(-reach, reach + 1):
            for dc in range(-reach, reach + 1):
                if dr * dr + dc * dc > reach * reach:
                    continue
                shifted = np.full(window.shape, -np.inf)
                rs = slice(max(dr, 0), window.shape[0] + min(dr, 0))
                rd = slice(max(-dr, 0), window.shape[0] + min(-dr, 0))
                cs = slice(max(dc, 0), window.shape[1] + min(dc, 0))
                cd = slice(max(-dc, 0), window.shape[1] + min(-dc, 0))
                shifted[rd, cd] = window[rs, cs]
                top = np.maximum(top, shifted)
        level[r0:r1, c0:c1] = top
        fill = mask & np.isfinite(level) & (grid.heights < level)
        grid.heights[fill] = level[fill]
        changed += int(fill.sum())
    return changed


def level_walks(grid, config: dict, roads) -> dict:
    """Sets the ground under the sidewalks and the walk on the sea wall of
    the showcase (the parts "sidewalks" and "sea_walls" of
    data/showcase/bai_truoc.json, in its outline) to their tops less
    UNDER_TOP_M, from one grid step past the edge of the road (the road
    surface is flat to there), to two grid steps past the outer edge of a
    sidewalk (so that the ground at its edge is level, also between two
    samples) and one grid step past the walk. Past a sidewalk, lower ground
    rises to it with SIDE_RAMP_GRADE; higher ground stays (a lot or a bank).
    A cell takes the nearest point of the line of its road, also on the
    outer side of a bend. The game makes the tops the same way: the top of a
    sidewalk is its road plus ROAD_LIFT_M plus its height, and the walk on
    the sea wall is its road plus ROAD_LIFT_M plus SEA_WALK_OVER_M.
    Returns {"cells": changed cells, "walks": the cells under the parts
    themselves (to their outer edges and half a grid step more)}."""
    h = grid.heights
    walks = np.zeros(h.shape, dtype=bool)
    outline_points = config.get("outline", [])
    if len(outline_points) < 3:
        return {"cells": 0, "walks": walks}
    outline = Polygon(outline_points)  # game (x, z)
    by_id = {int(r.id): r for r in roads}
    rows, cols = h.shape
    # The cells of the surfaces of the other roads do not change.
    protected = np.zeros(h.shape, dtype=bool)
    for road in roads:
        if road.type in WALK_WAY_TYPES or road.points is None or len(road.points) < 2:
            continue
        protected |= _near_line(grid, road.points[:, 0], -road.points[:, 1], road.width / 2.0 + grid.step)
    inside = _inside(grid, outline)
    target = np.full(h.shape, -np.inf)
    # Where the bands of two parts meet, a cell takes the part that it is under,
    # or the part with the nearest outer edge (the start of the walk on the sea
    # wall is in the band past the sidewalk of Quang Trung).
    past_edge = np.full(h.shape, np.inf)
    ramp = np.full(h.shape, -np.inf)
    # (way, side, width of the part, its height over the road, the band past its outer edge, a ramp, until z)
    parts = [(int(s["way"]), s.get("side", "right"), float(s.get("width", 2.0)), float(s.get("height", 0.15)),
              2.0 * grid.step, True, np.inf) for s in config.get("sidewalks", [])]
    for wall in config.get("sea_walls", []):
        for way in wall.get("ways", []):
            parts.append((int(way), wall.get("side", "right"), float(wall.get("walk", 3.0)), SEA_WALK_OVER_M,
                          grid.step, False, float(wall.get("until_z", np.inf))))
    for way, side, width, height, past, with_ramp, until_z in parts:
        road = by_id.get(way)
        if road is None or road.points is None or len(road.points) < 2:
            continue
        sign = 1.0 if side == "right" else -1.0
        x = road.points[:, 0]
        z = -road.points[:, 1]
        surface = grid.sample(x, z)
        half = road.width / 2.0
        near = half + grid.step
        edge = half + width
        far = edge + past
        reach = far + (SIDE_RAMP_M if with_ramp else 0.0)
        best = np.full(h.shape, np.inf)
        offset = np.zeros(h.shape)
        top = np.zeros(h.shape)
        for i in range(len(x) - 1):
            ax, az, bx, bz = x[i], z[i], x[i + 1], z[i + 1]
            dx, dz = bx - ax, bz - az
            length2 = dx * dx + dz * dz
            if length2 <= 0.0:
                continue
            c0 = max(0, int((min(ax, bx) - reach - grid.x0) / grid.step))
            c1 = min(cols - 1, int((max(ax, bx) + reach - grid.x0) / grid.step) + 1)
            r0 = max(0, int((min(az, bz) - reach - grid.z0) / grid.step))
            r1 = min(rows - 1, int((max(az, bz) + reach - grid.z0) / grid.step) + 1)
            if c1 < c0 or r1 < r0:
                continue
            gx, gz = np.meshgrid(grid.x0 + np.arange(c0, c1 + 1) * grid.step, grid.z0 + np.arange(r0, r1 + 1) * grid.step)
            t = np.clip(((gx - ax) * dx + (gz - az) * dz) / length2, 0.0, 1.0)
            d = np.hypot(gx - (ax + t * dx), gz - (az + t * dz))
            window = (slice(r0, r1 + 1), slice(c0, c1 + 1))
            nearer = d < best[window]
            # The game side of a line: (-forward.z, forward.x) (Showcase._sides()).
            side_of = -(gx - ax) * dz + (gz - az) * dx
            best[window] = np.where(nearer, d, best[window])
            offset[window] = np.where(nearer, np.where(sign * side_of > 0.0, d, -d), offset[window])
            top[window] = np.where(nearer, surface[i] + t * (surface[i + 1] - surface[i]), top[window])
        rows_z = grid.z0 + np.arange(rows) * grid.step
        ok = np.isfinite(best) & (rows_z[:, None] <= until_z)
        top = top + ROAD_LIFT_M + height - UNDER_TOP_M
        band = ok & (offset > near) & (offset <= far)
        out = ok & (offset > far) & (offset <= reach)
        rel = np.maximum(offset - edge, 0.0)
        take = band & (rel < past_edge)
        target[take] = top[take]
        past_edge[take] = rel[take]
        ramp[out] = np.maximum(ramp[out], (top - SIDE_RAMP_GRADE * (offset - far))[out])
        walks |= ok & (offset > near) & (offset <= edge + grid.step / 2.0)
    free = inside & ~protected
    band_cells = free & np.isfinite(target)
    h[band_cells] = target[band_cells]
    ramp_cells = free & ~band_cells & np.isfinite(ramp) & (h < ramp)
    h[ramp_cells] = ramp[ramp_cells]
    return {"cells": int(band_cells.sum() + ramp_cells.sum()), "walks": walks & free}


def _near_line(grid, x: np.ndarray, z: np.ndarray, reach: float) -> np.ndarray:
    """The cells within "reach" of the line (game x, z)."""
    rows, cols = grid.heights.shape
    mask = np.zeros((rows, cols), dtype=bool)
    for i in range(len(x) - 1):
        ax, az, bx, bz = x[i], z[i], x[i + 1], z[i + 1]
        c0 = max(0, int((min(ax, bx) - reach - grid.x0) / grid.step))
        c1 = min(cols - 1, int((max(ax, bx) + reach - grid.x0) / grid.step) + 1)
        r0 = max(0, int((min(az, bz) - reach - grid.z0) / grid.step))
        r1 = min(rows - 1, int((max(az, bz) + reach - grid.z0) / grid.step) + 1)
        if c1 < c0 or r1 < r0:
            continue
        gx, gz = np.meshgrid(grid.x0 + np.arange(c0, c1 + 1) * grid.step, grid.z0 + np.arange(r0, r1 + 1) * grid.step)
        dx, dz = bx - ax, bz - az
        length2 = max(dx * dx + dz * dz, 1e-9)
        t = np.clip(((gx - ax) * dx + (gz - az) * dz) / length2, 0.0, 1.0)
        mask[r0:r1 + 1, c0:c1 + 1] |= np.hypot(gx - (ax + t * dx), gz - (az + t * dz)) <= reach
    return mask


def _inside(grid, outline: Polygon) -> np.ndarray:
    """The cells whose centers are in the polygon (game x, z)."""
    rows, cols = grid.heights.shape
    minx, minz, maxx, maxz = outline.bounds
    mask = np.zeros((rows, cols), dtype=bool)
    c0 = max(0, int((minx - grid.x0) / grid.step))
    c1 = min(cols - 1, int((maxx - grid.x0) / grid.step) + 1)
    r0 = max(0, int((minz - grid.z0) / grid.step))
    r1 = min(rows - 1, int((maxz - grid.z0) / grid.step) + 1)
    if c1 < c0 or r1 < r0:
        return mask
    gx, gz = np.meshgrid(grid.x0 + np.arange(c0, c1 + 1) * grid.step, grid.z0 + np.arange(r0, r1 + 1) * grid.step)
    mask[r0:r1 + 1, c0:c1 + 1] = shapely.contains_xy(outline, gx, gz)
    return mask


# Report 0026, D-0026-25: the walk is level to the low wall of the beach. The
# ground of the walk side within WALL_LEVEL_M of the line comes up to the
# ground WALL_LEVEL_M from it (near the eye of S1 the walk fell 0.6 m in its
# last 2 m to the wall: 4.63 m at 3 m from the line, 4.02 m at 1 m), by at most
# WALL_FILL_M. The walk side is the side whose point WALL_SIDE_M out is not on
# the beach; where both or neither are, the ground stays.
WALL_LEVEL_M = 3.0
WALL_SIDE_M = 1.5
WALL_FILL_M = 0.8


def level_to_beach_walls(grid, lines: list[list[list[float]]], beaches: list, reach: float = WALL_LEVEL_M) -> int:
    """Fills the ground of the walk side of each line ([x, z] of the game) to
    the level of the walk at "reach" from the line. beaches: the beach shapes
    (map x, y). Returns the number of cells that changed."""
    from shapely.geometry import Point
    from shapely.ops import unary_union
    from shapely.prepared import prep
    beach = prep(unary_union(beaches)) if beaches else None
    changed = np.zeros(grid.heights.shape, dtype=bool)
    if beach is None:
        return 0
    for line in lines:
        points = np.asarray(line, dtype=float)
        for a, b in zip(points[:-1], points[1:]):
            d = b - a
            length = float(np.hypot(*d))
            if length < 0.01:
                continue
            u = d / length
            n = np.array([-u[1], u[0]])
            mid = (a + b) / 2.0
            plus = beach.contains(Point(mid[0] + n[0] * WALL_SIDE_M, -(mid[1] + n[1] * WALL_SIDE_M)))
            minus = beach.contains(Point(mid[0] - n[0] * WALL_SIDE_M, -(mid[1] - n[1] * WALL_SIDE_M)))
            if plus == minus:
                continue
            side = -n if plus else n
            lo = np.minimum(a, b) - reach - grid.step
            hi = np.maximum(a, b) + reach + grid.step
            c0, c1 = int(np.floor((lo[0] - grid.x0) / grid.step)), int(np.ceil((hi[0] - grid.x0) / grid.step))
            r0, r1 = int(np.floor((lo[1] - grid.z0) / grid.step)), int(np.ceil((hi[1] - grid.z0) / grid.step))
            c0, r0 = max(c0, 0), max(r0, 0)
            c1, r1 = min(c1, grid.heights.shape[1] - 1), min(r1, grid.heights.shape[0] - 1)
            if c1 < c0 or r1 < r0:
                continue
            cols, rows = np.meshgrid(np.arange(c0, c1 + 1), np.arange(r0, r1 + 1))
            x = grid.x0 + cols * grid.step
            z = grid.z0 + rows * grid.step
            along = (x - a[0]) * u[0] + (z - a[1]) * u[1]
            out = (x - a[0]) * side[0] + (z - a[1]) * side[1]
            band = (along >= 0.0) & (along <= length) & (out >= -grid.step * 0.5) & (out <= reach)
            if not band.any():
                continue
            # The level of the walk: the ground at "reach" out from the point of the line.
            px = a[0] + u[0] * along[band] + side[0] * reach
            pz = a[1] + u[1] * along[band] + side[1] * reach
            level = grid.sample(px, pz)
            rr, cc = rows[band], cols[band]
            fill = np.minimum(level, grid.heights[rr, cc] + WALL_FILL_M)
            low = grid.heights[rr, cc] < fill
            grid.heights[rr[low], cc[low]] = fill[low]
            changed[rr[low], cc[low]] = True
    return int(changed.sum())
