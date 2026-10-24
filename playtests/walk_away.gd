extends RefCounted
# PT-23 walk_away (plan 0003). Start a talk, then walk away with the
# joystick. The talk ends at 6 m. The person calls after the player. The
# phone stays usable.
# sizes: 1280x720 2400x1080
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	await d.walk_toward(d.main().hem.stand_points["pho"].x, 0.0)
	var line := await d.talk_to("cosau")
	d.expect(line == "cosau.open", "the talk starts, not \"%s\"" % line)
	await d.open_app("listen")
	await d.wait_answer()
	d.expect(d.find("reply.cam_on") != null, "the phrasebook shows the replies")
	var npc: Npc = d.main().hem.npcs["cosau"]
	# Walk away with the joystick, with the phone up (D7). A second coroutine
	# records where the talk ends.
	_watch(d, npc)
	await d.stick_to(Vector3(npc.global_position.x + 12.0, 0.0, 0.3))
	await d.wait_until(func() -> bool: return _done, 20.0, "the watch ends")
	var ended_at := _ended_at
	var called := _called
	d.expect(ended_at >= 6.0 and ended_at < 7.5, "the talk ends at 6 m: %.2f m" % ended_at)
	d.expect(called, "Cô Sáu calls after the player")
	await d.wait_frames(2)
	d.expect(d.find("reply.cam_on") == null, "the phrasebook has no replies after the talk")
	d.expect(await d.open_app("clock"), "the phone stays usable")
	await d.screenshot("after_walk_away")


var _ended_at := -1.0
var _called := false
var _done := false


func _watch(d: PlaytestDriver, npc: Npc) -> void:
	var end := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < end:
		var s := d.state()
		if s.talk_npc == "" and _ended_at < 0.0:
			_ended_at = Vector2(npc.global_position.x - s.player.x, npc.global_position.z - s.player.z).length()
		if s.speaking.get("cosau", "") == "cosau.call_after":
			_called = true
		if _ended_at >= 0.0 and _called and not s.speaking.has("cosau"):
			break
		await d.wait_frames(1)
	_done = true
