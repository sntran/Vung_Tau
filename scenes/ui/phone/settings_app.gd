class_name SettingsApp
extends ScrollContainer
## The Settings app (plan 0003, R28): the settings of plan 0002, the sound,
## the subtitle language, the subtitle size, and the opacity of the subtitle box.
## Plan 0004 adds the quality preset, fullscreen, and the mouse speed (R1 to R4).

const SENSITIVITY_RANGE := Vector2(0.25, 2.0)
const FOV_RANGE := Vector2(60.0, 90.0)
const SUBTITLE_SIZE_RANGE := Vector2(1.0, 1.5)

var phone: Phone
var _column: VBoxContainer
var _sensitivity: HSlider
var _sensitivity_label: Label
var _fov: HSlider
var _fov_label: Label
var _size: HSlider
var _size_label: Label
var _box: HSlider
var _box_label: Label
var _invert: CheckButton
var _gyro: CheckButton
var _tap_walk: CheckButton
var _sound: CheckButton
var _subtitles: TextButton
var _center: TextButton
var _quality: TextButton
var _restart_note: Label
var _restart: TextButton
var _fullscreen: CheckButton
var _mouse: HSlider
var _mouse_label: Label
var _preset := "low"
var _language := "vi"
var _quiet := false


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column = PhoneUi.column(8)
	add_child(_column)
	_quality = PhoneUi.button("settings.quality", "")
	_quality.pressed.connect(_next_preset)
	_column.add_child(_quality)
	_restart_note = PhoneUi.label("")
	_restart_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_restart_note)
	_restart = PhoneUi.button("settings.restart", "")
	_restart.pressed.connect(func() -> void: phone.request.emit("restart", {}))
	_column.add_child(_restart)
	_fullscreen = _toggle("settings.fullscreen")
	_sound = _toggle("settings.sound")
	_subtitles = PhoneUi.button("settings.subtitles", "")
	_subtitles.pressed.connect(_next_language)
	_column.add_child(_subtitles)
	var size_row := _slider("settings.subtitle_size", SUBTITLE_SIZE_RANGE, 0.25)
	_size = size_row[0]
	_size_label = size_row[1]
	var box_row := _slider("settings.subtitle_box", Vector2(0.0, 1.0), 0.25)
	_box = box_row[0]
	_box_label = box_row[1]
	var sensitivity := _slider("settings.sensitivity", SENSITIVITY_RANGE, 0.05)
	_sensitivity = sensitivity[0]
	_sensitivity_label = sensitivity[1]
	var mouse := _slider("settings.mouse_sensitivity", SaveFormat.MOUSE_SENSITIVITY_RANGE, 0.05)
	_mouse = mouse[0]
	_mouse_label = mouse[1]
	_invert = _toggle("settings.invert")
	_gyro = _toggle("settings.gyro")
	var fov := _slider("settings.fov", FOV_RANGE, 1.0)
	_fov = fov[0]
	_fov_label = fov[1]
	_tap_walk = _toggle("settings.tap_walk")
	_center = PhoneUi.button("settings.center", "")
	_center.pressed.connect(func() -> void: phone.request.emit("center", {}))
	_column.add_child(_center)


func _slider(test_id: String, value_range: Vector2, step: float) -> Array:
	var label := PhoneUi.label("")
	_column.add_child(label)
	var slider := HSlider.new()
	slider.set_meta("test_id", test_id)
	slider.min_value = value_range.x
	slider.max_value = value_range.y
	slider.step = step
	slider.custom_minimum_size = Vector2(0, UiTheme.BUTTON_MIN_HEIGHT)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_changed.unbind(1))
	_column.add_child(slider)
	return [slider, label]


