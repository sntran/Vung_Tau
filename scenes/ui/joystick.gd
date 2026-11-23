class_name Joystick
extends Control
## Draws the floating joystick where the left thumb touches.
## It does not take input. The main scene moves it and sets the knob.

const RADIUS := 80.0
## Plan 0018, D7: the joystick at its rest place is light (about 40 % opacity).
const REST_ALPHA := 0.4

var center := Vector2.ZERO
var knob := Vector2.ZERO
## True when the joystick shows at its rest place, with no thumb on it (D7).
var resting := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_at(point: Vector2) -> void:
	center = point
	knob = Vector2.ZERO
	visible = true
	resting = false
	queue_redraw()


## Plan 0018, D7: shows the joystick at its rest place, light, with no thumb on it.
func show_rest(point: Vector2) -> void:
	if visible and resting and center == point:
		return
	center = point
	knob = Vector2.ZERO
	visible = true
	resting = true
	queue_redraw()


## Sets the knob offset as a fraction of the radius (length 1 or less).
func set_knob(value: Vector2) -> void:
	knob = value.limit_length(1.0)
	queue_redraw()


func hide_stick() -> void:
	visible = false
	resting = false


func _draw() -> void:
	var alpha := REST_ALPHA if resting else 1.0
	draw_circle(center, RADIUS, Color(1, 1, 1, 0.18 * alpha))
	draw_arc(center, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.7 * alpha), 3.0, true)
	draw_circle(center + knob * RADIUS, RADIUS * 0.42, Color(1, 1, 1, 0.65 * alpha))
