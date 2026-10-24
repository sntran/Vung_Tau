extends RefCounted
# PT-04 clock_sheet. In the Clock app (plan 0003, R27), use each wait choice.
# Check the time after each one. Away from the homestay, "Sleep until
# morning" is not a choice. At the homestay, use it. Check day 2, 05:45, the
# player at the homestay door, and the morning message. The action "Rest" at
# the homestay opens the Clock app. Start at 23:00, wait one hour: the clock
# stops at 23:59, and cô Nga sends the "late" message.
# Run 1 uses the wait choices of the day. Run 2 starts at 18:30: away from
# the homestay, then back at the homestay to sleep. Each run is shorter than
# 180 s at 2400×1080 on a slow computer.
# phase: --start-time=06:00
# phase: --start-time=18:30 --fresh-save
# phase: --start-time=23:00 --fresh-save

const ALL_WAITS := ["clock.wait_hour", "clock.wait_1100", "clock.wait_1500", "clock.wait_1830",
		"clock.wait_2030", "clock.sleep"]


func run(d: PlaytestDriver) -> void:
	await d.skip_intro()
	match d.phase:
		1:
			await _day(d)
		2:
			await _evening(d)
		_:
			await _late(d)


## The test IDs of the choices that the Clock app shows.
func _choices(d: PlaytestDriver) -> Array:
	return d.visible_choice_ids().filter(func(id: String) -> bool: return id.begins_with("clock."))


func _wait(d: PlaytestDriver, choice: String, expected_time: int, expected_choices: Array) -> void:
	await d.open_app("clock")
	var s := d.state()
	d.expect(_choices(d) == expected_choices, "at %s the clock choices are %s, not %s" % [s.time_text, _choices(d), expected_choices])
	await d.screenshot("clock_" + s.time_text.replace(":", ""))
	await d.tap_phone_id(choice)
	s = d.state()
	d.expect(s.time == expected_time, "after %s the time is %s, not %s" % [choice, s.time_text,
			GameClock.format_time(expected_time)])


func _day(d: PlaytestDriver) -> void:
	await _wait(d, "clock.wait_hour", 420, ALL_WAITS)
	await _wait(d, "clock.wait_1100", 660, ALL_WAITS)
	await _wait(d, "clock.wait_1500", 900, ["clock.wait_hour", "clock.wait_1500", "clock.wait_1830", "clock.wait_2030", "clock.sleep"])
	await _wait(d, "clock.wait_1830", 1110, ["clock.wait_hour", "clock.wait_1830", "clock.wait_2030", "clock.sleep"])
	await d.lower_phone()


func _evening(d: PlaytestDriver) -> void:
	# Away from the homestay, the app does not show "Sleep until morning".
	await d.stick_to(Vector3(12.0, 0.0, 0.2))
	await d.open_app("clock")
	d.expect(_choices(d) == ["clock.wait_hour", "clock.wait_2030"], "away from the homestay there is no sleep: %s" % [_choices(d)])
	await d.screenshot("clock_away")
	await d.tap_phone_id("clock.wait_2030")
	d.expect(d.state().time == 1230, "Wait until 20:30 moves the clock to 20:30, not %s" % d.state().time_text)
	await d.lower_phone()

	# Back at the homestay: the action "Rest" opens the Clock app.
	await d.stick_to(Vector3(0.6, 0.0, 0.0))
	await d.look_at_id("spot.home")
	await d.wait_idle()
	var s := d.state()
	d.expect(s.action_verb == "Rest", "at the homestay the action is Rest, not \"%s\"" % s.action_verb)
	await d.tap_id("action")
	await d.wait_frames(3)
	s = d.state()
	d.expect(s.phone_up and s.app == "clock", "Rest opens the Clock app: %s %s" % [s.phone_up, s.app])
	d.expect(_choices(d) == ["clock.wait_hour", "clock.sleep"], "at the homestay at 20:30 the choices are %s" % [_choices(d)])
	await d.tap_phone_id("clock.sleep")
	await d.wait_idle()
	s = d.state()
	d.expect(s.day == 2, "after sleep the day is 2, not %d" % s.day)
	d.expect(s.time == 345, "after sleep the time is 5:45, not %s" % s.time_text)
	var door: Vector3 = GameState.HOME_DOOR
	d.expect(Vector2(s.player.x - door.x, s.player.z - door.z).length() < 0.2, "after sleep the player is at the homestay door: %s" % s.player)
	d.expect(absf(wrapf(float(s.yaw) - GameClock.HOME_YAW, -180.0, 180.0)) < 1.0,
			"after sleep the player looks along the hẻm toward Bãi Trước (plan 0001, R4): yaw %.1f" % s.yaw)
	d.expect(s.messages.has("morning"), "cô Nga sends the morning message: %s" % [s.messages])
	await d.open_app("messages")
	await d.screenshot("morning_day2")


func _late(d: PlaytestDriver) -> void:
	await _wait(d, "clock.wait_hour", 1439, ["clock.wait_hour", "clock.sleep"])
	var s := d.state()
	d.expect(s.messages.has("late"), "at 23:30 or later, cô Nga sends the late message: %s" % [s.messages])
	await d.open_app("messages")
	d.expect(d.find("message.late") != null, "the Messages app shows the late message")
	await d.screenshot("late")
