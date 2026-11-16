#!/usr/bin/env python3
"""The requests of this game to World (plan 0026, D5 and section 7).

A request is data in data/world/requests/*.json. The World guide
(World docs/requests.md) has three kinds of request: the words of a rule
(an order of a blueprint by its name), a blueprint in data, and a drawing
of edits. A request here also says when World cannot make the thing yet:

- "rule": an order of a blueprint that World has. World can build it now.
- "drawing": an order of the blueprint "drawing" (parts from edits). World
  can build it now from the drawing of this game.
- "new_rule": World has no rule for the thing. The request says what the
  rule must give ("needs"), with its sources.
- "world_plan": the thing is a step of a plan of World (for example World
  plan 0018, step 4). World builds it from its own survey.
- "answer": an answer to a question of a plan of World.

Usage:
    python tools/world/world_requests.py            # check the files, no network
    python tools/world/world_requests.py --check    # also check_order of World for each order
    python tools/world/world_requests.py --check --write   # and keep the result in the files
"""

from __future__ import annotations

import argparse
import datetime
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REQUESTS = ROOT / "data" / "world" / "requests"
FACTORY = "https://world.mkfifo.com"
KINDS = ("rule", "drawing", "new_rule", "world_plan", "answer")
OPEN_LICENSES = ("CC0", "CC BY", "CC BY-SA", "public domain")


def load(directory: Path = REQUESTS) -> dict[Path, dict]:
    return {path: json.loads(path.read_text(encoding="utf-8")) for path in sorted(directory.glob("*.json"))}


def problems(data: dict) -> list[str]:
    """The faults of one file of requests, with no network."""
    result = []
    ids = set()
    for request in data.get("requests", []):
        rid = request.get("id", "?")
        if rid in ids:
            result.append(f"{rid}: the id is two times in the file")
        ids.add(rid)
        for key in ("id", "what", "kind", "status"):
            if key not in request:
                result.append(f"{rid}: no \"{key}\"")
        kind = request.get("kind")
        if kind not in KINDS:
            result.append(f"{rid}: the kind \"{kind}\" is not one of {', '.join(KINDS)}")
        if kind in ("rule", "drawing") and "order" not in request:
            result.append(f"{rid}: a request of the kind \"{kind}\" has an order")
        if kind == "drawing" and request.get("order", {}).get("blueprint") != "drawing":
            result.append(f"{rid}: a request of the kind \"drawing\" is an order of the blueprint \"drawing\"")
        if kind == "new_rule" and not request.get("needs"):
            result.append(f"{rid}: a request of the kind \"new_rule\" says what the rule must give (\"needs\")")
        for source in request.get("sources", []):
            where = f"{rid}: the source {source.get('url', '?')}"
            for key in ("url", "date", "license", "shows"):
                if not source.get(key):
                    result.append(f"{where} has no \"{key}\"")
            is_open = any(str(source.get("license", "")).startswith(name) for name in OPEN_LICENSES)
            if bool(source.get("open")) != is_open:
                result.append(f"{where}: \"open\" must be {str(is_open).lower()} for the license {source.get('license')}")
            if "street view" in str(source.get("url", "")).lower() or "google.com/maps" in str(source.get("url", "")):
                result.append(f"{where}: no photos from Google Street View or Google Maps (plan 0026, section 7)")
    return result


def check_order(order: dict, base: str = FACTORY) -> dict:
    """World's check_order (the MCP tool of the factory): {"hash", "order"} or {"errors"}."""
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                       "params": {"name": "check_order", "arguments": {"order": order}}}).encode("utf-8")
    headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream",
               "User-Agent": "vung-tau-requests/1"}
    request = urllib.request.Request(f"{base}/mcp", data=body, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        answer = json.loads(response.read())
    return answer["result"]["structuredContent"]


def factory_commit(base: str = FACTORY) -> str:
    request = urllib.request.Request(f"{base}/version.json", headers={"User-Agent": "vung-tau-requests/1"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read())["commit"]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="check each order with check_order of World")
    parser.add_argument("--write", action="store_true", help="keep the result of each check in its file")
    parser.add_argument("--dir", default=str(REQUESTS))
    args = parser.parse_args(argv)
    files = load(Path(args.dir))
    faults = [f"{path.name}: {p}" for path, data in files.items() for p in problems(data)]
    for fault in faults:
        print(f"FAULT {fault}")
    if faults:
        return 1
    if not args.check:
        print(f"{sum(len(d.get('requests', [])) for d in files.values())} requests, no faults.")
        return 0
    commit = factory_commit()
    today = datetime.date.today().isoformat()
    for path, data in files.items():
        for request in data.get("requests", []):
            if "order" not in request:
                print(f"{request['id']}: {request['kind']}, no order")
                continue
            result = check_order(request["order"])
            if "errors" in result:
                print(f"{request['id']}: ERRORS {json.dumps(result['errors'], ensure_ascii=False)}")
                check = {"date": today, "world": commit, "errors": result["errors"]}
            else:
                print(f"{request['id']}: OK {result['hash']}")
                check = {"date": today, "world": commit, "hash": result["hash"]}
            request["check"] = check
        if args.write:
            path.write_text(json.dumps(data, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
