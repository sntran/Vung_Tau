extends RefCounted
# PT-74 showcase_walk (plan 0026, section 8). With the joystick, walk at 17:00
# from the north end of the park along the walk of the sea, the paths of the
# park, and the walk on the sea wall of Hạ Long to the port of Cầu Đá in front
# of Hải Âu, and 60 m onto the jetty. The player does not fall, does not walk
# through a wall or a person, and stays on the ground (or on the deck of the
# jetty). A screenshot every 50 m, and one of Hải Âu from the path. The walk of
# about 1.3 km is in eight runs, so that a run takes less than 180 s also at 3
# frames per second (PLAYTEST_MAX_FPS=3; report 0026, D-0026-01). The game
# runs six times faster and does up to 48 physics steps in one frame (a setup
# of the run, as the time scale of PT-34): the player walks at the same speed
# in game time, and the checks run at each physics step. The way along the sea
# wall never turns back, and a hold of the joystick that does not take the
# player on along the route counts as a stop (D-0026-01).
# Report 0026, D-0026-04: the walk on the sea wall is one smooth surface from
# the curb of the road to the parapet, with its tiles along its line: run 1
# checks the length of the walk with its tiles along the line, the change of
# the grade between two pieces, and casts rays down between the curb and the
# walk (each hits the walk).
# sizes: 1280x720
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low

const RUNS := 8
const TIME_SCALE := 6.0
const PHYSICS_STEPS := 48
const SHOT_EVERY := 50.0
## The walk of the sea from its north end to the park: the middle of the paving
## between the low wall and the raised lawns (data/geo/build/showcase.json).
const NORTH := [[-131.0, -356.0], [-129.5, -352.0], [-119.0, -336.0], [-106.0, -320.0], [-93.0, -304.0],
	[-80.5, -288.0], [-67.5, -272.0], [-54.0, -256.0], [-48.0, -240.0], [-46.0, -224.0], [-45.0, -208.0],
	[-42.5, -192.0], [-35.5, -176.0], [-28.5, -160.0], [-25.0, -152.0], [-15.0, -126.0]]
## The walks of the park (OSM ways, from north to south), the way through the
## south end of the park to the walk on the sea wall of Hạ Long (it starts at the
## junction of Quang Trung), and the path of the port of Cầu Đá.
const WALK_NORTH := 458829436
const WALK_SOUTH := 458829438
const TO_HA_LONG := [[20.0, 214.0], [40.0, 207.0], [60.0, 199.0], [67.0, 193.0], [78.0, 197.0]]
const PORT_PATH := 235006085
const HAI_AU := "way/790529523"
const HAI_AU_MODEL := "khach_san_hai_au"
## The walk on the deck of the jetty (m).
const ON_JETTY := 60.0
## Higher than this over the ground (m), the player stands on a part, not on the ground.
const MAX_OVER := 0.4
## The walk on the sea wall (D-0026-04): the steepest grade along it, and the
## largest change of the grade from one piece of 2 m to the next.
const MAX_WALK_GRADE := 0.12
const MAX_WALK_BEND := 0.08
## The highest curb of the walk over the road (m). At the junction at (-196,
## 428) the road of the data falls 0.8 m in 4 m (the junction keeps the height
## of the other road: tools/geo/geodata/terrain.py, _profile), and the walk
## stays smooth, 0.7 m over the road at its lowest point.
const MAX_WALK_CURB := 0.75
## Lower than this under the ground or the deck (m), the player falls.
const MAX_UNDER := 0.3
## The cells (m) of the tops of the walk on the sea wall.
const WALK_CELL := 1.0
## The first points of the way along Hạ Long on the road (every 2 m).
const ROAD_FIRST := 12
## The points (every 2 m) at each end of a piece of the walk on the sea wall
## where the route stays on the road.
const WALK_MARGIN := 2

