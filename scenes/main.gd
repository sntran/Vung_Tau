extends Node3D
## The main scene: the world and the UI.
##
## It sends taps to the world, runs the dialogue from data/dialogue/hem.json,
## and keeps the world and the UI the same as the game state.

## The player is near a spot at this distance or less (R26).
const NEAR_DISTANCE := 2.0
## The walk buttons walk the player this distance (R25).
const WALK_STEP := 6.0
## A tap is a press and a release with less movement than this.
const TAP_SLOP := 24.0
const WALK_BUTTON_SIZE := 96.0
const PANEL_MAX_FRACTION := 0.5
const LANDSCAPE_PANEL_WIDTH := 900.0

const ICON_LEFT := preload("res://assets/icons/arrow_left.svg")
const ICON_RIGHT := preload("res://assets/icons/arrow_right.svg")

## "hem" (the talk panel is the active UI), "notebook", or "clock".
var mode := "hem"
var line_id := ""
var near_spot := ""
var choices: Array = []
var context: Dictionary = {}
var pending: Dictionary = {}
var free_rect := Rect2()

@onready var hem: Hem = $World/Hem
@onready var player: Player = $World/Player
@onready var camera: CameraRig = $World/Camera
@onready var sun: DirectionalLight3D = $World/Sun
@onready var environment: Environment = $World/Environment.environment
@onready var ui_root: Control = $UI/Root
@onready var top_bar: TopBar = $UI/Root/TopBar
@onready var talk_panel: TalkPanel = $UI/Root/TalkPanel
@onready var notebook_sheet: NotebookSheet = $UI/Root/NotebookSheet
@onready var clock_sheet: ClockSheet = $UI/Root/ClockSheet
@onready var toast: Toast = $UI/Root/Toast
@onready var walk_left: Button = $UI/Root/WalkLeft
@onready var walk_right: Button = $UI/Root/WalkRight
@onready var ting_player: AudioStreamPlayer = $Sounds/Ting
@onready var clack_player: AudioStreamPlayer = $Sounds/Clack

var _press_position := Vector2.ZERO
var _press_valid := false


func _ready() -> void:
	add_to_group("main")
	ui_root.theme = UiTheme.make()
	ting_player.stream = Tones.ting()
	clack_player.stream = Tones.clack()
	_setup_walk_button(walk_left, "walk.left", ICON_LEFT, -WALK_STEP)
	_setup_walk_button(walk_right, "walk.right", ICON_RIGHT, WALK_STEP)
	top_bar.clock_pressed.connect(_on_clock_pressed)
	top_bar.sound_pressed.connect(_on_sound_pressed)
	top_bar.notebook_pressed.connect(_on_notebook_pressed)
	talk_panel.choice_pressed.connect(_on_choice)
	notebook_sheet.closed.connect(_close_sheets)
	clock_sheet.closed.connect(_close_sheets)
	clock_sheet.choice_pressed.connect(_on_clock_choice)
	GameState.time_changed.connect(_on_time_changed)
	GameState.card_learned.connect(_on_card_learned)
	player.stepped.connect(GameState.add_walk)
	player.arrived.connect(_on_arrived)
	hem.clacked.connect(_on_clacked)
	AudioServer.set_bus_mute(0, not GameState.sound)

	player.place(GameState.player_pos)
	camera.target = player
	camera.yaw_deg = BEACH_CAMERA_YAW if player.global_position.x > hem.end_x + 1.0 else 0.0
	_layout()
	camera.snap()
	_apply_time(GameState.minutes)
	if not GameState.flag("intro_done"):
		show_line("intro.welcome")
	else:
		show_hem_panel()


