"""The views of the known places of plan 0008 (D4, R8): rays from an eye to the
top of a place against the ground of the DEM. The game makes the same rays
against its own ground (PT-60), and the two results must agree."""

import math


def eye_points(config: dict, found_by_id: dict, roads, ground) -> dict:
    """The eye of each view of data/geo/place_views.json: [x, y, z] in game
    coordinates. "ground(x, z)" gives the height of the DEM."""
    result = {}
    for eye in config.get("eyes", []):
        record = found_by_id.get(eye["landmark"])
        if not record or not record.get("found"):
            continue
        x, z = record["position"]
        if eye.get("side") == "south" and record.get("outline"):
            # The south end of the outline (game +z), moved inset_m to the middle.
            sx, sz = max(record["outline"], key=lambda p: p[1])
            dx, dz = x - sx, z - sz
            length = math.hypot(dx, dz) or 1.0
            inset = min(float(eye.get("inset_m", 0.0)), length)
            x, z = sx + dx / length * inset, sz + dz / length * inset
        if eye.get("out_m"):
            # Toward the sea: away from the nearest point of the road.
            nearest = None
            for road in roads:
                if road.name != eye.get("away_from_road"):
                    continue
                for px, py in road.points:
                    d = math.hypot(px - x, -py - z)
                    if nearest is None or d < nearest[0]:
                        nearest = (d, px, -py)
            if nearest:
                dx, dz = x - nearest[1], z - nearest[2]
                length = math.hypot(dx, dz) or 1.0
                x, z = x + dx / length * float(eye["out_m"]), z + dz / length * float(eye["out_m"])
        base = max(ground(x, z), 0.0)
        result[eye["id"]] = [round(x, 2), round(base + float(eye.get("height_m", 1.6)), 2), round(z, 2)]
    return result


def seen_part(eye, target_base, top_m: float, ground, samples: int = 10, step_m: float = 1.0) -> float:
    """The part of the points from the ground of the target to its top that the
    eye sees: a ray to each point, blocked where the ground is higher than the
    ray. The last 3 m of each ray (the ground of the place) do not block."""
    seen = 0
    for i in range(samples):
        h = top_m * (i + 1) / samples
        tx, ty, tz = target_base[0], target_base[1] + h, target_base[2]
        length = math.dist((eye[0], eye[2]), (tx, tz))
        n = max(1, int(length / step_m))
        blocked = False
        for k in range(1, n):
            t = k / n
            if length * (1.0 - t) < 3.0:
                break
            x = eye[0] + (tx - eye[0]) * t
            z = eye[2] + (tz - eye[2]) * t
            y = eye[1] + (ty - eye[1]) * t
            if ground(x, z) > y:
                blocked = True
                break
        if not blocked:
            seen += 1
    return seen / samples


def views(config: dict, found_by_id: dict, roads, ground) -> dict:
    """The result for data/geo/build/place_views.json."""
    eyes = eye_points(config, found_by_id, roads, ground)
    samples = int(config.get("samples", 10))
    step = float(config.get("step_m", 1.0))
    results = []
    for eye_id, eye in eyes.items():
        for target in config.get("targets", []):
            record = found_by_id.get(target["place"])
            if not record or not record.get("found"):
                continue
            x, z = record["position"]
            base = [x, ground(x, z), z]
            part = seen_part(eye, base, float(target["top_m"]), ground, samples, step)
            results.append({"eye": eye_id, "place": target["place"], "top_m": target["top_m"],
                            "target": [round(base[0], 2), round(base[1], 2), round(base[2], 2)],
                            "seen": round(part, 2)})
    return {"note": "Made by tools/geo/build.py from data/geo/place_views.json (plan 0008, R8). Do not change by hand.",
            "samples": samples, "step_m": step, "eyes": eyes, "results": results}