## The top of the walk on the sea wall in each cell (Vector2i), the floor of the
## player there (not the ground under it).
var _walk_tops: Dictionary = {}
## The points where the way along the sea wall turns back.
var _backs: Array[Vector2] = []


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.showcase != null and w.places != null and not w.places.jetty.is_empty(),
			"the Vũng Tàu world has the showcase and the jetty of Cầu Đá"):
		return
	if not await d.wait_showcase():
		return
	var route := _route(w)
	var length := PlaytestDriver._length(route)
	if not d.expect(length > 900.0, "the route is %.0f m long" % length):
		return
	d.expect(_backs.is_empty(), "the way along the sea wall of Hạ Long never turns back: %s" % str(_backs))
	if d.phase == 1:
		_check_walk_surface(d, w)
	if d.phase == 5:
		_check_divided_road(d, w)
	var jetty_start := length - ON_JETTY
	var hai_au := _hai_au(w)
	var hai_au_at := PlaytestDriver.route_distance(route, hai_au) if hai_au != Vector3.INF else -1.0
	var from := length * (d.phase - 1) / RUNS
	var to := length * d.phase / RUNS
	if d.phase == RUNS:
		to = length - 1.0
	d.step("run %d of %d: %.0f m to %.0f m of %.0f m" % [d.phase, RUNS, from, to, length])
	var start := PlaytestDriver.route_point(route, from)
	var ahead := PlaytestDriver.route_point(route, from + 4.0)
	var start_cell := Vector2i(floori(start.x / WALK_CELL), floori(start.z / WALK_CELL))
	await d.start_at(start, rad_to_deg(atan2(-(ahead.x - start.x), -(ahead.z - start.z))), float(_walk_tops.get(start_cell, -INF)))
	await d.wait_frames(10)
	var player: Player = d.main().player
	var people: ShowcasePeople = w.showcase.people
	var stats := {"under": 0.0, "under_at": Vector3.ZERO, "over": 0.0, "over_at": Vector3.ZERO, "overlaps": 0, "overlap_at": Vector3.ZERO, "overlap_names": {},
			"near_person": INF, "frames": 0, "off_floor": 0, "drawn": 0}
	var check := func() -> void:
		stats.frames += 1
		var p := player.global_position
		# Under the ground or the deck: the player falls. Over them or over the
		# walk on the sea wall: the player stands on a part.
		var base := maxf(w.ground_height(p.x, p.z), w.places.floor_at(p.x, p.z))
		# Over: the highest ground under the body (a body on the edge of a steep
		# bank stands on its high side).
		var top := base
		for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var q := Vector2(p.x, p.z) + side * Player.RADIUS
			top = maxf(top, w.ground_height(q.x, q.y))
		# The walk on the sea wall in the cells around the player (the body
		# reaches into the next cell at the edge of the walk).
		var cell := Vector2i(floori(p.x / WALK_CELL), floori(p.z / WALK_CELL))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				top = maxf(top, float(_walk_tops.get(cell + Vector2i(dx, dz), -INF)))
		if player.is_on_floor():
			if p.y - top > stats.over:
				stats.over = p.y - top
				stats.over_at = p
		else:
			stats.off_floor += 1
		if base - p.y > stats.under:
			stats.under = base - p.y
			stats.under_at = p
		var hits := d.player_overlaps()
		if not hits.is_empty():
			if stats.overlaps == 0:
				stats.overlap_at = p
			stats.overlaps += 1
			for hit: String in hits:
				stats.overlap_names[hit] = true
		if people:
			for entry: Dictionary in people.walkers + people.sitters:
				var model: Node3D = entry.model
				if model.visible:
					var gap := Vector2(model.global_position.x - p.x, model.global_position.z - p.z).length()
					stats.near_person = minf(stats.near_person, gap)
	var tree := d.main().get_tree()
	var steps := Engine.max_physics_steps_per_frame
	Engine.max_physics_steps_per_frame = PHYSICS_STEPS
	tree.physics_frame.connect(check)
	var count_frame := func() -> void:
		stats.drawn += 1
	tree.process_frame.connect(count_frame)
	var started := Time.get_ticks_msec()
	d.set_time_scale(TIME_SCALE)
	# The goals of the run: each 50 m, and the point of the route in front of Hải Âu.
	var goals: Array[float] = []
	var mark := ceilf((from + 1.0) / SHOT_EVERY) * SHOT_EVERY
	while mark < to:
		goals.append(mark)
		mark += SHOT_EVERY
	goals.append(to)
	if hai_au_at > from and hai_au_at < to:
		goals.append(hai_au_at)
		goals.sort()
	var walked_all := true
	for goal in goals:
		if not await d.stick_along(route, goal, Callable(), 30.0, false, 25.0, true):
			walked_all = false
			break
		d.set_time_scale(1.0)
		if is_equal_approx(goal, hai_au_at):
			await d.look_at_point(hai_au + Vector3(0, 8.0, 0), 3.0, 20.0)
			await d.wait_frames(6)
			await d.screenshot("hai_au")
			await d.look_at_point(PlaytestDriver.route_point(route, goal + 8.0) + Vector3(0, Player.EYE_HEIGHT, 0), 4.0, 20.0)
		else:
			await d.wait_frames(4)
			await d.screenshot("walk_%04d" % roundi(goal))
		d.set_time_scale(TIME_SCALE)
	d.set_time_scale(1.0)
	tree.physics_frame.disconnect(check)
	tree.process_frame.disconnect(count_frame)
	d.step("run %d: %d frames and %d physics steps in %.0f s" % [d.phase, stats.drawn, stats.frames, (Time.get_ticks_msec() - started) / 1000.0])
	Engine.max_physics_steps_per_frame = steps
	var p := player.global_position
	var at := PlaytestDriver.route_distance(route, p)
	d.step("run %d: the player is at %.0f m of the route; %.2f m over the ground at most (at %.0f, %.0f), %.2f m under it at most; %d frames of %d physics steps off the floor; %d people near the route, the nearest at %.2f m" % [
			d.phase, at, stats.over, stats.over_at.x, stats.over_at.z, stats.under, stats.off_floor, stats.frames,
			(people.walkers.size() + people.sitters.size()) if people else 0, stats.near_person])
	d.expect(walked_all, "run %d: the player walks from %.0f m to %.0f m with the joystick (at %.0f m)" % [d.phase, from, to, at])
	d.expect(stats.under <= MAX_UNDER, "run %d: the player does not fall (%.2f m under the ground or the deck at %.0f, %.0f)" % [
			d.phase, stats.under, stats.under_at.x, stats.under_at.z])
	d.expect(stats.over <= MAX_OVER, "run %d: the player stays on the ground (%.2f m over it at %.0f, %.0f)" % [
			d.phase, stats.over, stats.over_at.x, stats.over_at.z])
	d.expect(stats.overlaps == 0, "run %d: the player is never inside a wall, a part, or a person: %s (%d steps, the first at %.1f, %.2f, %.1f)" % [
			d.phase, ", ".join(stats.overlap_names.keys()), stats.overlaps, stats.overlap_at.x, stats.overlap_at.y, stats.overlap_at.z])
	d.expect(stats.near_person >= Player.RADIUS + ShowcasePeople.BODY_RADIUS - 0.1,
			"run %d: the player does not walk through a person (the nearest at %.2f m)" % [d.phase, stats.near_person])
	if d.phase == RUNS:
		var deck := float(w.places.jetty.deck)
		d.expect(at >= jetty_start + ON_JETTY - 3.0, "the player walks %.0f m onto the jetty" % ON_JETTY)
		d.expect(w.places.floor_at(p.x, p.z) > -INF and absf(p.y - deck) < 0.3,
				"the player stands on the deck of the jetty (%.2f m, the deck %.2f m)" % [p.y, deck])
	d.expect(hai_au != Vector3.INF, "the showcase has Hải Âu (%s)" % HAI_AU)
	if d.phase == 4:
		await _check_south_paving(d, w)
		_check_square_parapet(d, w)


