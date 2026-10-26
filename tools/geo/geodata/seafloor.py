"""The report of the sea floor from data (plan 0005, R8g): the land that is dry
at the lowest tide of the game days, and the heights along a line from the
main beach of Bãi Trước out into the bay."""

import datetime

import numpy as np
from PIL import Image

from . import tidecalc

# The game days: from day 1 to the end of February 2019 (January and February 2019).
GAME_LAST_DAY = datetime.date(2019, 2, 28)
LOCAL = datetime.timezone(datetime.timedelta(hours=7))
# The profile: a point each PROFILE_STEP_M up to PROFILE_LENGTH_M from the sand.
PROFILE_STEP_M = 10.0
PROFILE_LENGTH_M = 600.0
# The distances of PT-35 (the water depth at low and high tide).
CHECK_DISTANCES_M = (100.0, 250.0)
MAP_STEP = 4


def tide_range(tide: dict, day_one: datetime.date, point: str = "bai_truoc") -> tuple[float, float]:
    """The lowest and the highest sea level of the game days."""
    start = datetime.datetime(day_one.year, day_one.month, day_one.day, tzinfo=LOCAL).timestamp()
    end = datetime.datetime(GAME_LAST_DAY.year, GAME_LAST_DAY.month, GAME_LAST_DAY.day, 23, 59, tzinfo=LOCAL).timestamp()
    levels = tidecalc.level(tide, point, np.arange(start, end, 600.0))
    return float(levels.min()), float(levels.max())


def profile(grid, land: np.ndarray, start: tuple[float, float], direction: tuple[float, float]) -> dict:
    """The heights along a line from the map point start (on the beach) in the
    map direction, from the first sea cell (the water line of the data) out.
    Returns the start of the sea in game coordinates, the game direction, and
    [distance from the sand, height] points."""
    d = np.asarray(direction, dtype=np.float64)
    d /= np.linalg.norm(d)
    x, y = start
    rows, cols = grid.shape
    shore = None
    for i in range(int(2000.0 / grid.step)):
        px, py = x + d[0] * i * grid.step, y + d[1] * i * grid.step
        col = int(round((px - grid.x0) / grid.step))
        row = int(round((-py - grid.z0) / grid.step))
        if 0 <= row < rows and 0 <= col < cols and not land[row, col]:
            shore = (px, py)
            break
    if shore is None:
        return {}
    distances = np.arange(0.0, PROFILE_LENGTH_M + 0.1, PROFILE_STEP_M)
    gx = shore[0] + d[0] * distances
    gz = -(shore[1] + d[1] * distances)
    heights = grid.sample(gx, gz)
    return {"start": [round(shore[0], 2), round(-shore[1], 2)], "direction": [round(float(d[0]), 4), round(float(-d[1]), 4)],
            "points": [[float(a), round(float(b), 2)] for a, b in zip(distances, heights)]}


def draw_dry_map(path, grid, land: np.ndarray, lowest: float) -> int:
    """A map of the land and of the sea floor that is dry at the lowest tide
    (sand color), and of the water (blue, darker when deeper). Returns the
    number of dry sea cells."""
    h = grid.heights[::MAP_STEP, ::MAP_STEP]
    on_land = land[::MAP_STEP, ::MAP_STEP]
    image = np.zeros(h.shape + (3,), dtype=np.uint8)
    depth = np.clip((lowest - h) / 10.0, 0.0, 1.0)[..., None]
    image[...] = (np.array([120, 190, 220]) * (1 - depth) + np.array([20, 50, 110]) * depth).astype(np.uint8)
    dry = ~on_land & (h > lowest)
    image[dry] = (226, 205, 150)
    image[on_land] = (130, 140, 115)
    Image.fromarray(image).save(path)
    return int((~land & (grid.heights > lowest)).sum())


def report(stats: dict, lowest: float, highest: float, line: dict, dry_cells: int, step: float, image_name: str) -> str:
    lines = ["# The sea floor report (plan 0005, R8g)", "",
             f"Made by `tools/geo/build.py` on {datetime.date.today().isoformat()}.", "",
             "## Sources", "",
             f"- The intertidal zone: {stats.get('intertidal_cells', 0)} grid cells with a height from the Sentinel-2 "
             "images and the tide (`tools/geo/intertidal.py`, the pixel method of DEA Intertidal)"
             + (f", from {stats['intertidal_min_m']:+.2f} m to {stats['intertidal_max_m']:+.2f} m." if
                stats.get("intertidal_cells") else "."),
             f"- The deeper water: {'the GEBCO 2025 grid' if stats.get('gebco') else 'no GEBCO data (the old slope)'}.",
             "- Between them, the floor slopes smoothly from the low-tide edge to the GEBCO depth. Where both have no value "
             "near the coast, the old slope stays.", "",
             "## The game days", "",
             f"The sea level of the game days (22 January to 28 February 2019) goes from {lowest:+.2f} m to {highest:+.2f} m.",
             f"At the lowest tide, {dry_cells * step * step / 1e6:.2f} km² of sea floor is dry.", "",
             f"![The land that is dry at the lowest tide]({image_name})", "",
             "Green: the land. Sand: the sea floor that is dry at the lowest tide. Blue: the water at the lowest tide "
             "(darker is deeper, to 10 m).", "",
             "## From the main beach of Bãi Trước out into the bay", ""]
    if line:
        lines += [f"The line starts at the water line of the data, game point ({line['start'][0]:.1f}, "
                  f"{line['start'][1]:.1f}), in the game direction ({line['direction'][0]:.2f}, {line['direction'][1]:.2f}).",
                  "", "| From the sand (m) | Height (m) | Depth at the lowest tide (m) | Depth at the highest tide (m) |",
                  "|---|---|---|---|"]
        for distance, height in line["points"]:
            if distance % 50 == 0:
                lines.append(f"| {distance:.0f} | {height:+.2f} | {max(lowest - height, 0.0):.2f} | "
                             f"{max(highest - height, 0.0):.2f} |")
    else:
        lines.append("No line: the start point is not on the land.")
    return "\n".join(lines) + "\n"
