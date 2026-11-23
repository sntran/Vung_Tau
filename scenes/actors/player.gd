class_name Player
extends CharacterBody3D
## The player in first person. The camera is at the eyes. The body is not visible.
##
## The player moves with "move_input" (the joystick or the keys) or walks to a
## point on the navigation mesh (tap to walk). The view turns with look() and
## with the gyroscope offset.

## The player stopped at the end of a tap walk.
signal arrived
## walk_limit stopped the player.
signal blocked
## The player walked or rode some meters (the play tests count them).
signal stepped(meters: float)
## The scooter hit a wall, a house, a person, or a stop (plan 0018, D5).
signal bumped

const WALK_SPEED := 1.4
const EYE_HEIGHT := 1.6
const RADIUS := 0.25
const HEIGHT := 1.7
## The player steps up on a curb or a doorstep of this height or less.
const STEP_HEIGHT := 0.25
const GRAVITY := 9.8
const PITCH_LIMIT := 80.0
## The view turns not faster than this, so that the look is smooth (D7).
const MAX_TURN_SPEED := 300.0
const NEAR := 0.05
## A tap walk stops when the player does not move for this time.
const STUCK_SECONDS := 1.5
## During a tap walk, the view turns to the walk direction at this rate.
const WALK_TURN_RATE := 3.0
## Plan 0018, D3: the eye on the seat of a scooter, over the ground.
const RIDE_EYE := 1.45
## The point of the scooter of World under the eye: its distance behind the
## middle of the scooter (the model has its front to +Z).
const RIDE_EYE_BACK := 0.5
## The view looks at least this much down on a scooter; more on a wide
## screen, so that the handlebars show (ride_pitch()).
const RIDE_PITCH := -10.0
## The grips of the handlebars: their angle under the eye (degrees), and the room under them in the view.
const GRIP_ANGLE := 28.0
const GRIP_ROOM := 6.0
## The head turns at most this much to each side on a scooter (D3).
const HEAD_LIMIT := 100.0
## The head comes back to the front this long after the last look, when the scooter moves (D3).
const HEAD_RETURN_S := 1.0
## A scooter rides up a curb or a ramp of this height or less (D5: 15 cm). A
## road has no collision of its own: the floor under it is the ground, and
## the surface of the road is RoadBuilder.LIFT over it. So a curb of 15 cm
## (RoadBuilder.CURB) is 19 cm over the floor of the road.
const RIDE_STEP := RoadBuilder.CURB + RoadBuilder.LIFT + 0.01
## A drop of more than this in front of the wheels stops the scooter (stairs,
## a wall over the sand). A curb down to a road is 19 cm.
const RIDE_DROP := 0.22
## The capsule along the scooter: its radius and its length.
const RIDE_RADIUS := 0.33
const RIDE_LENGTH := 1.9
## The distance from the middle of the scooter to each axle (m).
const AXLE := 0.63

## The joystick or key input: x is to the right, y is forward. The length is 1 or less.
var move_input := Vector2.ZERO
## True during a tap walk.
var walking := false
## False in a world without a navigation mesh: a tap walk then goes straight to the point.
var use_navigation := true
## When it is set, the player cannot go to a point where walk_limit.call(point, from) is false.
var walk_limit: Callable
## The view direction that the input asks for, in degrees.
var target_yaw := -90.0
var target_pitch := 0.0
## The view direction now, in degrees, after the smooth turn.
var yaw := -90.0
var pitch := 0.0
## The extra view turn from the gyroscope, in degrees.
var gyro_yaw := 0.0
var gyro_pitch := 0.0
var head: Node3D
var camera: Camera3D
var _agent: NavigationAgent3D
var _target := Vector3.ZERO
var _stuck_time := 0.0
## Plan 0018: the motion of the scooter while the player rides, else null.
var ride: ScooterMotion = null
## The scooter of World under the player while the player rides.
var ride_model: WorldModel = null
## When it is set, a scooter cannot go to a point where ride_limit.call(point, from) is false (the water, the sand).
var ride_limit: Callable
## The turn of the head from the front of the scooter, in degrees (D3).
var head_offset := 0.0
## The pitch of the ground under the two wheels, in degrees (R5).
var ground_pitch := 0.0
var _look_idle := 0.0
var _walk_shape: CollisionShape3D
var _ride_shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.FLOOR | Layers.SOLID | Layers.MOVING
	floor_snap_length = STEP_HEIGHT + 0.05
	floor_max_angle = deg_to_rad(40.0)
	safe_margin = 0.01
	var shape := CollisionShape3D.new()
	shape.name = "Capsule"
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	shape.shape = capsule
	shape.position = Vector3(0, HEIGHT / 2.0, 0)
	add_child(shape)
	_walk_shape = shape
	# Plan 0018, D4: a capsule along the scooter, off while the player walks.
	_ride_shape = CollisionShape3D.new()
	_ride_shape.name = "RideCapsule"
	var long := CapsuleShape3D.new()
	long.radius = RIDE_RADIUS
	long.height = RIDE_LENGTH
	_ride_shape.shape = long
	_ride_shape.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, RIDE_RADIUS, -RIDE_EYE_BACK))
	_ride_shape.disabled = true
	add_child(_ride_shape)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, EYE_HEIGHT, 0)
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = NEAR
	camera.far = 4000.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 75.0
	camera.current = true
	head.add_child(camera)
	_agent = NavigationAgent3D.new()
	_agent.name = "Agent"
	_agent.radius = RADIUS
	_agent.height = HEIGHT
	_agent.path_desired_distance = 0.3
	_agent.target_desired_distance = 0.1
	_agent.avoidance_enabled = false
	add_child(_agent)
	_apply_view()


