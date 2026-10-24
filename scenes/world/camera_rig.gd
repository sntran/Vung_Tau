class_name CameraRig
extends Camera3D
## The camera looks at the house fronts from the other side of the hẻm,
## at 25° down, and follows the player along the hẻm.
##
## The UI covers parts of the screen. The main scene tells the camera the
## free part of the screen ("free_rect"). The camera moves the center of the
## picture to the center of the free part, so the player is never under the
## talk panel. It uses a frustum offset (a lens shift), so the view angle
## does not change.

const PITCH_DEG := 25.0
const DISTANCE := 12.0
const LOOK_HEIGHT := 1.7
## The horizontal view angle of the free part of the screen.
const FREE_HFOV_DEG := 62.0
const MIN_FREE_VFOV_DEG := 32.0
const MAX_FREE_VFOV_DEG := 85.0
const NEAR := 0.1
const FOLLOW_RATE := 6.0
const LENS_RATE := 10.0

var target: Node3D
## The camera turns around the player by this angle. 0 looks at the house
## fronts (toward -Z). At the beach, the main scene turns the camera to the sea.
var yaw_deg := 0.0
var _yaw := 0.0
## The free part of the screen in viewport (base) coordinates.
var free_rect := Rect2()
var _focus := Vector3.ZERO
var _lens := Vector3.ZERO  # x: frustum height, y: offset x, z: offset y
var _snap := true


func _ready() -> void:
	projection = Camera3D.PROJECTION_FRUSTUM
	keep_aspect = Camera3D.KEEP_HEIGHT
	near = NEAR
	far = 4000.0


## Moves the camera to its target at once, with no smooth movement.
func snap() -> void:
	_snap = true


## Returns true when the camera does not move.
func is_settled() -> bool:
	if target == null:
		return true
	var goal := _goal_focus()
	return _focus.distance_to(goal) < 0.02 and _lens.distance_to(_goal_lens()) < 0.0005 \
			and absf(_yaw - yaw_deg) < 0.2


func _goal_focus() -> Vector3:
	return target.global_position + Vector3(0, LOOK_HEIGHT, 0)


func _goal_lens() -> Vector3:
	var view := get_viewport().get_visible_rect().size
	var rect := free_rect
	if rect.size.x < 10.0 or rect.size.y < 10.0:
		rect = Rect2(Vector2.ZERO, view)
	var aspect_free := rect.size.x / rect.size.y
	var vfov := 2.0 * atan(tan(deg_to_rad(FREE_HFOV_DEG) / 2.0) / aspect_free)
	vfov = clampf(vfov, deg_to_rad(MIN_FREE_VFOV_DEG), deg_to_rad(MAX_FREE_VFOV_DEG))
	var free_height := 2.0 * NEAR * tan(vfov / 2.0)
	var height := free_height * view.y / rect.size.y
	var width := height * view.x / view.y
	var center := rect.get_center()
	var offset_x := (0.5 - center.x / view.x) * width
	var offset_y := (center.y / view.y - 0.5) * height
	return Vector3(height, offset_x, offset_y)


## Returns the ray for a point in viewport (base) coordinates: [origin, direction].
## Camera3D.project_ray_normal() does not use the frustum offset, so the
## camera calculates the ray from its own lens values.
func screen_ray(point: Vector2) -> Array[Vector3]:
	var view := get_viewport().get_visible_rect().size
	var height := size
	var width := height * view.x / view.y
	var x := frustum_offset.x - width / 2.0 + point.x / view.x * width
	var y := frustum_offset.y + height / 2.0 - point.y / view.y * height
	var direction := (global_basis * Vector3(x, y, -near)).normalized()
	return [global_position, direction]


## Returns the point in viewport (base) coordinates for a 3D position.
func world_to_view(pos: Vector3) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var local := global_transform.affine_inverse() * pos
	var height := size
	var width := height * view.x / view.y
	var x := local.x * near / -local.z
	var y := local.y * near / -local.z
	return Vector2((x - frustum_offset.x + width / 2.0) / width * view.x,
			(frustum_offset.y + height / 2.0 - y) / height * view.y)


func _process(delta: float) -> void:
	if target == null:
		return
	var goal_focus := _goal_focus()
	var goal_lens := _goal_lens()
	if _snap:
		_focus = goal_focus
		_lens = goal_lens
		_yaw = yaw_deg
		_snap = false
	else:
		_focus = _focus.lerp(goal_focus, 1.0 - exp(-FOLLOW_RATE * delta))
		_lens = _lens.lerp(goal_lens, 1.0 - exp(-LENS_RATE * delta))
		_yaw = lerpf(_yaw, yaw_deg, 1.0 - exp(-FOLLOW_RATE * 0.5 * delta))
	var pitch := deg_to_rad(PITCH_DEG)
	var yaw := deg_to_rad(_yaw)
	global_position = _focus + Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * DISTANCE
	look_at(_focus, Vector3.UP)
	set_frustum(_lens.x, Vector2(_lens.y, _lens.z), NEAR, far)
