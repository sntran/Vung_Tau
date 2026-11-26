extends Node3D
## The main scene: the world in first person, the voices, and the phone.
##
## It reads the touch, mouse, and key input. People speak aloud with
## subtitles (plan 0003). The player answers with the phrasebook of the
## Listen app, in English, or with an action in the world. The phone is the
## only flat thing on the screen.

## The subtitle color of a person that the player does not know yet (D-0003-04).
const UNKNOWN_SPEAKER_COLOR := Color("#5E5E5E")
## A tap is shorter than this and moves less than TAP_SLOP (plan 0002, R8).
const TAP_SECONDS := 0.25
const TAP_SLOP := 12.0
## Tap to walk goes not farther than this (plan 0002, R10).
const TAP_WALK_RANGE := 15.0
## The focus is the touchable object nearest to the center dot, at this distance or less (D8).
const FOCUS_RANGE := 3.0
const FOCUS_ANGLE := 18.0
## A drag of one base pixel turns the view this many degrees at look speed 1.
const LOOK_DEG_PER_PIXEL := 0.2
const ACTION_SIZE := Vector2(180, 88)
## The player hears a voice at this distance or less (plan 0003, R11).
const HEAR_DISTANCE := 12.0
## A talk ends when the player walks farther than this from the person (R15).
const TALK_DISTANCE := 6.0
## A talk with no answer ends after this time.
const TALK_IDLE_SECONDS := 45.0
## The time between the lines of a talk.
const LINE_GAP_SECONDS := 0.5
## The Listen app keeps this many lines.
const TRANSCRIPT_MAX := 50
## The player can sleep at the homestay: at this distance from the door or less.
const HOME_DISTANCE := 5.0
## The bottom left part of the screen, where the left thumb holds the joystick.
## The subtitles stay out of it (R13).
const STICK_ZONE := Vector2(340, 260)
const SUBTITLE_MARGIN := 16.0
## Plan 0018, D13: the name of a road shows this long (s of the clock).
const ROAD_NAME_S := 3.0
## The name changes only while the player moves faster than this (m/s).
const ROAD_NAME_MOVING := 0.3
## Plan 0018, D12: the hint of the first rides (Riding.HINT_RIDES) shows this long (s).
const RIDE_HINT_S := 6.0

## The test ID of the focus ("spot.pho", "npc.batu"), or "".
var focus_id := ""
var focus_verb := ""
## The sensor source of the gyroscope. The play-test system can replace it.
var sensor: SensorSource = SensorSource.new()
## The talk with a person, or empty: {npc, state, line, answer, last, idle, saying, next}.
## "state" is "speaking", "answer" (the person waits for an answer), "phone"
## (the phone speaks a phrase), "saying" (the player says a phrase), or "idle".
var talk: Dictionary = {}
## The lines that the person speaks now: npc ID -> {line, left, heard}.
var speech: Dictionary = {}
## The Listen app writes down what the player hears while it is on (R19).
var listen_on := false
## The lines that the Listen app wrote down: [{speaker, line, vi, en}].
var transcript: Array[Dictionary] = []
## The line ID of the last Lens card, so that a card learns its cards one time.
var lens_line := ""
## True when a card came that the Sổ tay app did not show yet (R18).
var new_card := false
## "hem" (plans 0001 to 0003), or "vung_tau" (plan 0005) with --world=vung_tau.
var world_name := "hem"
## Plan 0009, R16: the time (ms) when the ground of the start was ready, on the web.
var _web_settled_ms := -1
## The real ground of Vũng Tàu, or null in the hẻm world.
var vung_tau: VungTau = null
## The time from the start of the engine to the end of the draw of the first
## frame (ms), or -1 (report 0026, D-0026-12: PT-37 checks the start of the
## Vũng Tàu world).
var first_frame_ms := -1
## Plan 0018, R1: the longest wait for the ground of the start before the clock runs.
const CLOCK_WAIT_S := 60.0
var _clock_wait := 0.0
## The time of the build of the Vũng Tàu world, from the load of its scene to
## its first chunks (ms), or -1.
var world_build_ms := -1
var debug_overlay: Label

@onready var hem: Hem = $World/Hem
@onready var player: Player = $World/Player
@onready var sun: DirectionalLight3D = $World/Sun
@onready var environment: Environment = $World/Environment.environment
@onready var ui_root: Control = $UI/Root
@onready var joystick: Joystick = $UI/Root/Joystick
@onready var center_dot: CenterDot = $UI/Root/CenterDot
@onready var action_button: Button = $UI/Root/ActionButton
## True while the action button is at its place for the scooter (D-0018-02).
var _action_on_scooter := false
## Plan 0018, D12 and D13: the hint of the first rides and the name of the road.
var _hint_note: ScreenNote
var _road_note: ScreenNote
## The name of the last road that the player was on ("" for a road with no name).
var _road_name_last := "-"
## The directions of the stick that the rider used while the hint shows.
var _hint_used := {}
## Plan 0031, R1: the time when the player can move, for the page, and the
## time to the next state for the page.
var _web_can_move_ms := -1
## Plan 0031, D11: the line of the times of the start (the Settings app shows the last line).
var load_times_text := ""
var _times_note: ScreenNote
var _times_shown := false
var _times_left := 0.0
var _times_update := 0.0
var _web_state_left := 0.0
## The kind of the last input: "touch", "keys", or "gamepad" (D12).
var last_input := "keys"
@onready var ting_player: AudioStreamPlayer = $Sounds/Ting
var subtitles: Subtitles
var phone: Phone
## The neutral voice of the phone (the Play button of the Listen app, R21).
var phone_voice: AudioStreamPlayer
var clack_player: AudioStreamPlayer3D
## Mouse look, keys, and the gamepad on a computer (plan 0004).
var desktop: DesktopControls
## Plan 0018: the scooters (get on, get off, the sounds).
var riding: Riding
## Plan 0018, D7: true when the last input was a touch. Then the joystick shows
## at its rest place; an input of the mouse or the keyboard hides it.
var touch_mode := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

## The touches and the mouse press: id -> {start, last, time, zone, active}.
var _touches: Dictionary = {}
var _stick_id: Variant = null
## The pending walk target: {spot} or {npc}.
var _pending: Dictionary = {}
## The time to the next chat line of each person with "chat" or "calls".
var _chat_left: Dictionary = {}
## The next chat of each person who chats, and the day of these values.
var _chat_index: Dictionary = {}
var _chat_day := -1
## The steps that wait: [{seconds, action, args, talk}]. A step of the talk
## ("talk" is true) stops when the talk ends.
var _steps: Array[Dictionary] = []
var _tv_caption_left := 0.0
var _machine_caption_left := 0.0
## True after stop_sounds(): no new sound starts.
var _stopped := false


