"""Preview renders of the people of the hẻm (plan 0006). See README.md.

python preview.py OUT_DIR [ID ...]
"""
import sys, os, math, json, importlib, time
import bpy, addon_utils
from mathutils import Vector, Matrix

OUT = sys.argv[1]
ONLY = sys.argv[2:]
SCR = os.path.dirname(os.path.abspath(__file__))
PRINTS = os.path.join(SCR, "prints")
os.makedirs(OUT, exist_ok=True)

addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)
M = "bl_ext.user_default.mpfb"
HumanService = importlib.import_module(M + ".services.humanservice").HumanService
TargetService = importlib.import_module(M + ".services.targetservice").TargetService
AssetService = importlib.import_module(M + ".services.assetservice").AssetService
LocationService = importlib.import_module(M + ".services.locationservice").LocationService
FaceService = importlib.import_module(M + ".services.faceservice").FaceService
HOP = importlib.import_module(M + ".entities.objectproperties").HumanObjectProperties
TARGETS = LocationService.get_mpfb_data("targets")
SKIN_SAT = float(os.environ.get("SKIN_SAT", "0.7"))


def age_value(years):
    return 0.5 + (years - 25) / 130.0


# Each person: macro sliders, face targets (file stem: weight), skin, hair, clothes.
PEOPLE = json.load(open(os.environ.get("PEOPLE_FILE", os.path.join(SCR, "people.json"))))


def find(name, subdir):
    for ext in (".mhclo", ".mhmat"):
        p = AssetService.find_asset_absolute_path(name + ext, asset_subdir=subdir)
        if p:
            return p
    return None


def target(h, stem, w):
    cat = stem.split("-")[0]
    folders = {"nose": "nose", "mouth": "mouth", "eye": "eyes", "head": "head", "chin": "chin",
               "cheek": "cheek", "neck": "neck", "eyebrows": "eyebrows", "ear": "ears",
               "forehead": "forehead", "stomach": "stomach", "torso": "torso"}
    folder = os.path.join(TARGETS, folders.get(cat, cat))
    paths = [os.path.join(folder, stem + ".target.gz")]
    if not os.path.exists(paths[0]):
        paths = [os.path.join(folder, side + stem + ".target.gz") for side in ("l-", "r-")]
    for path in paths:
        if not os.path.exists(path):
            print("NO TARGET", path)
            continue
        TargetService.load_target(h, path, weight=w)


def hsv_tint(mat, sat, val, hue=0.5, mix=None):
    nt = mat.node_tree
    for n in nt.nodes:
        if n.type == "BSDF_PRINCIPLED" and n.inputs["Base Color"].is_linked:
            link = n.inputs["Base Color"].links[0]
            hs = nt.nodes.new("ShaderNodeHueSaturation")
            hs.inputs["Saturation"].default_value = sat
            hs.inputs["Value"].default_value = val
            hs.inputs["Hue"].default_value = hue
            nt.links.new(link.from_socket, hs.inputs["Color"])
            out = hs.outputs["Color"]
            if mix:
                mx = nt.nodes.new("ShaderNodeMix")
                mx.data_type = "RGBA"
                mx.blend_type = "SCREEN"
                c = mix[0].lstrip("#")
                rgb = [((int(c[i:i + 2], 16) / 255.0) ** 2.2) for i in (0, 2, 4)]
                mx.inputs["Factor"].default_value = mix[1]
                nt.links.new(out, mx.inputs[6])
                mx.inputs[7].default_value = (*rgb, 1)
                out = mx.outputs[2]
            nt.links.new(out, n.inputs["Base Color"])


def cloth_material(name, spec):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.85
    if "print" in spec:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(os.path.join(PRINTS, spec["print"]))
        uv = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        s = spec.get("scale", 3.0)
        mp.inputs["Scale"].default_value = (s, s, s)
        nt.links.new(uv.outputs["UV"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], tex.inputs["Vector"])
        nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    else:
        c = spec["color"].lstrip("#")
        rgb = [((int(c[i:i + 2], 16) / 255.0) ** 2.2) for i in (0, 2, 4)]
        b.inputs["Base Color"].default_value = (*rgb, 1)
    return mat


