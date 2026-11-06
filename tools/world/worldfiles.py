"""The files of the orders of World (plan 0023, R1 to R4).

The functions here have no network and no clone. fetch.py uses them, and
the tests use them.

- encode() and order_hash() are the JSON and the hash of World
  (World.Orders.encode/1 and hash/1): the keys of each object in order,
  no spaces, and 32 hex digits of the SHA-256.
- full_order() gives the full order of a catalog order with no colors,
  no joints, and no targets. Only such an order can come from the files
  of priv/models of a clone with no build.
- receipt() makes the receipt of such an order from its GLB at the near
  level, as World.Orders makes it.
"""

from __future__ import annotations

import hashlib
import json
import math
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ORDERS = ROOT / "data" / "world" / "orders.json"
LOCK = ROOT / "data" / "world" / "lock.json"
ASSETS = ROOT / "assets" / "world"

## The suffix of the file of each level, and of the other files.
LEVEL_SUFFIX = {"near": ".glb", "mid": ".mid.glb", "far": ".far.glb"}
OTHER_SUFFIXES = (".parts.json", ".receipt.json")
## The keys of an order (World.Orders, @keys).
ORDER_KEYS = ("blueprint", "options", "colors", "joints", "targets")


def _float(value: float) -> str:
    """A float as Erlang writes it (float_to_binary(F, [short]))."""
    if math.isinf(value) or math.isnan(value):
        raise ValueError("JSON has no infinite or NaN number")
    text = repr(value)
    if "e" not in text:
        return text
    mantissa, exponent = text.split("e")
    if "." not in mantissa:
        mantissa += ".0"
    return f"{mantissa}e{int(exponent)}"


def _string(value: str) -> str:
    # Erlang json:encode/1 escapes the quote, the backslash, and the control
    # characters, and writes the other characters as UTF-8.
    return json.dumps(value, ensure_ascii=False)


def encode(value) -> str:
    """The JSON of a value with the keys of each object in order."""
    if isinstance(value, dict):
        pairs = [f"{_string(str(k))}:{encode(v)}" for k, v in sorted(value.items(), key=lambda kv: str(kv[0]))]
        return "{" + ",".join(pairs) + "}"
    if isinstance(value, (list, tuple)):
        return "[" + ",".join(encode(v) for v in value) + "]"
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return _float(value)
    if isinstance(value, str):
        return _string(value)
    raise TypeError(f"cannot encode {type(value).__name__}")


def order_hash(full: dict) -> str:
    """The hash of a full order: 32 hex digits of its SHA-256."""
    return hashlib.sha256(encode(full).encode("utf-8")).hexdigest()[:32]


def is_catalog_copy(order: dict) -> bool:
    """True when the files of priv/models are the files of the order."""
    return (
        order.get("blueprint") == "catalog"
        and set(order.get("options", {})) == {"name"}
        and not order.get("colors")
        and not order.get("joints")
        and not order.get("targets")
    )


def full_order(order: dict) -> dict:
    """The full order of a catalog order (World.Orders.check/1)."""
    if not is_catalog_copy(order):
        raise ValueError("only a catalog order with no colors, joints, or targets has a full order here")
    return {"blueprint": "catalog", "options": {"name": order["options"]["name"]}, "colors": {}, "joints": {}}


def agrees(given, full) -> bool:
    """True when each value of the given order is the value in the full order."""
    if isinstance(given, dict):
        if not isinstance(full, dict):
            return False
        return all(k in full and agrees(v, full[k]) for k, v in given.items())
    if isinstance(given, (int, float)) and not isinstance(given, bool) and isinstance(full, (int, float)):
        return float(given) == float(full)
    if isinstance(given, list) and isinstance(full, list):
        return len(given) == len(full) and all(agrees(a, b) for a, b in zip(given, full))
    return given == full


def glb_json(data: bytes) -> dict:
    """The JSON chunk of a GLB file."""
    magic, _version, _length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError("not a GLB file")
    chunk_length, chunk_type = struct.unpack_from("<I4s", data, 12)
    if chunk_type != b"JSON":
        raise ValueError("the first chunk of the GLB is not JSON")
    return json.loads(data[20 : 20 + chunk_length])


def scene_extras(data: bytes) -> dict:
    """The extras of the scene of a GLB of World."""
    doc = glb_json(data)
    return doc["scenes"][doc.get("scene", 0)].get("extras", {})


