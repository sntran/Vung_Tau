class_name Phone
extends Control
## The phone of the traveler (plan 0003, R16 to R18). It is the only flat
## thing on the screen, with the subtitles and the action button.
##
## A phone button at the bottom right raises the phone. The phone takes the
## right part of the screen, at most 38% of the width. A second tap on the
## button, or a swipe down on the phone, lowers it. The apps ask the main
## scene for each action with the signal "request".

signal request(action: String, args: Dictionary)
signal raised(up: bool)
signal app_changed(app: String)

const APPS := ["listen", "lens", "messages", "notebook", "clock", "settings"]
const MAX_FRACTION := 0.38
const MAX_WIDTH := 560.0
const MARGIN := 12.0
const BUTTON_SIZE := Vector2(150, 88)
const BANNER_SECONDS := 3.0
## A swipe down of this many base pixels lowers the phone.
const SWIPE := 110.0

var up := false
## The open app, or "" for the home screen.
var app := ""
var button: Button
var device: PanelContainer
var apps: Dictionary = {}
## The text of the last notification.
var last_notification := ""
var _dot: Control
var _time: Label
var _title: Label
var _home_button: Button
var _screen: PanelContainer
var _home: GridContainer
var _banner: PanelContainer
var _banner_label: Label
var _banner_left := 0.0
var _swipe_start := Vector2.INF
## The last state of each app. An app builds its controls again only when its state changes.
var _states: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button = Button.new()
	button.name = "PhoneButton"
	button.set_meta("test_id", "phone.button")
	button.theme_type_variation = "PrimaryButton"
	button.focus_mode = Control.FOCUS_NONE
	button.text = Content.ui_text("phone_button")
	button.pressed.connect(toggle)
	add_child(button)
	_dot = Control.new()
	_dot.name = "Dot"
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.draw.connect(func() -> void: _dot.draw_circle(Vector2(9, 9), 9.0, UiTheme.SIGN))
	_dot.size = Vector2(18, 18)
	_dot.position = Vector2(BUTTON_SIZE.x - 22, 4)
	_dot.visible = false
	button.add_child(_dot)
	_build_device()
	device.visible = false


func _build_device() -> void:
	device = PanelContainer.new()
	device.name = "Device"
	device.set_meta("test_id", "phone.device")
	device.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := UiTheme._flat(PhoneUi.DEVICE, 36)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 12
	device.add_theme_stylebox_override("panel", style)
	device.gui_input.connect(_on_device_input)
	add_child(device)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	device.add_child(column)
	var status := HBoxContainer.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(status)
	_time = PhoneUi.label("", "BarLabel", 20)
	_time.name = "StatusTime"
	_time.set_meta("test_id", "phone.time")
	status.add_child(_time)
	var signal_label := PhoneUi.label("▂▄▆ 82%", "BarSmall")
	signal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(signal_label)
	# The banner of a notification is under the status bar. While it shows, it
	# pushes the header and the app down, so it covers nothing (D-0003-07).
	_banner = PanelContainer.new()
	_banner.name = "Banner"
	_banner.set_meta("test_id", "phone.banner")
	_banner.theme_type_variation = "Toast"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	_banner_label = PhoneUi.label("")
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_child(_banner_label)
	column.add_child(_banner)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	_home_button = Button.new()
	_home_button.name = "Home"
	_home_button.set_meta("test_id", "phone.home")
	_home_button.theme_type_variation = "BarButton"
	_home_button.focus_mode = Control.FOCUS_NONE
	_home_button.custom_minimum_size = Vector2(120, UiTheme.BUTTON_MIN_HEIGHT)
	_home_button.text = "‹ " + Content.ui_text("home")
	_home_button.pressed.connect(open_app.bind(""))
	header.add_child(_home_button)
	_title = PhoneUi.label("", "BarLabel", PhoneUi.TITLE_SIZE)
	_title.name = "Title"
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title)
	_screen = PanelContainer.new()
	_screen.name = "Screen"
	_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var screen_style := UiTheme._flat(PhoneUi.SCREEN, 20)
	screen_style.set_content_margin_all(12)
	_screen.add_theme_stylebox_override("panel", screen_style)
	_screen.clip_contents = true
	column.add_child(_screen)
	_home = GridContainer.new()
	_home.name = "HomeScreen"
	_home.columns = 2
	_home.add_theme_constant_override("h_separation", 10)
	_home.add_theme_constant_override("v_separation", 10)
	_screen.add_child(_home)
	var names: Dictionary = Content.ui_dict("apps")
	for app_id: String in APPS:
		var app_button := PhoneUi.button("phone.app." + app_id, names.get(app_id, app_id), "", "Button")
		app_button.custom_minimum_size.y = 96
		app_button.main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		app_button.pressed.connect(open_app.bind(app_id))
		_home.add_child(app_button)
	apps.listen = ListenApp.new()
	apps.lens = LensApp.new()
	apps.messages = MessagesApp.new()
	apps.notebook = NotebookApp.new()
	apps.clock = ClockApp.new()
	apps.settings = SettingsApp.new()
	for app_id: String in apps:
		var page: Control = apps[app_id]
		page.name = "App_" + app_id
		page.set("phone", self)
		page.visible = false
		_screen.add_child(page)


