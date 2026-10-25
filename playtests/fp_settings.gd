extends RefCounted
# PT-16 fp_settings. In the Settings app (plan 0003, R28, and plan 0004, R1
# to R4), change each setting. Quit and start again. All settings are the
# same. Also check that each setting has its effect. Run 1 changes the
# settings of plans 0002 and 0003. Run 2 checks them and changes the settings
# of plan 0004. Run 3 checks all settings again.
# phase: --start-time=06:00
# phase:
# phase:


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	match d.phase:
		1:
			await _change(d)
		2:
			await _check(d)
			await _change_new(d)
		_:
			await _check(d)


## The settings of plan 0004. Run 2 changes them.
const NEW_SETTINGS := ["quality", "mouse_sensitivity", "fullscreen"]


func _expected_path(d: PlaytestDriver) -> String:
	return d.out_dir.path_join("expected.json")


## Taps a slider at a fraction of its length.
func _tap_slider(d: PlaytestDriver, test_id: String, fraction: float) -> void:
	await d.show_in_phone(test_id)
	var slider := d.find(test_id) as Control
	var rect := slider.get_global_rect()
	await d.tap(d.to_screen(Vector2(rect.position.x + rect.size.x * fraction, rect.get_center().y)))
	await d.wait_frames(3)


func _change(d: PlaytestDriver) -> void:
	await d.skip_intro()
	var before: Dictionary = d.state().settings
	await d.open_app("settings")
	await d.screenshot("settings_before")
	await d.tap_phone_id("settings.subtitles")
	await _tap_slider(d, "settings.subtitle_size", 0.9)
	await _tap_slider(d, "settings.subtitle_box", 0.1)
	await _tap_slider(d, "settings.sensitivity", 0.8)
	await d.tap_phone_id("settings.invert")
	await d.tap_phone_id("settings.gyro")
	await _tap_slider(d, "settings.fov", 0.25)
	await d.tap_phone_id("settings.tap_walk")
	await d.wait_frames(3)
	var after: Dictionary = d.state().settings
	for key: String in before:
		if key in NEW_SETTINGS:
			continue
		d.expect(after[key] != before[key], "the setting %s changed: %s" % [key, after[key]])
	d.expect(after.subtitles == "en", "the subtitles are in English: %s" % after.subtitles)
	d.expect(absf(float(d.state().fov) - float(after.fov)) < 0.5, "the field of view changes the camera")
	await d.screenshot("settings_after")
	await d.lower_phone()
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


## The quality preset, the mouse speed, and fullscreen (plan 0004). Fullscreen
## goes on and off again, because a fullscreen window under Xvfb has the size
## of the whole virtual screen.
func _change_new(d: PlaytestDriver) -> void:
	await d.tap_phone_id("phone.home")
	await d.open_app("settings")
	var before: Dictionary = d.state().settings
	await d.tap_phone_id("settings.quality")
	await _tap_slider(d, "settings.mouse_sensitivity", 0.8)
	await d.tap_phone_id("settings.fullscreen")
	await d.wait_frames(10)
	d.expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "the fullscreen setting makes the window fullscreen")
	await d.tap_phone_id("settings.fullscreen")
	await d.wait_frames(10)
	d.expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "the fullscreen setting off makes a window again")
	var after: Dictionary = d.state().settings
	for key: String in ["quality", "mouse_sensitivity"]:
		d.expect(after[key] != before[key], "the setting %s changed: %s" % [key, after[key]])
	var file := FileAccess.open(_expected_path(d), FileAccess.WRITE)
	file.store_string(JSON.stringify(after))
	file.close()
	await d.wait_frames(5)


func _check(d: PlaytestDriver) -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_expected_path(d)))
	var s := d.state()
	for key: String in expected:
		var value: Variant = s.settings[key]
		var ok: bool = value == expected[key] if typeof(value) in [TYPE_BOOL, TYPE_STRING] \
				else absf(float(value) - float(expected[key])) < 0.001
		d.expect(ok, "after the restart the setting %s is %s, not %s" % [key, value, expected[key]])
	d.expect(absf(float(s.fov) - float(expected.fov)) < 0.5, "after the restart the field of view is %s" % s.fov)
	await d.open_app("settings")
	await d.screenshot("settings_after_restart")
	# The Credits page opens from the Settings app (plan 0005, acceptance criterion 4).
	await d.tap_phone_id("settings.credits")
	d.expect(d.state().app == "credits", "the Credits button opens the credits page: %s" % d.state().app)
	var text := ""
	for node: Node in d.main().phone.apps.credits.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	d.expect(text.contains("© OpenStreetMap contributors"), "the credits show the OpenStreetMap notice")
	d.expect(text.contains("Copernicus WorldDEM-30 © DLR e.V."), "the credits show the Copernicus notice")
	await PlaytestLayout.check(d, "credits")
	await d.tap_phone_id("phone.home")
	d.expect(d.state().app == "", "Home closes the credits page")
	# The next steps start in the Settings app, as before the credits check.
	await d.open_app("settings")
