"""The report of the bare earth (plan 0009, R5b): ground_report.md and its maps."""

from __future__ import annotations

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from . import bareearth
from .config import FONT

SUN = (315.0, 45.0)  # azimuth and altitude of the light of the hillshade (degrees)


def hillshade(heights: np.ndarray, step: float) -> np.ndarray:
    """A gray hillshade (0 to 1) with a tint of the height."""
    h = np.nan_to_num(heights.astype(np.float64), nan=0.0)
    dz_dx = np.gradient(h, step, axis=1)
    dz_dy = -np.gradient(h, step, axis=0)
    slope = np.arctan(np.hypot(dz_dx, dz_dy))
    aspect = np.arctan2(dz_dy, -dz_dx)
    az, alt = np.radians(360.0 - SUN[0] + 90.0), np.radians(SUN[1])
    shade = np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect)
    return np.clip(shade, 0.0, 1.0)


def _font(size: int):
    return ImageFont.truetype(str(FONT), size) if FONT.exists() else ImageFont.load_default()


def _tile(heights: np.ndarray, step: float, land: np.ndarray, low: float, high: float) -> Image.Image:
    shade = hillshade(heights, step)
    t = np.clip((np.nan_to_num(heights, nan=low) - low) / max(high - low, 1.0), 0.0, 1.0)
    # The height as a tint: green low, brown high; the sea blue.
    r = 0.35 + 0.45 * t
    g = 0.55 + 0.1 * (1 - t)
    b = 0.30 + 0.1 * t
    rgb = np.stack([r, g, b], axis=-1) * (0.35 + 0.65 * shade[..., None])
    rgb[~land] = (0.55, 0.72, 0.85)
    rgb[~np.isfinite(heights)] = (0.85, 0.85, 0.85)
    return Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))


def window(grid_shape, step: float, x0: float, z0: float, center, radius: float) -> tuple[slice, slice]:
    cc = int((center[0] - x0) / step)
    cr = int((center[1] - z0) / step)
    r = int(radius / step)
    return (slice(max(cr - r, 0), min(cr + r, grid_shape[0])), slice(max(cc - r, 0), min(cc + r, grid_shape[1])))


def draw_models(path, title: str, crops: dict, land: np.ndarray, step: float, size: int = 360) -> None:
    """The models side by side (a hillshade with a tint of the height)."""
    finite = np.concatenate([c[np.isfinite(c) & land].ravel() for c in crops.values()] or [np.zeros(1)])
    low, high = (float(np.percentile(finite, 2)), float(np.percentile(finite, 98))) if finite.size else (0.0, 1.0)
    pad, head = 8, 44
    image = Image.new("RGB", (pad + len(crops) * (size + pad), head + size + pad + 22), (30, 30, 30))
    pen = ImageDraw.Draw(image)
    pen.text((pad, 8), title, fill=(240, 240, 240), font=_font(18))
    for i, (name, crop) in enumerate(crops.items()):
        tile = _tile(crop, step, land, low, high).resize((size, size), Image.Resampling.LANCZOS)
        x = pad + i * (size + pad)
        image.paste(tile, (x, head))
        pen.text((x, head + size + 4), name, fill=(230, 230, 230), font=_font(14))
    image.save(path, optimize=True)


def draw_change(path, change: np.ndarray, land: np.ndarray, every: int, places: list) -> None:
    """The change of the ground: blue where the bare earth is lower than
    Copernicus, red where it is higher (full color at 8 m)."""
    c = change[::every, ::every]
    l = land[::every, ::every]
    t = np.clip(c / 8.0, -1.0, 1.0)
    rgb = np.ones(c.shape + (3,), dtype=np.float32) * 0.93
    rgb[..., 0] -= np.clip(-t, 0, 1) * 0.8
    rgb[..., 1] -= np.abs(t) * 0.6
    rgb[..., 2] -= np.clip(t, 0, 1) * 0.8
    rgb[~l] = (0.55, 0.72, 0.85)
    image = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
    pen = ImageDraw.Draw(image)
    for name, row, col in places:
        r, cl = row / every, col / every
        pen.ellipse((cl - 5, r - 5, cl + 5, r + 5), outline=(0, 0, 0), width=2)
        pen.text((cl + 8, r - 8), name, fill=(0, 0, 0), font=_font(13))
    image.save(path, optimize=True)


def _row(name: str, stats: dict) -> str:
    if not stats["n"]:
        return f"| {name} | 0 | | |"
    return f"| {name} | {stats['n']} | {stats['mean']:+.2f} | {stats['rmse']:.2f} |"


