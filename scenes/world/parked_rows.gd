class_name ParkedRows
extends Node3D
## The rows of parked scooters of the Vũng Tàu world (plan 0023, R9a, R8):
## data/world/parked_rows.json. Each row is a WorldRow: the near and the mid
## level of the scooter of World, then its impostor, by the ranges of the
## quality preset.

const PATH := "res://data/world/parked_rows.json"

## The rows by id: {"node": WorldRow, "from", "to", "points": the ground point of each scooter}.
var rows: Dictionary = {}


func setup(world: VungTau, path := PATH) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("ParkedRows: cannot read %s." % path)
		return false
	for entry: Dictionary in parsed.get("rows", []):
		_add_row(world, entry)
	return true


func _add_row(world: VungTau, entry: Dictionary) -> void:
	var road := _road(world, str(entry.road), str(entry.near))
	if road.is_empty():
		push_error("ParkedRows: the row \"%s\" has no road \"%s\" near \"%s\"." % [entry.id, entry.road, entry.near])
		return
	var line: Array[Vector3] = road.line
	var row := WorldRow.new()
	row.name = "Parked_" + str(entry.id)
	add_child(row)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry.get("seed", 1))
	var sides: Array = entry.get("sides", [1])
	var per_side := ceili(float(entry.count) / sides.size())
	var half_width := float(road.width) / 2.0
	var points: Array[Vector3] = []
	var placed := 0
	for side_value: Variant in sides:
		var side := float(side_value)
		# From the nearest point of the road: half of the row to each way.
		var angles: Array[float] = []
		var length := 0.0
		for i in mini(per_side, int(entry.count) - placed):
			var angle := Parked.pick_angle(rng)
			angles.append(angle)
			length += _along(angle) + float(entry.get("gap", 0.3))
		var at := float(road.at) - length / 2.0
		for angle: float in angles:
			var step := _along(angle) + float(entry.get("gap", 0.3))
			var s := at + step / 2.0
			at += step
			var frame := _frame(line, s)
			var center: Vector3 = frame.point
			var along: Vector3 = frame.along
			var right := along.cross(Vector3.UP).normalized() * side
			# The line of the shop fronts, and the direction to the road.
			var wall := center + right * (half_width + float(entry.get("sidewalk", 3.0)))
			wall.y = world.ground_height(wall.x, wall.z)
			var forward := along if side > 0.0 else -along
			var xform := Parked.transform(wall, forward, -right, angle)
			xform.origin.y = world.ground_height(xform.origin.x, xform.origin.z)
			row.add(Parked.MODEL, xform, Parked.pick_color(rng), Parked.pose(rng))
			points.append(xform.origin)
			placed += 1
	row.build()
	rows[entry.id] = {"node": row, "from": float(entry.get("from", 0)), "to": float(entry.get("to", 24)), "points": points}


## The length of a parked scooter along the curb, for an angle.
static func _along(angle_deg: float) -> float:
	var a := deg_to_rad(angle_deg)
	return 1.86 * cos(a) + 0.68 * sin(a)


## The road with this name nearest to a landmark: its points, its width, and
## the distance along it of the nearest point.
static func _road(world: VungTau, road_name: String, landmark: String) -> Dictionary:
	var mark := world.data.landmark(landmark)
	if mark.is_empty():
		return {}
	var target := Vector2(mark.position[0], mark.position[1])
	var best := {}
	var best_d := INF
	for road: Dictionary in world.data.roads:
		if road.name != road_name:
			continue
		var line: Array[Vector3] = []
		for p: Array in road.points:
			line.append(Vector3(p[0], p[1], p[2]))
		var s := 0.0
		for i in line.size() - 1:
			var a := Vector2(line[i].x, line[i].z)
			var b := Vector2(line[i + 1].x, line[i + 1].z)
			var q := Geometry2D.get_closest_point_to_segment(target, a, b)
			var d := q.distance_to(target)
			if d < best_d:
				best_d = d
				best = {"line": line, "width": float(road.width), "at": s + a.distance_to(q)}
			s += a.distance_to(b)
	return best


## The point and the direction at a distance along a line (clamped to the ends).
static func _frame(line: Array[Vector3], s: float) -> Dictionary:
	var at := maxf(s, 0.0)
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var seg := Vector2(b.x - a.x, b.z - a.z).length()
		if at <= seg or i == line.size() - 2:
			var t := clampf(at / maxf(seg, 0.001), 0.0, 1.0)
			var along := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
			return {"point": a.lerp(b, t), "along": along}
		at -= seg
	return {"point": line[0], "along": Vector3.RIGHT}


func update_time(minutes: int) -> void:
	var hour := minutes / 60.0
	for row_id: String in rows:
		var entry: Dictionary = rows[row_id]
		(entry.node as Node3D).visible = hour >= float(entry.from) and hour < float(entry.to)
