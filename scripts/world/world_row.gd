class_name WorldRow
extends Node3D
## A row of models of World in MultiMeshes (plan 0023, D5, R8): the parked
## scooters on a sidewalk, the boats far out, a crowd far away.
##
## add() puts a model with its transform, its paint, and its pose. build()
## groups the models in cells of CELL meters. Each cell has a MultiMesh for
## each mesh of the near level and of the mid level, and one MultiMesh of
## cards for the impostor (tools/world/impostors.py). A model with no
## impostor (a piece of a wall) has its far level in place of the cards. The
## visibility ranges of the cells come from the quality preset
## (WorldModel.ranges): the near level to ranges.x, the mid level to
## ranges.y, then the impostor (or the far level) to ranges.z.

const CELL := 6.0
const IMPOSTORS := "res://assets/world/impostors.json"
const SHADER := "res://shaders/world_impostor.gdshader"
const ROW_LEVELS: Array[String] = ["near", "mid"]
const GROUP := &"world_rows"

static var _impostors: Dictionary = {}
static var _impostor_materials: Dictionary = {}
static var _meshes: Dictionary = {}  # model/level/node -> Mesh with the materials of the game
static var _templates: Dictionary = {}  # model -> WorldModel, not in a tree

## The size of a cell (m): larger cells give fewer draw calls (a row of the
## pieces of a wall).
var cell_size := CELL
## The set of materials of the models of the row ("house": the houses of plan
## 0009, R7a).
var material_set := ""
## The ranges of the levels for each preset (preset name -> Vector3), over
## WorldModel.ranges. A near range of 0 hides the near level (the pieces of a
## wall on Low, as the buildings of plan 0026, D6).
var custom_ranges: Dictionary = {}
## Plan 0031, D14: false when the cells cast no shadow (also a cell made again).
var shadow := true
var _items: Array[Dictionary] = []
## The cells: {"near": [MultiMeshInstance3D], "mid": [...], "mid_whole": [...], "impostor": [...]}.
var cells: Array[Dictionary] = []


## Puts a model in the row. "at" is in the frame of the row.
func add(model_id: String, at: Transform3D, paint := WorldMaterials.DEFAULT_PAINT, pose := {}) -> void:
	_items.append({"id": model_id, "at": at, "paint": paint, "pose": pose, "index": _items.size(), "slots": []})


