class_name PlaytestDriver
extends RefCounted
## The scenario API for the play tests (R34).
##
## A scenario changes the game only through input events. The functions
## state() and ui_report() only read the game.

## The scenario stops at the first failure when this is true.
var stop_on_failure := false
var failures: PackedStringArray = []
var steps: Array = []
var out_dir := ""
var phase := 1

var _tree: SceneTree
var _start_msec := 0
var _shot_count := 0


func _init(tree: SceneTree, output_dir: String, phase_number: int) -> void:
	_tree = tree
	out_dir = output_dir
	phase = phase_number
	_start_msec = Time.get_ticks_msec()
	_shot_count = (phase - 1) * 100


## The main scene node.
func main() -> Node:
	return _tree.get_first_node_in_group("main")


func viewport() -> Viewport:
	return _tree.root


# --- Log -----------------------------------------------------------------

## Records a step in log.json.
func step(text: String, ok := true, message := "") -> void:
	var entry := {"step": steps.size() + 1, "phase": phase, "name": text,
			"time_ms": Time.get_ticks_msec() - _start_msec, "result": "ok" if ok else "fail"}
	if message != "":
		entry.message = message
	steps.append(entry)
	print("[playtest] %s %s%s" % ["ok  " if ok else "FAIL", text, (": " + message) if message else ""])


## Records a failure with the message when the condition is false.
func expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	fail(message)
	return false


func fail(message: String) -> void:
	failures.append(message)
	step("expect", false, message)


# --- Waits ---------------------------------------------------------------

func wait_frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func wait_seconds(seconds: float) -> void:
	await _tree.create_timer(seconds).timeout


## Waits until "check" returns true. Records a failure at the timeout.
## Returns true when the check passed.
func wait_until(check: Callable, timeout_s := 10.0, what := "") -> bool:
	var end := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		if check.call():
			return true
		await _tree.process_frame
	if check.call():
		return true
	fail("wait timed out after %.1f s%s" % [timeout_s, (": " + what) if what else ""])
	return false


## Waits until the player stops walking and the camera stops moving.
## The camera must be still for 5 frames in a row: a new panel needs some
## frames for its height, and the camera moves when the height changes.
func wait_idle(timeout_s := 30.0) -> bool:
	var still := [0]
	return await wait_until(func() -> bool:
		var s := state()
		still[0] = still[0] + 1 if not s.walking and s.camera_settled else 0
		return still[0] >= 5, timeout_s, "the player and the camera stop")


# --- Input ---------------------------------------------------------------

## Converts a point in viewport (base) coordinates to a screen (window) pixel position.
func to_screen(viewport_pos: Vector2) -> Vector2:
	return viewport().get_final_transform() * viewport_pos


## Converts a screen (window) pixel position to viewport (base) coordinates.
func to_viewport(screen_pos: Vector2) -> Vector2:
	return viewport().get_final_transform().affine_inverse() * screen_pos