def recolor(mat, spec):
    nt = mat.node_tree
    found = False
    for b in [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"]:
        found = True
        for l in list(b.inputs["Base Color"].links):
            nt.links.remove(l)
        if spec.get("solid"):
            for l in list(b.inputs["Alpha"].links):
                nt.links.remove(l)
            b.inputs["Alpha"].default_value = 1.0
        b.inputs["Roughness"].default_value = 0.85
        if "print" in spec:
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = bpy.data.images.load(os.path.join(PRINTS, spec["print"]))
            uv = nt.nodes.new("ShaderNodeTexCoord")
            mp = nt.nodes.new("ShaderNodeMapping")
            sc = spec.get("scale", 3.0)
            mp.inputs["Scale"].default_value = (sc, sc, sc)
            nt.links.new(uv.outputs["UV"], mp.inputs["Vector"])
            nt.links.new(mp.outputs["Vector"], tex.inputs["Vector"])
            nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
        else:
            c = spec["color"].lstrip("#")
            rgb = [((int(c[i:i + 2], 16) / 255.0) ** 2.2) for i in (0, 2, 4)]
            b.inputs["Base Color"].default_value = (*rgb, 1)
    if not found:
        print("NO PRINCIPLED in", mat.name, [n.type for n in nt.nodes])


def tint_textures(nt, color, seen=None):
    """Multiplies the color textures of a node tree (and its groups) by a tint, once."""
    seen = set() if seen is None else seen
    if nt.as_pointer() in seen:
        return
    seen.add(nt.as_pointer())
    c = color.lstrip("#")
    rgb = [((int(c[i:i + 2], 16) / 255.0) ** 2.2) for i in (0, 2, 4)]
    for n in list(nt.nodes):
        if n.type == "GROUP" and n.node_tree:
            tint_textures(n.node_tree, color, seen)
        if n.type != "TEX_IMAGE" or not n.image:
            continue
        name = n.image.name.lower()
        if any(k in name for k in ("normal", "bump", "spec", "rough", "sss", "litsphere")):
            continue
        links = list(n.outputs["Color"].links)
        if not links:
            continue
        mx = nt.nodes.new("ShaderNodeMix")
        mx.data_type = "RGBA"
        mx.blend_type = "MULTIPLY"
        mx.inputs["Factor"].default_value = 1.0
        mx.inputs[7].default_value = (*rgb, 1)
        hs = nt.nodes.new("ShaderNodeHueSaturation")
        hs.inputs["Saturation"].default_value = SKIN_SAT
        nt.links.new(n.outputs["Color"], hs.inputs["Color"])
        nt.links.new(hs.outputs["Color"], mx.inputs[6])
        for l in links:
            nt.links.new(mx.outputs[2], l.to_socket)
        print("TINT", n.image.name)


def skin_material(color, sss=True):
    mat = bpy.data.materials.new("skin")
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    c = color.lstrip("#")
    rgb = [((int(c[i:i + 2], 16) / 255.0) ** 2.2) for i in (0, 2, 4)]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = 0.5
    if sss:
        b.inputs["Subsurface Weight"].default_value = 0.15
        b.inputs["Subsurface Radius"].default_value = (1.0, 0.35, 0.2)
    return mat


def aim(rig, bone, direction):
    """Turns a pose bone so it points in the armature-space direction."""
    pb = rig.pose.bones[bone]
    bpy.context.view_layer.update()
    head = pb.head.copy()
    d = (pb.tail - pb.head).normalized()
    q = d.rotation_difference(Vector(direction).normalized())
    pb.matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ pb.matrix
    bpy.context.view_layer.update()


def relax(rig, p):
    bpy.context.view_layer.objects.active = rig
    out = 0.22
    aim(rig, "upperarm_l", (out, 0.06, -1))
    aim(rig, "upperarm_r", (-out, 0.06, -1))
    aim(rig, "lowerarm_l", (0.12, -0.35, -1))
    aim(rig, "lowerarm_r", (-0.12, -0.35, -1))
    for side in "lr":
        aim(rig, f"hand_{side}", ((0.08 if side == 'l' else -0.08), -0.25, -1))


def bone_pts(rig, name):
    b = rig.data.bones[name]
    return rig.matrix_world @ b.head_local, rig.matrix_world @ b.tail_local


def cut(ob, rig, how):
    """Removes parts of a clothes mesh in the rest pose: sleeves or the lower legs."""
    import bmesh
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    if how in ("short_sleeves", "sleeveless"):
        # Smaller faces give a cleaner cut edge.
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True)
    mw = ob.matrix_world
    kill = []
    arms = [bone_pts(rig, f"upperarm_{s}") for s in "lr"]
    fore = [bone_pts(rig, f"lowerarm_{s}") for s in "lr"] + [bone_pts(rig, f"hand_{s}") for s in "lr"]
    knee = min(bone_pts(rig, f"calf_{s}")[0].z for s in "lr")
    neck = bone_pts(rig, "neck_01")[0]
    for v in bm.verts:
        w = mw @ v.co
        if how == "knee" and w.z < knee + 0.06:
            kill.append(v)
            continue
        if how in ("short_sleeves", "sleeveless"):
            hit = False
            for a, b in fore:
                ax = b - a
                t = (w - a).dot(ax) / ax.length_squared
                if -0.1 < t < 1.5 and (w - (a + ax * t)).length < 0.13:
                    hit = True
            if hit:
                kill.append(v)
                continue
            for a, b in arms:
                ax = b - a
                t = (w - a).dot(ax) / ax.length_squared
                dist = (w - (a + ax * t)).length
                limit = 0.42 if how == "short_sleeves" else -0.02
                if t > limit and dist < (0.12 if how == 'short_sleeves' else 0.16):
                    kill.append(v)
                    break
            else:
                if how == "sleeveless" and w.y < neck.y and abs(w.x - neck.x) < 0.075 and w.z > neck.z - 0.13:
                    kill.append(v)
    bmesh.ops.delete(bm, geom=list(set(kill)), context="VERTS")
    bm.to_mesh(me)
    bm.free()
    me.update()


