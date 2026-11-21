"""The documents speak for the project in my voice (CONTRIBUTING.md; report 0026, D-0026-45). No network."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
# The files where a line names the person who approves or confirms.
FILES = ["docs/plans/*.md", "docs/content/*.md", "data/showcase/*.json", "tests/unit/*.gd", "playtests/*.gd"]
# "the owner" in quotes is a name of the words, not of me.
OWNER = re.compile(r'(?<!")\bthe owner\b(?!")', re.IGNORECASE)


def test_the_documents_do_not_name_me_in_the_third_person():
    found = []
    for pattern in FILES:
        for path in sorted(ROOT.glob(pattern)):
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                if OWNER.search(line):
                    found.append(f"{path.relative_to(ROOT)}:{number}: {OWNER.search(line).group(0)}")
    assert found == [], "write \"I\" or \"me\" (CONTRIBUTING.md):\n" + "\n".join(found)
