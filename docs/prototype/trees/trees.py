"""Target look of the trees (plan 0020), made by code: coconut palm, bàng, casuarina (phi lao), and flame tree (phượng vĩ).

Run with Python and bpy 5.2.3 (the version of plan 0006):

    python trees.py coconut|bang|bang_tet|casuarina|flame OUT_DIR
"""
import sys, math, random
import bpy, bmesh
from mathutils import Vector, Matrix

OUT = sys.argv[-1]
rng = random.Random(7)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 760, 900
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Medium High Contrast'
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    nt = w.node_tree; bg = nt.nodes['Background']
    tc = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (0.75, 0.82, 0.90, 1); ramp.color_ramp.elements[1].color = (0.28, 0.45, 0.80, 1)
    nt.links.new(tc.outputs['Generated'], sep.inputs[0]); nt.links.new(sep.outputs['Z'], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bg.inputs[0]); bg.inputs[1].default_value = 0.9
    sun = bpy.data.lights.new('sun', 'SUN'); sun.energy = 4.0; sun.angle = math.radians(1.5)
    so = bpy.data.objects.new('sun', sun); sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(42), 0, math.radians(30))
    return sc


def mat(name, color, rough=0.6, trans=0.0, sub=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    if trans:
        p.inputs['Transmission Weight'].default_value = 0.0
        try:
            p.inputs['Subsurface Weight'].default_value = 0.0
        except Exception:
            pass
        # Thin leaves: mix with a translucent BSDF.
        nt = m.node_tree; out = nt.nodes['Material Output']
        tr = nt.nodes.new('ShaderNodeBsdfTranslucent'); tr.inputs[0].default_value = (*(sub or color), 1)
        mix = nt.nodes.new('ShaderNodeMixShader'); mix.inputs[0].default_value = trans
        nt.links.new(p.outputs[0], mix.inputs[1]); nt.links.new(tr.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs[0])
    return m


def obj(name, bm, mats):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for m in mats:
        me.materials.append(m)
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    for p in me.polygons:
        p.use_smooth = True
    return o


def tube(bm, pts, radii, sides=10, mat_index=0):
    rings = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = d.orthogonal().normalized(); b = d.cross(a)
        ring = [bm.verts.new(p + (a * math.cos(t) + b * math.sin(t)) * radii[i])
                for t in [2 * math.pi * k / sides for k in range(sides)]]
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            f = bm.faces.new((r0[k], r0[(k + 1) % sides], r1[(k + 1) % sides], r1[k]))
            f.material_index = mat_index
    return rings


def ground(color=(0.62, 0.55, 0.42)):
    bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=60)
    obj('ground', bm, [mat('g', color, 0.95)])


def camera(target, dist, height, lens=35, yaw=0.0):
    cam = bpy.data.cameras.new('c'); cam.lens = lens
    co = bpy.data.objects.new('c', cam); bpy.context.scene.collection.objects.link(co)
    co.location = Vector((math.sin(yaw) * dist, -math.cos(yaw) * dist, height))
    d = Vector(target) - co.location
    co.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = co


def leaf_materials(prefix, green, young, sub):
    return [mat(prefix + '_leaf', green, 0.45, 0.3, sub), mat(prefix + '_young', young, 0.45, 0.3, sub)]


def strip(bm, pts, half_widths, side, mi):
    """A thin strip along the points (a leaflet, a needle bundle, a pinna)."""
    prev = None
    for p, w in zip(pts, half_widths):
        a = bm.verts.new(p - side * w); b = bm.verts.new(p + side * w)
        if prev:
            f = bm.faces.new((prev[0], prev[1], b, a)); f.material_index = mi
        prev = (a, b)


def flat_shading(o, wood_index=0):
    for poly in o.data.polygons:
        if poly.material_index != wood_index:
            poly.use_smooth = False


