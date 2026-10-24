class_name CenterDot
extends Control
## A small dot at the center of the screen. It shows the focus (plan 0002, D8).

var active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(24, 24)
	size = Vector2(24, 24)


func set_active(on: bool) -> void:
	if on != active:
		active = on
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	draw_circle(c, 7.0 if active else 4.5, Color(0, 0, 0, 0.45))
	draw_circle(c, 5.0 if active else 3.0, UiTheme.GOLD if active else Color.WHITE)
