"""Plan 0031, D15 and R7: a pack of the web build in parts, each named by the
hash of its content (p/HASH.pck), so that a part that does not change between
builds keeps its name, and the page keeps it in its cache. A part is at most
PART_BYTES before Brotli, so at most 50 MB over the network.

    python3 tools/web/parts.py OUT_DIR ID=FILE ...   # writes OUT_DIR/p/*.pck and prints the packs as JSON
"""
import hashlib
import json
import sys
from pathlib import Path

PART_BYTES = 40_000_000


def split(pack: Path, out: Path, part_bytes: int = PART_BYTES) -> dict:
    """Writes the parts of the pack to OUT and gives {"size", "parts": [{"url", "size"}]}."""
    out.mkdir(parents=True, exist_ok=True)
    data = pack.read_bytes()
    entry = {"size": len(data), "parts": []}
    for at in range(0, len(data), part_bytes):
        part = data[at:at + part_bytes]
        name = hashlib.sha256(part).hexdigest()[:20] + ".pck"
        (out / name).write_bytes(part)
        entry["parts"].append({"url": f"p/{name}", "size": len(part)})
    return entry


def main(argv: list[str]) -> int:
    out = Path(argv[0])
    packs = {}
    for item in argv[1:]:
        pack_id, file = item.split("=", 1)
        packs[pack_id] = split(Path(file), out / "p")
    print(json.dumps(packs))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