func _ready() -> void:
	add_to_group("main")
	ui_root.theme = UiTheme.make()
	if DisplayServer.is_touchscreen_available():
		last_input = "touch"
	_road_note = ScreenNote.new()
	_road_note.name = "RoadName"
	ui_root.add_child(_road_note)
	_hint_note = ScreenNote.new()
	_hint_note.name = "RideHint"
	ui_root.add_child(_hint_note)
	_times_note = ScreenNote.new()
	_times_note.name = "LoadTimes"
	ui_root.add_child(_times_note)
	ting_player.stream = Tones.ting()
	action_button.set_meta("test_id", "action")
	action_button.theme_type_variation = "PrimaryButton"
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.pressed.connect(_on_action)
	subtitles = Subtitles.new()
	subtitles.name = "Subtitles"
	ui_root.add_child(subtitles)
	subtitles.text_changed.connect(func() -> void: _layout_subtitles(ui_root.get_viewport_rect().size))
	phone = Phone.new()
	phone.name = "Phone"
	ui_root.add_child(phone)
	phone.apps.lens.source_camera = player.camera
	phone.request.connect(_on_phone_request)
	phone.raised.connect(_on_phone_raised)
	phone.app_changed.connect(_on_app_changed)
	desktop = DesktopControls.new(self)
	add_child(desktop)
	phone_voice = AudioStreamPlayer.new()
	phone_voice.name = "PhoneVoice"
	$Sounds.add_child(phone_voice)
	_make_debug_overlay()
	GameState.time_changed.connect(_on_time_changed)
	GameState.card_learned.connect(_on_card_learned)
	GameState.message_received.connect(_on_message)
	player.stepped.connect(GameState.add_walk)
	player.arrived.connect(_on_arrived)
	player.blocked.connect(_on_blocked)
	AudioServer.set_bus_mute(0, not GameState.sound)
	RenderingServer.frame_post_draw.connect(func() -> void:
		if first_frame_ms < 0:
			first_frame_ms = Time.get_ticks_msec()
			# Plan 0009, R16: the page knows the first frame of the world.
			if OS.has_feature("web"):
				# The object keeps what the game gave before (the packs of plan 0031, D5).
				JavaScriptBridge.eval("window.vungTau = window.vungTau || {}; window.vungTau.world = '%s'; window.vungTau.firstFrameMs = %d; window.vungTau.mark && window.vungTau.mark('firstFrame')" % [world_name, first_frame_ms], true)
			# Plan 0031, D5: the test of a second pack, after the first frame.
			if GameState.has_arg("packtest"):
				add_child.call_deferred(WebPackTest.new()), CONNECT_ONE_SHOT)
	# Plan 0031, D5: the packs of the web build that come while the game runs.
	# Plan 0031, D14: a play test on a computer can keep the pack "models" out (--packs-sim).
	if OS.has_feature("web") or GameState.has_arg("packs-sim"):
		add_child(WebPacks.new(player))
	if GameState.arg_value("world") == "vung_tau":
		_start_vung_tau()
	if vung_tau == null:
		clack_player = AudioStreamPlayer3D.new()
		clack_player.name = "Clack"
		clack_player.stream = Tones.clack()
		clack_player.max_distance = float(Content.sound("clack").get("range_m", 25.0))
		clack_player.unit_size = 4.0
		hem.helper.add_child(clack_player)
		clack_player.position = Vector3(0.3, 1.0, 0.15)
		hem.clacked.connect(_on_clacked)
		# Report 0009, D-0009-26: a cart does not come where the player stands.
		hem.player_at = func() -> Vector3: return player.global_position
		for npc: Dictionary in Content.npc_list():
			for field: String in ["chat", "calls"]:
				if npc.has(field):
					_chat_left[npc.id] = randf_range(2.0, 6.0)
		player.place(GameState.player_pos, GameState.yaw, GameState.pitch)
	riding = Riding.new(self)
	add_child(riding)
	riding.setup()
	_apply_settings()
	_layout()
	_apply_time(GameState.minutes)
	if not GameState.flag("intro_done"):
		GameState.set_flag("intro_done")
		check_messages("start")
	check_messages()
	_update_dot()


## Plan 0005: the real ground in place of the hẻm. The hẻm world, its sun,
## and its sky go. The save of the hẻm world stays as it is.
func _start_vung_tau() -> void:
	var begin := Time.get_ticks_msec()
	var world: VungTau = load("res://scenes/world/vung_tau.tscn").instantiate()
	$World.add_child(world)
	if not world.setup():
		world.queue_free()
		return
	vung_tau = world
	world_name = "vung_tau"
	for node: Node in [$World/Hem, $World/Sun, $World/Environment]:
		node.queue_free()
	$World.remove_child($World/Hem)
	hem = null
	sun = world.sun
	environment = world.environment
	player.use_navigation = false
	player.walk_limit = world.can_stand
	# The land of the mainland on the horizon is 15 km to 32 km away (report 0009, Q14).
	player.camera.far = 40000.0
	var start := world.spawn(GameState.arg_value("start"))
	# The parts of the showcase build in the first frames (report 0026, D-0026-12).
	world.prepare_at(start.position, 64.0, false)
	player.place(start.position, start.yaw)
	world_build_ms = Time.get_ticks_msec() - begin


## Stops all sounds. An Ogg stream that still plays when the game quits is
## not freed, so the play-test system calls this some frames before it quits.
func stop_sounds() -> void:
	_stopped = true
	phone_voice.stop()
	phone_voice.stream = null
	ting_player.stop()
	if hem == null:
		return
	for npc: Npc in hem.npcs.values():
		npc.voice.stop()
		npc.voice.stream = null
	clack_player.stop()
	hem.tv.stop()


func _process(delta: float) -> void:
	# Plan 0018, R1: the clock runs from the first frame of the world, and in
	# the Vũng Tàu world when the ground of the start is ready (or after
	# CLOCK_WAIT_S of frames, so that a world that never settles does not stop it).
	if not GameState.clock_running and first_frame_ms >= 0:
		_clock_wait += delta
		if vung_tau == null or vung_tau.is_settled() or _clock_wait > CLOCK_WAIT_S:
			GameState.clock_running = true
	# Plan 0009, R16: the page knows when the ground of the start is ready.
	if _web_settled_ms < 0 and vung_tau != null and OS.has_feature("web") and first_frame_ms >= 0 and vung_tau.is_settled():
		_web_settled_ms = Time.get_ticks_msec()
		JavaScriptBridge.eval("window.vungTau.settledMs = %d" % _web_settled_ms, true)
	if OS.has_feature("web") and first_frame_ms >= 0:
		_update_web_state(delta)
	_layout()
	_update_rest_stick()
	_read_keys()
	_read_gyro(delta)
	_update_focus()
	_update_road_name(delta)
	_update_ride_hint(delta)
	_update_speech(delta)
	_update_talk(delta)
	_update_chats(delta)
	_update_sounds(delta)
	_refresh_phone()
	_update_debug_overlay()
	# The Vũng Tàu world does not save the position: the save is for the hẻm world.
	if vung_tau != null:
		return
	GameState.player_pos = player.global_position
	GameState.yaw = player.target_yaw
	GameState.pitch = player.target_pitch


# --- Input ---------------------------------------------------------------

## W, A, S, D, the arrow keys, and the left stick of a gamepad move the player
## (plan 0002, R11, and plan 0004, R2).
func _read_keys() -> void:
	if _stick_id != null:
		return
	var keys := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		keys.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		keys.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		keys.x += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		keys.x -= 1.0
	var from_keys := keys != Vector2.ZERO
	keys += desktop.move_stick()
	var was_moving := player.move_input.length() > 0.0
	if player.is_riding():
		# Plan 0018, D8: on a scooter the right trigger is the throttle and the left trigger the brake.
		keys.y += desktop.triggers()
		# D10, D11: W is the full stick up and D the full stick to the side,
		# also together (each part from -1 to 1).
		player.move_input = keys.clamp(Vector2(-1, -1), Vector2(1, 1))
	else:
		player.move_input = keys.limit_length(1.0)
	player.move_from_keys = from_keys
	if was_moving and keys == Vector2.ZERO:
		_save_position()


func _read_gyro(delta: float) -> void:
	if not GameState.settings.gyro or not sensor.has_data():
		return
	var turn := sensor.turn(delta)
	player.gyro_yaw += rad_to_deg(turn.x)
	player.gyro_pitch = clampf(player.gyro_pitch + rad_to_deg(turn.y),
			-Player.PITCH_LIMIT, Player.PITCH_LIMIT)


## Puts the gyroscope reference back: the view looks where the drags put it, level.
func center_view() -> void:
	player.gyro_yaw = 0.0
	player.gyro_pitch = 0.0
	player.target_pitch = 0.0


