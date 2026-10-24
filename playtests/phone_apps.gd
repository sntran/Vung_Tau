extends RefCounted
# PT-21 phone_apps (plan 0003). Open each app. Lens: point at Phở Cô Sáu at
# 06:00 and at 11:00, and check "Open now" and "Closed now". Clock: rest
# until 11:00. Sổ tay: the card count. Settings: change each setting, quit,
# start again, and check that they stay.
# sizes: 1280x720 2400x1080
# phase: --start-time=06:00
# phase:


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	if d.phase == 1:
		await _apps(d)
	else:
		await _after_restart(d)


func _expected_path(d: PlaytestDriver) -> String:
	return d.out_dir.path_join("expected.json")


func _lens_status(d: PlaytestDriver) -> String:
	await d.open_app("lens")
	await d.look_at_id("spot.pho")
	await d.wait_frames(3)
	var label := d.find("lens.status") as Label
	return label.text if label else ""


func _apps(d: PlaytestDriver) -> void:
	for app: String in Phone.APPS:
		d.expect(await d.open_app(app), "the app %s opens" % app)
	await d.lower_phone()
	await d.walk_toward(d.main().hem.stand_points["pho"].x, 0.0)
	var status := await _lens_status(d)
	d.expect(status.begins_with("Open now"), "at 06:00 the Lens shows \"Open now\": \"%s\"" % status)
	await d.screenshot("lens_open")
	await d.open_app("clock")
	await d.tap_phone_id("clock.wait_1100")
	d.expect(d.state().time == 660, "Rest until 11:00 moves the clock to 11:00, not %s" % d.state().time_text)
	status = await _lens_status(d)
	d.expect(status.begins_with("Closed now"), "at 11:00 the Lens shows \"Closed now\": \"%s\"" % status)
	await d.screenshot("lens_closed")
	await d.open_app("notebook")
	var count := d.find("notebook.count") as Label
	var expected := "%d of %d found" % [d.state().cards.size(), Content.card_list().size()]
	d.expect(count != null and count.text.begins_with(expected), "the Sổ tay shows the card count \"%s\": %s" % [expected,
			count.text if count else "none"])
	await d.screenshot("notebook")
	await d.open_app("settings")
	var before: Dictionary = d.state().settings
	var sound_before: bool = d.state().sound
	await d.tap_phone_id("settings.sound")
	await d.tap_phone_id("settings.subtitles")
	for id: String in ["settings.subtitle_size", "settings.subtitle_box", "settings.sensitivity", "settings.fov"]:
		await d.show_in_phone(id)
		var slider := d.find(id) as Control
		var rect := slider.get_global_rect()
		await d.tap(d.to_screen(Vector2(rect.position.x + rect.size.x * 0.9, rect.get_center().y)))
		await d.wait_frames(3)
	for id: String in ["settings.invert", "settings.gyro", "settings.tap_walk"]:
		await d.tap_phone_id(id)
	var after: Dictionary = d.state().settings
	for key: String in before:
		d.expect(after[key] != before[key], "the setting %s changed: %s" % [key, after[key]])
	d.expect(d.state().sound != sound_before, "the sound setting changed")
	await d.screenshot("settings_changed")
	var file := FileAccess.open(_expected_path(d), FileAccess.WRITE)
	file.store_string(JSON.stringify({"settings": after, "sound": d.state().sound}))
	file.close()
	await d.wait_frames(5)


func _after_restart(d: PlaytestDriver) -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_expected_path(d)))
	var s := d.state()
	for key: String in expected.settings:
		var value: Variant = s.settings[key]
		var want: Variant = expected.settings[key]
		var ok: bool = value == want if typeof(value) in [TYPE_BOOL, TYPE_STRING] else absf(float(value) - float(want)) < 0.001
		d.expect(ok, "after the restart the setting %s is %s, not %s" % [key, value, want])
	d.expect(s.sound == expected.sound, "after the restart the sound setting stays")
	await d.open_app("settings")
	await d.screenshot("settings_after_restart")
