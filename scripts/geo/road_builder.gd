class_name RoadBuilder
extends RefCounted
## Makes the road meshes of one ground chunk (plan 0005, R11).
##
## Main roads are asphalt with lane lines. A hẻm is concrete. A road with the
## sidewalk flag has a curb of 0.15 m and a sidewalk at each side. The
## functions use no nodes, so a worker thread can run them.

## The road surface is this much above the ground, so that it does not flicker.
const LIFT := 0.04
## The size of one copy of a texture of the road surfaces (m).
const TEXTURE_M := 4.0
const CURB := 0.15
const SIDEWALK_WIDTH := 2.0
## A road with a sidewalk must be at least this wide.
const MIN_SIDEWALK_ROAD := 7.0
const LINE_WIDTH := 0.12
const DASH := 3.0
const ASPHALT_TYPES := ["motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential",
		"living_street", "service"]
const LINE_TYPES := ["motorway", "trunk", "primary", "secondary", "tertiary"]
const DIRT_TYPES := ["path", "track"]
## A way with "paved" (the footways and the pedestrian ways in a park,
## tools/geo/build.py) has tiles, not concrete (report 0026, D-0026-17: the paths
## of the park of Bãi Trước looked like gravel).


## Returns {"asphalt", "concrete", "dirt", "paving", "sidewalk", "lines"}: each one is
## mesh arrays or null. "collision" is a PackedVector3Array of triangles for
## the sidewalks and the curbs. The positions are from "origin".
static func build(data: GeoData, key: Vector2i, origin: Vector3) -> Dictionary:
	var parts := {"asphalt": _Strip.new(), "concrete": _Strip.new(), "dirt": _Strip.new(), "paving": _Strip.new(),
			"sidewalk": _Strip.new(), "lines": _Strip.new()}
	var collision := PackedVector3Array()
	var others: Array = []
	for part: Array in data.road_parts.get(key, []):
		var road: Dictionary = data.roads[part[0]]
		var points: Array = road.points
		var line := PackedVector3Array()
		for i in range(part[1], part[2] + 1):
			var p: Array = points[i]
			line.append(Vector3(p[0], p[1], p[2]) - origin)
		if line.size() < 2:
			continue
		var kind: String = road.type
		var width: float = road.width
		var surface := "paving" if road.get("paved", false) else ("concrete" if road.hem else ("dirt" if kind in DIRT_TYPES else
				("asphalt" if kind in ASPHALT_TYPES else "concrete")))
		var half := width / 2.0
		var sidewalk := str(road.get("sidewalk", ""))
		if sidewalk != "" and width >= MIN_SIDEWALK_ROAD:
			var inner := half - SIDEWALK_WIDTH
			var sides: Array[float] = []
			if sidewalk in ["both", "left"]:
				sides.append(-1.0)
			if sidewalk in ["both", "right"]:
				sides.append(1.0)
			var left_edge := -inner if sides.has(-1.0) else -half
			var right_edge := inner if sides.has(1.0) else half
			parts[surface].ribbon(line, left_edge, right_edge, LIFT, LIFT)
			if others.is_empty():
				others = _carriageways(data, key)
			var dense := _dense(line, 0.5)
			for side: float in sides:
				var a := inner * side
				var b := half * side
				# Report 0026, D-0026-30 (audit 6): a sidewalk stops where it is
				# on the carriageway of another road (a junction); there the road
				# has its surface to its edge. A sidewalk that started at the node
				# of a junction went across the other roads.
				for run: Array in _sidewalk_runs(dense, [a + 0.1 * side, (a + b) / 2.0, b - 0.1 * side], origin, others, part[0]):
					var run_line: PackedVector3Array = run[1]
					if run[0]:
						# The sidewalk top and the curb face toward the road.
						parts.sidewalk.ribbon(run_line, minf(a, b), maxf(a, b), LIFT + CURB, LIFT + CURB)
						parts.sidewalk.wall(run_line, a, LIFT, LIFT + CURB, side > 0.0)
						collision.append_array(parts.sidewalk.last_triangles())
					else:
						parts[surface].ribbon(run_line, minf(a, b), maxf(a, b), LIFT, LIFT)
			if kind in LINE_TYPES:
				_lines(parts.lines, line, minf(-left_edge, right_edge), road.get("oneway", false))
		else:
			parts[surface].ribbon(line, -half, half, LIFT, LIFT)
			if kind in LINE_TYPES:
				_lines(parts.lines, line, half, road.get("oneway", false))
	var result := {"collision": collision}
	for name: String in parts:
		result[name] = parts[name].arrays()
	return result


