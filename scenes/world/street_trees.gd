class_name StreetTrees
extends Node3D
## The street trees and the park trees of data/geo/build/trees.json (plan 0005,
## R12a). The trees of each type are one MultiMesh for each tile of TILE
## meters, with a visibility range, so that there are few draw calls.

const TILE := 1024.0
const VISIBLE_RANGE := 900.0

## type -> number of trees.
var counts: Dictionary = {}
var _materials: Dictionary = {}


## Reads the trees. Returns false when the file is not there.
func setup(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	var types: Dictionary = parsed.get("types", {})
	for type: String in types:
		var material := TreeKit.material(type)
		_materials[type] = material
		var tiles := {}
		for p: Array in types[type]:
			var key := Vector2i(floori(p[0] / TILE), floori(p[2] / TILE))
			if not tiles.has(key):
				tiles[key] = []
			tiles[key].append(Vector3(p[0], p[1], p[2]))
		counts[type] = (types[type] as Array).size()
		for key: Vector2i in tiles:
			_add_tile(type, key, tiles[key], material)
	return true


func _add_tile(type: String, key: Vector2i, points: Array, material: Material) -> void:
	var origin := Vector3((key.x + 0.5) * TILE, 0.0, (key.y + 0.5) * TILE)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = TreeKit.mesh(type)
	multimesh.instance_count = points.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([type, key])
	for i in points.size():
		var p: Vector3 = points[i]
		var size := rng.randf_range(0.8, 1.2)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size)
		multimesh.set_instance_transform(i, Transform3D(basis, p - origin - Vector3(0, 0.05, 0)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Trees_%s_%d_%d" % [type, key.x, key.y]
	instance.multimesh = multimesh
	instance.material_override = material
	instance.position = origin
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = VISIBLE_RANGE
	instance.visibility_range_end_margin = 50.0
	add_child(instance)


## Sets the season of all tree types (plan 0005, R12a).
func apply_season(season: Dictionary) -> void:
	for type: String in _materials:
		TreeKit.apply_season(type, _materials[type], season)
