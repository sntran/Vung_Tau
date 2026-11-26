"""Plan 0031, R9: the files of the R2 bucket vung-tau (and only that bucket).
The deploy keeps the files of the last KEEP builds (by the time of their
upload), the build that the Worker gives on main, and the parts of the packs
(p/...) that their manifests (builds/BUILD/manifest.json) use; it removes the
other files. It uses the API of Cloudflare with CLOUDFLARE_API_TOKEN and
CLOUDFLARE_ACCOUNT_ID of the workspace (never printed).

    python3 tools/web/r2.py keys PREFIX          # the keys under the prefix, one in each line
    python3 tools/web/r2.py prune --keep 5 [--protect BUILD ...] [--dry-run]
"""
import argparse
import json
import os
import re
import sys
import urllib.parse
import urllib.request

BUCKET = "vung-tau"
API = "https://api.cloudflare.com/client/v4/accounts/{account}/r2/buckets/" + BUCKET
BUILD = re.compile(r"^builds/([0-9a-f]{7,40})/")


def choose(objects: list[dict], manifests: dict, keep: int, protect: set) -> list[str]:
    """The keys to remove: the files of the builds after the newest KEEP (and
    not protected), and the parts that no kept build uses."""
    newest: dict[str, str] = {}
    for o in objects:
        m = BUILD.match(o["key"])
        if m:
            newest[m.group(1)] = max(newest.get(m.group(1), ""), o["last_modified"])
    kept = set(sorted(newest, key=lambda b: newest[b], reverse=True)[:keep]) | set(protect)
    used = set()
    for build in kept:
        # A manifest with no packs (an error of the API in its place) would remove the parts that it uses.
        if build in manifests and not isinstance(manifests[build].get("packs"), dict):
            raise ValueError(f"the manifest of the build {build} has no packs: no removal")
        for pack in manifests.get(build, {}).get("packs", {}).values():
            for part in pack.get("parts", []):
                used.add(part["url"])
    gone = []
    for o in objects:
        key = o["key"]
        m = BUILD.match(key)
        if m and m.group(1) not in kept:
            gone.append(key)
        elif key.startswith("p/") and key.removesuffix(".br") not in used:
            gone.append(key)
    return gone


def _request(method: str, path: str, query: dict | None = None) -> bytes:
    account = os.environ["CLOUDFLARE_ACCOUNT_ID"]
    url = API.format(account=account) + path
    if query:
        url += "?" + urllib.parse.urlencode(query)
    request = urllib.request.Request(url, method=method, headers={
        "Authorization": "Bearer " + os.environ["CLOUDFLARE_API_TOKEN"], "User-Agent": "deploy-tool"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def list_objects(prefix: str) -> list[dict]:
    out, cursor = [], None
    while True:
        query = {"prefix": prefix, "per_page": 1000}
        if cursor:
            query["cursor"] = cursor
        data = json.loads(_request("GET", "/objects", query))
        out += data.get("result", [])
        info = data.get("result_info") or {}
        cursor = info.get("cursor")
        if not info.get("is_truncated") or not cursor:
            return out


def get_object(key: str) -> bytes:
    return _request("GET", "/objects/" + urllib.parse.quote(key, safe="/"))


def delete_object(key: str) -> None:
    _request("DELETE", "/objects/" + urllib.parse.quote(key, safe="/"))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    keys = sub.add_parser("keys")
    keys.add_argument("prefix")
    prune = sub.add_parser("prune")
    prune.add_argument("--keep", type=int, default=5)
    prune.add_argument("--protect", nargs="*", default=[])
    prune.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    if args.command == "keys":
        for o in list_objects(args.prefix):
            print(o["key"])
        return 0
    objects = list_objects("builds/") + list_objects("p/")
    manifests = {}
    for o in objects:
        m = BUILD.match(o["key"])
        if m and o["key"].endswith("/manifest.json"):
            manifests[m.group(1)] = json.loads(get_object(o["key"]))
    gone = choose(objects, manifests, args.keep, set(args.protect))
    size = sum(int(o.get("size", 0)) for o in objects if o["key"] in set(gone))
    print(f"r2.py: {len(objects)} files; {len(gone)} to remove ({size / 1e6:.0f} MB).")
    for key in gone:
        if args.dry_run:
            print(f"  would remove {key}")
        else:
            delete_object(key)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
