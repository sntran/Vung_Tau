#!/usr/bin/env python3
"""The privacy step of the street photos (report 0026, D-0026-39).

Mapillary blurs most number plates and faces, but not all of them. Before a
picture goes on a contact sheet (tools/geo/photos.py), this step:

1. leaves out an image that data/showcase/photo_privacy.json lists with
   "leave_out" (a person decides it after a look at the sheet);
2. blurs the boxes of the list ("blur": for the id of a point of
   data/showcase/photo_points.json, boxes as fractions of the picture of the
   sheet; a 360 image has a view for each point);
3. finds the number plates (an RT-DETR detector, Apache 2.0) and the faces
   (YuNet of OpenCV, MIT) and blurs each one.

    python tools/geo/privacy.py --fix     # the same step on the sheets that are there

The detectors come from DETECTORS at the first use, to build/privacy/, with
their SHA-256 checked. A detector gives a suggestion, not a guarantee: look at
each sheet, and put an image that it misses in the list.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIST = ROOT / "data" / "showcase" / "photo_privacy.json"
SHEETS = ROOT / "docs" / "reference" / "mapillary"
CACHE = ROOT / "build" / "privacy"
AGENT = "vung-tau-photos/1"

DETECTORS = {
    "plate": {
        "url": "https://huggingface.co/Topurrra/rtdetr-license-plate-detection-onnx/resolve/"
               "aecb24a78e31cea03f59b83156d55dde84f20d94/plate_rtdetr.onnx",
        "sha256": "50f9bf9d7eaa97ade59063ba608107203d0575a84c0fb27e0ebf3bab6f594366",
    },
    "face": {
        "url": "https://media.githubusercontent.com/media/opencv/opencv_zoo/main/models/"
               "face_detection_yunet/face_detection_yunet_2023mar.onnx",
        "sha256": "8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4",
    },
}
# The plate detector gives low scores that rank well (its model card): the
# real plate is the top box about 92 % of the time, with about 0.1.
PLATE_SCORE = 0.06
FACE_SCORE = 0.6
SIZE = 640
# A box is a plate if its width over its height is in this range, and it is
# small in the picture.
PLATE_ASPECT = (0.8, 6.0)
PLATE_MAX_PART = (0.3, 0.2)
# The blurred area is larger than the box by this part on each side.
GROW = 0.3

# The layout of the sheets of tools/geo/photos.py.
SHEET_COLUMNS = 3
TILE_W = 512
TITLE_H = 30
BAND_H = 22

_sessions: dict = {}


def detector(name: str) -> Path:
    spec = DETECTORS[name]
    path = CACHE / Path(spec["url"]).name
    if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest() != spec["sha256"]:
        CACHE.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(spec["url"], headers={"User-Agent": AGENT})
        with urllib.request.urlopen(request, timeout=300) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != spec["sha256"]:
            raise RuntimeError(f"the detector {name}: the SHA-256 is not the one of DETECTORS")
        path.write_bytes(data)
    return path


def windows(w: int, h: int) -> list[tuple[int, int, int, int]]:
    """The whole picture, and squares of the short side with overlap: a small
    plate is larger in a square than in the whole picture at 640 px."""
    out = [(0, 0, w, h)]
    side = min(w, h)
    if max(w, h) > SIZE:
        side = max(SIZE, side // 2 if min(w, h) > 2 * SIZE else side)
        step = max(1, int(side * 0.75))
        for y in range(0, max(1, h - side) + 1, step):
            for x in range(0, max(1, w - side) + 1, step):
                out.append((x, y, min(w, x + side), min(h, y + side)))
            if h - side > 0 and (h - side) % step:
                out.append((x, h - side, min(w, x + side), h))
        if w - side > 0 and (w - side) % step:
            out.append((w - side, 0, w, side))
    return list(dict.fromkeys(out))


def plate_boxes(img) -> list[tuple[float, float, float, float, float]]:
    """(x0, y0, x1, y1, score) of the plates in a PIL picture."""
    import numpy as np
    import onnxruntime as ort
    from PIL import Image
    if "plate" not in _sessions:
        _sessions["plate"] = ort.InferenceSession(str(detector("plate")), providers=["CPUExecutionProvider"])
    session = _sessions["plate"]
    w, h = img.size
    found = []
    for x0, y0, x1, y1 in windows(w, h):
        part = img.crop((x0, y0, x1, y1))
        pw, ph = part.size
        data = (np.asarray(part.resize((SIZE, SIZE), Image.BILINEAR), np.float32) / 255.0).transpose(2, 0, 1)[None]
        logits, boxes = session.run(None, {"pixel_values": data})
        scores = 1.0 / (1.0 + np.exp(-logits[0, :, 0]))
        for (cx, cy, bw, bh), score in zip(boxes[0], scores):
            if score < PLATE_SCORE:
                continue
            bw_px, bh_px = bw * pw, bh * ph
            if bh_px <= 0 or not (PLATE_ASPECT[0] <= bw_px / bh_px <= PLATE_ASPECT[1]):
                continue
            if bw_px > PLATE_MAX_PART[0] * w or bh_px > PLATE_MAX_PART[1] * h or bw_px < 4:
                continue
            found.append((x0 + (cx - bw / 2) * pw, y0 + (cy - bh / 2) * ph,
                          x0 + (cx + bw / 2) * pw, y0 + (cy + bh / 2) * ph, float(score)))
    return found


def face_boxes(img) -> list[tuple[float, float, float, float, float]]:
    import cv2
    import numpy as np
    array = cv2.cvtColor(np.asarray(img), cv2.COLOR_RGB2BGR)
    h, w = array.shape[:2]
    face = cv2.FaceDetectorYN_create(str(detector("face")), "", (w, h), FACE_SCORE)
    _, faces = face.detect(array)
    if faces is None:
        return []
    return [(f[0], f[1], f[0] + f[2], f[1] + f[3], float(f[-1])) for f in faces]


def blur(img, boxes) -> None:
    """Blurs each box (x0, y0, x1, y1, ...) of the picture in place."""
    from PIL import ImageFilter
    w, h = img.size
    for box in boxes:
        x0, y0, x1, y1 = box[:4]
        gx, gy = (x1 - x0) * GROW, (y1 - y0) * GROW
        area = (max(0, int(x0 - gx)), max(0, int(y0 - gy)), min(w, int(x1 + gx) + 1), min(h, int(y1 + gy) + 1))
        if area[2] <= area[0] or area[3] <= area[1]:
            continue
        part = img.crop(area)
        small = part.resize((max(1, part.width // 6), max(1, part.height // 6)))
        part = small.resize(part.size).filter(ImageFilter.GaussianBlur(max(2.0, min(part.size) / 4)))
        img.paste(part, area[:2])


def the_list() -> dict:
    if LIST.exists():
        return json.loads(LIST.read_text(encoding="utf-8"))
    return {"images": {}}


def clean(img, image_id: str, point: str = ""):
    """The picture for a sheet of the point with no plate or face that a person
    can read, or None if the list leaves the image out. Returns also the number
    of boxes that it blurred."""
    entry = the_list().get("images", {}).get(str(image_id), {})
    if entry.get("leave_out"):
        return None, 0
    img = img.copy()
    w, h = img.size
    listed = [(a * w, b * h, c * w, d * h) for a, b, c, d in entry.get("blur", {}).get(point, [])]
    found = plate_boxes(img) + face_boxes(img)
    blur(img, listed + found)
    return img, len(listed) + len(found)


def sharpness(img, box) -> float:
    import numpy as np
    from PIL import ImageFilter
    x0, y0, x1, y1 = (int(v) for v in box[:4])
    part = img.crop((max(0, x0), max(0, y0), max(x0 + 1, x1), max(y0 + 1, y1))).convert("L")
    if part.width < 3 or part.height < 3:
        return 0.0
    edges = np.asarray(part.filter(ImageFilter.Kernel((3, 3), [0, 1, 0, 1, -4, 1, 0, 1, 0], 1, 128)), float) - 128
    return float(edges[1:-1, 1:-1].var()) if edges.shape[0] > 2 and edges.shape[1] > 2 else 0.0


def tiles(sheet) -> list[tuple[int, int, int, int]]:
    """The boxes of the tiles of a sheet of tools/geo/photos.py (the parts that are not black)."""
    import numpy as np
    w, h = sheet.size
    tile_h = int(TILE_W * 0.75)
    rows = (h - TITLE_H) // (tile_h + BAND_H)
    gray = np.asarray(sheet.convert("L"))
    out = []
    for row in range(rows):
        for col in range(SHEET_COLUMNS):
            x, y = col * TILE_W, TITLE_H + row * (tile_h + BAND_H)
            cell = gray[y:y + tile_h, x:x + TILE_W]
            lit = np.argwhere(cell > 24)
            if len(lit) < 100:
                continue
            (y0, x0), (y1, x1) = lit.min(axis=0), lit.max(axis=0)
            out.append((x + int(x0), y + int(y0), x + int(x1) + 1, y + int(y1) + 1))
    return out


def tiles_of_ids(credits: Path) -> dict[str, list[tuple[str, int]]]:
    """For each image on the sheets: (sheet, the number of its tile). The tiles
    of a sheet are in the order of the date, then the id (photos.choose())."""
    rows: dict[str, list] = {}
    for line in credits.read_text(encoding="utf-8").splitlines():
        if line.startswith("| `sheet_"):
            cells = [c.strip() for c in line.strip("|").split("|")]
            rows.setdefault(cells[0].strip("`"), []).append((cells[2], cells[1].strip("`")))
    out: dict[str, list] = {}
    for sheet, entries in rows.items():
        for k, (_date, image_id) in enumerate(sorted(entries)):
            out.setdefault(image_id, []).append((sheet, k))
    return out


def point_of(sheet_name: str, points: list[str]) -> str:
    """The id of the point of a sheet name (sheet_POINT[_WINDOW]_N.jpg)."""
    stem = sheet_name.removeprefix("sheet_").rsplit("_", 1)[0]
    return max((p for p in points if stem == p or stem.startswith(p + "_")), key=len, default=stem)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--fix", action="store_true", help="the step on the sheets that are there")
    args = parser.parse_args()
    from PIL import Image
    if not args.fix:
        parser.print_help()
        return 2
    points = [p["id"] for p in json.loads((ROOT / "data" / "showcase" / "photo_points.json").read_text(encoding="utf-8"))["points"]]
    by_sheet: dict[str, dict[int, str]] = {}
    for image_id, places in tiles_of_ids(SHEETS / "CREDITS.md").items():
        for sheet_name, k in places:
            by_sheet.setdefault(sheet_name, {})[k] = image_id
    for sheet_name, ids in sorted(by_sheet.items()):
        sheet = Image.open(SHEETS / sheet_name).convert("RGB")
        total = 0
        for k, tile in enumerate(tiles(sheet)):
            img, count = clean(sheet.crop(tile), ids.get(k, ""), point_of(sheet_name, points))
            if img is None:
                print(f"{sheet_name}: the image {ids.get(k)} is left out: run the workflow \"Street photos\"")
                continue
            sheet.paste(img, tile[:2])
            total += count
        sheet.save(SHEETS / sheet_name, quality=78, optimize=True)
        print(f"{sheet_name}: {total} boxes blurred")
    return 0


if __name__ == "__main__":
    sys.exit(main())
