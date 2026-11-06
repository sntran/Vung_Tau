#!/usr/bin/env python3
"""Makes the impostor of each model of World with "impostor": true (plan 0023, R8).

    python tools/world/impostors.py            # the pictures that are not there or are old
    python tools/world/impostors.py --force    # all pictures again
    python tools/world/impostors.py --check    # make them again and compare (CI)

Blender 5.2.3 as a Python module (tools/trees/requirements.txt) renders the
near level of the model (assets/world/ID.glb) from 8 directions, as the
impostors of the trees (plan 0020, D3):

- ID_impostor.png: the color of the game material of each role (sRGB, with
  no light), and the cover in the alpha. The paint is white: the game
  multiplies it by the paint color of each model.
- ID_impostor_normal.png: the normal in the axes of the model in Godot
  (x, y, z to 0..1), and the paint in the alpha (1 where the paint shows).

Column j shows the model turned by -360 * j / 8 degrees: column 0 shows the
front (+Z in Godot). The base of the model is at the bottom middle of each
cell. assets/world/impostors.json has the size of the cell of each model.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import worldfiles as wf  # noqa: E402

MATERIALS = ROOT / "data" / "world" / "materials.json"
MANIFEST = wf.ASSETS / "impostors.json"
VIEWS = 8
CELL_PX = 128
SAMPLES = 16
VERSION = 1


def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def role_colors(materials: dict) -> dict:
    """The color of each role (sRGB 0..1) and if it is paint."""

    def material_of(role: str) -> str:
        if role in materials["roles"]:
            return materials["roles"][role]
        for pattern, name in materials.get("patterns", {}).items():
            if pattern.endswith("*") and role.startswith(pattern[:-1]):
                return name
        return ""

    def color(role: str):
        name = material_of(role)
        if not name:
            raise SystemExit(f"ERROR: the role \"{role}\" has no material in {MATERIALS}")
        values = materials["materials"][name]
        if values.get("hidden"):
            return None
        hex_ = values.get("color", "#FFFFFF").lstrip("#")
        rgb = tuple(int(hex_[i : i + 2], 16) / 255.0 for i in (0, 2, 4))
        return rgb, bool(values.get("paint", False))

    return color


# --- Blender -------------------------------------------------------------------


def _bpy():
    import bpy  # noqa: PLC0415

    return bpy


def reset_scene():
    bpy = _bpy()
    bpy.ops.wm.read_factory_settings(use_empty=True)


def render_setup(width: int, height: int):
    bpy = _bpy()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = SAMPLES
    sc.cycles.use_adaptive_sampling = False
    sc.cycles.use_denoising = False
    sc.cycles.seed = 1
    sc.cycles.max_bounces = 0
    sc.cycles.filter_width = 1.0
    sc.render.film_transparent = True
    sc.render.resolution_x = width
    sc.render.resolution_y = height
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.color_depth = "8"
    sc.view_settings.view_transform = "Raw"
    sc.view_settings.look = "None"
    sc.display_settings.display_device = "sRGB"
    sc.render.threads_mode = "FIXED"
    sc.render.threads = 1
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.0
    sc.world = world


def emission(name: str, rgb=None, mode: str = "color"):
    """An emission material: a flat color, the normal of the model, or white (the paint mask)."""
    bpy = _bpy()
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for node in list(nt.nodes):
        nt.nodes.remove(node)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 1.0
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    if mode == "color":
        # The view transform is Raw: the sRGB values go to the picture as they are.
        em.inputs["Color"].default_value = (*rgb, 1.0)
    else:
        # The normal in the axes of the object (Blender), to Godot: (x, z, -y).
        coords = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(coords.outputs["Normal"], sep.inputs[0])
        neg = nt.nodes.new("ShaderNodeMath")
        neg.operation = "MULTIPLY"
        neg.inputs[1].default_value = -1.0
        nt.links.new(sep.outputs[1], neg.inputs[0])
        comb = nt.nodes.new("ShaderNodeCombineXYZ")
        nt.links.new(sep.outputs[0], comb.inputs[0])
        nt.links.new(sep.outputs[2], comb.inputs[1])
        nt.links.new(neg.outputs[0], comb.inputs[2])
        ma = nt.nodes.new("ShaderNodeVectorMath")
        ma.operation = "MULTIPLY_ADD"
        ma.inputs[1].default_value = (0.5, 0.5, 0.5)
        ma.inputs[2].default_value = (0.5, 0.5, 0.5)
        nt.links.new(comb.outputs[0], ma.inputs[0])
        nt.links.new(ma.outputs[0], em.inputs["Color"])
    return m


def import_model(glb: Path):
    """The model as one mesh object, with the transforms of its nodes applied."""
    bpy = _bpy()
    bpy.ops.import_scene.gltf(filepath=str(glb))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for obj in meshes:
        matrix = obj.matrix_world.copy()
        if obj.data.users > 1:
            obj.data = obj.data.copy()
        obj.data.transform(matrix)
        if matrix.determinant() < 0.0:
            obj.data.flip_normals()
        obj.parent = None
        obj.matrix_world.identity()
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    model = bpy.context.view_layer.objects.active
    return model


def render_to(path: Path):
    bpy = _bpy()
    from PIL import Image  # noqa: PLC0415

    tmp = str(path) + ".tmp.png"
    bpy.context.scene.render.filepath = tmp
    bpy.ops.render.render(write_still=True)
    img = Image.open(tmp)
    img.load()
    os.remove(tmp)
    return img


def make_impostor(model_id: str, color_of, out_dir: Path) -> dict:
    bpy = _bpy()
    from mathutils import Vector  # noqa: PLC0415
    from PIL import Image  # noqa: PLC0415

    reset_scene()
    render_setup(CELL_PX * VIEWS, CELL_PX)
    model = import_model(wf.ASSETS / f"{model_id}.glb")
    points = [v.co for v in model.data.vertices]
    radius = max(math.hypot(p.x, p.y) for p in points)
    low = min(p.z for p in points)
    high = max(p.z for p in points)
    size = max(2.0 * radius, high - low) * 1.02

    # The materials of the game, the paint mask, and the normal.
    colors, masks = [], []
    for slot in model.material_slots:
        role = slot.material.name.split(".")[0] if slot.material else ""
        found = color_of(role)
        if found is None:
            colors.append(None)
            masks.append(None)
            continue
        rgb, paint = found
        colors.append(emission(f"c_{role}", (1.0, 1.0, 1.0) if paint else rgb))
        masks.append(emission(f"m_{role}", (1.0, 1.0, 1.0) if paint else (0.0, 0.0, 0.0)))
    normal = emission("normal", mode="normal")
    hidden = [i for i, c in enumerate(colors) if c is None]
    if hidden:
        import bmesh  # noqa: PLC0415

        bm = bmesh.new()
        bm.from_mesh(model.data)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in hidden], context="FACES")
        bm.to_mesh(model.data)
        bm.free()

    copies = [model]
    for j in range(1, VIEWS):
        copy = model.copy()
        bpy.context.scene.collection.objects.link(copy)
        copies.append(copy)
    for j, obj in enumerate(copies):
        # The glTF import gives the quaternion mode: the turn needs the Euler mode.
        obj.rotation_mode = "XYZ"
        obj.rotation_euler = (0.0, 0.0, -2.0 * math.pi * j / VIEWS)
        obj.scale = (1.0 / size, 1.0 / size, 1.0 / size)
        obj.location = (j + 0.5, 0.0, -low / size)

    cam = bpy.data.cameras.new("c")
    cam.type = "ORTHO"
    cam.ortho_scale = float(VIEWS)
    cam.clip_start = 0.01
    cam.clip_end = 1000.0
    cam_obj = bpy.data.objects.new("c", cam)
    bpy.context.scene.collection.objects.link(cam_obj)
    cam_obj.location = Vector((VIEWS / 2.0, -50.0, 0.5))
    cam_obj.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
    bpy.context.scene.camera = cam_obj

    def set_materials(table):
        for i, slot in enumerate(model.material_slots):
            if table[i] is not None:
                slot.link = "DATA"
                slot.material = table[i]

    set_materials(colors)
    color_img = render_to(out_dir / "c.png")
    set_materials(masks)
    mask_img = render_to(out_dir / "m.png")
    set_materials([normal if c is not None else None for c in colors])
    normal_img = render_to(out_dir / "n.png")

    r, g, b, _a = normal_img.split()
    paint = mask_img.split()[0]
    normal_rgba = Image.merge("RGBA", (r, g, b, paint))
    color_path = out_dir / f"{model_id}_impostor.png"
    normal_path = out_dir / f"{model_id}_impostor_normal.png"
    color_img.save(color_path, optimize=False)
    normal_rgba.save(normal_path, optimize=False)
    return {"size": round(size, 4), "views": VIEWS, "cell_px": CELL_PX}


## The import of the pictures: no lossy compression (the normal and the paint
## mask are data), and mipmaps for the far cards.
IMPORT_PARAMS = {"compress/mode": "0", "mipmaps/generate": "true", "process/fix_alpha_border": "true"}


def write_import(path: Path) -> None:
    import_path = path.with_name(path.name + ".import")
    if import_path.exists():
        return
    lines = ["[remap]", "", 'importer="texture"', 'type="CompressedTexture2D"', "", "[params]", ""]
    lines += [f"{key}={value}" for key, value in IMPORT_PARAMS.items()]
    import_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--only", nargs="*")
    args = parser.parse_args(argv)

    models = [m for m in wf.load_orders() if m.get("impostor")]
    if args.only:
        models = [m for m in models if m["id"] in args.only]
    materials = json.loads(MATERIALS.read_text(encoding="utf-8"))
    color_of = role_colors(materials)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {"models": {}}
    script = file_hash(Path(__file__))
    materials_hash = file_hash(MATERIALS)
    problems = []
    changed = False
    for model in models:
        mid = model["id"]
        source = file_hash(wf.ASSETS / f"{mid}.glb")
        key = {"glb": source, "materials": materials_hash, "script": script, "version": VERSION}
        entry = manifest["models"].get(mid, {})
        fresh = all(entry.get(k) == v for k, v in key.items()) and all(
            (wf.ASSETS / f"{mid}{s}").exists() for s in ("_impostor.png", "_impostor_normal.png")
        )
        if fresh and not args.force and not args.check:
            continue
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            values = make_impostor(mid, color_of, out)
            files = {}
            for suffix in ("_impostor.png", "_impostor_normal.png"):
                files[mid + suffix] = file_hash(out / (mid + suffix))
            if args.check:
                for name, digest in files.items():
                    if not (wf.ASSETS / name).exists() or file_hash(wf.ASSETS / name) != digest:
                        problems.append(f"{name} is not what impostors.py makes")
                if entry != {**key, **values, "files": files}:
                    problems.append(f"{mid}: impostors.json is not what impostors.py makes")
                continue
            for name in files:
                shutil.copyfile(out / name, wf.ASSETS / name)
                write_import(wf.ASSETS / name)
        manifest["models"][mid] = {**key, **values, "files": files}
        changed = True
        print(f"{mid}: the impostor ({values['size']} m)")
    if args.check:
        for problem in problems:
            print(f"ERROR: {problem}")
        if problems:
            return 1
        print(f"The impostors of {len(models)} models are what impostors.py makes.")
        return 0
    for mid in list(manifest["models"]):
        if mid not in {m["id"] for m in models} and not args.only:
            del manifest["models"][mid]
            changed = True
    if changed:
        manifest["models"] = dict(sorted(manifest["models"].items()))
        manifest["note"] = "The impostors of the models of World (plan 0023, R8): tools/world/impostors.py makes them."
        MANIFEST.write_text(json.dumps(manifest, indent="\t") + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
