class_name TownField
extends Node3D
## Plan 0009, phase 2 (R6, R10): the far level of the whole town. Each building
## of buildings_2019 is a box of its outline and its height, with a roof (a flat
## terrace, a metal roof, or a hip roof of tiles), from data/geo/build/town/
## (tools/geo/build.py, geodata/town.py). The boxes of a chunk of 256 m are one
## mesh with vertex colors, made in a worker thread when the view comes in the
## range of the preset (RANGES). A wall that a neighbor hides (a row of houses)
## draws only its part over the neighbor.
##
## A building that another part of the world already draws is left out: each
## building in the area of the showcase (plan 0026: its models, its stand-ins,
## and its details), a model or a stand-in of the showcase out of its area, and
## a known place (plan 0008, R3). So a chunk that touches the area of the
## showcase waits for it.

const FOLDER := "town"
## The distance (m) to which the boxes of a chunk show, for each preset (R10).
const RANGES := {"low": 1500.0, "medium": 3500.0, "high": 5000.0, "ultra": 6000.0}
## A chunk is made when the view is this much nearer than its range.
const MARGIN := 200.0
const MAX_TASKS := 2
## Each chunk has PARTS x PARTS meshes.
const PARTS := 1
const MAX_APPLY_PER_FRAME := 2
const ROOF_TERRACE := 0
const ROOF_METAL := 1
const ROOF_TILES := 2

static var range_end: float = RANGES.high

var world: VungTau
## The count of buildings in each chunk (Vector2i -> int), from the index.
var counts: Dictionary = {}
## The numbers of the boxes now: the buildings made, left out, and the triangles.
var made := 0
var left_out := 0
var triangles := 0
var _chunks: Dictionary = {}  # Vector2i -> {"state": 0 none, 1 busy, 2 done, "node": MeshInstance3D}
var _done: Array = []
var _mutex := Mutex.new()
var _tasks := 0
var _material: StandardMaterial3D
## The parts that draw their own buildings: [outline, its box, its middle].
var _keep_out: Array = []
var _keep_out_ready := false
var _showcase_area := PackedVector2Array()
var _focus := Vector3.ZERO
var _applied_range := -1.0


## Sets the range of the boxes for a quality preset (Quality.apply()).
static func set_preset(preset: String) -> void:
	range_end = float(RANGES.get(preset, RANGES.low))


func setup(w: VungTau) -> bool:
	world = w
	if w.showcase:
		_showcase_area = w.showcase.outline
	var path := w.data.root.path_join(FOLDER).path_join("index.json")
	if not FileAccess.file_exists(path):
		return false
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not index is Dictionary:
		push_error("TownField: %s cannot be read." % path)
		return false
	for entry: Array in index.get("chunks", []):
		counts[Vector2i(int(entry[0]), int(entry[1]))] = int(entry[2])
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.92
	return true


## The chunks of the boxes in the range that are not made yet (is_settled()).
func pending() -> int:
	var n := 0
	for key: Vector2i in counts:
		if _distance_to(key) < range_end and _state(key) != 2 and _can_make(key):
			n += 1
	return n


## Makes the boxes of each chunk in the radius at once (prepare_at()).
func prepare_at(point: Vector3, radius: float) -> void:
	_focus = point
	_read_keep_out()
	for key: Vector2i in counts:
		if _distance_to(key) < minf(radius, range_end) and _state(key) == 0 and _can_make(key):
			_chunks[key] = {"state": 1}
			_show(_build(key))


func _process(_delta: float) -> void:
	if world == null or counts.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	if camera:
		_focus = camera.global_position
	if not _keep_out_ready and (world.showcase == null or world.showcase.is_built()):
		_read_keep_out()
	if _applied_range != range_end:
		apply_range()
	_start_tasks()
	_apply_done()


func _state(key: Vector2i) -> int:
	return int(_chunks.get(key, {}).get("state", 0))


func _distance_to(key: Vector2i) -> float:
	var size := world.data.chunk_size
	var dx := maxf(maxf(key.x * size - _focus.x, _focus.x - (key.x + 1) * size), 0.0)
	var dz := maxf(maxf(key.y * size - _focus.z, _focus.z - (key.y + 1) * size), 0.0)
	return Vector2(dx, dz).length()


