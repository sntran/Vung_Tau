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


## Waits until the player stops walking and the view stops turning.
## The view must be still for 5 frames in a row: a new panel needs some
## frames for its height.
func wait_idle(timeout_s := 30.0) -> bool:
	var still := [0]
	return await wait_until(func() -> bool:
		var s := state()
		still[0] = still[0] + 1 if s.view_settled else 0
		return still[0] >= 5, timeout_s, "the player and the view stop")


# --- Input ---------------------------------------------------------------

## Converts a point in viewport (base) coordinates to a screen (window) pixel position.
func to_screen(viewport_pos: Vector2) -> Vector2:
	return viewport().get_final_transform() * viewport_pos


## Converts a screen (window) pixel position to viewport (base) coordinates.
func to_viewport(screen_pos: Vector2) -> Vector2:
	return viewport().get_final_transform().affine_inverse() * screen_pos


## Sends an InputEventScreenTouch press and release at a screen (window) pixel position.
## The press and the release go in the same frame: under lavapipe, one frame
## can take longer than the tap time limit (0.25 s).
func tap(pos: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = pos
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = pos
	release.pressed = false
	Input.parse_input_event(release)
	await wait_frames(2)


## A drag with a drag event at each frame (plan 0002, R26). "from" and "to"
## are screen (window) pixel positions.
func drag(from: Vector2, to: Vector2, seconds: float, index := 0) -> void:
	await drag_path([from, to], seconds, index)


## Sends a drag along the points (screen pixel positions), at the same speed
## on each part, during the seconds. The first point is the press, the last
## point is the release.
func drag_path(points: Array[Vector2], seconds: float, index := 0) -> void:
	var press := InputEventScreenTouch.new()
	press.index = index
	press.position = points[0]
	press.pressed = true
	Input.parse_input_event(press)
	await wait_frames(1)
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	var start := Time.get_ticks_msec()
	var last := points[0]
	while true:
		var t := clampf((Time.get_ticks_msec() - start) / maxf(seconds * 1000.0, 1.0), 0.0, 1.0)
		var pos := _point_on_path(points, total * t)
		var event := InputEventScreenDrag.new()
		event.index = index
		event.position = pos
		event.relative = pos - last
		event.screen_relative = event.relative
		Input.parse_input_event(event)
		last = pos
		await wait_frames(1)
		if t >= 1.0:
			break
	var release := InputEventScreenTouch.new()
	release.index = index
	release.position = points[points.size() - 1]
	release.pressed = false
	Input.parse_input_event(release)
	await wait_frames(1)


func _point_on_path(points: Array[Vector2], distance: float) -> Vector2:
	var left := distance
	for i in range(1, points.size()):
		var part := points[i - 1].distance_to(points[i])
		if left <= part and part > 0.0:
			return points[i - 1].lerp(points[i], left / part)
		left -= part
	return points[points.size() - 1]


## Touches a point on the left half, drags in the direction, holds, then
## releases (plan 0002, R26). A direction of length 1 is full speed.
func hold_stick(direction: Vector2, seconds: float) -> void:
	var start := await _free_point("stick")
	var radius := Joystick.RADIUS
	var target := start + direction.limit_length(1.0) * radius
	var s_start := to_screen(start)
	var s_target := to_screen(target)
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = s_start
	press.pressed = true
	Input.parse_input_event(press)
	await wait_frames(1)
	var last := s_start
	var timer: SceneTreeTimer = null
	while timer == null or timer.time_left > 0.0:
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = s_target
		event.relative = s_target - last
		event.screen_relative = event.relative
		Input.parse_input_event(event)
		last = s_target
		await wait_frames(1)
		# The time is game time. It starts when the stick moves the player, not
		# at the press. At a low frame rate, the game time is slower than the
		# real time.
		if timer == null:
			timer = _tree.create_timer(seconds, false, true)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = s_target
	release.pressed = false
	Input.parse_input_event(release)
	await wait_frames(1)


## Returns a point (base coordinates) in the zone ("stick" or "look") that no control covers.
func _free_point(zone: String) -> Vector2:
	var points: Array[Vector2] = await _free_points(zone)
	if points.is_empty():
		fail("no free point in the %s zone" % zone)
		return main().input_zones()[zone].get_center()
	return points[0]


## Returns the points of a grid in the zone that no control covers.
func _free_points(zone: String) -> Array[Vector2]:
	var rect: Rect2 = main().input_zones()[zone]
	var result: Array[Vector2] = []
	var fractions := [Vector2(0.45, 0.7), Vector2(0.5, 0.4), Vector2(0.3, 0.25), Vector2(0.15, 0.6),
			Vector2(0.7, 0.15), Vector2(0.1, 0.9)]
	if zone == "look":
		fractions = [Vector2(0.5, 0.2), Vector2(0.1, 0.15), Vector2(0.9, 0.1), Vector2(0.1, 0.5),
				Vector2(0.1, 0.85), Vector2(0.5, 0.08), Vector2(0.3, 0.3)]
	for f: Vector2 in fractions:
		var point := rect.position + rect.size * f
		var motion := InputEventMouseMotion.new()
		motion.position = to_screen(point)
		motion.global_position = motion.position
		Input.parse_input_event(motion)
		await wait_frames(1)
		if viewport().gui_get_hovered_control() == null:
			result.append(point)
	return result


## Turns the view with drags on the right half until the 3D point is at the
## center dot (within "tolerance" degrees). Returns true when it is there.
func look_at_point(point: Vector3, tolerance := 2.0, timeout_s := 30.0) -> bool:
	var end := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		var s := state()
		var to: Vector3 = point - s.eye
		var want_yaw := rad_to_deg(atan2(-to.x, -to.z))
		var want_pitch := rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()))
		var error_yaw: float = wrapf(want_yaw - float(s.yaw), -180.0, 180.0)
		var error_pitch: float = clampf(want_pitch, -Player.PITCH_LIMIT, Player.PITCH_LIMIT) - float(s.pitch)
		if absf(error_yaw) <= tolerance and absf(error_pitch) <= tolerance:
			return true
		var settings: Dictionary = s.settings
		var per_pixel := float(settings.look_sensitivity) * 0.2
		var invert := -1.0 if settings.invert_y else 1.0
		# look(-relative.x * k, -relative.y * k * invert): the drag that gives the error.
		var move := Vector2(-error_yaw / per_pixel, -error_pitch / per_pixel * invert)
		var view := viewport().get_visible_rect().size
		# The drag must end on the world, not on the phone or a button: at a
		# low frame rate, the drag has only its first and last points, and a
		# control under the last point takes the touch.
		var m: Node = main()
		var blocked: Array[Rect2] = [m.phone.button.get_global_rect().grow(10.0)]
		if m.phone.up:
			blocked.append(m.phone.device.get_global_rect().grow(10.0))
		if m.action_button.visible:
			blocked.append(m.action_button.get_global_rect().grow(10.0))
		var free_end := func(end: Vector2) -> Vector2:
			end = end.clamp(Vector2(5, 5), view - Vector2(5, 5))
			for rect: Rect2 in blocked:
				if rect.has_point(end):
					# Out of the control on the shorter way: up, or to the left.
					if end.y - rect.position.y < end.x - rect.position.x:
						end.y = rect.position.y - 1.0
					else:
						end.x = rect.position.x - 1.0
			return end
		# Start at the free point with the most room for the drag.
		var from := Vector2.ZERO
		var best_room := -1.0
		for candidate: Vector2 in await _free_points("look"):
			var drag_end: Vector2 = free_end.call(candidate + move)
			var room := (drag_end - candidate).length()
			if room > best_room:
				best_room = room
				from = candidate
		if best_room < 0.0:
			fail("no free point in the look zone")
			return false
		move = free_end.call(from + move) - from
		# A drag needs more than 12 px to turn the view. The turn is the
		# distance from the press to the release, so a short turn goes out
		# 16 px first and then back to the end point.
		var path: Array[Vector2] = [to_screen(from)]
		if move.length() < 14.0:
			var out := Vector2(0, 16) if from.y + 21.0 < view.y else Vector2(0, -16)
			path.append(to_screen(from + out))
		path.append(to_screen(from + move))
		await drag_path(path, 0.25)
		await wait_idle(5.0)
	fail("the view does not turn to %s" % point)
	return false