## Puts the player at the point at once, with no walk, and looks in the direction (degrees).
func place(point: Vector3, view_yaw: float, view_pitch := 0.0) -> void:
	walking = false
	velocity = Vector3.ZERO
	global_position = point
	_target = point
	target_yaw = view_yaw
	yaw = view_yaw
	target_pitch = view_pitch
	pitch = view_pitch
	if ride != null:
		ride.heading = view_yaw
		ride.speed = 0.0
		head_offset = 0.0
	_apply_view()


# --- The scooter (plan 0018) ---------------------------------------------

## True while the player rides a scooter.
func is_riding() -> bool:
	return ride != null


## Gets on the scooter: "model" is a WorldModel of the scooter, "at" the
## transform of the scooter in the world (its front to +Z). The player sits
## on it, and the body becomes a capsule along it (D4).
func start_ride(model: WorldModel, at: Transform3D) -> void:
	walking = false
	velocity = Vector3.ZERO
	var front := at.basis.z
	var heading := rad_to_deg(atan2(-front.x, -front.z))
	ride = ScooterMotion.new()
	ride.heading = heading
	ride_model = model
	if model.get_parent() != null:
		model.get_parent().remove_child(model)
	add_child(model)
	model.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -RIDE_EYE_BACK))
	model.set_pose({"stand": 0.0, "side_stand": 0.0, "fork": 0.0})
	# The eye over the seat: the middle of the scooter is RIDE_EYE_BACK in front of the eye.
	var middle := at.origin
	global_position = middle - ride.forward() * RIDE_EYE_BACK
	_walk_shape.disabled = true
	_ride_shape.disabled = false
	floor_snap_length = RIDE_STEP + 0.1
	floor_max_angle = deg_to_rad(25.0)
	head.position = Vector3(0, RIDE_EYE, 0)
	head_offset = 0.0
	yaw = heading
	target_yaw = heading
	target_pitch = ride_pitch()
	pitch = target_pitch
	ground_pitch = 0.0
	_look_idle = 0.0
	_apply_view()


## Gets off (D9): returns the scooter model and its transform in the world
## (its front to +Z). The caller parks it. The player stands at the left side.
func end_ride() -> Dictionary:
	if ride == null:
		return {}
	var model := ride_model
	var at := model.global_transform
	# The model leans and follows the ground: it stands up straight on its stand.
	var front := ride.forward()
	at = Transform3D(Basis.looking_at(-front, Vector3.UP), at.origin)
	remove_child(model)
	var heading := ride.heading
	ride = null
	ride_model = null
	_ride_shape.disabled = true
	_walk_shape.disabled = false
	floor_snap_length = STEP_HEIGHT + 0.05
	floor_max_angle = deg_to_rad(40.0)
	head.position = Vector3(0, EYE_HEIGHT, 0)
	head.rotation = Vector3.ZERO
	head_offset = 0.0
	ground_pitch = 0.0
	velocity = Vector3.ZERO
	# The left side of the scooter, away from the traffic (D9); the right side when the left is not free.
	var left := Vector3.UP.cross(front).normalized()
	var spot := at.origin + left * 0.75
	for side: Vector3 in [left, -left]:
		var place_at := at.origin + side * 0.75
		place_at.y = global_position.y
		var xform := Transform3D(Basis(), place_at + Vector3(0, 0.05, 0))
		if not test_move(xform, Vector3(0, 0.01, 0)):
			spot = place_at
			break
	place(Vector3(spot.x, global_position.y + 0.05, spot.z), heading, 0.0)
	return {"model": model, "transform": at}