def report(result: dict, choice: dict, applied: dict, zone_names: list, hills: dict, model_names: dict,
           settings: dict, places: list, maps: dict) -> str:
    names = {bareearth.COPERNICUS: "Copernicus GLO-30"} | model_names
    lines = [
        "# The ground under the trees and the roofs (plan 0009, R5b)",
        "",
        "Made by `tools/geo/build.py` from `data/geo/ground.json`. Do not edit by hand.",
        "",
        f"- **The zero of the heights.** All the heights are over the mean sea level: the heights over EGM2008 "
        f"(Copernicus, GEDTM30, DeltaDTM, and the lidar) take away {settings['mdt']:.2f} m, the mean dynamic "
        f"topography of DTU22 at Bãi Trước (report 0009, D-0009-07). Before, the land was "
        f"{settings['mdt']:.2f} m too high against the sea of the tide.",
        f"- **The lidar ground.** {result['points']} bins of 20 m of the ATL03 ground photons of ICESat-2 "
        f"(`lidar_tracks.json`) on the land of the box.",
        f"- **The rule.** For each group (a hill or the low land, and a class of the land cover), the model with "
        f"the smallest RMSE against the lidar ground. A group with fewer than {settings['min_points']} lidar points "
        f"keeps Copernicus. The build uses the model where it differs from Copernicus by more than "
        f"{settings['min_difference_m']:.1f} m on average (the mean over {settings['difference_mean_m']:.0f} m), "
        f"with a smooth change to Copernicus over {settings['blend_m']:.0f} m at the edge. The sea of the coastline "
        "(below the line of the high water) keeps the heights of plan 0005 (R8g).",
        "",
        "## The models against the lidar ground",
        "",
        "The difference is the model minus the lidar (m).",
        "",
    ]
    for title, key, keys in (("By land cover", "class", list(bareearth.CLASSES)),
                             ("By hill", "zone", zone_names)):
        lines += [f"### {title}", ""]
        for name in result["by_model"]:
            lines += [f"**{names.get(name, name)}**", "", "| Part | Points | Mean | RMSE |", "|---|---:|---:|---:|"]
            for k in keys:
                label = bareearth.CLASS_NAMES.get(k) or hills.get(k, {}).get("name") or "the low land"
                lines.append(_row(label, result["by_model"][name][key][k]))
            lines.append(_row("all", result["by_model"][name]["all"]))
            lines.append("")
    lines += ["## The model of each group", "", "| Group | Points | Copernicus RMSE | GEDTM30 RMSE | DeltaDTM RMSE | Model | Why |",
              "|---|---:|---:|---:|---:|---|---|"]
    for group, chosen in choice.items():
        zone, klass = group.split("/")
        label = f"{hills.get(zone, {}).get('name', 'the low land')}, {bareearth.CLASS_NAMES[klass]}"

        def rmse(model):
            g = result["by_model"].get(model, {}).get("group", {}).get(group)
            return f"{g['rmse']:.2f}" if g and g["rmse"] is not None else ""
        n = result["by_model"][bareearth.COPERNICUS]["group"][group]["n"]
        lines.append(f"| {label} | {n} | {rmse('copernicus')} | {rmse('gedtm30')} | {rmse('deltadtm')} | "
                     f"{names.get(chosen['model'], chosen['model'])} | {chosen['why']} |")
    numbers = applied["numbers"]
    lines += ["", "## The change", ""]
    for name, n in numbers["models"].items():
        if n.get("cells"):
            lines.append(f"- {names.get(name, name)}: {n['area_ha']} ha, a mean change of {n['mean_change_m']:+.2f} m.")
        else:
            lines.append(f"- {names.get(name, name)}: no part differs from Copernicus by more than the limit.")
    lines += [f"- All: {numbers['changed_ha']} ha change by more than 0.05 m (a mean of {numbers['mean_change_m']:+.2f} m); "
              f"the most lowered cell {numbers['largest_lowering_m']:.2f} m, the most raised {numbers['largest_raising_m']:.2f} m.",
              "", f"![The change of the ground]({maps['change']})", "",
              "Blue: the bare earth is lower than Copernicus; red: higher (full color at 8 m).", "",
              "## The places", "",
              "The mean height of the land in a circle of the place (m): Copernicus over EGM2008 (the ground before "
              "plan 0009, with no roads and no levels), the same over the mean sea level, and the ground of the game "
              "now (the bare earth, then the roads, the levels of the places, and the showcase), over the mean sea level.", "",
              "| Place | Copernicus over EGM2008 | Copernicus over the mean sea level | The ground of the game | Change |",
              "|---|---:|---:|---:|---:|"]
    for p in places:
        lines.append(f"| {p['name']} | {p['before_egm']:.2f} | {p['before_msl']:.2f} | {p['after']:.2f} | "
                     f"{p['after'] - p['before_egm']:+.2f} |")
    lines += ["", "## Bãi Trước and Núi Nhỏ, each model", ""]
    for key in ("bai_truoc", "nui_nho"):
        if key in maps:
            lines += [f"![{key}]({maps[key]})", ""]
    return "\n".join(lines) + "\n"


