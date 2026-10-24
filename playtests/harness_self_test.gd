extends RefCounted
# PT-10 harness_self_test. A button with a known test ID must react to
# tap_id(). A tap on an off-screen node must fail with a clear message.
# This scenario checks the play-test system itself.
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	# A button with a known test ID reacts to tap_id().
	await d.tap_id("topbar.notebook")
	await d.wait_frames(3)
	d.expect(d.state().mode == "notebook", "tap_id(topbar.notebook) opens the notebook")
	await d.tap_id("notebook.close")
	await d.wait_frames(3)
	d.expect(d.state().mode == "hem", "tap_id(notebook.close) closes the notebook")

	# A tap on an off-screen node fails with a clear message. At the door, the
	# player looks along the hẻm, so the homestay is at the side.
	var error: String = await d.try_tap_id("spot.home")
	d.expect(error.contains("off the screen") or error.contains("behind the camera"),
			"a tap on the off-screen homestay fails with a clear message: \"%s\"" % error)
	d.step("off-screen message: " + error)
	# A missing test ID fails with a clear message.
	error = await d.try_tap_id("no.such.node")
	d.expect(error.contains("no visible node"), "a tap on a missing node fails with a clear message: \"%s\"" % error)
	# A node under a control fails: the clock sheet covers the world.
	await d.tap_id("topbar.clock")
	await d.wait_frames(3)
	error = await d.try_tap_id("spot.pho")
	d.expect(error.contains("covered"), "a tap on a covered node fails with a clear message: \"%s\"" % error)
	d.step("covered message: " + error)
	d.expect(d.state().mode == "clock", "the failed tap did not send a tap")
	await d.tap_id("clock.close")
	await d.wait_frames(3)
	# A hidden cart cannot be tapped at 06:00.
	error = await d.try_tap_id("spot.go")
	d.expect(error.contains("no visible node"), "a hidden cart cannot be tapped: \"%s\"" % error)

	# tap() with a raw screen position presses the button there.
	var where := d.locate("topbar.notebook")
	d.expect(where.error == "", "locate(topbar.notebook) works")
	await d.tap(d.to_screen(where.point))
	await d.wait_frames(3)
	d.expect(d.state().mode == "notebook", "tap() on the notebook button opens the notebook")
	await d.tap_id("notebook.close")
	await d.wait_frames(3)

	# hold_stick() walks the player, drag() turns the view, look_at_id() finds a node.
	var p0: Vector3 = d.state().player
	await d.hold_stick(Vector2(0, -1), 1.5)
	await d.wait_idle()
	var walked: float = Vector2(d.state().player.x - p0.x, d.state().player.z - p0.z).length()
	# The release comes in the frame after the time, so a slow frame adds some walk.
	d.expect(walked > 1.5 and walked < 3.2, "hold_stick() for 1.5 s walks about 2.1 m: %.2f m" % walked)
	var yaw0: float = d.state().yaw
	var start := d.to_screen(await d._free_point("look"))
	await d.drag(start, start + Vector2(-100, 0), 0.3)
	await d.wait_idle()
	d.expect(wrapf(float(d.state().yaw) - yaw0, -180.0, 180.0) > 5.0, "a drag to the left turns the view to the left")
	d.expect(await d.look_at_id("spot.pho"), "look_at_id() turns the view to the phở shop")

	# wait_until() and expect() record failures. Remove them after the check.
	var count := d.failures.size()
	var passed: bool = await d.wait_until(func() -> bool: return false, 0.3, "self test")
	d.expect(not passed and d.failures.size() == count + 1, "wait_until() records a failure at the timeout")
	d.failures.resize(count)
	d.expect(false, "self test")
	d.expect(d.failures.size() == count + 1, "expect(false) records a failure")
	d.failures.resize(count)

	# screenshot() saves a PNG.
	await d.screenshot("self_test")
	var files := DirAccess.get_files_at(d.out_dir)
	var found := false
	for file in files:
		if file.ends_with("-self_test.png"):
			found = true
	d.expect(found, "screenshot() saves a PNG file")

	# state() and ui_report() read the game.
	var s := d.state()
	for key: String in ["time", "day", "cards", "mode", "player", "line", "choices"]:
		d.expect(s.has(key), "state() has \"%s\"" % key)
	var report := d.ui_report()
	var clock_found := false
	for item: Dictionary in report:
		if item.test_id == "topbar.clock":
			clock_found = item.rect.size.y >= UiTheme.BUTTON_MIN_HEIGHT
	d.expect(clock_found, "ui_report() has the clock button with its rectangle")
