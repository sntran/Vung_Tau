extends RefCounted
# PT-74 showcase_walk (plan 0026, section 8). With the joystick, walk at 17:00
# from the north end of the park along the walk of the sea, the paths of the
# park, and the walk on the sea wall of Hạ Long to the port of Cầu Đá in front
# of Hải Âu, and 60 m onto the jetty. The player does not fall, does not walk
# through a wall or a person, and stays on the ground (or on the deck of the
# jetty). A screenshot every 50 m, and one of Hải Âu from the path. The walk of
# about 1.2 km is in six runs. The game runs six times faster and does up to 48
# physics steps in one frame (a setup of the run, as the time scale of PT-34):
# the player walks at the same speed in game time, and the checks run at each
# physics step.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=17:00 --quality=low

const RUNS := 6
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
## The walk on the deck of the jetty (m).
const ON_JETTY := 60.0
## Higher than this over the ground (m), the player stands on a part, not on the ground.
const MAX_OVER := 0.4
## Lower than this under the ground or the deck (m), the player falls.
const MAX_UNDER := 0.3
## The cells (m) of the tops of the walk on the sea wall.
const WALK_CELL := 1.0
## The first points of the way along Hạ Long on the road (every 2 m).
const ROAD_FIRST := 12

## The top of the walk on the sea wall in each cell (Vector2i), the floor of the
## player there (not the ground under it).
var _walk_tops: Dictionary = {}


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.showcase != null and w.places != null and not w.places.jetty.is_empty(),
			"the Vũng Tàu world has the showcase and the jetty of Cầu Đá"):
		return
	var route := _route(w)
	var length := PlaytestDriver._length(route)
	if not d.expect(length > 900.0, "the route is %.0f m long" % length):
		return
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
	var stats := {"under": 0.0, "under_at": Vector3.ZERO, "over": 0.0, "over_at": Vector3.ZERO, "overlaps": 0, "overlap_names": {},
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
		var cell := Vector2i(floori(p.x / WALK_CELL), floori(p.z / WALK_CELL))
		if _walk_tops.has(cell):
			top = maxf(top, float(_walk_tops[cell]))
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
		if not await d.stick_along(route, goal, Callable(), 30.0, false, 25.0):
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
	d.expect(stats.overlaps == 0, "run %d: the player is never inside a wall, a part, or a person: %s" % [
			d.phase, ", ".join(stats.overlap_names.keys())])
	d.expect(stats.near_person >= Player.RADIUS + ShowcasePeople.BODY_RADIUS - 0.1,
			"run %d: the player does not walk through a person (the nearest at %.2f m)" % [d.phase, stats.near_person])
	if d.phase == RUNS:
		var deck := float(w.places.jetty.deck)
		d.expect(at >= jetty_start + ON_JETTY - 3.0, "the player walks %.0f m onto the jetty" % ON_JETTY)
		d.expect(w.places.floor_at(p.x, p.z) > -INF and absf(p.y - deck) < 0.3,
				"the player stands on the deck of the jetty (%.2f m, the deck %.2f m)" % [p.y, deck])
	d.expect(hai_au != Vector3.INF, "the showcase has Hải Âu (%s)" % HAI_AU)


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
	var behind := jetty[0] + out * 5.0
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
	return points.slice(0, _nearest(points, until) + 1)


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


## The middle of the stand-in of Hải Âu (its top), or INF.
func _hai_au(w: VungTau) -> Vector3:
	for entry: Dictionary in w.showcase.stand_ins:
		if str(entry.osm) == HAI_AU:
			return entry.center
	return Vector3.INF
