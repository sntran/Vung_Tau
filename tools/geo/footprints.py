#!/usr/bin/env python3
"""Gets the footprints of the buildings of the area of plan 0026 from Overture Maps.

    python tools/geo/footprints.py            # writes data/geo/build/footprints.json
    python tools/geo/footprints.py --release 2026-10-22.0

Report 0026, D-0026-03: OpenStreetMap has no building on the side of the hill
of Hạ Long between Cao ốc Sen Biển and Hải Âu, but the photos show houses and
hotels there. Plan 0009 (R1, approved for the area of plan 0026 first) takes
the footprints from public data. The workspace reached the public bucket of
Overture Maps on 2026-11-17 (plan 0009, D2: it did not on 2026-11-05), and CI
runs the workflow "Footprints". The buildings theme of Overture joins
OpenStreetMap, Microsoft ML Buildings, Google Open Buildings, and other sources
(ODbL). The file keeps each footprint in the frame of the game (x east, z
south), its sources, and its height or storeys when a source gives them. A
footprint gives no year and no storeys: the showcase builds a stand-in only for
a footprint whose storeys a photo gives (data/showcase/bai_truoc.json,
stand_ins.footprints).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "geo"))

from geodata.projection import Projection  # noqa: E402

OUT = ROOT / "data" / "geo" / "build" / "footprints.json"
WORLD = ROOT / "data" / "geo" / "build" / "world.json"
BUCKET = "https://overturemaps-us-west-2.s3.us-west-2.amazonaws.com"
# The area: the showcase of plan 0026 from the north end of the park to Nhà
# khách Hạ Long (lon, lat).
BOX = {"west": 107.0700, "south": 10.3360, "east": 107.0770, "north": 10.3470}


def _list(prefix: str, folders: bool = False) -> list[str]:
    """The keys (or the folders) of the public bucket under a prefix (the S3 list API, with no credential)."""
    found, token = [], None
    while True:
        query = {"list-type": "2", "prefix": prefix}
        if folders:
            query["delimiter"] = "/"
        if token:
            query["continuation-token"] = token
        with urllib.request.urlopen(f"{BUCKET}/?{urllib.parse.urlencode(query)}", timeout=60) as response:
            text = response.read().decode("utf-8")
        found += re.findall(r"<Prefix>([^<]+)</Prefix>" if folders else r"<Key>([^<]+)</Key>", text)
        match = re.search(r"<NextContinuationToken>([^<]+)</NextContinuationToken>", text)
        if not match:
            return found
        token = match.group(1)


def latest_release() -> str:
    """The newest release in the bucket (old releases are removed from it)."""
    releases = sorted(re.findall(r"^release/([0-9]{4}-[0-9]{2}-[0-9]{2}\.[0-9]+)/$", "\n".join(_list("release/", True)), re.M))
    if not releases:
        raise SystemExit("No release of Overture Maps in the bucket.")
    return releases[-1]


def fetch(release: str) -> list[dict]:
    """The footprints in BOX. DuckDB reads the parquet files over HTTPS (public, no
    S3 signature) and keeps only the row groups whose bbox can be in BOX."""
    import duckdb

    con = duckdb.connect()
    for statement in ("INSTALL spatial", "LOAD spatial", "INSTALL httpfs", "LOAD httpfs"):
        con.execute(statement)
    proxy = os.environ.get("HTTPS_PROXY", "")
    if proxy:
        con.execute(f"SET http_proxy='{proxy.split('://')[-1]}'")
    for bundle in (os.environ.get("REQUESTS_CA_BUNDLE", ""), os.environ.get("SSL_CERT_FILE", "")):
        if bundle and Path(bundle).exists():
            con.execute(f"SET ca_cert_file='{bundle}'")
            break
    keys = _list(f"release/{release}/theme=buildings/type=building/")
    urls = [f"{BUCKET}/{key}" for key in keys if key.endswith(".parquet")]
    rows = con.execute(
        f"""
        SELECT id, height, num_floors, sources, ST_AsGeoJSON(geometry)
        FROM read_parquet({urls!r})
        WHERE bbox.xmin > {BOX['west']} AND bbox.xmax < {BOX['east']}
          AND bbox.ymin > {BOX['south']} AND bbox.ymax < {BOX['north']}
        """
    ).fetchall()
    origin = json.loads(WORLD.read_text(encoding="utf-8"))["origin"]
    projection = Projection(float(origin["utm_e"]), float(origin["utm_n"]))
    result = []
    for overture_id, height, floors, sources, geometry in rows:
        shape = json.loads(geometry)
        if shape["type"] != "Polygon":
            continue
        ring = shape["coordinates"][0]
        xs, zs = projection.to_game([p[0] for p in ring], [p[1] for p in ring])
        datasets = sorted({str(s.get("dataset", "")) for s in (sources or []) if isinstance(s, dict)})
        record_ids = sorted({str(s.get("record_id", "")) for s in (sources or []) if isinstance(s, dict) and s.get("record_id")})
        result.append({
            "id": overture_id,
            "sources": datasets,
            "records": record_ids,
            "height": height,
            "floors": floors,
            "outline": [[round(float(x), 2), round(float(z), 2)] for x, z in zip(xs, zs)],
        })
    result.sort(key=lambda r: (r["outline"][0][1], r["outline"][0][0]))
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release", help="a release of Overture Maps (the newest if not given)")
    args = parser.parse_args()
    release = args.release or latest_release()
    footprints = fetch(release)
    OUT.write_text(json.dumps({
        "note": "Footprints of the buildings of the area of plan 0026 from the buildings theme of Overture Maps "
                "(tools/geo/footprints.py, report 0026, D-0026-03). (c) OpenStreetMap contributors, Overture Maps "
                "Foundation, Microsoft, Google, and the other sources of the theme: ODbL. No year and no storeys: "
                "a stand-in needs its storeys from a photo.",
        "release": release,
        "box": BOX,
        "footprints": footprints,
    }, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    print(f"{len(footprints)} footprints of the release {release} in {OUT.relative_to(ROOT)}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
