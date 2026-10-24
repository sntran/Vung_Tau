extends RefCounted
# PT-14 fp_focus. Look at Bà Tư from 2 m. The action button shows "Talk". Tap
# it. She speaks her greeting (plan 0003), and she faces the player. Look
# away. The action button hides. Also: in a talk with Cô Sáu, the focus on
# her shop shows the answer by action "Sit down".
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
	await d.skip_intro()
	var npc: Npc = d.main().hem.npcs["batu"]
	var s := d.state()
	var distance := Vector2(npc.global_position.x - s.player.x, npc.global_position.z - s.player.z).length()
	d.expect(distance <= 2.2, "the player is about 2 m from Bà Tư: %.2f m" % distance)
	var facing_before := npc.facing()
	await d.look_at_id("npc.batu")
	s = d.state()
	d.expect(s.focus == "npc.batu", "the focus is Bà Tư, not \"%s\"" % s.focus)
	d.expect(s.action_visible and s.action_verb == "Talk", "the action button shows \"Talk\", not \"%s\"" % s.action_verb)
	await d.screenshot("focus_batu")
	await d.tap_id("action")
	var line := await d.wait_line("batu")
	s = d.state()
	d.expect(line == "batu.greet", "the action starts the greeting, not \"%s\"" % line)
	var to_player := Vector3(s.player.x - npc.global_position.x, 0, s.player.z - npc.global_position.z).normalized()
	var facing := npc.facing()
	d.expect(Vector3(facing.x, 0, facing.z).normalized().dot(to_player) > 0.95, "Bà Tư faces the player")
	d.expect(facing.dot(facing_before) < 0.99, "Bà Tư turned to the player")
	await d.screenshot("batu_faces_player")
	await d.answer("chua", "play")
	await d.wait_quiet()
	await d.lower_phone()
	# Look away along the hẻm: the action button hides.
	await d.look_at_point(Vector3(20, 1.6, 0), 3.0)
	s = d.state()
	d.expect(s.focus == "" and not s.action_visible, "with no focus, the action button hides")
	await d.screenshot("no_focus")
	# In a talk with Cô Sáu, her shop shows the answer by action.
	await d.walk_toward(d.main().hem.stand_points["pho"].x, 0.0)
	line = await d.talk_to("cosau")
	d.expect(line == "cosau.open", "Cô Sáu invites the player in, not \"%s\"" % line)
	await d.wait_answer()
	await d.look_at_id("spot.pho")
	s = d.state()
	d.expect(s.focus == "spot.pho" and s.action_verb == "Sit down", "the phở shop shows \"Sit down\": %s %s" % [s.focus, s.action_verb])
	await d.screenshot("focus_pho")
	await d.tap_id("action")
	line = await d.wait_line("cosau")
	d.expect(line == "cosau.sit", "Cô Sáu answers the action, not \"%s\"" % line)
