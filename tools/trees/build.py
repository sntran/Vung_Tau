"""Makes the trees of plan 0020 (Real trees) from data/trees/types.json with
Blender as a Python module (bpy 5.2.3).

For each type and variant, assets/trees/TYPE_VARIANT.glb has two meshes:

- "near": the real wood and the real leaves (surfaces "wood" and "leaf").
- "mid": less wood and leaf cards (surfaces "wood" and "card"). A card is a
  flat picture of one leaf group, from TYPE_cards.png.

The far form is an impostor: TYPE_impostor.png and TYPE_impostor_normal.png
show each variant (a row) from 8 directions (the columns).

The vertex color of the near and mid meshes holds data, not a color:
R is a random value of the leaf (or of the card), G is how much the wind moves
the point (0 at the base of the trunk, 1 at the tips), B is the kind (0 wood,
0.5 leaf, 1 dead leaf or brown fruit), and A is the shade inside the crown
(1 outside, darker inside). The pictures hold the same data: R is the shade,
G the random value of the leaf, B the kind, and A the cover.

The normals of the leaves and the cards point half out of the crown, so all
three forms get almost the same light (R6).

Usage:

    python tools/trees/build.py [--only TYPE ...] [--out DIR]
    python tools/trees/build.py --check

The same values give the same files (R3). --check makes all files again in a
temporary folder and compares them with assets/trees: the meshes must be the
same, and the pictures can differ only in a few pixels (another processor can
round some values in another way).
"""

import argparse
import hashlib
import json
import math
import os
import random
import shutil
import sys
import tempfile

import bpy
import numpy as np
from mathutils import Matrix, Vector
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TYPES_PATH = os.path.join(ROOT, "data", "trees", "types.json")
OUT_DIR = os.path.join(ROOT, "assets", "trees")
UP = Vector((0.0, 0.0, 1.0))
# The part of the leaf normal that points out of the crown.
CROWN_NORMAL = 0.55
WOOD, LEAF, DEAD = 0.0, 0.5, 1.0


def srgb_to_linear(hex_color: str) -> tuple:
    value = hex_color.lstrip("#")
    result = []
    for i in range(3):
        c = int(value[2 * i:2 * i + 2], 16) / 255.0
        result.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(result)


# --- Mesh data -----------------------------------------------------------------

class Surface:
    """Triangles of one surface: positions, normals, data colors, and UVs."""

    def __init__(self):
        self.pos = []
        self.nrm = []
        self.col = []
        self.uv = []
        self.tris = []

    def vert(self, p, n, c, uv=(0.0, 0.0)) -> int:
        self.pos.append((p[0], p[1], p[2]))
        self.nrm.append((n[0], n[1], n[2]))
        self.col.append(c)
        self.uv.append(uv)
        return len(self.pos) - 1

    def tri(self, a, b, c):
        self.tris.append((a, b, c))

    @property
    def triangles(self) -> int:
        return len(self.tris)


class Tree:
    """What a generator makes: the wood, the leaf groups, the crown shape, and the wind."""

    def __init__(self, height):
        self.height = height
        self.tubes = []    # (points, radii, level)
        self.groups = []   # Group
        self.blobs = []    # (center, radius, kind, level): coconuts and the crown shaft
        self.crown_center = Vector((0, 0, height * 0.7))
        self.crown_radii = Vector((3.0, 3.0, 2.0))
        # The wind: points far from this axis move more.
        self.flex_top = Vector((0, 0, height))
        self.flex_reach = 4.0
        self.palm = False

    def flex(self, p: Vector) -> float:
        trunk = 0.18 * min(1.0, max(0.0, p.z / self.height)) ** 2
        if self.palm:
            out = (p - self.flex_top).length / self.flex_reach
        else:
            out = Vector((p.x, p.y, 0.0)).length / self.flex_reach
        return min(1.0, trunk + 0.82 * min(1.0, out) ** 1.4)

    def crown_e(self, p: Vector) -> float:
        d = p - self.crown_center
        r = self.crown_radii
        return math.sqrt((d.x / r.x) ** 2 + (d.y / r.y) ** 2 + (d.z / r.z) ** 2)

    def crown_normal(self, p: Vector) -> Vector:
        d = p - self.crown_center
        r = self.crown_radii
        n = Vector((d.x / (r.x * r.x), d.y / (r.y * r.y), d.z / (r.z * r.z)))
        if n.length < 1e-6:
            return UP.copy()
        return n.normalized()

    def shade(self, p: Vector) -> float:
        """Darker inside the crown, as the leaves shade each other."""
        e = self.crown_e(p)
        return 0.5 + 0.5 * min(1.0, max(0.0, (e - 0.25) / 0.75))


class Group:
    """A leaf group: a template in a frame. The template box maps to the frame
    axes ex (width) and ey (length), with the sizes sx and sy. ez is the normal."""

    def __init__(self, origin, ex, ey, sx, sy, template, cross=False, kind=LEAF, card_scale=1.0):
        self.origin = Vector(origin)
        ey = Vector(ey).normalized()
        ex = Vector(ex)
        ex = (ex - ey * ex.dot(ey))
        if ex.length < 1e-6:
            ex = ey.orthogonal()
        self.ex = ex.normalized()
        self.ey = ey
        self.ez = self.ex.cross(self.ey).normalized()
        self.sx = sx
        self.sy = sy
        self.template = template
        self.cross = cross
        self.kind = kind
        self.card_scale = card_scale

    def to_world(self, x, y, z) -> Vector:
        sz = (self.sx + self.sy) * 0.5
        return self.origin + self.ex * (x * self.sx) + self.ey * (y * self.sy) + self.ez * (z * sz)

    def dir_to_world(self, n) -> Vector:
        sz = (self.sx + self.sy) * 0.5
        v = self.ex * (n[0] / self.sx) + self.ey * (n[1] / self.sy) + self.ez * (n[2] / sz)
        return v.normalized() if v.length > 1e-9 else self.ez.copy()


# --- Templates -----------------------------------------------------------------

class Template:
    """Leaves in a unit box. Each leaf has its own random value. box is
    (x0, x1, y0, y1): the card covers it."""

    def __init__(self, box, kind=LEAF):
        self.box = box
        self.kind = kind
        self.pos = []
        self.nrm = []
        self.rnd = []
        self.tris = []

    def leaf_poly(self, pts, normal, rnd):
        """A leaf as a fan of triangles from the first point."""
        base = len(self.pos)
        for p in pts:
            self.pos.append(Vector(p))
            self.nrm.append(Vector(normal))
            self.rnd.append(rnd)
        for k in range(1, len(pts) - 1):
            self.tris.append((base, base + k, base + k + 1))

    def strip(self, pts, half_widths, side, normal, rnd):
        """A thin strip along the points (a leaflet, a needle, a pinna)."""
        base = len(self.pos)
        for p, w in zip(pts, half_widths):
            for s in (-1.0, 1.0):
                self.pos.append(Vector(p) + Vector(side) * (w * s))
                self.nrm.append(Vector(normal))
                self.rnd.append(rnd)
        for k in range(len(pts) - 1):
            a, b, c, d = base + 2 * k, base + 2 * k + 1, base + 2 * k + 3, base + 2 * k + 2
            self.tris.append((a, b, c))
            self.tris.append((a, c, d))


