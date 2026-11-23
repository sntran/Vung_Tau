extends RefCounted
# PT-11 hem_walk, a second part of PT-11 fp_walk (report 0004, D-0004-01). At
# 06:00, 07:00, 12:00, 18:00, and 20:30: at each point along the hẻm, a free
# path of 0.9 m or more (the player capsule and a margin) goes across the
# carts, the stools, and the people. Then walk the full hẻm with the joystick
# only, from the homestay to the beach road, on this free path. The player
# does not stop on the way. Each time has two runs: the walk to the middle of
# the hẻm, and the walk from there to the beach road (a run of the whole walk
# took 163 s of the limit of 180 s at 3 frames each second, and more on a slow
# CI computer). The second run puts the player where the first run stops.
# sizes: 1280x720 2400x1080
# phase: --start-time=06:00
# phase: --start-time=06:00 --fresh-save
# phase: --start-time=07:00 --fresh-save
# phase: --start-time=07:00 --fresh-save
# phase: --start-time=12:00 --fresh-save
# phase: --start-time=12:00 --fresh-save
# phase: --start-time=18:00 --fresh-save
# phase: --start-time=18:00 --fresh-save
# phase: --start-time=20:30 --fresh-save
# phase: --start-time=20:30 --fresh-save

## The free width that the player needs: the capsule and a margin.
const FREE_M := 0.9
## The distance between two points of the check along the hẻm.
const STEP_M := 0.25
## The walk starts to go to the side this distance before an obstacle.
const TURN_BEFORE_M := 1.0
## The size of a test cell across the hẻm.
const CELL_M := 0.05


func run(d: PlaytestDriver) -> void:
	await d.skip_intro()
	await d.wait_frames(4)
	var hem: Hem = d.main().hem
	var half: float = hem.hem_width / 2.0
	# The widest free part at each point along the hẻm: [from z, to z].
	var lane := {}
	var narrowest := INF
	var narrowest_x := 0.0
	var x := hem.start_x + 1.0
	while x < hem.end_x - 0.5:
		var free := _widest_free(d, x, half)
		if free.y - free.x < narrowest:
			narrowest = free.y - free.x
			narrowest_x = x
		lane[x] = free
		x += STEP_M
	d.expect(narrowest >= FREE_M, "%s: the free path is %.2f m at x %.1f, it must be %.1f m or more" % [
			d.state().time_text, narrowest, narrowest_x, FREE_M])
	d.step("%s: the narrowest free path is %.2f m at x %.1f" % [d.state().time_text, narrowest, narrowest_x])
	# Walk the full hẻm on the free path with the joystick, as a player does:
	# straight on, and to the side only as far as a cart or a person makes it
	# necessary, some steps before it.
	var points: Array = lane.keys()
	var first: Vector2 = lane[points[0]]
	var walk_z := (first.x + first.y) / 2.0
	var turns: Array[Vector3] = []
	var last_x := float(points[0])
	for point_x: float in points:
		var free: Vector2 = lane[point_x]
		var need := clampf(walk_z, free.x + FREE_M / 2.0, free.y - FREE_M / 2.0)
		if absf(need - walk_z) < 0.05:
			continue
		var before := point_x - TURN_BEFORE_M
		if before > last_x:
			turns.append(Vector3(before, 0, walk_z))
		turns.append(Vector3(point_x - STEP_M, 0, need))
		walk_z = need
		last_x = point_x
	turns.append(Vector3(points[points.size() - 1], 0, walk_z))
	d.step("the walk turns at %s" % [turns.map(func(t: Vector3) -> String: return "(%.2f, %.2f)" % [t.x, t.z])])
	# The odd runs walk to the middle of the hẻm, the even runs from there to
	# the beach road. The middle is a point on the straight walk to the first
	# turn past it.
	var middle := (hem.start_x + hem.end_x) / 2.0
	var last_turn := Vector3(float(points[0]), 0, (first.x + first.y) / 2.0)
	var split := 0
	while split < turns.size() - 1 and turns[split].x < middle:
		last_turn = turns[split]
		split += 1
	var after: Vector3 = turns[split]
	if after.x > middle and last_turn.x < middle:
		var z := lerpf(last_turn.z, after.z, (middle - last_turn.x) / (after.x - last_turn.x))
		turns.insert(split, Vector3(middle, 0, z))
	split += 1
	var second_half := d.phase % 2 == 0
	var from: Vector3
	if second_half:
		# Setup: the player stands where the first run of this time stops.
		var start: Vector3 = turns[split - 1]
		d.main().player.place(Vector3(start.x, 0.01, start.z), d.main().player.yaw)
		await d.wait_frames(5)
		d.step("the second half of the walk starts at (%.2f, %.2f)" % [start.x, start.z])
		from = start
	else:
		await d.stick_straight(Vector3(float(points[0]), 0, (first.x + first.y) / 2.0))
		from = d.state().player
	var part := turns.slice(split) if second_half else turns.slice(0, split)
	for target: Vector3 in part:
		await d.stick_straight(target)
		var at: Vector3 = d.state().player
		# A stop before the point is a blocked path. A walk a little past the
		# point is not.
		var way := Vector2(target.x - from.x, target.z - from.z)
		var left := Vector2(target.x - at.x, target.z - at.z)
		var short := left.dot(way.normalized()) if way.length() > 0.01 else 0.0
		var side := absf(left.cross(way.normalized())) if way.length() > 0.01 else left.length()
		if not d.expect(short < 0.6 and side < 0.6, "%s: the player stops at (%.2f, %.2f), %.2f m before the point (%.2f, %.2f) of the free path" % [
				d.state().time_text, at.x, at.z, short, target.x, target.z]):
			await d.screenshot("blocked")
			return
		from = target
	if not second_half:
		d.step("the first half of the walk ends at %s" % d.state().player)
		await d.screenshot("hem_middle")
		return
	await d.stick_to(Vector3(hem.end_x + 1.5, 0, 0))
	d.expect(d.state().player.x > hem.end_x, "the player walks out of the hẻm to the beach road")
	await d.screenshot("hem_end")


## Returns the start (x) and the end (y) of the widest free part across
## the hẻm at the position x. A cell is free when a box from 0.2 m to 1.7 m
## above the floor hits no wall, cart, stool, or person. The floor and the
## 8 cm steps are lower than the box.
func _widest_free(d: PlaytestDriver, x: float, half: float) -> Vector2:
	var player: Player = d.main().player
	var box := BoxShape3D.new()
	box.size = Vector3(STEP_M, 1.5, CELL_M)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.collision_mask = Layers.SOLID | Layers.MOVING
	query.exclude = [player.get_rid()]
	var space := player.get_world_3d().direct_space_state
	var best := Vector2(0, 0)
	var run_start := -half
	var z := -half + CELL_M / 2.0
	while z < half:
		query.transform = Transform3D(Basis(), Vector3(x, 0.95, z))
		if not space.intersect_shape(query, 1).is_empty():
			var width := z - CELL_M / 2.0 - run_start
			if width > best.y - best.x:
				best = Vector2(run_start, run_start + width)
			run_start = z + CELL_M / 2.0
		z += CELL_M
	if half - run_start > best.y - best.x:
		best = Vector2(run_start, half)
	return best
