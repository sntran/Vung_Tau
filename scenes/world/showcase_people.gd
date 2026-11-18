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
## A walker stops when the player is in front of it in its lane (nearer than
## STOP_GAP ahead and LANE to the side, m), and walks on when the player is not
## there (plan 0026, PT-74).
const STOP_GAP := 1.4
const LANE := 0.7
## A walker that waits steps aside at this speed (m/s), and goes back to its lane.
const STEP_ASIDE := 0.8
## A walker does not move nearer than this to the player (m, foot to foot): the
## two bodies and a margin.
const KEEP_GAP := 0.6

## Each walker: {"model", "body", "line" (PackedVector3Array), "length", "at" (m along the line),
## "speed", "sign", "side" (m to the right of the middle of the way), "now" (the side now),
## "room" (the most side on the way), "stopped"}. The body stops the player.
## The ranges of the levels of a person on Low: the mid level (6 500 to 9 600
## triangles) to 6 m, the far level (1 500) beyond. The people in the frames of
## the shots (report 0026, D-0026-07) made S5 330 000 triangles on Low, more
## than the limit of 300 000 (PT-73); with the mid level to 20 m and the hedges,
## the grove, and the poles of audit 2, S2 had 304 000 and S5 312 000. With the
## mid level to 12 m, one walker 7 m from the eye of S2 made 303 438 (the CI of
## 0732db6): S2 must have room for a person near the eye. The other presets
## keep WorldModel.RANGES.
const PEOPLE_RANGES := {"low": Vector3(5.0, 6.0, 150.0)}
## A swimmer goes out at most this many steps of 0.5 m from the water's edge.
const SWIM_STEPS := 160
## The tube of the swim ring phao_boi (m, its drawing), and the distance of the
## ring from the middle of an adult who holds it at its side (m).
const RING_TUBE := 0.2
const RING_SIDE := 0.55
## A swimmer is not nearer than this to the line of a boat on the sand (m).
const BOAT_GAP := 2.5
## A swimmer whose place is at a boat goes this far along the shore (m).
const SWIM_SHIFTS := [0.0, 3.0, -3.0, 6.0, -6.0]
## The ranges of the levels of the swimmers and their rings: the shot S1 (the
## photo of the beach) sees them from 55 m to 150 m, a little farther than the
## far end of the other people on Low. Fourteen far levels of 1 500 triangles.
const SWIM_RANGES := {
	"low": Vector3(15.0, 20.0, 170.0),
	"medium": Vector3(20.0, 55.0, 300.0),
	"high": Vector3(30.0, 80.0, 350.0),
	"ultra": Vector3(40.0, 110.0, 400.0),
}

var walkers: Array[Dictionary] = []
## Each sitter: {"model", "shape"}.
var sitters: Array[Dictionary] = []
## Each swimmer (report 0026, D-0026-20): {"model", "ring" (a swim ring or null),
## "side" (the place of the ring from the middle of the swimmer, in its frame),
## "base" (Vector2: its point on the line on the sand), "depth" (m of water at
## its feet), "turn" (degrees from the direction to the beach)}. The swimmers stand in the sea in their clothes (shorts
## and T-shirts, report 0026, Q20), some with a swim ring at the water line.
var swimmers: Array[Dictionary] = []
var _swim: Dictionary = {}
var _swim_sea := INF
var _swim_shown := -1.0
var _world: VungTau
var _showcase: Showcase
var _hours: Array = []
var _shown := -1.0