## Turns the view until the node with the test ID is at the center dot.
func look_at_id(test_id: String, timeout_s := 30.0) -> bool:
	var node := find(test_id) as Node3D
	if node == null:
		fail("look_at_id: no visible 3D node has the test ID \"%s\"" % test_id)
		return false
	var m: Node = main()
	var point := _node_center(node)
	var parts := test_id.split(".")
	if parts[0] == "spot" and m.hem.focus_points.has(parts[1]):
		point = m.hem.focus_points[parts[1]]
	return await look_at_point(point, 2.0, timeout_s)


## Sends gyroscope data through the sensor source of the game (plan 0002, R26).
## "rate" is in radians per second: x is the pitch rate, y is the yaw rate.
func gyro(rate: Vector3, seconds: float) -> void:
	var m: Node = main()
	if not m.sensor is ScriptedSensorSource:
		m.sensor = ScriptedSensorSource.new()
		m._apply_settings()
	var source := m.sensor as ScriptedSensorSource
	source.play(Vector2(rate.y, rate.x), seconds)
	# The game reads the source only when the gyroscope setting is on.
	if GameState.settings.gyro:
		while source.playing():
			await wait_frames(1)
	else:
		await wait_seconds(seconds)
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


func _button_parent(control: Control) -> Button:
	var parent := control.get_parent()
	while parent:
		if parent is Button:
			return parent
		parent = parent.get_parent()
	return null


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
	var where: Dictionary = await _tap_point(test_id)
	if where.error != "":
		return where.error
	await tap(to_screen(where.point))
	return ""