# ---------------- Coconut palm ----------------
def coconut(origin=Vector((0, 0, 0)), height=12.0, lean=2.0, seed=1):
    """A tall, thin, leaning trunk. A round crown: the fronds arch out, and the
    leaflets hang down from the frond like a curtain. Dead fronds hang along the trunk."""
    r = random.Random(seed)
    bm = bmesh.new()
    n = 30; pts = []; radii = []
    for i in range(n + 1):
        t = i / n
        pts.append(origin + Vector((lean * t ** 1.6, 0.2 * math.sin(t * 2.0), height * t)))
        radii.append(0.17 * (1 - t) + 0.12 * t + 0.12 * max(0, 0.06 - t) * 14)
    tube(bm, pts, radii, 12, 0)
    top = pts[-1]
    for i in range(5):
        bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.22 - 0.02 * i,
                                  matrix=Matrix.Translation(top + Vector((0, 0, 0.1 * i))))
    for i in range(10):
        a = r.uniform(0, 2 * math.pi)
        p = top + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, -0.25 - r.uniform(0, 0.3)))
        res = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=7, radius=0.12, matrix=Matrix.Translation(p))
        for v in res['verts']:
            for f in v.link_faces:
                f.material_index = 4 if i % 3 else 5
    fronds = 24
    for i in range(fronds):
        az = i * 2.39996 + r.uniform(-0.1, 0.1)
        age = i / (fronds - 1)
        dead = i >= fronds - 3
        up = math.radians((150 + r.uniform(-10, 10)) if dead else (30 + 75 * age + r.uniform(-6, 6)))
        L = (3.6 if dead else 5.8) + r.uniform(-0.4, 0.4)
        d0 = Vector((math.sin(up) * math.cos(az), math.sin(up) * math.sin(az), math.cos(up)))
        out = Vector((math.cos(az), math.sin(az), 0))
        side = out.cross(Vector((0, 0, 1))).normalized()
        seg = 24; rach = []
        for k in range(seg + 1):
            s = k / seg
            droop = 0.0 if dead else (0.9 + 0.8 * age) * (s ** 2.0) * L * 0.55
            rach.append(top + d0 * (s * L) - Vector((0, 0, droop)))
        mi = 3 if dead else (2 if age > 0.75 else 1)
        tube(bm, rach, [0.05 * (1 - k / seg) + 0.012 for k in range(seg + 1)], 5, 3 if dead else 1)
        pairs = 60 if dead else 120
        for k in range(5, pairs):
            s = k / pairs
            j = min(int(s * seg), seg - 1); fr = s * seg - j
            p = rach[j].lerp(rach[j + 1], fr)
            tang = (rach[j + 1] - rach[j]).normalized()
            ll = (0.35 + 0.85 * math.sin(math.pi * min(1.0, s * 1.1))) * (0.5 if dead else 1.0)
            for sgn in (-1, 1):
                sd = side * sgn
                hang = 1.6 if dead else (0.9 + 0.6 * age)
                dirv = (sd * 0.55 + tang * 0.25 + Vector((0, 0, -hang))).normalized()
                pts_l = [p + dirv * (ll * u) - Vector((0, 0, 0.35 * ll * u * u)) for u in (0, 0.25, 0.5, 0.75, 1.0)]
                width_side = dirv.cross(Vector((0, 0, 1))).normalized() if abs(dirv.z) < 0.99 else tang
                strip(bm, pts_l, [0.014, 0.016, 0.014, 0.009, 0.002], width_side, mi)
    trunk = mat('palm_trunk', (0.42, 0.37, 0.30), 0.85)
    nt = trunk.node_tree; pr = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord'); wave = nt.nodes.new('ShaderNodeTexWave')
    wave.wave_type = 'BANDS'; wave.bands_direction = 'Z'; wave.inputs['Scale'].default_value = 1.2
    wave.inputs['Distortion'].default_value = 1.5
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (0.24, 0.21, 0.17, 1); ramp.color_ramp.elements[1].color = (0.46, 0.41, 0.33, 1)
    nt.links.new(tc.outputs['Object'], wave.inputs['Vector']); nt.links.new(wave.outputs['Fac'], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], pr.inputs['Base Color'])
    leaf = mat('palm_leaf', (0.17, 0.30, 0.06), 0.5, 0.3, (0.45, 0.6, 0.12))
    old = mat('palm_old', (0.26, 0.33, 0.08), 0.5, 0.3, (0.55, 0.6, 0.15))
    deadm = mat('palm_dead', (0.42, 0.32, 0.18), 0.9, 0.2, (0.6, 0.45, 0.2))
    nut_g = mat('nut_g', (0.30, 0.40, 0.10), 0.5); nut_b = mat('nut_b', (0.45, 0.35, 0.12), 0.6)
    o = obj('coconut', bm, [trunk, leaf, old, deadm, nut_g, nut_b])
    flat_shading(o)
    for poly in o.data.polygons:
        if poly.material_index in (4, 5):
            poly.use_smooth = True
    return o


