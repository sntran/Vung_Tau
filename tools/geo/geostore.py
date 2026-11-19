"""The large raw files of plan 0009 in a release of the repository (report 0009,
D-0009-06). Git keeps only a small manifest for each kind of data, with the
SHA-256 of each file; the files themselves are assets of the release RELEASE
(as the people packs are assets of the release people-packs-1).

- put(): a tool writes a file once, compressed, to build/geodata/upload/. Its
  name has the start of its SHA-256, so a file of the release never changes
  and an old manifest stays good. The workflow "Buildings and lidar" uploads
  the folder to the release before it commits the manifest.
- get(): a tool gets a file of the manifest: from build/geodata/cache/, or
  from the release (public, no account), and checks its SHA-256.
"""

from __future__ import annotations

import gzip
import hashlib
import json
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = "sntran/Vung_Tau"
RELEASE = "geodata-0009-1"
CACHE = ROOT / "build" / "geodata" / "cache"
UPLOAD = ROOT / "build" / "geodata" / "upload"
AGENT = "vung-tau-geodata/1"


def load(path: Path) -> dict:
    """The manifest at path, or an empty one."""
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {"release": RELEASE, "files": {}}


def save(path: Path, manifest: dict, note: str) -> None:
    manifest["note"] = note
    manifest["release"] = manifest.get("release", RELEASE)
    manifest["files"] = dict(sorted(manifest.get("files", {}).items()))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


def put(manifest: dict, key: str, data: dict, **meta) -> str:
    """Writes data (JSON) as a compressed file of the release for the key (for
    example "atl03_ground/2019") and puts it in the manifest. Returns its name."""
    raw = json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    packed = gzip.compress(raw, compresslevel=9, mtime=0)
    digest = hashlib.sha256(packed).hexdigest()
    name = key.replace("/", "_") + "_" + digest[:12] + ".json.gz"
    UPLOAD.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    (UPLOAD / name).write_bytes(packed)
    (CACHE / name).write_bytes(packed)
    manifest.setdefault("files", {})[key] = {"name": name, "sha256": digest, "bytes": len(packed), **meta}
    return name


def get(manifest: dict, key: str, tries: int = 4) -> dict:
    """The JSON of the file of the key, from the cache or from the release."""
    entry = manifest["files"][key]
    path = CACHE / entry["name"]
    if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
        url = f"https://github.com/{REPOSITORY}/releases/download/{manifest.get('release', RELEASE)}/{entry['name']}"
        for attempt in range(tries):
            try:
                request = urllib.request.Request(url, headers={"User-Agent": AGENT})
                with urllib.request.urlopen(request, timeout=300) as response:
                    data = response.read()
                break
            except Exception:  # noqa: BLE001 - a network error: try again
                if attempt == tries - 1:
                    raise
                time.sleep(2 ** attempt * 3)
        if hashlib.sha256(data).hexdigest() != entry["sha256"]:
            raise ValueError(f"{entry['name']}: the SHA-256 of the release is not the SHA-256 of the manifest")
        CACHE.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return json.loads(gzip.decompress(path.read_bytes()).decode("utf-8"))
