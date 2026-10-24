class_name Player
extends CharacterBody3D
## The player in first person. The camera is at the eyes. The body is not visible.
##
## The player moves with "move_input" (the joystick or the keys) or walks to a
## point on the navigation mesh (tap to walk). The view turns with look() and
## with the gyroscope offset.

## The player stopped at the end of a tap walk.
signal arrived
## The player walked some meters. The clock uses this to move forward.
signal stepped(meters: float)

const WALK_SPEED := 1.4
const EYE_HEIGHT := 1.6
const RADIUS := 0.25
const HEIGHT := 1.7
## The player steps up on a curb or a doorstep of this height or less.
const STEP_HEIGHT := 0.2
const GRAVITY := 9.8
const PITCH_LIMIT := 80.0
## The view turns not faster than this, so that the look is smooth (D7).
const MAX_TURN_SPEED := 300.0
const NEAR := 0.05
## A tap walk stops when the player does not move for this time.
const STUCK_SECONDS := 1.5
## During a tap walk, the view turns to the walk direction at this rate.
const WALK_TURN_RATE := 3.0

## The joystick or key input: x is to the right, y is forward. The length is 1 or less.
var move_input := Vector2.ZERO
## True during a tap walk.
var walking := false
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
	_apply_view()


## Turns the view by a drag or a key. The values are in degrees.
func look(delta_yaw: float, delta_pitch: float) -> void:
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
	# Step up on a curb or a doorstep when a low wall stops the player.
	if horizontal.length() > 0.01 and is_on_wall():
		var moved := Vector3(global_position.x - start.x, 0, global_position.z - start.z)
		if moved.length() < wanted.length() * 0.5:
			_try_step(wanted - moved)
	var walked := Vector2(global_position.x - start.x, global_position.z - start.z).length()
	if walked > 0.0001:
		stepped.emit(walked)
	if walking:
		_check_arrival(walked, delta)


func _walk_velocity(_delta: float) -> Vector3:
	if _agent.is_navigation_finished():
		return Vector3.ZERO
	var next := _agent.get_next_path_position()
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
	if left < 0.12 or _agent.is_navigation_finished():
		walking = false
		arrived.emit()
		return
	_stuck_time = _stuck_time + delta if walked < 0.2 * WALK_SPEED * delta else 0.0
	if _stuck_time > STUCK_SECONDS:
		walking = false
		arrived.emit()


func _try_step(motion: Vector3) -> void:
	var up := Vector3(0, STEP_HEIGHT, 0)
	if test_move(global_transform, up):
		return
	var raised := global_transform.translated(up)
	if test_move(raised, motion):
		return
	global_position += up + motion
	apply_floor_snap()


func _process(delta: float) -> void:
	# The smooth look: the view turns to the target, not faster than the limit.
	var max_step := MAX_TURN_SPEED * delta
	var yaw_error := wrapf(target_yaw - yaw, -180.0, 180.0)
	yaw += clampf(yaw_error * minf(1.0, 18.0 * delta), -max_step, max_step)
	var pitch_error := target_pitch - pitch
	pitch += clampf(pitch_error * minf(1.0, 18.0 * delta), -max_step, max_step)
	_apply_view()


func _apply_view() -> void:
	if head == null:
		return
	rotation = Vector3(0, deg_to_rad(yaw + gyro_yaw), 0)
	head.rotation = Vector3(deg_to_rad(clampf(pitch + gyro_pitch, -PITCH_LIMIT, PITCH_LIMIT)), 0, 0)
