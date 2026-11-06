class_name WorldMaterials
extends RefCounted
## The materials of the game for the material roles of World (plan 0023, D3).
##
## data/world/materials.json gives a material of the game for each role. The
## GLB files of World name each material by its role. Several roles can have
## one material: a house merges its roles into 6 materials (plan 0009, R7a,
## the set "house").

const PATH := "res://data/world/materials.json"
## The default color of a paint material.
const DEFAULT_PAINT := Color("#8E9092")

static var _shared: WorldMaterials = null

var data: Dictionary = {}
var _cache: Dictionary = {}  # material name, or name + "/" + paint -> Material


## The library, loaded one time.
static func shared() -> WorldMaterials:
	if _shared == null:
		_shared = WorldMaterials.new()
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_shared.data = parsed
		else:
			push_error("WorldMaterials: cannot read %s." % PATH)
	return _shared


## The name of the game material of a role, or "" when the role has none.
## A set ("house") has its own roles first.
func material_name(role: String, material_set := "") -> String:
	if material_set != "":
		var roles: Dictionary = data.get(material_set, {}).get("roles", {})
		if roles.has(role):
			return str(roles[role])
	var all_roles: Dictionary = data.get("roles", {})
	if all_roles.has(role):
		return str(all_roles[role])
	var patterns: Dictionary = data.get("patterns", {})
	for pattern: String in patterns:
		if role.match(pattern):
			return str(patterns[pattern])
	return ""


## The values of a game material.
func values(material: String, material_set := "") -> Dictionary:
	if material_set != "" and data.get(material_set, {}).get("materials", {}).has(material):
		return data[material_set].materials[material]
	return data.get("materials", {}).get(material, {})


## True when the material shows the paint color of the model.
func is_paint(material: String, material_set := "") -> bool:
	return bool(values(material, material_set).get("paint", false))


## The material of the game for a surface of a GLB. "source" is the material
## of the GLB (its texture stays when the game material asks for it). Gives
## null for a role with no material.
func material_for(role: String, source: Material, paint := DEFAULT_PAINT, material_set := "") -> Material:
	var name := material_name(role, material_set)
	if name == "":
		return null
	var v := values(name, material_set)
	if v.is_empty():
		return null
	var keep_source := bool(v.get("texture", false)) or bool(v.get("vertex_mean", false))
	var key := "%s/%s" % [material_set, name]
	if bool(v.get("paint", false)):
		key += "/" + paint.to_html(false)
	if keep_source:
		key += "/%d" % (source.get_instance_id() if source else 0)
	if _cache.has(key):
		return _cache[key]
	var m: StandardMaterial3D
	if keep_source and source is StandardMaterial3D:
		m = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		m = StandardMaterial3D.new()
	m.resource_name = name
	if bool(v.get("hidden", false)):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0, 0, 0, 0)
		_cache[key] = m
		return m
	# A material that keeps the GLB material keeps its color (the tint of the
	# order: the hair color, the clothes colors), its texture, and its
	# transparency (the edges of the hair). Only the roughness and the
	# metallic value are the values of the game.
	if not keep_source:
		var color := Color(str(v.get("color", "#FFFFFF")))
		if bool(v.get("paint", false)):
			color = paint
		if v.has("alpha"):
			color.a = float(v.alpha)
		m.albedo_color = color
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if v.has("alpha") else BaseMaterial3D.TRANSPARENCY_DISABLED
		m.vertex_color_use_as_albedo = false
	m.roughness = float(v.get("roughness", 0.8))
	m.metallic = float(v.get("metallic", 0.0))
	m.metallic_specular = 0.5
	_cache[key] = m
	return m


## The color of the game for a role, with no light (the impostor pictures and
## the MultiMesh colors use it).
func color_of(role: String, material_set := "") -> Color:
	return Color(str(values(material_name(role, material_set), material_set).get("color", "#FFFFFF")))
