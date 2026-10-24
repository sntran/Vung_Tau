extends RefCounted
# PT-05 save_reload. Learn two cards and walk to the cà phê cóc. Quit the
# game. Start it again with the same save path. Check the cards, the day,
# the time, and the player position. Then put a save file with another
# version in place: the game starts a new game and does not crash.
# phase: --start-time=06:00
# phase:
# phase:


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	match d.phase:
		1:
			await _play(d)
		2:
			await _reload(d)
		3:
			await _other_version(d)


func _expected_path(d: PlaytestDriver) -> String:
	return d.out_dir.path_join("expected.json")


func _play(d: PlaytestDriver) -> void:
	await d.tap_id("choice.step_outside")
	await d.tap_id("choice.chua")
	await d.tap_id("choice.thanks")
	await d.wait_idle()
	await d.bring_into_view("spot.banhmi")
	await d.tap_id("spot.banhmi")
	await d.wait_idle()
	await d.tap_id("choice.okay")
	await d.wait_idle()
	var coc_x: float = d.main().hem.lot_x["coc"]
	await d.walk_toward(coc_x, 0.3)
	var s := d.state()
	d.expect(s.cards == ["anSang", "banhmi"], "two cards are in the notebook: %s" % [s.cards])
	d.expect(s.near_spot == "coc", "the player is at the cà phê cóc: %s" % s.near_spot)
	await d.screenshot("before_quit")
	var file := FileAccess.open(_expected_path(d), FileAccess.WRITE)
	file.store_string(JSON.stringify({"cards": s.cards, "day": s.day, "time": s.time,
			"x": s.player.x, "z": s.player.z}))
	file.close()
	# Wait some frames. Then the scenario ends and the game quits.
	await d.wait_frames(5)


func _reload(d: PlaytestDriver) -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_expected_path(d)))
	var s := d.state()
	d.expect(s.cards == expected.cards, "after the restart the cards are %s, not %s" % [s.cards, expected.cards])
	d.expect(s.day == int(expected.day), "after the restart the day is %d" % s.day)
	d.expect(s.time == int(expected.time), "after the restart the time is %s, not %s" % [s.time_text,
			GameClock.format_time(int(expected.time))])
	var miss := Vector2(s.player.x - expected.x, s.player.z - expected.z).length()
	d.expect(miss < 0.05, "after the restart the player is %.3f m from the old position" % miss)
	d.expect(s.intro_done and s.line == "hem.near" and s.near_spot == "coc",
			"after the restart the panel shows the cà phê cóc, not the intro: %s %s" % [s.line, s.near_spot])
	await d.screenshot("after_restart")
	# Put a save file with another version in place for the next run.
	var save_path := d.out_dir.path_join("save.json")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	data.version = 999
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _other_version(d: PlaytestDriver) -> void:
	var s := d.state()
	d.expect(s.day == 1 and s.time == 360 and s.cards.is_empty(),
			"a save with another version starts a new game: day %d %s %s" % [s.day, s.time_text, s.cards])
	d.expect(s.line == "intro.welcome", "the new game shows the intro, not %s" % s.line)
	await d.screenshot("new_game")