## Plan 0018, D7: the kind of the last input. A touch shows the joystick at its
## rest place; a key, a click of a real mouse, or a gamepad button hides it.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_mode = true
		last_input = "touch"
	elif (event is InputEventKey and event.pressed) or event is InputEventJoypadButton:
		touch_mode = false
		last_input = "keys" if event is InputEventKey else "gamepad"
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		last_input = "gamepad"
	elif event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		touch_mode = false
		last_input = "keys"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		else:
			_release(touch.index, touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_move(drag.index, drag.position, drag.relative)
	elif event is InputEventMouseButton:
		# A touch also makes a mouse event (touch-to-mouse emulation). Read only real mouse events.
		var button := event as InputEventMouseButton
		if button.device == InputEvent.DEVICE_ID_EMULATION or button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_press("mouse", button.position)
		else:
			_release("mouse", button.position)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.device == InputEvent.DEVICE_ID_EMULATION or not _touches.has("mouse"):
			return
		_move("mouse", motion.position, motion.relative)


## A touch on the world. The phone takes its own touches first, so the
## joystick and the look work while the phone is up (D7).
func _press(id: Variant, pos: Vector2) -> void:
	var view := ui_root.get_viewport_rect().size
	# The mouse always turns the view. A touch on the left half is the joystick.
	var zone := "look"
	if typeof(id) == TYPE_INT and pos.x < view.x / 2.0:
		zone = "stick"
	_touches[id] = {"start": pos, "last": pos, "time": Time.get_ticks_msec(), "zone": zone, "active": false}


func _move(id: Variant, pos: Vector2, relative: Vector2) -> void:
	if not _touches.has(id):
		return
	var t: Dictionary = _touches[id]
	t.last = pos
	var moved := pos.distance_to(t.start)
	var held: float = (Time.get_ticks_msec() - int(t.time)) / 1000.0
	if not t.active and (moved > TAP_SLOP or held > TAP_SECONDS):
		t.active = true
		# The movement before the drag started counts too.
		relative = pos - t.start
		# A joystick touch or a look drag stops a tap walk (R9).
		_stop_walk()
		if t.zone == "stick":
			_stick_id = id
			joystick.show_at(t.start)
	if not t.active:
		return
	if t.zone == "stick":
		var offset: Vector2 = (pos - t.start) / Joystick.RADIUS
		joystick.set_knob(offset)
		player.move_input = Vector2(offset.x, -offset.y).limit_length(1.0)
		player.move_from_keys = false
	else:
		var sensitivity := float(GameState.settings.look_sensitivity) * LOOK_DEG_PER_PIXEL
		var invert := -1.0 if GameState.settings.invert_y else 1.0
		player.look(-relative.x * sensitivity, -relative.y * sensitivity * invert)


func _release(id: Variant, pos: Vector2) -> void:
	if not _touches.has(id):
		return
	var t: Dictionary = _touches[id]
	_touches.erase(id)
	if _stick_id == id:
		_stick_id = null
		joystick.hide_stick()
		player.move_input = Vector2.ZERO
		_save_position()
	if t.active:
		if t.zone == "look":
			_save_position()
		return
	var held: float = (Time.get_ticks_msec() - int(t.time)) / 1000.0
	if held <= TAP_SECONDS and pos.distance_to(t.start) <= TAP_SLOP:
		tap_world(pos)


func _stop_walk() -> void:
	if player.walking:
		player.stop()
		_pending = {}
		_save_position()


func _save_position() -> void:
	if vung_tau != null:
		return
	GameState.set_player_pos(player.global_position, player.target_yaw, player.target_pitch)


## Returns what is under the screen point: a dictionary with "kind" ("spot",
## "npc", "floor", or "") and "id" and "position". The player has no body on
## any layer, so it never stops a tap.
func pick(screen_pos: Vector2) -> Dictionary:
	var camera := player.camera
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 600.0,
			Layers.FLOOR | Layers.TOUCH | Layers.SOLID | Layers.MOVING)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"kind": ""}
	var collider: Object = hit.collider
	if collider.has_meta("spot_id"):
		return {"kind": "spot", "id": collider.get_meta("spot_id"), "position": hit.position,
				"node": collider}
	if collider.has_meta("npc_id"):
		return {"kind": "npc", "id": collider.get_meta("npc_id"), "position": hit.position,
				"node": collider}
	return {"kind": "floor", "position": hit.position, "node": collider}


## A tap on the world: an answer by action (R1), or a walk to a spot, a
## person, or a point on the ground (plan 0002, D6).
func tap_world(screen_pos: Vector2) -> void:
	var hit := pick(screen_pos)
	if hit.kind in ["spot", "npc"] and try_action("%s.%s" % [hit.kind, hit.id]):
		return
	if not GameState.settings.tap_walk:
		return
	match hit.kind:
		"spot":
			walk_to(hem.stand_points[hit.id], {"spot": hit.id})
		"npc":
			walk_to(hem.npc_stand_points[hit.id], {"npc": hit.id})
		"floor":
			walk_to(hit.position, {})


## Walks to the point. When the point is more than 15 m away, the player
## walks 15 m in its direction, and the talk does not start (R10).
func walk_to(point: Vector3, target: Dictionary) -> void:
	var from := player.global_position
	var flat := Vector3(point.x - from.x, 0, point.z - from.z)
	if flat.length() > TAP_WALK_RANGE:
		point = from + flat.normalized() * TAP_WALK_RANGE
		target = {}
	_pending = target
	player.walk_to(point)


func _on_arrived() -> void:
	_save_position()
	var target := _pending
	_pending = {}
	if target.has("npc"):
		start_talk(target.npc)


# --- Focus and the action button --------------------------------------------

## Finds the focus: the touchable object nearest to the center dot, at 3 m or less.
func _update_focus() -> void:
	# Plan 0018, D7: while the player rides, the action button is "Get off".
	if player.is_riding():
		focus_id = "ride"
		focus_verb = Riding.verb("scooter_get_off")
		center_dot.set_active(false)
		action_button.visible = true
		action_button.text = focus_verb
		_place_action_button(true)
		return
	_place_action_button(false)
	var best := ""
	var best_angle := FOCUS_ANGLE
	if hem == null:
		_focus_scooter("")
		return
	var eye := player.eye_position()
	var forward := player.view_forward()
	for spot: Dictionary in Content.spot_list():
		if not hem.is_present(spot.id, GameState.minutes):
			continue
		var angle := _focus_angle(eye, forward, hem.focus_points[spot.id])
		if angle < best_angle:
			best_angle = angle
			best = "spot." + spot.id
	for npc_id: String in hem.npcs:
		var npc: Npc = hem.npcs[npc_id]
		if not npc.visible or not npc.touchable:
			continue
		# A look at the face, the chest, or the hips of a person: in a narrow
		# hẻm (plan 0004, R11a) people stand near, and the face alone is high.
		var angle := 999.0
		for y: float in [npc.height - 0.2, npc.height * 0.65, npc.height * 0.45]:
			angle = minf(angle, _focus_angle(eye, forward, npc.global_position + Vector3(0, y, 0)))
		if angle < best_angle:
			best_angle = angle
			best = "npc." + npc_id
	_focus_scooter(best)


## The focus, or a parked scooter that the player looks at within 2 m when
## nothing else has the focus (plan 0018, R4: the action "Ride").
func _focus_scooter(best: String) -> void:
	focus_id = best
	focus_verb = _verb_for(best)
	if best == "" and riding != null:
		var scooter := riding.looked_at()
		if scooter >= 0:
			focus_id = "scooter.%d" % scooter
			focus_verb = Riding.verb("scooter_ride")
	center_dot.set_active(focus_id != "")
	action_button.visible = focus_verb != ""
	action_button.text = focus_verb


## The text of the action button for the focus: an answer by action, "Talk"
## for a person, or the verb of the spot ("Rest" at the homestay).
func _verb_for(target: String) -> String:
	if target == "":
		return ""
	var answer := _action_for(target)
	if not answer.is_empty():
		return answer.verb
	var parts := target.split(".")
	if parts[0] == "npc":
		if not talk.is_empty() and talk.npc == parts[1] and talk.state != "idle":
			return ""
		return Content.npc(parts[1]).get("verb", "")
	return Content.spot(parts[1]).get("verb", "")


