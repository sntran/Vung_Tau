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
static var _noise: Array[Texture2D] = []


## Two tileable noise textures (256 × 256): a smooth one and a detailed one.
## The shaders read them, because many noise functions in a shader are slow
## on a computer without a graphics card (the play tests under lavapipe).
static func noise_textures() -> Array[Texture2D]:
	if not _noise.is_empty():
		return _noise
	for settings: Array in [[0.012, 4, 11], [0.05, 3, 23]]:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = settings[0]
		noise.fractal_octaves = settings[1]
		noise.seed = settings[2]
		var image := noise.get_seamless_image(256, 256)
		image.generate_mipmaps()
		_noise.append(ImageTexture.create_from_image(image))
	return _noise


static func all() -> Dictionary:
	if not _materials.is_empty():
		return _materials
	var noise := noise_textures()
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
	for material: ShaderMaterial in [plaster, metal_roof, tile_roof]:
		material.set_shader_parameter("noise_smooth", noise[0])
		material.set_shader_parameter("noise_detail", noise[1])
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
