"""Paths and configuration files of the geodata pipeline."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GEO = ROOT / "data" / "geo"
RAW = GEO / "raw"
BUILD = GEO / "build"
TEXTURES = ROOT / "assets" / "textures" / "ground"
FONT = ROOT / "assets" / "fonts" / "BeVietnamPro-Regular.ttf"


def load_json(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, data, indent: int | None = "\t") -> None:
    """Writes JSON with a newline at the end. Use indent=None for large files."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=indent, separators=None if indent else (",", ":"))
        f.write("\n")


class Config:
    """The configuration files in data/geo/. A test can give another folder."""

    def __init__(self, geo: Path = GEO):
        self.geo = geo
        self.area = load_json(geo / "area.json")
        self.landmarks = load_json(geo / "landmarks.json")["landmarks"]
        self.road_widths = load_json(geo / "road_widths.json")
        overrides = geo / "overrides.json"
        self.overrides = load_json(overrides)["corrections"] if overrides.exists() else []

    @property
    def bbox(self) -> tuple[float, float, float, float]:
        """The box as (west, south, east, north) in degrees."""
        b = self.area["bbox"]
        return (b["west"], b["south"], b["east"], b["north"])