func _focus_angle(eye: Vector3, forward: Vector3, point: Vector3) -> float:
	var to := point - eye
	var distance := to.length()
	if distance > FOCUS_RANGE or distance < 0.01:
		return 999.0
	return rad_to_deg(forward.angle_to(to))


func _on_action() -> void:
	if focus_id == "":
		return
	_stop_walk()
	# Plan 0018: get off, or get on the scooter in the focus.
	if focus_id == "ride":
		riding.get_off()
		return
	if focus_id.begins_with("scooter."):
		riding.ride(int(focus_id.get_slice(".", 1)))
		_update_focus()
		return
	if try_action(focus_id):
		return
	var parts := focus_id.split(".")
	if parts[0] == "npc":
		start_talk(parts[1])
	elif parts[1] == "home":
		phone.raise_phone()
		phone.open_app("clock")


# --- Speech ----------------------------------------------------------------

## The person speaks the line: the audio plays at the head, and the subtitle
## shows when the player hears it (R11, R12).
func speak(npc_id: String, line_id: String) -> void:
	var npc: Npc = hem.npcs.get(npc_id)
	if npc == null or _stopped:
		return
	var line := Content.line(line_id)
	npc.voice.stop()
	npc.voice.stream = Content.clip_stream(line_id)
	if npc.voice.stream:
		npc.voice.play()
	var seconds := Content.clip_duration(line_id)
	var heard := can_hear(npc)
	speech[npc_id] = {"line": line_id, "left": seconds, "heard": heard}
	if heard:
		_on_heard(npc_id, line_id, line, seconds)


## True when the player hears the person: the person is there, at 12 m or less.
func can_hear(npc: Npc) -> bool:
	return npc.visible and player.eye_position().distance_to(npc.head_position()) <= HEAR_DISTANCE


func _on_heard(npc_id: String, line_id: String, line: Dictionary, seconds: float) -> void:
	if line.has("introduces"):
		GameState.meet(line.introduces)
	# The subtitle names only a person that the player knows (D-0003-04).
	var speaker := Content.speaker(line.speaker)
	var known := GameState.has_met(line.speaker)
	var shown_name: String = speaker.name if known else Content.string("someone")
	var color := Color(speaker.color) if known else UNKNOWN_SPEAKER_COLOR
	subtitles.show_line(line_id, shown_name, color, line.vi, line.en, GameState.settings.subtitles, seconds)
	if listen_on:
		transcript.append({"speaker": line.speaker, "line": line_id, "vi": line.vi, "en": line.en})
		# The transcript keeps the newest lines only, so that the phone stays fast (D-0003-03).
		if transcript.size() > TRANSCRIPT_MAX:
			transcript = transcript.slice(transcript.size() - TRANSCRIPT_MAX)
	for card_id: String in line.get("learn", []):
		GameState.learn(card_id)
	check_messages("heard:" + line_id)


## The person stops the line at once. The line does not finish, so the talk does not go on.
func _stop_line(npc_id: String) -> void:
	if not speech.has(npc_id):
		return
	var item: Dictionary = speech[npc_id]
	hem.npcs[npc_id].voice.stop()
	if subtitles.current.get("line_id", "") == item.line:
		subtitles.clear()
	speech.erase(npc_id)


func _update_speech(delta: float) -> void:
	for npc_id: String in speech.keys():
		var item: Dictionary = speech[npc_id]
		item.left -= delta
		var npc: Npc = hem.npcs[npc_id]
		# The subtitle stops when the player walks out of hearing.
		if item.heard and not can_hear(npc) and subtitles.current.get("line_id", "") == item.line:
			subtitles.clear()
			item.heard = false
		if item.left <= 0.0:
			npc.voice.stop()
			speech.erase(npc_id)
			_on_line_finished(npc_id, item.line)


## True while the person speaks (the play tests read this).
func is_speaking(npc_id: String) -> bool:
	return speech.has(npc_id)


func _on_line_finished(npc_id: String, line_id: String) -> void:
	var line := Content.line(line_id)
	var in_talk: bool = not talk.is_empty() and talk.npc == npc_id and talk.state == "speaking" and talk.line == line_id
	if line.has("then"):
		var next_speaker: String = Content.line(line.then).speaker
		_wait_then(LINE_GAP_SECONDS, "speak", {"npc": next_speaker, "line": line.then}, in_talk)
	if not in_talk:
		return
	talk.last = line_id
	talk.idle = 0.0
	if talk.get("after_intro", "") != "":
		talk.line = talk.after_intro
		talk.after_intro = ""
		_wait_then(LINE_GAP_SECONDS, "speak", {"npc": npc_id, "line": talk.line})
	elif line.has("then"):
		talk.line = line.then
	elif not line.get("replies", []).is_empty() or not line.get("actions", []).is_empty():
		talk.state = "answer"
		talk.answer = line_id
	else:
		talk.state = "idle"


# --- Talk ------------------------------------------------------------------

## Starts a talk with the person: the person turns to the player and speaks
## the line for the time.
func start_talk(npc_id: String) -> void:
	var npc_data := Content.npc(npc_id)
	if npc_data.is_empty() or not npc_data.get("talk", true) or not hem.npcs.has(npc_id):
		return
	# A talk that waits for an answer goes on. After the end of a talk, a tap starts it again.
	if not talk.is_empty() and talk.npc == npc_id and talk.state != "idle":
		return
	end_talk(false)
	var rule := Content.rule_for(npc_data, "lines", GameState.minutes)
	if rule.is_empty():
		return
	for card_id: String in rule.get("learn", []):
		GameState.learn(card_id)
	hem.npcs[npc_id].face(player.global_position)
	_turn_to(hem.npcs[npc_id].head_position())
	# In the first talk, the person says who they are, then the line for the
	# time. The player knows the name from that line on (D-0003-04).
	var first: String = rule.line
	var after_intro := ""
	if not GameState.has_met(npc_id) and npc_data.has("intro"):
		first = npc_data.intro
		after_intro = rule.line
	talk = {"npc": npc_id, "state": "speaking", "line": first, "answer": "", "last": first,
			"idle": 0.0, "saying": {}, "after_intro": after_intro}
	speak(npc_id, first)


## Turns the view of the player to the point (the face of the person in a talk).
func _turn_to(point: Vector3) -> void:
	var to := point - player.eye_position()
	var yaw := rad_to_deg(atan2(-to.x, -to.z)) - player.gyro_yaw
	player.target_yaw += wrapf(yaw - player.target_yaw, -180.0, 180.0)
	player.target_pitch = clampf(rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length())) - player.gyro_pitch,
			-Player.PITCH_LIMIT, Player.PITCH_LIMIT)


## Ends the talk. When the player walks away before the talk ends, the person
## can call after the player with a short line (R15).
func end_talk(walked_away: bool) -> void:
	if talk.is_empty():
		return
	var npc_id: String = talk.npc
	var state: String = talk.state
	talk = {}
	_steps = _steps.filter(func(step: Dictionary) -> bool: return not step.talk)
	if walked_away and state in ["speaking", "answer", "saying"]:
		var call: String = Content.speaker(npc_id).get("call_after", "")
		if call != "":
			speak(npc_id, call)


func _update_talk(delta: float) -> void:
	var due: Array[Dictionary] = []
	for step in _steps:
		step.seconds -= delta
		if step.seconds <= 0.0:
			due.append(step)
	for step in due:
		_steps.erase(step)
		_do_step(step.action, step.args)
	if talk.is_empty():
		return
	var npc: Npc = hem.npcs[talk.npc]
	var flat := npc.global_position - player.global_position
	if Vector2(flat.x, flat.z).length() > TALK_DISTANCE or not npc.visible:
		end_talk(true)
		return
	if talk.state in ["answer", "idle"]:
		talk.idle += delta
		if talk.idle > TALK_IDLE_SECONDS:
			end_talk(false)