# ---------------- Bàng (Terminalia catappa) ----------------
LEAF_SHAPE = [(0, 0), (0.035, 0.03), (0.07, 0.11), (0.085, 0.19), (0.06, 0.25), (0.0, 0.27),
              (-0.06, 0.25), (-0.085, 0.19), (-0.07, 0.11), (-0.035, 0.03)]


def leaf(bm, base, direction, normal, size, mi):
    side = direction.cross(normal).normalized(); normal = side.cross(direction).normalized()
    vs = [bm.verts.new(base + side * x * size + direction * y * size + normal * (-(x * x) * 4 * size))
          for x, y in LEAF_SHAPE]
    c = bm.verts.new(base + direction * 0.14 * size + normal * 0.01)
    for k in range(len(vs)):
        f = bm.faces.new((c, vs[k], vs[(k + 1) % len(vs)])); f.material_index = mi


def rosette(bm, q, up, r, size, pick):
    t = up.orthogonal().normalized(); b = up.cross(t)
    m = r.randint(9, 13)
    for k in range(m):
        a = 2 * math.pi * k / m + r.uniform(-0.25, 0.25)
        d = (t * math.cos(a) + b * math.sin(a) + up * r.uniform(-0.15, 0.3)).normalized()
        mi = pick()
        if mi is not None:
            leaf(bm, q, d, up, size * r.uniform(0.75, 1.15), mi)


def bang(origin=Vector((0, 0, 0)), seed=3, tet=False):
    """An old bàng as in the photos: the trunk forks at about 2.5 m into two or
    three leaders. Layers of near-flat branches end in groups of large leaves.
    The crown is a tall, open dome: the sky shows through."""
    r = random.Random(seed)
    bm = bmesh.new()
    fork = 2.6
    tpts = [origin + Vector((0.05 * math.sin(i), 0.04 * math.cos(i), fork * i / 5)) for i in range(6)]
    tube(bm, tpts, [0.36 - 0.04 * i / 5 + (0.14 if i == 0 else 0) for i in range(6)], 14, 0)
    centre = origin + Vector((0, 0, 6.6)); A, B = 6.2, 3.7

    def reach(p, d):
        # Distance from p along d to the shell of the crown.
        lo, hi = 0.0, 20.0
        for _ in range(30):
            m = (lo + hi) / 2; v = p + d * m - centre
            if (v.x / A) ** 2 + (v.y / A) ** 2 + (v.z / B) ** 2 < 1:
                lo = m
            else:
                hi = m
        return lo

    tips = []
    leaders = 3
    for li in range(leaders):
        az = li * 2 * math.pi / leaders + r.uniform(-0.3, 0.3)
        out = Vector((math.cos(az), math.sin(az), 0))
        lean = r.uniform(0.25, 0.4)
        top_h = r.uniform(8.6, 9.6)
        lp = [tpts[-1] + out * (lean * (top_h - fork) * (k / 8) ** 1.3) + Vector((0, 0, (top_h - fork) * k / 8)) for k in range(9)]
        tube(bm, lp, [0.22 * (1 - 0.8 * k / 8) + 0.03 for k in range(9)], 10, 0)
        # Layers of branches from the leader.
        for k in range(2, 9):
            h_frac = k / 8
            for w in range(3 if k < 8 else 4):
                baz = az + r.uniform(-1.6, 1.6)
                d = Vector((math.cos(baz), math.sin(baz), r.uniform(0.08, 0.3))).normalized()
                L = reach(lp[k], d) * r.uniform(0.75, 0.95)
                if L < 0.8:
                    continue
                bp = [lp[k] + d * (L * u / 6) + Vector((0, 0, 0.25 * math.sin(math.pi * u / 6))) for u in range(7)]
                tube(bm, bp, [0.07 * (1 - 0.8 * u / 6) * (1.2 - h_frac * 0.5) + 0.01 for u in range(7)], 6, 0)
                side = d.cross(Vector((0, 0, 1))).normalized()
                for u in range(2, 7):
                    for sg in (-1, 1):
                        if r.random() < 0.1:
                            continue
                        td = (d * 0.6 + side * sg * r.uniform(0.4, 0.9) + Vector((0, 0, r.uniform(0.15, 0.45)))).normalized()
                        q = bp[u] + td * r.uniform(0.3, 0.7)
                        tube(bm, [bp[u], q], [0.02, 0.01], 4, 0)
                        tips.append(q)
                tips.append(bp[-1])
    leaves = leaf_materials('bang', (0.12, 0.31, 0.06), (0.30, 0.46, 0.10), (0.4, 0.6, 0.12))
    red = mat('bang_red', (0.45, 0.08, 0.03), 0.5, 0.25, (0.8, 0.25, 0.05))
    orange = mat('bang_orange', (0.55, 0.28, 0.05), 0.5, 0.25, (0.85, 0.5, 0.1))

    def pick():
        x = r.random()
        if tet:
            if x < 0.2:
                return None          # fallen
            return 3 if x < 0.45 else (4 if x < 0.58 else (2 if x < 0.66 else 1))
        return 2 if x < 0.18 else 1

    for q in tips:
        up = (Vector((0, 0, 1)) + Vector((r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), 0))).normalized()
        rosette(bm, q, up, r, 1.4, pick)
    wood = mat('bang_wood', (0.16, 0.13, 0.10), 0.9)
    o = obj('bang', bm, [wood] + leaves + [red, orange])
    flat_shading(o)
    return o


