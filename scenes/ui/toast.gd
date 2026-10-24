class_name Toast
extends PanelContainer
## A short message at the top of the screen. It hides after some seconds.
## It does not stop taps on the world.

const SECONDS := 2.8

var _label: RichTextLabel
var _left := 0.0


func _ready() -> void:
	theme_type_variation = "Toast"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	visible = false


## Shows the text (BBCode) for some seconds.
func show_text(text: String) -> void:
	_label.text = text
	visible = true
	_left = SECONDS


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			visible = false
