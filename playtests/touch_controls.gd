extends RefCounted
# PT-81 touch_controls (plan 0018, D7, R3). At 2400x1080 and 720x1280 on the
# Mobile renderer at Bãi Trước on Low (run 1), and at 1280x720 on the
# Compatibility renderer (the web build) in the test street (run 2: the
# Vũng Tàu world on the Compatibility renderer leaves two textures of
# 349 524 bytes at the quit, also on main, an open defect of its own; the
# page of the web build does not quit). After a touch, the joystick shows at its rest
# place (light), and it does not cover the phone button, the subtitles, the
# center dot, or the action button. A touch drag walks the player. On the
# scooter of the start, the drag up rides, down brakes, and to the sides
# turns; the button "Get off" takes the place of the action button and gets
# the player off. While the player rides, the button is not in the middle
# third of the view (the box of the middle third of the width and of the
# height, around the center dot: the road ahead; report 0018, D-0018-02), at
# each size, and a tap at a speed gives "Slow down to get off". After an input of the mouse the joystick goes away, and
# after a touch it comes back. A screenshot of each state.
# sizes: 2400x1080 720x1280 1280x720
# phase: --world=vung_tau --start=bai_truoc --start-time=12:00 --quality=low
# phase: --start-time=12:00 --quality=low --renderer=compatibility


## As Main.RIDE_HINT_S: the hint of the first rides shows 6 s at most (D12).
const RIDE_HINT_S := 6.0

