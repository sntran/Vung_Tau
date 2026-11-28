extends RefCounted
# PT-77 showcase_steps (plan 0026; report 0026, D-0026-26). With the joystick,
# at 17:00, the player walks through each opening of the low wall of the beach
# (Showcase.wall_openings): from the walk WALK_BACK m before the opening, down
# the steps to the sand SAND_OUT m past the wall, and back up to the walk. A
# screenshot of each opening from the walk and one from the sand. The steps go
# down on the side of the sand: the sand is lower than the walk at each opening
# with steps (in audit 3 the steps went up from the walk to the top of the wall
# at the flat north end of the line). The player reaches the sand (on the
# ground, at least MIN_DROP m under the walk where the opening has steps) and
# the walk again (within 0.3 m of its height). The model of the steps has its
# top at the walk and its foot on the sand (TOP_ON_WALK, FOOT_ON_SAND). The openings are in four runs
# (five openings took 151 s in the workspace, and CI is about two times slower).
# Report 0026, D-0026-33: no part stands in the way of an opening (the body of
# the player, PLAYER_RADIUS, from WALK_BACK m on the walk to SAND_OUT m on the
# sand), and no lamp pole stands nearer than POLE_CLEAR m to a side of an
# opening (in audit 4 a blue pole stood at the top of the steps of openings 0
# and 3). The walkers of the showcase go away for the walk (a setup step,
# PlaytestDriver.clear_walkers()).
# sizes: 1280x720
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low

const RUNS := 4
## The start on the walk before the opening, and the point on the sand past the wall (m).
const WALK_BACK := 3.0
const SAND_OUT := 4.5
## At an opening with steps, the sand is at least this much under the walk (the steps are scaled to the drop from 0.25 m).
const MIN_DROP := 0.2
const BACK_ON_WALK := 0.3
## The top of the model of the steps and the walk 1 m from the wall, and its foot and the sand (m).
const TOP_ON_WALK := 0.25
## The longest time of the turn from the sand back to the opening (s of real time).
const LOOK_BACK_S := 45.0
const FOOT_ON_SAND := 0.3
## An opening where the sand is this much under the walk has steps.
const NEEDS_STEPS := 0.4
## D-0026-33: the radius of the body of the player, and the least distance of a pole from a side of an opening (m).
const PLAYER_RADIUS := 0.3
const POLE_CLEAR := 1.5


func run(d: PlaytestDriver) -> void:
	# Plan 0018, R2: the people of the showcase that show come from the minute;
	# the clock stays at the time of the run, so that the set of the walkers is
	# the same in each run (a walker stood in opening 4 when the clock ran).
	d.hold_clock()
	var w := d.world()
	if not d.expect(w != null and w.showcase != null, "the Vũng Tàu world has the showcase"):
		return
	if not await d.wait_showcase():
		return
	# Report 0031, round 4: the walkers walk with the frames also with the clock
	# held, and in CI one stood in opening 4 and waited for the player there.
	# The test is of the fixed way through each opening: the walkers go away.
	d.step("the walkers of the showcase go away for the walk through the openings: %d" % d.clear_walkers())
	var openings: Array = w.showcase.wall_openings
	if not d.expect(openings.size() > 0, "the low wall of the beach has openings: %d" % openings.size()):
		return
	var steps := 0
	for opening: Dictionary in openings:
		steps += 1 if bool(opening.get("steps", false)) else 0
	d.step("%d openings, %d with steps down to the sand" % [openings.size(), steps])
	var per_run := ceili(float(openings.size()) / RUNS)
	var first := (d.phase - 1) * per_run
	for k in range(first, mini(first + per_run, openings.size())):
		await _walk_through(d, w, k, openings[k])
	d.fly_end()