## The route of the walk: the walk of the sea, the walks of the park, the walk
## on the sea wall of Hạ Long (the edge of the road where the walk has a gap),
## the path of the port of Cầu Đá, and the jetty from its shore.
func _route(w: VungTau) -> PackedVector3Array:
	var route := PackedVector3Array()
	for p: Array in NORTH:
		route.append(Vector3(float(p[0]), 0.0, float(p[1])))
	_append(route, _way(w, WALK_NORTH), true)
	_append(route, _way(w, WALK_SOUTH), true)
	# The parapet of the walk on the sea wall closes it on the side of the park:
	# the route goes through the south end of the park to the junction of Quang
	# Trung, and onto the walk from the road.
	for p: Array in TO_HA_LONG:
		route.append(Vector3(float(p[0]), 0.0, float(p[1])))
	var port := _way(w, PORT_PATH)
	var jetty: PackedVector3Array = w.places.jetty.line
	if port.is_empty():
		return route
	# The end of the path of the port at the side of Hạ Long, and the point of the
	# path nearest to the shore of the jetty.
	var port_start := 0 if Vector2(port[0].x, port[0].z).distance_to(Vector2(-200, 470)) < \
			Vector2(port[port.size() - 1].x, port[port.size() - 1].z).distance_to(Vector2(-200, 470)) else port.size() - 1
	_append(route, _sea_wall_walk(w, port[port_start]), false)
	# The deck has walls on its sides: the route goes onto it along its line,
	# from a point on the land behind its shore end.
	var out := Vector3(jetty[0].x - jetty[1].x, 0.0, jetty[0].z - jetty[1].z).normalized()
	var behind := jetty[0] + out * Showcase.JETTY_BEHIND
	var port_end := _nearest(port, behind)
	var part := PackedVector3Array()
	var step := 1 if port_end >= port_start else -1
	for i in range(port_start, port_end + step, step):
		part.append(port[i])
	_append(route, part, false)
	# The jetty from its shore.
	var on := PackedVector3Array()
	var walked := 0.0
	on.append(behind)
	on.append(jetty[0])
	for i in range(1, jetty.size()):
		on.append(jetty[i])
		walked += Vector2(jetty[i].x - jetty[i - 1].x, jetty[i].z - jetty[i - 1].z).length()
		if walked > ON_JETTY + 10.0:
			break
	_append(route, on, false)
	# The route ends ON_JETTY m along the deck.
	var cut := PlaytestDriver._length(route) - walked + ON_JETTY
	var result := PackedVector3Array()
	var sum := 0.0
	result.append(route[0])
	for i in range(1, route.size()):
		var part_length := Vector2(route[i].x - route[i - 1].x, route[i].z - route[i - 1].z).length()
		if sum + part_length >= cut:
			result.append(PlaytestDriver.route_point(route, cut))
			break
		sum += part_length
		result.append(route[i])
	return result


