#!/usr/bin/env python3
"""Puts the sheets of PT-72 in docs/showcase/ (plan 0026, R15).

    tools/playtest.sh showcase_shots
    python tools/showcase/sheets.py

Each sheet has the photo of the shot (its copy in docs/reference/photos/,
R17), then the shot on Low (the Mobile renderer) and on High (Forward+), at
17:10 (top) and at 12:00 (bottom). The page gives the link, the author, the
license, and the date of each photo, and where the eye of the shot is from
(report 0026, D-0026-02).
"""

from __future__ import annotations

import html
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT / "data" / "showcase" / "shots.json"
SHEETS = ROOT / "build" / "playtest" / "showcase_shots" / "1280x720"
OUT = ROOT / "docs" / "showcase"


def main() -> int:
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
            f'<img src="{html.escape(sheet.name)}" alt="The sheet of {html.escape(shot["id"])}"></section>'
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