def uncover(h, clothes_objs, mhclo_name, rig=None, how=None):
    """Shows the skin again where a cut removed the cloth: the delete group of the
    clothes keeps only the body vertices that are near the cloth that is left."""
    from mathutils.kdtree import KDTree
    group = h.vertex_groups.get("Delete." + mhclo_name)
    if not group:
        print("NO DELETE GROUP", mhclo_name)
        return
    pts = [o.matrix_world @ v.co for o in clothes_objs for v in o.data.vertices]
    kd = KDTree(len(pts))
    for i, q in enumerate(pts):
        kd.insert(q, i)
    kd.balance()
    gi = group.index
    drop = []
    knee = min(bone_pts(rig, f"calf_{s}")[0].z for s in "lr") if how == "knee" else None
    for v in h.data.vertices:
        if any(g.group == gi and g.weight > 0 for g in v.groups):
            w = h.matrix_world @ v.co
            _, _, dist = kd.find(w)
            if dist > 0.015 or (knee is not None and w.z < knee + 0.12):
                drop.append(v.index)
    group.remove(drop)


def iso_cut(bm, mw, field):
    """Cuts a mesh along the line where field() is 0 and keeps the part where it is > 0."""
    import bmesh
    val = {v: field(mw @ v.co) for v in bm.verts}
    for e in list(bm.edges):
        a, b = e.verts
        fa, fb = val[a], val[b]
        if (fa > 0) != (fb > 0) and abs(fa - fb) > 1e-9:
            t = fa / (fa - fb)
            ne, nv = bmesh.utils.edge_split(e, a, t)
            val[nv] = 0.0
    zero = {v for v, f in val.items() if f == 0.0}
    for f in list(bm.faces):
        zs = [v for v in f.verts if v in zero]
        if len(zs) == 2 and not bm.edges.get(zs):
            try:
                bmesh.ops.connect_verts(bm, verts=zs)
            except Exception:
                pass
    drop = [f for f in bm.faces if any(val.get(v, 0) < 0 for v in f.verts)]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")


