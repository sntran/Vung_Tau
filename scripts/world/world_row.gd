class_name WorldRow
extends Node3D
## A row of models of World in MultiMeshes (plan 0023, D5, R8): the parked
## scooters on a sidewalk, the boats far out, a crowd far away.
##
## add() puts a model with its transform, its paint, and its pose. build()
## groups the models in cells of CELL meters. Each cell has a MultiMesh for
## each mesh of the near level and of the mid level, and one MultiMesh of
## cards for the impostor (tools/world/impostors.py). The visibility ranges
## of the cells come from the quality preset (WorldModel.ranges): the near
## level to ranges.x, the mid level to ranges.y, then the impostor to
## ranges.z.

const CELL := 6.0
const IMPOSTORS := "res://assets/world/impostors.json"
const SHADER := "res://shaders/world_impostor.gdshader"
const ROW_LEVELS: Array[String] = ["near", "mid"]
const GROUP := &"world_rows"

static var _impostors: Dictionary = {}
static var _impostor_materials: Dictionary = {}
static var _meshes: Dictionary = {}  # model/level/node -> Mesh with the materials of the game
static var _templates: Dictionary = {}  # model -> WorldModel, not in a tree

var _items: Array[Dictionary] = []
## The cells: {"near": [MultiMeshInstance3D], "mid": [...], "impostor": [...]}.
var cells: Array[Dictionary] = []


## Puts a model in the row. "at" is in the frame of the row.
func add(model_id: String, at: Transform3D, paint := WorldMaterials.DEFAULT_PAINT, pose := {}) -> void:
	_items.append({"id": model_id, "at": at, "paint": paint, "pose": pose})


## The number of models in the row.
func count() -> int:
	return _items.size()


## Makes the MultiMeshes of the cells. Call it one time, after add().
func build() -> void:
	var by_cell := {}
	for item in _items:
		var origin: Vector3 = item.at.origin
		var key := Vector2i(floori(origin.x / CELL), floori(origin.z / CELL))
		if not by_cell.has(key):
			by_cell[key] = []
		by_cell[key].append(item)
	for key: Vector2i in by_cell:
		_build_cell(key, by_cell[key])
	add_to_group(GROUP)
	apply_ranges()


func _build_cell(key: Vector2i, items: Array) -> void:
	var cell := Node3D.new()
	cell.name = "cell_%d_%d" % [key.x, key.y]
	var center := Vector3.ZERO
	for item: Dictionary in items:
		center += item.at.origin
	center /= float(items.size())
	cell.position = center
	add_child(cell)
	var entry := {"near": [], "mid": [], "impostor": [], "node": cell}
	# For each level and each mesh node: the transform of each model.
	var batches := {}  # "level/model/node" -> {"mesh", "transforms", "colors"}
	for item: Dictionary in items:
		var template := _template(item.id)
		if template == null:
			continue
		template.set_pose(_rest_pose(template))
		template.set_pose(item.pose)
		var local_at := Transform3D(item.at.basis, item.at.origin - center)
		for level: String in ROW_LEVELS:
			var level_node := template.level(level)
			if level_node == null:
				continue
			for node in level_node.find_children("*", "MeshInstance3D", true, false):
				var m := node as MeshInstance3D
				var batch_key := "%s/%s/%s" % [level, item.id, template.level(level).get_path_to(m)]
				if not batches.has(batch_key):
					batches[batch_key] = {"level": level, "mesh": _row_mesh(batch_key, m),
							"transforms": [], "colors": []}
				batches[batch_key].transforms.append(local_at * template._global_of(m))
				batches[batch_key].colors.append(item.paint)
	for batch_key: String in batches:
		var batch: Dictionary = batches[batch_key]
		var node := _multimesh_node(batch.mesh, batch.transforms, batch.colors)
		node.name = batch_key.replace("/", "_")
		cell.add_child(node)
		entry[batch.level].append(node)
	# The impostor: one card for each model.
	var by_model := {}
	for item: Dictionary in items:
		if not by_model.has(item.id):
			by_model[item.id] = []
		by_model[item.id].append(item)
	for model_id: String in by_model:
		var values := impostor_values(model_id)
		if values.is_empty():
			continue
		var size := float(values.size)
		var quad := QuadMesh.new()
		quad.size = Vector2(size, size)
		quad.center_offset = Vector3(0.0, size / 2.0, 0.0)
		quad.material = impostor_material(model_id)
		var transforms := []
		var colors := []
		for item: Dictionary in by_model[model_id]:
			transforms.append(Transform3D(item.at.basis, item.at.origin - center))
			colors.append(item.paint)
		var card := _multimesh_node(quad, transforms, colors)
		card.name = "impostor_" + model_id
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cell.add_child(card)
		entry.impostor.append(card)
	cells.append(entry)