## A chunk that touches the area of the showcase waits until the showcase is
## built: its models and stand-ins leave out the buildings of the town there.
func _can_make(key: Vector2i) -> bool:
	if world.showcase == null or world.showcase.is_built():
		return true
	var size := world.data.chunk_size
	var rect := Rect2(key.x * size, key.y * size, size, size)
	for p: Vector2 in world.showcase.outline:
		if rect.grow(64.0).has_point(p):
			return false
	return true


func _start_tasks() -> void:
	while _tasks < MAX_TASKS:
		var best := Vector2i.ZERO
		var best_distance := INF
		for key: Vector2i in counts:
			if _state(key) != 0:
				continue
			var d := _distance_to(key)
			if d < range_end + MARGIN and d < best_distance and _can_make(key):
				best_distance = d
				best = key
		if best_distance == INF:
			return
		_chunks[best] = {"state": 1}
		_tasks += 1
		WorkerThreadPool.add_task(_task.bind(best), false, "town chunk")


func _task(key: Vector2i) -> void:
	var result := _build(key)
	_mutex.lock()
	_done.append(result)
	_mutex.unlock()


func _apply_done() -> void:
	_mutex.lock()
	var ready := _done.slice(0, MAX_APPLY_PER_FRAME)
	_done = _done.slice(MAX_APPLY_PER_FRAME)
	_mutex.unlock()
	for result: Dictionary in ready:
		_tasks -= 1
		_show(result)


## The middle of the top of each box that is made (PT-68).
func middles() -> PackedVector3Array:
	var out := PackedVector3Array()
	for key: Vector2i in _chunks:
		out.append_array(_chunks[key].get("middles", PackedVector3Array()))
	return out


func _show(result: Dictionary) -> void:
	var key: Vector2i = result.key
	_chunks[key] = {"state": 2, "middles": result.middles, "nodes": []}
	made += int(result.made)
	left_out += int(result.left_out)
	triangles += int(result.triangles)
	for part: Dictionary in result.parts:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part.arrays)
		mesh.surface_set_material(0, _material)
		var node := MeshInstance3D.new()
		node.name = "Town_%d_%d_%d" % [key.x, key.y, _chunks[key].nodes.size()]
		node.mesh = mesh
		node.position = part.origin
		node.visibility_range_end = range_end
		node.visibility_range_end_margin = MARGIN * 0.5
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		# A far level casts no shadow (R10).
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_chunks[key].nodes.append(node)
	_applied_range = range_end


## Sets the range of the chunks that are made (after a change of preset).
func apply_range() -> void:
	_applied_range = range_end
	for key: Vector2i in _chunks:
		for node: MeshInstance3D in _chunks[key].get("nodes", []):
			node.visibility_range_end = range_end


## The outlines and circles of the parts that draw their own buildings.
func _read_keep_out() -> void:
	var rings: Array[PackedVector2Array] = []
	if world.places:
		for id: String in world.places.places:
			var entry: Dictionary = world.places.places[id]
			var record: Dictionary = entry.record
			var ring := PackedVector2Array()
			for p: Array in record.get("outline", []):
				ring.append(Vector2(p[0], p[1]))
			if ring.size() < 3 and record.has("position"):
				ring = _circle(Vector2(record.position[0], record.position[1]), float(entry.get("radius", 15.0)))
			if ring.size() >= 3:
				rings.append(ring)
	if world.showcase and world.showcase.is_built():
		for entry: Dictionary in world.showcase.models:
			rings.append(entry.footprint)
		for entry: Dictionary in world.showcase.stand_ins:
			rings.append(entry.outline)
	var kept := []
	for ring in rings:
		var box := Rect2(ring[0], Vector2.ZERO)
		var middle := Vector2.ZERO
		for p in ring:
			box = box.expand(p)
			middle += p / ring.size()
		kept.append([ring, box, middle])
	# One assignment: a worker thread reads the old list or the new one.
	_keep_out = kept
	_keep_out_ready = true


static func _circle(c: Vector2, r: float) -> PackedVector2Array:
	var ring := PackedVector2Array()
	for i in 12:
		ring.append(c + Vector2.from_angle(TAU * i / 12.0) * r)
	return ring


