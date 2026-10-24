extends RefCounted
# PT-17 fp_layout. For each screen size: show the phone and each app, a
# subtitle, and the action button (plan 0003). No control is off the screen.
# No control covers the center dot. The subtitles are clear of the phone and
# the joystick zone. No button is in the joystick zone or the look zone in a
# way that a joystick touch or a look drag starts on it.
# sizes: 1280x720 2400x1080 1920x1080 720x1280
# compatibility: 1280x720
# The scenario has 2 runs, so that each run is shorter than 180 s at
# 2400×1080 under lavapipe. The second run starts from the save file of the
# first run.
# phase: --start-time=06:00
# phase:


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	if d.phase == 1:
		await _first_run(d)
	else:
		await _second_run(d)


func _first_run(d: PlaytestDriver) -> void:
	await PlaytestLayout.check(d, "start")
	await PlaytestLayout.check_buttons_take_touches(d, "start")
	# The action button: look at Bà Tư.
	await d.look_at_id("npc.batu")
	await PlaytestLayout.check(d, "action_talk")
	await PlaytestLayout.check_buttons_take_touches(d, "action_talk")
	await d.tap_id("action")
	await d.wait_line("batu")
	await d.wait_frames(3)
	await PlaytestLayout.check(d, "subtitle")
	await d.open_app("listen")
	await d.wait_answer()
	await PlaytestLayout.check(d, "phrasebook")
	await PlaytestLayout.check_buttons_take_touches(d, "phrasebook")
	await d.answer("chua", "play")
	await d.wait_line("batu")
	await d.wait_frames(3)
	await PlaytestLayout.check(d, "subtitle_phone_up")


func _second_run(d: PlaytestDriver) -> void:
	# The joystick shows where the thumb is. It does not cover a button.
	await d.hold_stick(Vector2(0, -1), 0.5)
	for app: String in ["messages", "notebook", "clock", "settings", "lens"]:
		await d.open_app(app)
		await PlaytestLayout.check(d, app)
	await d.raise_phone()
	await d.tap_id("phone.home")
	await PlaytestLayout.check(d, "phone_home")
	await PlaytestLayout.check_buttons_take_touches(d, "phone_home")
