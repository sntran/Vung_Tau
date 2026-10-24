class_name SettingsSheet
extends PanelContainer
## The settings sheet: look sensitivity, invert up and down, gyroscope look,
## field of view, and tap to walk (plan 0002, R18).

signal closed
signal changed(settings: Dictionary)

const SENSITIVITY_RANGE := Vector2(0.25, 2.0)
const FOV_RANGE := Vector2(60.0, 90.0)

var _title: Label
var _close: Button
var _sensitivity: HSlider
var _sensitivity_label: Label
var _fov: HSlider
var _fov_label: Label
var _invert: CheckButton
var _gyro: CheckButton
var _tap_walk: CheckButton
var _quiet := false
var _grid: GridContainer


func _ready() -> void:
	theme_type_variation = "SheetPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	_title = Label.new()
	_title.theme_type_variation = "Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_close = Button.new()
	_close.name = "Close"
	_close.set_meta("test_id", "settings.close")
	_close.custom_minimum_size = Vector2(140, UiTheme.BUTTON_MIN_HEIGHT)
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(closed.emit)
	header.add_child(_close)
	# Two columns in landscape, so that all settings fit on the screen.
	_grid = GridContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 32)
	_grid.add_theme_constant_override("v_separation", 10)
	column.add_child(_grid)
	var sensitivity := _slider_row(_grid, "settings.sensitivity", SENSITIVITY_RANGE, 0.05)
	_sensitivity = sensitivity[0]
	_sensitivity_label = sensitivity[1]
	_invert = _toggle(_grid, "settings.invert")
	_gyro = _toggle(_grid, "settings.gyro")
	var fov := _slider_row(_grid, "settings.fov", FOV_RANGE, 1.0)
	_fov = fov[0]
	_fov_label = fov[1]
	_tap_walk = _toggle(_grid, "settings.tap_walk")


func _slider_row(parent: Control, test_id: String, value_range: Vector2, step: float) -> Array:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	parent = box
	var label := Label.new()
	parent.add_child(label)
	var slider := HSlider.new()
	slider.set_meta("test_id", test_id)
	slider.min_value = value_range.x
	slider.max_value = value_range.y
	slider.step = step
	slider.custom_minimum_size = Vector2(0, UiTheme.BUTTON_MIN_HEIGHT)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_value_changed.unbind(1))
	parent.add_child(slider)
	return [slider, label]


func _toggle(parent: Control, test_id: String) -> CheckButton:
	var button := CheckButton.new()
	button.set_meta("test_id", test_id)
	button.custom_minimum_size = Vector2(0, UiTheme.BUTTON_MIN_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_END
	button.focus_mode = Control.FOCUS_NONE
	button.toggled.connect(_on_value_changed.unbind(1))
	parent.add_child(button)
	return button


## Shows the settings. "columns" is 2 in landscape.
func show_settings(settings: Dictionary, columns := 1) -> void:
	_grid.columns = columns
	_quiet = true
	_title.text = Content.ui_text("settings_title")
	_close.text = Content.ui_text("close")
	_invert.text = Content.ui_text("settings_invert")
	_gyro.text = Content.ui_text("settings_gyro")
	_tap_walk.text = Content.ui_text("settings_tap_walk")
	_sensitivity.value = float(settings.look_sensitivity)
	_fov.value = float(settings.fov)
	_invert.button_pressed = bool(settings.invert_y)
	_gyro.button_pressed = bool(settings.gyro)
	_tap_walk.button_pressed = bool(settings.tap_walk)
	_quiet = false
	_update_labels()


func current() -> Dictionary:
	return {
		"look_sensitivity": snappedf(_sensitivity.value, 0.01),
		"invert_y": _invert.button_pressed,
		"gyro": _gyro.button_pressed,
		"fov": _fov.value,
		"tap_walk": _tap_walk.button_pressed,
	}


func _update_labels() -> void:
	_sensitivity_label.text = Content.format(Content.ui_text("settings_sensitivity"),
			{"value": "%.2f" % _sensitivity.value})
	_fov_label.text = Content.format(Content.ui_text("settings_fov"), {"value": "%d°" % int(_fov.value)})


func _on_value_changed() -> void:
	_update_labels()
	if not _quiet:
		changed.emit(current())
