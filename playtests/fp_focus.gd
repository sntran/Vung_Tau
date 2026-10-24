extends RefCounted
# PT-14 fp_focus. Look at Bà Tư from 2 m. The action button shows "Talk". Tap
# it. The greeting line shows, and Bà Tư faces the player. Look away. The
# action button hides. Also: the focus on a spot shows its verb.
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
	await d.wait_frames(5)
	s = d.state()
	d.expect(s.line == "batu.greet", "the action opens the greeting, not %s" % s.line)
	var to_player := Vector3(s.player.x - npc.global_position.x, 0, s.player.z - npc.global_position.z).normalized()
	var facing := npc.facing()
	d.expect(Vector3(facing.x, 0, facing.z).normalized().dot(to_player) > 0.95, "Bà Tư faces the player")
	d.expect(facing.dot(facing_before) < 0.99, "Bà Tư turned to the player")
	await d.screenshot("batu_faces_player")
	await d.tap_id("choice.chua")
	await d.tap_id("choice.thanks")
	# Look away along the hẻm: the action button hides.
	await d.look_at_point(Vector3(20, 1.6, 0), 3.0)
	s = d.state()
	d.expect(s.focus == "" and not s.action_visible, "with no focus, the action button hides")
	await d.screenshot("no_focus")
	# A spot in focus shows its verb. The phở shop is open: "Sit".
	await d.walk_toward(d.main().hem.stand_points["pho"].x, 0.0)
	await d.look_at_id("spot.pho")
	s = d.state()
	d.expect(s.focus == "spot.pho" and s.action_verb == "Sit", "the open phở shop shows \"Sit\": %s %s" % [s.focus, s.action_verb])
	await d.tap_id("action")
	await d.wait_frames(5)
	d.expect(d.state().line == "spot.pho.open", "the action on the phở shop opens its line")
	await d.screenshot("focus_pho")
