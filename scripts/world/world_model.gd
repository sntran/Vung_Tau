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
## The preset of the ranges now.
static var preset := "low"
static var _orders: Dictionary = {}
static var _scenes: Dictionary = {}
static var _requested: Dictionary = {}  # the paths in the load of request()
static var _dropped: Dictionary = {}  # the paths whose load of request() is not used
static var _lowest: Dictionary = {}  # id/level -> the lowest point of the level at rest
static var _merged: Dictionary = {}  # id/paint/set -> the far mesh of a person with one opaque surface
static var _merged_material: StandardMaterial3D
static var _map_means: Dictionary = {}  # texture id -> the mean color of the map (linear)

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
## The turns in a minute of the joints with the role "spin" (a fan): 0 stops them.
var spin_rpm := 0.0:
	set(value):
		spin_rpm = value
		set_process(value != 0.0)
## The ranges of the levels for each preset (preset name -> Vector3), over WorldModel.RANGES.
var custom_ranges: Dictionary = {}
var _levels: Dictionary = {}  # level -> Node3D
var _spin_angle := 0.0


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
	release_dropped()
	var key := model_id + "/" + level
	if not _scenes.has(key):
		var path: String = ROOT + model_id + SUFFIX[level]
		if _requested.has(path) and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			_requested.erase(path)
			_scenes[key] = ResourceLoader.load_threaded_get(path) as PackedScene
		elif _requested.has(path):
			# The main thread does not wait for the load in the other thread: in CI
			# (the CI of 308cbc2, report 0026) such a wait in build_all() stopped the
			# game for more than 4 minutes. The main thread loads its own copy, and
			# release_dropped() frees the other copy when its load ends.
			_requested.erase(path)
			_dropped[path] = true
			_scenes[key] = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		else:
			_scenes[key] = load(path) as PackedScene
	return _scenes[key]


## Frees each load of request() that scene() did not use, when it ends.
static func release_dropped() -> void:
	for path: String in _dropped.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		if status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_FAILED:
			ResourceLoader.load_threaded_get(path)
		_dropped.erase(path)


## The levels of a model that the preset shows, with the ranges of its place
## (report 0026, Q24: on Low a building has no near level, plan 0026, D6, and
## the file of the near level is not loaded: its pictures took video memory).
static func levels_shown(model_id: String, model_ranges := {}) -> Array[String]:
	var result: Array[String] = []
	var r: Vector3 = model_ranges.get(preset, ranges)
	for level: String in levels_of(model_id):
		if level == "near" and r.x <= 0.0:
			continue
		result.append(level)
	return result


## Starts the load of the files of the levels of a model in other threads, so
## that make() does not wait for them (report 0026, D-0026-12).
static func request(model_id: String, model_ranges := {}) -> void:
	for level: String in levels_shown(model_id, model_ranges):
		var path: String = ROOT + model_id + SUFFIX[level]
		if _scenes.has(model_id + "/" + level) or _requested.has(path):
			continue
		if ResourceLoader.load_threaded_request(path) == OK:
			_requested[path] = true


## True when no file of a level of the model is still in the load of request().
static func is_loaded(model_id: String, model_ranges := {}) -> bool:
	for level: String in levels_shown(model_id, model_ranges):
		var path: String = ROOT + model_id + SUFFIX[level]
		if _requested.has(path) and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return false
	return true


## A model of World, or null with an error.
static func make(model_id: String, model_paint := WorldMaterials.DEFAULT_PAINT, set_name := "", model_ranges := {}) -> WorldModel:
	if order(model_id).is_empty():
		push_error("WorldModel: \"%s\" is not in %s." % [model_id, ORDERS])
		return null
	var model := WorldModel.new()
	model.id = model_id
	model.name = model_id
	model.paint = model_paint
	model.material_set = set_name
	model.custom_ranges = model_ranges
	if not model._build():
		model.free()
		return null
	return model


## Sets the ranges of the levels for a quality preset.
static func set_ranges(preset_name: String, tree: SceneTree = null) -> void:
	ranges = RANGES.get(preset_name, RANGES.low)
	preset = preset_name if RANGES.has(preset_name) else "low"
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree != null:
		for node in tree.get_nodes_in_group(GROUP):
			(node as WorldModel).apply_ranges()
		for node in tree.get_nodes_in_group(&"world_rows"):
			node.call("apply_ranges")


func _build() -> bool:
	for level: String in levels_shown(id, custom_ranges):
		if not _add_level(level):
			return false
	add_to_group(GROUP)
	apply_ranges()
	return true


func _add_level(level: String) -> bool:
	var packed := scene(id, level)
	if packed == null:
		push_error("WorldModel: the model \"%s\" has no file %s." % [id, ROOT + id + SUFFIX[level]])
		return false
	var node := packed.instantiate() as Node3D
	node.name = level
	add_child(node)
	if level == "near" and get_child_count() > 1:
		move_child(node, 0)
	_levels[level] = node
	# R7: the model stands on y = 0. A mid or far level of World can be
	# a little higher or lower (the soles of the shoes of a person are
	# 1 to 2 cm higher at the mid level): the level moves to the ground.
	node.position.y = -_lowest_of(level, node)
	if not _apply_materials(node, level):
		return false
	if level == "far" and not node.find_children("*", "Skeleton3D", true, false).is_empty():
		_merge_surfaces(node)
	_collect_joints(node, level)
	return true


