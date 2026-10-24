class_name ClockSheet
extends Control
## The clock sheet: wait for a time or sleep until morning.
## It shows only the wait times that are later than now.

signal closed
signal choice_pressed(choice: Dictionary)

var panel: PanelContainer
var _dim: ColorRect
var _title: Label
var _hint: Label
var _choices: GridContainer
var _close: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0, 0, 0, 0.35)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.theme_type_variation = "SheetPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	_title = Label.new()
	_title.theme_type_variation = "Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_title)
	_close = Button.new()
	_close.name = "Close"
	_close.set_meta("test_id", "clock.close")
	_close.custom_minimum_size = Vector2(140, UiTheme.BUTTON_MIN_HEIGHT)
	_close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_close.pressed.connect(closed.emit)
	header.add_child(_close)
	_hint = Label.new()
	_hint.theme_type_variation = "Hint"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	_choices = GridContainer.new()
	_choices.add_theme_constant_override("h_separation", 12)
	_choices.add_theme_constant_override("v_separation", 12)
	column.add_child(_choices)


func _on_dim_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		closed.emit()


## Fills the sheet for the time. "columns" is 2 in landscape, so that the sheet fits.
func show_time(minutes: int, columns := 1) -> void:
	_choices.columns = columns
	var part := GameClock.part_of_day(minutes, Content.ui.parts_of_day)
	var params := {"time": GameClock.format_time(minutes), "part": part.vi, "part_en": part.en,
			"wake": GameClock.format_time(GameClock.WAKE_MINUTES)}
	_title.text = Content.format(Content.ui_text("clock_title"), params)
	_hint.text = Content.format(Content.ui_text("clock_hint"), params)
	_close.text = Content.ui_text("close")
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	for choice: Dictionary in GameClock.clock_choices(Content.ui.clock_choices, minutes):
		var button := TextButton.new()
		button.name = "Choice_%s" % choice.id
		button.set_meta("test_id", "clock.%s" % choice.id)
		button.set_style("PrimaryButton" if choice.get("style", "") == "primary" else "Button")
		button.set_texts(Content.format(choice.label, params), Content.format(choice.get("sub", ""), params))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(choice_pressed.emit.bind(choice))
		_choices.add_child(button)