## True when a part of the world already draws the building of this outline:
## its middle is in a kept part, or a kept part has its middle in the outline.
func _kept(ring: PackedVector2Array, middle: Vector2) -> bool:
	# The area of the showcase draws its own buildings (plan 0026; its details
	# come later, report 0026, section 12.5): the town is round it.
	if _showcase_area.size() >= 3 and Geometry2D.is_point_in_polygon(middle, _showcase_area):
		return true
	var box := Rect2(ring[0], Vector2.ZERO)
	for p in ring:
		box = box.expand(p)
	for other: Array in _keep_out:
		if not (other[1] as Rect2).intersects(box, true):
			continue
		if Geometry2D.is_point_in_polygon(middle, other[0]) or Geometry2D.is_point_in_polygon(other[2], ring):
			return true
	return false


## Runs in a worker thread (or at once in prepare_at()): the mesh arrays of the
## boxes of a chunk.
func _build(key: Vector2i) -> Dictionary:
	var result := {"key": key, "parts": [], "made": 0, "left_out": 0, "triangles": 0, "middles": PackedVector3Array()}
	var path := world.data.root.path_join(FOLDER).path_join("%d_%d.json" % [key.x, key.y])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return result
	# Four parts of 128 m: the renderer culls a whole mesh, and a chunk of 256 m
	# that is only partly in the frame drew all its boxes (S5 of PT-73).
	var size := world.data.chunk_size
	var half := size / 2.0
	var parts := []
	for i in PARTS * PARTS:
		parts.append({"verts": PackedVector3Array(), "normals": PackedVector3Array(), "colors": PackedColorArray()})
	for b: Array in parsed.get("buildings", []):
		var flat: Array = b[6]
		var ring := PackedVector2Array()
		for i in range(0, flat.size(), 2):
			ring.append(Vector2(flat[i], flat[i + 1]))
		if ring.size() < 3:
			continue
		var middle := Vector2.ZERO
		for p in ring:
			middle += p / ring.size()
		if _kept(ring, middle):
			result.left_out += 1
			continue
		var px := clampi(int(floor((middle.x - key.x * size) / half)), 0, PARTS - 1)
		var pz := clampi(int(floor((middle.y - key.y * size) / half)), 0, PARTS - 1)
		var part: Dictionary = parts[pz * PARTS + px]
		var verts: PackedVector3Array = part.verts
		var normals: PackedVector3Array = part.normals
		var colors: PackedColorArray = part.colors
		var base := float(b[1])
		var top := float(b[2])
		var roof := int(b[3])
		var wall := Color(str(b[4]))
		var roof_color := Color(str(b[5]))
		var hidden: Array = b[7]
		_walls(ring, hidden, base, top, wall, verts, normals, colors)
		match roof:
			ROOF_TILES:
				_hip(ring, top, float(b[8]) if b.size() > 8 else 1.5, roof_color, verts, normals, colors)
			_:
				# A terrace and a metal roof are flat from far: only their colors differ.
				_cap(ring, top, roof_color, verts, normals, colors)
		# (The packed arrays are copies: put them back, AGENTS.md section 5.)
		part.verts = verts
		part.normals = normals
		part.colors = colors
		result.made += 1
		result.middles.append(Vector3(middle.x, top, middle.y))
	result.parts = []
	for i in parts.size():
		var part: Dictionary = parts[i]
		var verts: PackedVector3Array = part.verts
		if verts.is_empty():
			continue
		# The mesh is at the middle of its part: a visibility range is measured
		# from the origin of the node.
		var origin := Vector3(key.x * size + (i % PARTS + 0.5) * half, 0.0, key.y * size + (i / PARTS + 0.5) * half)
		for v in verts.size():
			verts[v] -= origin
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = part.normals
		arrays[Mesh.ARRAY_COLOR] = part.colors
		result.parts.append({"origin": origin, "arrays": arrays})
		result.triangles += verts.size() / 3
	return result


