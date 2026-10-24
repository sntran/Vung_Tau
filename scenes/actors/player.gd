class_name Player
extends Node3D
## The player. The player walks on the navigation mesh at 2.0 m/s.

## The player stopped at the end of a walk.
signal arrived
## The player walked some meters. The clock uses this to move forward.
signal stepped(meters: float)

const SPEED := 2.0

var walking := false
var figure: Node3D
var _agent: NavigationAgent3D
var _walk_time := 0.0
var _target := Vector3.ZERO


func _ready() -> void:
	figure = Greybox.person(self, Vector3.ZERO, Color("#2C7A6E"), Color("#E8E1C8"),
			Color("#E3B48E"), Color("#5A3A22"), 1.7, "Figure")
	# A backpack and a sun hat, so that the player looks like a visitor.
	Greybox.box(figure, Vector3(0.32, 0.4, 0.16), Vector3(0, 1.1, -0.2), Color("#C78B3A"), "Backpack")
	Greybox.cylinder(figure, 0.24, 0.04, Vector3(0, 1.72, 0), Color("#F2E6C8"), "HatBrim")
	Greybox.cylinder(figure, 0.13, 0.12, Vector3(0, 1.78, 0), Color("#F2E6C8"), "HatTop")
	_agent = NavigationAgent3D.new()
	_agent.name = "Agent"
	_agent.radius = 0.3
	_agent.height = 1.7
	_agent.path_desired_distance = 0.15
	_agent.target_desired_distance = 0.05
	_agent.avoidance_enabled = false
	add_child(_agent)


## Returns the point on the navigation mesh that is nearest to the point.
func nearest_walk_point(point: Vector3) -> Vector3:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return Vector3(point.x, 0, point.z)
	var result := NavigationServer3D.map_get_closest_point(map, point)
	return Vector3(result.x, 0, result.z)


## Walks to the point. The point moves to the nearest point on the navigation mesh.
func walk_to(point: Vector3) -> void:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		# The map is not ready in the first frame. Wait one physics frame.
		await get_tree().physics_frame
	_target = nearest_walk_point(point)
	_agent.target_position = _target
	walking = true
	_walk_time = 0.0


## Stops the walk without the "arrived" signal.
func stop() -> void:
	walking = false
	_agent.target_position = global_position
	_reset_legs()


## Puts the player at the point at once, with no walk.
func place(point: Vector3) -> void:
	walking = false
	global_position = Vector3(point.x, 0, point.z)
	_target = global_position
	_reset_legs()


func target() -> Vector3:
	return _target


func _physics_process(delta: float) -> void:
	if not walking:
		return
	if _agent.is_navigation_finished():
		_finish()
		return
	var next := _agent.get_next_path_position()
	var to_next := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
	var step := SPEED * delta
	var moved := minf(step, to_next.length())
	if to_next.length() > 0.001:
		var direction := to_next.normalized()
		global_position += direction * moved
		global_position.y = 0.0
		rotation.y = atan2(direction.x, direction.z)
	stepped.emit(moved)
	_walk_time += delta
	var swing := sin(_walk_time * 9.0) * 30.0
	figure.get_node("LegLeft").rotation_degrees.x = swing
	figure.get_node("LegRight").rotation_degrees.x = -swing
	if Vector2(global_position.x - _target.x, global_position.z - _target.z).length() < 0.05:
		_finish()


func _finish() -> void:
	walking = false
	_reset_legs()
	arrived.emit()


func _reset_legs() -> void:
	if figure:
		figure.get_node("LegLeft").rotation_degrees.x = 0.0
		figure.get_node("LegRight").rotation_degrees.x = 0.0