def leaf_outline(length, width, shape):
    """The points of a leaf from its base along +y: base, left side, tip, right side."""
    if shape == "obovate":       # bàng: wide near the tip
        prof = [(0.0, 0.0), (0.45, 0.25), (0.95, 0.62), (0.7, 0.9), (0.0, 1.0)]
    elif shape == "lance":       # frangipani, long narrow leaves
        prof = [(0.0, 0.0), (0.7, 0.2), (0.9, 0.55), (0.45, 0.85), (0.0, 1.0)]
    else:                        # elliptic
        prof = [(0.0, 0.0), (0.65, 0.18), (1.0, 0.5), (0.6, 0.82), (0.0, 1.0)]
    # Two points on each side: a leaf is 4 triangles.
    inner = prof[2:4] if shape == "obovate" else prof[1:3]
    left = [(-w * width * 0.5, y * length) for w, y in inner]
    right = [(w * width * 0.5, y * length) for w, y in reversed(inner)]
    return [(0.0, 0.0)] + left + [(0.0, length)] + right


def rosette_leaves(t: Template, r: random.Random, center, count, length, width, shape, lift, spread=1.0):
    """count leaves out from the center in the x-y plane, cupped up by lift."""
    for k in range(count):
        a = 2 * math.pi * k / count + r.uniform(-0.25, 0.25) * spread
        d = Vector((math.cos(a), math.sin(a), 0.0))
        side = Vector((-d.y, d.x, 0.0))
        ln = length * r.uniform(0.8, 1.15)
        rise = lift * r.uniform(0.5, 1.2)
        pts = []
        for x, y in leaf_outline(ln, width * ln / length, shape):
            u = y / ln
            pts.append(Vector(center) + d * y + side * x + Vector((0, 0, rise * u * u * ln - 0.06 * x * x / max(width, 1e-3))))
        n = (UP * 1.0 - d * rise * 0.8).normalized()
        t.leaf_poly(pts, n, r.random())


def template_rosette(seed, leaves, shape, lift=0.25, long=False) -> Template:
    """A group of leaves at the end of a twig (bàng, broadleaf, frangipani, scrub)."""
    r = random.Random(seed)
    t = Template((-0.5, 0.5, -0.5, 0.5))
    length, width = (0.48, 0.12) if long else (0.42, 0.24)
    rosette_leaves(t, r, (0.0, 0.0, 0.0), leaves, length, width, shape, lift)
    return t


def template_spray(seed, rosettes, leaves, shape, lift=0.2) -> Template:
    """A twig with some rosettes of leaves along it, in the box x -0.5..0.5, y 0..1."""
    r = random.Random(seed)
    t = Template((-0.5, 0.5, 0.0, 1.0))
    for i in range(rosettes):
        y = 0.25 + 0.6 * i / max(1, rosettes - 1) + r.uniform(-0.05, 0.05)
        x = r.uniform(-0.1, 0.1)
        rosette_leaves(t, r, (x, y, 0.02 * i), leaves, 0.26, 0.15, shape, lift)
    return t


def template_cluster(seed, twigs, leaves, leaf_length, leaf_width=0.45, leaf_triangles=2) -> Template:
    """A spray of many small leaves (report 0020, D-0020-02): a stem along y with
    short twigs to both sides, each with "leaves" small leaves, in the box
    x -0.5..0.5, y 0..1. A leaf is a diamond of 2 triangles, or 1 triangle (a
    narrow leaf from its wide base), so that more leaves cost the same. The
    crown is a mass of small leaves with gaps, not some large leaves."""
    r = random.Random(seed)
    t = Template((-0.5, 0.5, 0.0, 1.0))
    for i in range(twigs):
        y = 0.12 + 0.8 * (i + 0.5) / twigs + r.uniform(-0.03, 0.03)
        side = 1.0 if i % 2 else -1.0
        twig_len = r.uniform(0.25, 0.42) * (1.0 - 0.35 * y)
        d = Vector((side * r.uniform(0.75, 1.0), r.uniform(0.2, 0.6), 0.0)).normalized()
        base = Vector((r.uniform(-0.04, 0.04), y, 0.004 * i))
        for k in range(leaves):
            u = (k + 0.6) / leaves
            at = base + d * (twig_len * u) + Vector((0.0, 0.0, r.uniform(-0.02, 0.03)))
            # The leaves stand to both sides of the twig, toward the tip.
            turn = (1.0 if k % 2 else -1.0) * r.uniform(0.6, 1.1)
            ld = (d * math.cos(turn) + Vector((-d.y, d.x, 0.0)) * math.sin(turn)).normalized()
            ln = leaf_length * r.uniform(0.8, 1.2)
            wd = ln * leaf_width * 0.5
            sd = Vector((-ld.y, ld.x, 0.0))
            lift = Vector((0.0, 0.0, ln * r.uniform(0.05, 0.3)))
            if leaf_triangles == 1:
                pts = [at + sd * wd, at + ld * ln + lift, at - sd * wd]
            else:
                pts = [at, at + ld * (ln * 0.45) + sd * wd + lift * 0.5, at + ld * ln + lift,
                       at + ld * (ln * 0.45) - sd * wd + lift * 0.5]
            t.leaf_poly(pts, (UP * 1.0 - ld * 0.3).normalized(), r.random())
    return t


def template_palm_side(seed, pairs, dead=False) -> Template:
    """One side of a part of a palm frond: the rachis is on the y axis, the
    leaflets go out in +x and hang (the frame of the group gives the hang)."""
    r = random.Random(seed)
    t = Template((0.0, 1.0, 0.0, 1.12), DEAD if dead else LEAF)
    for k in range(pairs):
        y = (k + 0.5) / pairs + r.uniform(-0.01, 0.01)
        ln = r.uniform(0.85, 1.0) * (0.6 if dead else 1.0)
        # A small height step for each leaflet, so that crossing leaflets do not lie in one surface.
        pts = [Vector((ln * u, y + 0.1 * u, -0.25 * u * u + 0.003 * k)) for u in (0.0, 0.5, 1.0)]
        side = Vector((0.0, 1.0, 0.0))
        w = 0.026 if not dead else 0.018
        t.strip(pts, [w * 0.8, w, w * 0.15], side, (0.0, 0.0, 1.0), r.random())
    return t


def template_fan(seed, segments) -> Template:
    """A round fan leaf of a fan palm: pleated segments from the stem end."""
    r = random.Random(seed)
    t = Template((-1.0, 1.0, -0.2, 1.0))
    for k in range(segments):
        a0 = math.radians(-120 + 240 * k / segments)
        a1 = math.radians(-120 + 240 * (k + 1) / segments)
        am = (a0 + a1) / 2
        tip = 1.0 + r.uniform(-0.05, 0.05)
        pleat = 0.04 if k % 2 else -0.04
        pts = [Vector((0, 0, 0)), Vector((math.sin(a0) * 0.95, math.cos(a0) * 0.95, 0)),
               Vector((math.sin(am) * tip, math.cos(am) * tip, pleat)), Vector((math.sin(a1) * 0.95, math.cos(a1) * 0.95, 0))]
        t.leaf_poly(pts, (0, 0, 1), r.random())
        # The split tips droop.
        tp = Vector((math.sin(am) * (tip + 0.18), math.cos(am) * (tip + 0.18), -0.12))
        t.leaf_poly([pts[2] + Vector((0.01, 0, 0)), tp, pts[2] - Vector((0.01, 0, 0))], (0, 0, 1), r.random())
    return t


def template_tuft(seed, needles) -> Template:
    """A tuft of casuarina needles that hang down: the box x -0.5..0.5, y 0..1 (y is down the tuft)."""
    r = random.Random(seed)
    t = Template((-0.5, 0.5, 0.0, 1.0))
    for _ in range(needles):
        a = r.uniform(0, 2 * math.pi)
        out = Vector((math.cos(a) * r.uniform(0.1, 0.45), 0.0, math.sin(a) * 0.3))
        ln = r.uniform(0.6, 1.0)
        base = Vector((r.uniform(-0.12, 0.12), r.uniform(0.0, 0.15), r.uniform(-0.1, 0.1)))
        pts = [base, base + Vector((0, ln, 0)) + out * ln]
        t.strip(pts, [0.012, 0.004], (1.0, 0.0, 0.0), (0.0, 0.0, 1.0), r.random())
    return t


