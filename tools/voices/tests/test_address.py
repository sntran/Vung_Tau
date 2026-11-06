"""The forms of address of the voices build (plan 0007, R7 to R11): the same cases as tests/unit/test_address.gd."""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "voices"))

import address  # noqa: E402

CASES = json.loads((ROOT / "tests" / "unit" / "address_cases.json").read_text(encoding="utf-8"))
DATA = json.loads((ROOT / "data" / "address.json").read_text(encoding="utf-8"))


def test_each_row_and_role_rule():
    for case in CASES["words"]:
        traveler = {"gender": case["gender"], "age": case["age"]}
        words = address.words(DATA, case["person"], traveler)
        for field in address.FIELDS:
            assert words[field] == case[field], (case, field)
        assert address.display_name(DATA, case["person"], traveler) == case["name"], case


def test_fields_and_capital_letters():
    for case in CASES["fill"]:
        assert address.fill(case["text"], case["words"]) == case["result"]


def test_dear():
    for case in CASES["english"]:
        assert address.fill_english(DATA, case["text"], case["words"]) == case["result"]


def test_variant_keys():
    for case in CASES["keys"]:
        fields = [f for f in address.FIELDS if f in case["fields"]]
        assert address.key(case["words"], fields) == case["result"]


def test_variants_of_a_line():
    line = {"vi": "Dạ, {self} cảm ơn {them}.", "variants": [{"when": {"them": "em"}, "vi": "Cảm ơn {them}."}]}
    assert address.line_fields(line) == ["them", "self"]
    young = address.resolve_line(DATA, line, {"you": "anh", "me": "em", "them": "em", "self": "anh"})
    assert young["vi"] == "Cảm ơn em."
    assert address.resolve_line(DATA, line, {"you": "con", "me": "cô", "them": "cô", "self": "con"})["vi"] == \
        "Dạ, con cảm ơn cô."
