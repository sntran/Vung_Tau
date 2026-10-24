extends Node3D
## The main scene: the world in first person and the UI.
##
## It reads the touch, mouse, and key input, runs the dialogue from
## data/dialogue/hem.json, and keeps the world and the UI the same as the
## game state.

## The player is near a spot at this distance or less (plan 0001, R26).
const NEAR_DISTANCE := 2.0
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
const PANEL_MAX_FRACTION := 0.42
const PORTRAIT_PANEL_FRACTION := 0.4
const ACTION_SIZE := Vector2(180, 88)
## See _set_3d_scale().
const WIDE_WINDOW := 1920
const WIDE_3D_SCALE := 0.75

## "hem" (the talk panel is the active UI), "notebook", "clock", or "settings".
var mode := "hem"
var line_id := ""
var near_spot := ""
var choices: Array = []
var context: Dictionary = {}
var pending: Dictionary = {}
## The test ID of the focus ("spot.pho", "npc.batu"), or "".
var focus_id := ""
var focus_verb := ""
## The sensor source of the gyroscope. The play-test system can replace it.
var sensor: SensorSource = SensorSource.new()
## "hem" (plans 0001 and 0002), or "vung_tau" (plan 0003) with --world=vung_tau.
var world_name := "hem"
## The real ground of Vũng Tàu, or null in the hẻm world.
var vung_tau: VungTau = null
var debug_overlay: Label
var credits_sheet: CreditsSheet
var _water_message_time := -100000

@onready var hem: Hem = $World/Hem
## A message about deep water shows not more often than this.
const WATER_MESSAGE_MS := 3000
@onready var player: Player = $World/Player
@onready var sun: DirectionalLight3D = $World/Sun
@onready var environment: Environment = $World/Environment.environment
@onready var ui_root: Control = $UI/Root
@onready var top_bar: TopBar = $UI/Root/TopBar
@onready var talk_panel: TalkPanel = $UI/Root/TalkPanel
@onready var notebook_sheet: NotebookSheet = $UI/Root/NotebookSheet
@onready var clock_sheet: ClockSheet = $UI/Root/ClockSheet
@onready var settings_sheet: SettingsSheet = $UI/Root/SettingsSheet
@onready var toast: Toast = $UI/Root/Toast
@onready var joystick: Joystick = $UI/Root/Joystick
@onready var center_dot: CenterDot = $UI/Root/CenterDot
@onready var action_button: Button = $UI/Root/ActionButton
@onready var ting_player: AudioStreamPlayer = $Sounds/Ting
@onready var clack_player: AudioStreamPlayer = $Sounds/Clack

## The touches and the mouse press: id -> {start, last, time, zone, active}.
var _touches: Dictionary = {}
var _stick_id: Variant = null


func _ready() -> void:
	add_to_group("main")
	ui_root.theme = UiTheme.make()
	ting_player.stream = Tones.ting()
	clack_player.stream = Tones.clack()
	action_button.set_meta("test_id", "action")
	action_button.theme_type_variation = "PrimaryButton"
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.pressed.connect(_on_action)
	top_bar.clock_pressed.connect(_on_clock_pressed)
	top_bar.sound_pressed.connect(_on_sound_pressed)
	top_bar.notebook_pressed.connect(_on_notebook_pressed)
	top_bar.settings_pressed.connect(_on_settings_pressed)
	top_bar.center_pressed.connect(center_view)
	talk_panel.choice_pressed.connect(_on_choice)
	notebook_sheet.closed.connect(_close_sheets)
	clock_sheet.closed.connect(_close_sheets)
	clock_sheet.choice_pressed.connect(_on_clock_choice)
	settings_sheet.closed.connect(_close_sheets)
	settings_sheet.changed.connect(_on_settings_changed)
	settings_sheet.credits_pressed.connect(open_credits)
	credits_sheet = CreditsSheet.new()
	credits_sheet.name = "CreditsSheet"
	credits_sheet.visible = false
	credits_sheet.closed.connect(_close_sheets)
	ui_root.add_child(credits_sheet)
	ui_root.move_child(credits_sheet, settings_sheet.get_index() + 1)
	_make_debug_overlay()
	GameState.time_changed.connect(_on_time_changed)
	GameState.card_learned.connect(_on_card_learned)
	player.stepped.connect(GameState.add_walk)
	player.arrived.connect(_on_arrived)
	player.blocked.connect(_on_blocked)
	AudioServer.set_bus_mute(0, not GameState.sound)
	if GameState.arg_value("world") == "vung_tau":
		_start_vung_tau()
	if vung_tau == null:
		hem.clacked.connect(_on_clacked)
		player.place(GameState.player_pos, GameState.yaw, GameState.pitch)
	_apply_settings()
	_layout()
	_apply_time(GameState.minutes)
	if vung_tau != null:
		talk_panel.visible = false
	elif not GameState.flag("intro_done"):
		show_line("intro.welcome")
	else:
		show_hem_panel()