def template_bipinnate(seed, leaves, pairs) -> Template:
    """A group of fern-like flame tree leaves around the end of a twig."""
    r = random.Random(seed)
    t = Template((-0.5, 0.5, -0.5, 0.5))
    for i in range(leaves):
        a = 2 * math.pi * i / leaves + r.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        side = Vector((-d.y, d.x, 0.0))
        ln = r.uniform(0.38, 0.5)
        rnd = r.random()
        for k in range(pairs):
            # A small height step for each leaf, so that crossing leaves do not lie in one surface.
            p = d * (ln * (k + 1) / (pairs + 1)) + Vector((0, 0, -0.04 * ((k + 1) / pairs) ** 2 + 0.004 * i))
            pl = 0.13 * math.sin(math.pi * (k + 1) / (pairs + 1))
            for sg in (-1, 1):
                pd = (side * sg + d * 0.35).normalized()
                t.strip([p, p + pd * pl], [0.02, 0.006], d, (0, 0, 1), rnd)
    return t


def template_plume(seed, needles) -> Template:
    """A flat branchlet of the Norfolk pine: short needles on both sides of an axis on y."""
    r = random.Random(seed)
    t = Template((-0.5, 0.5, 0.0, 1.0))
    for k in range(needles):
        y = (k + 0.5) / needles
        for sg in (-1, 1):
            ln = 0.45 * (1.0 - 0.5 * y) * r.uniform(0.8, 1.1)
            d = Vector((sg * 0.9, 0.5, -0.2)).normalized()
            # Each needle a little higher than the one before: where needles cross,
            # the picture of the card then shows the same needle on each processor.
            p = Vector((0.0, y, 0.004 * k + (0.002 if sg > 0 else 0.0)))
            t.strip([p, p + d * ln], [0.07, 0.04], Vector((0, 1, 0)), (0, 0, 1), r.random())
    return t


# --- Geometry helpers ------------------------------------------------------------

def frame_of(d: Vector):
    a = d.orthogonal().normalized()
    return a, d.cross(a).normalized()


def lerp_path(pts, s):
    """The point at the part s (0..1) of a path of points."""
    k = s * (len(pts) - 1)
    j = min(int(k), len(pts) - 2)
    return pts[j].lerp(pts[j + 1], k - j), (pts[j + 1] - pts[j]).normalized()


def ellipsoid_reach(center, a, b, p, d):
    """The distance from p along d to the shell of an ellipsoid (radii a, a, b)."""
    lo, hi = 0.0, 40.0
    for _ in range(30):
        m = (lo + hi) / 2
        v = p + d * m - center
        if (v.x / a) ** 2 + (v.y / a) ** 2 + (v.z / b) ** 2 < 1:
            lo = m
        else:
            hi = m
    return lo


# --- Generators ------------------------------------------------------------------
# Each generator returns a Tree, and the templates of its type.

def templates_for(gen, v):
    """The templates of a generator: a list, the same for all variants."""
    if gen == "palm":
        pairs = v.get("leaflet_pairs_per_part", 12)
        return [template_palm_side(100 + i, pairs) for i in range(3)] + [template_palm_side(200, pairs - 3, dead=True)]
    if gen == "fan_palm":
        return [template_fan(110 + i, v.get("fan_segments", 22)) for i in range(3)]
    if gen in ("broadleaf", "scrub") and "leaf_cluster" in v:
        c = v["leaf_cluster"]
        return [template_cluster(170 + i, c["twigs"], c["leaves"], c["leaf_length"], c.get("leaf_width", 0.45),
                                 c.get("leaf_triangles", 2)) for i in range(3)]
    if gen in ("bang", "broadleaf", "scrub"):
        shape = v.get("leaf_shape", "obovate" if gen == "bang" else "elliptic")
        return [template_spray(120 + i, v.get("rosettes_per_spray", 3), v.get("leaves_per_rosette", 8), shape)
                for i in range(3)]
    if gen == "frangipani":
        return [template_rosette(130 + i, v.get("leaves_per_rosette", 12), "lance", lift=0.5, long=True) for i in range(3)]
    if gen == "casuarina":
        return [template_tuft(140 + i, v.get("needles_per_tuft", 26)) for i in range(3)]
    if gen == "flame":
        return [template_bipinnate(150 + i, v.get("leaves_per_group", 6), v.get("leaflet_pairs", 8)) for i in range(3)]
    if gen == "araucaria":
        return [template_plume(160 + i, v.get("needles_per_plume", 10)) for i in range(3)]
    raise ValueError(gen)


def gen_palm(v, seed, variant):
    r = random.Random(seed)
    height = r.uniform(*v["height"])
    lean = r.uniform(*v["lean"]) * (1 if variant % 2 == 0 else -1)
    tree = Tree(height)
    tree.palm = True
    n = 30
    pts, radii = [], []
    bend = r.uniform(0.1, 0.3)
    for i in range(n + 1):
        t = i / n
        pts.append(Vector((lean * t ** 1.6, bend * math.sin(t * 2.0), height * t)))
        radii.append(v["trunk_radius"] * (1 - 0.3 * t) + 0.12 * max(0, 0.06 - t) * 14)
    tree.tubes.append((pts, radii, 0))
    top = pts[-1]
    tree.blobs.append((top + Vector((0, 0, 0.15)), 0.24, WOOD, 0))
    for i in range(v.get("nuts", 10)):
        a = r.uniform(0, 2 * math.pi)
        p = top + Vector((math.cos(a) * 0.28, math.sin(a) * 0.28, -0.3 - r.uniform(0, 0.3)))
        tree.blobs.append((p, 0.12, DEAD if i % 3 == 0 else LEAF, 2))
    fronds = v["fronds"]
    dead_count = v.get("dead_fronds", 3)
    length = v["frond_length"]
    parts = v.get("frond_parts", 4)
    for i in range(fronds + dead_count):
        dead = i >= fronds
        az = i * 2.39996 + r.uniform(-0.1, 0.1)
        age = min(i, fronds - 1) / (fronds - 1)
        up = math.radians((150 + r.uniform(-10, 10)) if dead else (30 + 75 * age + r.uniform(-6, 6)))
        L = (length * 0.62 if dead else length) * r.uniform(0.93, 1.07)
        d0 = Vector((math.sin(up) * math.cos(az), math.sin(up) * math.sin(az), math.cos(up)))
        out = Vector((math.cos(az), math.sin(az), 0))
        side = out.cross(UP).normalized()
        seg = 12
        rach = []
        for k in range(seg + 1):
            s = k / seg
            droop = 0.0 if dead else (0.9 + 0.8 * age) * (s ** 2.0) * L * 0.55
            rach.append(top + d0 * (s * L) - Vector((0, 0, droop)))
        # The rachis is a thin tube of 3 sides (level 3), as a twig.
        tree.tubes.append((rach, [0.05 * (1 - k / seg) + 0.012 for k in range(seg + 1)], 3))
        start = 0.08
        for p_i in range(parts):
            s0 = start + (1 - start) * p_i / parts
            s1 = start + (1 - start) * (p_i + 1) / parts
            p0, tang = lerp_path(rach, s0)
            p1, _ = lerp_path(rach, s1)
            sm = (s0 + s1) / 2
            ll = (0.35 + 0.85 * math.sin(math.pi * min(1.0, sm * 1.1))) * (0.5 if dead else 1.0)
            hang = 1.6 if dead else (0.9 + 0.6 * age)
            for sgn in (-1, 1):
                sd = side * sgn
                dirv = (sd * 0.55 + tang * 0.25 + Vector((0, 0, -hang))).normalized()
                tpl = 3 if dead else r.randrange(3)
                tree.groups.append(Group(p0, dirv, p1 - p0, ll, (p1 - p0).length, tpl,
                                         kind=DEAD if dead else LEAF))
    tree.crown_center = top + Vector((0, 0, -0.8))
    tree.crown_radii = Vector((length * 0.9, length * 0.9, length * 0.55))
    tree.flex_top = top
    tree.flex_reach = length
    return tree


