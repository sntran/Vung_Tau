"""Target look of the trees (plan 0020): a coconut palm and a bàng tree, made by code.

Run with Python and bpy 5.2.3 (the version of plan 0006):

    python trees.py coconut OUT_DIR
    python trees.py bang OUT_DIR
    python trees.py bang_tet OUT_DIR
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


# ---------------- Coconut palm ----------------
def coconut(origin=Vector((0, 0, 0)), height=11.0, lean=1.6, seed=1):
    r = random.Random(seed)
    bm = bmesh.new()
    # Trunk: a gentle curve, wider at the base, ring marks from the material.
    n = 28; pts = []; radii = []
    for i in range(n + 1):
        t = i / n
        pts.append(origin + Vector((lean * t * t, 0.25 * math.sin(t * 2.5), height * t)))
        radii.append(0.2 * (1 - t) + 0.13 * t + 0.1 * max(0, 0.08 - t) * 12)
    tube(bm, pts, radii, 12, 0)
    top = pts[-1]; axis = (pts[-1] - pts[-3]).normalized()
    # Crown base (the "bulb" of leaf sheaths).
    for i in range(6):
        p = top + axis * (0.1 * i)
        bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.24 - 0.02 * i,
                                  matrix=Matrix.Translation(p))
    for f in bm.faces:
        if f.material_index == 0 and len(f.verts) != 4:
            pass
    # Coconuts.
    for i in range(9):
        a = r.uniform(0, 2 * math.pi)
        p = top + Vector((math.cos(a) * 0.32, math.sin(a) * 0.32, -0.3 - r.uniform(0, 0.25)))
        res = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=7, radius=0.13, matrix=Matrix.Translation(p))
        for v in res['verts']:
            for f in v.link_faces:
                f.material_index = 3 if i % 3 else 4
    # Fronds.
    fronds = 22
    for i in range(fronds):
        az = i * 2.39996 + r.uniform(-0.1, 0.1)
        age = i / fronds                       # 0 young (up), 1 old (down)
        dead = i >= fronds - 2
        up = math.radians(30 + 70 * age + r.uniform(-6, 6))
        L = 4.4 + r.uniform(-0.4, 0.3) - (1.2 if dead else 0.0)
        d0 = Vector((math.sin(up) * math.cos(az), math.sin(up) * math.sin(az), math.cos(up)))
        out = Vector((math.cos(az), math.sin(az), 0))
        seg = 20; rach = []
        for k in range(seg + 1):
            s = k / seg
            droop = (0.75 + 0.55 * age) * s * s * L * 0.5
            rach.append(top + d0 * (s * L) - Vector((0, 0, droop)))
        tube(bm, rach, [0.045 * (1 - k / seg) + 0.01 for k in range(seg + 1)], 5, 2 if dead else 1)
        side = out.cross(Vector((0, 0, 1))).normalized()
        mi = 2 if dead else 1
        for k in range(4, seg * 5):
            s = k / (seg * 5)
            p = rach[0].lerp(rach[-1], 0) if False else None
            j = min(int(s * seg), seg - 1); fr = s * seg - j
            p = rach[j].lerp(rach[j + 1], fr)
            tang = (rach[j + 1] - rach[j]).normalized()
            ll = (0.25 + 0.75 * math.sin(math.pi * min(1, s * 1.15))) * (0.95 if not dead else 0.6)
            for sgn in (-1, 1):
                sd = (side * sgn).normalized()
                # Leaflets point out, forward, and down in a V.
                dirv = (sd * 0.7 + tang * 0.3 + Vector((0, 0, -0.45 if not dead else -1.2))).normalized()
                wv = tang * 0.028
                q0 = p; segs = 4; prev = None
                for m in range(segs + 1):
                    u = m / segs
                    c = q0 + dirv * (ll * u) - Vector((0, 0, 0.12 * ll * u * u))
                    w = wv * (1 - 0.8 * u)
                    a1 = bm.verts.new(c - w); a2 = bm.verts.new(c + w)
                    if prev:
                        f = bm.faces.new((prev[0], prev[1], a2, a1)); f.material_index = mi
                    prev = (a1, a2)
    trunk = mat('palm_trunk', (0.42, 0.37, 0.30), 0.85)
    # Ring marks on the trunk.
    nt = trunk.node_tree; p = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord'); wave = nt.nodes.new('ShaderNodeTexWave')
    wave.wave_type = 'BANDS'; wave.bands_direction = 'Z'; wave.inputs['Scale'].default_value = 1.2
    wave.inputs['Distortion'].default_value = 1.5
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (0.20, 0.17, 0.13, 1); ramp.color_ramp.elements[1].color = (0.40, 0.35, 0.28, 1)
    nt.links.new(tc.outputs['Object'], wave.inputs['Vector']); nt.links.new(wave.outputs['Fac'], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], p.inputs['Base Color'])
    leaf = mat('palm_leaf', (0.13, 0.24, 0.05), 0.5, 0.3, (0.35, 0.5, 0.08))
    deadm = mat('palm_dead', (0.45, 0.33, 0.18), 0.9, 0.2, (0.6, 0.45, 0.2))
    nut_g = mat('nut_g', (0.30, 0.40, 0.10), 0.5); nut_b = mat('nut_b', (0.45, 0.35, 0.12), 0.6)
    o = obj('coconut', bm, [trunk, leaf, deadm, nut_g, nut_b])
    for poly in o.data.polygons:
        if poly.material_index in (1, 2):
            poly.use_smooth = False
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


def bang(origin=Vector((0, 0, 0)), seed=3, tet=False):
    """An old bàng: a short thick trunk, a few big limbs, and a wide dome of leaves."""
    r = random.Random(seed)
    bm = bmesh.new()
    trunk_h = 3.0
    tpts = [origin + Vector((0.1 * math.sin(i), 0.08 * math.cos(i * 1.3), trunk_h * i / 6)) for i in range(7)]
    tube(bm, tpts, [0.42 - 0.08 * i / 6 + (0.15 if i == 0 else 0) for i in range(7)], 14, 0)
    top = tpts[-1]
    centre = origin + Vector((0, 0, 5.2)); A, B = 6.2, 3.4     # the dome: half width, half height
    network = []                                               # points on the branches

    def inside(p, k=0.92):
        # Keep a branch end inside the dome, so no bare branch sticks out.
        v = p - centre; e = math.sqrt((v.x / A) ** 2 + (v.y / A) ** 2 + (v.z / B) ** 2)
        return centre + v * (k / e) if e > k else p
    limbs = 6
    for li in range(limbs):
        az = li * 2 * math.pi / limbs + r.uniform(-0.25, 0.25)
        out = Vector((math.cos(az), math.sin(az), 0))
        tilt = r.uniform(0.45, 0.75)                           # 0 = up, 1 = flat
        end = inside(centre + out * A * 0.72 + Vector((0, 0, B * (0.55 - tilt * 0.5))), 0.8)
        pts = [top.lerp(end, k / 8) + Vector((0, 0, 0.6 * math.sin(math.pi * k / 8)))  for k in range(9)]
        tube(bm, pts, [0.24 * (1 - 0.75 * k / 8) for k in range(9)], 8, 0)
        network += pts[2:]
        side = out.cross(Vector((0, 0, 1)))
        for k in (3, 5, 7):
            for sg in (-1, 1):
                d = (out * 0.5 + side * sg * r.uniform(0.6, 1.0) + Vector((0, 0, r.uniform(0.2, 0.6)))).normalized()
                q = inside(pts[k] + d * r.uniform(1.6, 2.6), 0.85)
                sub = [pts[k].lerp(q, u / 4) + Vector((0, 0, 0.25 * math.sin(math.pi * u / 4))) for u in range(5)]
                tube(bm, sub, [0.09 * (1 - 0.7 * u / 4) for u in range(5)], 6, 0)
                network += sub[1:]
                # Small branches from the end, out to the shell of the dome.
                for _ in range(4):
                    d2 = (d + Vector((r.uniform(-0.9, 0.9), r.uniform(-0.9, 0.9), r.uniform(-0.2, 0.5)))).normalized()
                    q2 = inside(sub[-1] + d2 * r.uniform(1.0, 1.8))
                    tw = [sub[-1].lerp(q2, u / 3) for u in range(4)]
                    tube(bm, tw, [0.035, 0.028, 0.02, 0.014], 4, 0)
                    network += tw[1:]
    # Groups of leaves on the shell of the dome, each on a twig from the nearest branch.
    rosettes = []
    for i in range(1600):
        th = math.acos(1 - r.random() * 1.15)                  # from the top to a little below the middle
        ph = r.uniform(0, 2 * math.pi)
        k = r.uniform(0.7, 1.0) ** 0.5
        n = Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))
        q = centre + Vector((n.x * A * k, n.y * A * k, n.z * B * k))
        near = min(network, key=lambda p: (p - q).length_squared)
        if (near - q).length > 1.4:
            continue
        tube(bm, [near, q], [0.022, 0.008], 3, 0)
        rosettes.append((q, n))
    green = mat('bang_leaf', (0.07, 0.20, 0.035), 0.45, 0.22, (0.3, 0.5, 0.08))
    red = mat('bang_red', (0.45, 0.08, 0.03), 0.5, 0.22, (0.8, 0.25, 0.05))
    orange = mat('bang_orange', (0.55, 0.28, 0.05), 0.5, 0.22, (0.85, 0.5, 0.1))
    for q, n in rosettes:
        up = (n + Vector((0, 0, 1.2))).normalized()
        m = r.randint(9, 13)
        for k in range(m):
            a = 2 * math.pi * k / m + r.uniform(-0.2, 0.2)
            t = up.orthogonal().normalized(); b = up.cross(t)
            d = (t * math.cos(a) + b * math.sin(a) + up * r.uniform(-0.1, 0.25)).normalized()
            mi = 1
            if tet:
                x = r.random(); mi = 2 if x < 0.35 else (3 if x < 0.5 else 1)
            leaf(bm, q, d, up, r.uniform(0.85, 1.2), mi)
    wood = mat('bang_wood', (0.12, 0.10, 0.08), 0.9)
    o = obj('bang', bm, [wood, green, red, orange])
    for poly in o.data.polygons:
        if poly.material_index:
            poly.use_smooth = False
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
if what == 'coconut':
    sc = reset(); ground((0.62, 0.52, 0.36))
    coconut(Vector((-2.2, 0, 0)), 11.5, 1.8, 1); coconut(Vector((2.4, 3.5, 0)), 10.0, -1.2, 4)
    person(Vector((1.0, -1.5, 0)))
    camera((0.4, 0, 6.0), 16, 1.7, 30)
    render('coconut')
elif what == 'bang':
    sc = reset(); ground((0.45, 0.42, 0.33))
    bang(Vector((0, 0, 0)), 3, tet=False); person(Vector((2.5, -2.5, 0)))
    camera((0, 0, 4.0), 18, 1.7, 30)
    render('bang_green')
elif what == 'bang_tet':
    sc = reset(); ground((0.45, 0.42, 0.33))
    bang(Vector((0, 0, 0)), 3, tet=True); person(Vector((2.5, -2.5, 0)))
    camera((0, 0, 4.0), 18, 1.7, 30)
    render('bang_tet')