## Plan 0018, R4: the models of the row with this id, each {"index", "at"
## (in the world), "paint", "pose", "hidden"}.
func items_of(model_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in _items:
		if item.id == model_id:
			out.append({"index": item.index, "at": global_transform * (item.at as Transform3D),
					"paint": item.paint, "pose": item.pose, "hidden": item.get("hidden", false)})
	return out


## Plan 0018, R4: hides a model of the row (a scooter that the player rides)
## or shows it again. Each MultiMesh of its cell gives it a transform of size 0.
func set_hidden(index: int, hidden: bool) -> void:
	if index < 0 or index >= _items.size():
		return
	var item: Dictionary = _items[index]
	item.hidden = hidden
	for slot: Array in item.slots:
		var multimesh: MultiMesh = slot[0]
		var t: Transform3D = slot[2]
		if hidden:
			t = Transform3D(Basis().scaled(Vector3.ZERO), t.origin)
		# The buffer, as _multimesh_node(): the headless renderer does not keep
		# set_instance_transform() (AGENTS.md, section 5).
		var buffer := multimesh.buffer
		var at := 16 * int(slot[1])
		for row in 3:
			buffer[at + 4 * row] = t.basis.x[row]
			buffer[at + 4 * row + 1] = t.basis.y[row]
			buffer[at + 4 * row + 2] = t.basis.z[row]
			buffer[at + 4 * row + 3] = t.origin[row]
		multimesh.buffer = buffer


## The number of models in the row.
func count() -> int:
	return _items.size()


## Makes the MultiMeshes of the cells. Call it one time, after add().
func build() -> void:
	var by_cell := {}
	for item in _items:
		var origin: Vector3 = item.at.origin
		var key := Vector2i(floori(origin.x / cell_size), floori(origin.z / cell_size))
		if not by_cell.has(key):
			by_cell[key] = []
		by_cell[key].append(item)
	for key: Vector2i in by_cell:
		cells.append(_build_cell(key, by_cell[key]))
	_free_templates()
	add_to_group(GROUP)
	apply_ranges()


## The templates are nodes outside the tree: free them, or they stay at the quit.
static func _free_templates() -> void:
	for model_id: String in _templates:
		if is_instance_valid(_templates[model_id]):
			(_templates[model_id] as Node).free()
	_templates.clear()


## Plan 0031, D14: true when a model of a cell has more levels now than when
## the cell was made (a pack of the web build came).
func cell_needs_upgrade(index: int) -> bool:
	var built: Dictionary = cells[index].built
	for model_id: String in built:
		if WorldModel.levels_of(model_id).size() > int(built[model_id]):
			return true
	return false


func needs_upgrade() -> bool:
	for index in cells.size():
		if cell_needs_upgrade(index):
			return true
	return false


## Plan 0031, D14: makes a cell again with the levels that came, and then frees
## the old cell (no frame with no cell). The hidden models stay hidden.
func upgrade_cell(index: int) -> void:
	if index < 0 or index >= cells.size() or not cell_needs_upgrade(index):
		return
	var old: Dictionary = cells[index]
	for item: Dictionary in old.items:
		item.slots = []
	var entry := _build_cell(old.key, old.items)
	_free_templates()
	cells[index] = entry
	for item: Dictionary in old.items:
		if item.get("hidden", false):
			set_hidden(int(item.index), true)
	(old.node as Node).queue_free()
	_apply_cell_ranges(entry, custom_ranges.get(WorldModel.preset, WorldModel.ranges))


## Makes the next cell that waits for its better levels (a unit test).
func upgrade_next() -> void:
	for index in cells.size():
		if cell_needs_upgrade(index):
			upgrade_cell(index)
			return


func _build_cell(key: Vector2i, items: Array) -> Dictionary:
	var cell := Node3D.new()
	cell.name = "cell_%d_%d" % [key.x, key.y]
	var center := Vector3.ZERO
	for item: Dictionary in items:
		center += item.at.origin
	center /= float(items.size())
	cell.position = center
	add_child(cell)
	# "mid_whole": the mid level of a model with no near file (plan 0031, D4:
	# the web pack has no near level of a building), from 0 m.
	# "far_whole" (D14): the far level of a model whose mid and near levels are
	# in a pack that is not there yet, from 0 m (no hole), with no card.
	var entry := {"near": [], "mid": [], "mid_whole": [], "far_whole": [], "impostor": [], "node": cell,
			"key": key, "items": items, "built": {}}
	var far_only := {}
	# For each level and each mesh node: the transform of each model.
	var batches := {}  # "level/model/node" -> {"mesh", "transforms", "colors"}
	for item: Dictionary in items:
		var template := _template(item.id, material_set)
		if template == null:
			continue
		entry.built[item.id] = WorldModel.levels_of(item.id).size()
		if template.level("near") == null and template.level("mid") == null:
			far_only[item.id] = true
		template.set_pose(_rest_pose(template))
		template.set_pose(item.pose)
		var local_at := Transform3D(item.at.basis, item.at.origin - center)
		var levels := ROW_LEVELS.duplicate()
		if impostor_values(item.id).is_empty() or far_only.has(item.id):
			levels.append("far")
		for level: String in levels:
			var level_node := template.level(level)
			if level_node == null:
				continue
			for node in level_node.find_children("*", "MeshInstance3D", true, false):
				var m := node as MeshInstance3D
				var batch_key := "%s/%s/%s/%s" % [level, item.id, material_set, template.level(level).get_path_to(m)]
				if not batches.has(batch_key):
					batches[batch_key] = {"level": level, "mesh": _row_mesh(batch_key, m, material_set),
							"transforms": [], "colors": [], "items": [],
							"whole": (level == "mid" and template.level("near") == null) or (level == "far" and far_only.has(item.id))}
				batches[batch_key].transforms.append(local_at * template._global_of(m))
				batches[batch_key].colors.append(item.paint)
				batches[batch_key].items.append(item)
	for batch_key: String in batches:
		var batch: Dictionary = batches[batch_key]
		var node := _multimesh_node(batch.mesh, batch.transforms, batch.colors)
		node.name = batch_key.replace("/", "_")
		if not shadow:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cell.add_child(node)
		for i in batch.items.size():
			(batch.items[i].slots as Array).append([node.multimesh, i, batch.transforms[i]])
		# The far level of a model with no impostor takes the range of the cards.
		var part: String = batch.level
		if batch.level == "far":
			part = "far_whole" if batch.whole else "impostor"
		elif batch.whole:
			part = "mid_whole"
		entry[part].append(node)
	# The impostor: one card for each model.
	var by_model := {}
	for item: Dictionary in items:
		if not by_model.has(item.id):
			by_model[item.id] = []
		by_model[item.id].append(item)
	for model_id: String in by_model:
		var values := impostor_values(model_id)
		if values.is_empty() or far_only.has(model_id):
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
		for i in by_model[model_id].size():
			(by_model[model_id][i].slots as Array).append([card.multimesh, i, transforms[i]])
		card.name = "impostor_" + model_id
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cell.add_child(card)
		entry.impostor.append(card)
	return entry


static func _rest_pose(template: WorldModel) -> Dictionary:
	var pose := {}
	for joint_name: String in template.joints:
		pose[joint_name] = 0.0
	return pose


static func _template(model_id: String, set_name := "") -> WorldModel:
	var key := model_id + "/" + set_name
	if not _templates.has(key):
		_templates[key] = WorldModel.make(model_id, WorldMaterials.DEFAULT_PAINT, set_name)
	return _templates[key]


## The mesh of a node of a template with the materials of the game for a
## MultiMesh: the paint takes the color of each instance.
static func _row_mesh(key: String, node: MeshInstance3D, set_name := "") -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var mesh := node.mesh.duplicate() as Mesh
	var painted: Array[int] = []
	for i in mesh.get_surface_count():
		var material := node.get_surface_override_material(i)
		if material is StandardMaterial3D and material.resource_name != "" \
				and WorldMaterials.shared().is_paint(material.resource_name, set_name):
			material = row_paint_material(material as StandardMaterial3D)
			painted.append(i)
		mesh.surface_set_material(i, material)
	# A house of World (the set "house") has vertex colors that are not its
	# paint: the painted surfaces drop them, so the paint of each copy shows.
	if set_name == "house" and not painted.is_empty() and mesh is ArrayMesh:
		mesh = _without_colors(mesh as ArrayMesh, painted)
	_meshes[key] = mesh
	return mesh


## The mesh with no vertex colors on the surfaces of the list.
static func _without_colors(mesh: ArrayMesh, surfaces: Array[int]) -> ArrayMesh:
	var out := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		if surfaces.has(i):
			arrays[Mesh.ARRAY_COLOR] = null
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(i), arrays)
		out.surface_set_material(i, mesh.surface_get_material(i))
	return out


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
	# The buffer, not set_instance_transform(): the headless renderer does not
	# keep the instance transforms (AGENTS.md, section 5). For each instance:
	# 12 floats of the transform (a row of the basis and the origin at a
	# time), then 4 floats of the color.
	var buffer := PackedFloat32Array()
	buffer.resize(16 * transforms.size())
	for i in transforms.size():
		var t: Transform3D = transforms[i]
		var c: Color = colors[i]
		for row in 3:
			buffer[16 * i + 4 * row] = t.basis.x[row]
			buffer[16 * i + 4 * row + 1] = t.basis.y[row]
			buffer[16 * i + 4 * row + 2] = t.basis.z[row]
			buffer[16 * i + 4 * row + 3] = t.origin[row]
		buffer[16 * i + 12] = c.r
		buffer[16 * i + 13] = c.g
		buffer[16 * i + 14] = c.b
		buffer[16 * i + 15] = c.a
	multimesh.buffer = buffer
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
	var r: Vector3 = custom_ranges.get(WorldModel.preset, WorldModel.ranges)
	for entry in cells:
		_apply_cell_ranges(entry, r)


static func _apply_cell_ranges(entry: Dictionary, r: Vector3) -> void:
	_set_range(entry.near, 0.0, r.x)
	_set_range(entry.mid, r.x, r.y)
	_set_range(entry.mid_whole, 0.0, r.y)
	_set_range(entry.far_whole, 0.0, r.z)
	_set_range(entry.impostor, r.y, r.z)


static func _set_range(nodes: Array, begin: float, end: float) -> void:
	for node: GeometryInstance3D in nodes:
		# An end of 0 is no end in Godot: a level with no range does not show.
		node.visible = end > begin
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