def gen_fan_palm(v, seed, variant):
    r = random.Random(seed)
    height = r.uniform(*v["height"])
    tree = Tree(height)
    tree.palm = True
    pts = [Vector((0.05 * math.sin(i), 0.04 * math.cos(i), height * i / 8)) for i in range(9)]
    tree.tubes.append((pts, [v["trunk_radius"] * (1.15 - 0.25 * i / 8) for i in range(9)], 0))
    top = pts[-1]
    for i in range(v["leaves"]):
        az = i * 2.39996 + r.uniform(-0.15, 0.15)
        # From up to a little below the horizon: the fans stand out on their stems
        # (report 0020, D-0020-04: the crown was a round mass).
        up = math.radians(v.get("up_from", 15) + v.get("up_range", 85) * (i / v["leaves"]) + r.uniform(-8, 8))
        d = Vector((math.sin(up) * math.cos(az), math.sin(up) * math.sin(az), math.cos(up)))
        stem_len = v["stem_length"] * r.uniform(0.8, 1.2)
        end = top + d * stem_len - Vector((0, 0, 0.1 * stem_len * math.sin(up)))
        tree.tubes.append(([top, (top + end) / 2, end], [0.03, 0.025, 0.02], 1))
        out = Vector((math.cos(az), math.sin(az), 0))
        rad = v["leaf_radius"] * r.uniform(0.85, 1.1)
        # The fan faces up and out, along its stem.
        ey = (d + UP * v.get("fan_up", 0.3)).normalized()
        tree.groups.append(Group(end, out.cross(UP), ey, rad, rad, r.randrange(3)))
    tree.crown_center = top + Vector((0, 0, 0.3))
    reach = v["stem_length"] + v["leaf_radius"]
    tree.crown_radii = Vector((reach, reach, reach * 0.8))
    tree.flex_top = top
    tree.flex_reach = reach
    return tree


def gen_crowned(v, seed, variant, bang_style):
    """bàng and the broadleaf trees: a trunk that forks into leaders, layers of
    branches out to the shell of the crown, and sprays of leaves at the ends."""
    r = random.Random(seed)
    height = r.uniform(*v["height"])
    tree = Tree(height)
    fork = v["fork"] * r.uniform(0.9, 1.1)
    a = v["crown_width"] / 2 * r.uniform(0.9, 1.08)
    b = v["crown_height"] / 2 * r.uniform(0.92, 1.08)
    centre = Vector((0, 0, height - b))
    lean = Vector((r.uniform(-1, 1), r.uniform(-1, 1), 0)) * v.get("lean", 0.15)
    tpts = [Vector((0.05 * math.sin(i), 0.04 * math.cos(i), fork * i / 5)) + lean * (i / 5) for i in range(6)]
    tr = v["trunk_radius"]
    tree.tubes.append((tpts, [tr * (1 - 0.12 * i / 5) + (tr * 0.4 if i == 0 else 0) for i in range(6)], 0))
    leaders = v["leaders"]
    sprays_per_branch = v.get("sprays_per_branch", 3)
    spray_len = v.get("spray_length", 1.3) * v.get("leaf_size", 1.0)
    layers = v.get("layers", 6)
    branches_per_layer = v.get("branches_per_layer", 3)
    for li in range(leaders):
        az = li * 2 * math.pi / leaders + r.uniform(-0.3, 0.3)
        out = Vector((math.cos(az), math.sin(az), 0))
        spread = min(a * 0.45, max(0.4, a - 1.5)) * r.uniform(0.5, 0.8)
        top_h = height - b * r.uniform(0.25, 0.55)
        lp = []
        for k in range(6):
            s = k / 5
            lp.append(tpts[-1] + out * (spread * s ** 1.2) + Vector((0, 0, (top_h - fork) * s)))
        tree.tubes.append((lp, [tr * 0.62 * (1 - 0.8 * k / 5) + 0.03 for k in range(6)], 1))
        for k in range(layers):
            s = 0.25 + 0.75 * k / max(1, layers - 1)
            base, _ = lerp_path(lp, s)
            if (base - centre).z < -b * 0.95:
                continue
            for w in range(branches_per_layer + (1 if k == layers - 1 else 0)):
                baz = az + r.uniform(-1.6, 1.6)
                d = Vector((math.cos(baz), math.sin(baz), r.uniform(0.05, 0.35) + (0.4 if k == layers - 1 else 0))).normalized()
                L = ellipsoid_reach(centre, a, b, base, d) * r.uniform(0.72, 0.92)
                if L < 0.7:
                    continue
                bp = [base + d * (L * u / 3) + Vector((0, 0, 0.2 * math.sin(math.pi * u / 3))) for u in range(4)]
                rad = 0.07 * (1.2 - 0.5 * s) * min(1.5, tr / 0.3)
                tree.tubes.append((bp, [rad * (1 - 0.8 * u / 3) + 0.01 for u in range(4)], 2))
                side = d.cross(UP).normalized()
                for u in range(sprays_per_branch):
                    tip = u == sprays_per_branch - 1
                    q, tang = lerp_path(bp, 0.45 + 0.55 * (u + 1) / sprays_per_branch)
                    sg = 1 if u % 2 else -1
                    sd = tang if tip else (tang * 0.5 + side * sg * r.uniform(0.6, 1.0) + UP * r.uniform(0.1, 0.4)).normalized()
                    sd = (sd + UP * 0.5).normalized()
                    length = spray_len * r.uniform(0.8, 1.2)
                    # The spray faces up, a little to the outside, with a random roll.
                    ex = sd.cross(UP)
                    if ex.length < 1e-3:
                        ex = side
                    ex = (ex.normalized() * math.cos(r.uniform(-0.7, 0.7)) + UP * math.sin(r.uniform(-0.7, 0.7)))
                    tree.groups.append(Group(q - sd * 0.1, ex, sd, length * 0.75, length, r.randrange(3)))
                    if not tip:
                        tree.tubes.append(([q - sd * 0.15, q + sd * 0.35], [0.018, 0.008], 3))
    tree.crown_center = centre
    tree.crown_radii = Vector((a, a, b))
    tree.flex_reach = a
    return tree


def gen_frangipani(v, seed, variant):
    r = random.Random(seed)
    height = r.uniform(*v["height"])
    tree = Tree(height)
    first = height * 0.3
    tr = v["trunk_radius"]
    trunk = [Vector((0.03 * math.sin(i), 0, first * i / 3)) for i in range(4)]
    tree.tubes.append((trunk, [tr * 1.3, tr * 1.05, tr, tr * 0.95], 0))
    ends = []

    def grow(p, d, length, radius, depth):
        q = p + d * length
        mid = (p + q) / 2 + Vector((0, 0, 0.08 * length))
        tree.tubes.append(([p, mid, q], [radius, radius * 0.9, radius * 0.8], min(depth, 3)))
        if depth >= v["forks"]:
            ends.append((q, d))
            return
        n = 2 if r.random() < 0.7 else 3
        for k in range(n):
            az = r.uniform(0, 2 * math.pi)
            nd = (d * 0.9 + Vector((math.cos(az), math.sin(az), 0)) * 0.7 + UP * 0.25).normalized()
            grow(q, nd, length * r.uniform(0.7, 0.85), radius * 0.72, depth + 1)

    for k in range(3):
        az = 2 * math.pi * k / 3 + r.uniform(-0.3, 0.3)
        grow(trunk[-1], (Vector((math.cos(az), math.sin(az), 0)) * 0.55 + UP).normalized(),
             (height - first) * 0.42, tr * 0.7, 1)
    for q, d in ends:
        size = v.get("leaf_size", 1.0) * r.uniform(0.85, 1.1) * 0.9
        ex = d.orthogonal().normalized()
        tree.groups.append(Group(q + d * 0.05, ex, d.cross(ex), size, size, r.randrange(3)))
    zs = [q.z for q, _ in ends] or [height]
    rx = max([Vector((q.x, q.y, 0)).length for q, _ in ends] or [1.5]) + 0.5
    tree.crown_center = Vector((0, 0, sum(zs) / len(zs)))
    tree.crown_radii = Vector((rx, rx, max(1.0, height - first) * 0.5))
    tree.flex_reach = rx
    tree.height = max(height, max(zs) + 0.4)
    return tree