## Along Hạ Long on its sea side: the way of the people of the showcase
## (Showcase.sea_walk: the walk on the sea wall, or the road where the walk has
## a gap at a junction), up to the point nearest to "until". The top of the walk
## goes to _walk_tops.
func _sea_wall_walk(w: VungTau, until: Vector3) -> PackedVector3Array:
	# The first points on the road: at the junction of Quang Trung the ground
	# falls away from the start of the walk, so the player steps onto the walk
	# from the road (a step of 0.19 m).
	var points: PackedVector3Array = w.showcase.sea_walk.duplicate()
	var road: PackedVector3Array = w.showcase.sea_road
	for i in mini(ROAD_FIRST, points.size()):
		points[i] = road[i]
	# The player goes onto the walk and off it from the road, over its side, 4 m
	# inside each piece: at an end of a piece the ground falls to the beach
	# (report 0026, D-0026-01).
	var flags: PackedByteArray = w.showcase.sea_walk_on
	for i in points.size():
		var inside := true
		for k in range(-WALK_MARGIN, WALK_MARGIN + 1):
			if i + k < 0 or i + k >= flags.size() or flags[i + k] == 0:
				inside = false
				break
		if not inside:
			points[i] = road[i]
	var on: PackedByteArray = w.showcase.sea_walk_on
	var walk := float(w.showcase.data.sea_walls[0].get("walk", 3.0))
	var walk_points: PackedVector3Array = w.showcase.sea_walk
	for i in walk_points.size() - 1:
		if on[i] == 0 or on[i + 1] == 0:
			continue
		var a := walk_points[i]
		var b := walk_points[i + 1]
		var across := Vector3(-(b.z - a.z), 0.0, b.x - a.x).normalized()
		for t in 5:
			var at := a.lerp(b, t / 4.0)
			for k in range(-4, 5):
				var q := at + across * (walk / 2.0 * k / 4.0)
				var cell := Vector2i(floori(q.x / WALK_CELL), floori(q.z / WALK_CELL))
				_walk_tops[cell] = maxf(float(_walk_tops.get(cell, -INF)), at.y)
	# The way of the people never turns back (report 0026, D-0026-01: where two
	# ways of Hạ Long met, it went 4 m back, and a slow computer turned round there).
	# The way ends at the point of the road nearest to "until" (the path of the
	# port of Cầu Đá), and the player leaves the walk over its side to the road
	# before it: from the walk, the line to the path goes over the parapet or
	# the closed end of the walk (PT-74 run 8 stopped there).
	var end := _nearest(road, until)
	for i in range(maxi(0, end - WALK_MARGIN), end + 1):
		points[i] = road[i]
	var way := points.slice(0, end + 1)
	for i in range(1, way.size() - 1):
		var a := Vector2(way[i].x - way[i - 1].x, way[i].z - way[i - 1].z)
		var b := Vector2(way[i + 1].x - way[i].x, way[i + 1].z - way[i].z)
		if a.length() > 0.01 and b.length() > 0.01 and a.dot(b) < 0.0:
			_backs.append(Vector2(way[i].x, way[i].z))
	return way


## The points of an OSM way of the roads (x, y, z), or none.
func _way(w: VungTau, id: int) -> PackedVector3Array:
	var line := PackedVector3Array()
	for road: Dictionary in w.data.roads:
		if int(road.id) == id:
			for p: Array in road.points:
				line.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
			break
	return line


## Adds a line to the route, in the direction that starts nearer to the end of the route.
func _append(route: PackedVector3Array, line: PackedVector3Array, either_way: bool) -> void:
	if line.is_empty():
		return
	var points := line.duplicate()
	if either_way and route.size() > 0:
		var last := route[route.size() - 1]
		if last.distance_to(points[points.size() - 1]) < last.distance_to(points[0]):
			points.reverse()
	route.append_array(points)


