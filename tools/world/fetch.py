#!/usr/bin/env python3
"""Gets the files of the orders of World to assets/world/ (plan 0023, R2, R3).

    python tools/world/fetch.py --source=checkout --world=PATH   # the files that are not there
    python tools/world/fetch.py --source=factory
    python tools/world/fetch.py --check                          # no network: the files agree with the lock
    python tools/world/fetch.py --update --source=factory        # all files again, from the newest World

The sources:

- factory: POST /orders on https://world.mkfifo.com, then /o/HASH.*.
  The factory has the newest World (/version.json). Without --update, its
  commit must be the commit of the lock.
- checkout: a clone of World at the commit of the lock. A catalog order
  with no colors, no joints, and no targets is a copy of priv/models, with
  no build. Another order needs `mix world.order` in the clone: give the
  command with --mix (CI only, because the workspace cannot get the
  packages of Hex).

The lock (data/world/lock.json) has the commit of World and, for each id,
the hash of the order and the SHA-256 of each file.
"""

from __future__ import annotations

import argparse
import http.client
import json
import re
import shlex
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import worldfiles as wf  # noqa: E402

FACTORY = "https://world.mkfifo.com"
LEVEL_FILES = {"near": "glb", "mid": "mid.glb", "far": "far.glb"}


class FetchError(Exception):
    pass


# --- The factory -------------------------------------------------------------------


def _http(url: str, body: bytes | None = None, timeout: float = 600.0, tries: int = 3) -> bytes:
    # The builder of the factory can stop for a moment (503), and the factory
    # can close a connection in the middle of a file: try again.
    for attempt in range(tries):
        try:
            return _http_once(url, body, timeout)
        except FetchError as error:
            if "HTTP 503" not in str(error) or attempt == tries - 1:
                raise
        except (ConnectionError, TimeoutError, http.client.HTTPException) as error:
            if attempt == tries - 1:
                raise FetchError(f"{url}: {error}") from error
        time.sleep(5.0 * (attempt + 1))
    raise FetchError(f"{url}: no answer")


def _http_once(url: str, body: bytes | None, timeout: float) -> bytes:
    headers = {"User-Agent": "vung-tau-fetch/1", "Accept": "*/*"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=body, headers=headers, method="POST" if body is not None else "GET")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")[:2000]
        raise FetchError(f"{url}: HTTP {error.code}: {detail}") from error
    except urllib.error.URLError as error:
        raise FetchError(f"{url}: {error.reason}") from error


def factory_commit(base: str = FACTORY) -> str:
    data = json.loads(_http(f"{base}/version.json", timeout=30.0))
    commit = data.get("commit") or data.get("version")
    if not commit:
        raise FetchError(f"{base}/version.json has no commit: {data}")
    return str(commit)


def factory_files(model: dict, base: str = FACTORY) -> dict[str, bytes]:
    """The files of an order from the factory, by their names in assets/world/."""
    placed = json.loads(_http(f"{base}/orders", json.dumps(model["order"]).encode("utf-8")))
    hash_ = placed["hash"]
    files: dict[str, bytes] = {}
    for level, suffix in wf.LEVEL_SUFFIX.items():
        if level in model["levels"]:
            files[model["id"] + suffix] = _http(f"{base}/o/{hash_}.{LEVEL_FILES[level]}")
    files[model["id"] + ".parts.json"] = _http(f"{base}/o/{hash_}.parts.json")
    files[model["id"] + ".receipt.json"] = _http(f"{base}/o/{hash_}.receipt.json")
    return files


# --- A clone of World ----------------------------------------------------------------


def clone_commit(clone: Path) -> str:
    result = subprocess.run(["git", "-C", str(clone), "rev-parse", "HEAD"], capture_output=True, text=True)
    if result.returncode != 0:
        raise FetchError(f"{clone} is not a clone of World: {result.stderr.strip()}")
    return result.stdout.strip()