func _wait_then(seconds: float, action: String, args: Dictionary, in_talk := true) -> void:
	_steps.append({"seconds": seconds, "action": action, "args": args, "talk": in_talk})


func _do_step(action: String, args: Dictionary) -> void:
	match action:
		"speak":
			speak(args.npc, args.line)
		"answer":
			_answer(args.line)


## The person answers with the line, in the talk.
func _answer(line_id: String) -> void:
	if talk.is_empty():
		return
	talk.state = "speaking"
	talk.line = line_id
	talk.saying = {}
	speak(talk.npc, line_id)


## Returns the reply of the answer line with the ID, or the "say again" phrase.
func _reply(reply_id: String) -> Dictionary:
	if talk.is_empty():
		return {}
	if reply_id == "say_again":
		var phrase := Content.say_again(talk.npc)
		# While the person speaks, "say again" asks for the line that the person says now.
		var again: String = talk.line if talk.state == "speaking" else talk.last
		return {"id": "say_again", "vi": phrase.vi, "en": phrase.en, "next": again}
	if talk.state != "answer":
		return {}
	for reply: Dictionary in Content.line(talk.answer).get("replies", []):
		if reply.id == reply_id:
			return reply
	return {}


## The player answers with a phrase (R21). "mode" is "play" (the phone
## speaks it), "said" (the player says it), or "english".
func reply(reply_id: String, mode: String) -> bool:
	var entry := _reply(reply_id)
	if entry.is_empty():
		return false
	# "Say again" while the person speaks: the person stops, so that the phone
	# voice does not play over the voice of the person (D-0003-02).
	if reply_id == "say_again" and talk.state == "speaking":
		_stop_line(talk.npc)
	for card_id: String in entry.get("learn", []):
		GameState.learn(card_id)
	talk.idle = 0.0
	var next: String = entry.get("next", "")
	match mode:
		"english":
			if next != "":
				_answer(next)
			else:
				talk.state = "idle"
		"play":
			talk.state = "phone"
			var clip_id := VoiceClips.say_again_id(talk.npc) if reply_id == "say_again" \
					else VoiceClips.reply_id(talk.answer, reply_id)
			phone_voice.stream = Content.clip_stream(clip_id)
			if phone_voice.stream:
				phone_voice.play()
			if next != "":
				_wait_then(Content.clip_duration(clip_id) + LINE_GAP_SECONDS, "answer", {"line": next})
			else:
				talk.state = "idle"
		"said":
			talk.state = "saying"
			talk.saying = entry
	return true


## The player said the phrase of "I'll say it". The person answers in a warmer way (R21).
func said_done() -> void:
	if talk.is_empty() or talk.state != "saying":
		return
	var entry: Dictionary = talk.saying
	var next: String = entry.get("next_said", entry.get("next", ""))
	if next == "":
		talk.state = "idle"
		talk.saying = {}
		return
	_wait_then(LINE_GAP_SECONDS, "answer", {"line": next})
	talk.saying = {}
	talk.state = "phone"


## Returns the answer by action of the talk for the target, or empty.
func _action_for(target: String) -> Dictionary:
	if talk.is_empty() or talk.state != "answer":
		return {}
	for entry: Dictionary in Content.line(talk.answer).get("actions", []):
		if entry.target == target:
			return entry
	return {}


## An answer by action in the world (D8): the target is the test ID of the
## spot or the person. Returns true when the talk had this action.
func try_action(target: String) -> bool:
	var entry := _action_for(target)
	if entry.is_empty():
		return false
	_stop_walk()
	for card_id: String in entry.get("learn", []):
		GameState.learn(card_id)
	_answer(entry.next)
	return true


## The people who call out (Cô Út) speak each "every_s" seconds. The people
## who chat with other people (the neighbors at the cà phê cóc) have a list
## of chats: each chat plays one time each day, in order, "every_s" seconds
## after the last one. Then they sit quietly (D-0003-03).
func _update_chats(delta: float) -> void:
	if hem == null:
		return
	if _chat_day != GameState.day:
		_chat_day = GameState.day
		_chat_index.clear()
	for npc_id: String in _chat_left:
		var npc: Npc = hem.npcs.get(npc_id)
		if npc == null or not npc.visible:
			continue
		if not talk.is_empty() and talk.npc == npc_id:
			continue
		var data := Content.npc(npc_id)
		var chat: Dictionary = data.get("chat", data.get("calls", {}))
		var lines: Array = chat.get("lines", [chat.get("line", "")])
		if lines.any(func(line_id: String) -> bool: return _chat_busy(line_id)):
			continue
		var index: int = _chat_index.get(npc_id, 0)
		if chat.has("lines") and index >= lines.size():
			continue
		_chat_left[npc_id] -= delta
		if _chat_left[npc_id] <= 0.0:
			_chat_left[npc_id] = float(chat.every_s)
			if chat.has("lines"):
				_chat_index[npc_id] = index + 1
				speak(npc_id, lines[index])
			else:
				speak(npc_id, chat.line)


## True while a line of the chat that starts with the line plays or waits.
func _chat_busy(first_line: String) -> bool:
	var chain := {}
	var line_id := first_line
	while line_id != "" and not chain.has(line_id):
		chain[line_id] = true
		line_id = Content.line(line_id).get("then", "")
	for npc_id: String in speech:
		if chain.has(speech[npc_id].line):
			return true
	for step in _steps:
		if chain.has(step.args.get("line", "")):
			return true
	return false


# --- Sounds ----------------------------------------------------------------

func _on_clacked(position_3d: Vector3) -> void:
	if _stopped:
		return
	clack_player.play()
	var sound := Content.sound("clack")
	if player.eye_position().distance_to(position_3d) <= float(sound.get("range_m", 25.0)):
		subtitles.show_caption(sound.get("caption", ""))


## The caption of the TV upstairs shows from time to time while the player hears it (R14).
func _update_sounds(delta: float) -> void:
	_tv_caption_left -= delta
	_update_machine_caption(delta)
	if hem == null or not hem.tv.playing or _tv_caption_left > 0.0:
		return
	var sound := Content.sound("tv")
	if player.eye_position().distance_to(hem.tv.global_position) <= float(sound.get("range_m", 8.0)):
		subtitles.show_caption(sound.get("caption", ""))
		_tv_caption_left = 6.0


## The caption of the roadworks machines shows from time to time while the
## player hears them (plan 0005, R11a).
func _update_machine_caption(delta: float) -> void:
	_machine_caption_left -= delta
	if vung_tau == null or vung_tau.roadworks == null or _machine_caption_left > 0.0:
		return
	var machine := vung_tau.roadworks.machine
	if not machine.playing:
		return
	var sound := Content.sound("machine")
	if player.eye_position().distance_to(machine.global_position) <= float(sound.get("range_m", 40.0)):
		subtitles.show_caption(sound.get("caption", ""))
		_machine_caption_left = 8.0


# --- Messages and notifications ----------------------------------------------

## Sends the messages of cô Nga that are due. "event" is "", "start",
## "wake", "heard:LINE", or "lens:LINE" (R24).
func check_messages(event := "") -> void:
	for message: Dictionary in Content.message_list():
		var repeat: bool = message.get("repeat", false)
		if GameState.has_message(message.id, repeat):
			continue
		if message.has("day") and GameState.day != int(message.day):
			continue
		if message.has("unless_card") and GameState.knows(message.unless_card):
			continue
		if message.has("after"):
			if message.after != event:
				continue
		elif message.has("at"):
			if GameState.minutes < int(message.at) or GameState.minutes >= int(message.get("before", 1440)):
				continue
		var text := Content.format(message.text, {"day": GameState.day,
				"time": GameClock.format_time(GameState.minutes)})
		GameState.add_message(message.id, text)


