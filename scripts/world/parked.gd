class_name Parked
extends RefCounted
## Parked scooters of World (plan 0023, R9a).
##
## A parked scooter stands on its center stand (Q7: World has no side stand
## yet), at 10° to 30° from the line of the curb, with its front wheel
## turned. The paint colors come from data/world/palette.json ("scooters").

const PALETTE := "res://data/world/palette.json"
const MODEL := "scooter_tay_ga_1"
## The angle to the line of the curb, in degrees (R9a).
const MIN_ANGLE := 10.0
const MAX_ANGLE := 30.0
## The angles in a narrow hẻm (Q9): parallel to the wall.
const PARALLEL_ANGLE := Vector2(0.0, 5.0)
## The turn of the front wheel, in degrees, to one side or the other.
const MIN_STEER := 12.0
const MAX_STEER := 30.0

static var _colors: Array[Color] = []
static var _weights: Array[float] = []
static var _stand_angle := -1.0


## The paint colors and their weights.
static func colors() -> Array[Color]:
	_load()
	return _colors


static func _load() -> void:
	if not _colors.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALETTE))
	if not parsed is Dictionary:
		push_error("Parked: cannot read %s." % PALETTE)
		_colors.append(WorldMaterials.DEFAULT_PAINT)
		_weights.append(1.0)
		return
	for entry: Dictionary in parsed.get("scooters", {}).get("colors", []):
		_colors.append(Color(str(entry.color)))
		_weights.append(float(entry.get("weight", 1.0)))


## A paint color by its weight.
static func pick_color(rng: RandomNumberGenerator) -> Color:
	_load()
	var total := 0.0
	for w in _weights:
		total += w
	var at := rng.randf() * total
	for i in _colors.size():
		at -= _weights[i]
		if at <= 0.0:
			return _colors[i]
	return _colors[-1]


## The angle of the center stand where its foot is on the ground (y = 0): a
## real stand stops on the ground before its limit.
static func stand_angle() -> float:
	if _stand_angle >= 0.0:
		return _stand_angle
	var model := WorldModel.make(MODEL)
	if model == null or model.joint("stand") == null:
		_stand_angle = 0.0
		return _stand_angle
	var best := 0.0
	var a := 0.0
	while a <= 92.0:
		model.set_pose({"stand": a})
		if _lowest(model, model.joint("stand")) < 0.0:
			break
		best = a
		a += 1.0
	model.free()
	_stand_angle = best
	return _stand_angle


static func _lowest(model: WorldModel, node: Node3D) -> float:
	var low := INF
	var t := model._global_of(node)
	var m := node as MeshInstance3D
	if m != null and m.mesh != null:
		for p in m.mesh.get_faces():
			low = minf(low, (t * p).y)
	return low


## The pose of a parked scooter: the stand down, the front wheel turned.
static func pose(rng: RandomNumberGenerator) -> Dictionary:
	var steer := rng.randf_range(MIN_STEER, MAX_STEER) * (1.0 if rng.randf() < 0.5 else -1.0)
	return {"stand": stand_angle(), "fork": steer}


## An angle to the line of the curb, in degrees: 10° to 30° on a street (R9a).
## In a hẻm narrower than about 4 m, a scooter stands parallel to the wall
## (Q9: PARALLEL_ANGLE).
static func pick_angle(rng: RandomNumberGenerator, angles := Vector2(MIN_ANGLE, MAX_ANGLE)) -> float:
	return rng.randf_range(angles.x, angles.y)


## The transform of a parked scooter. "wall" is the point at the foot of the
## wall (or at the curb) next to the scooter, "along" the direction of the
## curb, and "out" the direction from the wall to the street. The front points
## to "along" and turns out by "angle_deg". The scooter touches the line of
## the wall with its rear side, 5 cm from it.
static func transform(wall: Vector3, along: Vector3, out: Vector3, angle_deg: float) -> Transform3D:
	var angle := deg_to_rad(angle_deg)
	var at := wall + out.normalized() * (depth(angle_deg) / 2.0 + 0.05)
	var forward := (along.normalized() * cos(angle) + out.normalized() * sin(angle)).normalized()
	# The model has its front to +Z.
	var basis := Basis.looking_at(-forward, Vector3.UP)
	return Transform3D(basis, at)


## The depth of a parked scooter from the wall, for an angle: the length and
## the width of the model across the line of the curb.
static func depth(angle_deg: float, width := 0.68) -> float:
	var a := deg_to_rad(angle_deg)
	return 1.86 * sin(a) + width * cos(a)