func run(d: PlaytestDriver) -> void:
	# Run 1 at 2400x1080 and 720x1280 (Mobile), run 2 at 1280x720 (Compatibility).
	var web_size := d.main().get_window().size == Vector2i(1280, 720)
	if (d.phase == 2) != web_size:
		d.step("run %d is not for this size" % d.phase)
		return
	if d.world() != null:
		await d.wait_ground(120.0)
	await d.wait_frames(5)
	var s := d.state()
	# A short look drag: the last input is a touch.
	var look: Rect2 = d.main().input_zones().look
	var p := d.to_screen(look.get_center())
	await d.drag(p, p + Vector2(30, 0), 0.3, 1)
	await d.wait_frames(3)
	s = d.state()
	d.expect(s.touch_mode and s.stick_visible and s.stick_resting, "after a touch the joystick shows at its rest place (D7): touch %s, visible %s, rest %s" % [
			s.touch_mode, s.stick_visible, s.stick_resting])
	_check_room(d, "rest")
	await d.screenshot("stick_rest")
	# The joystick under the thumb, and a walk.
	var from: Vector3 = s.player
	await _hold_and_shoot(d, Vector2(0, -1), 1.5, "stick_walk")
	s = d.state()
	var walked := Vector2(s.player.x - from.x, s.player.z - from.z).length()
	d.expect(walked > 1.0, "a touch drag walks the player: %.2f m" % walked)
	d.expect(s.stick_visible and s.stick_resting, "after the drag the joystick is at its rest place again")
	# The scooter of the start.
	var riding: Riding = d.main().riding
	var index := riding.scooters.nearest(s.player, 14.0)
	if not d.expect(index >= 0, "a scooter stands near the start"):
		return
	var scooter: Transform3D = riding.scooters.parked[index].at
	# The side of the scooter nearer to the player (in the hẻm, the other side is the wall).
	var left := Vector3.UP.cross(scooter.basis.z.normalized()).normalized()
	var beside := scooter.origin + left * 1.1
	if (scooter.origin - left * 1.1).distance_to(s.player) < beside.distance_to(s.player):
		beside = scooter.origin - left * 1.1
	var walk := PackedVector3Array([s.player, beside])
	await d.stick_along(walk, PlaytestDriver.route_distance(walk, beside), Callable(), 12.0, true)
	await d.look_at_point(scooter.origin + Vector3(0, 0.6, 0), 2.0)
	await d.wait_frames(3)
	s = d.state()
	d.expect(s.action_verb == Riding.verb("scooter_ride"), "the action button is \"Ride\" at the scooter: \"%s\"" % s.action_verb)
	_check_room(d, "ride_button")
	await d.screenshot("ride_button")
	await d.tap_id("action")
	await d.wait_frames(5)
	s = d.state()
	if not d.expect(s.riding, "the action button gets the player on the scooter"):
		return
	d.expect(s.action_verb == Riding.verb("scooter_get_off"), "on the scooter the button is \"Get off\": \"%s\"" % s.action_verb)
	_check_room(d, "riding")
	await d.screenshot("get_off_button")
	# D12, R13: on the first ride the hint shows by the joystick; it goes away
	# when the rider has used each direction (up, a side, down), or after 6 s.
	var hint := Content.ui_text("scooter_hint_touch")
	var on_at: float = Playtest.frame_s
	d.expect(hint != "" and s.hint_text == hint, "on the first ride the hint shows: \"%s\" (D12)" % s.hint_text)
	_check_room(d, "ride_hint")
	await d.screenshot("ride_hint")
	for step: Vector2 in [Vector2(0, -1), Vector2(1, 0)]:
		await _hold_and_shoot(d, step, 0.3, "")
		var shown: bool = d.state().hint_text == hint
		var seconds: float = Playtest.frame_s - on_at
		d.step("after the push %s: the hint shows %s, %.1f s after the rider got on" % [step, shown, seconds])
		d.expect(shown or seconds >= RIDE_HINT_S, "before each direction is used and before 6 s, the hint still shows (%.1f s)" % seconds)
	await _hold_and_shoot(d, Vector2(0, 1), 0.3, "")
	s = d.state()
	d.expect(s.hint_text == "", "after up, a side, and down, the hint goes away (D12): \"%s\"" % s.hint_text)
	# Up rides.
	await _hold_and_shoot(d, Vector2(0, -1), 3.0, "drag_up_rides")
	s = d.state()
	d.expect(s.speed_kmh > 8.0, "the drag up rides: %.1f km/h" % s.speed_kmh)
	# "Get off" at a speed: the player stays on, and the caption says to slow down (D9).
	# The screenshot in the first frame after the tap (report 0018, section 7.3).
	var moving_kmh: float = s.speed_kmh
	await d.tap_id("action")
	await d.screenshot("get_off_at_speed")
	s = d.state()
	var caption: Dictionary = d.subtitle()
	var slow_down := Content.ui_text("scooter_too_fast")
	d.expect(s.riding, "a tap on \"Get off\" at %.1f km/h does not get the player off (D9)" % moving_kmh)
	d.expect(str(caption.get("text", caption.get("vi", ""))).contains(slow_down) or str(caption).contains(slow_down),
			"a tap on \"Get off\" at a speed shows \"%s\": %s" % [slow_down, caption])
	_check_room(d, "get_off_at_speed")
	# To the side turns.
	var heading: float = s.heading
	await _hold_and_shoot(d, Vector2(0.8, -0.6), 1.5, "drag_right_turns")
	s = d.state()
	var turned := wrapf(s.heading - heading, -180.0, 180.0)
	d.expect(turned < -5.0, "the drag to the right turns to the right: %.1f°" % turned)
	# Down brakes.
	await _hold_and_shoot(d, Vector2(0, 1), 3.0, "drag_down_brakes")
	s = d.state()
	d.expect(absf(s.speed_kmh) < 2.0, "the drag down brakes: %.1f km/h" % s.speed_kmh)
	# Get off.
	await d.tap_id("action")
	await d.wait_frames(5)
	s = d.state()
	d.expect(not s.riding, "\"Get off\" gets the player off")
	await d.screenshot("got_off")
	# A mouse input: the joystick goes away; a touch: it comes back.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = p
	click.global_position = p
	click.pressed = true
	Input.parse_input_event(click)
	await d.wait_frames(2)
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await d.wait_frames(3)
	s = d.state()
	d.expect(not s.touch_mode and not s.stick_visible, "after a click of the mouse the joystick goes away (D7)")
	await d.screenshot("after_mouse")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await d.drag(p, p + Vector2(-30, 0), 0.3, 1)
	await d.wait_frames(3)
	s = d.state()
	d.expect(s.touch_mode and s.stick_visible and s.stick_resting, "after a touch the joystick comes back at its rest place")
	await d.screenshot("after_touch")


