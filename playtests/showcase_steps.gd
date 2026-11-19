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
# the walk again (within 0.3 m of its height). The openings are in four runs
# (five openings took 151 s in the workspace, and CI is about two times slower).
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
## An opening where the sand is this much under the walk has steps.
const NEEDS_STEPS := 0.4


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.showcase != null, "the Vũng Tàu world has the showcase"):
		return
	if not await d.wait_showcase():
		return
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
	var walk_y := w.ground_height(walk_point.x, walk_point.z)
	var sand_y := w.ground_height(sand_point.x, sand_point.z)
	walk_point.y = walk_y
	sand_point.y = sand_y
	var has_steps := bool(opening.get("steps", false))
	d.step("opening %d at (%.1f, %.1f): the walk %.2f m, the sand %.2f m, %s" % [
			k, at.x, at.z, walk_y, sand_y, "with steps" if has_steps else "no steps (the sand is near the height of the walk)"])
	if has_steps:
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
	# From the sand, the view back to the opening and its steps.
	await d.look_at_point(at + Vector3(0, 0.6, 0), 3.0, 15.0)
	await d.wait_frames(6)
	await d.screenshot("opening_%02d_sand" % k)
	var up := PackedVector3Array([sand_point, at, walk_point])
	reached = await d.stick_along(up, PlaytestDriver._length(up), Callable(), 6.0, false, 8.0, true)
	player = d.state().player
	d.expect(reached and absf(player.y - walk_y) <= BACK_ON_WALK + 0.1,
			"opening %d: the player walks back up to the walk: %.2f m (the walk %.2f m)" % [k, player.y, walk_y])