def gen_casuarina(v, seed, variant):
    r = random.Random(seed)
    height = r.uniform(*v["height"])
    tree = Tree(height)
    lean = r.uniform(0.3, 0.9) * (1 if variant % 2 else -1)
    tp = [Vector((lean * (i / 12) ** 2, 0.2 * math.sin(i * 0.5), height * i / 12)) for i in range(13)]
    tree.tubes.append((tp, [v["trunk_radius"] * (1 - 0.85 * i / 12) + 0.02 for i in range(13)], 0))
    branches = v["branches"]
    tufts = v.get("tufts_per_branch", 3)
    for i in range(branches):
        if r.random() < 0.3:
            continue
        f = 0.42 + 0.56 * i / (branches - 1)
        p, _ = lerp_path(tp, f)
        az = i * 2.39996 + r.uniform(-0.3, 0.3)
        out = Vector((math.cos(az), math.sin(az), 0))
        L = (3.4 * (1 - f) + 1.0) * r.uniform(0.45, 1.35)
        rise = r.uniform(0.9, 1.6)
        bp = [p + out * (L * u / 4) + Vector((0, 0, rise * L * 0.35 * (u / 4) - 0.25 * L * (u / 4) ** 2)) for u in range(5)]
        tree.tubes.append((bp, [0.04 * (1 - 0.7 * u / 4) + 0.008 for u in range(5)], 2))
        for k in range(tufts):
            if r.random() < 0.12:
                continue
            q, _ = lerp_path(bp, 0.3 + 0.7 * (k + 1) / tufts)
            q = q + Vector((r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4), r.uniform(-0.1, 0.3)))
            down = (Vector((0, 0, -1)) + out * r.uniform(0.1, 0.4)).normalized()
            size = v.get("tuft_size", 1.0) * r.uniform(0.8, 1.2)
            tree.groups.append(Group(q, out.cross(UP), down, size * 1.1, size * 0.9, r.randrange(3), cross=True))
    tree.crown_center = Vector((lean * 0.5, 0, height * 0.72))
    tree.crown_radii = Vector((2.4, 2.4, height * 0.3))
    tree.flex_reach = 3.0
    return tree


def gen_flame(v, seed, variant):
    r = random.Random(seed)
    height = r.uniform(*v["height"])
    tree = Tree(height)
    fork = v["fork"] * r.uniform(0.9, 1.1)
    tr = v["trunk_radius"]
    tp = [Vector((0.04 * math.sin(i), 0, fork * i / 4)) for i in range(5)]
    tree.tubes.append((tp, [tr + (tr * 0.4 if i == 0 else 0) - 0.1 * tr * i for i in range(5)], 0))
    A = v["crown_width"] / 2 * r.uniform(0.9, 1.05)
    B = v["crown_height"] / 2
    centre = Vector((0, 0, height - B))
    limbs = v.get("limbs", 5)
    twigs = v.get("twigs_per_limb", 12)
    for li in range(limbs):
        az = li * 2 * math.pi / limbs + r.uniform(-0.3, 0.3)
        out = Vector((math.cos(az), math.sin(az), 0))
        end = centre + out * A * r.uniform(0.55, 0.7) + Vector((0, 0, r.uniform(-0.3, 0.6)))
        lp = [tp[-1].lerp(end, k / 8) + Vector((0, 0, 0.9 * math.sin(math.pi * k / 8))) for k in range(9)]
        tree.tubes.append((lp, [tr * 0.6 * (1 - 0.7 * k / 8) for k in range(9)], 1))
        for k in range(twigs):
            base, _ = lerp_path(lp, 0.35 + 0.65 * r.random())
            d = (out * 0.5 + Vector((r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(0.2, 0.6)))).normalized()
            q = base + d * r.uniform(0.8, 2.2)
            w = q - centre
            e = math.sqrt((w.x / A) ** 2 + (w.y / A) ** 2 + (w.z / B) ** 2)
            if e > 0.95:
                q = centre + w * (0.95 / e)
            tree.tubes.append(([base, q], [0.05, 0.015], 2))
            size = v.get("group_size", 1.5) * r.uniform(0.85, 1.15)
            hd = Vector((d.x, d.y, 0.0))
            hd = hd.normalized() if hd.length > 1e-3 else out
            ey = (hd + UP * 0.15).normalized()
            tree.groups.append(Group(q, ey.cross(UP), ey, size, size, r.randrange(3)))
    tree.crown_center = centre
    tree.crown_radii = Vector((A, A, B))
    tree.flex_reach = A
    return tree


def gen_araucaria(v, seed, variant):
    r = random.Random(seed)
    height = r.uniform(*v["height"])
    tree = Tree(height)
    tp = [Vector((0.03 * math.sin(i * 0.7), 0.02 * math.cos(i), height * i / 10)) for i in range(11)]
    tree.tubes.append((tp, [v["trunk_radius"] * (1 - 0.9 * i / 10) + 0.02 for i in range(11)], 0))
    tiers = v["tiers"]
    per_tier = v.get("branches_per_tier", 5)
    width = v.get("crown_width", 6.0) / 2
    for i in range(tiers):
        f = 0.18 + 0.8 * i / (tiers - 1)
        p, _ = lerp_path(tp, f)
        L = max(0.4, width * (1 - f) ** 0.9 * r.uniform(0.85, 1.1))
        for k in range(per_tier):
            az = 2 * math.pi * k / per_tier + i * 0.6 + r.uniform(-0.15, 0.15)
            out = Vector((math.cos(az), math.sin(az), 0))
            bp = [p + out * (L * u / 3) + Vector((0, 0, 0.12 * L * (u / 3) - 0.1 * L * (u / 3) ** 2)) for u in range(4)]
            tree.tubes.append((bp, [0.05 * (1 - 0.7 * u / 3) + 0.008 for u in range(4)], 2))
            parts = max(1, int(L / 1.1 + 0.5))
            for j in range(parts):
                q, tang = lerp_path(bp, j / parts)
                side = tang.cross(UP).normalized()
                ln = L / parts * 1.15
                # The plumes rise a little to the tip and turn around the branch.
                roll = r.uniform(-0.6, 0.6)
                tree.groups.append(Group(q, side * math.cos(roll) + UP * math.sin(roll), tang + UP * 0.3,
                                         v.get("plume_width", 1.0), ln, r.randrange(3), cross=bool(v.get("card_cross", False))))
    tree.crown_center = Vector((0, 0, height * 0.55))
    tree.crown_radii = Vector((width, width, height * 0.5))
    tree.flex_reach = width + 1.0
    return tree