func _nearest(line: PackedVector3Array, point: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in line.size():
		var gap := Vector2(line[i].x - point.x, line[i].z - point.z).length()
		if gap < best_d:
			best_d = gap
			best = i
	return best


## The middle of Hải Âu at the ground: its model (khach_san_hai_au, report
## 0026, D-0026-09), or its stand-in, or INF.
func _hai_au(w: VungTau) -> Vector3:
	for entry: Dictionary in w.showcase.models:
		if str(entry.id) == HAI_AU_MODEL:
			var middle := Vector2.ZERO
			for p: Vector2 in entry.footprint:
				middle += p
			middle /= maxf(entry.footprint.size(), 1.0)
			return Vector3(middle.x, float(entry.base), middle.y)
	for entry: Dictionary in w.showcase.stand_ins:
		if str(entry.osm) == HAI_AU:
			return entry.center
	return Vector3.INF


## Report 0026, D-0026-04: the walk on the sea wall of Hạ Long had its tiles on
## the axes of the world (a jagged edge, steps in the pattern) and a strip of
## bare ground between the curb of the road and the walk.
func _check_walk_surface(d: PlaytestDriver, w: VungTau) -> void:
	var lengths: Dictionary = w.showcase.lengths
	var along := float(lengths.get("sea_walk_along", 0.0))
	var all := float(lengths.get("sea_wall", 0.0))
	d.expect(all > 100.0 and absf(along - all) < 1.0,
			"the tiles of the walk on the sea wall follow its line: %.0f m of %.0f m" % [along, all])
	var walk: PackedVector3Array = w.showcase.sea_walk
	var road: PackedVector3Array = w.showcase.sea_road
	var on: PackedByteArray = w.showcase.sea_walk_on
	var grade := {"value": 0.0, "at": Vector3.ZERO}
	var bend := {"value": 0.0, "at": Vector3.ZERO}
	for i in range(1, walk.size() - 1):
		if on[i - 1] == 0 or on[i] == 0 or on[i + 1] == 0:
			continue
		var g0 := (walk[i].y - walk[i - 1].y) / maxf(Vector2(walk[i].x - walk[i - 1].x, walk[i].z - walk[i - 1].z).length(), 0.1)
		var g1 := (walk[i + 1].y - walk[i].y) / maxf(Vector2(walk[i + 1].x - walk[i].x, walk[i + 1].z - walk[i].z).length(), 0.1)
		if absf(g1) > grade.value:
			grade = {"value": absf(g1), "at": walk[i]}
		if absf(g1 - g0) > bend.value:
			bend = {"value": absf(g1 - g0), "at": walk[i]}
	# The curb: the top of the walk over the ground at the edge of the road.
	var curb := {"value": 0.0, "at": Vector3.ZERO}
	for i in walk.size():
		var edge := road[i] + Vector3(walk[i].x - road[i].x, 0.0, walk[i].z - road[i].z).normalized() * (Showcase.ROAD_INSIDE - 0.1)
		if on[i] == 1 and walk[i].y - w.ground_height(edge.x, edge.z) > curb.value:
			curb = {"value": walk[i].y - w.ground_height(edge.x, edge.z), "at": walk[i]}
	d.step("the walk on the sea wall: the steepest grade %.3f at (%.0f, %.0f), the largest change of grade %.3f at (%.0f, %.0f), the highest curb %.2f m at (%.0f, %.0f)" % [
			grade.value, grade.at.x, grade.at.z, bend.value, bend.at.x, bend.at.z, curb.value, curb.at.x, curb.at.z])
	d.expect(curb.value <= MAX_WALK_CURB, "the walk on the sea wall is at most %.2f m over the road at the curb: %.2f m" % [MAX_WALK_CURB, curb.value])
	d.expect(grade.value <= MAX_WALK_GRADE, "the walk on the sea wall is not steeper than %.2f: %.3f" % [MAX_WALK_GRADE, grade.value])
	d.expect(bend.value <= MAX_WALK_BEND, "the grade of the walk on the sea wall changes by at most %.2f from piece to piece: %.3f at (%.0f, %.0f)" % [
			MAX_WALK_BEND, bend.value, bend.at.x, bend.at.z])
	# From the curb of the road to the middle of the walk, a ray down hits the walk.
	var space := w.get_world_3d().direct_space_state
	var tested := 0
	var misses: Array[String] = []
	for i in range(0, walk.size(), 3):
		if i < 2 or i >= walk.size() - 2 or on[i - 2] == 0 or on[i] == 0 or on[i + 2] == 0:
			continue
		var side := Vector3(walk[i].x - road[i].x, 0.0, walk[i].z - road[i].z)
		var reach := side.length()
		side = side.normalized()
		# The curb is ROAD_INSIDE m from the point of the road.
		for k: float in [0.3, 1.0, 2.0]:
			if Showcase.ROAD_INSIDE + k >= reach:
				continue
			var at := road[i] + side * (Showcase.ROAD_INSIDE + k)
			var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, walk[i].y + 3.0, at.z), Vector3(at.x, walk[i].y - 3.0, at.z))
			var hit := space.intersect_ray(query)
			tested += 1
			if hit.is_empty() or not (hit.collider is Node) or (hit.collider as Node).name != "ShowcaseBody":
				misses.append("(%.0f, %.0f)" % [at.x, at.z])
	d.step("the walk on the sea wall from the curb: %d rays, %d miss the walk" % [tested, misses.size()])
	d.expect(tested > 50 and misses.is_empty(), "the walk on the sea wall goes from the curb of the road: %s" % ", ".join(misses.slice(0, 10)))


