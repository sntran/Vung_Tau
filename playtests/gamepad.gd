extends RefCounted
# PT-27 gamepad (plan 0004, R2). The steps of PT-26 with gamepad events: the
# left stick walks, the right stick looks, A acts on Bà Tư, Y raises the
# phone, the D-pad and A open the Listen app, B goes back, and Y lowers the phone.
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
	await d.skip_intro()
	# The right stick turns the view.
	var yaw0: float = d.state().target_yaw
	await d.pad_stick(true, Vector2(0.8, 0), 0.4)
	await d.wait_idle()
	d.expect(float(d.state().target_yaw) < yaw0 - 8.0, "the right stick to the right turns the view to the right: %.1f to %.1f" % [yaw0, d.state().target_yaw])
	# The left stick walks along the hẻm.
	await d.pad_look_at(Vector3(20.0, 1.6, 0.0))
	var p0: Vector3 = d.state().player
	await d.pad_stick(false, Vector2(0, -1), 1.5)
	await d.wait_idle()
	var walked: float = d.state().player.distance_to(p0)
	d.expect(walked > 1.0, "the left stick walks the player: %.2f m" % walked)
	await d.screenshot("walked")
	# Back to Bà Tư, and A acts on her.
	await d.pad_look_at(Vector3(p0.x, 1.6, p0.z))
	await d.pad_stick(false, Vector2(0, -1), 1.5)
	await d.wait_idle()
	var batu: Npc = d.main().hem.npcs["batu"]
	await d.pad_look_at(batu.head_position(), 4.0)
	await d.wait_idle()
	d.expect(d.state().focus == "npc.batu", "Bà Tư is the focus: %s" % d.state().focus)
	await d.pad_button(JOY_BUTTON_A)
	await d.wait_frames(5)
	d.expect(d.state().talk_npc == "batu", "A starts the talk with Bà Tư: %s" % d.state().talk_npc)
	await d.screenshot("talk_with_a")
	# Y raises the phone. The D-pad selects the Listen app, and A opens it.
	await d.pad_button(JOY_BUTTON_Y)
	d.expect(d.state().phone_up, "Y raises the phone")
	if await d.pad_select("phone.app.listen"):
		await d.pad_button(JOY_BUTTON_A)
		d.expect(d.state().app == "listen", "A opens the Listen app: %s" % d.state().app)
		await d.screenshot("listen_with_gamepad")
	# B goes back to the home screen, and B again lowers the phone.
	await d.pad_button(JOY_BUTTON_B)
	d.expect(d.state().phone_up and d.state().app == "", "B shows the home screen")
	await d.pad_button(JOY_BUTTON_B)
	d.expect(not d.state().phone_up, "B on the home screen lowers the phone")
	# Y raises and lowers the phone.
	await d.pad_button(JOY_BUTTON_Y)
	await d.pad_button(JOY_BUTTON_Y)
	d.expect(not d.state().phone_up, "Y lowers the phone")