static func _rest_pose(template: WorldModel) -> Dictionary:
	var pose := {}
	for joint_name: String in template.joints:
		pose[joint_name] = 0.0
	return pose


static func _template(model_id: String) -> WorldModel:
	if not _templates.has(model_id):
		_templates[model_id] = WorldModel.make(model_id)
	return _templates[model_id]


## The mesh of a node of a template with the materials of the game for a
## MultiMesh: the paint takes the color of each instance.
static func _row_mesh(key: String, node: MeshInstance3D) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var mesh := node.mesh.duplicate() as Mesh
	for i in mesh.get_surface_count():
		var material := node.get_surface_override_material(i)
		if material is StandardMaterial3D and material.resource_name != "" \
				and WorldMaterials.shared().is_paint(material.resource_name):
			material = row_paint_material(material as StandardMaterial3D)
		mesh.surface_set_material(i, material)
	_meshes[key] = mesh
	return mesh


## The paint material of a row: white, times the color of each instance.
static func row_paint_material(paint: StandardMaterial3D) -> StandardMaterial3D:
	var key := "paint/%d" % paint.get_instance_id()
	if not _meshes.has(key):
		var m := paint.duplicate() as StandardMaterial3D
		m.albedo_color = Color.WHITE
		m.vertex_color_use_as_albedo = true
		_meshes[key] = m
	return _meshes[key]


static func _multimesh_node(mesh: Mesh, transforms: Array, colors: Array) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	return node


## The values of the impostor of a model (assets/world/impostors.json): the
## size of a cell in meters and the views. {} when the model has none.
static func impostor_values(model_id: String) -> Dictionary:
	if _impostors.is_empty() and FileAccess.file_exists(IMPOSTORS):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(IMPOSTORS))
		if parsed is Dictionary:
			_impostors = parsed.get("models", {})
	return _impostors.get(model_id, {})


static func impostor_material(model_id: String) -> ShaderMaterial:
	if not _impostor_materials.has(model_id):
		var values := impostor_values(model_id)
		var m := ShaderMaterial.new()
		m.shader = load(SHADER) as Shader
		m.set_shader_parameter("impostor", load(WorldModel.ROOT + model_id + "_impostor.png"))
		m.set_shader_parameter("impostor_normal", load(WorldModel.ROOT + model_id + "_impostor_normal.png"))
		m.set_shader_parameter("views", float(values.get("views", 8)))
		m.set_shader_parameter("cell_size", float(values.get("size", 2.0)))
		_impostor_materials[model_id] = m
	return _impostor_materials[model_id]


## Sets the visibility ranges of the cells from the ranges of the preset.
func apply_ranges() -> void:
	var r := WorldModel.ranges
	for entry in cells:
		_set_range(entry.near, 0.0, r.x)
		_set_range(entry.mid, r.x, r.y)
		_set_range(entry.impostor, r.y, r.z)


static func _set_range(nodes: Array, begin: float, end: float) -> void:
	for node: GeometryInstance3D in nodes:
		node.visibility_range_begin = begin
		node.visibility_range_end = end
		node.visibility_range_begin_margin = WorldModel.FADE if begin > 0.0 else 0.0
		node.visibility_range_end_margin = WorldModel.FADE
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## The level that a cell shows at a distance: "near", "mid", "impostor", or "".
static func level_at(distance: float) -> String:
	var r := WorldModel.ranges
	if distance < r.x:
		return "near"
	if distance < r.y:
		return "mid"
	if distance < r.z:
		return "impostor"
	return ""