## Sends an InputEventScreenTouch press and release at a screen (window) pixel position.
func tap(pos: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = pos
	press.pressed = true
	Input.parse_input_event(press)
	await wait_frames(1)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = pos
	release.pressed = false
	Input.parse_input_event(release)
	await wait_frames(1)


## Sends a key press and release.
func key(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	await wait_frames(2)
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await wait_frames(2)


## Finds the visible node with the test ID. Returns null when there is none.
func find(test_id: String) -> Node:
	return _find_in(_tree.root, test_id)


func _find_in(node: Node, test_id: String) -> Node:
	if node.has_meta("test_id") and node.get_meta("test_id") == test_id and _is_shown(node):
		return node
	for child in node.get_children():
		var found := _find_in(child, test_id)
		if found:
			return found
	return null


func _is_shown(node: Node) -> bool:
	if node is CanvasItem:
		return (node as CanvasItem).is_visible_in_tree()
	if node is Node3D:
		if not (node as Node3D).is_visible_in_tree():
			return false
		var area := node as Area3D
		return area == null or area.collision_layer != 0
	return true


## Returns the screen point of a 3D position, or null when it is behind the camera.
func world_to_screen(pos: Vector3) -> Variant:
	var camera := viewport().get_camera_3d()
	if camera.is_position_behind(pos):
		return null
	return to_screen(camera.unproject_position(pos))


## Finds the node with the test ID and calculates its screen center. Returns
## an empty text and the point, or an error text that tells why the tap is
## not possible: the node is missing, off the screen, or covered.
func locate(test_id: String) -> Dictionary:
	var node := find(test_id)
	if node == null:
		return {"error": "no visible node has the test ID \"%s\"" % test_id}
	var view := viewport().get_visible_rect()
	var point := Vector2.ZERO
	if node is Control:
		var control := node as Control
		var rect := control.get_global_rect()
		point = rect.get_center()
		if not view.has_point(point):
			return {"error": "\"%s\" is off the screen at %s" % [test_id, point]}
		var scroll := _scroll_parent(control)
		if scroll and not scroll.get_global_rect().has_point(point):
			return {"error": "\"%s\" is scrolled out of its scroll area" % test_id}
	elif node is Node3D:
		var center := (node as Node3D).global_position
		for child in node.get_children():
			if child is CollisionShape3D:
				center = (child as CollisionShape3D).global_position
				break
		var camera := viewport().get_camera_3d()
		if camera.is_position_behind(center):
			return {"error": "\"%s\" is behind the camera" % test_id}
		point = camera.unproject_position(center)
		if not view.has_point(point):
			return {"error": "\"%s\" is off the screen at %s" % [test_id, point]}
	else:
		return {"error": "\"%s\" is not a Control or a Node3D" % test_id}
	return {"error": "", "point": point, "node": node}


## Checks that nothing covers the node at the point. Returns an error text or "".
func _check_cover(node: Node, point: Vector2, test_id: String) -> String:
	var motion := InputEventMouseMotion.new()
	motion.position = to_screen(point)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await wait_frames(1)
	if not is_instance_valid(node) or not _is_shown(node):
		return "\"%s\" is gone from the screen" % test_id
	var hovered := viewport().gui_get_hovered_control()
	if node is Control:
		if hovered == null or not (hovered == node or (node as Control).is_ancestor_of(hovered)):
			return "\"%s\" is covered by %s" % [test_id, _describe(hovered)]
		return ""
	if hovered != null:
		return "\"%s\" is covered by the control %s" % [test_id, _describe(hovered)]
	var hit: Dictionary = main().pick(point)
	if hit.get("node") != node:
		return "\"%s\" is covered by %s" % [test_id, _describe(hit.get("node"))]
	return ""


func _describe(node: Variant) -> String:
	if node == null:
		return "nothing"
	var n := node as Node
	if n.has_meta("test_id"):
		return "\"%s\"" % n.get_meta("test_id")
	return "%s (%s)" % [n.name, n.get_class()]


func _scroll_parent(control: Control) -> ScrollContainer:
	var parent := control.get_parent()
	while parent:
		if parent is ScrollContainer:
			return parent
		parent = parent.get_parent()
	return null


## Taps the node with the test ID. Returns an error text, or "" when the tap was sent.
## It does not record a failure. Use tap_id() for a normal step.
func try_tap_id(test_id: String) -> String:
	await _wait_stable(test_id)
	var where := locate(test_id)
	if where.error != "":
		return where.error
	var cover: String = await _check_cover(where.node, where.point, test_id)
	if cover != "":
		return cover
	await tap(to_screen(where.point))
	return ""


## Waits until a control is shown and its screen position does not change
## in two frames (a new panel needs some frames for its layout). It waits
## not more than 15 frames. It does not wait for a 3D node: a player taps a
## shop also when the camera moves.
func _wait_stable(test_id: String) -> void:
	var last := Vector2(-1, -1)
	for i in 15:
		var node := find(test_id)
		if node is Node3D:
			return
		var where := locate(test_id)
		if where.error == "" and where.point.distance_to(last) < 0.5:
			return
		last = where.get("point", Vector2(-1, -1))
		await wait_frames(1)


## Taps the node with the test ID. Records a failure when the node is
## missing, off the screen, or covered by another touchable object or control.
func tap_id(test_id: String) -> bool:
	var error: String = await try_tap_id(test_id)
	if error != "":
		fail("tap_id: " + error)
		return false
	step("tap " + test_id)
	return true


## Taps the floor at a 3D point. Records a failure when the point is off the
## screen, or when a control or a touchable object covers it.
func tap_floor(pos: Vector3) -> bool:
	var error: String = await try_tap_floor(pos)
	if error != "":
		fail("tap_floor: " + error)
		return false
	step("tap floor at (%.2f, %.2f)" % [pos.x, pos.z])
	return true


## With "wait_camera", it first waits (not more than 3 s) until the camera
## stops, so that the point on the screen does not move during the tap.
func try_tap_floor(pos: Vector3, wait_camera := true) -> String:
	if wait_camera:
		var end := Time.get_ticks_msec() + 3000
		var still := 0
		while still < 5 and Time.get_ticks_msec() < end:
			still = still + 1 if main().camera.is_settled() else 0
			await wait_frames(1)
	var camera := viewport().get_camera_3d()
	if camera.is_position_behind(pos):
		return "the point %s is behind the camera" % pos
	var point := camera.unproject_position(pos)
	if not viewport().get_visible_rect().has_point(point):
		return "the point %s is off the screen" % pos
	var motion := InputEventMouseMotion.new()
	motion.position = to_screen(point)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await wait_frames(1)
	var hovered := viewport().gui_get_hovered_control()
	if hovered != null:
		return "the point %s is covered by the control %s" % [pos, _describe(hovered)]
	var hit: Dictionary = main().pick(point)
	if hit.kind != "floor":
		return "the point %s is covered by %s" % [pos, _describe(hit.get("node"))]
	await tap(to_screen(point))
	return ""


## Walks with floor taps of 5 m or less until the player is at the X position.
func walk_toward(x: float, z := 0.5) -> bool:
	for i in 12:
		var pos: Vector3 = state().player
		var step := clampf(x - pos.x, -5.0, 5.0)
		if absf(x - pos.x) < 0.5:
			return true
		if not await tap_floor(Vector3(pos.x + step, 0, z)):
			return false
		await wait_idle()
	fail("the player does not come to x=%.2f" % x)
	return false


## Walks with floor taps until the node with the test ID is in the free part of the screen.
func bring_into_view(test_id: String) -> bool:
	for i in 8:
		var where := locate(test_id)
		if where.error == "" and state().free_rect.has_point(where.point):
			return true
		var node := find(test_id) as Node3D
		if node == null:
			break
		var pos: Vector3 = state().player
		var step := clampf(node.global_position.x - pos.x, -5.0, 5.0)
		if absf(step) < 0.5:
			break
		if not await tap_floor(Vector3(pos.x + step, 0, 0.5)):
			return false
		await wait_idle()
	fail("\"%s\" does not come into the free part of the screen" % test_id)
	return false


## Returns the screen point of a 3D position in viewport (base) coordinates.
func world_to_view(pos: Vector3) -> Vector2:
	return viewport().get_camera_3d().unproject_position(pos)


# --- Screenshots ---------------------------------------------------------

## Waits for the frame to draw, then saves a numbered PNG.
func screenshot(shot_name: String) -> void:
	await wait_frames(2)
	await RenderingServer.frame_post_draw
	_shot_count += 1
	var file := "%03d-%s.png" % [_shot_count, shot_name]
	var image := viewport().get_texture().get_image()
	var error := image.save_png(out_dir.path_join(file))
	step("screenshot " + file, error == OK, "" if error == OK else "cannot save: error %d" % error)


# --- Read-only state -------------------------------------------------------

## Returns a read-only copy of the game state for the scenario.
func state() -> Dictionary:
	var m: Node = main()
	var player: Node3D = m.player
	var pos := player.global_position
	var hem: Node = m.hem
	var bubble := false
	if hem.helper:
		bubble = hem.helper.is_bubble_visible()
	return {
		"time": GameState.minutes,
		"time_text": GameClock.format_time(GameState.minutes),
		"day": GameState.day,
		"cards": GameState.cards.duplicate(),
		"mode": m.mode,
		"player": pos,
		"walking": player.walking,
		"line": m.line_id if m.mode == "hem" else "",
		"choices": visible_choice_ids(),
		"near_spot": m.near_spot,
		"walked_total_m": GameState.walked_total_m,
		"clack_count": hem.clack_count,
		"bubble_visible": bubble,
		"lights_on": hem.lights_on().size(),
		"lights_in_view": m.lights_in_view(),
		"camera_settled": m.camera.is_settled(),
		"player_screen_rect": m.player_screen_rect(),
		"free_rect": m.free_rect,
		"top_bar_rect": m.top_bar.get_global_rect(),
		"panel_rect": m.talk_panel.get_global_rect(),
		"toast_visible": m.toast.visible,
		"sound": GameState.sound,
		"intro_done": bool(GameState.flag("intro_done")),
		"view_size": viewport().get_visible_rect().size,
	}


## Returns the test IDs of the visible choices of the active UI: the talk
## panel in the hẻm, or the clock sheet. The notebook has no choices.
func visible_choice_ids() -> Array[String]:
	var result: Array[String] = []
	var m: Node = main()
	var root: Control = m.talk_panel if m.mode == "hem" else m.clock_sheet
	if m.mode == "notebook":
		return result
	var controls: Array[Control] = []
	_collect_controls(root, controls)
	for control in controls:
		if control is Button and control.has_meta("test_id"):
			var id: String = control.get_meta("test_id")
			if id.begins_with("choice.") or (id.begins_with("clock.") and id != "clock.close"):
				result.append(id)
	return result


func _visible_controls() -> Array[Control]:
	var result: Array[Control] = []
	var root: Control = main().ui_root
	_collect_controls(root, result)
	return result


func _collect_controls(node: Node, result: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			result.append(child)
			_collect_controls(child, result)


## Returns the rectangle of each visible control, in viewport (base) coordinates,
## and tells if a label has more lines than it can show.
func ui_report() -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for control in _visible_controls():
		var entry := {
			"name": str(control.get_path()).get_file(),
			"path": str(control.get_path()),
			"class": control.get_class(),
			"test_id": control.get_meta("test_id", ""),
			"rect": control.get_global_rect(),
			"button": control is Button,
			"hidden_lines": false,
			"trimmed": false,
		}
		var scroll := _scroll_parent(control)
		if scroll:
			entry.scroll_rect = scroll.get_global_rect()
		if control is Label:
			var label := control as Label
			entry.lines = label.get_line_count()
			entry.visible_lines = label.get_visible_line_count()
			entry.hidden_lines = label.text != "" and label.get_visible_line_count() < label.get_line_count()
			if label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING or label.clip_text:
				var font := label.get_theme_font("font")
				var font_size := label.get_theme_font_size("font_size")
				var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				entry.trimmed = width > label.size.x + 0.5
		elif control is RichTextLabel:
			var rich := control as RichTextLabel
			entry.lines = rich.get_line_count()
			entry.visible_lines = rich.get_visible_line_count()
			entry.hidden_lines = rich.get_visible_line_count() < rich.get_line_count() \
					or rich.get_content_height() > rich.size.y + 1.0
		report.append(entry)
	return report
