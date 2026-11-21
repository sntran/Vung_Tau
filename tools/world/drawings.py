#!/usr/bin/env python3
"""The models that this game makes with the tools of World (docs/world-models.md).

    python tools/world/drawings.py check                 # the files, with no network (CI)
    python tools/world/drawings.py check --factory ID    # also the check of World (check_order)
    python tools/world/drawings.py place ID              # keep the order on the factory: its hash
    python tools/world/drawings.py look ID --level mid   # the level next to the photos: build/look/ID_mid.png
    python tools/world/drawings.py look ID --lock        # the same with the files of the lock (assets/world/):
                                                         # a model that the job "Models of World" built
    python tools/world/drawings.py sync [ID ...]         # put the order of each drawing (or of these) in data/world/orders.json

A file data/world/drawings/ID.json has:

- "id": the id of the model in data/world/orders.json;
- "what": what the thing is;
- "way": "order" (a blueprint of World with the numbers of this game),
  "remix" (an order with {"free": true} and edits), "drawing" (a sculpture
  from edits) or "blueprint" (an order of a blueprint in data of
  data/world/blueprints/);
- "order": the order of World;
- "sources": the photos, each with "url", "date", "license", "author",
  "open", "file" (the copy in docs/reference/photos/ for an open photo) and
  "shows";
- "sizes": each size with its "value", its "unit" and its "source" (how it
  was measured, from which photo), or the source "estimate (no source)";
- "looks": each review of a level next to the photos (its date, its hash,
  its level, and what was changed after it);
- "status": "Source", or "Check" when a size or a look has no photo of 2017
  to 2021 (the game does not use the model);
- "levels", "uses", "impostor": as in data/world/orders.json.
"""

from __future__ import annotations

import argparse
import gzip
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DRAWINGS = ROOT / "data" / "world" / "drawings"
BLUEPRINTS = ROOT / "data" / "world" / "blueprints"
ORDERS = ROOT / "data" / "world" / "orders.json"
PHOTOS = ROOT / "docs" / "reference" / "photos"
LOOK = ROOT / "build" / "look"
FACTORY = os.environ.get("WORLD_FACTORY", "https://world.mkfifo.com")
AGENT = "vung-tau-tools/1"
WAYS = ("order", "remix", "drawing", "blueprint")
STATUS = ("Source", "Check")
ESTIMATE = "estimate (no source)"
OPEN = ("CC0", "CC BY", "CC BY-SA", "public domain")


# --- The files -----------------------------------------------------------------

def load(model_id: str) -> dict:
    return json.loads((DRAWINGS / f"{model_id}.json").read_text(encoding="utf-8"))