def checkout_files(model: dict, clone: Path, mix: str | None) -> dict[str, bytes]:
    """The files of an order from a clone of World, by their names in assets/world/."""
    order = model["order"]
    files: dict[str, bytes] = {}
    if wf.is_catalog_copy(order):
        name = order["options"]["name"]
        source = clone / "priv" / "models"
        for level, suffix in wf.LEVEL_SUFFIX.items():
            path = source / (name + suffix)
            if not path.exists():
                raise FetchError(f"{model['id']}: {path} is not in the clone: is {name} a model of the catalog?")
            if level in model["levels"]:
                files[model["id"] + suffix] = path.read_bytes()
        files[model["id"] + ".parts.json"] = (source / (name + ".parts.json")).read_bytes()
        full = wf.full_order(order)
        # The receipt has the values of the near level, also for a model with no near level.
        near = (source / (name + ".glb")).read_bytes()
        files[model["id"] + ".receipt.json"] = wf.receipt(full, near, wf.world_version(clone)).encode("utf-8")
        return files
    if not mix:
        raise FetchError(
            f"{model['id']}: the order is not a model of the catalog with no colors, joints, or targets. "
            "It needs `mix world.order` (give --mix=COMMAND, in CI only)."
        )
    with tempfile.TemporaryDirectory() as tmp:
        order_path = Path(tmp) / "order.json"
        order_path.write_text(json.dumps(order), encoding="utf-8")
        out = Path(tmp) / "out"
        command = shlex.split(mix) + ["world.order", str(order_path), "--dir", str(out)]
        result = subprocess.run(command, cwd=clone, capture_output=True, text=True)
        if result.returncode != 0:
            raise FetchError(f"{model['id']}: {' '.join(command)} failed:\n{result.stdout}\n{result.stderr}")
        receipts = list(out.glob("*.receipt.json"))
        if len(receipts) != 1:
            raise FetchError(f"{model['id']}: mix world.order wrote {len(receipts)} receipts")
        hash_ = receipts[0].name.split(".")[0]
        for level, suffix in wf.LEVEL_SUFFIX.items():
            if level in model["levels"]:
                files[model["id"] + suffix] = (out / (hash_ + suffix)).read_bytes()
        files[model["id"] + ".parts.json"] = (out / f"{hash_}.parts.json").read_bytes()
        files[model["id"] + ".receipt.json"] = receipts[0].read_bytes()
    return files


# --- The run -------------------------------------------------------------------------


## The import settings of each GLB of World (R5): World gives the levels, so
## Godot makes no LODs and no shadow meshes. The node names stay (the joints
## of World are nodes, and a name such as "front_wheel" must not become a
## VehicleWheel3D), and the animations import (the routines of people).
IMPORT_PARAMS = {
    "meshes/generate_lods": "false",
    "meshes/create_shadow_meshes": "false",
    "nodes/use_name_suffixes": "false",
    "animation/import": "true",
    # The textures of people stay in the imported scene: an extracted picture
    # is a file of Godot in assets/world/, not a file of World.
    "gltf/embedded_image_handling": "3",
}


def write_import(path: Path) -> None:
    """Writes or corrects the .import file of a GLB with IMPORT_PARAMS."""
    import_path = path.with_name(path.name + ".import")
    if not import_path.exists():
        lines = ["[remap]", "", 'importer="scene"', "importer_version=1", "", "[params]", ""]
        lines += [f"{key}={value}" for key, value in IMPORT_PARAMS.items()]
        import_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return
    text = import_path.read_text(encoding="utf-8")
    for key, value in IMPORT_PARAMS.items():
        if f"\n{key}=" in text:
            text = re.sub(rf"(?m)^{re.escape(key)}=.*$", f"{key}={value}", text)
        else:
            text = text.replace("[params]\n", f"[params]\n\n{key}={value}\n", 1)
    import_path.write_text(text, encoding="utf-8")


