class_name Roadworks
extends Node3D
## Roadworks on a part of a road (plan 0005, R11a), from
## data/geo/build/roadworks.json: gravel and fresh concrete on the new part of
## the road, barriers, drain pipes, a small excavator, and a site sign. Workers
## are there in the work hours, but not in the lunch break. Then the machine
## sound plays.

const BARRIER_SPACING := 2.5
const PIPE_SPACING := 18.0
const CONCRETE_LENGTH := 30.0
const WORKERS := 4

var record: Dictionary = {}
var workers: Node3D
var machine: AudioStreamPlayer3D
var excavator_position := Vector3.ZERO
var sign_position := Vector3.ZERO
## The direction from the sign to the people who read it (the road side).
var sign_facing := Vector3.FORWARD
## The points of the road line: x, height, z.
var _line: PackedVector3Array = PackedVector3Array()
var _hours: Array[int] = []


## Builds the first roadworks of the file. Returns false when there is none.
func setup(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or (parsed.get("roadworks", []) as Array).is_empty():
		return false
	record = parsed.roadworks[0]
	for p: Array in record.points:
		_line.append(Vector3(p[0], p[1], p[2]))
	var hours: Dictionary = record.get("work_hours", {})
	for key: String in ["start", "lunch", "after_lunch", "end"]:
		var parts := str(hours.get(key, "00:00")).split(":")
		_hours.append(int(parts[0]) * 60 + int(parts[1]))
	_build()
	return true


## True when the workers work at the clock time (minutes after midnight).
func is_working(minutes: int) -> bool:
	if _hours.size() < 4:
		return false
	var m := posmod(minutes, 24 * 60)
	return (m >= _hours[0] and m < _hours[1]) or (m >= _hours[2] and m < _hours[3])


## Shows the workers and plays the machines in the work hours.
func update_time(minutes: int) -> void:
	var working := is_working(minutes)
	workers.visible = working
	if working and not machine.playing:
		machine.play()
	elif not working and machine.playing:
		machine.stop()


## The point at a distance along the line, and the unit direction there.
func _at(distance: float) -> Array:
	var done := 0.0
	for i in _line.size() - 1:
		var step := Vector2(_line[i + 1].x - _line[i].x, _line[i + 1].z - _line[i].z).length()
		if done + step >= distance or i == _line.size() - 2:
			var part := clampf((distance - done) / maxf(step, 0.001), 0.0, 1.0)
			var direction := (_line[i + 1] - _line[i])
			direction.y = 0.0
			return [_line[i].lerp(_line[i + 1], part), direction.normalized()]
		done += step
	return [_line[0], Vector3.FORWARD]


func _side(direction: Vector3) -> Vector3:
	return Vector3(-direction.z, 0.0, direction.x)


func _build() -> void:
	var length := float(record.length_m)
	var road_half := float(record.road_width_m) / 2.0
	var widen := float(record.widen_m)
	var batch := MeshBatch.new()
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = Layers.FLOOR
	body.collision_mask = 0
	add_child(body)
	# The new part of the road: gravel, with fresh concrete on every other part.
	var step := 2.0
	var distance := 0.0
	while distance < length:
		var a: Array = _at(distance)
		var b: Array = _at(minf(distance + step, length))
		var side_a := _side(a[1])
		var side_b := _side(b[1])
		var fresh := int(distance / CONCRETE_LENGTH) % 2 == 1
		var color := Color("#C9C5BA") if fresh else Color("#8A7F6E")
		var lift := Vector3(0, 0.06 if fresh else 0.04, 0)
		var pa: Vector3 = a[0]
		var pb: Vector3 = b[0]
		var quad: Array[Vector3] = [pa + side_a * road_half + lift, pb + side_b * road_half + lift,
				pb + side_b * (road_half + widen) + lift, pa + side_a * (road_half + widen) + lift]
		batch.quad("works", quad, color)
		distance += step
	# Barriers between the road and the work, white and orange.
	var count := int(length / BARRIER_SPACING)
	for i in count:
		var at: Array = _at(i * BARRIER_SPACING + 1.0)
		var basis := Basis.looking_at(at[1], Vector3.UP)
		var place: Vector3 = at[0] + _side(at[1]) * (road_half + 0.25)
		var color := Color("#E8742A") if i % 2 == 0 else Color("#F1EEE6")
		batch.box("works", Vector3(0.4, 0.8, 1.6), place + Vector3(0, 0.45, 0), color, basis)
	# Drain pipes on the far side of the work.
	for i in int(length / PIPE_SPACING):
		var at: Array = _at(i * PIPE_SPACING + 8.0)
		var basis := Basis.looking_at(at[1], Vector3.UP) * Basis(Vector3.RIGHT, PI / 2.0)
		var base: Vector3 = at[0] + _side(at[1]) * (road_half + widen + 0.9)
		# Two pipes side by side, and one pipe on them.
		for offset: Vector3 in [Vector3(0, 0.5, 0) - _side(at[1]) * 0.52, Vector3(0, 0.5, 0) + _side(at[1]) * 0.52,
				Vector3(0, 1.35, 0)]:
			batch.cylinder("works", 0.5, 1.2, base + offset, Color("#A8A49A"), 12, basis)
	# The excavator: at the corner of the homestay hẻm, or in the middle.
	var at_distance := float(record.corner.distance_m) if record.has("corner") else length / 2.0
	var at_excavator: Array = _at(clampf(at_distance - 6.0, 4.0, length - 4.0))
	var basis_excavator := Basis.looking_at(at_excavator[1], Vector3.UP)
	excavator_position = at_excavator[0] + _side(at_excavator[1]) * (road_half + widen / 2.0)
	_add_excavator(batch, body, excavator_position, basis_excavator)
	# The site sign at the bottom of the roadworks.
	var at_sign: Array = _at(3.0)
	sign_position = at_sign[0] + _side(at_sign[1]) * (road_half + widen + 1.5)
	sign_facing = -_side(at_sign[1])
	_add_sign(batch, sign_position, Basis.looking_at(-_side(at_sign[1]), Vector3.UP))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.85
	batch.commit(self, {"works": material}, "Roadworks")
	# The workers.
	workers = Node3D.new()
	workers.name = "Workers"
	add_child(workers)
	var worker_batch := MeshBatch.new()
	for i in WORKERS:
		var at: Array = _at(clampf(at_distance - 14.0 + i * 7.0, 2.0, length - 2.0))
		var place: Vector3 = at[0] + _side(at[1]) * (road_half + 0.8 + (i % 2) * 1.2)
		_add_worker(worker_batch, place, Basis(Vector3.UP, i * 1.7))
	worker_batch.commit(workers, {"works": material}, "Worker")
	machine = AudioStreamPlayer3D.new()
	machine.name = "Machine"
	machine.stream = Tones.machine()
	machine.max_distance = float(Content.sound("machine").get("range_m", 40.0))
	machine.unit_size = 6.0
	machine.volume_db = -6.0
	machine.position = excavator_position + Vector3(0, 1.5, 0)
	add_child(machine)


## A small excavator: tracks, the yellow body and cabin, and the arm with the bucket.
func _add_excavator(batch: MeshBatch, body: StaticBody3D, place: Vector3, basis: Basis) -> void:
	var at := func(local: Vector3) -> Vector3: return place + basis * local
	var yellow := Color("#E3B11F")
	for side in [-1.0, 1.0]:
		batch.box("works", Vector3(0.45, 0.55, 2.6), at.call(Vector3(side * 0.75, 0.3, 0)), Color("#2B2B2B"), basis)
	batch.box("works", Vector3(1.9, 0.7, 2.2), at.call(Vector3(0, 0.95, 0.2)), yellow, basis)
	batch.box("works", Vector3(0.9, 1.2, 1.0), at.call(Vector3(-0.45, 1.9, 0.0)), yellow, basis)
	batch.box("works", Vector3(0.8, 0.8, 0.05), at.call(Vector3(-0.45, 2.0, -0.52)), Color("#3A4A55"), basis)
	var boom := basis * Basis(Vector3.RIGHT, 0.7)
	batch.box("works", Vector3(0.3, 0.35, 2.4), at.call(Vector3(0.45, 1.9, -1.3)), yellow, boom)
	var arm := basis * Basis(Vector3.RIGHT, -0.5)
	batch.box("works", Vector3(0.25, 0.3, 1.6), at.call(Vector3(0.45, 1.7, -2.9)), yellow, arm)
	batch.box("works", Vector3(0.7, 0.5, 0.5), at.call(Vector3(0.45, 0.7, -3.3)), Color("#4A4A48"), basis)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.4, 2.8)
	shape.shape = box
	shape.transform = Transform3D(basis, place + Vector3(0, 1.2, 0))
	body.add_child(shape)