## Plan 0003: the real ground in place of the hẻm. The hẻm world, its sun,
## and its sky go. The save of the hẻm world stays as it is.
func _start_vung_tau() -> void:
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
	player.camera.far = 6000.0
	var start := world.spawn()
	world.prepare_at(start.position)
	player.place(start.position, start.yaw)


func _process(delta: float) -> void:
	_layout()
	_read_keys()
	_read_gyro(delta)
	_update_focus()
	_refresh_hem_panel()
	_update_debug_overlay()
	if vung_tau != null:
		_update_top_bar()
		return
	GameState.player_pos = player.global_position
	GameState.yaw = player.target_yaw
	GameState.pitch = player.target_pitch


# --- Input ---------------------------------------------------------------

## W, A, S, D and the arrow keys move the player (plan 0002, R11).
func _read_keys() -> void:
	if _stick_id != null:
		return
	var keys := Vector2.ZERO
	if mode == "hem":
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			keys.y += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			keys.y -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			keys.x += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			keys.x -= 1.0
	var was_moving := player.move_input.length() > 0.0
	player.move_input = keys.limit_length(1.0)
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


func _press(id: Variant, pos: Vector2) -> void:
	if mode != "hem":
		return
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
		pending = {}
		_save_position()


func _save_position() -> void:
	# The Vũng Tàu world does not save the position: the save is for the hẻm world.
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


## A tap on the world: walk to a spot, a person, or a point on the ground (D6).
func tap_world(screen_pos: Vector2) -> void:
	if mode != "hem" or not GameState.settings.tap_walk:
		return
	var hit := pick(screen_pos)
	match hit.kind:
		"spot":
			walk_to(hem.stand_points[hit.id], {"spot": hit.id})
		"npc":
			walk_to(hem.npc_stand_points[hit.id], {"npc": hit.id})
		"floor":
			walk_to(hit.position, {})


## Walks to the point. When the point is more than 15 m away, the player
## walks 15 m in its direction and does not open the talk panel (R10).
func walk_to(point: Vector3, target: Dictionary) -> void:
	var from := player.global_position
	var flat := Vector3(point.x - from.x, 0, point.z - from.z)
	if flat.length() > TAP_WALK_RANGE:
		point = from + flat.normalized() * TAP_WALK_RANGE
		target = {}
	pending = target
	player.walk_to(point)


func _on_arrived() -> void:
	_save_position()
	var target := pending
	pending = {}
	if target.has("spot"):
		open_spot(target.spot)
	elif target.has("npc"):
		open_npc(target.npc)
	else:
		show_hem_panel()


# --- Focus and the action button --------------------------------------------

