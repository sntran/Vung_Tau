"""Tests of tools/world (plan 0023, R2 to R4)."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import fetch  # noqa: E402
import worldfiles as wf  # noqa: E402


def test_encode_has_the_keys_in_order_and_no_spaces():
    assert wf.encode({"b": 1, "a": [1.5, "x"], "c": {}}) == '{"a":[1.5,"x"],"b":1,"c":{}}'


def test_encode_writes_floats_and_text_as_erlang():
    assert wf.encode(1.0) == "1.0"
    assert wf.encode(1e-05) == "1.0e-5"
    assert wf.encode(2.5e-07) == "2.5e-7"
    assert wf.encode("Vũng Tàu \"a\"") == '"Vũng Tàu \\"a\\""'
    assert wf.encode([True, None]) == "[true,null]"


def test_the_full_order_of_a_catalog_model():
    full = wf.full_order({"blueprint": "catalog", "options": {"name": "honda_vision_110"}})
    assert wf.encode(full) == '{"blueprint":"catalog","colors":{},"joints":{},"options":{"name":"honda_vision_110"}}'
    assert len(wf.order_hash(full)) == 32
    with pytest.raises(ValueError):
        wf.full_order({"blueprint": "catalog", "options": {"name": "x"}, "colors": {"paint": "#ffffff"}})


def test_agrees_compares_the_given_values_only():
    full = {"blueprint": "person", "options": {"gender": 0.0, "age": 60.0}, "colors": {}, "joints": {}}
    assert wf.agrees({"blueprint": "person", "options": {"gender": 0}}, full)
    assert not wf.agrees({"blueprint": "person", "options": {"gender": 1}}, full)


def test_the_files_of_the_game_agree_with_the_lock():
    problems = wf.check(wf.load_orders(), wf.load_lock())
    assert problems == []


def test_check_finds_a_changed_file(tmp_path):
    assets = tmp_path / "world"
    shutil.copytree(wf.ASSETS, assets)
    model = wf.load_orders()[0]
    path = assets / f"{model['id']}.parts.json"
    path.write_bytes(path.read_bytes() + b" ")
    problems = wf.check(wf.load_orders(), wf.load_lock(), assets)
    assert any("does not agree with the SHA-256" in p for p in problems)
    (assets / "extra.glb").write_bytes(b"x")
    assert any("extra.glb" in p for p in wf.check(wf.load_orders(), wf.load_lock(), assets))


def test_the_receipts_have_the_hash_of_their_order():
    for model in wf.load_orders():
        receipt = json.loads((wf.ASSETS / f"{model['id']}.receipt.json").read_text(encoding="utf-8"))
        assert receipt["hash"] == wf.order_hash(receipt["order"])
        assert wf.agrees(model["order"], receipt["order"])


def _factory_commit():
    try:
        return fetch.factory_commit()
    except fetch.FetchError:
        return None


## R4: the factory and a clone at the same commit give the same bytes.
ORDERS = [
    {"id": "a", "order": {"blueprint": "catalog", "options": {"name": "honda_vision_110"}}, "levels": ["near", "mid", "far"]},
    {"id": "b", "order": {"blueprint": "catalog", "options": {"name": "ceiling_fan_52in"}}, "levels": ["near", "mid", "far"]},
    {"id": "c", "order": {"blueprint": "catalog", "options": {"name": "thung_rac_240l"}}, "levels": ["near", "mid", "far"]},
]


def test_the_two_sources_give_the_same_bytes(tmp_path):
    commit = _factory_commit()
    if commit is None:
        pytest.skip("the factory (world.mkfifo.com) is not reachable here")
    clone = tmp_path / "World"
    subprocess.run(["git", "clone", "-q", "https://github.com/sntran/World", str(clone)], check=True)
    subprocess.run(["git", "-C", str(clone), "checkout", "-q", commit], check=True)
    for model in ORDERS:
        from_factory = fetch.factory_files(model)
        from_clone = fetch.checkout_files(model, clone, None)
        assert sorted(from_factory) == sorted(from_clone)
        for name in from_factory:
            assert from_factory[name] == from_clone[name], f"{model['order']['options']['name']}: {name} is not the same"
