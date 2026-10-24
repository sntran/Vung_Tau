class_name CreditsSheet
extends PanelContainer
## The credits sheet: the notices of the map data, the height data, and the
## assets (plan 0003, acceptance criterion 4). The text is in data/credits.json.

signal closed

const PATH := "res://data/credits.json"

var _title: Label
var _close: Button
var _column: VBoxContainer


func _ready() -> void:
	theme_type_variation = "SheetPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	outer.add_child(header)
	_title = Label.new()
	_title.theme_type_variation = "Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_close = Button.new()
	_close.name = "Close"
	_close.set_meta("test_id", "credits.close")
	_close.custom_minimum_size = Vector2(140, UiTheme.BUTTON_MIN_HEIGHT)
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(closed.emit)
	header.add_child(_close)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 14)
	scroll.add_child(_column)


func show_credits() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary:
		data = {"title": "Credits", "sections": []}
	_title.text = data.get("title", "Credits")
	_close.text = Content.ui_text("close")
	for child in _column.get_children():
		child.queue_free()
	for section: Dictionary in data.get("sections", []):
		var heading := Label.new()
		heading.theme_type_variation = "GroupTitle"
		heading.text = section.title
		_column.add_child(heading)
		var text := Label.new()
		text.text = section.text
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.set_meta("test_id", "credits.text")
		_column.add_child(text)