## Finds a point of the node that no other object or control covers.
## Returns {error, point}. The error is "" when there is a point.
func _tap_point(test_id: String) -> Dictionary:
	var where := locate(test_id)
	if where.error != "":
		return where
	var cover: String = await _check_cover(where.node, where.point, test_id)
	# The check waits some frames. At a low frame rate, the UI can change in that
	# time (for example the phrasebook after a new line).
	if not is_instance_valid(where.node):
		return {"error": "%s is gone" % test_id, "point": Vector2.ZERO}
	if cover != "" and where.node is Node3D:
		# A player taps a part of the object that they can see. Try the center
		# dot and the corners of the shape.
		for point: Vector2 in _other_points(where.node):
			var other: String = await _check_cover(where.node, point, test_id)
			if not is_instance_valid(where.node):
				return {"error": "%s is gone" % test_id, "point": Vector2.ZERO}
			if other == "":
				where.point = point
				cover = ""
				break
	where.error = cover
	return where


## Returns other screen points (base coordinates) on a 3D node: the center of
## the screen, and points between the center and the corners of its box shape.
func _other_points(node: Node3D) -> Array[Vector2]:
	var view := viewport().get_visible_rect()
	var camera := viewport().get_camera_3d()
	var result: Array[Vector2] = [view.get_center()]
	for child in node.get_children():
		var shape := child as CollisionShape3D
		if shape == null or not shape.shape is BoxShape3D:
			continue
		var half: Vector3 = (shape.shape as BoxShape3D).size * 0.35
		for corner: Vector3 in [Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(-1, -1, 1), Vector3(1, -1, 1),
				Vector3(-1, 1, -1), Vector3(1, 1, -1)]:
			var world := shape.global_transform * (corner * half)
			if not camera.is_position_behind(world):
				var point := camera.unproject_position(world)
				if view.has_point(point):
					result.append(point)
	return result


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


## With "wait_camera", it first waits (not more than 3 s) until the view
## stops, so that the point on the screen does not move during the tap.
func try_tap_floor(pos: Vector3, wait_camera := true) -> String:
	if wait_camera:
		var end := Time.get_ticks_msec() + 3000
		var still := 0
		while still < 5 and Time.get_ticks_msec() < end:
			still = still + 1 if state().view_settled else 0
			await wait_frames(1)
	var error: String = await check_floor_point(pos)
	if error != "":
		return error
	await tap(to_screen(viewport().get_camera_3d().unproject_position(pos)))
	return ""


## Returns "" when a tap can reach the floor at the 3D point, or the reason why not.
## It does not tap.
func check_floor_point(pos: Vector3) -> String:
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
	return ""


