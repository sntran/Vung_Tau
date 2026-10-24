import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

DATA = HERE / "data"


@pytest.fixture(scope="session")
def small_build(tmp_path_factory):
    """Builds the small test extract one time for all tests."""
    import build
    out = tmp_path_factory.mktemp("build")
    assert build.build(DATA, out, DATA / "geo") == 0
    return out
