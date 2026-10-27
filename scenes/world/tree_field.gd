class_name TreeField
extends Node3D
## The trees of the world in their three forms (plan 0020, D3): the near form
## (real leaves), the middle form (leaf cards), and the far form (impostors).
##
## The trees are in cells of CELL meters. When the view moves MOVE_STEP meters,
## the field puts the trees near the view in one MultiMesh for each type,
## variant, and form. The shaders fade one form into the next by the distance
## of each tree (R6), so a tree can be in two lists near the end of a form.
##
## A source is a group of trees that comes and goes together: STATIC for the
## street and park trees, and a chunk key for the hill trees. The static trees
## have their far form in fixed tiles of FAR_TILE meters. The far form of the
## other trees is in the lists near the view.

const CELL := 32.0
const FAR_TILE := 512.0
const MOVE_STEP := 4.0
## The source of the street and park trees.
const STATIC := Vector2i(-1000000, -1000000)

## The number of trees of each type.
var counts: Dictionary = {}
## The trees in the lists of each form after the last update, and the number of updates.
var shown := {"near": 0, "mid": 0, "mid_flat": 0, "far": 0}
var updates := 0
var library: TreeLibrary
var _cells: Dictionary = {}  # Vector2i -> {source -> {mesh_id -> [PackedFloat32Array, PackedVector3Array]}}
var _cell_heights: Dictionary = {}  # Vector2i -> Vector2(lowest, highest) tree base
var _source_cells: Dictionary = {}  # source -> Array of Vector2i
var _instances: Dictionary = {}  # "form:mesh_id" -> MultiMeshInstance3D
var _far_tiles: Dictionary = {}  # tile and type index -> Array of PackedFloat32Array (16 floats each)
var _view := Vector3(INF, INF, INF)
var _ranges := Vector3.ZERO
var _dirty := true


func setup(tree_library: TreeLibrary) -> void:
	library = tree_library


## mesh_id: the type index and the variant in one number.
static func mesh_id(type_index: int, variant: int) -> int:
	return type_index * 8 + variant


## The variant of a tree at a position: the same place always has the same tree.
static func variant_at(p: Vector3, variant_count: int) -> int:
	return posmod(hash(Vector2i(roundi(p.x * 4.0), roundi(p.z * 4.0))), variant_count)


## Adds trees of one type to a source. Each transform has the base of the tree
## as its origin, in world space. The variant comes from the position, so the
## same place always has the same tree, or from variants (the gallery of PT-52).
func add_trees(source: Vector2i, type: String, transforms: Array[Transform3D], far_tiles := false,
		variants: Array[int] = []) -> void:
	var index := library.index_of(type)
	if index < 0 or not library.has_type(type):
		push_warning("TreeField: no files for the tree type %s." % type)
		return
	var variant_count := library.variants(type)
	var far := far_tiles and library.has_far(type)
	# First the trees of each cell and mesh. A packed array in a container is a
	# copy when it changes, so the arrays grow in local variables.
	var groups := {}  # Vector2i -> {mesh_id -> Array of Transform3D}
	for n in transforms.size():
		var t := transforms[n]
		var p := t.origin
		var variant := variant_at(p, variant_count)
		if n < variants.size():
			variant = variants[n] % variant_count
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not groups.has(key):
			groups[key] = {}
		var id := mesh_id(index, variant)
		if not groups[key].has(id):
			groups[key][id] = []
		groups[key][id].append(t)
		if far:
			_add_far(index, variant, t)
	var cells: Array = _source_cells.get(source, [])
	for key: Vector2i in groups:
		if not _cells.has(key):
			_cells[key] = {}
		var by_source: Dictionary = _cells[key]
		if not by_source.has(source):
			by_source[source] = {}
			cells.append(key)
		var by_mesh: Dictionary = by_source[source]
		for id: int in groups[key]:
			var old: Array = by_mesh.get(id, [PackedFloat32Array(), PackedVector3Array()])
			var floats: PackedFloat32Array = old[0]
			var points: PackedVector3Array = old[1]
			by_mesh.erase(id)
			for t: Transform3D in groups[key][id]:
				floats.append_array(_transform_floats(t))
				points.append(t.origin)
				var heights: Vector2 = _cell_heights.get(key, Vector2(t.origin.y, t.origin.y))
				_cell_heights[key] = Vector2(minf(heights.x, t.origin.y), maxf(heights.y, t.origin.y))
			by_mesh[id] = [floats, points]
	_source_cells[source] = cells
	counts[type] = int(counts.get(type, 0)) + transforms.size()
	_dirty = true


## Removes all trees of a source.
func remove_source(source: Vector2i) -> void:
	if not _source_cells.has(source):
		return
	for key: Vector2i in _source_cells[source]:
		var by_source: Dictionary = _cells.get(key, {})
		var by_mesh: Dictionary = by_source.get(source, {})
		for id: int in by_mesh:
			var type := library.names[id / 8]
			counts[type] = int(counts.get(type, 0)) - (by_mesh[id][1] as PackedVector3Array).size()
		by_source.erase(source)
		if by_source.is_empty():
			_cells.erase(key)
			_cell_heights.erase(key)
	_source_cells.erase(source)
	_dirty = true


