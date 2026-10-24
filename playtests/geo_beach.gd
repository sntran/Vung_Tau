extends RefCounted
# PT-20 geo_beach. Walk from the road across the sand to the water. The player
# stops at the 0.5 m depth and the message shows.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=09:00


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts"):
		return
	await d.wait_ground()
	var beach := w.data.landmark("bai_truoc")
	if not d.expect(not beach.is_empty(), "the data has Bãi Trước"):
		return
	var start: Vector3 = d.state().player
	d.expect(not str(d.state().road_name).is_empty(), "the player starts on a road: %s" % d.state().road_name)
	await d.screenshot("road")
	# From the road to the center of the beach, then on in the same direction.
	var center := Vector3(beach.position[0], 0.0, beach.position[1])
	var direction := Vector3(center.x - start.x, 0.0, center.z - start.z).normalized()
	var route := PackedVector3Array([start, start + direction * 400.0])
	d.set_time_scale(3.0)
	var sand := [false]
	var message := [false]
	var water := Content.ui_text("water_too_deep")
	var check := func() -> void:
		var s := d.state()
		if float(s.ground) < 2.0 and str(s.road_name).is_empty():
			sand[0] = true
		if s.subtitle.get("lines", [""])[0] == water:
			message[0] = true
	await d.stick_along(route, 400.0, check, 15.0, true)
	d.set_time_scale(1.0)
	var s := d.state()
	d.expect(sand[0], "the player walks on the sand")
	var depth: float = -float(s.ground)
	d.expect(depth > 0.3 and depth <= VungTau.MAX_WATER_DEPTH + 0.02,
			"the player stops at the 0.5 m depth: the water is %.2f m deep" % depth)
	d.expect(message[0], "the message \"%s\" shows when the water stops the player" % water)
	# More joystick into the sea does not move the player into deeper water, and
	# the message shows again.
	var before: Vector3 = s.player
	await d.hold_stick(Vector2(0, -1), 1.5)
	s = d.state()
	d.expect(s.subtitle.get("lines", [""])[0] == water, "the message shows again: %s" % [s.subtitle])
	await d.screenshot("water_too_deep")
	await d.wait_idle()
	var after: Vector3 = d.state().player
	d.expect(-float(d.state().ground) <= VungTau.MAX_WATER_DEPTH + 0.02, "the player does not go into deeper water")
	d.expect(Vector2(after.x - before.x, after.z - before.z).length() < 1.0, "the player stays at the edge")
	# The player can walk back to the beach.
	await d.look_at_point(Vector3(start.x, after.y + Player.EYE_HEIGHT, start.z), 5.0)
	await d.hold_stick(Vector2(0, -1), 3.0)
	await d.wait_idle()
	d.expect(float(d.state().ground) > float(s.ground) + 0.1, "the player walks back out of the water")
	await d.screenshot("back_on_the_beach")