## Walks with tap to walk until the player is at the point (±0.5 m).
## It turns the view to the point with look drags first. Each tap goes not
## farther than "step" meters.
func walk_toward(x: float, z := 0.0, step := 6.0) -> bool:
	var stuck := 0
	for i in 16:
		var pos: Vector3 = state().player
		var to := Vector2(x - pos.x, z - pos.z)
		if to.length() < 0.5:
			return true
		var length := minf(to.length(), step)
		var target := Vector3(pos.x, pos.y, pos.z) + Vector3(to.x, 0, to.y).normalized() * length
		if to.length() > step:
			# On the way, walk on the middle line of the hẻm, away from the carts.
			target.z = clampf(target.z, -0.2, 0.6) if absf(target.x) < 30.0 else target.z
		await look_at_point(target + Vector3(0, 0.05, 0), 6.0, 25.0)
		# A cart or a person can cover the point. Then try a nearer point.
		var tapped := false
		for fraction: float in [1.0, 0.7, 0.45]:
			var point := Vector3(pos.x, pos.y, pos.z).lerp(target, fraction)
			if await check_floor_point(point) == "":
				await tap(to_screen(viewport().get_camera_3d().unproject_position(point)))
				tapped = true
				break
		if not tapped:
			# No floor point is free to tap: walk this part with the joystick.
			# In the hẻm, a cart can be between the player and the point. Then
			# go to the middle line first.
			if absf(pos.x) < 30.0 and absf(pos.z - 0.2) > 0.6:
				await stick_to(Vector3(pos.x, pos.y, 0.2))
			else:
				await stick_to(point_on_way(pos, target))
		await wait_idle()
		var now: Vector3 = state().player
		stuck = stuck + 1 if Vector2(now.x - pos.x, now.z - pos.z).length() < 0.2 else 0
		if stuck >= 3:
			break
	fail("the player does not come to (%.2f, %.2f)" % [x, z])
	return false


## Walks to the point with the joystick only: it turns the view to the point
## with look drags, then holds the joystick forward for the time of the walk.
func stick_to(point: Vector3) -> bool:
	# A long walk along the hẻm goes by the free lane in the middle, as a
	# player steers past the carts and the people at the sides (plan 0004, R11a).
	var hem: Hem = main().hem
	var start: Vector3 = state().player
	var lane_z := hem.helper_z - 0.6
	if absf(point.x - start.x) > 3.0 and start.x < hem.end_x and absf(start.z - lane_z) > 0.3:
		await _stick_straight(Vector3(start.x, start.y, lane_z))
		await _stick_straight(Vector3(clampf(point.x, hem.start_x, hem.end_x - 0.5), start.y, lane_z))
	return await _stick_straight(point)


func _stick_straight(point: Vector3) -> bool:
	for attempt in 3:
		var pos: Vector3 = state().player
		var flat := Vector2(point.x - pos.x, point.z - pos.z)
		if flat.length() < 0.4:
			return true
		await look_at_point(Vector3(point.x, pos.y + Player.EYE_HEIGHT, point.z), 1.5)
		await hold_stick(Vector2(0, -1), flat.length() / Player.WALK_SPEED)
		await wait_idle()
	var end: Vector3 = state().player
	return Vector2(point.x - end.x, point.z - end.z).length() < 0.6


func point_on_way(from: Vector3, to: Vector3) -> Vector3:
	return Vector3(to.x, from.y, to.z)


## Returns the joystick direction that walks in the world direction (on the ground).
func stick_for(world_direction: Vector3) -> Vector2:
	var yaw := deg_to_rad(float(state().yaw))
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	# hold_stick() takes screen directions: up (negative y) is forward.
	return Vector2(world_direction.dot(right), -world_direction.dot(forward))


## Turns the view and walks until the node with the test ID is at 12 m or
## less and free to tap.
func bring_into_view(test_id: String) -> bool:
	var last_error := ""
	for i in 8:
		var node := find(test_id) as Node3D
		if node == null:
			break
		var center := _node_center(node)
		var pos: Vector3 = state().player
		var flat := Vector2(center.x - pos.x, center.z - pos.z)
		if flat.length() > 12.0:
			var target := Vector3(pos.x, 0, pos.z) + Vector3(flat.x, 0, flat.y).normalized() * 8.0
			if not await walk_toward(target.x, target.z, 8.0):
				return false
			continue
		await look_at_id(test_id)
		var where: Dictionary = await _tap_point(test_id)
		last_error = where.error
		if where.error == "":
			return true
		# Something covers the node: walk to a point in front of it, then try again.
		var main_node: Node = main()
		if center.x < main_node.hem.end_x:
			var front_z := 0.4 if i % 2 == 0 else -0.3
			await walk_toward(center.x + (1.5 if i % 2 == 0 else -1.5), front_z, 6.0)
		else:
			var near := Vector3(pos.x, 0, pos.z) + Vector3(flat.x, 0, flat.y).normalized() * minf(3.0, flat.length() - 2.0)
			await walk_toward(near.x, near.z, 6.0)
	fail("\"%s\" does not come into the view (%s)" % [test_id, last_error])
	return false


