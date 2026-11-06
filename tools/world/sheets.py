#!/usr/bin/env python3
"""Puts the review sheets of PT-56 in docs/world/ (plan 0023, R11).

    tools/playtest.sh world_models
    python tools/world/sheets.py

The export workflow publishes docs/world/ on GitHub Pages at /world/.
"""

from __future__ import annotations

import html
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import worldfiles as wf  # noqa: E402

SHEETS = wf.ROOT / "build" / "playtest" / "world_models" / "1280x720"
OUT = wf.ROOT / "docs" / "world"


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    lock = wf.load_lock()
    rows = []
    for model in wf.load_orders():
        mid = model["id"]
        sheet = SHEETS / f"sheet_{mid}.png"
        if not sheet.exists():
            print(f"ERROR: {sheet} is not there. Run tools/playtest.sh world_models.")
            return 1
        shutil.copyfile(sheet, OUT / f"sheet_{mid}.png")
        receipt = json.loads((wf.ASSETS / f"{mid}.receipt.json").read_text(encoding="utf-8"))
        sources = "".join(f"<li>{html.escape(s)}</li>" for s in receipt.get("sources") or [])
        rows.append(
            f"<section><h2>{html.escape(mid)}</h2>"
            f"<p>Catalog {html.escape(model['catalog'])}. {html.escape(model['uses'])}</p>"
            f"<p>Order: <code>{html.escape(json.dumps(model['order'], ensure_ascii=False))}</code>, "
            f"hash <code>{html.escape(receipt['hash'])}</code>.</p><ul>{sources}</ul>"
            f"<p>Rows: Low near, mid, far; High near, mid, far. Columns: front, side, three quarters. 12:00.</p>"
            f'<img src="sheet_{html.escape(mid)}.png" alt="The sheet of {html.escape(mid)}"></section>'
        )
    commit = lock["world"]["commit"]
    page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Models of World</title>
<style>body{{font-family:sans-serif;margin:16px;max-width:980px;background:#fafafa;color:#222}}
img{{max-width:100%;height:auto;border:1px solid #ccc}}code{{font-size:90%;word-break:break-all}}</style></head>
<body><h1>The models of World in Vũng Tàu</h1>
<p>Plan 0023, PT-56. World commit <code>{html.escape(commit)}</code>. The game gives the materials and the light.</p>
{''.join(rows)}
</body></html>
"""
    (OUT / "index.html").write_text(page, encoding="utf-8")
    print(f"Wrote {OUT / 'index.html'} with {len(rows)} models.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
