extends RefCounted
# PT-09 soak. Use seed 1. Do 200 random taps on the floor, the spots, the
# people, and the visible buttons of the phone (plan 0003). Between the taps, do random joystick touches and look
# drags. Check that there is no script error, and that the player is always
# on the floor and never in a wall.
# The 200 taps are in 10 runs of 20, so that each run is shorter than 180 s at
# 2400×1080 under lavapipe. The random number state goes from one run to the
# next, so the taps are one sequence with seed 1. The game starts again
# between the runs, from the same save file.
# After each action, the test waits until the player stops walking (not for a
# number of frames), so a slow computer makes the same walk (report 0003,
# D-0003-05). Not more than 40 % of all 200 taps can be impossible.
# Report 0009, D-0009-26: in run 2 the cart of mía came at its opening hour
# (10:00) where the player stood (action 36), and the player was in its solid.
# The last run has a step for it: the player walks to the place of the cart
# before 10:00, the clock goes to 10:00 (a setup step), and the player is not in
# a solid; the cart waits, and comes when the player steps to its stand point.
# phase: --start-time=06:00 --seed=1
# phase: --seed=1
# phase: --seed=1
# phase: --seed=1
# phase: --seed=1
# phase: --seed=1
# phase: --seed=1
# phase: --seed=1
# phase: --seed=1
# phase: --seed=1

const TAPS := 200
const RUNS := 10
## The longest wait for the end of a walk, in game time.
const WALK_WAIT_S := 10.0


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
					await d.look_at_id(nearest)
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
		await _wait_walk_end(d)
		if not _check_body(d, i):
			break
		if (i + 1) % 25 == 0:
			await d.screenshot("tap_%03d" % (i + 1))
	var file := FileAccess.open(state_path, FileAccess.WRITE)
	file.store_string(str(rng.state))
	file.close()
	d.step("actions: %s" % [counts])
	d.step("reasons for the taps that were not possible: %s" % [reasons])
	# A run of 20 taps can end in a corner where more taps are not possible,
	# so the rule of 40 % is for all 200 taps, at the end of the last run.
	var totals_path := d.out_dir.path_join("skipped_taps.txt")
	var skipped := counts.skipped as int
	if d.phase > 1 and FileAccess.file_exists(totals_path):
		skipped += FileAccess.get_file_as_string(totals_path).to_int()
	var totals := FileAccess.open(totals_path, FileAccess.WRITE)
	totals.store_string(str(skipped))
	totals.close()
	if d.phase == RUNS:
		# After the random taps, so that their sequence stays the same.
		await _cart_comes_where_the_player_stands(d)
		await _shutter_waits_for_the_player(d)
		d.expect(skipped <= TAPS * 2 / 5, "more than 40 %% of the random taps were not possible: %d of %d" % [skipped, TAPS])


## Waits until the player stops walking, but not more than WALK_WAIT_S of game time.
func _wait_walk_end(d: PlaytestDriver) -> void:
	var timer := d.main().get_tree().create_timer(WALK_WAIT_S)
	while d.state().walking and timer.time_left > 0.0:
		await d.wait_frames(1)


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


## The half sizes of the solid of a cart of the hẻm (Hem._build_cart()).
const CART_HALF_WIDTH := 0.7
const CART_HALF_DEPTH := 0.375


