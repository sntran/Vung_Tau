class_name TreeLibrary
extends RefCounted
## The tree types of plan 0020 (Real trees): the meshes, the pictures, and the
## materials of each type. tools/trees/build.py makes them from
## data/trees/types.json: assets/trees/TYPE_VARIANT.glb has the near and the
## middle form, and TYPE_impostor.png the far form of all variants.
##
## The materials of a type are shared by all its trees, so a change of season
## is one change for each type (R9).

const TYPES_PATH := "res://data/trees/types.json"
const ROOT := "res://assets/trees/"
## The ends of the near, middle, and far form of each preset (R5).
const RANGES := {
	"low": Vector3(20.0, 120.0, 900.0),
	"medium": Vector3(35.0, 200.0, 900.0),
	"high": Vector3(60.0, 300.0, 1500.0),
	"ultra": Vector3(90.0, 400.0, 2000.0),
}
## On a phone (the Mobile renderer), the near form ends at 15 m and the middle form at 80 m (R13).
const PHONE_NEAR := 15.0
const PHONE_MID := 80.0
const SHADERS := {
	"leaf": "res://shaders/tree_leaf.gdshader",
	"card": "res://shaders/tree_card.gdshader",
	"wood": "res://shaders/tree_wood.gdshader",
	"far": "res://shaders/tree_impostor.gdshader",
}

## The ranges of the forms now (Quality.apply() sets them with set_ranges()).
static var ranges := Vector3(20.0, 120.0, 900.0)
## The sun shadow distance of the preset: the trees farther than this cast no shadow (R7).
static var shadow_distance := 25.0
static var _shared: TreeLibrary = null

## The type names, in the order of data/trees/types.json.
var names: Array[String] = []
## The values of each type (data/trees/types.json).
var types: Dictionary = {}
## The values of the whole file: the wind, the variants, the impostor size.
var settings: Dictionary = {}
## assets/trees/manifest.json.
var manifest: Dictionary = {}
var _meshes: Dictionary = {}  # "type/variant/form" -> Mesh with the materials of the type
var _materials: Dictionary = {}  # type -> {"leaf", "card", "wood_near", "wood_mid", "far"}
var _quads: Dictionary = {}  # type -> the card mesh of the far form


## The library, loaded one time.
static func shared() -> TreeLibrary:
	if _shared == null:
		_shared = TreeLibrary.new()
		_shared._load()
	return _shared


## Sets the ranges of the forms for a quality preset, and for the renderer.
static func set_ranges(preset: String) -> void:
	var value: Vector3 = RANGES.get(preset, RANGES.low)
	if Quality.current_renderer() == "mobile":
		value = Vector3(PHONE_NEAR, PHONE_MID, value.z)
	ranges = value
	shadow_distance = float(Quality.PRESETS[Quality.valid(preset)].shadow_distance)
	RenderingServer.global_shader_parameter_set("tree_ranges", value)


func _load() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TYPES_PATH))
	if not parsed is Dictionary:
		push_error("TreeLibrary: cannot read %s." % TYPES_PATH)
		return
	settings = parsed
	types = parsed.get("types", {})
	for name: String in types:
		names.append(name)
	var manifest_path := ROOT.path_join("manifest.json")
	if FileAccess.file_exists(manifest_path):
		var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if m is Dictionary:
			manifest = m


## True when the type has its files (tools/trees/build.py made them).
func has_type(type: String) -> bool:
	return manifest.get("types", {}).has(type)


## The index of a type name, or -1.
func index_of(type: String) -> int:
	return names.find(type)


## The number of variants of a type.
func variants(type: String) -> int:
	return (manifest.get("types", {}).get(type, {}).get("variants", []) as Array).size()


## The values of a variant in the manifest (sizes, triangles).
func variant_info(type: String, variant: int) -> Dictionary:
	return manifest.types[type].variants[variant]


## The part of the ranges for the type: the bushes end sooner.
func range_scale(type: String) -> float:
	return float(types.get(type, {}).get("range_scale", 1.0))


## The part of the near range for the type, after range_scale: the types with
## many small leaves have their near form only nearer (report 0020, D-0020-02).
func near_scale(type: String) -> float:
	return float(types.get(type, {}).get("near_scale", 1.0))


## True when the far form of the type is an impostor. The bushes have no far form.
func has_far(type: String) -> bool:
	return bool(types.get(type, {}).get("far", true))


## The mesh of a form ("near", "mid", or "shadow": the middle form that casts
## the shadow of a near tree) of a variant, with the materials of the type.
func mesh(type: String, variant: int, form: String) -> Mesh:
	var key := "%s/%d/%s" % [type, variant, form]
	if _meshes.has(key):
		return _meshes[key]
	var info := variant_info(type, variant)
	var scene: PackedScene = load(ROOT.path_join(str(info.file)))
	var root := scene.instantiate()
	var source: MeshInstance3D = root.find_child("mid" if form == "shadow" else form, true, false)
	var result: ArrayMesh = source.mesh.duplicate()
	root.free()
	var mats := materials(type)
	for i in result.get_surface_count():
		var surface := result.surface_get_material(i)
		var surface_name := surface.resource_name if surface else ""
		match surface_name:
			"leaf":
				result.surface_set_material(i, mats.leaf)
			"card":
				result.surface_set_material(i, mats.card_shadow if form == "shadow" else mats.card)
			_:
				result.surface_set_material(i, {"near": mats.wood_near, "mid": mats.wood_mid}.get(form, mats.wood_shadow))
	_meshes[key] = result
	return result