def make_singlet(h, rig, color):
    """Áo ba lỗ made by code from the torso surface of the body, pushed out a little."""
    import bmesh
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(h.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    ob = bpy.data.objects.new("singlet", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.matrix_world = h.matrix_world
    pelvis = bone_pts(rig, "pelvis")[0]
    neck = bone_pts(rig, "neck_01")[0]
    sh = [bone_pts(rig, f"upperarm_{s}")[0] for s in "lr"]
    sx = min(abs(p.x) for p in sh)
    sz = min(p.z for p in sh)

    def field(w):
        ax = abs(w.x)
        hem = (w.z - (pelvis.z - 0.035)) * 10
        top = (neck.z + 0.03 - w.z) * 10
        side = (sx + 0.01 - ax) * 10
        nh = 0.16 if w.y < neck.y else 0.07
        neckhole = (ax / 0.088) ** 2 + ((w.z - (neck.z + 0.03)) / nh) ** 2 - 1
        arm = ((ax - (sx + 0.015)) / 0.075) ** 2 + ((w.z - (sz - 0.03)) / 0.15) ** 2 - 1
        return min(hem, top, side, neckhole, arm)

    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    iso_cut(bm, ob.matrix_world, field)
    bm.normal_update()
    for v in bm.verts:
        w = (ob.matrix_world @ v.co).z
        # More room over the belly and at the hem, so that the waist of the trousers stays inside.
        v.co += v.normal * (0.007 + max(0.0, min(0.012, (pelvis.z + 0.12 - w) * 0.08)))
    bm.to_mesh(me)
    bm.free()
    for mod in list(ob.modifiers):
        ob.modifiers.remove(mod)
    arm = ob.modifiers.new("rig", "ARMATURE")
    arm.object = rig
    sol = ob.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.002
    ob.parent = rig
    ob.matrix_parent_inverse = rig.matrix_world.inverted()
    me.materials.clear()
    me.materials.append(cloth_material("singlet", {"color": color}))
    for poly in me.polygons:
        poly.use_smooth = True


def make_glasses(rig, eyes_ob, spec):
    """Glasses made by code: two rims, a bridge, and two arms to the ears."""
    pts = [eyes_ob.matrix_world @ v.co for v in eyes_ob.data.vertices]
    left = [q for q in pts if q.x > 0]
    right = [q for q in pts if q.x < 0]
    def center(qs):
        c = sum(qs, Vector()) / len(qs)
        return c
    cl, cr = center(left), center(right)
    front = min(q.y for q in pts) - 0.009
    mat = cloth_material("glasses", {"color": spec.get("color", "#2A2522")})
    lens_mat = None
    if spec.get("dark"):
        lens_mat = cloth_material("lens", {"color": "#1A1A1A"})
    parts = []
    for c in (cl, cr):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.0175, minor_radius=0.0011, location=(c.x, front, c.z + 0.002),
                                         rotation=(math.radians(90), 0, 0))
        rim = bpy.context.object
        rim.scale = (1.2, 0.85, 1.0)
        rim.data.materials.append(mat)
        parts.append(rim)
        if lens_mat:
            bpy.ops.mesh.primitive_circle_add(radius=0.0175, fill_type="NGON", location=(c.x, front, c.z + 0.002),
                                              rotation=(math.radians(90), 0, 0))
            ln = bpy.context.object
            ln.scale = (1.2, 0.85, 1.0)
            ln.data.materials.append(lens_mat)
            parts.append(ln)
    gap = (cl.x - 0.0175 * 1.2) - (cr.x + 0.0175 * 1.2)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.0012, depth=max(gap, 0.004), location=(0, front, (cl.z + cr.z) / 2 + 0.006),
                                        rotation=(0, math.radians(90), 0))
    bpy.context.object.data.materials.append(mat)
    parts.append(bpy.context.object)
    for c, sgn in ((cl, 1), (cr, -1)):
        a = Vector((c.x + sgn * 0.0175 * 1.2, front, c.z + 0.006))
        b = Vector((c.x + sgn * 0.036, front + 0.095, c.z + 0.002))
        d = b - a
        bpy.ops.mesh.primitive_cylinder_add(radius=0.0012, depth=d.length, location=(a + b) / 2)
        arm = bpy.context.object
        arm.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        arm.data.materials.append(mat)
        parts.append(arm)