def _needs(model: dict, entry: dict | None, assets: Path) -> bool:
    if entry is None:
        return True
    names = wf.file_names(model)
    if sorted(entry.get("files", {})) != sorted(names):
        return True
    for name in names:
        path = assets / name
        if not path.exists() or wf.sha256(path.read_bytes()) != entry["files"][name]:
            return True
    receipt = json.loads((assets / f"{model['id']}.receipt.json").read_text(encoding="utf-8"))
    return not wf.agrees(model["order"], receipt.get("order", {}))


def run(args: argparse.Namespace) -> int:
    models = wf.load_orders(Path(args.orders))
    lock = wf.load_lock(Path(args.lock))
    assets = Path(args.assets)
    if args.only:
        chosen = [m for m in models if m["id"] in args.only]
        missing = set(args.only) - {m["id"] for m in chosen}
        if missing:
            raise FetchError(f"no model {sorted(missing)} in orders.json")
    else:
        chosen = models

    if args.check:
        problems = wf.check(models, lock, assets)
        for problem in problems:
            print(f"ERROR: {problem}")
        if problems:
            print("Run tools/world/fetch.py to get the files again.")
            return 1
        print(f"The {len(models)} models of World agree with the lock (commit {lock['world']['commit']}).")
        return 0

    if args.source == "factory":
        commit = factory_commit(args.factory)
        get = lambda m: factory_files(m, args.factory)  # noqa: E731
    elif args.source == "checkout":
        if not args.world:
            raise FetchError("--source=checkout needs --world=PATH, a clone of World")
        clone = Path(args.world).resolve()
        commit = clone_commit(clone)
        get = lambda m: checkout_files(m, clone, args.mix)  # noqa: E731
    else:
        raise FetchError("give --source=factory or --source=checkout")

    locked = lock.get("world", {}).get("commit")
    if args.update or not locked:
        lock["world"] = {"commit": commit, "repository": "https://github.com/sntran/World"}
        if locked and locked != commit:
            print(f"World: {locked} to {commit}.")
    elif locked != commit:
        raise FetchError(
            f"the {args.source} has World {commit}, but the lock has {locked}. "
            "Use a clone at the commit of the lock, or --update."
        )

    assets.mkdir(parents=True, exist_ok=True)
    count = 0
    for model in chosen:
        if not args.update and not _needs(model, lock["models"].get(model["id"]), assets):
            continue
        files = get(model)
        receipt = json.loads(files[model["id"] + ".receipt.json"])
        for name, data in files.items():
            (assets / name).write_bytes(data)
            if name.endswith(".glb"):
                write_import(assets / name)
        lock["models"][model["id"]] = {
            "hash": receipt["hash"],
            "files": {name: wf.sha256(data) for name, data in sorted(files.items())},
        }
        count += 1
        print(f"{model['id']}: {receipt['hash']}", flush=True)
        # The lock after each model: a stop of the factory keeps the models before it.
        wf.write_lock(lock, Path(args.lock))
    for model_id in list(lock["models"]):
        if model_id not in {m["id"] for m in models}:
            del lock["models"][model_id]
    wf.write_lock(lock, Path(args.lock))
    print(f"Got the files of {count} models from World {commit}.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", choices=["factory", "checkout"])
    parser.add_argument("--world", help="a clone of World (for --source=checkout)")
    parser.add_argument("--mix", help="the command of mix in the clone, for an order that is not a catalog copy (CI)")
    parser.add_argument("--factory", default=FACTORY, help="the URL of the factory")
    parser.add_argument("--check", action="store_true", help="check the files against the lock, with no network")
    parser.add_argument("--update", action="store_true", help="get all files again from the newest World")
    parser.add_argument("--only", nargs="*", help="only these ids")
    parser.add_argument("--orders", default=str(wf.ORDERS))
    parser.add_argument("--lock", default=str(wf.LOCK))
    parser.add_argument("--assets", default=str(wf.ASSETS))
    args = parser.parse_args(argv)
    try:
        return run(args)
    except FetchError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
