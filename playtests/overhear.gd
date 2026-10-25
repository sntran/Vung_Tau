extends RefCounted
# PT-19 overhear (plan 0003). Two neighbors talk at the cà phê cóc. Turn on
# Listen at 4 m. The lines go into the transcript. Walk to 15 m. No new line
# goes into the transcript, and no subtitle shows.
# Report 0003: the "far" screenshot looks along the hẻm, not at a wall
# (D-0003-06). In run 2, the player stays 3 minutes near the neighbors with
# Listen on, and no chat line comes again (D-0003-03). The game runs 3 times
# faster in run 2, so that the run is shorter than 180 s.
# sizes: 1280x720 2400x1080
# phase: --start-time=06:00
# phase: --start-time=06:00 --fresh-save


func run(d: PlaytestDriver) -> void:
	if d.phase == 2:
		await _no_repeats(d)
		return
	await d.wait_idle()
	var hem: Node = d.main().hem
	var chu_bay: Npc = hem.npcs["chubay"]
	var near := Vector3(chu_bay.global_position.x + 3.0, 0.0, 0.6)
	await d.stick_to(near)
	var s := d.state()
	var distance := Vector2(chu_bay.global_position.x - s.player.x, chu_bay.global_position.z - s.player.z).length()
	d.expect(distance <= 5.0, "the player is about 4 m from the neighbors: %.1f m" % distance)
	await d.open_app("listen")
	await d.tap_phone_id("listen.toggle")
	# Wait for two lines of the neighbors.
	d.expect(await d.wait_until(func() -> bool: return d.transcript().size() >= 2, 60.0, "two lines of the neighbors"),
			"the lines of the neighbors go into the transcript")
	var transcript := d.transcript()
	d.expect(transcript.size() >= 2 and transcript[0].speaker == Content.string("someone"),
			"the player has not met them, so the app shows \"Someone\": %s" % [transcript])
	# The subtitle uses the same name rule (D-0003-04).
	var names := {}
	var record := func() -> void:
		var shown := d.subtitle()
		if not shown.is_empty() and not shown.get("caption", false):
			names[shown.get("speaker", "")] = true
	d.main().get_tree().process_frame.connect(record)
	await d.wait_until(func() -> bool: return not names.is_empty(), 30.0, "a subtitle of the neighbors")
	d.main().get_tree().process_frame.disconnect(record)
	d.expect(names.keys() == [Content.string("someone")], "the subtitles of the neighbors show \"Someone\": %s" % [names.keys()])
	await d.screenshot("overheard")
	await d.lower_phone()
	# Walk to 15 m.
	await d.stick_to(Vector3(chu_bay.global_position.x - 15.0, 0.0, 0.2))
	s = d.state()
	distance = Vector2(chu_bay.global_position.x - s.player.x, chu_bay.global_position.z - s.player.z).length()
	d.expect(distance >= 14.0, "the player is 15 m from the neighbors: %.1f m" % distance)
	var count := d.transcript().size()
	var saw_subtitle := false
	# The next chat comes "every_s" seconds after the last one.
	var end := Time.get_ticks_msec() + 120000
	var spoke := false
	while Time.get_ticks_msec() < end:
		var now := d.state()
		if now.speaking.has("chubay") or now.speaking.has("chuchin"):
			spoke = true
		if not now.subtitle.is_empty() and not now.subtitle.get("caption", false):
			saw_subtitle = true
		if spoke and now.speaking.is_empty():
			break
		await d.wait_frames(2)
	d.expect(spoke, "the neighbors talk again")
	d.expect(d.transcript().size() == count, "at 15 m no new line goes into the transcript")
	d.expect(not saw_subtitle, "at 15 m no subtitle shows")
	# Look back along the hẻm to the neighbors, not at the end wall (D-0003-06).
	await d.look_at_point(chu_bay.global_position + Vector3(0, 1.4, 0), 6.0)
	await d.screenshot("far")


## Run 2: 3 minutes near the neighbors with Listen on. Each chat line comes
## one time only, and the neighbors have more than one chat (D-0003-03).
func _no_repeats(d: PlaytestDriver) -> void:
	await d.wait_idle()
	var chu_bay: Npc = d.main().hem.npcs["chubay"]
	await d.stick_to(Vector3(chu_bay.global_position.x + 3.0, 0.0, 0.6))
	await d.open_app("listen")
	await d.tap_phone_id("listen.toggle")
	await d.lower_phone()
	var heard: Array[String] = []
	var record := func() -> void:
		for npc_id: String in ["chubay", "chuchin"]:
			var item: Dictionary = d.main().speech.get(npc_id, {})
			if not item.is_empty() and (heard.is_empty() or heard[heard.size() - 1] != item.line):
				heard.append(item.line)
	d.main().get_tree().process_frame.connect(record)
	Engine.time_scale = 3.0
	await d.wait_seconds(180.0)
	Engine.time_scale = 1.0
	d.main().get_tree().process_frame.disconnect(record)
	var repeated := heard.filter(func(line_id: String) -> bool: return heard.count(line_id) > 1)
	d.expect(repeated.is_empty(), "in 3 minutes no chat line comes again: %s" % [heard])
	var chats := heard.filter(func(line_id: String) -> bool: return line_id.ends_with(".1"))
	d.expect(chats.size() >= 2, "the neighbors have more than one chat: %s" % [chats])
	await d.open_app("listen")
	await d.screenshot("three_minutes")