func _node_center(node: Node3D) -> Vector3:
	for child in node.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).global_position
	return node.global_position


## Returns the screen point of a 3D position in viewport (base) coordinates.
func world_to_view(pos: Vector3) -> Vector2:
	return viewport().get_camera_3d().unproject_position(pos)


## Waits at the start of a scenario. The intro of plan 0001 is now the first
## message of cô Nga (plan 0003): it needs no answer.
func skip_intro() -> void:
	await wait_idle()


# --- The phone (plan 0003) -----------------------------------------------

## Raises the phone with a tap on the phone button.
func raise_phone() -> bool:
	if main().phone.up:
		return true
	await tap_id("phone.button")
	return expect(main().phone.up, "the phone is up")


## Lowers the phone with a tap on the phone button.
func lower_phone() -> bool:
	if not main().phone.up:
		return true
	await tap_id("phone.button")
	return expect(not main().phone.up, "the phone is down")


## Raises the phone and opens the app ("listen", "lens", "messages",
## "notebook", "clock", or "settings") from the home screen.
func open_app(app: String) -> bool:
	if not await raise_phone():
		return false
	var phone: Phone = main().phone
	if phone.app == app:
		return true
	if phone.app != "":
		await tap_id("phone.home")
	await tap_id("phone.app." + app)
	await wait_frames(3)
	return expect(phone.app == app, "the app %s is open, not \"%s\"" % [app, phone.app])


## Scrolls the app so that the control with the test ID shows (as a player
## scrolls with a finger).
func show_in_phone(test_id: String) -> void:
	var control := find(test_id) as Control
	if control == null:
		return
	var scroll := _scroll_parent(control)
	if scroll:
		scroll.ensure_control_visible(control)
		await wait_frames(3)


## Taps a control of the phone with the test ID. The phone must be up.
func tap_phone_id(test_id: String) -> bool:
	if not main().phone.up:
		fail("tap_phone_id(%s): the phone is down" % test_id)
		return false
	await show_in_phone(test_id)
	var ok := await tap_id(test_id)
	await wait_frames(3)
	return ok


## The visible subtitle: {speaker, lines, line_id, caption}, or an empty dictionary.
func subtitle() -> Dictionary:
	var subtitles: Subtitles = main().subtitles
	return subtitles.current.duplicate() if subtitles.visible else {}


## The entries of the Listen app: [{speaker, vi, en}] (the speaker as the app shows it).
func transcript() -> Array:
	return main().transcript_view()


## True while the person speaks a line (the audio plays at the head).
func audio_playing(npc_id: String) -> bool:
	var m: Node = main()
	return m.is_speaking(npc_id) and m.hem.npcs[npc_id].voice.playing


## Waits until the person speaks a line. Returns the line ID, or "" at the timeout.
func wait_line(npc_id: String, timeout_s := 15.0) -> String:
	var m: Node = main()
	if await wait_until(func() -> bool: return m.is_speaking(npc_id), timeout_s, "%s speaks" % npc_id):
		return m.speech[npc_id].line
	return ""


## Waits until the talk waits for an answer (the phrasebook shows the replies).
func wait_answer(timeout_s := 20.0) -> bool:
	var m: Node = main()
	return await wait_until(func() -> bool: return not m.talk.is_empty() and m.talk.state == "answer",
			timeout_s, "the person waits for an answer")


## Turns to the person, taps the person, and waits for the first line.
## Returns the line ID, or "".
func talk_to(npc_id: String) -> String:
	await bring_into_view("npc." + npc_id)
	if not await tap_id("npc." + npc_id):
		return ""
	return await wait_line(npc_id, 30.0)


## Answers with a reply of the phrasebook: "mode" is "play", "say", or
## "english". For "say", it also taps "I said it". The reply "say_again" is
## the "say again" phrase.
func answer(reply_id: String, mode: String) -> bool:
	if reply_id != "say_again" and not await wait_answer():
		return false
	if not await open_app("listen"):
		return false
	if not await tap_phone_id("reply.%s.%s" % [reply_id, mode]):
		return false
	if mode == "say":
		return await tap_phone_id("said.done")
	return true