def gen_scrub(v, seed, variant):
    r = random.Random(seed)
    height = r.uniform(*v["height"])
    tree = Tree(height)
    a = v["crown_width"] / 2 * r.uniform(0.85, 1.15)
    b = height / 2
    centre = Vector((0, 0, b * 1.05))
    spray_len = v.get("spray_length", 1.0) * v.get("leaf_size", 1.0)
    for k in range(v["stems"]):
        az = 2 * math.pi * k / v["stems"] + r.uniform(-0.4, 0.4)
        out = Vector((math.cos(az), math.sin(az), 0))
        top = Vector((0, 0, 0)) + out * a * r.uniform(0.2, 0.5) + Vector((0, 0, height * r.uniform(0.6, 0.85)))
        st = [Vector((0, 0, 0)) + out * 0.1, top * 0.5 + out * 0.15, top]
        tree.tubes.append((st, [0.05, 0.035, 0.015], 1))
    for k in range(v.get("sprays", 26)):
        # Points on the upper part of the dome, facing out.
        u = r.uniform(0, 2 * math.pi)
        w = r.uniform(-0.15, 1.0)
        n = Vector((math.cos(u) * math.sqrt(1 - w * w), math.sin(u) * math.sqrt(1 - w * w), w))
        q = centre + Vector((n.x * a, n.y * a, n.z * b)) * r.uniform(0.75, 0.95)
        q.z = max(q.z, 0.25)
        tangent = n.cross(UP)
        if tangent.length < 1e-3:
            tangent = Vector((1, 0, 0))
        ey = (tangent.cross(n) * -1.0 + UP * 0.4).normalized()
        length = spray_len * r.uniform(0.8, 1.2)
        tree.groups.append(Group(q - ey * length * 0.4, tangent, ey, length * 0.8, length, r.randrange(3),
                                 cross=bool(v.get("card_cross", False))))
    tree.crown_center = centre
    tree.crown_radii = Vector((a, a, b))
    tree.flex_reach = a
    return tree


GENERATORS = {
    "palm": gen_palm,
    "fan_palm": gen_fan_palm,
    "bang": lambda v, s, i: gen_crowned(v, s, i, True),
    "broadleaf": lambda v, s, i: gen_crowned(v, s, i, False),
    "frangipani": gen_frangipani,
    "casuarina": gen_casuarina,
    "flame": gen_flame,
    "araucaria": gen_araucaria,
    "scrub": gen_scrub,
}

# The sides of the tubes of each level (trunk, leaders, branches, twigs) in the near and the middle form.
NEAR_SIDES = (12, 8, 4, 3)
MID_SIDES = (4, 3, 3, 0)


# --- Build the meshes -----------------------------------------------------------

def add_tube(surf: Surface, tree: Tree, pts, radii, sides):
    rings = []
    length = 0.0
    for i, p in enumerate(pts):
        if i:
            length += (pts[i] - pts[i - 1]).length
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a, b = frame_of(d)
        ring = []
        for k in range(sides + 1):
            t = 2 * math.pi * k / sides
            n = a * math.cos(t) + b * math.sin(t)
            q = p + n * radii[i]
            shade = min(1.0, 0.45 + 0.55 * min(1.0, q.z / max(1.0, tree.crown_center.z - tree.crown_radii.z)))
            ring.append(surf.vert(q, n, (0.0, tree.flex(q), WOOD, shade), (k / sides, length / 1.5)))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            surf.tri(r0[k], r0[k + 1], r1[k + 1])
            surf.tri(r0[k], r1[k + 1], r1[k])


def add_blob(surf: Surface, tree: Tree, center, radius, kind, rings=4, sides=8):
    verts = []
    for i in range(rings + 1):
        phi = math.pi * i / rings
        row = []
        for k in range(sides + 1):
            t = 2 * math.pi * k / sides
            n = Vector((math.sin(phi) * math.cos(t), math.sin(phi) * math.sin(t), math.cos(phi)))
            q = center + n * radius
            col = (0.37 if kind != WOOD else 0.0, tree.flex(q), kind, tree.shade(q) if kind != WOOD else 0.8)
            row.append(surf.vert(q, n, col))
        verts.append(row)
    for r0, r1 in zip(verts, verts[1:]):
        for k in range(sides):
            surf.tri(r0[k], r1[k], r1[k + 1])
            surf.tri(r0[k], r1[k + 1], r0[k + 1])


def leaf_normal(tree: Tree, p: Vector, n: Vector) -> Vector:
    c = tree.crown_normal(p)
    if n.dot(c) < 0:
        n = -n
    return (n * (1 - CROWN_NORMAL) + c * CROWN_NORMAL).normalized()


def add_group_leaves(surf: Surface, tree: Tree, g: Group, t: Template, rng: random.Random):
    base = []
    offset = rng.random()
    for p, n, rnd in zip(t.pos, t.nrm, t.rnd):
        q = g.to_world(p.x, p.y, p.z)
        nn = leaf_normal(tree, q, g.dir_to_world(n))
        kind = g.kind if g.kind != LEAF else t.kind
        base.append(surf.vert(q, nn, ((rnd + offset) % 1.0, tree.flex(q), kind, tree.shade(q))))
    for a, b, c in t.tris:
        surf.tri(base[a], base[b], base[c])


def add_card(surf: Surface, tree: Tree, g: Group, t: Template, cell, cells, rng: random.Random, scale=1.0):
    """A quad over the template box. The UVs map the box to its atlas cell."""
    x0, x1, y0, y1 = t.box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 * scale, (y1 - y0) / 2 * scale
    rnd = rng.random()
    corners = [(cx - hx, cy - hy, 0.0, 1.0), (cx + hx, cy - hy, 1.0, 1.0), (cx + hx, cy + hy, 1.0, 0.0),
               (cx - hx, cy + hy, 0.0, 0.0)]
    planes = [(g.ex, g.ey)]
    if g.cross:
        planes.append((g.ez, g.ey))
    for ax, ay in planes:
        ids = []
        for x, y, u, w in corners:
            q = g.origin + ax * (x * g.sx) + ay * (y * g.sy)
            n = leaf_normal(tree, q, ax.cross(ay))
            # Blender UVs start at the bottom; glTF and Godot UVs at the top.
            ids.append(surf.vert(q, n, (rnd, tree.flex(q), LEAF, tree.shade(q)), ((cell + u) / cells, 1.0 - w)))
        surf.tri(ids[0], ids[1], ids[2])
        surf.tri(ids[0], ids[2], ids[3])


