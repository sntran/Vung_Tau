"""Plan 0031, R7 and R9: the parts of the packs by the hash of their content,
and the choice of the files of the bucket that the deploy removes."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import parts  # noqa: E402
import r2  # noqa: E402


def bid(i):
    """The id of a build: 12 hex characters, as a commit."""
    return f"b{i:011x}"


def obj(key, when):
    return {"key": key, "last_modified": when}


def test_the_deploy_keeps_the_last_five_builds_and_the_parts_that_they_use():
    objects = []
    for i in range(7):
        objects += [obj(f"builds/{bid(i)}/index.wasm", f"2026-11-2{i}T00:00:00Z"), obj(f"builds/{bid(i)}/manifest.json", f"2026-11-2{i}T00:00:01Z")]
    objects += [obj("p/aaa.pck", "2026-11-20T00:00:00Z"), obj("p/aaa.pck.br", "2026-11-20T00:00:00Z"),
                obj("p/bbb.pck", "2026-11-26T00:00:00Z"), obj("p/old.pck", "2026-11-19T00:00:00Z")]
    manifests = {bid(i): {"packs": {"index": {"parts": [{"url": "p/aaa.pck"}]}}} for i in range(2, 7)}
    manifests[bid(6)]["packs"]["people"] = {"parts": [{"url": "p/bbb.pck"}]}
    gone = r2.choose(objects, manifests, keep=5, protect=set())
    assert f"builds/{bid(0)}/index.wasm" in gone and f"builds/{bid(1)}/manifest.json" in gone
    assert not any(key.startswith(f"builds/{bid(i)}/") for i in range(2, 7) for key in gone)
    assert "p/old.pck" in gone
    assert "p/aaa.pck" not in gone and "p/aaa.pck.br" not in gone and "p/bbb.pck" not in gone


def test_the_deploy_keeps_the_build_of_main():
    objects = [obj(f"builds/{bid(i)}/index.wasm", f"2026-11-2{i}T00:00:00Z") for i in range(7)]
    gone = r2.choose(objects, {}, keep=5, protect={bid(0)})
    assert f"builds/{bid(0)}/index.wasm" not in gone
    assert f"builds/{bid(1)}/index.wasm" in gone


def test_a_pack_goes_in_parts_named_by_the_hash_of_their_content(tmp_path):
    pack = tmp_path / "index.pck"
    pack.write_bytes(bytes(range(256)) * 1000)  # 256 000 bytes
    out = tmp_path / "p"
    entry = parts.split(pack, out, part_bytes=100_000)
    assert entry["size"] == 256_000
    assert [p["size"] for p in entry["parts"]] == [100_000, 100_000, 56_000]
    assert b"".join((out / Path(p["url"]).name).read_bytes() for p in entry["parts"]) == pack.read_bytes()
    assert all(p["url"].startswith("p/") and p["url"].endswith(".pck") for p in entry["parts"])
    again = parts.split(pack, tmp_path / "q", part_bytes=100_000)
    assert again["parts"] == entry["parts"], "the same content has the same names"