# The town profile counts the land more than this from the sea (m).
SHORE_M = 30.0


def town_profile(grid, before: np.ndarray, config: dict, point, land: np.ndarray | None = None) -> dict:
    """Report 0009, D-0009-20: a profile of the ground of the town from west to
    east, north_m north of a landmark, length_m long: the filter of plans 0005
    to 0026 (before) and the filter now (after, with the bare earth). The
    numbers are for the land more than SHORE_M from the sea (land: the land
    mask of the grid): the bank at the coastline is not a step of the town."""
    x0, y0 = point
    y = y0 + float(config["north_m"])
    xs = np.arange(x0 - config["length_m"] / 2.0, x0 + config["length_m"] / 2.0, grid.step)
    zs = np.full_like(xs, -y)
    after = grid.sample(xs, zs)
    copy = type(grid)(grid.x0, grid.z0, grid.step, before.astype(np.float32))
    old = copy.sample(xs, zs)

    inland = np.ones(len(xs) - 1, dtype=bool)
    if land is not None:
        from scipy import ndimage
        far = ndimage.distance_transform_edt(land) * grid.step > SHORE_M
        rows = np.clip(np.round((zs - grid.z0) / grid.step).astype(int), 0, land.shape[0] - 1)
        cols = np.clip(np.round((xs - grid.x0) / grid.step).astype(int), 0, land.shape[1] - 1)
        cell = far[rows, cols]
        inland = cell[:-1] & cell[1:]

    def flat(values):
        return float((np.abs(np.diff(values))[inland] < 0.005).mean())

    def largest_step(values):
        return float(np.abs(np.diff(values))[inland].max())
    return {"config": config, "x": xs, "z": float(-y), "before": old, "after": after,
            "flat_before": flat(old), "flat_after": flat(after),
            "step_before": largest_step(old), "step_after": largest_step(after)}


def write_town_profile(out, profile: dict) -> None:
    """The picture of the profile (town_profile.png) and its part of ground_report.md."""
    from PIL import Image, ImageDraw
    width, height, pad = 900, 300, 30
    values = np.concatenate([profile["before"], profile["after"]])
    low, high = float(values.min()) - 0.5, float(values.max()) + 0.5
    image = Image.new("RGB", (width, height), (250, 250, 250))
    draw = ImageDraw.Draw(image)
    n = len(profile["x"])
    for key, color in (("before", (200, 40, 40)), ("after", (30, 90, 200))):
        points = [(pad + i * (width - 2 * pad) / max(n - 1, 1),
                   height - pad - (v - low) / (high - low) * (height - 2 * pad)) for i, v in enumerate(profile[key])]
        draw.line(points, fill=color, width=2)
    draw.text((pad, 6), f"Red: before (a square window). Blue: after (the bare earth, and a round window). "
                        f"{low:.1f} m to {high:.1f} m, {profile['config']['length_m']:.0f} m across", fill=(0, 0, 0))
    image.save(out / "town_profile.png")
    (out / "town_profile.png.import").write_text("[remap]\n\nimporter=\"keep\"\n", encoding="utf-8")
    c = profile["config"]
    text = ["", "## The profile of the town (report 0009, D-0009-20)", "",
            f"A line of {c['length_m']:.0f} m from west to east, {c['north_m']:.0f} m north of {c['name']} "
            f"(game z {profile['z']:.0f}). Before, the filter of the buildings of plans 0005 to 0026 opened the "
            "ground with a flat square window: it cut each hump of the ground into a flat square, with steps "
            "between the squares. Now the filter does not change the bare earth (GEDTM30 and DeltaDTM have no "
            "buildings), and elsewhere it opens with a flat round window: a slope of the ground stays, a bank "
            "keeps its edge, and a hump smaller than the window gets a round flat top.", "",
            f"The numbers are for the land more than {SHORE_M:.0f} m from the sea.", "",
            "| | Before | After |", "|---|---:|---:|",
            f"| Cells flat to 5 mm with the next cell | {profile['flat_before'] * 100:.0f} % | {profile['flat_after'] * 100:.0f} % |",
            f"| The largest step between two cells (m) | {profile['step_before']:.2f} | {profile['step_after']:.2f} |",
            "", "![town profile](town_profile.png)", ""]
    with open(out / "ground_report.md", "a", encoding="utf-8") as f:
        f.write("\n".join(text))
