class_name Joystick
extends Control
## Draws the floating joystick where the left thumb touches.
## It does not take input. The main scene moves it and sets the knob.

const RADIUS := 80.0

var center := Vector2.ZERO
var knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_at(point: Vector2) -> void:
	center = point
	knob = Vector2.ZERO
	visible = true
	queue_redraw()


## Sets the knob offset as a fraction of the radius (length 1 or less).
func set_knob(value: Vector2) -> void:
	knob = value.limit_length(1.0)
	queue_redraw()


func hide_stick() -> void:
	visible = false


func _draw() -> void:
	draw_circle(center, RADIUS, Color(1, 1, 1, 0.18))
	draw_arc(center, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.7), 3.0, true)
	draw_circle(center + knob * RADIUS, RADIUS * 0.42, Color(1, 1, 1, 0.65))
