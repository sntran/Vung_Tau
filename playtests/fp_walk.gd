extends RefCounted
# PT-11 fp_walk. From the homestay door, walk to Bãi Trước with the joystick
# and look drags only. Then walk back with tap to walk only (a look drag turns
# the view to the next point, and a tap makes the walk). At each lot, check the
# position (±1 m) and save a screenshot at eye height. Check that the clock
# moved by the time of the frames, not by the distance (plan 0018, R1 and R2:
# before, 1 minute for each 8 m).
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
	await d.skip_intro()
	d.expect(d.state().clock_running, "the clock runs after the start")
	var start := d.state()
	var hem: Node = d.main().hem
	var targets: Array = []
	for lot: Dictionary in Content.layout.lots:
		targets.append({"name": lot.id, "pos": Vector3(hem.lot_x[lot.id], 0, 0)})
	targets.append({"name": "hem_end", "pos": Vector3(hem.end_x + 1.5, 0, 0)})
	targets.append({"name": "beach_road", "pos": Vector3(hem.end_x + 5.0, 0, 0)})
	targets.append({"name": "sand", "pos": Vector3(hem.end_x + hem.beach.road_width + 3.0, Beach.SAND_Y, 0)})
	var walked := 0.0
	var last: Vector3 = d.state().player
	# To the beach with the joystick and look drags.
	for i in range(1, targets.size()):
		var target: Dictionary = targets[i]
		var pos: Vector3 = d.state().player
		var flat := Vector2(target.pos.x - pos.x, target.pos.z - pos.z)
		await d.look_at_point(Vector3(target.pos.x, 1.6 + target.pos.y, target.pos.z), 1.0)
		await d.hold_stick(Vector2(0, -1), flat.length() / Player.WALK_SPEED)
		await d.wait_idle()
		var at: Vector3 = d.state().player
		var miss := Vector2(at.x - target.pos.x, at.z - target.pos.z).length()
		d.expect(miss <= 1.0, "%s: the player is %.2f m from the target" % [target.name, miss])
		walked += Vector2(at.x - last.x, at.z - last.z).length()
		last = at
		_check_clock(d, start, walked, target.name)
		await d.screenshot("stick_" + target.name)
	d.expect(d.state().player.y < -0.2, "the player is on the sand of Bãi Trước")
	# Back to the homestay with tap to walk.
	targets.reverse()
	for i in range(1, targets.size()):
		var target: Dictionary = targets[i]
		var ok: bool = await d.walk_toward(target.pos.x, target.pos.z, 6.0)
		if not ok:
			return
		var at: Vector3 = d.state().player
		var miss := Vector2(at.x - target.pos.x, at.z - target.pos.z).length()
		d.expect(miss <= 1.0, "back to %s: the player is %.2f m from the target" % [target.name, miss])
		_check_clock(d, start, d.state().walked_total_m, "back to " + target.name)
		await d.screenshot("tap_" + target.name)


func _check_clock(d: PlaytestDriver, start: Dictionary, walked: float, where: String) -> void:
	var s := d.state()
	d.expect(absf(s.walked_total_m - walked) <= 1.0,
			"%s: the game counts %.2f m, the straight distance is %.2f m" % [where, s.walked_total_m, walked])
	var clock: float = s.clock_s - start.clock_s
	var frames: float = s.frame_s - start.frame_s
	d.expect(absf(clock - frames) <= 1.0, "%s: the clock moved %.1f s in %.1f s of frames (%.1f m walked): %s" % [
			where, clock, frames, s.walked_total_m, s.time_text])