func _toggle(test_id: String) -> CheckButton:
	var button := CheckButton.new()
	button.set_meta("test_id", test_id)
	button.custom_minimum_size = Vector2(0, UiTheme.BUTTON_MIN_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", PhoneUi.FONT_SIZE)
	button.toggled.connect(_on_changed.unbind(1))
	_column.add_child(button)
	return button


## state.settings, state.sound.
func refresh(state: Dictionary) -> void:
	var settings: Dictionary = state.get("settings", SaveFormat.DEFAULT_SETTINGS)
	_quiet = true
	_sound.text = Content.ui_text("settings_sound")
	_invert.text = Content.ui_text("settings_invert")
	_gyro.text = Content.ui_text("settings_gyro")
	_tap_walk.text = Content.ui_text("settings_tap_walk")
	_center.set_texts(Content.ui_text("center_view"))
	_fullscreen.text = Content.ui_text("settings_fullscreen")
	_restart.set_texts(Content.ui_text("settings_restart"))
	# A phone has no window and no mouse.
	var desktop := not OS.has_feature("mobile") and not OS.has_feature("web")
	_fullscreen.visible = desktop
	_mouse.visible = desktop
	_mouse_label.visible = desktop
	_fullscreen.button_pressed = bool(settings.fullscreen)
	_mouse.value = float(settings.mouse_sensitivity)
	_preset = Quality.valid(settings.quality)
	_sound.button_pressed = bool(state.get("sound", true))
	_sensitivity.value = float(settings.look_sensitivity)
	_fov.value = float(settings.fov)
	_size.value = float(settings.subtitle_size)
	_box.value = float(settings.subtitle_box)
	_invert.button_pressed = bool(settings.invert_y)
	_gyro.button_pressed = bool(settings.gyro)
	_tap_walk.button_pressed = bool(settings.tap_walk)
	_language = settings.subtitles
	_quiet = false
	_update_labels()


func current() -> Dictionary:
	return {
		"look_sensitivity": snappedf(_sensitivity.value, 0.01),
		"invert_y": _invert.button_pressed,
		"gyro": _gyro.button_pressed,
		"fov": _fov.value,
		"tap_walk": _tap_walk.button_pressed,
		"subtitles": _language,
		"subtitle_size": _size.value,
		"subtitle_box": _box.value,
		"quality": _preset,
		"mouse_sensitivity": snappedf(_mouse.value, 0.01),
		"fullscreen": _fullscreen.button_pressed,
	}


func _next_preset() -> void:
	_preset = Quality.NAMES[(Quality.NAMES.find(_preset) + 1) % Quality.NAMES.size()]
	_on_changed()


func _next_language() -> void:
	var languages := SaveFormat.SUBTITLE_LANGUAGES
	_language = languages[(languages.find(_language) + 1) % languages.size()]
	_on_changed()


func _update_labels() -> void:
	_sensitivity_label.text = Content.format(Content.ui_text("settings_sensitivity"),
			{"value": "%.2f" % _sensitivity.value})
	_fov_label.text = Content.format(Content.ui_text("settings_fov"), {"value": "%d°" % int(_fov.value)})
	_size_label.text = Content.format(Content.ui_text("settings_subtitle_size"), {"value": "%d%%" % int(_size.value * 100)})
	_box_label.text = Content.format(Content.ui_text("settings_subtitle_box"), {"value": "%d%%" % int(_box.value * 100)})
	_quality.set_texts(Content.format(Content.ui_text("settings_quality"),
			{"value": Content.ui_dict("quality_presets").get(_preset, _preset)}))
	# A change of renderer needs a restart (R4).
	var restart := Quality.needs_restart(_preset)
	_restart_note.text = Content.ui_text("settings_restart_note") if restart else ""
	_restart_note.visible = restart
	_restart.visible = restart
	_mouse_label.text = Content.format(Content.ui_text("settings_mouse"), {"value": "%.2f" % _mouse.value})
	_subtitles.set_texts(Content.format(Content.ui_text("settings_subtitles"),
			{"value": Content.ui_dict("subtitle_languages").get(_language, _language)}))


func _on_changed() -> void:
	_update_labels()
	if _quiet:
		return
	phone.request.emit("settings", {"settings": current(), "sound": _sound.button_pressed})