## Report 0026, D-0026-42: the far level of a person of World has 7 to 11
## surfaces (each garment, the skin, the eyes), and each surface is a draw
## call: the 40 people of S5 made 266 of its 597 draw calls on Low. The opaque
## surfaces become one surface with the same color at each point: the color of
## its material, times its vertex color when the material uses it, times the
## mean color of its map (the skin and the eyes), in linear light, kept as sRGB. The blend shapes
## (the blink of the eyes) stay on the merged surface. A transparent surface
## stays as it is.
func _merge_surfaces(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh := mi.mesh as ArrayMesh
		if mesh == null or mesh.get_surface_count() < 2:
			continue
		var key := "%s/%s/%s/%s" % [id, paint.to_html(false), material_set, mi.name]
		if not _merged.has(key):
			_merged[key] = _merged_mesh(mi)
		var merged: Array = _merged[key]
		if merged.is_empty():
			continue
		mi.mesh = merged[0]
		for i in mi.get_surface_override_material_count():
			mi.set_surface_override_material(i, null)
		var kept: Array = merged[1]
		for i in kept.size():
			mi.set_surface_override_material(i + 1, kept[i])
		if _merged_material == null:
			_merged_material = StandardMaterial3D.new()
			_merged_material.resource_name = "merged_far"
			_merged_material.vertex_color_use_as_albedo = true
			_merged_material.vertex_color_is_srgb = true
			_merged_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_merged_material.roughness = 0.9
			_merged_material.metallic_specular = 0.5
		mi.set_surface_override_material(0, _merged_material)


## [the new mesh (the merged surface first, then the kept surfaces), the
## materials of the kept surfaces], or [] when no two surfaces merge.
static func _merged_mesh(mi: MeshInstance3D) -> Array:
	var mesh := mi.mesh as ArrayMesh
	var opaque: Array[int] = []
	var kept: Array[int] = []
	var flags := 0
	for i in mesh.get_surface_count():
		var m := mi.get_active_material(i) as StandardMaterial3D
		var format := mesh.surface_get_format(i)
		if m == null or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mesh.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES:
			kept.append(i)
			continue
		var surface_flags := format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		if not opaque.is_empty() and surface_flags != flags:
			kept.append(i)
			continue
		flags = surface_flags
		opaque.append(i)
	if opaque.size() < 2:
		return []
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var shapes := mesh.get_blend_shape_count()
	var shape_vertices: Array[PackedVector3Array] = []
	var shape_normals: Array[PackedVector3Array] = []
	for k in shapes:
		shape_vertices.append(PackedVector3Array())
		shape_normals.append(PackedVector3Array())
	var skinned := true
	for i in opaque:
		var arrays := mesh.surface_get_arrays(i)
		var surface_shapes := mesh.surface_get_blend_shape_arrays(i)
		for k in shapes:
			var shape: Array = surface_shapes[k] if k < surface_shapes.size() else []
			var sv: Variant = shape[Mesh.ARRAY_VERTEX] if shape.size() > Mesh.ARRAY_VERTEX else null
			var sn: Variant = shape[Mesh.ARRAY_NORMAL] if shape.size() > Mesh.ARRAY_NORMAL else null
			shape_vertices[k].append_array(sv if sv != null else arrays[Mesh.ARRAY_VERTEX])
			shape_normals[k].append_array(sn if sn != null else (arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()))
		var m := mi.get_active_material(i) as StandardMaterial3D
		var base := m.albedo_color.srgb_to_linear()
		if m.albedo_texture != null:
			base *= _map_mean(m.albedo_texture)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var start := vertices.size()
		vertices.append_array(points)
		var n: Variant = arrays[Mesh.ARRAY_NORMAL]
		normals.append_array(n if n != null else PackedVector3Array())
		var c: Variant = arrays[Mesh.ARRAY_COLOR]
		for k in points.size():
			var color := base
			if c != null and m.vertex_color_use_as_albedo:
				var v: Color = (c as PackedColorArray)[k]
				color *= v.srgb_to_linear() if m.vertex_color_is_srgb else v
			# The points keep 8 bits for each color: sRGB keeps the steps of the dark colors.
			colors.append(Color(color.r, color.g, color.b, 1.0).linear_to_srgb())
		if arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
			skinned = false
		else:
			bones.append_array(arrays[Mesh.ARRAY_BONES])
			weights.append_array(arrays[Mesh.ARRAY_WEIGHTS])
		var index: Variant = arrays[Mesh.ARRAY_INDEX]
		if index == null:
			for k in points.size():
				indices.append(start + k)
		else:
			for k: int in index:
				indices.append(start + k)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if normals.size() == vertices.size():
		arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	if skinned:
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var out := ArrayMesh.new()
	out.blend_shape_mode = mesh.blend_shape_mode
	var blend_arrays := []
	for k in shapes:
		out.add_blend_shape(mesh.get_blend_shape_name(k))
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = shape_vertices[k]
		if arrays[Mesh.ARRAY_NORMAL] != null:
			shape[Mesh.ARRAY_NORMAL] = shape_normals[k]
		blend_arrays.append(shape)
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blend_arrays, {}, flags)
	var materials := []
	for i in kept:
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(i), mesh.surface_get_arrays(i), mesh.surface_get_blend_shape_arrays(i), {},
				mesh.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		materials.append(mi.get_active_material(i))
	out.resource_name = mesh.resource_name
	return [out, materials]