func _on_message(message: Dictionary) -> void:
	var sender := Content.sender()
	phone.notify(Content.format(Content.ui_text("notify_message"), {"name": sender.get("name", ""),
			"text": message.text}))
	ting_player.play()
	if phone.up and phone.app == "messages":
		GameState.read_messages()
	_update_dot()


func _on_card_learned(card_id: String) -> void:
	var card := Content.card(card_id)
	phone.notify(Content.format(Content.ui_text("notify_card"), {"title": card.title}))
	ting_player.play()
	new_card = not (phone.up and phone.app == "notebook")
	_update_dot()


func _update_dot() -> void:
	phone.set_dot(GameState.unread > 0 or new_card)


# --- The phone ---------------------------------------------------------------

func _on_phone_raised(_up: bool) -> void:
	_on_app_changed(phone.app)


func _on_app_changed(app: String) -> void:
	if not phone.up:
		return
	if app == "messages":
		GameState.read_messages()
	elif app == "notebook":
		new_card = false
	_update_dot()


func _on_phone_request(action: String, args: Dictionary) -> void:
	match action:
		"listen":
			listen_on = bool(args.on)
		"reply":
			reply(args.id, args.mode)
		"said_done":
			said_done()
		"save_phrase":
			var index := int(args.index)
			if index >= 0 and index < transcript.size():
				var entry: Dictionary = transcript[index]
				if GameState.save_phrase(entry.vi, entry.en):
					phone.notify(Content.format(Content.ui_text("phrase_saved"), {"vi": entry.vi}))
		"rest":
			_rest(args.choice)
		"settings":
			GameState.set_settings(args.settings)
			if bool(args.sound) != GameState.sound:
				GameState.set_sound(bool(args.sound))
				AudioServer.set_bus_mute(0, not GameState.sound)
			_apply_settings()
		"center":
			center_view()


## A choice of the Clock app: wait, or sleep until morning (R27).
func _rest(choice: Dictionary) -> void:
	_stop_walk()
	end_talk(false)
	if choice.get("sleep", false):
		if is_at_home():
			sleep_until_morning()
		return
	var target := GameClock.wait_target(choice, GameState.minutes)
	if target >= 0:
		GameState.set_minutes(target)


func is_at_home() -> bool:
	if hem == null:
		return false
	var flat := player.global_position - GameState.HOME_DOOR
	return Vector2(flat.x, flat.z).length() <= HOME_DISTANCE


## The next day: the player is at the homestay door and looks along the hẻm (plan 0001, R4).
func sleep_until_morning() -> void:
	_stop_walk()
	end_talk(false)
	GameState.sleep_until_morning()
	if vung_tau != null:
		return
	player.place(GameState.player_pos, GameState.yaw, GameState.pitch)
	center_view()
	check_messages("wake")


## The data of the open app.
func phone_state() -> Dictionary:
	match phone.app:
		"listen":
			return {"listen_on": listen_on, "transcript": transcript_view(), "talk": phrasebook()}
		"lens":
			return {"lens": lens_card()}
		"messages":
			return {"messages": GameState.messages, "sender": Content.sender()}
		"notebook":
			return {"cards": GameState.cards, "phrases": GameState.phrases}
		"clock":
			return {"minutes": GameState.minutes, "day": GameState.day, "at_home": is_at_home()}
		"settings":
			return {"settings": GameState.settings, "sound": GameState.sound, "load_times": load_times_text}
	return {}


func _refresh_phone() -> void:
	phone.set_time(GameClock.format_time(GameState.minutes))
	if phone.up:
		phone.refresh(phone_state())
	if phone.up and phone.app == "lens":
		_learn_from_lens()


## The transcript as the Listen app shows it: the speaker name only after the
## player has met that person (R19).
func transcript_view() -> Array:
	var result := []
	for entry in transcript:
		var speaker_name: String = Content.speaker(entry.speaker).name if GameState.has_met(entry.speaker) \
				else Content.string("someone")
		result.append({"speaker": speaker_name, "vi": entry.vi, "en": entry.en})
	return result


## The phrasebook of the talk (R20, R21): the replies of the line that waits
## for an answer, and always the "say again" phrase.
func phrasebook() -> Dictionary:
	if talk.is_empty():
		return {}
	var result := {"say_again": Content.say_again(talk.npc), "replies": []}
	if talk.state == "saying":
		result.saying = {"vi": talk.saying.vi, "en": talk.saying.en}
	elif talk.state == "answer":
		result.replies = Content.line(talk.answer).get("replies", [])
	return result


## The card of the Lens app for the focus (R23).
func lens_card() -> Dictionary:
	var parts := focus_id.split(".")
	if parts.size() < 2:
		# A known place of the Vũng Tàu world in the middle of the view (plan 0008, D6).
		if vung_tau != null and vung_tau.places != null:
			return vung_tau.places.lens_card(player.eye_position(), player.view_forward())
		return {}
	if parts[0] == "npc":
		var npc_id := parts[1]
		var shown: String = Content.speaker(npc_id).name if GameState.has_met(npc_id) else Content.string("someone")
		return {"kind": "person", "name": shown}
	# A parked scooter ("scooter.N", plan 0018, R4) is not a spot.
	var spot := Content.spot(parts[1]) if parts[0] == "spot" else {}
	if spot.is_empty():
		return {}
	var rule := Content.rule_for(spot, "lens", GameState.minutes)
	var params := _spot_params(spot)
	return {"kind": "spot", "id": spot.id, "line": rule.get("line", ""), "name": spot.name, "en": spot.en,
			"status": params.status, "text": Content.format(Content.line(rule.get("line", "")).get("text", ""), params)}


func _learn_from_lens() -> void:
	var card := lens_card()
	var line_id: String = card.get("line", "")
	if line_id == "" or line_id == lens_line:
		return
	lens_line = line_id
	var rule := Content.rule_for(Content.spot(card.id), "lens", GameState.minutes)
	for card_id: String in rule.get("learn", []):
		GameState.learn(card_id)
	check_messages("lens:" + line_id)


## The values for the "{key}" fields of a spot text.
func _spot_params(spot: Dictionary) -> Dictionary:
	var hours: Variant = spot.hours
	var open := GameClock.is_open(hours, GameState.minutes)
	var params := {"name": spot.name, "en": spot.en, "status": "", "hours": Content.hours_text(hours)}
	if hours != null:
		params.open = GameClock.format_time(int(hours.open))
		params.close = GameClock.format_time(int(hours.close))
		params.status = Content.format(Content.string("status_open" if open else "status_closed"),
				{"hours": params.hours})
	return params


func _apply_settings() -> void:
	player.camera.fov = float(GameState.settings.fov)
	subtitles.apply_settings(float(GameState.settings.subtitle_size), float(GameState.settings.subtitle_box))
	Quality.apply(GameState.settings.quality, environment, sun, get_viewport())
	_apply_window_mode()


## The fullscreen setting of a desktop window (plan 0004, R1). Phones and the
## web build have no window setting.
func _apply_window_mode() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return
	var fullscreen := bool(GameState.settings.fullscreen)
	var mode := DisplayServer.window_get_mode()
	var is_fullscreen := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if fullscreen and not is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_time_changed(minutes: int, _day: int) -> void:
	_apply_time(minutes)
	if hem == null:
		return
	# A shop closes its shutter: a player in the shop room goes out to the hẻm.
	var room := hem.room_at(player.global_position)
	if room != "" and hem.shutter_of(room) != TubeHouse.Shutter.OPEN:
		_stop_walk()
		player.place(hem.stand_points[room], player.target_yaw, player.target_pitch)
		_save_position()
	check_messages()


# --- Time and light --------------------------------------------------------