def make_dep(rig, color):
    """Flip-flops (dép) made by code: a sole and a thong strap under each foot."""
    import bmesh
    mat = cloth_material("dep", {"color": color})
    for s in "lr":
        ankle = bone_pts(rig, f"foot_{s}")[0]
        ball_h, ball_t = bone_pts(rig, f"ball_{s}")
        fwd = (ball_t - ankle)
        fwd.z = 0
        fwd.normalize()
        side = Vector((fwd.y, -fwd.x, 0))
        heel = Vector((ankle.x, ankle.y, 0)) - fwd * 0.075
        toe = Vector((ball_t.x, ball_t.y, 0)) + fwd * 0.025
        length = (toe - heel).length
        mid = (heel + toe) / 2
        bpy.ops.mesh.primitive_cube_add(size=1, location=(mid.x, mid.y, 0.009))
        sole = bpy.context.object
        sole.scale = (0.092, length - 0.01, 0.012)
        sole.rotation_euler = (0, 0, math.atan2(-fwd.x, fwd.y))
        bpy.ops.object.modifier_add(type="BEVEL")
        sole.modifiers[-1].width = 0.02
        sole.modifiers[-1].segments = 4
        sole.modifiers[-1].limit_method = 'NONE'
        sole.data.materials.append(mat)
        # The strap: from between the first two toes to each side of the foot.
        post = Vector((ball_h.x, ball_h.y, 0.02)) + fwd * 0.035 + side * (0.012 if s == "l" else -0.012)
        for k in (-1, 1):
            end = Vector((ankle.x, ankle.y, 0.035)) + fwd * 0.045 + side * 0.048 * k
            d = end - post
            bpy.ops.mesh.primitive_cylinder_add(radius=0.006, depth=d.length, location=(post + end) / 2)
            st = bpy.context.object
            st.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
            st.data.materials.append(mat)


