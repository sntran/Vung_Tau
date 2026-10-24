extends RefCounted
# PT-26 desktop_controls (plan 0004, R2, R3). Keyboard and mouse: walk the
# hẻm, look, act on Bà Tư with E, raise the phone with Tab, use the Listen app
# with the mouse, lower the phone with a right click. Esc shows the home
# screen of the phone (the menu of the game).
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
	await d.skip_intro()
	var view: Vector2 = d.state().view_size
	# A click of the mouse on the world captures the cursor.
	await d.mouse_click(d.to_screen(Vector2(view.x * 0.62, view.y * 0.3)))
	d.expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "a click on the world captures the cursor")
	d.expect(not d.state().walking, "the click that captures the cursor does not walk")
	# The mouse turns the view.
	var yaw0: float = d.state().target_yaw
	await d.mouse_move(Vector2(120, 0))
	await d.wait_idle()
	d.expect(float(d.state().target_yaw) < yaw0 - 8.0, "the mouse to the right turns the view to the right: %.1f to %.1f" % [yaw0, d.state().target_yaw])
	var pitch0: float = d.state().pitch
	await d.mouse_move(Vector2(0, -80))
	await d.wait_idle()
	d.expect(float(d.state().pitch) > pitch0 + 4.0, "the mouse up turns the view up")
	# W walks along the hẻm.
	await d.mouse_look_at(Vector3(20.0, 1.6, 0.0))
	var p0: Vector3 = d.state().player
	await d.key(KEY_W, 1.5)
	await d.wait_idle()
	var walked: float = d.state().player.distance_to(p0)
	d.expect(walked > 1.0, "W walks the player: %.2f m" % walked)
	await d.screenshot("walked")
	# Walk back to Bà Tư. Then look at her and act with E.
	await d.mouse_look_at(Vector3(p0.x, 1.6, p0.z))
	await d.key(KEY_W, 1.5)
	await d.wait_idle()
	var batu: Npc = d.main().hem.npcs["batu"]
	await d.mouse_look_at(batu.head_position(), 4.0)
	await d.wait_idle()
	d.expect(d.state().focus == "npc.batu", "Bà Tư is the focus: %s" % d.state().focus)
	await d.key(KEY_E)
	await d.wait_frames(5)
	d.expect(d.state().talk_npc == "batu", "E starts the talk with Bà Tư: %s" % d.state().talk_npc)
	await d.screenshot("talk_with_e")
	# Tab raises the phone. The cursor is free.
	await d.key(KEY_TAB)
	d.expect(d.state().phone_up, "Tab raises the phone")
	d.expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the cursor is free when the phone is up")
	# W still walks with the phone up (R3).
	var p1: Vector3 = d.state().player
	await d.key(KEY_W, 0.6)
	await d.wait_idle()
	d.expect(d.state().player.distance_to(p1) > 0.2, "W walks with the phone up")
	# The mouse uses the Listen app.
	await d.mouse_click(d.screen_center_of("phone.app.listen"))
	d.expect(d.state().app == "listen", "a click opens the Listen app: %s" % d.state().app)
	await d.screenshot("listen_with_mouse")
	await d.mouse_click(d.screen_center_of("phone.home"))
	d.expect(d.state().app == "", "a click on Home shows the home screen")
	# A right click lowers the phone, and the cursor is captured again.
	await d.mouse_click(d.to_screen(Vector2(view.x * 0.3, view.y * 0.3)), MOUSE_BUTTON_RIGHT)
	d.expect(not d.state().phone_up, "a right click lowers the phone")
	d.expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "the cursor is captured again")
	# Esc shows the home screen of the phone (the menu), and Esc again lowers it.
	await d.key(KEY_ESCAPE)
	d.expect(d.state().phone_up and d.state().app == "", "Esc shows the home screen of the phone")
	d.expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the cursor is free on the menu")
	await d.screenshot("menu")
	await d.key(KEY_ESCAPE)
	d.expect(not d.state().phone_up, "Esc again lowers the phone")