## The pitch of the view on a scooter (D3): the grips of the handlebars show
## at the bottom of the view at each aspect of the screen. The camera keeps
## the horizontal field of view, so a wide screen sees less up and down.
func ride_pitch() -> float:
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16, 9)
	var half := rad_to_deg(atan(tan(deg_to_rad(camera.fov / 2.0)) * size.y / maxf(size.x, 1.0)))
	return clampf(-(GRIP_ANGLE - half + GRIP_ROOM), -25.0, RIDE_PITCH)


## The speed of the scooter in km/h, or 0.
func ride_speed_kmh() -> float:
	return ride.speed_kmh() if ride != null else 0.0


## The middle of the scooter under the player.
func ride_middle() -> Vector3:
	if ride == null:
		return global_position
	return global_position + ride.forward() * RIDE_EYE_BACK


func _ride_physics(delta: float) -> void:
	var start := global_position
	ride.step(delta, maxf(move_input.y, 0.0), maxf(-move_input.y, 0.0), move_input.x)
	rotation = Vector3(0, deg_to_rad(ride.heading), 0)
	var v := ride.velocity()
	velocity.x = v.x
	velocity.z = v.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	var wanted := Vector3(v.x, 0, v.z) * delta
	# Stairs down, a wall over the sand: a drop in front of the wheels stops the scooter.
	if absf(ride.speed) > 0.01 and _drop_ahead(signf(ride.speed), wanted.length()):
		_hit()
		velocity.x = 0.0
		velocity.z = 0.0
		wanted = Vector3.ZERO
	move_and_slide()
	var limited: bool = ride_limit.is_valid() and not ride_limit.call(global_position, start)
	if limited:
		global_position = Vector3(start.x, global_position.y, start.z)
		_hit()
		blocked.emit()
	elif wanted.length() > 0.0001 and is_on_wall():
		var moved := Vector3(global_position.x - start.x, 0, global_position.z - start.z)
		# A hit: the scooter goes into a wall at more than 30° from its face, or
		# stops (D5). Along a wall (a smaller angle) it slides.
		var into := _into_wall(wanted.normalized()) > 0.5 or moved.length() < wanted.length() * 0.5
		if into and _wall_is_step():
			var before_y := global_position.y
			_try_ride_step(wanted - moved)
			if global_position.y > before_y + 0.01:
				into = false
		if into:
			_hit()
			velocity.x = 0.0
			velocity.z = 0.0
	_update_ground_pitch()
	var rode := Vector2(global_position.x - start.x, global_position.z - start.z).length()
	if rode > 0.0001:
		stepped.emit(rode)


## The largest part of the direction that goes into a wall of the last move
## (0: along the wall, 1: straight into it).
func _into_wall(direction: Vector3) -> float:
	var most := 0.0
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if normal.y > 0.7:
			continue
		var flat := Vector3(normal.x, 0.0, normal.z)
		if flat.length() < 0.01:
			continue
		most = maxf(most, -direction.dot(flat.normalized()))
	return most


## Stops the scooter at a hit, with the sound of a bump when it moved.
func _hit() -> void:
	if absf(ride.speed) > 0.3:
		bumped.emit()
	ride.stop()


## True when the ground in front of the front wheel (or behind the rear wheel
## when the scooter goes back) is more than RIDE_DROP lower than the scooter.
func _drop_ahead(direction: float, step: float) -> bool:
	var middle := ride_middle()
	var front := ride.forward() * direction
	var point := middle + front * (AXLE + 0.25 + step)
	var floor_y := _floor_under(point, global_position.y + RIDE_STEP + 0.3)
	return floor_y < global_position.y - RIDE_DROP


## The height of the floor under the point, from "top" down, or -INF.
func _floor_under(point: Vector3, top: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, top, point.z),
			Vector3(point.x, top - 3.0, point.z), Layers.FLOOR | Layers.SOLID)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else -INF


## A curb or a ramp of RIDE_STEP or less: up, and on. A stair (a second step
## right after the first) stops the scooter (D5).
func _try_ride_step(motion: Vector3) -> void:
	var up := Vector3(0, RIDE_STEP, 0)
	if test_move(global_transform, up):
		return
	var raised := global_transform.translated(up)
	if test_move(raised, motion):
		return
	# A stair: the floor 0.5 m further on is one more step up (a slope after a curb is not).
	var ahead := ride_middle() + Vector3(motion.x, 0.0, motion.z).normalized() * (AXLE + 0.75)
	if _floor_under(ahead, global_position.y + 2.0 * RIDE_STEP + 0.3) > global_position.y + RIDE_STEP + 0.1:
		return
	if ride_limit.is_valid() and not ride_limit.call(global_position + motion, global_position):
		return
	global_position += up + motion
	apply_floor_snap()