## Makes the MultiMeshes of the far tiles. Call it after the static trees are in.
func commit_far_tiles() -> void:
	for key: int in _far_tiles:
		var index := posmod(key, 1000)
		var type := library.names[index]
		var buffer := _joined(_far_tiles[key])
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = library.far_mesh(type)
		multimesh.instance_count = buffer.size() / 16
		multimesh.buffer = buffer
		var instance := MultiMeshInstance3D.new()
		instance.name = "Far_%s_%d" % [type, key / 1000]
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = TreeLibrary.RANGES.ultra.z * library.range_scale(type) + FAR_TILE
		add_child(instance)
	_far_tiles.clear()


func _add_far(index: int, variant: int, t: Transform3D) -> void:
	var tile := Vector2i(floori(t.origin.x / FAR_TILE), floori(t.origin.z / FAR_TILE))
	# One number for the tile and the type: the tile in a small range of numbers.
	var key := ((tile.x + 500) * 1000 + (tile.y + 500)) * 1000 + index
	if not _far_tiles.has(key):
		_far_tiles[key] = []
	_far_tiles[key].append(_transform_floats(t) + _far_custom(index, variant))


func _far_custom(index: int, variant: int) -> PackedFloat32Array:
	var info := library.variant_info(library.names[index], variant)
	return PackedFloat32Array([float(variant), float(info.impostor_size), 0.0, 0.0])


## The 12 floats of a transform in the order of a MultiMesh buffer.
static func _transform_floats(t: Transform3D) -> PackedFloat32Array:
	var b := t.basis
	return PackedFloat32Array([b.x.x, b.y.x, b.z.x, t.origin.x, b.x.y, b.y.y, b.z.y, t.origin.y,
			b.x.z, b.y.z, b.z.z, t.origin.z])


func _process(_delta: float) -> void:
	if library == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var view := camera.global_position
	RenderingServer.global_shader_parameter_set("tree_view_position", view)
	if TreeLibrary.ranges != _ranges:
		_ranges = TreeLibrary.ranges
		_dirty = true
	if _dirty or view.distance_to(_view) > MOVE_STEP:
		refresh(view)


## Puts the trees near the view point in the lists of their forms.
func refresh(view: Vector3) -> void:
	_view = view
	_dirty = false
	updates += 1
	# "mid_flat": the middle form farther than the shadow distance, with no shadow (R7).
	var lists := {"near": {}, "mid": {}, "mid_flat": {}, "far": {}}
	var widest := 1.0
	for type: String in library.names:
		widest = maxf(widest, library.range_scale(type))
	var reach := _ranges.y * widest + CELL
	var lo := Vector2i(floori((view.x - reach) / CELL), floori((view.z - reach) / CELL))
	var hi := Vector2i(floori((view.x + reach) / CELL), floori((view.z + reach) / CELL))
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var key := Vector2i(cx, cy)
			if _cells.has(key):
				_sort_cell(key, view, lists, false)
	# The far form of the trees without far tiles (the hill trees), outside the cells above.
	for source: Vector2i in _source_cells:
		if source == STATIC:
			continue
		for key: Vector2i in _source_cells[source]:
			if key.x >= lo.x and key.x <= hi.x and key.y >= lo.y and key.y <= hi.y:
				continue
			_sort_cell(key, view, lists, true, source)
	_apply(lists)


## Sorts the trees of a cell into the lists. far_only: only the far form, and
## only for the source.
func _sort_cell(key: Vector2i, view: Vector3, lists: Dictionary, far_only: bool, only_source := Vector2i.MAX) -> void:
	var heights: Vector2 = _cell_heights[key]
	var box_min := Vector3(key.x * CELL, heights.x, key.y * CELL)
	var box_max := Vector3((key.x + 1) * CELL, heights.y + 1.0, (key.y + 1) * CELL)
	var nearest := view.clamp(box_min, box_max)
	var d_min := view.distance_to(nearest)
	var farthest := Vector3(box_max.x if view.x < (box_min.x + box_max.x) / 2.0 else box_min.x,
			box_max.y if view.y < (box_min.y + box_max.y) / 2.0 else box_min.y,
			box_max.z if view.z < (box_min.z + box_max.z) / 2.0 else box_min.z)
	var d_max := view.distance_to(farthest)
	var by_source: Dictionary = _cells[key]
	for source: Vector2i in by_source:
		if only_source != Vector2i.MAX and source != only_source:
			continue
		var static_far: bool = source == STATIC
		var by_mesh: Dictionary = by_source[source]
		for id: int in by_mesh:
			var type := library.names[id / 8]
			var scale := library.range_scale(type)
			var near_end := _ranges.x * scale
			var mid_end := _ranges.y * scale
			var far_end := _ranges.z * scale
			var near_start := near_end - _fade(near_end)
			var mid_fade := mid_end - _fade(mid_end)
			var far := not static_far and library.has_far(type)
			if far_only and not far:
				continue
			if d_min > (far_end if far else mid_end):
				continue
			var data: Array = by_mesh[id]
			var floats: PackedFloat32Array = data[0]
			var points: PackedVector3Array = data[1]
			var shadow := TreeLibrary.shadow_distance
			if not far_only:
				if d_max < near_start:
					_append(lists.near, id, floats)
					continue
				if d_min > near_end and d_max < mid_fade and (d_max < shadow or d_min > shadow):
					_append(lists.mid if d_max < shadow else lists.mid_flat, id, floats)
					continue
			if far_only and far and d_min > mid_end and d_max < far_end:
				_append_far(lists.far, id, floats)
				continue
			# Near the end of a form: tree by tree.
			for i in points.size():
				var d := view.distance_to(points[i])
				if not far_only:
					if d < near_end:
						_append(lists.near, id, floats.slice(i * 12, i * 12 + 12))
					if d > near_start and d < mid_end:
						_append(lists.mid if d < shadow else lists.mid_flat, id, floats.slice(i * 12, i * 12 + 12))
				if far and d > mid_fade and d < far_end:
					_append_far(lists.far, id, floats.slice(i * 12, i * 12 + 12))


