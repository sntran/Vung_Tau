"""Tests for photos.py, the street photos of Mapillary (plan 0009, R5e). No network."""

import json
import math

import photos


def varint(v):
    out = bytearray()
    while True:
        b = v & 0x7F
        v >>= 7
        if v:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def field(number, wire, payload):
    key = varint((number << 3) | wire)
    if wire == 0:
        return key + varint(payload)
    return key + varint(len(payload)) + payload


def zig(v):
    return (v << 1) ^ (v >> 63)


def tile_with(points, extent=4096):
    """A tile with one layer "image" and a point feature for each (id, x, y, is_pano)."""
    keys = [b"id", b"is_pano"]
    values = []
    features = b""
    for fid, x, y, pano in points:
        values.append(field(5, 0, fid))
        values.append(field(7, 0, 1 if pano else 0))
        tags = varint(0) + varint(len(values) - 2) + varint(1) + varint(len(values) - 1)
        geometry = varint((1 & 7) | (1 << 3)) + varint(zig(x)) + varint(zig(y))
        features += field(2, 2, field(1, 0, fid) + field(2, 2, tags) + field(3, 0, 1) + field(4, 2, geometry))
    layer = field(1, 2, b"image") + features
    for k in keys:
        layer += field(3, 2, k)
    for v in values:
        layer += field(4, 2, v)
    layer += field(5, 0, extent) + field(15, 0, 2)
    return field(3, 2, layer)


def test_decode_tile_reads_the_points_and_the_properties():
    data = tile_with([(4242424242424242, 100, 4000, False), (17, 2048, 2048, True)])
    layers = photos.decode_tile(data)
    points = layers["image"]
    assert len(points) == 2
    assert points[0]["properties"]["id"] == 4242424242424242
    assert points[0]["properties"]["is_pano"] is False
    assert (points[0]["x"], points[0]["y"]) == (100, 4000)
    assert points[1]["properties"]["is_pano"] is True


def test_the_tiles_of_the_play_area_and_their_positions():
    bbox = {"south": 10.30, "west": 107.05, "north": 10.42, "east": 107.13}
    tiles = photos.tile_range(bbox)
    assert 10 <= len(tiles) <= 40
    # Each corner of the box is in a tile of the list.
    for lon, lat in [(107.05, 10.42), (107.13, 10.30)]:
        assert any(
            photos.tile_lonlat(tx, ty, 0, 4096, 4096)[0] <= lon <= photos.tile_lonlat(tx, ty, 4096, 0, 4096)[0]
            and photos.tile_lonlat(tx, ty, 0, 4096, 4096)[1] <= lat <= photos.tile_lonlat(tx, ty, 4096, 0, 4096)[1]
            for tx, ty in tiles)


def test_a_row_of_the_index_has_no_url_and_the_time_of_vietnam():
    image = {"id": "123", "captured_at": 1548900000000, "computed_geometry": {"type": "Point", "coordinates": [107.07, 10.34]},
             "compass_angle": 370.0, "camera_type": "spherical", "sequence": "abc", "creator": {"username": "someone", "id": "9"},
             "thumb_1024_url": "https://example.invalid/x.jpg"}
    r = dict(zip(photos.COLUMNS, photos.row(image)))
    assert r["date"] == "2019-01-31T09:00"
    assert r["computed"] == 1 and r["compass"] == 10.0 and r["author"] == "someone"
    assert "http" not in json.dumps(r)


def test_the_direction_toward_a_point():
    # Game x is to the east, z to the south: the north is -z.
    assert math.isclose(photos.bearing(0, -1), 0.0)
    assert math.isclose(photos.bearing(1, 0), 90.0)
    assert math.isclose(photos.bearing(0, 1), 180.0)
    assert math.isclose(photos.angle_between(350, 10), 20.0)
    point = {"at": [10.0, 0.0], "look": "toward"}
    east = {"x": 0.0, "z": 0.0, "camera": "perspective", "compass": 80.0, "computed_compass": None}
    west = dict(east, compass=260.0)
    assert photos.looks(east, point)
    assert not photos.looks(west, point)
    assert photos.looks(dict(west, camera="spherical"), point)


def test_choose_spreads_the_years_and_the_sequences():
    images = []
    for k in range(10):
        images.append({"id": str(k), "date": "2019-01-20T10:00", "x": float(k), "z": 0.0, "camera": "perspective",
                       "compass": 0.0, "computed_compass": None, "sequence": "one", "author": "a"})
    images.append({"id": "100", "date": "2016-05-01T10:00", "x": 1.0, "z": 0.0, "camera": "perspective", "compass": 0.0,
                   "computed_compass": None, "sequence": "old", "author": "b"})
    images.append({"id": "200", "date": "2021-02-01T10:00", "x": 50.0, "z": 0.0, "camera": "perspective", "compass": 0.0,
                   "computed_compass": None, "sequence": "two", "author": "c"})
    point = {"id": "p", "at": [0.0, 0.0], "radius_m": 60, "look": "any", "max": 12}
    chosen, matched = photos.choose(images, point, [2017, 2021])
    assert matched == 11  # the image of 2016 is out
    assert [r["id"] for r in chosen] == ["0", "1", "200"]  # 2 of the sequence "one", and the image of 2021
    tet = dict(point, dates=[["2021-01-22", "2021-02-12"]])
    assert [r["id"] for r in photos.choose(images, tet, [2017, 2021])[0]] == ["200"]


def test_the_photo_points_are_correct():
    data = json.loads(photos.POINTS.read_text(encoding="utf-8"))
    ids = [p["id"] for p in data["points"]]
    assert len(ids) == len(set(ids))
    asked = {q for p in data["points"] for q in p["for"]}
    for question in ["Q21", "Q22", "Q23", "D-0026-21", "D-0026-22", "D-0026-24", "D-0026-25", "R18", "R19", "R20"]:
        assert question in asked, question
    for p in data["points"]:
        assert p["look"] in ("toward", "any") or isinstance(p["look"], list)
        for a, b in p.get("dates", []):
            assert a <= b