## Report 0026, D-0026-30 (audit 6): between the two roads of a divided road
## (the median of Quang Trung) the ground does not show. In the area of the
## showcase, points across the space between the edges of the two roads, each
## DIVIDED_STEP m along the first road, are each under a face of a road mesh
## or of a part of the showcase (the median, its curbs, the asphalt where the
## median ends). At the junction of Quang Trung with Hạ Long, the brown earth
## showed between the road meshes (PT-74 run 5 at 700 m).
const DIVIDED_STEP := 1.0
func _check_divided_road(d: PlaytestDriver, w: VungTau) -> void:
	var ways: Array = w.showcase.data.get("median", {}).get("ways", [])
	if not d.expect(ways.size() == 2, "the showcase has the median of Quang Trung"):
		return
	var a: Dictionary = w.showcase._roads[int(ways[0])]
	var b: Dictionary = w.showcase._roads[int(ways[1])]
	var line_a: PackedVector3Array = w.showcase._dense(w.showcase._line(a), DIVIDED_STEP)
	var line_b: PackedVector3Array = w.showcase._line(b)
	var points := PackedVector2Array()
	for p: Vector3 in line_a:
		var q: Vector3 = w.showcase._nearest(line_b, p)
		var across := Vector2(q.x - p.x, q.z - p.z)
		var gap := across.length() - float(a.width) / 2.0 - float(b.width) / 2.0
		if gap <= 0.1 or gap > 12.0 or not w.showcase.contains((p.x + q.x) / 2.0, (p.z + q.z) / 2.0):
			continue
		var dir := across.normalized()
		var from := Vector2(p.x, p.z) + dir * (float(a.width) / 2.0 + 0.05)
		for k in 5:
			points.append(from + dir * (gap - 0.1) * k / 4.0)
	var faces := _top_faces(w, points)
	var bare := PackedVector2Array()
	for point in points:
		if not _covered(faces, point):
			bare.append(point)
	var listed := PackedStringArray()
	for i in mini(bare.size(), 6):
		listed.append("(%.1f, %.1f)" % [bare[i].x, bare[i].y])
	d.step("the space between the two roads of Quang Trung: %d points, %d with no road and no part over them%s" % [
			points.size(), bare.size(), "" if bare.is_empty() else ": " + ", ".join(listed)])
	d.expect(points.size() > 50 and bare.is_empty(), "the ground does not show between the two roads of Quang Trung: %d of %d points are bare ground" % [
			bare.size(), points.size()])
	_check_junction_sidewalks(d, w, Vector2(80.0, 204.0))