## R5: the pitch of the scooter from the ground under its two wheels.
func _update_ground_pitch() -> void:
	var middle := ride_middle()
	var front := ride.forward()
	var top := global_position.y + 1.0
	var a := _floor_under(middle + front * AXLE, top)
	var b := _floor_under(middle - front * AXLE, top)
	if a == -INF or b == -INF:
		return
	ground_pitch = rad_to_deg(atan2(a - b, 2.0 * AXLE))


## Turns the view by a drag or a key. The values are in degrees.
func look(delta_yaw: float, delta_pitch: float) -> void:
	if ride != null:
		# On a scooter the head turns, up to HEAD_LIMIT to each side (D3).
		head_offset = clampf(head_offset + delta_yaw, -HEAD_LIMIT, HEAD_LIMIT)
		target_pitch = clampf(target_pitch + delta_pitch, -PITCH_LIMIT, PITCH_LIMIT)
		_look_idle = 0.0
		return
	target_yaw += delta_yaw
	target_pitch = clampf(target_pitch + delta_pitch, -PITCH_LIMIT, PITCH_LIMIT)


## Returns the point on the navigation mesh that is nearest to the point.
func nearest_walk_point(point: Vector3) -> Vector3:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return point
	return NavigationServer3D.map_get_closest_point(map, point)


## Walks to the point on the navigation mesh (tap to walk).
func walk_to(point: Vector3) -> void:
	if not use_navigation:
		_target = point
		walking = true
		_stuck_time = 0.0
		return
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		await get_tree().physics_frame
	_target = nearest_walk_point(point)
	_agent.target_position = _target
	walking = true
	_stuck_time = 0.0


## Stops a tap walk without the "arrived" signal.
func stop() -> void:
	walking = false
	_agent.target_position = global_position


func target() -> Vector3:
	return _target


## The position of the eyes.
func eye_position() -> Vector3:
	return camera.global_position


## The direction of the view.
func view_forward() -> Vector3:
	return -camera.global_basis.z


