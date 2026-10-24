extends RefCounted
# PT-07 tap_through. Stand the player directly in front of the bánh mì cart
# at 06:00. Tap the cart. The cart dialogue must open. The tap point is on
# the player body, so the test shows that the body does not stop the tap (R24).
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	await d.tap_id("choice.step_outside")
	await d.tap_id("choice.good_morning")
	await d.tap_id("choice.okay")
	await d.wait_idle()
	await d.bring_into_view("spot.banhmi")
	await d.tap_id("spot.banhmi")
	await d.wait_idle()
	d.expect(d.state().line == "spot.banhmi.look", "the cart dialogue opens")
	await d.tap_id("choice.okay")
	await d.wait_idle()
	var s := d.state()
	var cart: Node3D = d.find("spot.banhmi")
	d.expect(absf(s.player.x - cart.global_position.x) < 0.3 and s.player.z > cart.global_position.z,
			"the player stands directly in front of the cart: %s" % s.player)
	await d.screenshot("in_front_of_cart")
	# The middle of the player body, on the screen.
	var body := d.world_to_view(s.player + Vector3(0, 1.0, 0))
	var player_rect: Rect2 = s.player_screen_rect
	d.expect(player_rect.has_point(body), "the tap point is on the player body")
	var hit: Dictionary = d.main().pick(body)
	d.expect(hit.get("node") == cart, "behind the player body at the tap point is the cart, not %s" % hit.get("kind"))
	await d.tap(d.to_screen(body))
	await d.wait_idle()
	s = d.state()
	d.expect(s.line == "spot.banhmi.look", "a tap through the player body opens the cart dialogue, not %s" % s.line)
	await d.screenshot("cart_dialogue")
	# tap_id on the cart also works: the player body does not count as a cover.
	await d.tap_id("choice.okay")
	await d.wait_idle()
	await d.tap_id("spot.banhmi")
	await d.wait_idle()
	d.expect(d.state().line == "spot.banhmi.look", "tap_id on the cart opens the cart dialogue")