## Places the phone and the button for the size of the view.
func layout(view: Vector2) -> void:
	# The phone node has no size: its children have their own places.
	position = Vector2.ZERO
	size = Vector2.ZERO
	var width := minf(view.x * MAX_FRACTION, MAX_WIDTH)
	device.position = Vector2(view.x - width - MARGIN, MARGIN)
	device.size = Vector2(width, view.y - 2.0 * MARGIN)
	button.size = BUTTON_SIZE
	if up:
		button.position = Vector2(device.position.x - BUTTON_SIZE.x - MARGIN, view.y - BUTTON_SIZE.y - MARGIN)
	else:
		button.position = Vector2(view.x - BUTTON_SIZE.x - MARGIN, view.y - BUTTON_SIZE.y - MARGIN)


## The part of the view that the phone covers (an empty rectangle when it is down).
func covered_rect() -> Rect2:
	return device.get_rect() if up else Rect2()


func toggle() -> void:
	if up:
		lower_phone()
	else:
		raise_phone()


func raise_phone() -> void:
	if up:
		return
	up = true
	device.visible = true
	_show_page()
	raised.emit(true)


func lower_phone() -> void:
	if not up:
		return
	up = false
	device.visible = false
	_swipe_start = Vector2.INF
	raised.emit(false)


func open_app(app_id: String) -> void:
	app = app_id
	_states.erase(app_id)
	_show_page()
	app_changed.emit(app)


func _show_page() -> void:
	_home.visible = app == ""
	for app_id: String in apps:
		apps[app_id].visible = app_id == app
	_home_button.visible = app != ""
	_title.text = Content.ui_dict("apps").get(app, "") if app != "" else ""


## Gives the open app its data (see the "refresh" function of each app).
func refresh(state: Dictionary, force := false) -> void:
	if not up or app == "" or not apps.has(app):
		return
	var key := var_to_str(state)
	if not force and _states.get(app, "") == key:
		return
	_states[app] = key
	apps[app].refresh(state)


func set_time(text: String) -> void:
	_time.text = text


## The dot on the phone button: a new message or a new card (R18).
func set_dot(on: bool) -> void:
	_dot.visible = on
	_dot.queue_redraw()


func has_dot() -> bool:
	return _dot.visible


## A notification: a banner on the phone when it is up, else a short vibration.
func notify(text: String) -> void:
	last_notification = text
	if up:
		_banner_label.text = text
		_banner.visible = true
		_banner_left = BANNER_SECONDS
	else:
		Input.vibrate_handheld(120)


func banner_visible() -> bool:
	return _banner.visible


func _process(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= delta
		if _banner_left <= 0.0:
			_banner.visible = false


func _on_device_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if press and press.button_index == MOUSE_BUTTON_LEFT:
		pressed = press.pressed
		released = not press.pressed
		pos = press.position
	elif touch:
		pressed = touch.pressed
		released = not touch.pressed
		pos = touch.position
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		var at: Vector2 = event.position
		if _swipe_start != Vector2.INF and at.y - _swipe_start.y > SWIPE \
				and absf(at.x - _swipe_start.x) < at.y - _swipe_start.y:
			lower_phone()
		return
	if pressed:
		_swipe_start = pos
	elif released:
		_swipe_start = Vector2.INF


# --- Gamepad (plan 0004, R2) --------------------------------------------------

## The button that the gamepad selected (its index in pad_buttons()).
var _pad_index := -1


## The buttons on the screen of the phone that a player can press now, from
## the top to the bottom.
func pad_buttons() -> Array[BaseButton]:
	var result: Array[BaseButton] = []
	for node: Node in device.find_children("*", "BaseButton", true, false):
		var b := node as BaseButton
		if b.is_visible_in_tree() and not b.disabled:
			result.append(b)
	result.sort_custom(func(a: BaseButton, b: BaseButton) -> bool:
		var pa := a.get_global_rect().position
		var pb := b.get_global_rect().position
		return pa.y < pb.y - 4.0 or (absf(pa.y - pb.y) <= 4.0 and pa.x < pb.x))
	return result


## Moves the selection of the gamepad to the next (+1) or the last (-1) button.
func pad_move(step: int) -> void:
	var buttons := pad_buttons()
	if buttons.is_empty():
		return
	_pad_index = wrapi(_pad_index + step, 0, buttons.size()) if _pad_index >= 0 else (0 if step > 0 else buttons.size() - 1)
	var b := buttons[_pad_index]
	b.focus_mode = Control.FOCUS_ALL
	b.grab_focus()


## The button that the gamepad selected, or null.
func pad_selected() -> BaseButton:
	var focused := get_viewport().gui_get_focus_owner() as BaseButton
	return focused if focused != null and pad_buttons().has(focused) else null


## Presses the selected button.
func pad_press() -> void:
	var b := pad_selected()
	if b == null:
		return
	if b.toggle_mode:
		b.button_pressed = not b.button_pressed
	else:
		b.pressed.emit()
	_pad_index = -1


## B on the gamepad: back to the home screen, or down when the home screen shows.
func pad_back() -> void:
	_pad_index = -1
	if app != "":
		open_app("")
	else:
		lower_phone()
