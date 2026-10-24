extends RefCounted
# PT-17 fp_layout. For each screen size: open each sheet and each kind of talk
# panel. No control is off the screen. No control covers the top bar or the
# center dot. No button is in the joystick zone or the look zone in a way that
# a joystick touch or a look drag starts on it.
# sizes: 1280x720 2400x1080 1920x1080 720x1280
# compatibility: 1280x720
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	await PlaytestLayout.check(d, "intro")
	await PlaytestLayout.check_buttons_take_touches(d, "intro")
	await d.tap_id("choice.step_outside")
	await PlaytestLayout.check(d, "greeting")
	await PlaytestLayout.check_buttons_take_touches(d, "greeting")
	await d.tap_id("choice.chua")
	await d.tap_id("choice.thanks")
	await PlaytestLayout.check(d, "near_homestay")
	await PlaytestLayout.check_buttons_take_touches(d, "near_homestay")
	# The action button: look at Bà Tư.
	await d.look_at_id("npc.batu")
	await PlaytestLayout.check(d, "action_talk")
	await PlaytestLayout.check_buttons_take_touches(d, "action_talk")
	await d.tap_id("action")
	await PlaytestLayout.check(d, "talk_from_action")
	await d.tap_id("choice.chua")
	await d.tap_id("choice.thanks")
	# The joystick shows where the thumb is. It does not cover a button.
	await d.hold_stick(Vector2(0, -1), 0.5)
	for sheet: Array in [["topbar.notebook", "notebook.close"], ["topbar.settings", "settings.close"],
			["topbar.clock", "clock.close"]]:
		await d.tap_id(sheet[0])
		await PlaytestLayout.check(d, sheet[0].replace("topbar.", ""))
		await d.tap_id(sheet[1])
	await d.bring_into_view("spot.banhkhot")
	await d.tap_id("spot.banhkhot")
	await PlaytestLayout.check(d, "closed_shop")