def build_forms(tree: Tree, templates, seed, max_cards, card_scale=1.0):
    rng = random.Random(seed * 7 + 1)
    near_wood, near_leaf = Surface(), Surface()
    mid_wood, mid_card = Surface(), Surface()
    for pts, radii, level in tree.tubes:
        add_tube(near_wood, tree, pts, radii, NEAR_SIDES[level])
        if MID_SIDES[level] and max(radii) >= (0.09 if level >= 2 else 0.03):
            # The middle form has fewer rings too: the trunk 4 parts, the others 2.
            step = max(1, len(pts) // (4 if level == 0 else 2))
            idx = list(range(0, len(pts), step))
            if idx[-1] != len(pts) - 1:
                idx.append(len(pts) - 1)
            add_tube(mid_wood, tree, [pts[i] for i in idx], [radii[i] for i in idx], MID_SIDES[level])
    for center, radius, kind, level in tree.blobs:
        add_blob(near_leaf if kind != WOOD else near_wood, tree, center, radius, kind)
        if level == 0:
            add_blob(mid_wood, tree, center, radius, kind, 3, 5)
    for g in tree.groups:
        add_group_leaves(near_leaf, tree, g, templates[g.template], rng)
    # The middle form: every k-th group, a little larger, so the cover stays the same.
    keep = max(1, math.ceil(len(tree.groups) / max_cards))
    scale = (math.sqrt(keep) if keep > 1 else 1.0) * card_scale
    for i, g in enumerate(tree.groups):
        if i % keep:
            continue
        add_card(mid_card, tree, g, templates[g.template], g.template, len(templates), rng, scale)
    return {"near": [("wood", near_wood), ("leaf", near_leaf)], "mid": [("wood", mid_wood), ("card", mid_card)]}


# --- Blender ---------------------------------------------------------------------

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def make_object(name, surfaces, materials, render_data=False):
    """One Blender object from the surfaces (each surface gets its material)."""
    pos, nrm, col, uv, tris, mats = [], [], [], [], [], []
    for mi, (_, s) in enumerate(surfaces):
        base = len(pos)
        pos += s.pos
        nrm += s.nrm
        col += s.col
        uv += s.uv
        tris += [(a + base, b + base, c + base) for a, b, c in s.tris]
        mats += [mi] * len(s.tris)
    me = bpy.data.meshes.new(name)
    me.from_pydata(pos, [], tris)
    for m in materials:
        me.materials.append(m)
    me.polygons.foreach_set("material_index", mats)
    me.polygons.foreach_set("use_smooth", [True] * len(tris))
    attr = me.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
    attr.data.foreach_set("color", np.asarray(col, dtype=np.float32).ravel())
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = 0
    layer = me.uv_layers.new(name="UVMap")
    loop_vert = np.zeros(len(me.loops), dtype=np.int32)
    me.loops.foreach_get("vertex_index", loop_vert)
    uv_arr = np.asarray(uv, dtype=np.float32)
    layer.data.foreach_set("uv", uv_arr[loop_vert].ravel())
    if render_data:
        # For the pictures only (not exported): the normal as a vector attribute.
        na = me.attributes.new("Nrm", 'FLOAT_VECTOR', 'POINT')
        na.data.foreach_set("vector", np.asarray(nrm, dtype=np.float32).ravel())
    me.normals_split_custom_set_from_vertices(nrm)
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def plain_materials(names):
    return [bpy.data.materials.get(n) or bpy.data.materials.new(n) for n in names]


def export_glb(path, forms):
    reset_scene()
    for form, surfaces in forms.items():
        make_object(form, surfaces, plain_materials([n for n, _ in surfaces]))
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_vertex_color='ACTIVE', export_normals=True,
                              export_tangents=False, export_materials='EXPORT', export_yup=True, export_apply=False,
                              export_image_format='NONE', export_extras=False, export_cameras=False, export_lights=False)