def receipt(full: dict, near_glb: bytes, world_version: str) -> str:
    """The receipt of an order (World.Orders, receipt/3), from its near GLB."""
    extras = scene_extras(near_glb)
    return encode(
        {
            "order": full,
            "hash": order_hash(full),
            "level": "near",
            "world": world_version,
            "name": extras.get("name"),
            "kind": extras.get("kind"),
            "size": extras.get("size"),
            "joints": extras.get("joints"),
            "limbs": extras.get("limbs"),
            "sources": extras.get("sources"),
        }
    )


def world_version(clone: Path) -> str:
    """The version of the app of World (mix.exs)."""
    match = re.search(r'version:\s*"([^"]+)"', (clone / "mix.exs").read_text(encoding="utf-8"))
    if not match:
        raise ValueError(f"no version in {clone / 'mix.exs'}")
    return match.group(1)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_names(model: dict) -> list[str]:
    """The names of the files of a model of orders.json, in assets/world/."""
    names = [model["id"] + LEVEL_SUFFIX[level] for level in ("near", "mid", "far") if level in model["levels"]]
    return names + [model["id"] + suffix for suffix in OTHER_SUFFIXES]


def load_orders(path: Path = ORDERS) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    models = data["models"]
    ids = [m["id"] for m in models]
    if len(ids) != len(set(ids)):
        raise ValueError("orders.json has an id two times")
    for model in models:
        for key in ("id", "order", "levels", "impostor", "uses", "catalog"):
            if key not in model:
                raise ValueError(f"orders.json: the model {model.get('id', '?')} has no \"{key}\"")
        if "near" not in model["levels"]:
            raise ValueError(f"orders.json: the model {model['id']} has no near level")
        unknown = set(model["levels"]) - set(LEVEL_SUFFIX)
        if unknown:
            raise ValueError(f"orders.json: the model {model['id']} has the levels {sorted(unknown)}")
        bad_keys = set(model["order"]) - set(ORDER_KEYS)
        if bad_keys:
            raise ValueError(f"orders.json: the order of {model['id']} has the keys {sorted(bad_keys)}")
    return models


def load_lock(path: Path = LOCK) -> dict:
    if not path.exists():
        return {"world": {}, "models": {}}
    return json.loads(path.read_text(encoding="utf-8"))


def write_lock(lock: dict, path: Path = LOCK) -> None:
    lock["models"] = dict(sorted(lock["models"].items()))
    path.write_text(json.dumps(lock, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")


def check(models: list[dict], lock: dict, assets: Path = ASSETS) -> list[str]:
    """The problems of assets/world/ against the lock and the orders (R3)."""
    problems: list[str] = []
    if not lock.get("world", {}).get("commit"):
        problems.append("lock.json has no commit of World")
    expected: set[str] = set()
    for model in models:
        mid = model["id"]
        entry = lock["models"].get(mid)
        if entry is None:
            problems.append(f"{mid}: not in lock.json")
            continue
        names = file_names(model)
        expected.update(names)
        if sorted(entry.get("files", {})) != sorted(names):
            problems.append(f"{mid}: the files of lock.json are not the files of the levels: {sorted(entry.get('files', {}))}")
        for name in names:
            path = assets / name
            if not path.exists():
                problems.append(f"{mid}: {name} is not in assets/world/")
                continue
            if sha256(path.read_bytes()) != entry.get("files", {}).get(name):
                problems.append(f"{mid}: {name} does not agree with the SHA-256 of lock.json")
        receipt_path = assets / f"{mid}.receipt.json"
        if receipt_path.exists():
            rec = json.loads(receipt_path.read_text(encoding="utf-8"))
            if rec.get("hash") != entry.get("hash"):
                problems.append(f"{mid}: the hash of the receipt is not the hash of lock.json")
            if not agrees(model["order"], rec.get("order", {})):
                problems.append(f"{mid}: the order of orders.json is not the order of the receipt")
            if rec.get("order") and order_hash(rec["order"]) != rec.get("hash"):
                problems.append(f"{mid}: the hash of the receipt is not the hash of its order")
    for model_id in lock["models"]:
        if model_id not in {m["id"] for m in models}:
            problems.append(f"{model_id}: in lock.json, but not in orders.json")
    if assets.exists():
        for path in sorted(assets.iterdir()):
            # The impostors are files of the game (impostors.py), not of World.
            if path.suffix == ".import" or path.name.endswith(".png") or path.name == "impostors.json":
                continue
            if path.name not in expected and not path.name.startswith("."):
                problems.append(f"{path.name}: in assets/world/, but not a file of orders.json")
    return problems