# ---------------- Casuarina (phi lao) ----------------
def casuarina(origin=Vector((0, 0, 0)), seed=5, height=13.0):
    """Tall and thin, with a ragged, see-through crown of drooping grey-green needles."""
    r = random.Random(seed)
    bm = bmesh.new()
    tp = [origin + Vector((0.6 * (i / 12) ** 2, 0.2 * math.sin(i * 0.5), height * i / 12)) for i in range(13)]
    tube(bm, tp, [0.22 * (1 - 0.85 * i / 12) + 0.02 for i in range(13)], 10, 0)
    for i in range(46):
        if r.random() < 0.3:
            continue
        f = 0.42 + 0.56 * i / 45
        k = f * 12; j = min(int(k), 11); p = tp[j].lerp(tp[j + 1], k - j)
        az = i * 2.39996 + r.uniform(-0.3, 0.3)
        out = Vector((math.cos(az), math.sin(az), 0))
        L = (3.4 * (1 - f) + 1.0) * r.uniform(0.45, 1.35)
        rise = r.uniform(0.9, 1.6)
        bp = [p + out * (L * u / 5) + Vector((0, 0, rise * L * 0.35 * (u / 5) - 0.25 * L * (u / 5) ** 2)) for u in range(6)]
        tube(bm, bp, [0.04 * (1 - 0.7 * u / 5) + 0.008 for u in range(6)], 5, 0)
        for u in range(1, 6):
            if r.random() < 0.1:
                continue
            for _ in range(3):
                tuft_c = bp[u] + Vector((r.uniform(-0.6, 0.6), r.uniform(-0.6, 0.6), r.uniform(-0.15, 0.35)))
                for _n in range(36):
                    a = r.uniform(0, 2 * math.pi)
                    dn = (Vector((math.cos(a), math.sin(a), 0)) * r.uniform(0.3, 0.8) + Vector((0, 0, -1.0))).normalized()
                    ln = r.uniform(0.4, 0.8)
                    pts = [tuft_c + dn * (ln * v) + Vector((math.cos(a), math.sin(a), 0)) * 0.1 * v for v in (0, 0.5, 1.0)]
                    strip(bm, pts, [0.012, 0.01, 0.003], Vector((-math.sin(a), math.cos(a), 0)), 1)
    o = obj('casuarina', bm, [mat('cas_wood', (0.20, 0.16, 0.13), 0.9), mat('cas_needle', (0.13, 0.18, 0.11), 0.6, 0.2, (0.3, 0.38, 0.15))])
    flat_shading(o)
    return o