func _apply_time(minutes: int) -> void:
	if vung_tau != null:
		vung_tau.update_time(minutes, GameState.day)
		return
	hem.update_time(minutes)
	var sky := DayLight.sky_colors(minutes)
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	sky_material.sky_top_color = sky[0]
	sky_material.sky_horizon_color = sky[1]
	# The lower half of the sky is not visible, but SDFGI (High and Ultra)
	# takes its light. By day it has the warm color of the sunlit ground, so
	# the shade is not blue and cold (D-0004-04).
	var day := 1.0 - DayLight.darkness(minutes) / 0.55
	sky_material.ground_horizon_color = sky[1].lerp(DayLight.WARM_GROUND, 0.6 * day)
	sky_material.ground_bottom_color = sky[1].darkened(0.5).lerp(DayLight.WARM_GROUND, 0.8 * day)
	environment.ambient_light_color = DayLight.ambient_color(minutes)
	environment.ambient_light_energy = DayLight.ambient_energy(minutes)
	environment.sdfgi_energy = DayLight.gi_energy(minutes)
	environment.fog_light_color = sky[1]
	sun.rotation_degrees = DayLight.sun_rotation(minutes)
	sun.light_color = DayLight.sun_color(minutes)
	sun.light_energy = DayLight.sun_energy(minutes)
	# The sun casts shadows on all presets (plan 0004, R5), except in the web
	# build: see Quality.sun_shadow().
	sun.shadow_enabled = Quality.sun_shadow()


# --- Layout ----------------------------------------------------------------

## The parts of the screen: the phone at the right, the action button below
## the center dot, and the subtitles at the bottom, out of the joystick zone
## and the phone (R13, R16).
func _layout() -> void:
	var view := ui_root.get_viewport_rect().size
	var center := view / 2.0
	center_dot.position = center - center_dot.size / 2.0
	_place_action_button(player != null and player.is_riding(), true)
	_layout_notes(view)
	joystick.position = Vector2.ZERO
	joystick.size = view
	phone.layout(view)
	_layout_subtitles(view)


## The place of the action button: below the center dot, or on the scooter
## (plan 0018, D7) at the right, above the phone button, out of the middle
## third of the view, which shows the road ahead (report 0018, D-0018-02).
## It stays there at each speed, so that it does not move under the thumb.
func _place_action_button(on_scooter: bool, force := false) -> void:
	# Off the scooter the place changes only with the size of the view (_layout()).
	if not on_scooter and not _action_on_scooter and not force:
		return
	var view := ui_root.get_viewport_rect().size
	action_button.size = ACTION_SIZE
	var before := action_button.position
	if on_scooter:
		var size := action_button.get_combined_minimum_size().max(ACTION_SIZE)
		action_button.size = size
		var button: Control = phone.button
		action_button.position = Vector2(button.position.x + button.size.x - size.x,
				button.position.y - size.y - Phone.MARGIN)
	else:
		action_button.position = Vector2(view.x / 2.0 - ACTION_SIZE.x / 2.0, view.y / 2.0 + 80.0)
	if on_scooter != _action_on_scooter or action_button.position != before:
		_action_on_scooter = on_scooter
		_layout_subtitles(view)


## Plan 0018, D13: the name of the road at the top, in the middle; D12: the
## hint of the first rides above the zone of the joystick, at the left.
func _layout_notes(view: Vector2) -> void:
	if _road_note == null:
		return
	_road_note.reset_size()
	var top := SUBTITLE_MARGIN
	# Plan 0031, D11: the line of the times is at the top; the name of the road under it.
	if _times_note != null and _times_note.visible:
		_times_note.reset_size()
		_times_note.position = Vector2(maxf((view.x - _times_note.size.x) / 2.0, 0.0), SUBTITLE_MARGIN)
		top += _times_note.size.y + SUBTITLE_MARGIN / 2.0
	_road_note.position = Vector2((view.x - _road_note.size.x) / 2.0, top)
	_hint_note.reset_size()
	# By the joystick (D12), clear of it (R13): above its ring, where the thumb
	# holds it now or at its rest place; below the ring when no room is above.
	var center: Vector2 = joystick.center if joystick.visible else stick_rest()
	var radius := Joystick.RADIUS
	var hint_size := _hint_note.size
	var x := clampf(center.x - hint_size.x / 2.0, SUBTITLE_MARGIN, maxf(SUBTITLE_MARGIN, view.x - hint_size.x - SUBTITLE_MARGIN))
	var y := center.y - radius - hint_size.y - SUBTITLE_MARGIN / 2.0
	if y < SUBTITLE_MARGIN:
		y = center.y + radius + SUBTITLE_MARGIN / 2.0
	_hint_note.position = Vector2(x, y)


## Plan 0018, D13: when the player comes onto a road with another name (on a
## walk or a ride), its name shows for ROAD_NAME_S. A road with no name shows
## nothing. The time of the note runs with the clock.
func _update_road_name(delta: float) -> void:
	if vung_tau == null:
		return
	var at := player.ride_middle() if player.is_riding() else player.global_position
	# The player comes onto a road by a walk or a ride: a placement (the start,
	# a setup step of a play test) or a flight of the camera shows no name.
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > ROAD_NAME_MOVING
	var road := vung_tau.road_at(at) if moving else {}
	if not road.is_empty():
		var road_name := str(road.get("name", ""))
		if road_name != _road_name_last:
			_road_name_last = road_name
			if road_name != "":
				_road_note.show_text(road_name, ROAD_NAME_S)
			else:
				_road_note.hide_note()
	_road_note.tick(delta if GameState.clock_running else 0.0)


## Plan 0018, D12: the hint on the first Riding.HINT_RIDES rides (Riding calls it
## when the player gets on). The words are for the last kind of input.
func start_ride_hint() -> void:
	_hint_used = {}
	_hint_note.show_text(_ride_hint_words(), RIDE_HINT_S)


## The words of the hint for the last kind of input (data/ui.json).
func _ride_hint_words() -> String:
	var key := {"touch": "scooter_hint_touch", "gamepad": "scooter_hint_gamepad"}.get(last_input, "scooter_hint_keys") as String
	if touch_mode:
		key = "scooter_hint_touch"
	return Content.ui_text(key)


## The hint goes after RIDE_HINT_S, or when the rider used each direction (up,
## down, a side), or when the player gets off.
func _update_ride_hint(delta: float) -> void:
	if _hint_note == null or not _hint_note.visible:
		return
	if not player.is_riding():
		_hint_note.hide_note()
		return
	# The words follow the kind of input (a phone knows it at the first touch).
	var words := _ride_hint_words()
	if _hint_note.label.text != words:
		_hint_note.label.text = words
	var stick := player.move_input
	if stick.y > 0.3:
		_hint_used.up = true
	if stick.y < -0.3:
		_hint_used.down = true
	if absf(stick.x) > 0.3:
		_hint_used.side = true
	if _hint_used.size() >= 3:
		_hint_note.hide_note()
		return
	# The time of the hint runs only while the rider can ride (with --ride the
	# world loads first, and the scooter waits for the showcase: D-0018-03).
	_hint_note.tick(delta if GameState.clock_running and not player.ride_hold else 0.0)