## The carriageways (the road without its sidewalks) of the roads of the chunk
## and of the chunks round it: [road index, points (x, z), half width, box].
static func _carriageways(data: GeoData, key: Vector2i) -> Array:
	var result: Array = []
	var seen := {}
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for part: Array in data.road_parts.get(key + Vector2i(dx, dz), []):
				if seen.has(part[0]):
					continue
				seen[part[0]] = true
				var road: Dictionary = data.roads[part[0]]
				var half := float(road.width) / 2.0
				if str(road.get("sidewalk", "")) != "" and float(road.width) >= MIN_SIDEWALK_ROAD:
					half -= SIDEWALK_WIDTH
				var points := PackedVector2Array()
				var box := Rect2()
				for p: Array in road.points:
					var q := Vector2(float(p[0]), float(p[2]))
					box = Rect2(q, Vector2.ZERO) if points.is_empty() else box.expand(q)
					points.append(q)
				result.append([part[0], points, half, box.grow(half)])
	return result


## The runs of a line where a sidewalk (its points at the offsets across it)
## is free of the carriageways of the other roads: [[free, line], ...]. Two
## runs that meet share their point.
static func _sidewalk_runs(line: PackedVector3Array, offsets: Array, origin: Vector3, others: Array, road: int) -> Array:
	var sides := _Strip._sides(line)
	var runs: Array = []
	var current := PackedVector3Array()
	var current_free := true
	for i in line.size():
		var free := true
		for offset: float in offsets:
			var p := line[i] + sides[i] * offset + origin
			var q := Vector2(p.x, p.z)
			for other: Array in others:
				if other[0] == road or not (other[3] as Rect2).has_point(q):
					continue
				var points: PackedVector2Array = other[1]
				for j in points.size() - 1:
					if q.distance_to(Geometry2D.get_closest_point_to_segment(q, points[j], points[j + 1])) < float(other[2]):
						free = false
						break
				if not free:
					break
			if not free:
				break
		if i > 0 and free != current_free:
			# The segment where the state changes is not a sidewalk: it goes to
			# the run of the surface of the road.
			if current_free:
				if current.size() >= 2:
					runs.append([true, current])
				current = PackedVector3Array()
				current.append(line[i - 1])
			else:
				current.append(line[i])
				if current.size() >= 2:
					runs.append([false, current])
				current = PackedVector3Array()
		current_free = free
		current.append(line[i])
	if current.size() >= 2:
		runs.append([current_free, current])
	# The points of the dense line on a straight part go: each run keeps its
	# ends and its turns (more points made S5 27 000 triangles more, PT-73).
	for run: Array in runs:
		run[1] = _corners(run[1])
	return runs


static func _corners(line: PackedVector3Array) -> PackedVector3Array:
	if line.size() <= 2:
		return line
	var out := PackedVector3Array([line[0]])
	for i in range(1, line.size() - 1):
		var a := (line[i] - out[out.size() - 1]).normalized()
		var b := (line[i + 1] - line[i]).normalized()
		if a.dot(b) < 0.99999:
			out.append(line[i])
	out.append(line[line.size() - 1])
	return out


