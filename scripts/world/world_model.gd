class_name WorldModel
extends Node3D
## A model of World in the game (plan 0023, R6).
##
## WorldModel.make(id) loads the files of assets/world/ID*.glb that
## tools/world/fetch.py got for the order "id" of data/world/orders.json:
##
## - The levels (near, mid, far) are children of this one node, with the
##   visibility ranges of the quality preset (set_ranges()).
## - Each surface gets the material of the game for its role
##   (WorldMaterials, data/world/materials.json). A role with no material
##   stops the load with an error that names the role and the model.
## - joint(name) gives the node of a joint of the near level. set_pose()
##   sets joints by name, in their limits, on each level (World
##   docs/format.md, "A pose").
## - parts() gives the parts of ID.parts.json.

const ROOT := "res://assets/world/"
const ORDERS := "res://data/world/orders.json"
const LEVELS: Array[String] = ["near", "mid", "far"]
const SUFFIX := {"near": ".glb", "mid": ".mid.glb", "far": ".far.glb"}
## The end of the near level, the mid level, and the far level, for each
## preset (R8: on Low, the near level to 15 m and the mid level to 40 m).
const RANGES := {
	"low": Vector3(15.0, 40.0, 150.0),
	"medium": Vector3(20.0, 55.0, 200.0),
	"high": Vector3(30.0, 80.0, 300.0),
	"ultra": Vector3(40.0, 110.0, 400.0),
}
## The width of the fade between two levels, in meters.
const FADE := 1.5
const GROUP := &"world_models"

## The ranges now (Quality.apply() sets them with set_ranges()).
static var ranges := Vector3(15.0, 40.0, 150.0)
static var _orders: Dictionary = {}
static var _scenes: Dictionary = {}

## The id of the order in data/world/orders.json.
var id := ""
## The paint color of the model (the role "paint").
var paint := WorldMaterials.DEFAULT_PAINT
## The material set ("house" for a house, plan 0009, R7a), or "".
var material_set := ""
## The far end of this model, when it is not ranges.z (0 for ranges.z). A row
## with impostors sets it to the end of the mid level.
var far_end := 0.0
## The joints by name: {"node": the near node, "nodes": the node of each
## level, "rest": the rest transform of each node, "kind", "limits", "axis",
## "role"}.
var joints: Dictionary = {}
var _levels: Dictionary = {}  # level -> Node3D


## The entry of an id in data/world/orders.json, or {}.
static func order(model_id: String) -> Dictionary:
	if _orders.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORDERS))
		if parsed is Dictionary:
			for entry: Dictionary in parsed.get("models", []):
				_orders[entry.id] = entry
	return _orders.get(model_id, {})


## The ids of data/world/orders.json, in their order.
static func ids() -> Array[String]:
	var result: Array[String] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORDERS))
	if parsed is Dictionary:
		for entry: Dictionary in parsed.get("models", []):
			result.append(str(entry.id))
	return result


## The levels of an id that the game uses.
static func levels_of(model_id: String) -> Array[String]:
	var result: Array[String] = []
	for level: String in order(model_id).get("levels", ["near"]):
		result.append(level)
	return result


## The scene of a level of a model, loaded one time.
static func scene(model_id: String, level: String) -> PackedScene:
	var key := model_id + "/" + level
	if not _scenes.has(key):
		_scenes[key] = load(ROOT + model_id + SUFFIX[level]) as PackedScene
	return _scenes[key]


## A model of World, or null with an error.
static func make(model_id: String, model_paint := WorldMaterials.DEFAULT_PAINT, set_name := "") -> WorldModel:
	if order(model_id).is_empty():
		push_error("WorldModel: \"%s\" is not in %s." % [model_id, ORDERS])
		return null
	var model := WorldModel.new()
	model.id = model_id
	model.name = model_id
	model.paint = model_paint
	model.material_set = set_name
	if not model._build():
		model.free()
		return null
	return model


## Sets the ranges of the levels for a quality preset.
static func set_ranges(preset: String, tree: SceneTree = null) -> void:
	ranges = RANGES.get(preset, RANGES.low)
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree != null:
		for node in tree.get_nodes_in_group(GROUP):
			(node as WorldModel).apply_ranges()
		for node in tree.get_nodes_in_group(&"world_rows"):
			node.call("apply_ranges")


func _build() -> bool:
	for level: String in levels_of(id):
		var packed := scene(id, level)
		if packed == null:
			push_error("WorldModel: the model \"%s\" has no file %s." % [id, ROOT + id + SUFFIX[level]])
			return false
		var node := packed.instantiate() as Node3D
		node.name = level
		add_child(node)
		_levels[level] = node
		if not _apply_materials(node, level):
			return false
		_collect_joints(node, level)
	add_to_group(GROUP)
	apply_ranges()
	return true


func _apply_materials(root: Node, level: String) -> bool:
	var library := WorldMaterials.shared()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var mesh := mesh_node.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var source := mesh.surface_get_material(i)
			var role := source.resource_name if source != null else ""
			var material := library.material_for(role, source, paint, material_set)
			if material == null:
				push_error("WorldModel: the role \"%s\" of the model \"%s\" (%s level) has no material in %s." % [
						role, id, level, WorldMaterials.PATH])
				return false
			mesh_node.set_surface_override_material(i, material)
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		var multi := node as MultiMeshInstance3D
		var mesh := multi.multimesh.mesh if multi.multimesh else null
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var source := mesh.surface_get_material(0)
		var role := source.resource_name if source != null else ""
		var material := library.material_for(role, source, paint, material_set)
		if material == null:
			push_error("WorldModel: the role \"%s\" of the model \"%s\" (%s level) has no material in %s." % [
					role, id, level, WorldMaterials.PATH])
			return false
		multi.material_override = material
	return true


