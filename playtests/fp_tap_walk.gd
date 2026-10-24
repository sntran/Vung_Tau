extends RefCounted
# PT-13 fp_tap_walk. Tap a spot that is 10 m away. The player arrives, and
# the Lens app shows the cart (plan 0003). Tap a spot that is 25 m away. The
# player walks 15 m toward it and stops. Tap the ground. Start a joystick
# touch during a tap walk. The tap walk stops.
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
	await d.skip_intro()
	var hem: Node = d.main().hem
	# The bánh mì cart is about 9 m from the homestay door.
	var from: Vector3 = d.state().player
	var cart: Vector3 = hem.stand_points["banhmi"]
	d.expect(Vector2(cart.x - from.x, cart.z - from.z).length() > 8.0, "the cart is about 10 m away")
	await d.look_at_id("spot.banhmi")
	await d.tap_id("spot.banhmi")
	await d.wait_idle()
	var s := d.state()
	d.expect(Vector2(s.player.x - cart.x, s.player.z - cart.z).length() < 0.5, "the player is at the cart: %s" % s.player)
	await d.open_app("lens")
	await d.look_at_id("spot.banhmi")
	await d.wait_frames(3)
	d.expect(d.main().lens_card().get("line", "") == "spot.banhmi.look", "the Lens shows the cart: %s" % d.main().lens_card())
	await d.screenshot("at_cart")
	await d.lower_phone()
	# The beach is more than 25 m away: the player walks 15 m and stops.
	from = d.state().player
	var beach: Vector3 = hem.stand_points["beach"]
	var far := Vector2(beach.x - from.x, beach.z - from.z).length()
	d.expect(far > 25.0, "the beach is more than 25 m away: %.1f m" % far)
	await d.look_at_id("spot.beach")
	await d.tap_id("spot.beach")
	await d.wait_idle()
	s = d.state()
	var walked := Vector2(s.player.x - from.x, s.player.z - from.z).length()
	d.expect(absf(walked - 15.0) <= 1.0, "a tap on a spot 25 m away walks 15 m: %.2f m" % walked)
	var beach_left := Vector2(beach.x - s.player.x, beach.z - s.player.z).length()
	d.expect(beach_left > 9.0, "the player stops before the beach: %.1f m" % beach_left)
	await d.screenshot("walked_15m")
	# A tap on the ground walks there.
	var ground := Vector3(s.player.x - 4.0, 0, 0.5)
	await d.look_at_point(ground, 5.0)
	await d.tap_floor(ground)
	await d.wait_idle()
	var at: Vector3 = d.state().player
	d.expect(Vector2(at.x - ground.x, at.z - ground.z).length() < 0.6, "a tap on the ground walks there: %s" % at)
	# A joystick touch during a tap walk stops the walk.
	var goal := Vector3(at.x - 10.0, 0, 0)
	await d.look_at_point(goal, 5.0)
	await d.tap_floor(goal)
	# Wait only until the walk starts: at a low frame rate, ten frames are a
	# long walk.
	d.expect(await d.wait_until(func() -> bool: return d.state().walking, 10.0, "the tap walk starts"),
			"the tap walk starts")
	await d.hold_stick(Vector2(1, 0), 0.3)
	await d.wait_idle()
	s = d.state()
	d.expect(not s.walking, "a joystick touch stops the tap walk")
	d.expect(Vector2(s.player.x - goal.x, s.player.z - goal.z).length() > 3.0, "the player did not walk to the goal: %s" % s.player)
	# A look drag also stops a tap walk.
	at = s.player
	goal = Vector3(at.x + 12.0, 0, 0)
	await d.look_at_point(goal, 5.0)
	await d.tap_floor(goal)
	await d.wait_until(func() -> bool: return d.state().walking, 10.0, "the second tap walk starts")
	var start := d.to_screen(await d._free_point("look"))
	await d.drag(start, start + Vector2(0, 40), 0.3)
	await d.wait_idle()
	s = d.state()
	d.expect(not s.walking and Vector2(s.player.x - goal.x, s.player.z - goal.z).length() > 3.0,
			"a look drag stops the tap walk")
	await d.screenshot("stopped")
