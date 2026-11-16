class_name ShowcasePeople
extends Node3D
## The people of the showcase of Bãi Trước (plan 0026, R10, D8): people of
## World who walk along the paths of the park and the walk of the sea, and
## people who sit on the borders of the raised lawns. data/showcase/people.json
## gives their models, their places, and the part of them that is there at
## each hour (all of them at 17:00, fewer at noon).

const PATH := "res://data/showcase/people.json"
const BODY_RADIUS := 0.28
const BODY_HEIGHT := 1.7

## Each walker: {"model", "line" (PackedVector3Array), "length", "at" (m along the line), "speed", "sign"}.
var walkers: Array[Dictionary] = []
## Each sitter: {"model", "shape"}.
var sitters: Array[Dictionary] = []
var _world: VungTau
var _hours: Array = []
var _shown := -1.0


func setup(world: VungTau, showcase: Showcase, path := PATH) -> bool:
	_world = world
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("ShowcasePeople: cannot read %s." % path)
		return false
	_hours = parsed.get("hours", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(parsed.get("seed", 1))
	_add_walkers(world, showcase, parsed.get("walkers", {}), rng)
	_add_sitters(world, showcase, parsed.get("sitters", {}), rng)
	return true


## The part of the people that is there at the clock time (0 to 1).
func share_at(minutes: float) -> float:
	var hour := fposmod(minutes / 60.0, 24.0)
	for i in _hours.size() - 1:
		var a: Array = _hours[i]
		var b: Array = _hours[i + 1]
		if float(a[0]) <= hour and hour <= float(b[0]):
			var span := float(b[0]) - float(a[0])
			return lerpf(float(a[1]), float(b[1]), (hour - float(a[0])) / span if span > 0.0 else 0.0)
	return 0.0


## The number of people that are there now.
func shown_count() -> int:
	var n := 0
	for w: Dictionary in walkers:
		n += 1 if (w.model as Node3D).visible else 0
	for s: Dictionary in sitters:
		n += 1 if (s.model as Node3D).visible else 0
	return n


func update_time(minutes: int) -> void:
	var share := share_at(minutes)
	if is_equal_approx(share, _shown):
		return
	_shown = share
	_show(walkers, share)
	_show(sitters, share)


func _show(people: Array[Dictionary], share: float) -> void:
	var count := roundi(people.size() * share)
	for i in people.size():
		var on := i < count
		var model: WorldModel = people[i].model
		model.visible = on
		model.set_animation_active(on)
		if people[i].has("shape"):
			(people[i].shape as CollisionShape3D).disabled = not on


func _process(delta: float) -> void:
	for w: Dictionary in walkers:
		var model: WorldModel = w.model
		if not model.visible:
			continue
		var at := float(w.at) + float(w.speed) * float(w.sign) * delta
		if at < 0.0 or at > float(w.length):
			w.sign = -float(w.sign)
			at = clampf(at, 0.0, float(w.length))
		w.at = at
		_place_walker(w)


func _place_walker(w: Dictionary) -> void:
	var line: PackedVector3Array = w.line
	var along := 0.0
	for i in line.size() - 1:
		var length := line[i].distance_to(line[i + 1])
		if along + length >= float(w.at) or i == line.size() - 2:
			var t := clampf((float(w.at) - along) / maxf(length, 0.001), 0.0, 1.0)
			var p := line[i].lerp(line[i + 1], t)
			p.y = _world.ground_height(p.x, p.z) + 0.03
			var dir := (line[i + 1] - line[i]) * float(w.sign)
			dir.y = 0.0
			if dir.length() < 0.001:
				dir = Vector3.BACK
			(w.model as WorldModel).transform = Transform3D(Basis.looking_at(-dir.normalized(), Vector3.UP), p)
			return
		along += length


## The walkers: on the ways of the types of the config in the park, or on its ways.
func _add_walkers(world: VungTau, showcase: Showcase, cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	var types: Array = cfg.get("types", ["footway", "pedestrian"])
	var ways: Array = cfg.get("ways", [])
	var min_length := float(cfg.get("min_length_m", 20.0))
	var lines: Array[PackedVector3Array] = []
	for road: Dictionary in world.data.roads:
		var named := ways.has(int(road.id))
		if not named and not str(road.type) in types:
			continue
		var line := PackedVector3Array()
		for p: Array in road.points:
			var point := Vector3(float(p[0]), float(p[1]), float(p[2]))
			var inside := showcase.contains(point.x, point.z) and (named or (showcase.park.size() >= 3 and
					Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), showcase.park)))
			if inside:
				line.append(point)
			elif line.size() >= 2:
				break
		if line.size() >= 2 and Showcase._line_length(line) >= min_length:
			lines.append(line)
	if lines.is_empty():
		return
	var models: Array = cfg.get("models", [])
	var speed: Array = cfg.get("speed_m_s", [0.9, 1.3])
	for i in int(cfg.get("count", 0)):
		var model := WorldModel.make(str(models[i % models.size()]))
		if model == null:
			continue
		var line: PackedVector3Array = lines[rng.randi() % lines.size()]
		var length := Showcase._line_length(line)
		add_child(model)
		model.apply_ranges()
		model.play("walk", rng.randf())
		var w := {"model": model, "line": line, "length": length, "at": rng.randf() * length,
				"speed": rng.randf_range(float(speed[0]), float(speed[1])), "sign": 1.0 if rng.randf() < 0.5 else -1.0}
		_place_walker(w)
		walkers.append(w)


## The sitters: on the borders of the raised lawns, with their backs to the lawn.
func _add_sitters(world: VungTau, showcase: Showcase, cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	var seats: Array[Transform3D] = []
	var every := float(cfg.get("every_m", 1.8))
	var out_m := float(cfg.get("out_m", 0.3))
	for ring: PackedVector2Array in showcase.planter_rings:
		var clockwise := Showcase._area(ring) < 0.0
		for i in ring.size():
			var a := ring[i]
			var b := ring[(i + 1) % ring.size()]
			var edge := (b - a)
			if edge.length() < every:
				continue
			var normal := Vector2(edge.y, -edge.x).normalized() if not clockwise else Vector2(-edge.y, edge.x).normalized()
			var n := int(edge.length() / every)
			for k in n:
				var p := a.lerp(b, (k + 0.5) / n) + normal * out_m
				var front := Vector3(normal.x, 0.0, normal.y)
				var at := Vector3(p.x, world.ground_height(p.x, p.y), p.y)
				seats.append(Transform3D(Basis.looking_at(-front, Vector3.UP), at))
	if seats.is_empty():
		return
	# The order of the seats is random, so the first people of the day are not all in one place.
	for i in range(seats.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t := seats[i]
		seats[i] = seats[j]
		seats[j] = t
	var body := StaticBody3D.new()
	body.name = "Sitters"
	body.collision_layer = Layers.SOLID
	body.collision_mask = 0
	add_child(body)
	var models: Array = cfg.get("models", [])
	for i in mini(int(cfg.get("count", 0)), seats.size()):
		var model := WorldModel.make(str(models[i % models.size()]))
		if model == null:
			continue
		model.transform = seats[i]
		add_child(model)
		model.apply_ranges()
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = BODY_RADIUS
		capsule.height = BODY_HEIGHT * 0.75
		shape.shape = capsule
		shape.position = seats[i].origin + Vector3(0, BODY_HEIGHT * 0.375, 0)
		body.add_child(shape)
		sitters.append({"model": model, "shape": shape})