## Finds the focus: the touchable object nearest to the center dot, at 3 m or less.
func _update_focus() -> void:
	var best := ""
	var best_angle := FOCUS_ANGLE
	var verb := ""
	if mode == "hem" and hem != null:
		var eye := player.eye_position()
		var forward := player.view_forward()
		for spot: Dictionary in Content.spot_list():
			if not hem.is_present(spot.id, GameState.minutes):
				continue
			var angle := _focus_angle(eye, forward, hem.focus_points[spot.id])
			if angle < best_angle:
				best_angle = angle
				best = "spot." + spot.id
				var open := GameClock.is_open(spot.hours, GameState.minutes)
				verb = spot.get("verb_open", spot.verb) if open else spot.verb
		for npc_id: String in hem.npcs:
			var npc: Npc = hem.npcs[npc_id]
			if not npc.visible:
				continue
			var angle := _focus_angle(eye, forward, npc.global_position + Vector3(0, npc.height - 0.2, 0))
			if angle < best_angle:
				best_angle = angle
				best = "npc." + npc_id
				verb = Content.npc(npc_id).verb
	focus_id = best
	focus_verb = verb
	center_dot.set_active(best != "")
	action_button.visible = best != ""
	action_button.text = verb


func _focus_angle(eye: Vector3, forward: Vector3, point: Vector3) -> float:
	var to := point - eye
	var distance := to.length()
	if distance > FOCUS_RANGE or distance < 0.01:
		return 999.0
	return rad_to_deg(forward.angle_to(to))


func _on_action() -> void:
	if focus_id == "" or mode != "hem":
		return
	_stop_walk()
	var parts := focus_id.split(".")
	if parts[0] == "spot":
		open_spot(parts[1])
	else:
		open_npc(parts[1])


# --- Dialogue ------------------------------------------------------------

## Shows the line of the spot for the time, and learns the cards of the rule.
func open_spot(spot_id: String) -> void:
	var spot := Content.spot(spot_id)
	var rule := Content.line_rule(spot, GameState.minutes)
	_learn(rule.get("learn", []))
	show_line(rule.line, {"spot": spot_id})


## Shows the line of the person. The person turns to face the player (R14).
func open_npc(npc_id: String) -> void:
	var npc := Content.npc(npc_id)
	var rule := Content.line_rule(npc, GameState.minutes)
	if hem.npcs.has(npc_id):
		hem.npcs[npc_id].face(player.global_position)
	_learn(rule.get("learn", []))
	show_line(rule.line, {"npc": npc_id})


## Shows the panel for the place where the player stands: the near spot, or a tip.
func show_hem_panel() -> void:
	if vung_tau != null:
		return
	if GameState.is_late():
		show_line("hem.late")
		return
	var spot_id := find_near_spot()
	if spot_id != "":
		show_line("hem.near", {"spot": spot_id})
		return
	var tip := Content.hem_tip(GameState.minutes, GameState.cards)
	show_line(tip.line)


## The hẻm panel (a near spot or a tip) follows the player during a walk with
## the joystick or the keys. A dialogue line stays until the player answers it.
func _refresh_hem_panel() -> void:
	if mode != "hem" or player.walking or hem == null:
		return
	if line_id != "hem.near" and not line_id.begins_with("hem.tip."):
		return
	var spot_id := find_near_spot()
	if spot_id != near_spot:
		show_hem_panel()


## Returns the nearest spot that is there now, at 2 m or less, or "".
func find_near_spot() -> String:
	var best := ""
	var best_distance := NEAR_DISTANCE
	if hem == null:
		return best
	var pos := player.global_position
	for spot: Dictionary in Content.spot_list():
		if not hem.is_present(spot.id, GameState.minutes):
			continue
		var stand: Vector3 = hem.stand_points[spot.id]
		var distance := Vector2(pos.x - stand.x, pos.z - stand.z).length()
		if distance <= best_distance:
			best = spot.id
			best_distance = distance
	return best


## Shows a line in the talk panel. At 23:30 or later, the only line is "hem.late".
func show_line(id: String, line_context: Dictionary = {}) -> void:
	if GameState.is_late() and id != "hem.late":
		id = "hem.late"
		line_context = {}
	var line := Content.line(id)
	line_id = id
	context = line_context
	near_spot = line_context.get("spot", "") if id == "hem.near" else ""
	choices = line.choices
	var params := _params()
	var view := {
		"line_id": id,
		"text": Content.format(line.text, params).strip_edges(),
		"hint": Content.format(line.get("hint", ""), params),
		"phrases": line.get("phrases", []),
		"choices": [],
	}
	if line.has("speaker"):
		var speaker := Content.speaker(line.speaker)
		view.speaker = speaker.name
		view.speaker_color = Color(speaker.color)
	for choice: Dictionary in choices:
		view.choices.append({
			"id": choice.id,
			"label": Content.format(choice.label, params),
			"sub": Content.format(choice.get("sub", ""), params),
			"style": choice.get("style", ""),
		})
	talk_panel.show_line(view)
	_update_top_bar()