func _collect_joints(root: Node, level: String) -> void:
	for node in root.find_children("*", "Node3D", true, false):
		if not node.has_meta("extras"):
			continue
		var extras: Variant = node.get_meta("extras")
		if not extras is Dictionary or not (extras as Dictionary).has("kind"):
			continue
		var joint_name := String(node.name)
		if not joints.has(joint_name):
			var axis_values: Array = extras.get("axis", [0.0, 1.0, 0.0])
			joints[joint_name] = {"kind": str(extras.kind), "role": str(extras.get("role", "")),
					"limits": extras.get("limits"), "axis": Vector3(axis_values[0], axis_values[1], axis_values[2]),
					"nodes": {}, "rest": {}, "node": null}
		var joint_entry: Dictionary = joints[joint_name]
		joint_entry.nodes[level] = node
		joint_entry.rest[level] = (node as Node3D).transform
		if level == "near":
			joint_entry.node = node


## Sets the visibility ranges of the levels from the ranges of the preset.
func apply_ranges() -> void:
	var used := levels_of(id)
	var far := far_end if far_end > 0.0 else ranges.z
	var begin := 0.0
	for i in used.size():
		var level: String = used[i]
		var end := far
		if i < used.size() - 1:
			end = ranges.x if level == "near" else ranges.y
		var node: Node3D = _levels.get(level)
		if node == null:
			continue
		for geometry in node.find_children("*", "GeometryInstance3D", true, false):
			var g := geometry as GeometryInstance3D
			g.visibility_range_begin = begin
			g.visibility_range_end = end
			g.visibility_range_begin_margin = FADE if begin > 0.0 else 0.0
			g.visibility_range_end_margin = FADE
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		begin = end


## The node of a level ("near", "mid", "far").
func level(level_name: String) -> Node3D:
	return _levels.get(level_name)


## The node of a joint of the near level, or null.
func joint(joint_name: String) -> Node3D:
	return joints.get(joint_name, {}).get("node")


## The names of the joints with a role ("wheel", "steer", "stand", "spin" ...).
func joints_with_role(role: String) -> Array[String]:
	var result: Array[String] = []
	for joint_name: String in joints:
		if joints[joint_name].role == role:
			result.append(joint_name)
	return result


## Sets joints by name: degrees for a hinge, meters for a slide. A value out
## of the limits stops at the nearest limit, as a real joint stops.
func set_pose(pose: Dictionary) -> void:
	for joint_name: String in pose:
		if not joints.has(joint_name):
			push_warning("WorldModel: the model \"%s\" has no joint \"%s\"." % [id, joint_name])
			continue
		var j: Dictionary = joints[joint_name]
		var value := clamp_value(j, float(pose[joint_name]))
		for level_name: String in j.nodes:
			var node: Node3D = j.nodes[level_name]
			var rest: Transform3D = j.rest[level_name]
			var axis: Vector3 = j.axis.normalized()
			if j.kind == "slide":
				node.transform = Transform3D(rest.basis, rest.origin + rest.basis * (axis * value))
			else:
				node.transform = Transform3D(rest.basis * Basis(axis, deg_to_rad(value)), rest.origin)


## The value of a joint in its limits.
static func clamp_value(j: Dictionary, value: float) -> float:
	var limits: Variant = j.get("limits")
	if limits is Array and (limits as Array).size() == 2:
		return clampf(value, float(limits[0]), float(limits[1]))
	return value


## The parts of the model (ID.parts.json): name, kind, count, params, sources.
func parts() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + id + ".parts.json"))
	return parsed.get("parts", []) if parsed is Dictionary else []


## The receipt of the order (ID.receipt.json): the full order, the hash, the
## size, the joints, and the sources.
func receipt() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + id + ".receipt.json"))
	return parsed if parsed is Dictionary else {}


## The box of the points of the meshes of a level, in the frame of this node.
func level_aabb(level_name := "near") -> AABB:
	var node: Node3D = _levels.get(level_name)
	var box := AABB()
	var first := true
	if node == null:
		return box
	var inverse := global_transform.affine_inverse() if is_inside_tree() else Transform3D.IDENTITY
	for geometry in node.find_children("*", "MeshInstance3D", true, false):
		var m := geometry as MeshInstance3D
		if m.mesh == null:
			continue
		# The points of the mesh, not its box: a turned box is larger than
		# the turned mesh.
		var to_model := inverse * _global_of(m)
		for point in m.mesh.get_faces():
			var p := to_model * point
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
	return box


# The transform of a node in the frame of this model, also outside a tree.
func _global_of(node: Node3D) -> Transform3D:
	if node.is_inside_tree():
		return node.global_transform
	var t := node.transform
	var parent := node.get_parent()
	while parent != null and parent != self and parent is Node3D:
		t = (parent as Node3D).transform * t
		parent = parent.get_parent()
	return t