## Holds the joystick in the direction for the seconds, with a screenshot
## while the thumb holds it.
func _hold_and_shoot(d: PlaytestDriver, direction: Vector2, seconds: float, shot: String) -> void:
	var rest: Vector2 = d.main().stick_rest()
	var start := d.to_screen(rest)
	var target := d.to_screen(rest + direction.limit_length(1.0) * Joystick.RADIUS)
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = start
	press.pressed = true
	Input.parse_input_event(press)
	await d.wait_frames(1)
	var timer: SceneTreeTimer = null
	var shot_taken := false
	while timer == null or timer.time_left > 0.0:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = target
		drag.relative = target - start
		drag.screen_relative = drag.relative
		Input.parse_input_event(drag)
		await d.wait_frames(1)
		if timer == null:
			timer = d.main().get_tree().create_timer(seconds, false, true)
		elif shot != "" and not shot_taken and timer.time_left < seconds / 2.0:
			shot_taken = true
			var s := d.state()
			d.expect(s.stick_visible and not s.stick_resting, "%s: the joystick is under the thumb" % shot)
			_check_room(d, shot)
			await d.screenshot(shot)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = target
	release.pressed = false
	Input.parse_input_event(release)
	await d.wait_frames(2)


## R3: the joystick does not cover the phone button, the subtitles, the
## center dot, or the action button.
func _check_room(d: PlaytestDriver, where: String) -> void:
	var s := d.state()
	var m := d.main()
	if not s.stick_visible:
		return
	var stick: Rect2 = s.stick_rect
	var others := {"the phone button": s.phone_button_rect, "the subtitles": s.subtitle_rect,
			"the center dot": m.center_dot.get_global_rect(),
			"the action button": m.action_button.get_global_rect() if m.action_button.visible else Rect2()}
	if s.phone_up:
		others["the phone"] = s.phone_rect
	# R13, R14: the hint and the name of the road are clear of the other things.
	for label: String in ["hint", "road_sign"]:
		var r: Rect2 = s["%s_rect" % label]
		if r.size == Vector2.ZERO:
			continue
		var blocks := {"the joystick": stick, "the phone button": s.phone_button_rect, "the subtitles": s.subtitle_rect,
				"the action button": m.action_button.get_global_rect() if m.action_button.visible else Rect2(),
				"the center dot": m.center_dot.get_global_rect()}
		for other: String in blocks:
			var o: Rect2 = blocks[other]
			if o.size != Vector2.ZERO:
				d.expect(not r.intersects(o), "%s: the %s %s is clear of %s %s (R13, R14)" % [where, label.replace("_", " "), r, other, o])
		var view: Vector2 = m.ui_root.get_viewport_rect().size
		d.expect(Rect2(Vector2.ZERO, view).encloses(r), "%s: the %s %s is on the screen %s" % [where, label.replace("_", " "), r, view])
	# D-0018-02: on the scooter, "Get off" is out of the middle third of the view.
	if s.riding and m.action_button.visible:
		var view: Vector2 = m.ui_root.get_viewport_rect().size
		var middle := Rect2(view / 3.0, view / 3.0)
		var button: Rect2 = m.action_button.get_global_rect()
		d.expect(not button.intersects(middle), "%s: \"Get off\" %s is not in the middle third of the view %s, at %.1f km/h (D-0018-02)" % [
				where, button, middle, s.speed_kmh])
		d.expect(not button.intersects(s.subtitle_rect) or s.subtitle_rect.size == Vector2.ZERO,
				"%s: \"Get off\" %s does not cover the subtitles %s" % [where, button, s.subtitle_rect])
		d.expect(not button.intersects(s.phone_button_rect), "%s: \"Get off\" %s does not cover the phone button %s" % [
				where, button, s.phone_button_rect])
	for name: String in others:
		var r: Rect2 = others[name]
		if r.size == Vector2.ZERO:
			continue
		d.expect(not stick.intersects(r), "%s: the joystick %s does not cover %s %s (R3)" % [where, stick, name, r])