## Waits until no person speaks and the talk does not wait for a step.
func wait_quiet(timeout_s := 20.0) -> bool:
	var m: Node = main()
	return await wait_until(func() -> bool: return m.speech.is_empty() and m._steps.is_empty(), timeout_s,
			"the people are quiet")


## Returns the collision objects that the player capsule goes into by more
## than 2 cm. A correct game returns an empty list. It only reads the physics.
func player_overlaps() -> Array:
	var player: Player = main().player
	var capsule := CapsuleShape3D.new()
	capsule.radius = Player.RADIUS - 0.02
	capsule.height = Player.HEIGHT - 0.04
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis(), player.global_position + Vector3(0, Player.HEIGHT / 2.0, 0))
	query.collision_mask = Layers.SOLID | Layers.MOVING
	var hits := player.get_world_3d().direct_space_state.intersect_shape(query, 8)
	var names := []
	for hit: Dictionary in hits:
		names.append(str((hit.collider as Node).get_path()))
	return names


## Returns the distance from the eyes to the first solid object in the view
## direction, or INF. It only reads the physics.
func view_distance_to_solid() -> float:
	var player: Player = main().player
	var from := player.eye_position()
	var query := PhysicsRayQueryParameters3D.create(from, from + player.view_forward() * 50.0,
			Layers.SOLID | Layers.MOVING)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return INF
	return from.distance_to(hit.position)


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
	var phone: Phone = m.phone
	var talk: Dictionary = m.talk
	var speaking := {}
	for npc_id: String in m.speech:
		speaking[npc_id] = m.speech[npc_id].line
	return {
		"time": GameState.minutes,
		"time_text": GameClock.format_time(GameState.minutes),
		"day": GameState.day,
		"cards": GameState.cards.duplicate(),
		"player": pos,
		"walking": player.walking,
		"talk_npc": talk.get("npc", ""),
		"talk_state": talk.get("state", ""),
		"talk_line": talk.get("line", ""),
		"speaking": speaking,
		"subtitle": subtitle(),
		"listen_on": m.listen_on,
		"transcript_size": m.transcript.size(),
		"phone_up": phone.up,
		"app": phone.app,
		"phone_rect": phone.device.get_global_rect() if phone.up else Rect2(),
		"phone_button_rect": phone.button.get_global_rect(),
		"phone_dot": phone.has_dot(),
		"notification": phone.last_notification,
		"banner_visible": phone.banner_visible(),
		"messages": GameState.messages.map(func(message: Dictionary) -> String: return message.id),
		"unread": GameState.unread,
		"phrases": GameState.phrases.duplicate(true),
		"met": GameState.met.duplicate(),
		"subtitle_rect": m.subtitles.get_global_rect() if m.subtitles.visible else Rect2(),
		"stick_zone": m.stick_zone(),
		"walked_total_m": GameState.walked_total_m,
		"clack_count": hem.clack_count,
		"clack_time": hem.clack_time,
		"tv_on": hem.tv.playing,
		"lights_on": hem.lights_on().size(),
		"lights_in_view": m.lights_in_view(),
		"view_settled": _view_settled(m),
		"yaw": player.yaw + player.gyro_yaw,
		"pitch": player.pitch + player.gyro_pitch,
		"target_yaw": player.target_yaw,
		"gyro_yaw": player.gyro_yaw,
		"gyro_pitch": player.gyro_pitch,
		"eye": player.eye_position(),
		"on_floor": player.is_on_floor(),
		"focus": m.focus_id,
		"action_visible": m.action_button.visible,
		"action_verb": m.action_button.text if m.action_button.visible else "",
		"joystick_visible": m.joystick.visible,
		"settings": GameState.settings.duplicate(),
		"fov": player.camera.fov,
		"sound": GameState.sound,
		"intro_done": bool(GameState.flag("intro_done")),
		"view_size": viewport().get_visible_rect().size,
		"shutters": _shutters(hem),
		"boats_in": hem.beach.boats_in.visible,
		"exercisers": hem.beach.exercisers.visible,
	}