func _physics_process(delta: float) -> void:
	if ride != null:
		_ride_physics(delta)
		return
	var start := global_position
	var horizontal := Vector3.ZERO
	if move_input.length() > 0.01:
		walking = false
		var basis_yaw := Basis(Vector3.UP, deg_to_rad(yaw + gyro_yaw))
		var direction := basis_yaw * Vector3(move_input.x, 0, -move_input.y)
		horizontal = direction * WALK_SPEED
	elif walking:
		horizontal = _walk_velocity(delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	var wanted := horizontal * delta
	move_and_slide()
	var limited: bool = walk_limit.is_valid() and not walk_limit.call(global_position, start)
	if limited:
		global_position = Vector3(start.x, global_position.y, start.z)
		velocity = Vector3.ZERO
		if walking:
			walking = false
			arrived.emit()
		blocked.emit()
	# Step up on a curb or a doorstep when a low wall stops the player. A steep
	# slope of the ground (a height map) is not a step.
	if horizontal.length() > 0.01 and is_on_wall() and _wall_is_step():
		var moved := Vector3(global_position.x - start.x, 0, global_position.z - start.z)
		if moved.length() < wanted.length() * 0.5:
			_try_step(wanted - moved)
	# On a walkable slope of a height map, move_and_slide can stop: the motion
	# hits the floor triangle (also reported as a wall) and does not slide (the
	# edge of the Hải Đăng road at a hairpin, PT-36). When all the contacts are
	# walkable, a small step up goes on. A slope steeper than floor_max_angle
	# still stops the player.
	elif horizontal.length() > 0.01 and not limited and is_on_floor() and _contacts_are_walkable():
		var moved := Vector3(global_position.x - start.x, 0, global_position.z - start.z)
		if moved.length() < wanted.length() * 0.1:
			_try_step(wanted - moved)
	var walked := Vector2(global_position.x - start.x, global_position.z - start.z).length()
	if walked > 0.0001:
		stepped.emit(walked)
	if walking:
		_check_arrival(walked, delta)


func _walk_velocity(_delta: float) -> Vector3:
	var next := _target
	if use_navigation:
		if _agent.is_navigation_finished():
			return Vector3.ZERO
		next = _agent.get_next_path_position()
	var to_next := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
	if to_next.length() < 0.001:
		return Vector3.ZERO
	var direction := to_next.normalized()
	# The view turns to the walk direction, as a person looks where they walk.
	var walk_yaw := rad_to_deg(atan2(-direction.x, -direction.z))
	target_yaw += wrapf(walk_yaw - (target_yaw + gyro_yaw), -180.0, 180.0) * minf(1.0, WALK_TURN_RATE * _delta)
	var speed := WALK_SPEED
	var left := Vector2(_target.x - global_position.x, _target.z - global_position.z).length()
	if left < WALK_SPEED * _delta:
		speed = left / maxf(_delta, 0.001)
	return direction * speed


func _check_arrival(walked: float, delta: float) -> void:
	var left := Vector2(_target.x - global_position.x, _target.z - global_position.z).length()
	if left < 0.12 or (use_navigation and _agent.is_navigation_finished()):
		walking = false
		arrived.emit()
		return
	_stuck_time = _stuck_time + delta if walked < 0.2 * WALK_SPEED * delta else 0.0
	if _stuck_time > STUCK_SECONDS:
		walking = false
		arrived.emit()


func _wall_is_step() -> bool:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().y > 0.7:
			continue
		var owner_id := collision.get_collider_shape_index()
		var body := collision.get_collider() as CollisionObject3D
		if body == null:
			continue
		var shape := body.shape_owner_get_shape(body.shape_find_owner(owner_id), 0)
		if not shape is HeightMapShape3D:
			return true
	return false


## True when each contact of the last move_and_slide is a walkable floor (not steeper than floor_max_angle).
func _contacts_are_walkable() -> bool:
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_angle(0, up_direction) > floor_max_angle:
			return false
	return true


func _try_step(motion: Vector3) -> void:
	var up := Vector3(0, STEP_HEIGHT, 0)
	if test_move(global_transform, up):
		return
	var raised := global_transform.translated(up)
	if test_move(raised, motion):
		return
	if walk_limit.is_valid() and not walk_limit.call(global_position + motion, global_position):
		return
	global_position += up + motion
	apply_floor_snap()


func _process(delta: float) -> void:
	if ride != null:
		_ride_view(delta)
		return
	# The smooth look: the view turns to the target, not faster than the limit.
	var max_step := MAX_TURN_SPEED * delta
	var yaw_error := wrapf(target_yaw - yaw, -180.0, 180.0)
	yaw += clampf(yaw_error * minf(1.0, 18.0 * delta), -max_step, max_step)
	var pitch_error := target_pitch - pitch
	pitch += clampf(pitch_error * minf(1.0, 18.0 * delta), -max_step, max_step)
	_apply_view()


## The view on a scooter (D3): the head turns on the scooter and comes back to
## the front 1 s after the last look while the scooter moves; the view
## follows the ground and leans into a turn. The scooter of World shows its
## wheels, its handlebars, and its fork (R5).
func _ride_view(delta: float) -> void:
	_look_idle += delta
	if _look_idle > HEAD_RETURN_S and absf(ride.speed) > 0.5:
		head_offset = move_toward(head_offset, 0.0, 120.0 * delta)
		target_pitch = move_toward(target_pitch, ride_pitch(), 60.0 * delta)
	var max_step := MAX_TURN_SPEED * delta
	pitch += clampf((target_pitch - pitch) * minf(1.0, 18.0 * delta), -max_step, max_step)
	yaw = ride.heading + head_offset
	target_yaw = yaw
	if ride_model != null:
		ride_model.set_pose({"fork": -ride.steer, "front_wheel": ride.wheel_turn, "rear_wheel": ride.wheel_turn})
		# Turned by PI: the pitch and the lean of the model have the other sign.
		ride_model.rotation = Vector3(deg_to_rad(-ground_pitch), PI, deg_to_rad(ride.lean))
	_apply_view()


func _apply_view() -> void:
	if head == null:
		return
	if ride != null:
		rotation = Vector3(0, deg_to_rad(ride.heading), 0)
		head.rotation = Vector3(deg_to_rad(clampf(pitch + gyro_pitch + ground_pitch, -PITCH_LIMIT, PITCH_LIMIT)),
				deg_to_rad(head_offset + gyro_yaw), deg_to_rad(-ride.lean))
		return
	rotation = Vector3(0, deg_to_rad(yaw + gyro_yaw), 0)
	head.rotation = Vector3(deg_to_rad(clampf(pitch + gyro_pitch, -PITCH_LIMIT, PITCH_LIMIT)), 0, 0)
