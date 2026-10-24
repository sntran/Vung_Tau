extends RefCounted
# PT-09 soak. Use seed 1. Do 200 random taps on the floor, the spots, and
# the visible choices. Check that there is no script error and that the
# player never leaves the floor.
# phase: --start-time=06:00 --seed=1

const TAPS := 200


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var spot_ids: Array[String] = []
	for spot: Dictionary in Content.spot_list():
		spot_ids.append("spot." + spot.id)
	var counts := {"floor": 0, "spot": 0, "choice": 0, "skipped": 0}
	var reasons := {}
	var map: RID = d.main().get_world_3d().navigation_map
	for i in TAPS:
		var s := d.state()
		var kind := rng.randi_range(0, 2)
		# A sheet covers the world. Then only its choices can be tapped.
		if s.mode != "hem":
			kind = 2
		var error := ""
		if kind == 0:
			# A random floor point in the free part of the screen.
			var pos: Vector3 = s.player
			var point := Vector3.ZERO
			for attempt in 10:
				point = Vector3(pos.x + rng.randf_range(-5.0, 5.0), 0, rng.randf_range(-1.5, 1.7))
				if _in_free_part(d, s, point):
					break
			error = await d.try_tap_floor(point, false)
			counts.floor += 1
		elif kind == 1:
			# A random spot from the spots that are on the screen now.
			var on_screen: Array[String] = []
			for id in spot_ids:
				var where := d.locate(id)
				if where.error == "" and _in_free_part_2d(s, where.point):
					on_screen.append(id)
			if on_screen.is_empty():
				error = "no spot on the screen"
			else:
				error = await d.try_tap_id(on_screen[rng.randi_range(0, on_screen.size() - 1)])
			counts.spot += 1
		else:
			var choices: Array = s.choices
			if choices.is_empty():
				error = "no choices"
			else:
				error = await d.try_tap_id(choices[rng.randi_range(0, choices.size() - 1)])
			counts.choice += 1
		if error != "":
			counts.skipped += 1
			var reason := error.get_slice(" at ", 0).get_slice("(", 0)
			reasons[reason] = reasons.get(reason, 0) + 1
		await d.wait_frames(rng.randi_range(1, 4))
		var p: Vector3 = d.state().player
		var on_mesh := NavigationServer3D.map_get_closest_point(map, p)
		if absf(p.y) > 0.1 or Vector2(p.x - on_mesh.x, p.z - on_mesh.z).length() > 0.1:
			d.fail("tap %d: the player left the floor at %s" % [i + 1, p])
			break
		if (i + 1) % 25 == 0:
			await d.screenshot("tap_%03d" % (i + 1))
	d.step("taps: %s" % [counts])
	d.step("reasons for the taps that were not possible: %s" % [reasons])
	d.expect(counts.skipped < TAPS / 4, "more than a quarter of the random taps were not possible: %s" % [counts])


## Returns true when the 3D point is in the free part of the screen, away from the walk buttons.
func _in_free_part(d: PlaytestDriver, s: Dictionary, point: Vector3) -> bool:
	return _in_free_part_2d(s, d.world_to_view(point))


func _in_free_part_2d(s: Dictionary, view_point: Vector2) -> bool:
	var free: Rect2 = s.free_rect
	# The walk buttons are in the low corners of the free part.
	var inner := Rect2(free.position, free.size - Vector2(0, 130))
	return inner.has_point(view_point)