func _setup_walk_button(button: Button, test_id: String, icon: Texture2D, step: float) -> void:
	button.set_meta("test_id", test_id)
	button.theme_type_variation = "WalkButton"
	button.icon = icon
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = false
	button.custom_minimum_size = Vector2(WALK_BUTTON_SIZE, WALK_BUTTON_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(walk_by.bind(step))


## At the beach, the camera turns to look at the sea (toward +X).
const BEACH_CAMERA_YAW := -65.0


func _process(_delta: float) -> void:
	_layout()
	camera.yaw_deg = BEACH_CAMERA_YAW if player.global_position.x > hem.end_x + 1.0 else 0.0


# --- Input ---------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# The arrow keys walk the player, the same as the walk buttons (R25).
	if mode != "hem":
		return
	if event.is_action_pressed("ui_left", false, true):
		walk_by(-WALK_STEP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right", false, true):
		walk_by(WALK_STEP)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# A touch on a phone also makes a mouse event (touch-to-mouse emulation),
	# so the world reads only the mouse events.
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_press_position = button.position
		_press_valid = true
		return
	if _press_valid and button.position.distance_to(_press_position) <= TAP_SLOP:
		_press_valid = false
		tap_world(button.position)
		get_viewport().set_input_as_handled()
	_press_valid = false


## Returns what is under the screen point: a dictionary with "kind" ("spot",
## "npc", "floor", or "") and "id" and "position". The player body is not on
## the touch layer, so it never stops a tap on an object behind it (R24).
func pick(screen_pos: Vector2) -> Dictionary:
	var ray := camera.screen_ray(screen_pos)
	var origin := ray[0]
	var direction := ray[1]
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 600.0,
			Hem.FLOOR_LAYER | Hem.TOUCH_LAYER)
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


## A tap on the world: walk to a spot, a person, or a point on the floor (R23).
func tap_world(screen_pos: Vector2) -> void:
	if mode != "hem":
		return
	var hit := pick(screen_pos)
	match hit.kind:
		"spot":
			walk_to(hem.stand_points[hit.id], {"spot": hit.id})
		"npc":
			walk_to(hem.npc_stand_points[hit.id], {"npc": hit.id})
		"floor":
			walk_to(hit.position, {})


func walk_to(point: Vector3, target: Dictionary) -> void:
	pending = target
	player.walk_to(point)


## Walks the player along the hẻm by "step" meters (the walk buttons and the arrow keys).
func walk_by(step: float) -> void:
	if mode != "hem":
		return
	var from := player.target() if player.walking else player.global_position
	walk_to(from + Vector3(step, 0, 0), {})


func _on_arrived() -> void:
	GameState.set_player_pos(player.global_position)
	var target := pending
	pending = {}
	if target.has("spot"):
		open_spot(target.spot)
	elif target.has("npc"):
		open_npc(target.npc)
	else:
		show_hem_panel()


# --- Dialogue ------------------------------------------------------------

## Shows the line of the spot for the time, and learns the cards of the rule.
func open_spot(spot_id: String) -> void:
	var spot := Content.spot(spot_id)
	var rule := Content.line_rule(spot, GameState.minutes)
	_learn(rule.get("learn", []))
	show_line(rule.line, {"spot": spot_id})


func open_npc(npc_id: String) -> void:
	var npc := Content.npc(npc_id)
	var rule := Content.line_rule(npc, GameState.minutes)
	_learn(rule.get("learn", []))
	show_line(rule.line, {"npc": npc_id})


## Shows the panel for the place where the player stands: the near spot, or a tip.
func show_hem_panel() -> void:
	if GameState.is_late():
		show_line("hem.late")
		return
	var spot_id := find_near_spot()
	if spot_id != "":
		show_line("hem.near", {"spot": spot_id})
		return
	var tip := Content.hem_tip(GameState.minutes, GameState.cards)
	show_line(tip.line)


## Returns the nearest spot that is there now, at 2 m or less, or "".
func find_near_spot() -> String:
	var best := ""
	var best_distance := NEAR_DISTANCE
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


## Shows a line in the talk panel. At 23:30 or later, the only line is "hem.late" (R10).
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
	if player.walking:
		player.stop()
		pending = {}
		GameState.set_player_pos(player.global_position)
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


func sleep_until_morning() -> void:
	player.stop()
	pending = {}
	GameState.sleep_until_morning()
	player.place(GameState.player_pos)
	camera.snap()
	show_line("home.morning")


# --- Sheets and the top bar ------------------------------------------------

func _on_clock_pressed() -> void:
	if mode == "clock":
		_close_sheets()
	else:
		open_clock()


func open_clock() -> void:
	_close_sheets()
	mode = "clock"
	clock_sheet.show_time(GameState.minutes)
	clock_sheet.visible = true


func _on_clock_choice(choice: Dictionary) -> void:
	_close_sheets()
	if player.walking:
		player.stop()
		pending = {}
		GameState.set_player_pos(player.global_position)
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
	_close_sheets()
	mode = "notebook"
	var view := ui_root.get_viewport_rect().size
	notebook_sheet.show_cards(GameState.cards, 1 if view.x < 1000.0 else 3)
	notebook_sheet.visible = true


func _close_sheets() -> void:
	mode = "hem"
	notebook_sheet.visible = false
	clock_sheet.visible = false


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
	if GameState.is_late() and line_id != "hem.late" and mode == "hem" and not player.walking:
		show_hem_panel()


func _update_top_bar() -> void:
	var part := GameClock.part_of_day(GameState.minutes, Content.ui.parts_of_day)
	var at_beach := player.global_position.x > hem.end_x
	var place := Content.ui_text("beach_name" if at_beach else "place_name")
	var sub := Content.format(Content.ui_text("beach_sub" if at_beach else "place_sub"),
			{"day": GameState.day})
	top_bar.show_state(GameClock.format_time(GameState.minutes), part.vi, place, sub, GameState.sound,
			GameState.cards.size(), Content.card_list().size())


# --- Time and light --------------------------------------------------------

func _apply_time(minutes: int) -> void:
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
	sun.shadow_enabled = DayLight.sun_height(minutes) > 0.0
	_update_top_bar()


# --- Layout ----------------------------------------------------------------

## Places the UI for the screen size, and tells the camera the free part of the screen.
## Portrait: the talk panel is at the bottom. Landscape: it is at the right side.
func _layout() -> void:
	var view := ui_root.get_viewport_rect().size
	var safe_top := _safe_top_inset()
	var bar_height := UiTheme.TOP_BAR_HEIGHT + safe_top
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(view.x, bar_height)
	var bar_margin: MarginContainer = top_bar.get_child(0)
	if bar_margin.get_theme_constant("margin_top") != 12 + int(safe_top):
		bar_margin.add_theme_constant_override("margin_top", 12 + int(safe_top))
	var landscape := view.x > view.y
	var panel_width := minf(LANDSCAPE_PANEL_WIDTH, view.x * 0.45) if landscape else view.x
	var max_height := (view.y - bar_height) if landscape else view.y * PANEL_MAX_FRACTION
	talk_panel.size = Vector2(panel_width, talk_panel.size.y)
	var panel_height := clampf(talk_panel.needed_height(), 120.0, max_height)
	talk_panel.size = Vector2(panel_width, panel_height)
	talk_panel.position = Vector2(view.x - panel_width, view.y - panel_height)
	if landscape:
		free_rect = Rect2(0, bar_height, view.x - panel_width, view.y - bar_height)
	else:
		free_rect = Rect2(0, bar_height, view.x, view.y - bar_height - panel_height)
	camera.free_rect = free_rect
	var button_y := free_rect.end.y - WALK_BUTTON_SIZE - 16.0
	walk_left.position = Vector2(free_rect.position.x + 16.0, button_y)
	walk_left.size = Vector2(WALK_BUTTON_SIZE, WALK_BUTTON_SIZE)
	walk_right.position = Vector2(free_rect.end.x - WALK_BUTTON_SIZE - 16.0, button_y)
	walk_right.size = Vector2(WALK_BUTTON_SIZE, WALK_BUTTON_SIZE)
	notebook_sheet.position = Vector2(0, bar_height)
	notebook_sheet.size = Vector2(view.x, view.y - bar_height)
	clock_sheet.position = Vector2(0, bar_height)
	clock_sheet.size = Vector2(view.x, view.y - bar_height)
	var clock_width := minf(view.x, 760.0)
	clock_sheet.panel.size = Vector2(clock_width, 0)
	clock_sheet.panel.position = Vector2((view.x - clock_width) / 2.0, 0)
	var toast_width := minf(view.x - 32.0, 640.0)
	toast.size = Vector2(toast_width, 0)
	toast.position = Vector2((view.x - toast_width) / 2.0, bar_height + 16.0)


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

## Returns the screen rectangle of the player body, in viewport (base) coordinates.
func player_screen_rect() -> Rect2:
	var feet := camera.unproject_position(player.global_position)
	var head := camera.unproject_position(player.global_position + Vector3(0, 1.8, 0))
	var left := camera.unproject_position(player.global_position + Vector3(-0.3, 0.9, 0))
	var right := camera.unproject_position(player.global_position + Vector3(0.3, 0.9, 0))
	var rect := Rect2(feet, Vector2.ZERO)
	for point: Vector2 in [head, left, right]:
		rect = rect.expand(point)
	return rect


## Returns the number of dynamic lights that light a part of the view.
func lights_in_view() -> int:
	var count := 1 if sun.visible else 0
	var planes := camera.get_frustum()
	for light in hem.lights_on():
		var inside := true
		for plane: Plane in planes:
			if plane.distance_to(light.global_position) > light.omni_range:
				inside = false
				break
		if inside:
			count += 1
	return count
