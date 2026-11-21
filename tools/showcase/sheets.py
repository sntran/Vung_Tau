#!/usr/bin/env python3
"""Puts the sheets of PT-72 in docs/showcase/ (plan 0026, R15).

    tools/playtest.sh showcase_shots
    python tools/showcase/sheets.py

Each sheet has the photo of the shot (its copy in docs/reference/photos/,
R17), then the shot on Low (the Mobile renderer) and on High (Forward+), at
17:10 (top) and at 12:00 (bottom). The page gives the link, the author, the
license, and the date of each photo, and where the eye of the shot is from
(report 0026, D-0026-02). A shot with a box "hill" also gets the sheet of that
box at twice its size: the box of the photo, then the box of each screenshot
(report 0026, D-0026-23).
"""

from __future__ import annotations

import html
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PHOTOS = ROOT / "docs" / "reference" / "photos"
SHOTS = ROOT / "data" / "showcase" / "shots.json"
SHEETS = ROOT / "build" / "playtest" / "showcase_shots" / "1280x720"
OUT = ROOT / "docs" / "showcase"


def hill_sheet(shot: dict) -> str | None:
    """The sheet of the box "hill" of a shot at twice its size (D-0026-23), or None."""
    from PIL import Image, ImageDraw
    if "hill" not in shot:
        return None
    width = 1280
    def crop(path: Path, box: list[float]) -> Image.Image:
        image = Image.open(path).convert("RGB")
        if image.width != width:
            image = image.resize((width, round(image.height * width / image.width)))
        w, h = image.size
        part = image.crop((round(box[0] * w), round(box[1] * h), round(box[2] * w), round(box[3] * h)))
        return part.resize((part.width * 2, part.height * 2), Image.Resampling.BICUBIC)
    parts = [("the photo", crop(PHOTOS / shot["photos"][0]["file"], shot["hill"]["photo"]))]
    for shot_file in sorted(SHEETS.glob(f"*-{shot['id']}_*.png")):
        label = shot_file.stem.split("-", 1)[1].replace(f"{shot['id']}_", "")
        if label.count("_") == 1:
            parts.append((label, crop(shot_file, shot["hill"]["shot"])))
    cell = (max(p.width for _, p in parts), max(p.height for _, p in parts) + 20)
    sheet = Image.new("RGB", (cell[0] * len(parts), cell[1]), (24, 24, 24))
    draw = ImageDraw.Draw(sheet)
    for k, (label, part) in enumerate(parts):
        sheet.paste(part, (k * cell[0], 20))
        draw.text((k * cell[0] + 6, 4), label, fill=(255, 255, 255))
    name = f"sheet_{shot['id']}_hill.jpg"
    sheet.save(OUT / name, quality=85)
    return name


def main() -> int:
    global OUT
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, help="the folder of the sheets (R21: docs/showcase/mac/ for the run on a Mac)")
    args = parser.parse_args()
    if args.out:
        OUT = args.out if args.out.is_absolute() else ROOT / args.out
    data = json.loads(SHOTS.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    for shot in data["shots"]:
        sheet = SHEETS / f"sheet_{shot['id']}.jpg"
        if not sheet.exists():
            print(f"ERROR: {sheet} is not there. Run tools/playtest.sh showcase_shots.")
            return 1
        shutil.copyfile(sheet, OUT / sheet.name)
        photo = shot["photos"][0]
        rows.append(
            f"<section><h2>{html.escape(shot['id'])}: {html.escape(shot['name'])}</h2>"
            f'<p>The photo: <a href="{html.escape(photo["url"])}">{html.escape(photo["url"])}</a>, '
            f"{html.escape(photo['author'])}, {html.escape(photo['license'])}, {html.escape(photo['date'])}. "
            f"{html.escape(photo['shows'])}</p>"
            f"<p>The eye: {html.escape(photo['place']['from'])}. The lens: {html.escape(photo['lens'])}. "
            f"{html.escape(shot.get('how', ''))}</p>"
            f"<p>Columns: the photo, Low (the Mobile renderer), High (Forward+). Rows: 17:10, 12:00.</p>"
            f'<img src="{html.escape(sheet.name)}" alt="The sheet of {html.escape(shot["id"])}">'
            + (f'<p>The box "hill" at twice its size: the photo, then each screenshot (report 0026, D-0026-23).</p>'
               f'<img src="{html.escape(hill)}" alt="The hill of {html.escape(shot["id"])}">' if (hill := hill_sheet(shot)) else "")
            + "</section>"
        )
    page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Bãi Trước shots</title>
<style>body{{font-family:sans-serif;margin:16px;max-width:1300px;background:#fafafa;color:#222}}
img{{max-width:100%;height:auto;border:1px solid #ccc}}a{{word-break:break-all}}</style></head>
<body><h1>The showcase of Bãi Trước</h1>
<p>Plan 0026, PT-72. The five shots of section 3, next to their photos.</p>
{''.join(rows)}
</body></html>
"""
    (OUT / "index.html").write_text(page, encoding="utf-8")
    print(f"Wrote {OUT / 'index.html'} with {len(rows)} shots.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
