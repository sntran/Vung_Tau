class_name DesktopControls
extends Node
## The controls of a computer (plan 0004, D4, R2, R3): mouse look with a
## captured cursor, E to act, Tab for the phone, Esc for the menu, and a gamepad.
##
## W, A, S, D are in main.gd (plan 0002). Touch controls stay as they are:
## a touch makes mouse events with the device DEVICE_ID_EMULATION, and this
## node does not read them.
##
## A click of a real mouse on the world captures the cursor. Then the mouse
## turns the view, and a click acts on the focus, the same as E. When the
## phone is up, the cursor is free and the mouse uses the apps. Tab, Esc, or
## a right click lowers the phone, and the cursor is captured again.

## A mouse movement of one pixel turns the view this many degrees at mouse speed 1.
const MOUSE_DEG_PER_PIXEL := 0.1
## The right stick turns the view this many degrees each second at look speed 1.
const STICK_DEG_PER_SECOND := 140.0
const STICK_DEADZONE := 0.2

## True after the player captured the cursor one time. Then the cursor is
## captured again when the phone goes down.
var mouse_play := false

var _main: Node
## The device of the last gamepad event.
var _pad_device := 0


func _init(main: Node) -> void:
	_main = main
	name = "DesktopControls"


func _ready() -> void:
	_main.phone.raised.connect(_on_phone_raised)


func captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		_pad_device = event.device
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.device == InputEvent.DEVICE_ID_EMULATION or not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_RIGHT and _main.phone.up:
			_main.phone.lower_phone()
			_handled()
		elif button.button_index == MOUSE_BUTTON_LEFT and captured():
			_main._on_action()
			_handled()
		elif button.button_index == MOUSE_BUTTON_LEFT and not _main.phone.up:
			mouse_play = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_handled()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.device == InputEvent.DEVICE_ID_EMULATION or not captured():
			return
		var speed := float(GameState.settings.mouse_sensitivity) * MOUSE_DEG_PER_PIXEL
		var invert := -1.0 if GameState.settings.invert_y else 1.0
		_main.player.look(-motion.relative.x * speed, -motion.relative.y * speed * invert)
		_handled()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.physical_keycode:
			KEY_E:
				_main._on_action()
				_handled()
			KEY_TAB, KEY_ESCAPE:
				# The phone is the menu of the game: Esc shows its home screen.
				if key.physical_keycode == KEY_ESCAPE and not _main.phone.up:
					_main.phone.open_app("")
				_main.phone.toggle()
				_handled()
	elif event is InputEventJoypadButton:
		var pad := event as InputEventJoypadButton
		if not pad.pressed:
			return
		# With the phone up, the D-pad selects a button, A presses it, and B goes back.
		if _main.phone.up:
			match pad.button_index:
				JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT:
					_main.phone.pad_move(1)
					_handled()
					return
				JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT:
					_main.phone.pad_move(-1)
					_handled()
					return
				JOY_BUTTON_A:
					_main.phone.pad_press()
					_handled()
					return
				JOY_BUTTON_B:
					_main.phone.pad_back()
					_handled()
					return
		match pad.button_index:
			JOY_BUTTON_A:
				_main._on_action()
				_handled()
			JOY_BUTTON_Y:
				_main.phone.toggle()
				_handled()


func _process(delta: float) -> void:
	var look := _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	if look == Vector2.ZERO:
		return
	var speed := float(GameState.settings.look_sensitivity) * STICK_DEG_PER_SECOND * delta
	var invert := -1.0 if GameState.settings.invert_y else 1.0
	_main.player.look(-look.x * speed, -look.y * speed * invert)


## The left stick of the gamepad: x is to the right, y is forward.
func move_stick() -> Vector2:
	var stick := _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	return Vector2(stick.x, -stick.y)


func _stick(axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	var value := Vector2(Input.get_joy_axis(_pad_device, axis_x), Input.get_joy_axis(_pad_device, axis_y))
	var length := value.length()
	if length < STICK_DEADZONE:
		return Vector2.ZERO
	# After the deadzone, the value starts again at 0: a small push gives a slow turn.
	return value / length * clampf((length - STICK_DEADZONE) / (1.0 - STICK_DEADZONE), 0.0, 1.0)


func _on_phone_raised(up: bool) -> void:
	if up and captured():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not up and mouse_play:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _handled() -> void:
	get_viewport().set_input_as_handled()