## The ring is counterclockwise on the map (x east, y north), so in the game
## (x, z = -north) it is clockwise seen from above. The front of a face has its
## corners clockwise seen from outside (AGENTS.md, section 5f).
static func _walls(ring: PackedVector2Array, hidden: Array, base: float, top: float, color: Color,
		verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray) -> void:
	var n := ring.size()
	for e in n:
		var a := ring[e]
		var c := ring[(e + 1) % n]
		var bottom := maxf(base, float(hidden[e]) if e < hidden.size() else base)
		if bottom >= top - 0.05:
			continue
		var edge := c - a
		if edge.length() < 0.05:
			continue
		var normal := Vector3(-edge.y, 0.0, edge.x).normalized()
		var a0 := Vector3(a.x, bottom, a.y)
		var a1 := Vector3(a.x, top, a.y)
		var c0 := Vector3(c.x, bottom, c.y)
		var c1 := Vector3(c.x, top, c.y)
		_tri(a0, a1, c1, normal, color, verts, normals, colors)
		_tri(a0, c1, c0, normal, color, verts, normals, colors)


static func _tri(p: Vector3, q: Vector3, r: Vector3, normal: Vector3, color: Color,
		verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray) -> void:
	# The order of the corners: clockwise seen from the side of the normal.
	if (q - p).cross(r - p).dot(normal) > 0.0:
		var t := q
		q = r
		r = t
	verts.append_array([p, q, r])
	normals.append_array([normal, normal, normal])
	colors.append_array([color, color, color])


static func _cap(ring: PackedVector2Array, y: float, color: Color,
		verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray) -> void:
	var indices := Geometry2D.triangulate_polygon(ring)
	for i in range(0, indices.size(), 3):
		var p := ring[indices[i]]
		var q := ring[indices[i + 1]]
		var r := ring[indices[i + 2]]
		_tri(Vector3(p.x, y, p.y), Vector3(q.x, y, q.y), Vector3(r.x, y, r.y), Vector3.UP, color, verts, normals, colors)


## A hip roof: a rectangle has a ridge along its long side; another outline a
## point over its middle.
static func _hip(ring: PackedVector2Array, top: float, rise: float, color: Color,
		verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray) -> void:
	var middle := Vector2.ZERO
	for p in ring:
		middle += p / ring.size()
	var ridge := [middle, middle]
	if ring.size() == 4:
		var long_axis := ring[1] - ring[0]
		var short := (ring[2] - ring[1]).length()
		if long_axis.length() < short:
			long_axis = ring[2] - ring[1]
			short = (ring[1] - ring[0]).length()
		var half := maxf(long_axis.length() * 0.5 - short * 0.5, 0.0)
		ridge = [middle - long_axis.normalized() * half, middle + long_axis.normalized() * half]
	var n := ring.size()
	for e in n:
		var a := ring[e]
		var c := ring[(e + 1) % n]
		# The nearer end of the ridge to this side.
		var mid := (a + c) * 0.5
		var r0: Vector2 = ridge[0]
		var r1: Vector2 = ridge[1]
		var pa := Vector3(a.x, top, a.y)
		var pc := Vector3(c.x, top, c.y)
		var q0 := Vector3(r0.x, top + rise, r0.y)
		var q1 := Vector3(r1.x, top + rise, r1.y)
		var normal := (pc - pa).cross(q0 - pa)
		if normal.y < 0.0:
			normal = -normal
		if r0.distance_to(r1) < 0.05 or absf((c - a).normalized().dot((r1 - r0).normalized())) < 0.7:
			var q := q0 if mid.distance_to(r0) <= mid.distance_to(r1) else q1
			normal = (pc - pa).cross(q - pa)
			if normal.y < 0.0:
				normal = -normal
			_tri(pa, pc, q, normal.normalized(), color, verts, normals, colors)
		else:
			# A long side: a trapezoid to the whole ridge.
			var near_a := q0 if a.distance_to(r0) <= a.distance_to(r1) else q1
			var near_c := q1 if near_a == q0 else q0
			normal = (pc - pa).cross(near_a - pa)
			if normal.y < 0.0:
				normal = -normal
			_tri(pa, pc, near_c, normal.normalized(), color, verts, normals, colors)
			_tri(pa, near_c, near_a, normal.normalized(), color, verts, normals, colors)