static func _dense(line: PackedVector3Array, step: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in line.size() - 1:
		var n := maxi(1, ceili(line[i].distance_to(line[i + 1]) / step))
		for k in n:
			out.append(line[i].lerp(line[i + 1], float(k) / n))
	out.append(line[line.size() - 1])
	return out


static func _lines(strip: _Strip, line: PackedVector3Array, half: float, oneway: bool) -> void:
	# The edge lines, and a dashed center line on a road with two directions.
	var edge := half - 0.3
	strip.ribbon(line, -edge - LINE_WIDTH / 2.0, -edge + LINE_WIDTH / 2.0, LIFT + 0.006, LIFT + 0.006)
	strip.ribbon(line, edge - LINE_WIDTH / 2.0, edge + LINE_WIDTH / 2.0, LIFT + 0.006, LIFT + 0.006)
	if not oneway:
		strip.ribbon(line, -LINE_WIDTH / 2.0, LINE_WIDTH / 2.0, LIFT + 0.006, LIFT + 0.006, DASH)


## A set of triangles for one material.
class _Strip:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var _last_start := 0

	## A flat strip along the line from the offset "left" to "right" (meters to
	## the right side of the line). With "dash", only every other part of
	## "dash" meters has the strip.
	func ribbon(line: PackedVector3Array, left: float, right: float, lift_left: float, lift_right: float,
			dash := 0.0) -> void:
		_last_start = vertices.size()
		var sides := _sides(line)
		var distance := 0.0
		for i in line.size() - 1:
			var length := line[i].distance_to(line[i + 1])
			if dash > 0.0 and int(floor((distance + length / 2.0) / dash)) % 2 == 1:
				distance += length
				continue
			var a0 := line[i] + sides[i] * left + Vector3(0, lift_left, 0)
			var a1 := line[i] + sides[i] * right + Vector3(0, lift_right, 0)
			var b0 := line[i + 1] + sides[i + 1] * left + Vector3(0, lift_left, 0)
			var b1 := line[i + 1] + sides[i + 1] * right + Vector3(0, lift_right, 0)
			# The texture in meters, both ways (report 0026, D-0026-18: from 0 to 1
			# across the whole road, the grain of the asphalt was ten times too
			# large, and the roads looked like gravel).
			var v0 := distance / TEXTURE_M
			var v1 := (distance + length) / TEXTURE_M
			var u0 := left / TEXTURE_M
			var u1 := right / TEXTURE_M
			_quad(a0, a1, b0, b1, Vector2(u0, v0), Vector2(u1, v0), Vector2(u0, v1), Vector2(u1, v1))
			distance += length

	## A vertical face along the line at the offset, from "low" to "high".
	func wall(line: PackedVector3Array, offset: float, low: float, high: float, face_left: bool) -> void:
		var sides := _sides(line)
		for i in line.size() - 1:
			var a := line[i] + sides[i] * offset
			var b := line[i + 1] + sides[i + 1] * offset
			var a_low := a + Vector3(0, low, 0)
			var a_high := a + Vector3(0, high, 0)
			var b_low := b + Vector3(0, low, 0)
			var b_high := b + Vector3(0, high, 0)
			# The face looks toward the middle of the road.
			var normal := -sides[i] if face_left else sides[i]
			if face_left:
				_quad(a_high, a_low, b_high, b_low, Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), normal)
			else:
				_quad(a_low, a_high, b_low, b_high, Vector2(0, 1), Vector2(0, 0), Vector2(1, 1), Vector2(1, 0), normal)

	func last_triangles() -> PackedVector3Array:
		return vertices.slice(_last_start)

	func _quad(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3, ua0: Vector2, ua1: Vector2, ub0: Vector2,
			ub1: Vector2, given_normal := Vector3.ZERO) -> void:
		# Two triangles, clockwise when seen from above (the front faces in Godot).
		var normal := given_normal
		if normal == Vector3.ZERO:
			normal = (b0 - a0).cross(a1 - a0).normalized()
			if normal.y < 0.0:
				normal = -normal
		for v in [[a0, ua0], [b0, ub0], [a1, ua1], [a1, ua1], [b0, ub0], [b1, ub1]]:
			vertices.append(v[0])
			uvs.append(v[1])
			normals.append(normal)

	func arrays() -> Variant:
		if vertices.is_empty():
			return null
		var result := []
		result.resize(Mesh.ARRAY_MAX)
		result[Mesh.ARRAY_VERTEX] = vertices
		result[Mesh.ARRAY_NORMAL] = normals
		result[Mesh.ARRAY_TEX_UV] = uvs
		return result

	## The unit vector to the right side of the line at each point (a miter).
	static func _sides(line: PackedVector3Array) -> PackedVector3Array:
		var result := PackedVector3Array()
		result.resize(line.size())
		for i in line.size():
			var before := line[maxi(i - 1, 0)]
			var after := line[mini(i + 1, line.size() - 1)]
			var forward := Vector3(after.x - before.x, 0, after.z - before.z).normalized()
			result[i] = Vector3(-forward.z, 0, forward.x)
		return result