## True when the player does not walk and the view does not turn.
func _view_settled(m: Node) -> bool:
	var player: Player = m.player
	return not player.walking and player.move_input == Vector2.ZERO \
			and absf(wrapf(player.target_yaw - player.yaw, -180.0, 180.0)) < 0.2 \
			and absf(player.target_pitch - player.pitch) < 0.2 and player.velocity.length() < 0.05


## Returns the shutter position of each shop: "open", "half", or "closed".
func _shutters(hem: Node) -> Dictionary:
	var names := {TubeHouse.Shutter.OPEN: "open", TubeHouse.Shutter.HALF: "half",
			TubeHouse.Shutter.CLOSED: "closed"}
	var result := {}
	for lot: Dictionary in Content.layout.lots:
		if lot.get("ground") == "shop" and lot.has("spot"):
			result[lot.spot] = names[hem.houses[lot.id].shutter]
	return result


## Returns the test IDs of the visible buttons of the open phone app.
func visible_choice_ids() -> Array[String]:
	var result: Array[String] = []
	var phone: Phone = main().phone
	if not phone.up:
		return result
	var controls: Array[Control] = []
	_collect_controls(phone.device, controls)
	for control in controls:
		if control is Button and control.has_meta("test_id"):
			result.append(control.get_meta("test_id"))
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
		# The text of a button must be inside the button.
		var button := _button_parent(control)
		if button and (control is Label) and (control as Label).text != "":
			entry.outside_button = not button.get_global_rect().grow(0.5).encloses(control.get_global_rect())
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


# --- Fixed views (plan 0004) --------------------------------------------------

## Puts the camera at a fixed viewpoint for a screenshot (PT-25, PT-28, PT-32).
## The player stops: physics does not move it until fly_end(). This is a test
## setup step, the same as --start-time.
func fly_to(eye: Vector3, look_at: Vector3) -> void:
	var player: Player = main().player
	player.set_physics_process(false)
	var to := look_at - eye
	var yaw := rad_to_deg(atan2(-to.x, -to.z))
	var pitch := rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()))
	player.place(eye - Vector3(0, Player.EYE_HEIGHT, 0), yaw, pitch)
	await wait_frames(2)


func fly_end() -> void:
	main().player.set_physics_process(true)


## The fixed views of the hẻm for the look review and the budget (PT-25, PT-32):
## [{name, eye, target}].
func hem_views() -> Array[Dictionary]:
	var hem: Hem = main().hem
	var half := hem.hem_width / 2.0
	var mid := (hem.start_x + hem.end_x) / 2.0
	return [
		{"name": "along", "eye": Vector3(hem.start_x + 1.0, 1.6, 0.2), "target": Vector3(hem.end_x, 3.0, -0.2)},
		{"name": "back", "eye": Vector3(hem.end_x - 1.0, 1.6, -0.2), "target": Vector3(hem.start_x, 4.0, 0.2)},
		{"name": "fronts", "eye": Vector3(mid, 1.6, half - 0.4), "target": Vector3(mid + 3.0, 6.0, -half)},
		{"name": "roofs", "eye": Vector3(mid - 14.0, 26.0, 18.0), "target": Vector3(mid, 4.0, 0.0)},
	]


# --- Keyboard, mouse, and gamepad (plan 0004) ----------------------------------

## Presses a key. With "hold_s", the key stays down for that time.
func key(keycode: Key, hold_s := 0.0) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = keycode
	down.keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	if hold_s > 0.0:
		await wait_seconds(hold_s)
	else:
		await wait_frames(2)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await wait_frames(2)
	step("key %s" % OS.get_keycode_string(keycode))


