extends RefCounted
# PT-09 soak. Use seed 1. Do 200 random taps on the floor, the spots, the
# people, and the visible buttons of the phone (plan 0003). Between the taps, do random joystick touches and look
# drags. Check that there is no script error, and that the player is always
# on the floor and never in a wall.
# The 200 taps are in 4 runs of 50, so that each run is shorter than 180 s at
# 2400×1080 under lavapipe. The random number state goes from one run to the
# next, so the taps are one sequence with seed 1. The game starts again
# between the runs, from the same save file.
# phase: --start-time=06:00 --seed=1
# phase: --seed=1
# phase: --seed=1
# phase: --seed=1

const TAPS := 200
const RUNS := 4


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var state_path := d.out_dir.path_join("rng_state.txt")
	if d.phase > 1:
		rng.state = FileAccess.get_file_as_string(state_path).to_int()
	var spot_ids: Array[String] = []
	for spot: Dictionary in Content.spot_list():
		spot_ids.append("spot." + spot.id)
	for npc: Dictionary in Content.npc_list():
		if npc.get("talk", true):
			spot_ids.append("npc." + npc.id)
	var counts := {"floor": 0, "spot": 0, "phone": 0, "skipped": 0, "stick": 0, "look": 0}
	var reasons := {}
	var per_run := TAPS / RUNS
	for i in range((d.phase - 1) * per_run, d.phase * per_run):
		var s := d.state()
		var kind := rng.randi_range(0, 2)
		var error := ""
		if kind == 0:
			# A random floor point near the player, in the view and not under a control.
			var point: Variant = _floor_point(d, s, rng)
			if point == null:
				# A wall fills the view: turn around, as a player does.
				var from := d.to_screen(await d._free_point("look"))
				await d.drag(from, from + Vector2(-300, 0), 0.3)
				await d.wait_idle(5.0)
				point = _floor_point(d, d.state(), rng)
			if point == null:
				error = "no ground in the view"
			else:
				await d.tap(d.to_screen(point))
			counts.floor += 1
		elif kind == 1:
			var on_screen := _visible_targets(d, spot_ids)
			if on_screen.is_empty():
				# No place in the view: look for the nearest one, as a player does.
				await d.lower_phone()
				var nearest := _nearest_target(d, spot_ids)
				if nearest != "":
					await d.look_at_id(nearest, 10.0)
				on_screen = _visible_targets(d, spot_ids)
			if on_screen.is_empty():
				error = "no spot on the screen"
			else:
				error = await d.try_tap_id(on_screen[rng.randi_range(0, on_screen.size() - 1)])
			counts.spot += 1
		else:
			# The phone button, or a button of the open app.
			var buttons: Array = d.visible_choice_ids()
			buttons.append("phone.button")
			error = await d.try_tap_id(buttons[rng.randi_range(0, buttons.size() - 1)])
			counts.phone += 1
		if error != "":
			counts.skipped += 1
			var reason := error.get_slice(" at ", 0).get_slice("(", 0)
			reasons[reason] = reasons.get(reason, 0) + 1
		# Some joystick touches and look drags between the taps.
		if rng.randf() < 0.15:
			var direction := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			await d.hold_stick(direction, rng.randf_range(0.2, 0.8))
			counts.stick += 1
		elif rng.randf() < 0.15:
			var start := d.to_screen(await d._free_point("look"))
			await d.drag(start, start + Vector2(rng.randf_range(-150, 150), rng.randf_range(-60, 60)), 0.2)
			counts.look += 1
		await d.wait_frames(rng.randi_range(0, 1))
		if not _check_body(d, i):
			break
		if (i + 1) % 25 == 0:
			await d.screenshot("tap_%03d" % (i + 1))
	var file := FileAccess.open(state_path, FileAccess.WRITE)
	file.store_string(str(rng.state))
	file.close()
	d.step("actions: %s" % [counts])
	d.step("reasons for the taps that were not possible: %s" % [reasons])
	# The timing of a slower computer (CI) changes the random walk, so some runs
	# end in a corner where more taps are not possible.
	d.expect(counts.skipped <= per_run * 2 / 5, "more than 40 %% of the random taps were not possible: %s" % [counts])


## The spots and the people that the player can see: the first thing on the
## ray, and not under a control.
func _visible_targets(d: PlaytestDriver, ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var phone: Rect2 = d.state().phone_rect
	for id in ids:
		var where := d.locate(id)
		if where.error != "" or phone.has_point(where.point):
			continue
		var hit: Dictionary = d.main().pick(where.point)
		if hit.kind != "" and "%s.%s" % [hit.kind, hit.get("id", "")] == id:
			result.append(id)
	return result


## The nearest spot or person that is there now.
func _nearest_target(d: PlaytestDriver, ids: Array[String]) -> String:
	var best := ""
	var best_distance := INF
	var at: Vector3 = d.state().player
	for id in ids:
		var node := d.find(id) as Node3D
		if node == null:
			continue
		var distance := at.distance_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = id
	return best


## Returns a random screen point (base coordinates) where a tap reaches the
## floor, not under a control, or null. It only reads the game.
func _floor_point(d: PlaytestDriver, s: Dictionary, rng: RandomNumberGenerator) -> Variant:
	var view: Vector2 = s.view_size
	var blocked: Array[Rect2] = [s.phone_rect.grow(8.0), s.phone_button_rect.grow(8.0)]
	if d.main().action_button.visible:
		blocked.append(d.main().action_button.get_global_rect().grow(8.0))
	for attempt in 30:
		var point := Vector2(rng.randf_range(0.05, 0.95) * view.x, rng.randf_range(0.5, 0.97) * view.y)
		var free := true
		for rect in blocked:
			if rect.has_point(point):
				free = false
		if not free:
			continue
		var hit: Dictionary = d.main().pick(point)
		if hit.kind == "floor" and (hit.node as CollisionObject3D).collision_layer & Layers.FLOOR:
			return point
	return null


## The player is on a floor (the hẻm, the road, the steps, or the sand) and not in a wall.
func _check_body(d: PlaytestDriver, i: int) -> bool:
	var s := d.state()
	var p: Vector3 = s.player
	var overlaps := d.player_overlaps()
	if p.y > 0.25 or p.y < Beach.SAND_Y - 0.1 or not overlaps.is_empty():
		var space: PhysicsDirectSpaceState3D = d.main().get_world_3d().direct_space_state
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p - Vector3(0, 1.0, 0)))
		var under: String = str((below.collider as Node).get_path()) if not below.is_empty() else "nothing"
		var probe := PhysicsShapeQueryParameters3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = Player.RADIUS + 0.05
		capsule.height = Player.HEIGHT + 0.1
		probe.shape = capsule
		probe.transform = Transform3D(Basis(), p + Vector3(0, Player.HEIGHT / 2.0, 0))
		for hit: Dictionary in space.intersect_shape(probe):
			under += ", near %s" % (hit.collider as Node).get_path()
		d.fail("action %d: the player left the floor or is in a wall at %s %s, on %s" % [i + 1, p, overlaps, under])
		return false
	return true
