extends RefCounted
# PT-19 overhear (plan 0003). Two neighbors talk at the cà phê cóc. Turn on
# Listen at 4 m. The lines go into the transcript. Walk to 15 m. No new line
# goes into the transcript, and no subtitle shows.
# sizes: 1280x720 2400x1080
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
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
	await d.screenshot("overheard")
	await d.lower_phone()
	# Walk to 15 m.
	await d.stick_to(Vector3(chu_bay.global_position.x - 15.0, 0.0, 0.2))
	s = d.state()
	distance = Vector2(chu_bay.global_position.x - s.player.x, chu_bay.global_position.z - s.player.z).length()
	d.expect(distance >= 14.0, "the player is 15 m from the neighbors: %.1f m" % distance)
	var count := d.transcript().size()
	var saw_subtitle := false
	var end := Time.get_ticks_msec() + 40000
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
	await d.screenshot("far")