func _walk_through(d: PlaytestDriver, w: VungTau, k: int, opening: Dictionary) -> void:
	var at: Vector3 = opening.at
	var sand: Vector3 = opening.get("sand", Vector3.ZERO)
	if not d.expect(sand != Vector3.ZERO, "opening %d knows its side of the sand" % k):
		return
	var walk_point := at - sand * WALK_BACK
	var sand_point := at + sand * SAND_OUT
	_check_way(d, w, k, opening, sand)
	var walk_y := w.ground_height(walk_point.x, walk_point.z)
	var sand_y := w.ground_height(sand_point.x, sand_point.z)
	walk_point.y = walk_y
	sand_point.y = sand_y
	var has_steps := bool(opening.get("steps", false))
	d.step("opening %d at (%.1f, %.1f): the walk %.2f m, the sand %.2f m, %s" % [
			k, at.x, at.z, walk_y, sand_y, "with steps" if has_steps else "no steps (the sand is near the height of the walk)"])
	if has_steps:
		# The model of the steps: its top at the walk next to the wall, and its
		# foot on the side of the sand, on the sand (audit 3 of the corrections:
		# the steps went down under the walk, and at an opening near a raised
		# lawn their top was about 1 m over the walk).
		var near_walk := at - sand * 1.0
		var top_y := float(opening.get("top_y", INF))
		var near_y := w.ground_height(near_walk.x, near_walk.z)
		d.expect(absf(top_y - near_y) <= TOP_ON_WALK, "opening %d: the top of the steps is at the walk: %.2f m, the walk 1 m from the wall %.2f m" % [
				k, top_y, near_y])
		var profile := PackedStringArray()
		for m: float in [3.0, 2.0, 1.0, 0.5, 0.0, -0.5, -1.0, -2.0, -3.0]:
			var q := at - sand * m
			profile.append("%.2f" % w.ground_height(q.x, q.z))
		d.step("opening %d: the top of the steps %.2f m; the ground from 3 m on the walk to 3 m on the sand: %s" % [
				k, top_y, ", ".join(profile)])
		var foot: Vector3 = opening.get("foot", at)
		var foot_ground := w.ground_height(foot.x, foot.z)
		d.expect((foot - at).dot(sand) > 1.0 and absf(foot.y - foot_ground) <= FOOT_ON_SAND,
				"opening %d: the foot of the steps is on the sand: %.1f m to the sand side of the wall, %.2f m over the ground" % [
				k, (foot - at).dot(sand), foot.y - foot_ground])
		d.expect(walk_y - sand_y >= MIN_DROP, "opening %d: the steps go down to the sand: the sand is %.2f m under the walk (at least %.2f)" % [
				k, walk_y - sand_y, MIN_DROP])
	else:
		d.expect(walk_y - sand_y < NEEDS_STEPS, "opening %d: an opening with no steps has the sand near the walk: %.2f m under it (less than %.2f)" % [
				k, walk_y - sand_y, NEEDS_STEPS])
	var yaw := rad_to_deg(atan2(-sand.x, -sand.z))
	await d.start_at(walk_point, yaw)
	await d.wait_ground(60.0)
	await d.wait_frames(6)
	await d.screenshot("opening_%02d_walk" % k)
	var down := PackedVector3Array([walk_point, at, sand_point])
	var reached := await d.stick_along(down, PlaytestDriver._length(down), Callable(), 6.0, false, 8.0, true)
	var player: Vector3 = d.state().player
	d.expect(reached, "opening %d: the player walks through the opening down to the sand" % k)
	d.expect(player.y - w.ground_height(player.x, player.z) < 0.3 and player.distance_to(sand_point) < 2.0,
			"opening %d: the player is on the sand: %.2f m over the ground, %.1f m from the point" % [
				k, player.y - w.ground_height(player.x, player.z), player.distance_to(sand_point)])
	# From the sand, the view back to the opening and its steps: a turn of about
	# 180 degrees. In CI (about two times slower) 15 s of real time was too short
	# at opening 2 (the CI of a55e83e and of ad8c8bd).
	await d.look_at_point(at + Vector3(0, 0.6, 0), 3.0, LOOK_BACK_S)
	await d.wait_frames(6)
	await d.screenshot("opening_%02d_sand" % k)
	var up := PackedVector3Array([sand_point, at, walk_point])
	reached = await d.stick_along(up, PlaytestDriver._length(up), Callable(), 6.0, false, 8.0, true)
	player = d.state().player
	d.expect(reached and absf(player.y - walk_y) <= BACK_ON_WALK + 0.1,
			"opening %d: the player walks back up to the walk: %.2f m (the walk %.2f m)" % [k, player.y, walk_y])


## D-0026-33: the things of the showcase near an opening: the lamps (their
## poles), the low lamps of the paths, and the plants and benches of the park.
## A thing in the way of the body of the player through the opening fails, and
## a lamp pole nearer than POLE_CLEAR to a side of the opening fails.
func _check_way(d: PlaytestDriver, w: VungTau, k: int, opening: Dictionary, sand: Vector3) -> void:
	var at: Vector3 = opening.at
	var along: Vector3 = opening.get("along", Vector3.RIGHT)
	along.y = 0.0
	along = along.normalized()
	var half := float(opening.get("half", 1.35))
	var things: Array = []
	for lamp: Dictionary in w.showcase.lamps:
		things.append(["the lamp %s" % lamp.get("kind", ""), lamp.at, true])
	for p: Vector3 in w.showcase.path_lamp_points:
		things.append(["a low lamp of a path", p, true])
	for plant: Dictionary in w.showcase.park_plants:
		things.append(["the %s" % plant.get("kind", "plant"), plant.get("at", Vector3.INF), false])
	var found := PackedStringArray()
	for thing: Array in things:
		var p: Vector3 = thing[1]
		if not p.is_finite():
			continue
		var offset := p - at
		offset.y = 0.0
		var side := absf(offset.dot(along))
		var out := offset.dot(sand)
		if out >= -WALK_BACK and out <= SAND_OUT and side < half - PLAYER_RADIUS:
			found.append("%s at (%.1f, %.1f) is in the way: %.1f m from the middle, %.1f m to the sand side" % [
					thing[0], p.x, p.z, side, out])
		elif bool(thing[2]) and absf(out) <= POLE_CLEAR and side < half + POLE_CLEAR:
			found.append("%s at (%.1f, %.1f) is %.1f m from the side of the opening (at least %.1f)" % [
					thing[0], p.x, p.z, side - half, POLE_CLEAR])
	d.expect(found.is_empty(), "opening %d: nothing stands in the way of the opening%s" % [
			k, "" if found.is_empty() else ": " + "; ".join(found)])