static func _fade(range: float) -> float:
	# The same width as tree_fade_width() in tree_common.gdshaderinc.
	return clampf(range * 0.2, 3.0, 60.0)


## The lists hold pieces of buffers; _apply() joins them.
static func _append(list: Dictionary, id: int, floats: PackedFloat32Array) -> void:
	if not list.has(id):
		list[id] = []
	list[id].append(floats)


func _append_far(list: Dictionary, id: int, floats: PackedFloat32Array) -> void:
	if not list.has(id):
		list[id] = []
	var custom := _far_custom(id / 8, id % 8)
	var piece := PackedFloat32Array()
	for i in floats.size() / 12:
		piece.append_array(floats.slice(i * 12, i * 12 + 12))
		piece.append_array(custom)
	list[id].append(piece)


static func _joined(pieces: Array) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for piece: PackedFloat32Array in pieces:
		result.append_array(piece)
	return result


func _apply(lists: Dictionary) -> void:
	var seen := {}
	for form: String in lists:
		var total := 0
		var stride := 16 if form == "far" else 12
		var list: Dictionary = lists[form]
		for id: int in list:
			var key := "%s:%d" % [form, id]
			seen[key] = true
			var buffer := _joined(list[id])
			var instance := _instance(key, form, id)
			instance.multimesh.instance_count = buffer.size() / stride
			instance.multimesh.buffer = buffer
			instance.visible = true
			if form == "near":
				# The shadow of a near tree comes from its middle form: the same
				# shape, with far fewer triangles.
				var caster := _instance("shadow:%d" % id, "shadow", id)
				seen["shadow:%d" % id] = true
				caster.multimesh.instance_count = buffer.size() / stride
				caster.multimesh.buffer = buffer
				caster.visible = true
			total += buffer.size() / stride
		shown[form] = total
	for key: String in _instances:
		if not seen.has(key):
			var instance: MultiMeshInstance3D = _instances[key]
			instance.visible = false
			instance.multimesh.instance_count = 0


func _instance(key: String, form: String, id: int) -> MultiMeshInstance3D:
	if _instances.has(key):
		return _instances[key]
	var type := library.names[id / 8]
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	if form == "far":
		multimesh.use_custom_data = true
		multimesh.mesh = library.far_mesh(type)
	else:
		multimesh.mesh = library.mesh(type, id % 8, form if form in ["near", "shadow"] else "mid")
	var instance := MultiMeshInstance3D.new()
	instance.name = "%s_%s_%d" % [form.to_pascal_case(), type, id % 8 + 1]
	instance.multimesh = multimesh
	# The far form, and the middle form farther than the shadow distance, cast no shadow (R7).
	# The near form casts its shadow with the "shadow" instance (its middle form).
	match form:
		"mid":
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		"shadow":
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_instances[key] = instance
	return instance


## The trees of a type within a distance of a point (for the play tests):
## an Array of [position, variant].
func trees_near(type: String, point: Vector3, radius: float) -> Array:
	var result := []
	var index := library.index_of(type)
	var lo := Vector2i(floori((point.x - radius) / CELL), floori((point.z - radius) / CELL))
	var hi := Vector2i(floori((point.x + radius) / CELL), floori((point.z + radius) / CELL))
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			for by_mesh: Dictionary in (_cells.get(Vector2i(cx, cy), {}) as Dictionary).values():
				for id: int in by_mesh:
					if id / 8 != index:
						continue
					for p: Vector3 in by_mesh[id][1]:
						if Vector2(p.x - point.x, p.z - point.z).length() <= radius:
							result.append([p, id % 8])
	return result


## All tree positions within a distance of a point, of any type: an Array of [position, type].
func all_trees_near(point: Vector3, radius: float) -> Array:
	var result := []
	for type: String in library.names:
		for entry: Array in trees_near(type, point, radius):
			result.append([entry[0], type])
	return result
