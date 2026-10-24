extends RefCounted
# PT-04 clock_sheet. Use each wait choice. Check the time after each one.
# Use "Sleep until morning". Check day 2, 05:45, and the player at the
# homestay door. Start at 23:00, wait one hour, and check that the only
# choice is "Go home and sleep". Also: the Close button, a tap outside the
# sheet, and the homestay choices "Rest one hour" and "Sleep until morning".
# phase: --start-time=06:00
# phase: --start-time=23:00 --fresh-save

const ALL_WAITS := ["clock.wait_hour", "clock.wait_1100", "clock.wait_1500", "clock.wait_1830",
		"clock.wait_2030", "clock.sleep"]


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	await d.tap_id("choice.step_outside")
	await d.tap_id("choice.good_morning")
	await d.tap_id("choice.okay")
	await d.wait_idle()
	if d.phase == 1:
		await _day(d)
	else:
		await _late(d)


func _open_clock(d: PlaytestDriver) -> void:
	await d.tap_id("topbar.clock")
	await d.wait_frames(3)
	d.expect(d.state().mode == "clock", "the clock sheet opens")


func _wait(d: PlaytestDriver, choice: String, expected_time: int, expected_choices: Array) -> void:
	await _open_clock(d)
	var s := d.state()
	d.expect(s.choices == expected_choices, "at %s the clock choices are %s, not %s" % [s.time_text, s.choices, expected_choices])
	await d.screenshot("clock_" + s.time_text.replace(":", ""))
	await d.tap_id(choice)
	await d.wait_frames(3)
	s = d.state()
	d.expect(s.mode == "hem", "the clock sheet closes after %s" % choice)
	d.expect(s.time == expected_time, "after %s the time is %s, not %s" % [choice, s.time_text,
			GameClock.format_time(expected_time)])


func _day(d: PlaytestDriver) -> void:
	# Close and a tap outside the sheet do not change the time.
	await _open_clock(d)
	await d.tap_id("clock.close")
	await d.wait_frames(3)
	d.expect(d.state().mode == "hem" and d.state().time == 360, "Close closes the sheet, and the time stays")
	await _open_clock(d)
	var view: Vector2 = d.state().view_size
	await d.tap(d.to_screen(Vector2(view.x / 2.0, view.y - 40.0)))
	await d.wait_frames(3)
	d.expect(d.state().mode == "hem" and d.state().time == 360, "a tap outside closes the sheet, and the time stays")

	await _wait(d, "clock.wait_hour", 420, ALL_WAITS)
	await _wait(d, "clock.wait_1100", 660, ALL_WAITS)
	await _wait(d, "clock.wait_1500", 900, ["clock.wait_hour", "clock.wait_1500", "clock.wait_1830", "clock.wait_2030", "clock.sleep"])
	await _wait(d, "clock.wait_1830", 1110, ["clock.wait_hour", "clock.wait_1830", "clock.wait_2030", "clock.sleep"])
	await _wait(d, "clock.wait_2030", 1230, ["clock.wait_hour", "clock.wait_2030", "clock.sleep"])
	await d.screenshot("after_waits")

	# The homestay: rest one hour.
	await d.tap_id("spot.home")
	await d.wait_idle()
	d.expect(d.state().line == "spot.home.look", "the homestay line shows")
	await d.tap_id("choice.rest")
	await d.wait_frames(3)
	d.expect(d.state().time == 1290, "Rest one hour moves the clock to 21:30, not %s" % d.state().time_text)

	# Walk away from home, then sleep from the clock sheet.
	await d.tap_id("walk.right")
	await d.wait_idle()
	await _open_clock(d)
	d.expect(d.state().choices == ["clock.wait_hour", "clock.sleep"], "at 21:30 the choices are wait one hour and sleep")
	await d.tap_id("clock.sleep")
	await d.wait_idle()
	var s := d.state()
	d.expect(s.day == 2, "after sleep the day is 2, not %d" % s.day)
	d.expect(s.time == 345, "after sleep the time is 5:45, not %s" % s.time_text)
	var door: Vector3 = GameState.HOME_DOOR
	d.expect(Vector2(s.player.x - door.x, s.player.z - door.z).length() < 0.2, "after sleep the player is at the homestay door: %s" % s.player)
	d.expect(s.line == "home.morning", "the morning line shows, not %s" % s.line)
	await d.screenshot("morning_day2")
	await d.tap_id("choice.step_outside")
	await d.wait_frames(3)
	d.expect(d.state().line == "hem.near", "after the morning line the homestay panel shows")

	# The homestay: sleep until morning from the talk panel.
	await d.tap_id("choice.look")
	await d.wait_frames(3)
	await d.tap_id("choice.sleep")
	await d.wait_idle()
	s = d.state()
	d.expect(s.day == 3 and s.time == 345, "sleep in the homestay gives day 3, 5:45: day %d %s" % [s.day, s.time_text])
	await d.screenshot("morning_day3")


func _late(d: PlaytestDriver) -> void:
	await _wait(d, "clock.wait_hour", 1439, ["clock.wait_hour", "clock.sleep"])
	var s := d.state()
	d.expect(s.line == "hem.late", "at 23:59 the late line shows, not %s" % s.line)
	d.expect(s.choices == ["choice.go_home_sleep"], "at 23:59 the only choice is Go home and sleep: %s" % [s.choices])
	await d.screenshot("late")
	# A spot also shows only the late line.
	await d.tap_id("spot.pho")
	await d.wait_idle()
	s = d.state()
	d.expect(s.choices == ["choice.go_home_sleep"], "at 23:59 a spot shows only Go home and sleep: %s" % [s.choices])
	await d.tap_id("choice.go_home_sleep")
	await d.wait_idle()
	s = d.state()
	d.expect(s.day == 2 and s.time == 345, "Go home and sleep gives day 2, 5:45: day %d %s" % [s.day, s.time_text])
	await d.screenshot("late_morning")