# ---------------- Flame tree (phượng vĩ) ----------------
def flame(origin=Vector((0, 0, 0)), seed=9):
    """A grey trunk that forks low into wide limbs, and a wide, flat umbrella of
    fine, fern-like leaves."""
    r = random.Random(seed)
    bm = bmesh.new()
    fork = 2.3
    tp = [origin + Vector((0.04 * math.sin(i), 0, fork * i / 4)) for i in range(5)]
    tube(bm, tp, [0.3 + (0.12 if i == 0 else 0) - 0.03 * i for i in range(5)], 12, 0)
    centre = origin + Vector((0, 0, 5.4)); A, B = 7.0, 2.0
    tips = []
    for li in range(5):
        az = li * 2 * math.pi / 5 + r.uniform(-0.3, 0.3)
        out = Vector((math.cos(az), math.sin(az), 0))
        end = centre + out * A * r.uniform(0.55, 0.7) + Vector((0, 0, r.uniform(-0.3, 0.6)))
        lp = [tp[-1].lerp(end, k / 8) + Vector((0, 0, 0.9 * math.sin(math.pi * k / 8))) for k in range(9)]
        tube(bm, lp, [0.18 * (1 - 0.7 * k / 8) for k in range(9)], 8, 0)
        for k in range(3, 9):
            for _ in range(9):
                d = (out * 0.5 + Vector((r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(0.2, 0.6)))).normalized()
                q = lp[k] + d * r.uniform(0.8, 2.2)
                v = q - centre
                e = math.sqrt((v.x / A) ** 2 + (v.y / A) ** 2 + (v.z / B) ** 2)
                if e > 0.98:
                    q = centre + v * (0.98 / e)
                tube(bm, [lp[k], q], [0.05, 0.015], 4, 0)
                tips.append(q)
    for q in tips:
        for _ in range(10):
            a = r.uniform(0, 2 * math.pi)
            d = Vector((math.cos(a), math.sin(a), r.uniform(-0.25, 0.15))).normalized()
            side = d.cross(Vector((0, 0, 1))).normalized()
            L = r.uniform(0.5, 0.8)
            for k in range(12):
                p = q + d * (L * k / 12) - Vector((0, 0, 0.1 * (k / 12) ** 2))
                for sg in (-1, 1):
                    pd = (side * sg + d * 0.4 + Vector((0, 0, -0.1))).normalized()
                    pl = 0.22 * math.sin(math.pi * (k + 1) / 13)
                    strip(bm, [p, p + pd * pl * 0.5, p + pd * pl], [0.02, 0.022, 0.006], d, 1)
    o = obj('flame', bm, [mat('fl_wood', (0.30, 0.28, 0.25), 0.85), mat('fl_leaf', (0.13, 0.32, 0.05), 0.5, 0.3, (0.4, 0.6, 0.12))])
    flat_shading(o)
    return o


def person(at):
    """A 1.7 m figure for scale."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.2, radius2=0.17, depth=1.45,
                          matrix=Matrix.Translation(at + Vector((0, 0, 0.72))))
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=8, radius=0.12, matrix=Matrix.Translation(at + Vector((0, 0, 1.58))))
    obj('person', bm, [mat('p', (0.15, 0.2, 0.35), 0.7)])


def render(name):
    bpy.context.scene.render.filepath = f'{OUT}/{name}.png'
    bpy.ops.render.render(write_still=True)


what = sys.argv[-2]
sc = reset()
if what == 'coconut':
    ground((0.62, 0.52, 0.36))
    coconut(Vector((-2.5, 0, 0)), 12.5, 2.2, 1); coconut(Vector((2.6, 4.0, 0)), 11.0, -1.6, 4)
    person(Vector((1.0, -1.5, 0)))
    camera((0.2, 0, 7.0), 21, 1.7, 30)
elif what in ('bang', 'bang_tet'):
    ground((0.45, 0.42, 0.33))
    bang(Vector((0, 0, 0)), 3, tet=(what == 'bang_tet')); person(Vector((2.5, -2.5, 0)))
    camera((0, 0, 5.0), 21, 1.7, 30)
elif what == 'casuarina':
    ground((0.45, 0.42, 0.33))
    casuarina(Vector((-1.5, 0, 0)), 5, 13.0); casuarina(Vector((2.5, 3.0, 0)), 8, 11.0); person(Vector((1.2, -2.0, 0)))
    camera((0.3, 0, 6.5), 21, 1.7, 30)
elif what == 'flame':
    ground((0.45, 0.42, 0.33))
    flame(Vector((0, 0, 0)), 9); person(Vector((2.5, -2.5, 0)))
    camera((0, 0, 3.8), 21, 1.7, 30)
render(what)