## The mean color of a map (linear), one time for each map.
static func _map_mean(texture: Texture2D) -> Color:
	var key := texture.get_instance_id()
	if _map_means.has(key):
		return _map_means[key]
	var mean := Color.WHITE
	var image := texture.get_image()
	if image != null:
		image = image.duplicate() as Image
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(16, 16, Image.INTERPOLATE_BILINEAR)
		var sum := Color(0, 0, 0, 0)
		for y in image.get_height():
			for x in image.get_width():
				sum += image.get_pixel(x, y).srgb_to_linear()
		var count := float(image.get_width() * image.get_height())
		mean = Color(sum.r / count, sum.g / count, sum.b / count, 1.0)
	_map_means[key] = mean
	return mean


# The lowest point of the meshes of a level at rest, one time for each model.
func _lowest_of(level_name: String, node: Node3D) -> float:
	var key := id + "/" + level_name
	if _lowest.has(key):
		return _lowest[key]
	var low := INF
	for geometry in node.find_children("*", "MeshInstance3D", true, false):
		var m := geometry as MeshInstance3D
		if m.mesh == null:
			continue
		var t := _global_of(m)
		for point in m.mesh.get_faces():
			low = minf(low, (t * point).y)
	if low == INF:
		low = 0.0
	_lowest[key] = low
	return low


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
			# A sculpture of this game (data/world/drawings/) has the colors at its
			# points: a kept material with no image map shows them.
			if material == source and (mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0:
				material = library.with_vertex_colors(material)
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


func _ready() -> void:
	set_process(spin_rpm != 0.0)


func _process(delta: float) -> void:
	# The game time: a fan turns slower when the frame rate is low.
	_spin_angle = fmod(_spin_angle + spin_rpm * 6.0 * delta, 360.0)
	var pose := {}
	for joint_name in joints_with_role("spin"):
		pose[joint_name] = _spin_angle
	set_pose(pose)


## Sets the visibility ranges of the levels from the ranges of the preset.
func apply_ranges() -> void:
	var used := levels_of(id)
	# A building of the showcase has the ranges of its place for each preset
	# (plan 0026, D6: on Low it has no near level).
	var r: Vector3 = custom_ranges.get(preset, ranges)
	var far := far_end if far_end > 0.0 else r.z
	var begin := 0.0
	for i in used.size():
		var level: String = used[i]
		var end := far
		if i < used.size() - 1:
			end = r.x if level == "near" else r.y
		var node: Node3D = _levels.get(level)
		if node == null and end > begin and is_inside_tree():
			# A preset that shows a level that the model did not load (Q24).
			if _add_level(level):
				node = _levels.get(level)
		if node == null:
			begin = maxf(begin, end) if end > begin else begin
			continue
		# An end of 0 is no end in Godot: a level with no range does not show.
		node.visible = end > begin
		if not node.visible:
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


## Plays an animation of the model (a routine of a person) in a loop, on
## each level, from a part of its length (0 to 1): each person of a group
## starts at its own time.
func play(animation: String, start := 0.0) -> bool:
	var found := false
	for player in animation_players():
		if not player.has_animation(animation):
			continue
		var clip := player.get_animation(animation)
		clip.loop_mode = Animation.LOOP_LINEAR
		player.play(animation)
		player.seek(clip.length * fposmod(start, 1.0), true)
		found = true
	if not found:
		push_error("WorldModel: the model \"%s\" has no animation \"%s\"." % [id, animation])
	return found


## The animation players of the levels.
func animation_players() -> Array[AnimationPlayer]:
	var result: Array[AnimationPlayer] = []
	for level_name: String in _levels:
		for node in (_levels[level_name] as Node).find_children("*", "AnimationPlayer", true, false):
			result.append(node as AnimationPlayer)
	return result


## The time of the animation now, in seconds (the first level), or -1.
func animation_time() -> float:
	for player in animation_players():
		if player.is_playing():
			return player.current_animation_position
	return -1.0


## Stops or starts the animations: a hidden group costs no time.
func set_animation_active(on: bool) -> void:
	for player in animation_players():
		player.active = on


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
