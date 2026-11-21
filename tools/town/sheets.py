#!/usr/bin/env python3
"""Puts the sheets of PT-68 in docs/town/ (plan 0009, phase 2, R6).

    tools/playtest.sh town_views
    python tools/photos/photos.py        # the open photos of data/geo/town_views.json
    python tools/town/sheets.py

Each sheet has the open photo of the view (its copy in docs/reference/photos/,
plan 0026, R17), then the view of the game at 12:00 and at 18:00 on Low. A view
with no open photo says so. docs/town/index.md gives the link, the author, the
license, and the date of each photo, and where the eye of each view is from.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PHOTOS = ROOT / "docs" / "reference" / "photos"
VIEWS = ROOT / "data" / "geo" / "town_views.json"
SHOTS = ROOT / "build" / "playtest" / "town_views" / "1280x720"
OUT = ROOT / "docs" / "town"
WIDTH = 960


def _fit(image, width: int, height: int):
    from PIL import Image
    scale = min(width / image.width, height / image.height)
    return image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)


def sheet(view: dict) -> tuple[str, list[str]]:
    """The sheet of a view: the photo (or a note), then 12:00 and 18:00."""
    from PIL import Image, ImageDraw, ImageFont
    font_path = ROOT / "assets" / "fonts" / "BeVietnamPro-Regular.ttf"
    font = ImageFont.truetype(str(font_path), 18) if font_path.exists() else ImageFont.load_default()
    height = WIDTH * 9 // 16
    cells = []
    missing = []
    photos = view.get("photos", [])
    if photos and (PHOTOS / photos[0]["file"]).exists():
        cells.append((f"The photo ({photos[0]['date'][:4]}, {photos[0]['license']})",
                      _fit(Image.open(PHOTOS / photos[0]["file"]).convert("RGB"), WIDTH, height)))
    else:
        note = Image.new("RGB", (WIDTH, height), (40, 40, 40))
        ImageDraw.Draw(note).multiline_text((20, 20), "No open photo of this view.\n" + view.get("photo_note", "")[:160],
                                            fill=(230, 230, 230), font=font)
        cells.append(("No photo", note))
        if photos:
            missing.append(f"{view['id']}: the copy {photos[0]['file']} is not in docs/reference/photos/")
    for time in ("1200", "1800"):
        found = sorted(SHOTS.glob(f"*-{view['id']}_{time}.png"))
        if not found:
            missing.append(f"{view['id']}: no screenshot at {time}")
            continue
        cells.append((f"The game, Low, {time[:2]}:{time[2:]}", _fit(Image.open(found[-1]).convert("RGB"), WIDTH, height)))
    out = Image.new("RGB", (WIDTH * len(cells), height + 34), (24, 24, 24))
    draw = ImageDraw.Draw(out)
    for k, (label, image) in enumerate(cells):
        out.paste(image, (k * WIDTH + (WIDTH - image.width) // 2, 34 + (height - image.height) // 2))
        draw.text((k * WIDTH + 8, 6), label, fill=(255, 255, 255), font=font)
    name = f"sheet_{view['id']}.jpg"
    out.save(OUT / name, quality=85)
    return name, missing


def main() -> int:
    views = json.loads(VIEWS.read_text(encoding="utf-8"))["views"]
    OUT.mkdir(parents=True, exist_ok=True)
    lines = ["# The views of the town (plan 0009, PT-68)", "",
             "Made by `tools/town/sheets.py` from the screenshots of `tools/playtest.sh town_views`. "
             "The boxes of the town are the far level of phase 2: each building of 2019 as a box of its outline "
             "and its height, with a roof. On Low they show to 1 500 m; farther, the ground shows its pattern of roofs.", ""]
    problems = []
    for view in views:
        name, missing = sheet(view)
        problems += missing
        lines += [f"## {view['name']}", "", f"![{view['id']}]({name})", ""]
        if view.get("eye_note"):
            lines += [f"- The eye: {view['eye_note']}"]
        for photo in view.get("photos", []):
            lines += [f"- The photo: [{photo.get('title', photo['url'])}]({photo['url']}), {photo['author']}, "
                      f"{photo['license']}, {photo['date']}. {photo['shows']}"]
        if not view.get("photos"):
            lines += [f"- {view.get('photo_note', 'No open photo.')}"]
        lines.append("")
    (OUT / "index.md").write_text("\n".join(lines), encoding="utf-8")
    for problem in problems:
        print(problem)
    print(f"Wrote {OUT / 'index.md'} with {len(views)} views.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
