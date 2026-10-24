class_name RoadBuilder
extends RefCounted
## Makes the road meshes of one ground chunk (plan 0004, R11).
##
## Main roads are asphalt with lane lines. A hẻm is concrete. A road with the
## sidewalk flag has a curb of 0.15 m and a sidewalk at each side. The
## functions use no nodes, so a worker thread can run them.

## The road surface is this much above the ground, so that it does not flicker.
const LIFT := 0.04
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


## Returns {"asphalt", "concrete", "dirt", "sidewalk", "lines"}: each one is
## mesh arrays or null. "collision" is a PackedVector3Array of triangles for
## the sidewalks and the curbs. The positions are from "origin".
static func build(data: GeoData, key: Vector2i, origin: Vector3) -> Dictionary:
	var parts := {"asphalt": _Strip.new(), "concrete": _Strip.new(), "dirt": _Strip.new(),
			"sidewalk": _Strip.new(), "lines": _Strip.new()}
	var collision := PackedVector3Array()
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
		var surface := "concrete" if road.hem else ("dirt" if kind in DIRT_TYPES else
				("asphalt" if kind in ASPHALT_TYPES else "concrete"))
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
			for side: float in sides:
				var a := inner * side
				var b := half * side
				# The sidewalk top and the curb face toward the road.
				parts.sidewalk.ribbon(line, minf(a, b), maxf(a, b), LIFT + CURB, LIFT + CURB)
				parts.sidewalk.wall(line, a, LIFT, LIFT + CURB, side > 0.0)
				collision.append_array(parts.sidewalk.last_triangles())
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
			var v0 := distance / 4.0
			var v1 := (distance + length) / 4.0
			_quad(a0, a1, b0, b1, Vector2(0, v0), Vector2(1, v0), Vector2(0, v1), Vector2(1, v1))
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
