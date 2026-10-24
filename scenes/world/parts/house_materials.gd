class_name HouseMaterials
extends RefCounted
## The materials of the house kit (plan 0004, R7, R8). All houses share them.
## The values of each house are instance uniforms of the shaders, or vertex
## colors, so that the materials stay few (R13).

const PLASTER := "plaster"
const BARE := "bare"
const DETAIL := "detail"
const METAL := "metal"
const GLASS := "glass"
const GLOW := "glow"
const METAL_ROOF := "metal_roof"
const TILE_ROOF := "tile_roof"
const TILES := "tiles"
const CLOTH := "cloth"
const CABLE := "cable"

static var _materials: Dictionary = {}


static func all() -> Dictionary:
	if not _materials.is_empty():
		return _materials
	var plaster := ShaderMaterial.new()
	plaster.shader = load("res://scenes/world/parts/plaster.gdshader")
	_materials[PLASTER] = plaster
	_materials[BARE] = plaster
	var metal_roof := ShaderMaterial.new()
	metal_roof.shader = load("res://scenes/world/parts/metal_roof.gdshader")
	_materials[METAL_ROOF] = metal_roof
	var tile_roof := ShaderMaterial.new()
	tile_roof.shader = load("res://scenes/world/parts/tile_roof.gdshader")
	_materials[TILE_ROOF] = tile_roof
	var tiles := ShaderMaterial.new()
	tiles.shader = load("res://scenes/world/parts/tiles.gdshader")
	_materials[TILES] = tiles
	_materials[DETAIL] = _vertex_color(0.85, 0.0)
	_materials[METAL] = _vertex_color(0.35, 0.65)
	var glass := _vertex_color(0.12, 0.3)
	glass.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_materials[GLASS] = glass
	var cloth := _vertex_color(0.95, 0.0)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[CLOTH] = cloth
	_materials[CABLE] = _vertex_color(0.6, 0.0)
	var glow := _vertex_color(0.6, 0.0)
	glow.emission_enabled = true
	glow.emission = Color("#FFE7A0")
	glow.emission_energy_multiplier = 0.0
	_materials[GLOW] = glow
	return _materials


static func _vertex_color(roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = roughness
	material.metallic = metallic
	return material
