class_name Riding
extends Node
## The scooter in the main scene (plan 0018): the parked scooters that the
## player can ride (R4), the start points with a scooter (R8), get on and get
## off (D1, D9), the limits of a scooter (D5), and its sounds (R7).

## The player gets off only under this speed (D9).
const GET_OFF_KMH := 2.0
## A start point of data/geo/starts.json has a scooter within this distance (R8).
const START_RANGE := 10.0
## The scooter of a start stands this far ahead of the start point, on the right side.
const START_AHEAD := 4.0
## The engine loop: its pitch at a stop and at the top speed.
const ENGINE_PITCH := Vector2(1.0, 2.6)
## The caption of the engine shows again after this time (s) while the player rides.
const ENGINE_CAPTION_S := 8.0

var scooters: Scooters
var engine: AudioStreamPlayer
var start_sound: AudioStreamPlayer
var bump_sound: AudioStreamPlayer
## The paint of the scooter that the player rides.
var paint := WorldMaterials.DEFAULT_PAINT
## The number of hits of the scooter (the play tests read it).
var bumps := 0
var _main: Node
var _caption_left := 0.0


func _init(main: Node) -> void:
	_main = main
	name = "Riding"


func setup() -> void:
	scooters = Scooters.new()
	scooters.name = "Scooters"
	_main.get_node("World").add_child(scooters)
	var world: VungTau = _main.vung_tau
	if world != null:
		if world.parked != null:
			for row_id: String in world.parked.rows:
				scooters.add_row(world.parked.rows[row_id].node)
		_add_start_scooters(world)
		_main.player.ride_limit = _can_ride
	elif _main.hem != null:
		for scooter: WorldModel in _main.hem.scooters:
			scooters.add_node(scooter, scooter.get_meta("solid", null))
	_main.player.bumped.connect(_on_bumped)
	engine = _player("ScooterEngine", Tones.scooter_engine(), -8.0)
	start_sound = _player("ScooterStart", Tones.scooter_start(), -4.0)
	bump_sound = _player("ScooterBump", Tones.scooter_bump(), -2.0)
	# R8: --ride (the URL parameter ride on the web) starts on the scooter of the start.
	if GameState.has_arg("ride"):
		var near := scooters.nearest(_main.player.global_position, START_RANGE + 2.0)
		if near >= 0:
			ride(near)


func _player(node_name: String, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.name = node_name
	sound.stream = stream
	sound.volume_db = volume_db
	_main.get_node("Sounds").add_child(sound)
	return sound


## R8: a parked scooter near each start point: START_AHEAD in front of it, on
## the right side of the road, along the road.
func _add_start_scooters(world: VungTau) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/geo/starts.json"))
	if not parsed is Dictionary:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1800
	for record: Dictionary in parsed.get("starts", []):
		var start := world.start_point(str(record.id))
		if start.is_empty():
			continue
		var at: Vector3 = start.position
		var front := Basis(Vector3.UP, deg_to_rad(float(start.yaw))) * Vector3(0, 0, -1)
		var road := world.road_at(at)
		# Along the road: the direction of its nearest segment, the way of the view of the start.
		var along := _road_direction(road, at)
		if along != Vector3.ZERO:
			front = along if along.dot(front) >= 0.0 else -along
		var right := front.cross(Vector3.UP).normalized()
		var side := maxf(float(road.get("width", 3.0)) / 2.0 - 0.9, 0.0)
		var point := at + front * START_AHEAD + right * side
		point.y = world.ground_height(point.x, point.z)
		var xform := Transform3D(Basis.looking_at(-front, Vector3.UP), point)
		scooters.park(xform, Parked.pick_color(rng))


## The direction of the segment of the road nearest to the point, or ZERO.
static func _road_direction(road: Dictionary, at: Vector3) -> Vector3:
	var points: Array = road.get("points", [])
	var best := Vector3.ZERO
	var best_d := INF
	var p := Vector2(at.x, at.z)
	for i in points.size() - 1:
		var a := Vector2(points[i][0], points[i][2])
		var b := Vector2(points[i + 1][0], points[i + 1][2])
		if a.distance_to(b) < 0.1:
			continue
		var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
		if d < best_d:
			best_d = d
			best = Vector3(b.x - a.x, 0.0, b.y - a.y).normalized()
	return best


## D5: a scooter does not go into the water or onto the sand. The roads, the
## sidewalks, and the parts of the places (the walk of Hạ Long) are not sand.
func _can_ride(point: Vector3, from: Vector3) -> bool:
	var world: VungTau = _main.vung_tau
	if not world.can_stand(point, from):
		return false
	if world.surface_at(point.x, point.z).r < 0.5:
		return true
	var query := PhysicsRayQueryParameters3D.create(point + Vector3(0, 0.5, 0), point - Vector3(0, 1.5, 0), Layers.FLOOR)
	var player: Player = _main.player
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var body := hit.collider as CollisionObject3D
	if body == null:
		return true
	var owner_id := body.shape_find_owner(int(hit.shape))
	var shape := body.shape_owner_get_shape(owner_id, 0)
	# The ground of the chunks is a height map; a road or a part is another shape.
	return not (shape is HeightMapShape3D)


## The index of the parked scooter that the player looks at, or -1 (R4).
func looked_at() -> int:
	var player: Player = _main.player
	if player.is_riding():
		return -1
	return scooters.looked_at(player.eye_position(), player.view_forward(), player.global_position)


## Gets on the scooter (D1).
func ride(index: int) -> void:
	var taken := scooters.take(index)
	if taken.is_empty():
		return
	paint = taken.paint
	_main.player.start_ride(taken.model, taken.at)
	start_sound.play()
	_show_caption("scooter_start")
	_caption_left = 1.5
	engine.play()


## Gets off (D9): only under GET_OFF_KMH. The scooter stays on its stand there.
func get_off() -> bool:
	var player: Player = _main.player
	if not player.is_riding():
		return false
	if player.ride_speed_kmh() >= GET_OFF_KMH:
		_main.subtitles.show_caption(Content.ui_text("scooter_too_fast"))
		return false
	var left := player.end_ride()
	engine.stop()
	scooters.park(left.transform, paint, left.model)
	return true


func _on_bumped() -> void:
	bumps += 1
	bump_sound.play()
	_show_caption("scooter_bump")


func _show_caption(sound_id: String) -> void:
	_main.subtitles.show_caption(Content.sound(sound_id).get("caption", ""))


func _process(delta: float) -> void:
	var player: Player = _main.player
	if not player.is_riding():
		return
	var part := clampf(absf(player.ride.speed) / ScooterMotion.TOP_SPEED, 0.0, 1.0)
	engine.pitch_scale = lerpf(ENGINE_PITCH.x, ENGINE_PITCH.y, part)
	engine.volume_db = lerpf(-10.0, -3.0, part)
	_caption_left -= delta
	if _caption_left <= 0.0:
		_show_caption("scooter_engine")
		_caption_left = ENGINE_CAPTION_S


## The texts of the action button (D7): "Lên xe · Ride" and "Xuống xe · Get off".
static func verb(key: String) -> String:
	var text := Content.ui_dict(key)
	return "%s · %s" % [text.get("vi", ""), text.get("en", "")]