## Report 0009, D-0009-26: a cart comes at its opening hour, also where the
## player stands. The cart waits while the player is in its place.
func _cart_comes_where_the_player_stands(d: PlaytestDriver) -> void:
	var hem: Hem = d.main().hem
	var cart: Node3D = hem.carts["mia"]
	var open := int(Content.spot("mia").hours.open)
	await d.lower_phone()
	# Setup: the clock before the hour of the cart (as start_at() puts the player).
	GameState.set_minutes(open - 2)
	await d.wait_frames(3)
	while hem.is_baking():
		await d.wait_frames(1)
	d.expect(not cart.visible, "the cart of mía is not there before %s" % GameClock.format_time(open))
	var place := cart.global_position
	# A point in the box of the cart near its front: the step of the house is
	# behind the cart, and in CI the player stopped 0.6 m short of the middle.
	if not await d.walk_toward(place.x, place.z + CART_HALF_DEPTH - 0.05):
		return
	await _wait_walk_end(d)
	var at: Vector3 = d.state().player
	d.step("the player stands at %s, in the place of the cart of mía (%.2f, %.2f)" % [at, place.x, place.z])
	if not d.expect(absf(at.x - place.x) <= CART_HALF_WIDTH + Player.RADIUS and absf(at.z - place.z) <= CART_HALF_DEPTH + Player.RADIUS,
			"the player stands where the solid of the cart comes (%.2f, %.2f from its middle)" % [at.x - place.x, at.z - place.z]):
		return
	GameState.set_minutes(open)
	await d.wait_frames(3)
	d.expect(d.player_overlaps().is_empty(), "at %s the player is not in a solid: %s" % [
			GameClock.format_time(open), d.player_overlaps()])
	d.expect(not cart.visible, "the cart of mía waits while the player stands in its place")
	await d.look_at_point(place + Vector3(0, 0.8, 0), 6.0, 20.0)
	await d.wait_frames(3)
	await d.screenshot("cart_waits")
	var stand: Vector3 = hem.stand_points["mia"]
	if not await d.walk_toward(stand.x, stand.z):
		return
	await _wait_walk_end(d)
	GameState.set_minutes(open + 1)
	await d.wait_frames(3)
	d.expect(cart.visible, "the cart of mía comes when the player steps away")
	d.expect(d.player_overlaps().is_empty(), "the player is not in a solid when the cart comes: %s" % [d.player_overlaps()])
	await d.look_at_point(place + Vector3(0, 0.8, 0), 6.0, 20.0)
	await d.wait_frames(3)
	await d.screenshot("cart_comes")


## Report 0009, audit 5: in CI (2400x1080, run 8, action 152) the player
## stood in the door of the phở of cô Sáu when its shutter came down at 10:30
## (the half shutter): its solid pushed the player 0.26 m up. A shutter waits
## while the player stands in its door, and comes down when the player goes.
func _shutter_waits_for_the_player(d: PlaytestDriver) -> void:
	var hem: Hem = d.main().hem
	var house: TubeHouse = hem.houses[hem._spot_lots["pho"]]
	var close := int(Content.spot("pho").hours.close)
	# Setup: the clock before the shop closes.
	GameState.set_minutes(close - 2)
	await d.wait_frames(3)
	var door := Vector3(float(hem.lot_x[hem._spot_lots["pho"]]) - 1.2, 0.0, -hem.hem_width / 2.0 + 0.1)
	if not await d.walk_toward(door.x, door.z):
		return
	await _wait_walk_end(d)
	var at: Vector3 = d.state().player
	d.step("the player stands at %s, in the door of the phở (%.2f, %.2f)" % [at, door.x, door.z])
	if not d.expect(house.in_shutter_way(at, Player.RADIUS), "the player stands in the way of the shutter of the phở"):
		return
	GameState.set_minutes(close)
	await d.wait_frames(5)
	at = d.state().player
	d.expect(d.player_overlaps().is_empty() and at.y < 0.15, "at %s the player in the door is not in a solid and not pushed up: %s %s" % [
			GameClock.format_time(close), at, d.player_overlaps()])
	d.expect(house.shutter == TubeHouse.Shutter.OPEN, "the shutter of the phở waits while the player stands in its door")
	await d.screenshot("shutter_waits")
	var away := Vector3(door.x, 0.0, 0.2)
	if not await d.walk_toward(away.x, away.z):
		return
	await _wait_walk_end(d)
	GameState.set_minutes(close + 1)
	await d.wait_frames(5)
	d.expect(house.shutter != TubeHouse.Shutter.OPEN, "the shutter of the phở comes down when the player steps away")
	d.expect(d.player_overlaps().is_empty(), "the player is not in a solid when the shutter comes down: %s" % [d.player_overlaps()])
	await d.screenshot("shutter_down")