## A click of a real mouse (not a touch) at a screen point.
func mouse_click(screen: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.device = 0
		event.button_index = button
		event.pressed = pressed
		event.position = screen
		event.global_position = screen
		Input.parse_input_event(event)
		await wait_frames(2)
	step("mouse click %s at (%d, %d)" % ["right" if button == MOUSE_BUTTON_RIGHT else "left", screen.x, screen.y])


## A movement of a real mouse, in pixels.
func mouse_move(relative: Vector2, steps := 6) -> void:
	for i in steps:
		var event := InputEventMouseMotion.new()
		event.device = 0
		event.relative = relative / steps
		event.position = to_screen(viewport().get_visible_rect().size / 2.0)
		Input.parse_input_event(event)
		await wait_frames(1)
	step("mouse move (%d, %d)" % [relative.x, relative.y])


## Presses a gamepad button.
func pad_button(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await wait_frames(2)
	step("gamepad button %d" % button)


## Holds a gamepad stick (left or right) in a direction for a time.
func pad_stick(right: bool, direction: Vector2, seconds: float) -> void:
	var axes := [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y] if right else [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]
	for value: Vector2 in [direction, Vector2.ZERO]:
		for i in 2:
			var event := InputEventJoypadMotion.new()
			event.device = 0
			event.axis = axes[i]
			event.axis_value = value[i]
			Input.parse_input_event(event)
		if value != Vector2.ZERO:
			await wait_seconds(seconds)
	await wait_frames(2)
	step("gamepad %s stick (%.1f, %.1f) for %.1f s" % ["right" if right else "left", direction.x, direction.y, seconds])


## Turns the view with a real mouse (the cursor is captured) until the 3D
## point is at the center dot. Returns true when it is there.
func mouse_look_at(point: Vector3, tolerance := 2.0, timeout_s := 30.0) -> bool:
	var end := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		var s := state()
		var to: Vector3 = point - s.eye
		var want_yaw := rad_to_deg(atan2(-to.x, -to.z))
		var want_pitch := rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()))
		var error_yaw: float = wrapf(want_yaw - float(s.yaw), -180.0, 180.0)
		var error_pitch: float = clampf(want_pitch, -Player.PITCH_LIMIT, Player.PITCH_LIMIT) - float(s.pitch)
		if absf(error_yaw) <= tolerance and absf(error_pitch) <= tolerance:
			return true
		var per_pixel := float(s.settings.mouse_sensitivity) * DesktopControls.MOUSE_DEG_PER_PIXEL
		var invert := -1.0 if s.settings.invert_y else 1.0
		await mouse_move(Vector2(-error_yaw / per_pixel, -error_pitch / per_pixel * invert))
		await wait_idle(5.0)
	fail("the mouse does not turn the view to %s" % point)
	return false


## The center of a control with the test ID, in screen coordinates.
func screen_center_of(test_id: String) -> Vector2:
	var control := find(test_id) as Control
	return to_screen(control.get_global_rect().get_center()) if control else Vector2(-1, -1)


## Turns the view with the right stick of a gamepad until the 3D point is at
## the center dot. Returns true when it is there.
func pad_look_at(point: Vector3, tolerance := 3.0, timeout_s := 40.0) -> bool:
	var end := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		var s := state()
		var to: Vector3 = point - s.eye
		var want_yaw := rad_to_deg(atan2(-to.x, -to.z))
		var want_pitch := rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()))
		var error_yaw: float = wrapf(want_yaw - float(s.yaw), -180.0, 180.0)
		var error_pitch: float = clampf(want_pitch, -Player.PITCH_LIMIT, Player.PITCH_LIMIT) - float(s.pitch)
		if absf(error_yaw) <= tolerance and absf(error_pitch) <= tolerance:
			return true
		var speed := float(s.settings.look_sensitivity) * DesktopControls.STICK_DEG_PER_SECOND
		var invert := -1.0 if s.settings.invert_y else 1.0
		# One axis at a time. A small error uses a small push of the stick, so
		# that one frame at a low frame rate does not turn too far.
		var error := error_yaw if absf(error_yaw) > tolerance else error_pitch
		# The turn rate after the deadzone (see DesktopControls._stick()).
		var rate := clampf(absf(error) / 40.0, 0.03, 0.6)
		var push := DesktopControls.STICK_DEADZONE + rate * (1.0 - DesktopControls.STICK_DEADZONE)
		var seconds := absf(error) / (speed * rate)
		if absf(error_yaw) > tolerance:
			await pad_stick(true, Vector2(-signf(error_yaw) * push, 0), seconds)
		else:
			await pad_stick(true, Vector2(0, -signf(error_pitch) * invert * push), seconds)
		await wait_idle(5.0)
	fail("the right stick does not turn the view to %s" % point)
	return false


## Presses the D-pad until the gamepad selects the phone button with the test ID.
func pad_select(test_id: String) -> bool:
	var phone: Phone = main().phone
	for i in phone.pad_buttons().size() + 1:
		var selected := phone.pad_selected()
		if selected != null and selected.get_meta("test_id", "") == test_id:
			return true
		await pad_button(JOY_BUTTON_DPAD_DOWN)
	fail("the D-pad does not select %s" % test_id)
	return false