func _layout_subtitles(view: Vector2) -> void:
	var stick := stick_zone()
	var phone_left := view.x - minf(view.x * Phone.MAX_FRACTION, Phone.MAX_WIDTH) - Phone.MARGIN
	# The line length is for the room above the joystick zone when the phone
	# is up: the smallest room. Then the split does not change when the phone goes up.
	var smallest := phone_left - 2.0 * SUBTITLE_MARGIN - subtitles.padding()
	# Some letters are wider than the mean: keep 15 % more room.
	subtitles.max_chars = clampi(int(smallest / (subtitles.char_width() * 1.15)), 12, SubtitleText.MAX_CHARS)
	var width := minf(subtitles.box_width(), view.x - 2.0 * SUBTITLE_MARGIN)
	# Beside the joystick zone, at the bottom, when there is room.
	var left := stick.end.x + SUBTITLE_MARGIN
	var right := phone.button.position.x - SUBTITLE_MARGIN
	var bottom := view.y - SUBTITLE_MARGIN
	# On the scooter, "Get off" is above the phone button (D-0018-02).
	var top_right := phone.button.position.y
	if _action_on_scooter:
		right = minf(right, action_button.position.x - SUBTITLE_MARGIN)
		top_right = action_button.position.y
	if right - left < width:
		# Else above the joystick zone and the phone button, at the left of the phone.
		left = SUBTITLE_MARGIN
		right = (phone_left if phone.up else view.x) - SUBTITLE_MARGIN
		bottom = minf(stick.position.y, top_right) - SUBTITLE_MARGIN
		# Plan 0018, D12: and above the hint of the first rides.
		if _hint_note != null and _hint_note.visible:
			bottom = minf(bottom, _hint_note.position.y - SUBTITLE_MARGIN)
	var x := clampf((left + right) / 2.0 - width / 2.0, left, maxf(left, right - width))
	subtitles.size = Vector2(width, 0)
	subtitles.position = Vector2(x, bottom - subtitles.size.y)


## Plan 0018, D7: the joystick at its rest place while no thumb holds it.
func _update_rest_stick() -> void:
	if _stick_id != null:
		return
	if touch_mode:
		joystick.show_rest(stick_rest())
	elif joystick.visible:
		joystick.hide_stick()


## The rest place of the joystick: the middle of the joystick zone (D7).
func stick_rest() -> Vector2:
	return stick_zone().get_center()


# --- Values for the play tests ---------------------------------------------

## Plan 0031, R1: what the page measures (tools/web/check.js, PT-85): the time
## when the player can move (the clock runs, and a scooter is not held for the
## showcase), and four times each second the place, the heading, and the speed.
func _update_web_state(delta: float) -> void:
	if _web_can_move_ms < 0 and GameState.clock_running and not player.ride_hold:
		_web_can_move_ms = Time.get_ticks_msec()
		JavaScriptBridge.eval("window.vungTau.canMoveMs = %d; window.vungTau.mark && window.vungTau.mark('canMove')" % _web_can_move_ms, true)
		# Plan 0031, D11: the line of the times at the top, for LoadTimes.SHOW_S.
		var branch := str(JavaScriptBridge.eval("window.vungTauBuild ? window.vungTauBuild.branch : ''", true))
		_times_shown = LoadTimes.shows(true, branch, GameState.has_arg("times"))
		_times_left = LoadTimes.SHOW_S if _times_shown else 0.0
		_times_update = 0.0
	if _times_shown:
		_update_times_line(delta)
	_web_state_left -= delta
	if _web_state_left > 0.0:
		return
	_web_state_left = 0.25
	var at := player.global_position
	var heading := player.ride.heading if player.is_riding() else player.yaw
	JavaScriptBridge.eval("window.vungTau.state = {x: %.2f, z: %.2f, heading: %.1f, speedKmh: %.1f, riding: %s, frames: %d}" % [
			at.x, at.z, heading, player.ride_speed_kmh(), "true" if player.is_riding() else "false", Engine.get_frames_drawn()], true)


## Plan 0031, D11: the line of the times, each second while it shows (the
## frames each second and the memory change). The Settings app keeps the last line.
func _update_times_line(delta: float) -> void:
	_times_update -= delta
	if _times_update > 0.0:
		_times_note.tick(delta)
		return
	_times_update = 1.0
	var parsed: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.vungTau.times ? window.vungTau.times() : {})", true)))
	var line := LoadTimes.line(parsed if parsed is Dictionary else {}, Engine.get_frames_per_second())
	if line != "":
		load_times_text = line
		JavaScriptBridge.eval("window.vungTau.timesLine = %s" % JSON.stringify(line), true)
	if _times_left > 0.0:
		_times_note.show_text(line, _times_left)
	_times_left = maxf(_times_left - 1.0, 0.0)


## The line of the times on the screen, or "".
func load_times_shown() -> String:
	return _times_note.shown() if _times_note != null else ""


## Plan 0018, D12: the text of the hint of the first rides, or "".
func ride_hint_text() -> String:
	return _hint_note.shown() if _hint_note != null else ""


func ride_hint_rect() -> Rect2:
	return _hint_note.get_global_rect() if _hint_note != null and _hint_note.visible else Rect2()


## Plan 0018, D13: the name of the road on the screen, or "".
func road_name_text() -> String:
	return _road_note.shown() if _road_note != null else ""


func road_name_rect() -> Rect2:
	return _road_note.get_global_rect() if _road_note != null and _road_note.visible else Rect2()


## The zone of the joystick and the zone of the look, in base coordinates.
func input_zones() -> Dictionary:
	var view := ui_root.get_viewport_rect().size
	return {
		"stick": Rect2(0, 0, view.x / 2.0, view.y),
		"look": Rect2(view.x / 2.0, 0, view.x / 2.0, view.y),
	}


## The part of the screen where the left thumb holds the joystick.
func stick_zone() -> Rect2:
	var view := ui_root.get_viewport_rect().size
	return Rect2(0, view.y - STICK_ZONE.y, STICK_ZONE.x, STICK_ZONE.y)


## Returns the number of dynamic lights that light a part of the view.
func lights_in_view() -> int:
	var count := 1 if sun.visible else 0
	if hem == null:
		return count
	var planes := player.camera.get_frustum()
	for light in hem.lights_on():
		var inside := true
		for plane: Plane in planes:
			if plane.distance_to(light.global_position) > light.omni_range:
				inside = false
				break
		if inside:
			count += 1
	return count


# --- Deep water and the debug overlay (plan 0005) ---------------------------

## The player stops at deep water: a message shows in the subtitle box (R13).
## Each stop shows it again, so it stays while the player pushes into the
## water and goes some seconds after. (A gap in real time between two messages
## did not work when the game runs faster: the caption went before the gap.)
func _on_blocked() -> void:
	subtitles.show_caption(Content.ui_text("water_too_deep"))


func _make_debug_overlay() -> void:
	debug_overlay = Label.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.set_meta("test_id", "debug")
	debug_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_overlay.add_theme_color_override("font_color", Color.WHITE)
	debug_overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	debug_overlay.add_theme_constant_override("outline_size", 6)
	debug_overlay.add_theme_font_size_override("font_size", 18)
	debug_overlay.visible = GameState.all_args().has("--debug")
	debug_overlay.position = Vector2(12, 8)
	ui_root.add_child(debug_overlay)


## F3 shows or hides the frame rate and the place (plan 0005, R16).
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		debug_overlay.visible = not debug_overlay.visible


func _update_debug_overlay() -> void:
	if not debug_overlay.visible:
		return
	var pos := player.global_position
	var lines := ["%d fps, %.1f ms" % [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1.0)],
			"X %.1f  Y %.2f  Z %.1f" % [pos.x, pos.y, pos.z]]
	if vung_tau != null:
		var lonlat := vung_tau.data.projection.game_to_lonlat(pos.x, pos.z)
		var road := vung_tau.road_at(pos)
		var counts := vung_tau.loaded_counts()
		lines.append("%.6f N, %.6f E" % [lonlat[1], lonlat[0]])
		lines.append("Ground %.2f m" % vung_tau.ground_height(pos.x, pos.z))
		lines.append("Road: %s" % (road.get("name", "") if not road.is_empty() else "-"))
		lines.append("Chunks: %d near, %d mid, %d far" % [counts.near, counts.mid, counts.far])
		lines.append("Sea %+.2f m, ridge %s" % [vung_tau.sea_level, "dry" if vung_tau.is_ridge_dry() else "under water"])
		lines.append(GameCalendar.text(GameState.day))
	debug_overlay.text = "\n".join(lines)