## The site sign on two posts, with the name of the work, the contractor (a
## fictional name), and the planned end.
func _add_sign(batch: MeshBatch, place: Vector3, basis: Basis) -> void:
	for side in [-1.0, 1.0]:
		batch.box("works", Vector3(0.1, 2.6, 0.1), place + basis * Vector3(side * 1.75, 1.3, 0.05), Color("#5A5A58"), basis)
	batch.box("works", Vector3(3.8, 1.7, 0.06), place + basis * Vector3(0, 2.0, 0), Color("#1F5FA8"), basis)
	var label := Label3D.new()
	label.name = "SiteSign"
	label.text = "%s\n%s\nDự kiến hoàn thành: %s" % [record.sign, record.contractor, record.planned_end]
	label.font = load("res://assets/fonts/BeVietnamPro-SemiBold.ttf")
	label.font_size = 40
	label.pixel_size = 0.004
	label.outline_size = 0
	label.modulate = Color("#FFFFFF")
	label.width = 820.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.transform = Transform3D(basis * Basis(Vector3.UP, PI), place + basis * Vector3(0, 2.0, -0.04))
	label.set_meta("test_id", "roadworks.sign")
	add_child(label)


## A worker: an orange vest, dark trousers, a face, and a yellow hard hat.
func _add_worker(batch: MeshBatch, place: Vector3, basis: Basis) -> void:
	var at := func(local: Vector3) -> Vector3: return place + basis * local
	batch.box("works", Vector3(0.36, 0.85, 0.24), at.call(Vector3(0, 0.45, 0)), Color("#2F3540"), basis)
	batch.box("works", Vector3(0.44, 0.6, 0.28), at.call(Vector3(0, 1.15, 0)), Color("#F07A1E"), basis)
	batch.box("works", Vector3(0.22, 0.24, 0.22), at.call(Vector3(0, 1.6, 0)), Color("#B7835E"), basis)
	batch.cylinder("works", 0.17, 0.12, at.call(Vector3(0, 1.76, 0)), Color("#F2C522"), 10, basis)