## The card of the far form of a type: the base at the origin. The shader turns
## it to the camera; the box covers the largest variant, for the culling.
func far_mesh(type: String) -> Mesh:
	if _quads.has(type):
		return _quads[type]
	var size := 1.0
	for v: Dictionary in manifest.types[type].variants:
		size = maxf(size, float(v.impostor_size))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.surface_set_material(0, materials(type).far)
	result.custom_aabb = AABB(Vector3(-size, 0.0, -size), Vector3(size * 2.0, size * 1.5, size * 2.0))
	_quads[type] = result
	return result


## The materials of a type: "leaf", "card", "wood_near", "wood_mid", "far", and
## the shadow materials "card_shadow" and "wood_shadow".
func materials(type: String) -> Dictionary:
	if _materials.has(type):
		return _materials[type]
	var v: Dictionary = types[type]
	var made := {}
	for key: String in ["leaf", "card", "wood_near", "wood_mid", "far", "card_shadow", "wood_shadow"]:
		var shader_key := key.get_slice("_", 0)
		var material := ShaderMaterial.new()
		material.shader = load(SHADERS[shader_key])
		material.set_shader_parameter("range_scale", range_scale(type))
		material.set_shader_parameter("near_scale", near_scale(type))
		material.set_shader_parameter("wood_color", Color(str(v.wood)))
		material.set_shader_parameter("leaf_color", Color(str(v.leaf)))
		material.set_shader_parameter("leaf_young", Color(str(v.get("leaf_young", v.leaf))))
		material.set_shader_parameter("dead_color", Color(str(v.get("dead", "#8F7448"))))
		material.set_shader_parameter("flower_color", Color(str(v.get("flower", "#FFFFFF"))))
		material.set_shader_parameter("sway", float(v.get("sway", 0.35)))
		material.set_shader_parameter("young_share", float(v.get("young_share", 0.12)))
		var dry: Dictionary = v.get("season", {}).get("dry", {})
		material.set_shader_parameter("red_color", Color(str(dry.get("red", "#A33A1C"))))
		material.set_shader_parameter("orange_color", Color(str(dry.get("orange", "#B8742A"))))
		made[key] = material
	made.wood_near.set_shader_parameter("form", 0)
	made.wood_mid.set_shader_parameter("form", 1)
	made.wood_shadow.set_shader_parameter("form", -1)
	made.card_shadow.set_shader_parameter("form", -1)
	made.wood_near.set_shader_parameter("rings", float(v.get("rings", 0.0)))
	made.wood_mid.set_shader_parameter("rings", float(v.get("rings", 0.0)))
	var files: Dictionary = manifest.types[type]
	made.card.set_shader_parameter("cards", load(ROOT.path_join(str(files.cards.file))))
	made.card_shadow.set_shader_parameter("cards", load(ROOT.path_join(str(files.cards.file))))
	made.far.set_shader_parameter("impostor", load(ROOT.path_join(str(files.impostor.file))))
	made.far.set_shader_parameter("impostor_normal", load(ROOT.path_join(str(files.impostor.normal))))
	made.far.set_shader_parameter("views", float(files.impostor.views))
	made.far.set_shader_parameter("rows", float(files.impostor.rows))
	_materials[type] = made
	return made


## The season values of a type on a date (R9): the leaf color between the
## rainy and the dry look, the red and the bare parts, and the flowers.
func season_of(type: String, month: int, day: int) -> Dictionary:
	var v: Dictionary = types[type]
	var dryness := Season.dryness(month, day)
	var seasons: Dictionary = v.get("season", {})
	var rainy: Dictionary = seasons.get("rainy", {})
	var dry: Dictionary = seasons.get("dry", {})
	var leaf := Color(str(rainy.get("leaf", v.leaf))).lerp(Color(str(dry.get("leaf", v.leaf))), dryness)
	var flowers := 0.0
	if v.has("flowers"):
		flowers = Season.by_month(v.flowers, month, day)
	return {"leaf": leaf, "red_share": float(dry.get("red_share", 0.0)) * dryness,
			"bare_share": float(dry.get("bare_share", 0.0)) * dryness, "flower_share": flowers}


## Sets the season of all loaded types for a game day.
func apply_season(game_day: int) -> void:
	var date := GameCalendar.date_of(game_day)
	for type: String in _materials:
		var values := season_of(type, date.month, date.day)
		for material: ShaderMaterial in (_materials[type] as Dictionary).values():
			material.set_shader_parameter("leaf_color", values.leaf)
			material.set_shader_parameter("red_share", values.red_share)
			material.set_shader_parameter("bare_share", values.bare_share)
			material.set_shader_parameter("flower_share", values.flower_share)