## Report 0026, D-0026-30 (audit 6): in a junction, a sidewalk does not go
## across the carriageway of another road (brown strips across the junction of
## Quang Trung with Hạ Long). The points of the carriageway (the road minus its
## sidewalks) of each road within JUNCTION_M of the point, each 1 m along and
## across it, are not under a face of a sidewalk.
const JUNCTION_M := 30.0
func _check_junction_sidewalks(d: PlaytestDriver, w: VungTau, at: Vector2) -> void:
	var points := PackedVector2Array()
	for road: Dictionary in w.showcase._roads.values():
		var half := float(road.width) / 2.0
		if str(road.get("sidewalk", "")) != "" and float(road.width) >= RoadBuilder.MIN_SIDEWALK_ROAD:
			half -= RoadBuilder.SIDEWALK_WIDTH
		var line: PackedVector3Array = w.showcase._dense(w.showcase._line(road), 1.0)
		for i in line.size() - 1:
			var p := Vector2(line[i].x, line[i].z)
			if p.distance_to(at) > JUNCTION_M:
				continue
			var along := Vector2(line[i + 1].x - p.x, line[i + 1].z - p.y).normalized()
			var across := Vector2(-along.y, along.x)
			var k := -half + 0.3
			while k <= half - 0.3:
				points.append(p + across * k)
				k += 1.0
	var faces := {}
	for node in w.find_children("Road_sidewalk", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var t := mesh_node.global_transform
		var tri := mesh_node.mesh.get_faces()
		for i in range(0, tri.size(), 3):
			var p0 := t * tri[i]
			var p1 := t * tri[i + 1]
			var p2 := t * tri[i + 2]
			if absf((p1 - p0).cross(p2 - p0).normalized().y) < 0.5:
				continue
			var f := [Vector2(p0.x, p0.z), Vector2(p1.x, p1.z), Vector2(p2.x, p2.z)]
			if f[0].distance_to(at) > JUNCTION_M + 20.0:
				continue
			var r := Rect2(f[0], Vector2.ZERO).expand(f[1]).expand(f[2])
			for cx in range(floori(r.position.x / 4.0), floori(r.end.x / 4.0) + 1):
				for cz in range(floori(r.position.y / 4.0), floori(r.end.y / 4.0) + 1):
					faces.get_or_add(Vector2i(cx, cz), []).append(f)
	var under := PackedVector2Array()
	for point in points:
		if _covered(faces, point):
			under.append(point)
	var listed := PackedStringArray()
	for i in mini(under.size(), 6):
		listed.append("(%.1f, %.1f)" % [under[i].x, under[i].y])
	d.step("the junction at (%.0f, %.0f): %d points of the carriageways, %d under a sidewalk%s" % [
			at.x, at.y, points.size(), under.size(), "" if under.is_empty() else ": " + ", ".join(listed)])
	d.expect(points.size() > 100 and under.is_empty(), "no sidewalk goes across a carriageway in the junction at (%.0f, %.0f): %d of %d points" % [
			at.x, at.y, under.size(), points.size()])


## The faces that look up of the road meshes and of the parts of the showcase
## near the points, in cells of 4 m: {cell: [[a, b, c] in x, z]}.
static func _top_faces(w: VungTau, points: PackedVector2Array) -> Dictionary:
	var box := Rect2(points[0], Vector2.ZERO) if not points.is_empty() else Rect2()
	for point in points:
		box = box.expand(point)
	box = box.grow(2.0)
	var nodes: Array[Node] = w.showcase.find_children("*", "MeshInstance3D", true, false)
	for node in w.find_children("Road_*", "MeshInstance3D", true, false):
		if node.name != "Road_lines":
			nodes.append(node)
	var cells := {}
	for node in nodes:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null or not mesh_node.is_visible_in_tree():
			continue
		var t := mesh_node.global_transform
		var aabb := t * mesh_node.get_aabb()
		if not box.intersects(Rect2(aabb.position.x, aabb.position.z, aabb.size.x, aabb.size.z)):
			continue
		var tri := mesh_node.mesh.get_faces()
		for i in range(0, tri.size(), 3):
			var p0 := t * tri[i]
			var p1 := t * tri[i + 1]
			var p2 := t * tri[i + 2]
			if absf((p1 - p0).cross(p2 - p0).normalized().y) < 0.5:
				continue
			var f := [Vector2(p0.x, p0.z), Vector2(p1.x, p1.z), Vector2(p2.x, p2.z)]
			var r := Rect2(f[0], Vector2.ZERO).expand(f[1]).expand(f[2])
			if not box.intersects(r):
				continue
			for cx in range(floori(r.position.x / 4.0), floori(r.end.x / 4.0) + 1):
				for cz in range(floori(r.position.y / 4.0), floori(r.end.y / 4.0) + 1):
					cells.get_or_add(Vector2i(cx, cz), []).append(f)
	return cells


static func _covered(cells: Dictionary, point: Vector2) -> bool:
	for f: Array in cells.get(Vector2i(floori(point.x / 4.0), floori(point.y / 4.0)), []):
		if Geometry2D.point_is_inside_triangle(point, f[0], f[1], f[2]):
			return true
	return false


## Report 0026, D-0026-30 (audit 6): the paving of the square at the south end
## of the park does not look like the sand of the beach next to it at 17:00
## (PT-74 run 4, at 550 m: it was orange, saturation 0.42 against 0.37 of the
## sand; the slabs of the photo have 0.16). The drone photo of 2021 shows the
## square in pale cream slabs. From
## above the square, the mean color of the points of the paving (the ground
## mask of the showcase in the outline of the square, over the water) and of
## the points of dry sand near it (the surface mask of the world) in the frame:
## the paving is less saturated than the sand by PAVING_GREYER at least, its
## saturation is within PAVING_PHOTO of the clean slabs of the photo (the
## pixels in the outline of the square on the photo with a value over 0.55),
## and it is not darker than the sand by more than PAVING_DARKER.
const PAVING_GREYER := 0.03
const PAVING_PHOTO := 0.1
const PAVING_DARKER := 0.05
func _check_south_paving(d: PlaytestDriver, w: VungTau) -> void:
	var square: Dictionary = {}
	for item: Dictionary in w.showcase.data.get("ground", {}).get("drawn", []):
		if str(item.get("id", "")) == "south_end_square":
			square = item
	if not d.expect(not square.is_empty(), "the showcase has the square of the south end"):
		return
	var outline := PackedVector2Array()
	for q: Array in square.outline:
		outline.append(Vector2(float(q[0]), float(q[1])))
	var box := Rect2(outline[0], Vector2.ZERO)
	for q in outline:
		box = box.expand(q)
	var middle := box.get_center()
	var ground_y := w.ground_height(middle.x, middle.y)
	var eye := Vector3(middle.x + 14.0, ground_y + 30.0, middle.y)
	await d.fly_to(eye, Vector3(middle.x - 10.0, ground_y, middle.y))
	await d.wait_ground(60.0)
	d.main().ui_root.visible = false
	await d.wait_frames(8)
	var camera := d.viewport().get_camera_3d()
	var frame := d.viewport().get_texture().get_image()
	var rect := Rect2(Vector2.ZERO, Vector2(frame.get_size()))
	var sums := {"paving": [Color(0, 0, 0), 0], "sand": [Color(0, 0, 0), 0]}
	var x := box.position.x - 60.0
	while x <= box.end.x + 20.0:
		var z := box.position.y - 30.0
		while z <= box.end.y + 30.0:
			var kind := ""
			var g := w.showcase.ground_at(x, z)
			var h := w.ground_height(x, z)
			if g.g > 0.5 and Geometry2D.is_point_in_polygon(Vector2(x, z), outline) and h > w.sea_level + 0.2:
				kind = "paving"
			elif w.surface_at(x, z).r > 0.5 and g.r < 0.3 and g.g < 0.3 and g.b < 0.3 and h > w.sea_level + 0.2:
				kind = "sand"
			if kind != "":
				var p := Vector3(x, h, z)
				if not camera.is_position_behind(p):
					var px := camera.unproject_position(p)
					if rect.grow(-4.0).has_point(px):
						var hit := d.viewport().world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position, p + Vector3(0, 0.3, 0)))
						if hit.is_empty() or (hit.position as Vector3).distance_to(p) < 1.0:
							var c := frame.get_pixelv(Vector2i(px))
							sums[kind][0] += c
							sums[kind][1] += 1
			z += 1.5
		x += 1.5
	await d.screenshot("south_end_square_paving")
	d.main().ui_root.visible = true
	d.fly_end()
	if not d.expect(int(sums.paving[1]) > 30 and int(sums.sand[1]) > 10, "the frame shows the paving of the square (%d points) and the sand (%d points)" % [
			sums.paving[1], sums.sand[1]]):
		return
	var paving: Color = sums.paving[0] / float(sums.paving[1])
	var sand: Color = sums.sand[0] / float(sums.sand[1])
	var photo := _photo_slabs(square)
	d.step("the square of the south end at 17:00: the paving #%s (saturation %.2f, value %.2f), the sand #%s (saturation %.2f, value %.2f); the slabs of the photo #%s (saturation %.2f)" % [
			paving.to_html(false), paving.s, paving.v, sand.to_html(false), sand.s, sand.v, photo.to_html(false), photo.s])
	d.expect(sand.s - paving.s >= PAVING_GREYER and absf(paving.s - photo.s) <= PAVING_PHOTO and sand.v - paving.v <= PAVING_DARKER,
			"the paving of the square is pale slabs, not sand: %.2f less saturated than the sand (at least %.2f), %.2f from the saturation of the slabs of the photo (at most %.2f), %.2f darker than the sand (at most %.2f)" % [
				sand.s - paving.s, PAVING_GREYER, absf(paving.s - photo.s), PAVING_PHOTO, sand.v - paving.v, PAVING_DARKER])


