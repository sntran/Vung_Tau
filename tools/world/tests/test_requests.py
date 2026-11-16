"""The requests of the game to World (plan 0026, D5): the files have no faults."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import world_requests  # noqa: E402


def test_the_request_files_have_no_faults():
    files = world_requests.load()
    assert files, "data/world/requests/ has a file"
    for path, data in files.items():
        assert world_requests.problems(data) == [], path.name


def test_a_photo_with_no_open_license_is_a_reference_only():
    data = {"requests": [{"id": "X", "what": "a thing", "kind": "new_rule", "needs": "a rule", "status": "Check",
                          "sources": [{"url": "https://example.org/a.jpg", "date": "2019", "license": "all rights reserved",
                                       "open": True, "shows": "a wall"}]}]}
    assert any('"open" must be false' in p for p in world_requests.problems(data))


def test_a_rule_request_has_an_order():
    data = {"requests": [{"id": "X", "what": "a thing", "kind": "rule", "status": "Check"}]}
    assert any("has an order" in p for p in world_requests.problems(data))