def emission_material(name, mode):
    """An emission material for the pictures: "data" shows the data (shade, random,
    kind) and "normal" shows the normal in Godot axes (x, z, -y of Blender)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for node in list(nt.nodes):
        nt.nodes.remove(node)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    em = nt.nodes.new('ShaderNodeEmission')
    em.inputs['Strength'].default_value = 1.0
    nt.links.new(em.outputs[0], out.inputs['Surface'])
    attr = nt.nodes.new('ShaderNodeAttribute')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    comb = nt.nodes.new('ShaderNodeCombineXYZ')
    if mode == "data":
        attr.attribute_name = "Col"
        # Col is (random, flex, kind, shade); the picture is (shade, random, kind).
        sep_c = nt.nodes.new('ShaderNodeSeparateColor')
        nt.links.new(attr.outputs['Color'], sep_c.inputs[0])
        nt.links.new(attr.outputs['Alpha'], comb.inputs[0])
        nt.links.new(sep_c.outputs[0], comb.inputs[1])
        nt.links.new(sep_c.outputs[2], comb.inputs[2])
    else:
        attr.attribute_name = "Nrm"
        nt.links.new(attr.outputs['Vector'], sep.inputs[0])
        neg = nt.nodes.new('ShaderNodeMath')
        neg.operation = 'MULTIPLY'
        neg.inputs[1].default_value = -1.0
        nt.links.new(sep.outputs[1], neg.inputs[0])
        g = nt.nodes.new('ShaderNodeCombineXYZ')
        nt.links.new(sep.outputs[0], g.inputs[0])
        nt.links.new(sep.outputs[2], g.inputs[1])
        nt.links.new(neg.outputs[0], g.inputs[2])
        ma = nt.nodes.new('ShaderNodeVectorMath')
        ma.operation = 'MULTIPLY_ADD'
        ma.inputs[1].default_value = (0.5, 0.5, 0.5)
        ma.inputs[2].default_value = (0.5, 0.5, 0.5)
        nt.links.new(g.outputs[0], ma.inputs[0])
        comb = ma
    nt.links.new(comb.outputs[0], em.inputs['Color'])
    return m


def render_setup(width, height, samples=16):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.cycles.use_adaptive_sampling = False
    sc.cycles.use_denoising = False
    sc.cycles.seed = 1
    sc.cycles.max_bounces = 0
    sc.cycles.filter_width = 1.0
    sc.render.film_transparent = True
    sc.render.resolution_x = width
    sc.render.resolution_y = height
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.render.image_settings.color_depth = '8'
    sc.view_settings.view_transform = 'Raw'
    sc.view_settings.look = 'None'
    sc.display_settings.display_device = 'sRGB'
    sc.render.threads_mode = 'FIXED'
    sc.render.threads = 1
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[1].default_value = 0.0
    sc.world = world
    return sc


def ortho_camera(center, scale, rotation):
    cam = bpy.data.cameras.new("c")
    cam.type = 'ORTHO'
    cam.ortho_scale = scale
    cam.clip_start = 0.01
    cam.clip_end = 1000.0
    obj = bpy.data.objects.new("c", cam)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = center
    obj.rotation_euler = rotation
    bpy.context.scene.camera = obj


def render_to(path):
    sc = bpy.context.scene
    tmp = path + ".tmp.png"
    sc.render.filepath = tmp
    bpy.ops.render.render(write_still=True)
    # Save again without metadata, so the file depends only on the pixels.
    img = Image.open(tmp)
    img.load()
    img.save(path, optimize=False)
    os.remove(tmp)
    return np.asarray(img, dtype=np.float32) / 255.0


def template_surface(t: Template) -> Surface:
    s = Surface()
    base = []
    for p, n, rnd in zip(t.pos, t.nrm, t.rnd):
        base.append(s.vert(p, n, (rnd, 0.0, t.kind, 1.0)))
    for a, b, c in t.tris:
        s.tri(base[a], base[b], base[c])
    return s


def render_cards(path, templates, cell_px):
    """The card atlas: one cell for each template, seen from above."""
    reset_scene()
    render_setup(cell_px * len(templates), cell_px, samples=16)
    mat = emission_material("data", "data")
    for i, t in enumerate(templates):
        x0, x1, y0, y1 = t.box
        obj = make_object("t%d" % i, [("leaf", template_surface(t))], [mat])
        # The box goes to the cell [i, i + 1] x [0, 1], in a scale of its own on x and y.
        obj.scale = (1.0 / (x1 - x0), 1.0 / (y1 - y0), 0.25)
        obj.location = (i - x0 / (x1 - x0), -y0 / (y1 - y0), 0.0)
    n = len(templates)
    ortho_camera(Vector((n / 2, 0.5, 10.0)), float(n), (0.0, 0.0, 0.0))
    pixels = render_to(path)
    # The camera looks down: the image top is +y, the cell row v = 0 at the top. The card UVs use the same.
    return pixels


def render_impostor(path_data, path_normal, near_objects, cell_px, views):
    """The impostor atlas: one row for each variant, one column for each view."""
    reset_scene()
    rows = len(near_objects)
    render_setup(cell_px * views, cell_px * rows, samples=16)
    data = emission_material("data", "data")
    normal = emission_material("normal", "normal")
    sizes = []
    meshes = []
    for v, (surfaces, size) in enumerate(near_objects):
        obj = make_object("v%d" % v, surfaces, [data] * len(surfaces), render_data=True)
        meshes.append(obj)
        sizes.append(size)
    for v, obj in enumerate(meshes):
        size = sizes[v]
        for j in range(views):
            copy = obj if j == 0 else obj.copy()
            if j:
                bpy.context.scene.collection.objects.link(copy)
            copy.rotation_euler = (0.0, 0.0, -2 * math.pi * j / views)
            copy.scale = (1.0 / size, 1.0 / size, 1.0 / size)
            # The base of the trunk at the bottom middle of the cell. Row 0 is at the top.
            copy.location = (j + 0.5, 0.0, rows - 1 - v)
    ortho_camera(Vector((views / 2, -50.0, rows / 2)), float(views), (math.pi / 2, 0.0, 0.0))
    pixels_data = render_to(path_data)
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            for slot in obj.material_slots:
                slot.material = normal
    pixels_normal = render_to(path_normal)
    return pixels_data, pixels_normal


# --- Main --------------------------------------------------------------------------

def file_hash(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def surfaces_extent(surfaces):
    pts = np.asarray([p for _, s in surfaces for p in s.pos], dtype=np.float64)
    radius = float(np.sqrt(pts[:, 0] ** 2 + pts[:, 1] ** 2).max())
    return radius, float(pts[:, 2].max())


def mean_leaf_cover(pixels):
    """The mean data of the covered pixels: for the R6 check of the game."""
    a = pixels[..., 3]
    cover = a > 0.5
    if not cover.any():
        return [0.0, 0.0, 0.0]
    return [round(float(pixels[..., i][cover].mean()), 4) for i in range(3)]


def build_type(name, v, settings, out_dir, script_hash):
    gen = v["generator"]
    templates = templates_for(gen, v)
    cell_px = settings["cards"]["cell_px"]
    views = settings["impostor"]["views"]
    imp_px = settings["impostor"]["cell_px"]
    max_cards = v.get("max_cards", 90)
    entry = {"generator": gen, "variants": [], "templates": len(templates)}
    near_for_impostor = []
    for i, seed in enumerate(v["seeds"][:settings["variants"]]):
        tree = GENERATORS[gen](v, seed, i)
        forms = build_forms(tree, templates, seed, max_cards, float(v.get("card_scale", 1.0)))
        path = os.path.join(out_dir, "%s_%d.glb" % (name, i + 1))
        export_glb(path, forms)
        radius, top = surfaces_extent(forms["near"])
        size = max(2 * radius, top) * 1.03
        near_for_impostor.append((forms["near"], size))
        entry["variants"].append({
            "file": os.path.basename(path),
            "near_triangles": sum(s.triangles for _, s in forms["near"]),
            "mid_triangles": sum(s.triangles for _, s in forms["mid"]),
            "cards": forms["mid"][1][1].triangles // 2,
            "height": round(top, 2),
            "radius": round(radius, 2),
            "impostor_size": round(size, 3),
            "sha256": file_hash(path),
        })
        print("%s %d: near %d triangles, middle %d triangles, %.1f m high, %.1f m wide" % (
            name, i + 1, entry["variants"][-1]["near_triangles"], entry["variants"][-1]["mid_triangles"], top, 2 * radius),
            flush=True)
    cards_path = os.path.join(out_dir, "%s_cards.png" % name)
    cards = render_cards(cards_path, templates, cell_px)
    imp_path = os.path.join(out_dir, "%s_impostor.png" % name)
    imp_n_path = os.path.join(out_dir, "%s_impostor_normal.png" % name)
    imp, _ = render_impostor(imp_path, imp_n_path, near_for_impostor, imp_px, views)
    cover = float(v.get("impostor_cover", 1.0))
    if cover != 1.0:
        # Thin parts (needles) are thinner than a pixel of the picture: more cover keeps them (R6).
        imp[..., 3] = np.clip(imp[..., 3] * cover, 0.0, 1.0)
        Image.fromarray(np.round(imp * 255.0).astype(np.uint8), "RGBA").save(imp_path, optimize=False)
    entry["cards"] = {"file": os.path.basename(cards_path), "cells": len(templates), "mean": mean_leaf_cover(cards),
                      "sha256": file_hash(cards_path)}
    entry["impostor"] = {"file": os.path.basename(imp_path), "normal": os.path.basename(imp_n_path), "views": views,
                         "rows": len(near_for_impostor), "mean": mean_leaf_cover(imp), "sha256": file_hash(imp_path),
                         "normal_sha256": file_hash(imp_n_path)}
    entry["source_hash"] = hashlib.sha256((json.dumps(v, sort_keys=True) + script_hash).encode()).hexdigest()
    return entry


# --check: a picture at a quarter of its size can differ in this part of its
# pixels by more than CHECK_STEP of 255. Thin needles have many edge pixels,
# and another processor rounds some of them in another way.
CHECK_PIXELS = 0.01
CHECK_STEP = 24


def compare(made_dir, kept_dir) -> list:
    """The problems: files of assets/trees that the build does not make again."""
    problems = []
    for name in sorted(os.listdir(kept_dir)):
        kept = os.path.join(kept_dir, name)
        made = os.path.join(made_dir, name)
        if name.endswith(".import") or name == "manifest.json" or not os.path.isfile(kept):
            continue
        if not os.path.exists(made):
            problems.append("%s: the build does not make it" % name)
        elif name.endswith(".glb"):
            if file_hash(made) != file_hash(kept):
                problems.append("%s: the mesh is different" % name)
        elif name.endswith(".png"):
            a = np.asarray(Image.open(made), dtype=np.int16)
            b = np.asarray(Image.open(kept), dtype=np.int16)
            if a.shape != b.shape:
                problems.append("%s: the size is different" % name)
            else:
                # Compare at a quarter of the size: the edge pixels of thin parts round in another way.
                h, w = (a.shape[0] // 4) * 4, (a.shape[1] // 4) * 4
                small_a = a[:h, :w].reshape(h // 4, 4, w // 4, 4, -1).mean(axis=(1, 3))
                small_b = b[:h, :w].reshape(h // 4, 4, w // 4, 4, -1).mean(axis=(1, 3))
                part = float((np.abs(small_a - small_b) > CHECK_STEP).any(axis=-1).mean())
                if part > CHECK_PIXELS:
                    problems.append("%s: %.2f %% of the pixels are different" % (name, part * 100.0))
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--only", nargs="*", help="Make only these types.")
    parser.add_argument("--out", default=OUT_DIR, help="The output folder (assets/trees).")
    parser.add_argument("--check", action="store_true", help="Check that assets/trees is what the build makes.")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
    if args.check:
        made = tempfile.mkdtemp(prefix="trees-")
        try:
            args.out = made
            build(args)
            problems = compare(made, OUT_DIR)
        finally:
            shutil.rmtree(made, ignore_errors=True)
        for problem in problems:
            print("check: " + problem)
        print("check: %s" % ("assets/trees is up to date" if not problems else "run tools/trees/build.py"))
        sys.exit(1 if problems else 0)
    build(args)


def build(args):
    with open(TYPES_PATH, encoding="utf-8") as f:
        data = json.load(f)
    os.makedirs(args.out, exist_ok=True)
    with open(os.path.abspath(__file__), "rb") as f:
        script_hash = hashlib.sha256(f.read()).hexdigest()
    manifest_path = os.path.join(args.out, "manifest.json")
    manifest = {"types": {}}
    if os.path.exists(manifest_path):
        with open(manifest_path, encoding="utf-8") as f:
            manifest = json.load(f)
    manifest["note"] = "Made by tools/trees/build.py from data/trees/types.json (plan 0020). Do not change by hand."
    manifest["bpy"] = bpy.app.version_string
    for name, v in data["types"].items():
        if args.only and name not in args.only:
            continue
        manifest["types"][name] = build_type(name, v, data, args.out, script_hash)
    manifest["types"] = {k: manifest["types"][k] for k in data["types"] if k in manifest["types"]}
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent="\t", ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    main()