## The mean color of the clean slabs of the square on its photo: the pixels in
## the outline of the square on the photo (photo_points) with a value over 0.55.
static func _photo_slabs(square: Dictionary) -> Color:
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://docs/reference/photos/" + str(square.photo)))
	if image == null:
		return Color(0, 0, 0)
	var polygon := PackedVector2Array()
	for q: Array in square.photo_points:
		polygon.append(Vector2(float(q[0]), float(q[1])))
	var box := Rect2(polygon[0], Vector2.ZERO)
	for q in polygon:
		box = box.expand(q)
	var total := Color(0, 0, 0)
	var count := 0
	for y in range(int(box.position.y), int(box.end.y), 2):
		for x in range(int(box.position.x), int(box.end.x), 2):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), polygon):
				var c := image.get_pixel(x, y)
				if c.v > 0.55:
					total += c
					count += 1
	return total / float(maxi(count, 1))


## Report 0026, D-0026-30 (audit 6): the square of the south end has its
## parapet over the water (the drone photo of 2021: a low wall with a light top
## along its sea edge). Every PARAPET_STEP m along the sea edge of the square
## (the side of its outline with the sea next to it), a ray 0.15 m or 0.72 m
## over the paving (the base and the rail of a balustrade) from 3 m inside the
## edge out to the sea meets a wall within PARAPET_OUT m past the edge.
const PARAPET_STEP := 3.0
const PARAPET_OUT := 1.5
func _check_square_parapet(d: PlaytestDriver, w: VungTau) -> void:
	var outline: Array = []
	for item: Dictionary in w.showcase.data.get("ground", {}).get("drawn", []):
		if str(item.get("id", "")) == "south_end_square":
			outline = item.outline
	var space := d.viewport().world_3d.direct_space_state
	var rays := 0
	var open := PackedStringArray()
	for i in outline.size():
		var a := Vector2(float(outline[i][0]), float(outline[i][1]))
		var b := Vector2(float(outline[(i + 1) % outline.size()][0]), float(outline[(i + 1) % outline.size()][1]))
		var along := (b - a).normalized()
		# The outside of the side: the outline goes round; the side whose outside is over the sea.
		for out: Vector2 in [Vector2(along.y, -along.x), Vector2(-along.y, along.x)]:
			var probe := (a + b) / 2.0 + out * 3.0
			if w.ground_height(probe.x, probe.y) > w.sea_level - 0.3:
				continue
			var t := 1.0
			while t < a.distance_to(b) - 1.0:
				var at := a + along * t
				var inside := at - out * 1.0
				var ground := w.ground_height(inside.x, inside.y)
				rays += 1
				# At the base of the wall and at its rail (a balustrade has gaps between).
				var hit := false
				for over: float in [0.15, 0.72]:
					var from := Vector3(at.x - out.x * 3.0, ground + over, at.y - out.y * 3.0)
					var to := Vector3(at.x + out.x * PARAPET_OUT, ground + over, at.y + out.y * PARAPET_OUT)
					if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to)).is_empty():
						hit = true
				if not hit:
					open.append("(%.0f, %.0f)" % [at.x, at.y])
				t += PARAPET_STEP
	d.step("the parapet of the square of the south end: %d rays along its sea edge, %d with no wall%s" % [
			rays, open.size(), "" if open.is_empty() else ": " + ", ".join(open.slice(0, 8))])
	d.expect(rays >= 10 and open.is_empty(), "the square of the south end has its parapet over the water: %d of %d places have no wall" % [
			open.size(), rays])