## The values for the "{key}" fields in the dialogue text.
func _params() -> Dictionary:
	var params := {
		"day": GameState.day,
		"time": GameClock.format_time(GameState.minutes),
	}
	var spot_id: String = context.get("spot", "")
	if spot_id != "":
		var spot := Content.spot(spot_id)
		var hours: Variant = spot.hours
		var open := GameClock.is_open(hours, GameState.minutes)
		params.name = spot.name
		params.en = spot.en
		params.hours = Content.hours_text(hours)
		params.status = ""
		if hours != null:
			params.open = GameClock.format_time(int(hours.open))
			params.close = GameClock.format_time(int(hours.close))
			params.status = Content.format(Content.string("status_open" if open else "status_closed"),
					{"hours": params.hours})
		params.look = spot.get("look_label_open", spot.look_label) if open else spot.look_label
	return params


func _on_choice(index: int) -> void:
	if index < 0 or index >= choices.size() or mode != "hem":
		return
	var choice: Dictionary = choices[index]
	_stop_walk()
	_learn(choice.get("learn", []))
	if choice.has("flag"):
		GameState.set_flag(choice.flag)
	if choice.has("minutes"):
		GameState.add_minutes(int(choice.minutes))
	if choice.has("until"):
		GameState.wait_until(int(choice.until))
	if choice.get("sleep", false):
		sleep_until_morning()
		return
	if choice.get("open", "") == "clock":
		open_clock()
		return
	var next: String = choice.get("next", "@hem")
	match next:
		"@hem":
			show_hem_panel()
		"@spot":
			open_spot(context.spot)
		_:
			show_line(next, context)


func _learn(card_ids: Array) -> void:
	for card_id: String in card_ids:
		GameState.learn(card_id)


## The next day: the player is at the homestay door and looks along the hẻm (R4).
func sleep_until_morning() -> void:
	_stop_walk()
	GameState.sleep_until_morning()
	if vung_tau != null:
		return
	player.place(GameState.player_pos, GameState.yaw, GameState.pitch)
	center_view()
	show_line("home.morning")


# --- Sheets and the top bar ------------------------------------------------

func _on_clock_pressed() -> void:
	if mode == "clock":
		_close_sheets()
	else:
		open_clock()


func open_clock() -> void:
	_open_sheet("clock")
	var view := ui_root.get_viewport_rect().size
	clock_sheet.show_time(GameState.minutes, 2 if view.x > view.y else 1)
	clock_sheet.visible = true


func _on_clock_choice(choice: Dictionary) -> void:
	_close_sheets()
	_stop_walk()
	if choice.get("sleep", false):
		sleep_until_morning()
		return
	var target := GameClock.wait_target(choice, GameState.minutes)
	if target >= 0:
		GameState.set_minutes(target)
	show_hem_panel()


func _on_notebook_pressed() -> void:
	if mode == "notebook":
		_close_sheets()
		return
	_open_sheet("notebook")
	var view := ui_root.get_viewport_rect().size
	notebook_sheet.show_cards(GameState.cards, 1 if view.x < 1000.0 else 2)
	notebook_sheet.visible = true


func _on_settings_pressed() -> void:
	if mode == "settings":
		_close_sheets()
		return
	_open_sheet("settings")
	var view := ui_root.get_viewport_rect().size
	settings_sheet.show_settings(GameState.settings, 2 if view.x > view.y else 1)
	settings_sheet.visible = true


func _on_settings_changed(settings: Dictionary) -> void:
	GameState.set_settings(settings)
	_apply_settings()