def save(drawing: dict) -> None:
    path = DRAWINGS / f"{drawing['id']}.json"
    path.write_text(json.dumps(drawing, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


def all_ids() -> list[str]:
    return sorted(p.stem for p in DRAWINGS.glob("*.json"))


def _tiny_numbers(value, path: list) -> list:
    """The numbers of a value that are not 0 and less than 0.001 (with their paths)."""
    if isinstance(value, dict):
        return [found for key, item in value.items() for found in _tiny_numbers(item, path + [key])]
    if isinstance(value, list):
        return [found for i, item in enumerate(value) for found in _tiny_numbers(item, path + [i])]
    if isinstance(value, float) and value != 0.0 and abs(value) < 0.001:
        return [("/".join(str(p) for p in path), value)]
    return []


def problems(drawing: dict, model_id: str) -> list[str]:
    """The problems of the file of a drawing, with no network."""
    found = []
    for key in ("id", "what", "way", "order", "sources", "sizes", "status", "levels", "uses"):
        if key not in drawing:
            found.append(f"{model_id}: no \"{key}\"")
    if drawing.get("id") != model_id:
        found.append(f"{model_id}: the id is not the name of the file")
    if drawing.get("way") not in WAYS:
        found.append(f"{model_id}: the way is not one of {', '.join(WAYS)}")
    if drawing.get("status") not in STATUS:
        found.append(f"{model_id}: the status is not one of {', '.join(STATUS)}")
    for path, number in _tiny_numbers(drawing.get("order", {}), []):
        # World writes such a number with an exponent ("-4.84e-4") when it
        # takes the hash of the order, and this game without one: the hash of
        # the receipt was not the hash of its order (cao_oc_sen_bien, 2026-11-17).
        found.append(f"{model_id}: the order has {number} at {path}: use 0 or a number of 0.001 or more")
    order = drawing.get("order", {})
    if not isinstance(order, dict) or "blueprint" not in order:
        found.append(f"{model_id}: the order has no blueprint")
    if drawing.get("way") == "blueprint":
        name = order.get("blueprint", {}).get("file", "") if isinstance(order.get("blueprint"), dict) else ""
        if not name or not (ROOT / name).exists():
            found.append(f"{model_id}: an order of a blueprint in data names its file (\"blueprint\": {{\"file\": ...}})")
    sources = drawing.get("sources", [])
    if not sources and drawing.get("status") == "Source":
        found.append(f"{model_id}: no photo, so the status is Check")
    for i, photo in enumerate(sources):
        for key in ("url", "date", "license", "author", "shows"):
            if not photo.get(key):
                found.append(f"{model_id}: sources.{i} has no \"{key}\"")
        if photo.get("open") and not (PHOTOS / str(photo.get("file", ""))).is_file():
            found.append(f"{model_id}: sources.{i} is open, but docs/reference/photos/{photo.get('file')} is not there")
    for name, size in drawing.get("sizes", {}).items():
        if not isinstance(size, dict) or "value" not in size or not size.get("source"):
            found.append(f"{model_id}: sizes.{name} needs a value and a source (or \"{ESTIMATE}\")")
    for key in ("levels",):
        if not set(drawing.get(key, [])) <= {"near", "mid", "far"} or not drawing.get(key):
            found.append(f"{model_id}: levels must be some of near, mid, far")
    return found


# The words of a "status_note" that say why a drawing with the status Source is
# not in the game (report 0026, D-0026-27: cay_thong_noel).
NOT_IN_THE_GAME = "Not in the game"


def order_problems(ids: list[str]) -> list[str]:
    """The drawings with the status Source whose order is not in data/world/orders.json as it is,
    and the drawings with the status Source with no order there, unless the "status_note" starts
    with NOT_IN_THE_GAME and says why (report 0026, D-0026-27)."""
    orders = {m["id"]: m for m in json.loads(ORDERS.read_text(encoding="utf-8"))["models"]}
    found = []
    for model_id in ids:
        drawing = load(model_id)
        if drawing.get("status") == "Source" and model_id not in orders \
                and not str(drawing.get("status_note", "")).startswith(NOT_IN_THE_GAME):
            found.append(f"{model_id}: the status is Source, but the order is not in data/world/orders.json "
                         f"(run sync), and the status_note does not start with \"{NOT_IN_THE_GAME}\" and say why")
        if drawing.get("status") == "Source" and model_id in orders and orders[model_id].get("order") != full_order(drawing):
            found.append(f"{model_id}: the order in data/world/orders.json is not the order of the drawing (run sync)")
        if drawing.get("status") == "Check" and model_id in orders:
            found.append(f"{model_id}: the status is Check, but the order is in data/world/orders.json (run sync)")
    return found


def full_order(drawing: dict) -> dict:
    """The order for World: a blueprint in data goes into the order itself."""
    order = json.loads(json.dumps(drawing["order"]))
    blueprint = order.get("blueprint")
    if isinstance(blueprint, dict) and "file" in blueprint:
        order["blueprint"] = json.loads((ROOT / blueprint["file"]).read_text(encoding="utf-8"))
    return order


# --- The factory ---------------------------------------------------------------

def _request(path: str, body: dict | None = None, timeout: float = 600.0, tries: int = 4) -> bytes:
    data = None if body is None else json.dumps(body).encode("utf-8")
    headers = {"user-agent": AGENT, "accept-encoding": "gzip"}
    if data is not None:
        headers["content-type"] = "application/json"
        headers["accept"] = "application/json"
    for attempt in range(tries):
        req = urllib.request.Request(FACTORY + path, data=data, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as response:
                raw = response.read()
                return gzip.decompress(raw) if response.headers.get("content-encoding") == "gzip" else raw
        except urllib.error.HTTPError as error:
            if error.code in (502, 503, 504) and attempt < tries - 1:
                time.sleep(10 * (attempt + 1))
                continue
            text = error.read()
            raise SystemExit(f"{path}: HTTP {error.code}: {text[:2000].decode('utf-8', 'replace')}")
    raise SystemExit(f"{path}: no answer")


def tool(name: str, arguments: dict) -> dict:
    """A tool of the MCP server of World: its data, or an exit with its errors."""
    answer = json.loads(_request("/mcp", {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                                          "params": {"name": name, "arguments": arguments}}, timeout=300))
    if "error" in answer:
        raise SystemExit(f"{name}: {answer['error']}")
    result = answer["result"]
    data = result.get("structuredContent") or json.loads(result["content"][0]["text"])
    if result.get("isError"):
        raise SystemExit(f"{name}: " + json.dumps(data, ensure_ascii=False, indent=1)[:6000])
    return data


def check(drawing: dict) -> dict:
    return tool("check_order", {"order": full_order(drawing)})


def place(drawing: dict) -> dict:
    return json.loads(_request("/orders", full_order(drawing), timeout=300))


def fetch_level(order_hash: str, level: str, out: Path) -> Path:
    suffix = {"near": ".glb", "mid": ".mid.glb", "far": ".far.glb"}[level]
    out.mkdir(parents=True, exist_ok=True)
    path = out / f"{order_hash}{suffix}"
    if not path.exists():
        path.write_bytes(_request(f"/o/{order_hash}{suffix}", timeout=1800))
    return path


# --- The look ------------------------------------------------------------------

def render(glbs: list[Path], out: Path) -> None:
    godot = os.environ.get("GODOT", str(ROOT / ".tools" / "godot" / "godot"))
    command = ["xvfb-run", "-a", "-s", "-screen 0 1024x1024x24", godot, "--path", str(ROOT),
               "--rendering-driver", "vulkan", "--rendering-method", "mobile", "--audio-driver", "Dummy",
               "--resolution", "640x640", "-s", "res://tools/world/look.gd", "--", str(out)] + [str(g) for g in glbs]
    subprocess.run(command, check=True, timeout=900, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def sheet(drawing: dict, views: dict[str, Path], out: Path, other_photos: Path | None) -> Path:
    """The views of a level in a row, the photos in the row under it, and the sizes."""
    from PIL import Image, ImageDraw

    cell = 400
    photos = []
    for photo in drawing.get("sources", []):
        path = PHOTOS / str(photo.get("file", "")) if photo.get("open") else None
        if (path is None or not path.is_file()) and other_photos is not None:
            path = other_photos / str(photo.get("file", ""))
        if path is not None and path.is_file():
            photos.append(Image.open(path).convert("RGB"))
    columns = max(len(views), min(len(photos), 4), 1)
    rows = 1 + (len(photos) + columns - 1) // columns if photos else 1
    text_h = 22 * (len(drawing.get("sizes", {})) + 3)
    page = Image.new("RGB", (columns * cell, rows * cell + text_h), "#202124")
    pen = ImageDraw.Draw(page)
    for i, (name, path) in enumerate(views.items()):
        image = Image.open(path).convert("RGB")
        image.thumbnail((cell, cell))
        page.paste(image, (i * cell, 0))
        pen.text((i * cell + 6, 6), name, fill="#ffffff")
    for i, image in enumerate(photos):
        image.thumbnail((cell, cell))
        page.paste(image, ((i % columns) * cell, (1 + i // columns) * cell))
    y = rows * cell + 6
    pen.text((6, y), f"{drawing['id']} ({drawing['way']}, {drawing['status']}): {drawing['what'][:140]}", fill="#ffffff")
    for name, size in drawing.get("sizes", {}).items():
        y += 22
        pen.text((6, y), f"{name}: {size.get('value')} {size.get('unit', '')}  {str(size.get('source'))[:150]}", fill="#d0d0d0")
    out.parent.mkdir(parents=True, exist_ok=True)
    page.save(out)
    return out


# --- The commands --------------------------------------------------------------

def command_check(args) -> int:
    ids = args.ids or all_ids()
    found = []
    for model_id in ids:
        drawing = load(model_id)
        found += problems(drawing, model_id)
        if args.factory and not found:
            data = check(drawing)
            print(f"{model_id}: World checks the order: {data.get('hash', '')}")
    found += order_problems(ids)
    for line in found:
        print(line)
    print(f"{len(ids)} drawings, {len(found)} problems.")
    return 1 if found else 0


def command_place(args) -> int:
    drawing = load(args.id)
    for line in problems(drawing, args.id):
        print(line)
    answer = place(drawing)
    drawing["hash"] = answer["hash"]
    save(drawing)
    print(json.dumps({"hash": answer["hash"], "files": answer.get("files", answer.get("urls"))}, indent=1)[:1500])
    return 0


def lock_level(model_id: str, level: str, out: Path) -> tuple[str, Path]:
    """The hash of the order of the model in data/world/lock.json and a copy of
    the file of the level in assets/world/ (the files that the game uses)."""
    lock = json.loads((ROOT / "data" / "world" / "lock.json").read_text(encoding="utf-8"))
    entry = lock["models"].get(model_id)
    if entry is None:
        raise SystemExit(f"{model_id}: not in data/world/lock.json")
    suffix = {"near": ".glb", "mid": ".mid.glb", "far": ".far.glb"}[level]
    source = ROOT / "assets" / "world" / f"{model_id}{suffix}"
    if not source.exists():
        raise SystemExit(f"{model_id}: no file {source.relative_to(ROOT)} (run tools/world/fetch.py)")
    out.mkdir(parents=True, exist_ok=True)
    path = out / f"{entry['hash']}{suffix}"
    path.write_bytes(source.read_bytes())
    return entry["hash"], path


def command_look(args) -> int:
    drawing = load(args.id)
    work = LOOK / args.id
    if args.world:
        # Report 0026, audit 6: mix world.order in a clone of World (CI), for an
        # order that the factory cannot build and that is not an order of the game.
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import fetch
        model = {"id": args.id, "order": full_order(drawing), "levels": [args.level]}
        files = fetch.checkout_files(model, Path(args.world), args.mix)
        work.mkdir(parents=True, exist_ok=True)
        suffix = {"near": ".glb", "mid": ".mid.glb", "far": ".far.glb"}[args.level]
        glb = work / f"{args.id}{suffix}"
        glb.write_bytes(files[args.id + suffix])
        order_hash = json.loads(files[args.id + ".receipt.json"]).get("hash", "")
    elif args.lock:
        order_hash, glb = lock_level(args.id, args.level, work)
        if drawing.get("hash") and drawing["hash"] != order_hash:
            print(f"{args.id}: the lock has the order {order_hash}, the drawing {drawing['hash']}")
    else:
        order_hash = args.hash or drawing.get("hash")
        if not order_hash:
            order_hash = place(drawing)["hash"]
            drawing["hash"] = order_hash
            save(drawing)
        glb = fetch_level(order_hash, args.level, work)
    render([glb], work)
    stem = glb.name.replace(".glb", "").replace(".", "_")
    views = {v: work / f"{stem}_{v}.png" for v in ("front", "side", "three_quarters", "above")}
    out = sheet(drawing, views, LOOK / f"{args.id}_{args.level}.png", Path(args.other) if args.other else None)
    print(f"{out} ({order_hash}, {args.level}, {glb.stat().st_size // 1024} KB)")
    return 0


def command_sync(args) -> int:
    data = json.loads(ORDERS.read_text(encoding="utf-8"))
    models = data["models"]
    by_id = {m["id"]: m for m in models}
    for model_id in args.ids or all_ids():
        drawing = load(model_id)
        if drawing.get("status") != "Source":
            if model_id in by_id:
                models.remove(by_id.pop(model_id))
                print(f"{model_id}: Check, out of the orders")
            continue
        entry = by_id.get(model_id)
        if entry is None:
            entry = {"id": model_id}
            models.append(entry)
            by_id[model_id] = entry
        entry["order"] = full_order(drawing)
        entry["levels"] = drawing["levels"]
        entry["impostor"] = bool(drawing.get("impostor", False))
        entry["uses"] = drawing["uses"]
        entry["drawing"] = f"data/world/drawings/{model_id}.json"
        entry.setdefault("catalog", None)
    ORDERS.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    print(f"{len(models)} orders in {ORDERS.relative_to(ROOT)}.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("check")
    p.add_argument("ids", nargs="*")
    p.add_argument("--factory", action="store_true", help="also the check of World (network)")
    p.set_defaults(run=command_check)
    p = sub.add_parser("place")
    p.add_argument("id")
    p.set_defaults(run=command_place)
    p = sub.add_parser("look")
    p.add_argument("id")
    p.add_argument("--level", default="mid", choices=("near", "mid", "far"))
    p.add_argument("--hash")
    p.add_argument("--other", help="a folder with the photos that are not open (tools/photos/photos.py --other)")
    p.add_argument("--lock", action="store_true", help="the files of the lock (assets/world/), not of the factory")
    p.add_argument("--world", help="a clone of World: build the order with --mix there (CI), not at the factory")
    p.add_argument("--mix", help="the command of mix in the clone (with --world)")
    p.set_defaults(run=command_look)
    p = sub.add_parser("sync")
    p.add_argument("ids", nargs="*")
    p.set_defaults(run=command_sync)
    args = parser.parse_args()
    return args.run(args)


if __name__ == "__main__":
    sys.exit(main())