def build(p):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    h = HumanService.create_human()
    for k, v in p["macro"].items():
        HOP.set_value(k, age_value(v) if k == "age" else v, entity_reference=h)
    TargetService.reapply_macro_details(h)
    for stem, w in p.get("targets", {}).items():
        target(h, stem, w)
    skin_path = find(p["skin"], "skins") if p.get("skin") else None
    if skin_path:
        HumanService.set_character_skin(skin_path, h, skin_type="ENHANCED_SSS")
        if p.get("skin_tint"):
            seen = set()
            for m in h.data.materials:
                if m and m.use_nodes:
                    tint_textures(m.node_tree, p["skin_tint"], seen)
    else:
        h.data.materials.clear()
        h.data.materials.append(skin_material(p.get("skin_color", "#B98563")))
    rig = HumanService.add_builtin_rig(h, "game_engine")
    parts = [("eyes", "low-poly", "Eyes"), ("eyebrows", p.get("eyebrows", "eyebrow001"), "Eyebrows"),
             ("eyelashes", "eyelashes01", "Eyelashes"), ("teeth", "teeth_base", "Teeth"),
             ("tongue", "tongue01", "Tongue")]
    eyes = []
    for sub, name, kind in parts:
        path = find(name, sub)
        if path:
            before = set(bpy.data.objects)
            HumanService.add_mhclo_asset(path, h, asset_type=kind, material_type="MAKESKIN")
            if kind == "Eyes":
                eyes = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
        else:
            print("MISSING", sub, name)
    if p.get("hair"):
        path = find(p["hair"], "hair")
        if path:
            before = set(bpy.data.objects)
            HumanService.add_mhclo_asset(path, h, asset_type="Hair", material_type="MAKESKIN")
            for ob in [o for o in bpy.data.objects if o not in before and o.type == "MESH"]:
                for m in ob.data.materials:
                    if m and m.use_nodes:
                        hsv_tint(m, p.get("hair_sat", 0.0), p.get("hair_val", 0.15), mix=p.get("hair_mix"))
        else:
            print("MISSING hair", p["hair"])
    if p.get("singlet"):
        make_singlet(h, rig, p["singlet"])
    for item in p.get("clothes", []):
        path = find(item["mhclo"], "clothes")
        if not path:
            print("MISSING clothes", item["mhclo"])
            continue
        before = set(bpy.data.objects)
        HumanService.add_mhclo_asset(path, h, asset_type="Clothes", material_type="MAKESKIN")
        new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
        if item.get("cut"):
            for ob in new:
                cut(ob, rig, item["cut"])
            uncover(h, new, item["mhclo"], rig, item["cut"])
        if "color" in item or "print" in item:
            for ob in new:
                for m in ob.data.materials:
                    if m and m.use_nodes:
                        recolor(m, item)
    if p.get("dep"):
        make_dep(rig, p["dep"])
    if p.get("face"):
        FaceService.set_expression(h, p["face"])
        FaceService.interpolate_targets(h)
    if p.get("glasses") and eyes:
        make_glasses(rig, eyes[0], p["glasses"])
    relax(rig, p)
    return h, rig


def scene_setup():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = int(os.environ.get("SAMPLES", "48"))
    sc.cycles.use_denoising = True
    sc.cycles.device = "CPU"
    sc.view_settings.view_transform = "AgX"
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.75, 0.78, 0.82, 1)
    bg.inputs[1].default_value = 0.55
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.2
    sun.angle = math.radians(8)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(50), 0, math.radians(35))
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new("fill", "AREA")
    fill.energy = 250
    fill.size = 4
    fo = bpy.data.objects.new("fill", fill)
    fo.location = (-2.5, -3, 1.6)
    fo.rotation_euler = (math.radians(75), 0, math.radians(-40))
    sc.collection.objects.link(fo)
    # A plain floor and a wall in the colors of the hẻm.
    bpy.ops.mesh.primitive_plane_add(size=20)
    floor = bpy.context.object
    floor.data.materials.append(cloth_material("floor", {"color": "#8C857A"}))
    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 2.2, 0), rotation=(math.radians(90), 0, 0))
    wall = bpy.context.object
    wall.data.materials.append(cloth_material("wall", {"color": "#D8CFBE"}))
    return sc


def shoot(sc, name, loc, look, lens, rx, ry):
    cam = bpy.data.cameras.new(name)
    cam.lens = lens
    co = bpy.data.objects.new(name, cam)
    sc.collection.objects.link(co)
    co.location = loc
    d = Vector(look) - Vector(loc)
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.camera = co
    sc.render.resolution_x, sc.render.resolution_y = rx, ry
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)


for p in PEOPLE:
    if ONLY and p["id"] not in ONLY:
        continue
    t = time.time()
    h, rig = build(p)
    sc = scene_setup()
    bpy.context.view_layer.update()
    head = rig.matrix_world @ rig.pose.bones["head"].head
    top = head.z + 0.24
    hz = head.z + 0.1
    if not os.environ.get("FACE_ONLY"):
        shoot(sc, p["id"] + "_body", (0.95, -2.6, top * 0.6), (0, 0, top * 0.5), 50, 640, 960)
    shoot(sc, p["id"] + "_face", (0.36, -1.1, hz), (0, -0.04, hz - 0.03), 85, 640, 640)
    print("DONE", p["id"], round(time.time() - t, 1), "s, height", round(top, 2))