func _apply_settings() -> void:
	player.camera.fov = float(GameState.settings.fov)
	top_bar.show_center(bool(GameState.settings.gyro) and sensor.has_data())


func _open_sheet(sheet: String) -> void:
	_close_sheets()
	_stop_walk()
	_cancel_touches()
	mode = sheet


func _close_sheets() -> void:
	mode = "hem"
	notebook_sheet.visible = false
	clock_sheet.visible = false
	settings_sheet.visible = false
	credits_sheet.visible = false


## The credits sheet opens from the settings sheet (plan 0003).
func open_credits() -> void:
	_open_sheet("credits")
	credits_sheet.show_credits()
	credits_sheet.visible = true


## Ends all touches: a sheet covers the world, so the joystick and the look stop.
func _cancel_touches() -> void:
	_touches.clear()
	_stick_id = null
	joystick.hide_stick()
	player.move_input = Vector2.ZERO


func _on_sound_pressed() -> void:
	GameState.set_sound(not GameState.sound)
	AudioServer.set_bus_mute(0, not GameState.sound)
	if GameState.sound:
		ting_player.play()
	_update_top_bar()


func _on_card_learned(card_id: String) -> void:
	var card := Content.card(card_id)
	toast.show_text("%s [b]%s[/b]" % [Content.ui_text("toast_new_card"), card.title])
	ting_player.play()
	_update_top_bar()


func _on_clacked(_position: Vector3) -> void:
	clack_player.play()


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
	if GameState.is_late() and line_id != "hem.late" and mode == "hem" and not player.walking:
		show_hem_panel()


func _update_top_bar() -> void:
	var part := GameClock.part_of_day(GameState.minutes, Content.ui.parts_of_day)
	var place: String
	var sub: String
	if vung_tau != null:
		# The name of the road under the player, from OpenStreetMap.
		var road := vung_tau.road_at(player.global_position)
		place = road.get("name", "") if road.get("name", "") != "" else Content.ui_text("world_name")
		sub = Content.format(Content.ui_text("world_sub"), {"day": GameState.day})
	else:
		var at_beach := player.global_position.x > hem.end_x
		place = Content.ui_text("beach_name" if at_beach else "place_name")
		sub = Content.format(Content.ui_text("beach_sub" if at_beach else "place_sub"), {"day": GameState.day})
	top_bar.show_state(GameClock.format_time(GameState.minutes), part.vi, place, sub, GameState.sound,
			GameState.cards.size(), Content.card_list().size())


# --- Time and light --------------------------------------------------------

func _apply_time(minutes: int) -> void:
	if vung_tau != null:
		vung_tau.update_time(minutes, GameState.day)
		_update_top_bar()
		return
	hem.update_time(minutes)
	var sky := DayLight.sky_colors(minutes)
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	sky_material.sky_top_color = sky[0]
	sky_material.sky_horizon_color = sky[1]
	sky_material.ground_horizon_color = sky[1]
	sky_material.ground_bottom_color = sky[1].darkened(0.5)
	environment.ambient_light_color = sky[1].lerp(Color.WHITE, 0.4)
	environment.ambient_light_energy = DayLight.ambient_energy(minutes)
	environment.fog_light_color = sky[1]
	sun.rotation_degrees = DayLight.sun_rotation(minutes)
	sun.light_color = DayLight.sun_color(minutes)
	sun.light_energy = DayLight.sun_energy(minutes)
	# No sun shadows: see plan 0001, note N18.
	sun.shadow_enabled = false
	_update_top_bar()


# --- Layout ----------------------------------------------------------------

