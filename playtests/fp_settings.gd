extends RefCounted
# PT-16 fp_settings. Change each setting. Quit and start again. All settings
# are the same. Also check that each setting has its effect.
# phase: --start-time=06:00
# phase:


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	if d.phase == 1:
		await _change(d)
	else:
		await _check(d)


func _expected_path(d: PlaytestDriver) -> String:
	return d.out_dir.path_join("expected.json")


## Taps a slider at a fraction of its length.
func _tap_slider(d: PlaytestDriver, test_id: String, fraction: float) -> void:
	var slider := d.find(test_id) as Control
	var rect := slider.get_global_rect()
	await d.tap(d.to_screen(Vector2(rect.position.x + rect.size.x * fraction, rect.get_center().y)))
	await d.wait_frames(3)


func _change(d: PlaytestDriver) -> void:
	await d.skip_intro()
	var before: Dictionary = d.state().settings
	await d.tap_id("topbar.settings")
	await d.wait_frames(3)
	d.expect(d.state().mode == "settings", "the settings sheet opens")
	await d.screenshot("settings_before")
	await _tap_slider(d, "settings.sensitivity", 0.8)
	await d.tap_id("settings.invert")
	await d.tap_id("settings.gyro")
	await _tap_slider(d, "settings.fov", 0.25)
	await d.tap_id("settings.tap_walk")
	await d.wait_frames(3)
	var after: Dictionary = d.state().settings
	for key: String in before:
		d.expect(after[key] != before[key], "the setting %s changed: %s" % [key, after[key]])
	d.expect(absf(float(d.state().fov) - float(after.fov)) < 0.5, "the field of view changes the camera")
	await d.screenshot("settings_after")
	await d.tap_id("settings.close")
	await d.wait_frames(3)
	# Invert: a drag up now turns the view down.
	var pitch0: float = d.state().pitch
	var start := d.to_screen(await d._free_point("look"))
	await d.drag(start, start + Vector2(0, -60), 0.3)
	await d.wait_idle()
	d.expect(float(d.state().pitch) < pitch0 - 2.0, "with invert, a drag up turns the view down")
	# Tap to walk is off: a tap on the ground does not walk.
	var p0: Vector3 = d.state().player
	var ground := Vector3(p0.x + 4.0, 0, 0)
	await d.look_at_point(ground, 6.0)
	await d.tap_floor(ground)
	await d.wait_frames(20)
	d.expect(not d.state().walking and d.state().player.distance_to(p0) < 0.1, "with tap to walk off, a tap does not walk")
	var file := FileAccess.open(_expected_path(d), FileAccess.WRITE)
	file.store_string(JSON.stringify(d.state().settings))
	file.close()
	await d.wait_frames(5)


func _check(d: PlaytestDriver) -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_expected_path(d)))
	var s := d.state()
	for key: String in expected:
		var value: Variant = s.settings[key]
		var ok: bool = value == expected[key] if typeof(value) == TYPE_BOOL else absf(float(value) - float(expected[key])) < 0.001
		d.expect(ok, "after the restart the setting %s is %s, not %s" % [key, value, expected[key]])
	d.expect(absf(float(s.fov) - float(expected.fov)) < 0.5, "after the restart the field of view is %s" % s.fov)
	await d.tap_id("topbar.settings")
	await d.wait_frames(3)
	await d.screenshot("settings_after_restart")
	# The credits sheet opens from the settings sheet (plan 0003, acceptance criterion 4).
	await d.tap_id("settings.credits")
	await d.wait_frames(5)
	d.expect(d.state().mode == "credits", "the Credits button opens the credits sheet: %s" % d.state().mode)
	var text := ""
	for node: Node in d.main().credits_sheet.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	d.expect(text.contains("© OpenStreetMap contributors"), "the credits show the OpenStreetMap notice")
	d.expect(text.contains("Copernicus WorldDEM-30 © DLR e.V."), "the credits show the Copernicus notice")
	await PlaytestLayout.check(d, "credits")
	await d.tap_id("credits.close")
	await d.wait_frames(3)
	d.expect(d.state().mode == "hem", "Close closes the credits sheet")
