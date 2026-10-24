extends RefCounted
# PT-02 walk_hem. Walk from the homestay to Bãi Trước with floor taps only,
# then back with the walk buttons only. At each lot, check that the player
# is within 1 m of the target. Check that the clock moved forward the correct
# number of minutes for the distance. Check that the player is always on the
# floor (Y within 0.1 m of the floor). Screenshot each lot. At the end, the
# arrow keys walk the player the same as the walk buttons.
# phase: --start-time=06:00

var _off_floor := false


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	await d.tap_id("choice.step_outside")
	await d.tap_id("choice.good_morning")
	await d.tap_id("choice.okay")
	await d.wait_idle()
	var start_time: int = d.state().time
	var hem: Node = d.main().hem
	var targets: Array = []
	for lot: Dictionary in Content.layout.lots:
		targets.append({"name": lot.id, "pos": Vector3(hem.lot_x[lot.id], 0, 0.5)})
	targets.append({"name": "hem_end", "pos": Vector3(hem.end_x + 1.5, 0, 0.5)})
	targets.append({"name": "beach_road", "pos": Vector3(hem.end_x + 5.5, 0, 0.5)})
	var expected_walk := 0.0
	var last: Vector3 = d.state().player
	# Floor taps to the beach. The first lot is the start point, so skip it.
	for i in range(1, targets.size()):
		var target: Dictionary = targets[i]
		if not await d.tap_floor(target.pos):
			return
		await _walk_and_watch(d)
		var s := d.state()
		var pos: Vector3 = s.player
		var miss := Vector2(pos.x - target.pos.x, pos.z - target.pos.z).length()
		d.expect(miss <= 1.0, "%s: the player is %.2f m from the target" % [target.name, miss])
		expected_walk += Vector2(pos.x - last.x, pos.z - last.z).length()
		last = pos
		_check_clock(d, start_time, expected_walk, target.name)
		await d.screenshot("tap_" + target.name)
	d.expect(d.state().player.x > hem.end_x, "the player is on the beach road")
	# Back to the homestay with the walk buttons only.
	var guard := 0
	while d.state().player.x > 0.5 and guard < 10:
		guard += 1
		var before: Vector3 = d.state().player
		if not await d.tap_id("walk.left"):
			return
		await _walk_and_watch(d)
		var after: Vector3 = d.state().player
		var expected_x := maxf(before.x - 6.0, hem.start_x + 0.3)
		d.expect(absf(after.x - expected_x) <= 1.0,
				"walk.left: the player is at x=%.2f, the target is x=%.2f" % [after.x, expected_x])
		expected_walk += Vector2(after.x - before.x, after.z - before.z).length()
		_check_clock(d, start_time, expected_walk, "walk.left %d" % guard)
		await d.screenshot("walk_left_%d" % guard)
	d.expect(d.state().player.x <= 0.5, "the walk buttons bring the player back to the homestay")
	# The arrow keys do the same as the walk buttons.
	var from: Vector3 = d.state().player
	await d.key(KEY_RIGHT)
	await _walk_and_watch(d)
	var to: Vector3 = d.state().player
	d.expect(absf(to.x - from.x - 6.0) <= 1.0, "the right arrow key walks 6 m (%.2f m)" % (to.x - from.x))
	expected_walk += absf(to.x - from.x)
	await d.key(KEY_LEFT)
	await _walk_and_watch(d)
	expected_walk += absf(d.state().player.x - to.x)
	d.expect(absf(d.state().player.x - from.x) <= 1.0, "the left arrow key walks back 6 m")
	_check_clock(d, start_time, expected_walk, "arrow keys")
	d.expect(not _off_floor, "the player is always on the floor")
	await d.screenshot("back_home")


## Waits until the player stops. Checks the height of the player in each frame.
func _walk_and_watch(d: PlaytestDriver) -> void:
	await d.wait_frames(2)
	var ok: bool = await d.wait_until(func() -> bool:
		var s := d.state()
		if absf(s.player.y) > 0.1 and not _off_floor:
			_off_floor = true
			d.fail("the player is not on the floor: y=%.3f" % s.player.y)
		return not s.walking and s.camera_settled, 40.0, "the player stops")
	if not ok:
		return


func _check_clock(d: PlaytestDriver, start_time: int, walked: float, where: String) -> void:
	var s := d.state()
	d.expect(absf(s.walked_total_m - walked) <= 0.6,
			"%s: the game counts %.2f m, the straight distance is %.2f m" % [where, s.walked_total_m, walked])
	var expected := start_time + int(floor(s.walked_total_m / GameClock.METERS_PER_MINUTE))
	d.expect(s.time == expected, "%s: the clock is %s, it must be %s for %.1f m" % [where, s.time_text,
			GameClock.format_time(expected), s.walked_total_m])