## The parts of the screen. Landscape: the talk panel is at the right side.
## Portrait (the web build in a narrow window): the talk panel is at the bottom.
func _layout() -> void:
	_set_3d_scale()
	var view := ui_root.get_viewport_rect().size
	var safe_top := _safe_top_inset()
	var bar_height := UiTheme.TOP_BAR_HEIGHT + safe_top
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(view.x, bar_height)
	var bar_margin: MarginContainer = top_bar.get_child(0)
	if bar_margin.get_theme_constant("margin_top") != 12 + int(safe_top):
		bar_margin.add_theme_constant_override("margin_top", 12 + int(safe_top))
	var landscape := view.x > view.y
	var panel_width := minf(view.x * PANEL_MAX_FRACTION, 600.0) if landscape else view.x
	var max_height := (view.y - bar_height - 16.0) if landscape else view.y * PORTRAIT_PANEL_FRACTION
	talk_panel.size = Vector2(panel_width, talk_panel.size.y)
	var panel_height := clampf(talk_panel.needed_height(), 120.0, max_height)
	talk_panel.size = Vector2(panel_width, panel_height)
	talk_panel.position = Vector2(view.x - panel_width, view.y - panel_height)
	var center := view / 2.0
	center_dot.position = center - center_dot.size / 2.0
	action_button.size = ACTION_SIZE
	action_button.position = Vector2(center.x - ACTION_SIZE.x / 2.0, center.y + 80.0)
	joystick.position = Vector2.ZERO
	joystick.size = view
	for sheet: Control in [notebook_sheet, clock_sheet, settings_sheet, credits_sheet]:
		sheet.position = Vector2(0, bar_height)
		sheet.size = Vector2(view.x, view.y - bar_height)
	var clock_width := minf(view.x, 900.0 if landscape else 760.0)
	clock_sheet.panel.size = Vector2(clock_width, 0)
	clock_sheet.panel.position = Vector2((view.x - clock_width) / 2.0, 0)
	var free_width := view.x - panel_width if landscape else view.x
	var toast_width := minf(free_width - 32.0, 640.0)
	toast.size = Vector2(toast_width, 0)
	toast.position = Vector2((free_width - toast_width) / 2.0, bar_height + 16.0)


## On a window wider than 1920 pixels (a phone with a 2400 x 1080 screen),
## the 3D view renders at 0.75 of the window size, so that it is faster. The
## UI stays at the full size. Godot has FSR only for the Forward+ renderer, so
## the scale is bilinear.
func _set_3d_scale() -> void:
	var viewport := get_viewport()
	var render_scale := WIDE_3D_SCALE if get_window().size.x > WIDE_WINDOW else 1.0
	if not is_equal_approx(viewport.scaling_3d_scale, render_scale):
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = render_scale


## Returns the top inset of the phone screen (a notch or a camera cutout) in base pixels.
func _safe_top_inset() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var window := get_window()
	if safe.size.y <= 0 or window.size.y <= 0:
		return 0.0
	var inset := float(safe.position.y - window.position.y)
	var scale := get_viewport().get_final_transform().get_scale().y
	return clampf(inset / maxf(scale, 0.01), 0.0, 120.0)


# --- Values for the play tests ---------------------------------------------

## The zone of the joystick and the zone of the look, in base coordinates.
func input_zones() -> Dictionary:
	var view := ui_root.get_viewport_rect().size
	var top := top_bar.size.y
	return {
		"stick": Rect2(0, top, view.x / 2.0, view.y - top),
		"look": Rect2(view.x / 2.0, top, view.x / 2.0, view.y - top),
	}


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


# --- Deep water and the debug overlay (plan 0003) ---------------------------

func _on_blocked() -> void:
	if Time.get_ticks_msec() - _water_message_time < WATER_MESSAGE_MS:
		return
	_water_message_time = Time.get_ticks_msec()
	toast.show_text(Content.ui_text("water_too_deep"))


func _make_debug_overlay() -> void:
	debug_overlay = Label.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.set_meta("test_id", "debug")
	debug_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_overlay.add_theme_color_override("font_color", Color.WHITE)
	debug_overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	debug_overlay.add_theme_constant_override("outline_size", 6)
	debug_overlay.add_theme_font_size_override("font_size", 18)
	debug_overlay.visible = OS.get_cmdline_user_args().has("--debug")
	ui_root.add_child(debug_overlay)


## F3 shows or hides the frame rate and the place (R16).
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
	debug_overlay.text = "\n".join(lines)
	debug_overlay.position = Vector2(12, top_bar.size.y + 8)
