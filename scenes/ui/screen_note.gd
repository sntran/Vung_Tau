class_name ScreenNote
extends PanelContainer
## A short note on the screen (plan 0018): the name of the road (D13) and the
## hint of the first rides (D12). White text in a dark box, as the subtitles,
## for some seconds.

var label: Label
## The seconds that the note still shows; it goes when they are 0.
var left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color.WHITE)
	add_child(label)
	visible = false


## Shows the text for the seconds.
func show_text(text: String, seconds: float) -> void:
	label.text = text
	left = seconds
	visible = text != ""
	size = Vector2.ZERO
	reset_size()


## The time goes on by "delta" (0 holds the note); the note goes at the end.
func tick(delta: float) -> void:
	if not visible:
		return
	left -= delta
	if left <= 0.0:
		hide_note()


func hide_note() -> void:
	visible = false
	left = 0.0


## The text that shows, or "".
func shown() -> String:
	return label.text if visible else ""