func setup(world: VungTau, showcase: Showcase, path := PATH) -> bool:
	_world = world
	_showcase = showcase
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("ShowcasePeople: cannot read %s." % path)
		return false
	_hours = parsed.get("hours", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(parsed.get("seed", 1))
	_add_walkers(world, showcase, parsed.get("walkers", {}), rng)
	_add_sitters(world, showcase, parsed.get("sitters", {}), rng)
	_add_swimmers(parsed.get("swimmers", {}), rng)
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
	_update_swimmers(minutes)
	var share := share_at(minutes)
	if is_equal_approx(share, _shown):
		return
	_shown = share
	_show(walkers, share)
	_show(sitters, share)


## The number of swimmers in the sea now.
func swimmers_shown() -> int:
	var n := 0
	for s: Dictionary in swimmers:
		n += 1 if (s.model as Node3D).visible else 0
	return n


func _add_swimmers(cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	if cfg.is_empty():
		return
	_swim = cfg
	var line := PackedVector2Array()
	for q: Array in cfg.get("line", []):
		line.append(Vector2(float(q[0]), float(q[1])))
	var models := _with_files(cfg.get("models", []))
	if line.size() < 2 or models.is_empty():
		return
	var total := 0.0
	for i in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	var adult: Array = cfg.get("depth_m", [0.6, 1.0])
	var child: Array = cfg.get("child_depth_m", [0.4, 0.6])
	for i in int(cfg.get("count", 0)):
		var id := str(models[i % models.size()])
		var model := WorldModel.make(id)
		if model == null:
			continue
		add_child(model)
		model.custom_ranges = SWIM_RANGES
		model.apply_ranges()
		_no_shadow(model)
		var age := float(WorldModel.order(id).get("order", {}).get("options", {}).get("age", 30))
		var depth: Array = child if age < float(cfg.get("child_age", 14)) else adult
		var ring: WorldModel = null
		if rng.randf() < float(cfg.get("ring_part", 0.0)) and Showcase._has_model(str(cfg.get("ring_model", ""))):
			ring = WorldModel.make(str(cfg.ring_model))
			if ring:
				add_child(ring)
				ring.custom_ranges = SWIM_RANGES
				ring.apply_ranges()
				_no_shadow(ring)
		# A child stands in its ring; an adult holds the ring at its side.
		var side := Vector3.ZERO if depth == child else Vector3(RING_SIDE * (1.0 if rng.randf() < 0.5 else -1.0), 0.0, 0.0)
		swimmers.append({"model": model, "ring": ring, "side": side, "base": _along(line, total * (i + rng.randf()) / int(cfg.count)),
				"depth": rng.randf_range(float(depth[0]), float(depth[1])), "turn": rng.randf_range(-70.0, 70.0)})
	# The first swimmers of the list are in the sea when only some are there: a
	# mixed order, so that they are not all at one end of the line.
	for i in range(swimmers.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var keep := swimmers[i]
		swimmers[i] = swimmers[j]
		swimmers[j] = keep


## The far level of a person casts no shadow: on Low it starts at 12 m, and the
## shadow pass doubled the triangles of the people of S2 (report 0026, PT-73).
static func _far_no_shadow(model: WorldModel) -> void:
	var far := model.level("far")
	if far != null:
		_no_shadow(far)


## A swimmer and its ring cast no shadow: the water does not show it, and the
## shadow pass doubled their triangles (report 0026, PT-73: S5).
static func _no_shadow(model: Node) -> void:
	for node in model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The point at the distance s along a line.
static func _along(line: PackedVector2Array, s: float) -> Vector2:
	var left := s
	for i in line.size() - 1:
		var length := line[i].distance_to(line[i + 1])
		if left <= length:
			return line[i].lerp(line[i + 1], left / maxf(length, 0.001))
		left -= length
	return line[line.size() - 1]


## The swimmers of the hour, each where the water at its feet is its depth: from
## its point of the line of the water's edge, out to the sea. The tide moves them.
func _update_swimmers(minutes: int) -> void:
	if swimmers.is_empty():
		return
	var sea := _world.sea_level
	var share := _share(_swim.get("hours", []), minutes)
	if absf(sea - _swim_sea) < 0.05 and is_equal_approx(share, _swim_shown):
		return
	_swim_sea = sea
	_swim_shown = share
	var out_dir: Array = _swim.get("to_sea", [-1.0, 0.0])
	var out := Vector2(float(out_dir[0]), float(out_dir[1])).normalized()
	var count := roundi(swimmers.size() * share)
	var along := Vector2(-out.y, out.x)
	for i in swimmers.size():
		var s: Dictionary = swimmers[i]
		var model: WorldModel = s.model
		var q := Vector2.ZERO
		var found := false
		# From its point, or a little to a side of it when a boat is there.
		for shift: float in SWIM_SHIFTS:
			q = (s.base as Vector2) + along * shift
			var deep := false
			for k in SWIM_STEPS:
				if sea - _world.ground_height(q.x, q.y) >= float(s.depth):
					deep = true
					break
				q += out * 0.5
			if deep and not _near_boat(q):
				found = true
				break
		var on := i < count and found
		model.visible = on
		if s.ring:
			(s.ring as Node3D).visible = on
		if not on:
			continue
		var ground := _world.ground_height(q.x, q.y)
		var to_beach := Vector3(-out.x, 0.0, -out.y).rotated(Vector3.UP, deg_to_rad(float(s.turn)))
		var basis := Basis.looking_at(-to_beach, Vector3.UP)
		model.transform = Transform3D(basis, Vector3(q.x, ground, q.y))
		if s.ring:
			# The middle of the tube of the ring is at the water line.
			var at := Vector3(q.x, sea - RING_TUBE * 0.5, q.y) + basis * (s.side as Vector3)
			(s.ring as Node3D).transform = Transform3D(Basis.IDENTITY, at)


## True when the point is nearer than BOAT_GAP to a boat on the sand.
func _near_boat(q: Vector2) -> bool:
	if _showcase == null:
		return false
	for boat: Dictionary in _showcase.beached_boats:
		var at: Vector3 = boat.at
		var along: Vector3 = boat.along
		var half := float(boat.half)
		var a := Vector2(at.x, at.z) - Vector2(along.x, along.z) * half
		var b := Vector2(at.x, at.z) + Vector2(along.x, along.z) * half
		if Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) < BOAT_GAP:
			return true
	return false


static func _share(hours: Array, minutes: float) -> float:
	var hour := fposmod(minutes / 60.0, 24.0)
	for i in hours.size() - 1:
		var a: Array = hours[i]
		var b: Array = hours[i + 1]
		if float(a[0]) <= hour and hour <= float(b[0]):
			var span := float(b[0]) - float(a[0])
			return lerpf(float(a[1]), float(b[1]), (hour - float(a[0])) / span if span > 0.0 else 0.0)
	return 0.0


func _show(people: Array[Dictionary], share: float) -> void:
	var count := roundi(people.size() * share)
	for i in people.size():
		var on := i < count
		var model: WorldModel = people[i].model
		model.visible = on
		model.set_animation_active(on)
		if people[i].has("shape"):
			(people[i].shape as CollisionShape3D).disabled = not on
		if people[i].has("body"):
			(people[i].body as CollisionObject3D).collision_layer = Layers.MOVING if on else 0


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	for w: Dictionary in walkers:
		var model: WorldModel = w.model
		if not model.visible:
			continue
		# The player in front of the walker: the walker stops and steps aside,
		# away from the player, in the width of its way.
		var stop := false
		var aside := float(w.side)
		var player := Vector3.INF
		if camera:
			player = camera.global_position
			var to_player := player - model.global_position
			to_player.y = 0.0
			var forward := model.global_transform.basis.z
			forward.y = 0.0
			forward = forward.normalized()
			var ahead := to_player.dot(forward)
			var right := forward.cross(Vector3.UP)
			stop = ahead > 0.0 and ahead < STOP_GAP and absf(to_player.dot(right)) < LANE
			if stop:
				aside = -float(w.room) if to_player.dot(right) > 0.0 else float(w.room)
		var before := {"at": w.at, "now": w.now, "sign": w.sign}
		if stop:
			w.now = move_toward(float(w.now), aside, STEP_ASIDE * delta)
		else:
			w.now = move_toward(float(w.now), float(w.side), STEP_ASIDE * 0.5 * delta)
			var at := float(w.at) + float(w.speed) * float(w.sign) * delta
			if at < 0.0 or at > float(w.length):
				w.sign = -float(w.sign)
				at = clampf(at, 0.0, float(w.length))
			w.at = at
		var place := _walker_transform(w)
		# Never into the player: the walker waits where it is.
		var near := player != Vector3.INF and Vector2(place.origin.x - player.x, place.origin.z - player.z).length() < KEEP_GAP \
				and Vector2(place.origin.x - player.x, place.origin.z - player.z).length() \
				< Vector2(model.global_position.x - player.x, model.global_position.z - player.z).length()
		if near:
			w.at = before.at
			w.now = before.now
			w.sign = before.sign
		else:
			model.transform = place
		var waits := stop or near
		if waits != bool(w.stopped):
			w.stopped = waits
			model.set_animation_active(not waits)


func _place_walker(w: Dictionary) -> void:
	(w.model as WorldModel).transform = _walker_transform(w)


## The place of a walker: "at" m along its line, "now" m to the right of it, its
## front in the direction of its walk.
func _walker_transform(w: Dictionary) -> Transform3D:
	var line: PackedVector3Array = w.line
	var along := 0.0
	for i in line.size() - 1:
		var length := line[i].distance_to(line[i + 1])
		if along + length >= float(w.at) or i == line.size() - 2:
			var t := clampf((float(w.at) - along) / maxf(length, 0.001), 0.0, 1.0)
			var p := line[i].lerp(line[i + 1], t)
			var dir := (line[i + 1] - line[i]) * float(w.sign)
			dir.y = 0.0
			if dir.length() < 0.001:
				dir = Vector3.BACK
			# People keep to the right of the way.
			p += dir.normalized().cross(Vector3.UP) * float(w.get("now", 0.0))
			p.y = _world.ground_height(p.x, p.z) + 0.03
			return Transform3D(Basis.looking_at(-dir.normalized(), Vector3.UP), p)
		along += length
	return (w.model as WorldModel).transform


## The walkers: on the ways of the types of the config in the park, or on its ways.
func _add_walkers(world: VungTau, showcase: Showcase, cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	var types: Array = cfg.get("types", ["footway", "pedestrian"])
	var ways: Array = cfg.get("ways", [])
	var min_length := float(cfg.get("min_length_m", 20.0))
	var lines: Array[PackedVector3Array] = []
	var widths: Array[float] = []
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
			widths.append(float(road.get("width", 2.0)))
	if lines.is_empty():
		return
	var models := _with_files(cfg.get("models", []))
	var speed: Array = cfg.get("speed_m_s", [0.9, 1.3])
	var keep_right: Array = cfg.get("keep_right_m", [0.0, 0.0])
	# The spots: walkers on a short way in the frame of a shot (report 0026,
	# D-0026-07), in the order of the walkers, so the first of the day are there.
	# Each entry: [the line, the place of the walker on it, the walkers on it].
	var spot_lines: Array = []
	for spot: Dictionary in cfg.get("spots", []):
		var spot_line := PackedVector3Array()
		for p: Array in spot.line:
			spot_line.append(Vector3(float(p[0]), world.ground_height(float(p[0]), float(p[1])), float(p[1])))
		var n := int(spot.get("count", 0))
		for k in n:
			spot_lines.append([spot_line, k, n])
	# Every other walker is on a spot, so the spots have people at each hour (the
	# order of the list is the order in which the people come: _show()).
	var count := int(cfg.get("count", 0))
	var plan: Array = []
	for i in count:
		var on_spot := not spot_lines.is_empty() and (i % 2 == 0 or count - i <= spot_lines.size())
		plan.append(spot_lines.pop_front() if on_spot else null)
	for i in count:
		var model := WorldModel.make(str(models[i % models.size()]))
		if model == null:
			continue
		var which := rng.randi() % lines.size()
		var line: PackedVector3Array = lines[which]
		# Not on the borders of the way: the half of the width less a body and a border.
		var room := maxf(widths[which] / 2.0 - 0.5, 0.0)
		var spot: Array = plan[i] if plan[i] != null else []
		if not spot.is_empty():
			line = spot[0]
			room = 1.0
		var length := Showcase._line_length(line)
		# The walkers of a spot start apart, one in each part of its line.
		var start := rng.randf() * length
		if not spot.is_empty():
			start = (float(spot[1]) + rng.randf_range(0.25, 0.75)) / float(spot[2]) * length
		var side := minf(rng.randf_range(float(keep_right[0]), float(keep_right[1])), room)
		add_child(model)
		model.custom_ranges = PEOPLE_RANGES
		model.apply_ranges()
		_far_no_shadow(model)
		model.play("walk", rng.randf())
		var w := {"model": model, "body": _walker_body(model), "line": line, "length": length,
				"at": start, "speed": rng.randf_range(float(speed[0]), float(speed[1])),
				"sign": 1.0 if rng.randf() < 0.5 else -1.0, "side": side, "now": side, "room": maxf(room, 0.7), "stopped": false}
		_place_walker(w)
		walkers.append(w)


## The body of a walker: it moves with the model, and it stops the player.
func _walker_body(model: WorldModel) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = "Body"
	body.sync_to_physics = false
	body.collision_layer = Layers.MOVING
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	shape.shape = capsule
	shape.position = Vector3(0, BODY_HEIGHT / 2.0, 0)
	body.add_child(shape)
	model.add_child(body)
	return body


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
	var models := _with_files(cfg.get("models", []))
	for i in mini(int(cfg.get("count", 0)), seats.size()):
		var model := WorldModel.make(str(models[i % models.size()]))
		if model == null:
			continue
		model.transform = seats[i]
		add_child(model)
		model.custom_ranges = PEOPLE_RANGES
		model.apply_ranges()
		_far_no_shadow(model)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = BODY_RADIUS
		capsule.height = BODY_HEIGHT * 0.75
		shape.shape = capsule
		shape.position = seats[i].origin + Vector3(0, BODY_HEIGHT * 0.375, 0)
		body.add_child(shape)
		sitters.append({"model": model, "shape": shape})


## The models of the list whose files are in assets/world (a model whose order
## waits for the job "Models of World" is left out until then).
static func _with_files(models: Array) -> Array:
	return models.filter(func(id: Variant) -> bool: return Showcase._has_model(str(id)))
