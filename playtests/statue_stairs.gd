extends RefCounted
# PT-61 statue_stairs (plan 0008, R6, R7). With tap to walk only, go from the
# road at the foot of Núi Nhỏ to the plaza of the statue: the route of OSM
# ("route" of the place: footways and the stairs). Each run walks a part of
# the route (a run under lavapipe must be shorter than 180 s). Checks: the
# player stays on the route (on the stairs, the steps of 15 cm to 18 cm, R6);
# each run reaches the end of its part; the last run reaches the plaza, and
# the player cannot pass the parapet round it (R6: a push of 4 s with the
# joystick out to the edge). Screenshots at the bottom, in the middle, and at
# the top.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=08:00
# phase: --world=vung_tau --start-time=08:00
# phase: --world=vung_tau --start-time=08:00
# phase: --world=vung_tau --start-time=08:00
# phase: --world=vung_tau --start-time=08:00
# phase: --world=vung_tau --start-time=08:00
# phase: --world=vung_tau --start-time=08:00
# phase: --world=vung_tau --start-time=08:00
# phase: --world=vung_tau --start-time=08:00

const PARTS := 8
const TAP_M := 7.0
const OFF_ROUTE_M := 2.0


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.places != null and w.places.places.has("chua_kito_vua"), "the statue is a place"):
		return
	var entry: Dictionary = w.places.places.chua_kito_vua
	var route := route_line(w, entry.place.get("route", []))
	if not d.expect(route.size() >= 2, "the route from the road has points"):
		return
	# The walk ends on the plaza: the route ends at its first point 1.5 m inside
	# the plaza (the ways round the statue come after it).
	route = _to_plaza(route, entry)
	var total := PlaytestDriver._length(route)
	d.step("the route from the road to the plaza: %.0f m, %d stairs, %d steps" % [total, w.places.stairs.size(),
			w.places.stairs.reduce(func(n: int, s: Dictionary) -> int: return n + int(s.steps), 0)])
	for s: Dictionary in w.places.stairs:
		if s.place == "chua_kito_vua":
			var line: PackedVector3Array = s.points
			for i in range(1, line.size()):
				var rise := absf(line[i].y - line[i - 1].y)
				if rise > 0.001 and (rise < KnownPlaces.STEP_MIN - 0.005 or rise > KnownPlaces.STEP_MAX + 0.005):
					d.fail("the stairs %d have a step of %.3f m" % [s.way, rise])
					break
	if d.phase <= PARTS:
		var from := total * (d.phase - 1) / PARTS
		var to := total * d.phase / PARTS
		await _walk(d, w, route, from, to)
	else:
		await _plaza(d, w, entry, route, total)


## The route up to its first point 1.5 m inside the plaza.
static func _to_plaza(route: PackedVector3Array, entry: Dictionary) -> PackedVector3Array:
	var c: Vector3 = entry.get("center", Vector3.ZERO)
	var inside := float(entry.get("plaza", 15.0)) - 1.5
	var result := PackedVector3Array()
	for i in route.size():
		var r := Vector2(route[i].x - c.x, route[i].z - c.z).length()
		if r <= inside and i > 0:
			# The point on the line from the last point where it comes to "inside".
			var a := route[i - 1]
			var lo := 0.0
			var hi := 1.0
			for step in 24:
				var t := (lo + hi) / 2.0
				var q := a.lerp(route[i], t)
				if Vector2(q.x - c.x, q.z - c.z).length() > inside:
					lo = t
				else:
					hi = t
			result.append(a.lerp(route[i], hi))
			break
		result.append(route[i])
		if r <= inside:
			break
	return result


## The route: the OSM ways in their order from the road, joined end to end.
static func route_line(w: VungTau, ids: Array) -> PackedVector3Array:
	var by_id := {}
	for road: Dictionary in w.data.roads:
		by_id[int(road.id)] = road
	var result := PackedVector3Array()
	for i in ids.size():
		var road: Dictionary = by_id.get(int(ids[i]), {})
		if road.is_empty():
			continue
		var points := PackedVector3Array()
		for p: Array in road.points:
			points.append(Vector3(p[0], w.ground_height(p[0], p[2]), p[2]))
		if result.is_empty():
			# The first way goes to the next one.
			if i + 1 < ids.size() and by_id.has(int(ids[i + 1])):
				var nxt: Array = by_id[int(ids[i + 1])].points
				var ends := [Vector2(nxt[0][0], nxt[0][2]), Vector2(nxt[-1][0], nxt[-1][2])]
				var d0 := minf(Vector2(points[0].x, points[0].z).distance_to(ends[0]), Vector2(points[0].x, points[0].z).distance_to(ends[1]))
				var d1 := minf(Vector2(points[-1].x, points[-1].z).distance_to(ends[0]), Vector2(points[-1].x, points[-1].z).distance_to(ends[1]))
				if d0 < d1:
					points.reverse()
		else:
			var last := Vector2(result[-1].x, result[-1].z)
			if Vector2(points[-1].x, points[-1].z).distance_to(last) < Vector2(points[0].x, points[0].z).distance_to(last):
				points.reverse()
		result.append_array(points)
	return result


static func _walk(d: PlaytestDriver, w: VungTau, route: PackedVector3Array, from: float, to: float) -> void:
	var start := PlaytestDriver.route_point(route, from)
	var ahead := PlaytestDriver.route_point(route, minf(from + 3.0, to))
	await d.start_at(start, rad_to_deg(atan2(-(ahead.x - start.x), -(ahead.z - start.z))))
	await d.wait_frames(10)
	await d.screenshot("part_%d_start" % d.phase)
	var farthest := {"off": 0.0}
	var check := func() -> void:
		var p: Vector3 = d.state().player
		var off := _off_route(route, p)
		farthest.off = maxf(farthest.off, off)
	d.main().get_tree().process_frame.connect(check)
	var at := from
	var tries := 0
	while at < to - 1.0 and tries < 120:
		tries += 1
		# A player taps along the stairs: at a turn, a nearer point, so that the
		# straight walk to it stays within 0.5 m of the route.
		var reach := TAP_M
		while reach > 2.0 and _cuts_corner(route, d.state().player, at, minf(at + reach, to)):
			reach *= 0.7
		var target := PlaytestDriver.route_point(route, minf(at + reach, to))
		target.y = _floor_y(w, target)
		await d.look_at_point(target, 3.0, 15.0)
		if await d.try_tap_floor(target) != "":
			# The point is not on the screen (a step or a wall in front): a nearer one.
			target = PlaytestDriver.route_point(route, minf(at + TAP_M * 0.5, to))
			target.y = _floor_y(w, target)
			await d.look_at_point(target, 3.0, 15.0)
			var error := await d.try_tap_floor(target)
			if error != "":
				d.step("part %d: no tap at %.0f m: %s" % [d.phase, at, error])
				break
		await d.wait_idle(30.0)
		var now := _distance_near(route, d.state().player, at)
		if now <= at + 0.2:
			# A player taps again when a tap does not move them: once, at a nearer
			# point. A real block stops this tap too.
			var again := PlaytestDriver.route_point(route, minf(at + 2.5, to))
			again.y = _floor_y(w, again)
			await d.look_at_point(again, 3.0, 15.0)
			if await d.try_tap_floor(again) == "":
				await d.wait_idle(30.0)
				now = _distance_near(route, d.state().player, at)
				if now > at + 0.2:
					d.step("part %d: a second tap at %.0f m moves the player" % [d.phase, at])
		if now <= at + 0.2:
			var p: Vector3 = d.state().player
			var screen := d.viewport().get_camera_3d().unproject_position(target)
			var hit: Dictionary = d.main().pick(screen)
			var node: Node = hit.get("node")
			d.step("part %d: a tap at %s does not move the player from %.0f m (%s); the tap hits %s at %s" % [
					d.phase, target, at, p, node.get_path() if node else "nothing", hit.get("position")])
			break
		at = now
	d.main().get_tree().process_frame.disconnect(check)
	await d.screenshot("part_%d_end" % d.phase)
	d.step("part %d: from %.0f m to %.0f m of the route, the player came to %.0f m; at most %.1f m from the route" % [
			d.phase, from, to, at, farthest.off])
	d.expect(at >= to - 2.0, "part %d: the player comes to %.0f m of the route (%.0f m)" % [d.phase, to, at])
	d.expect(farthest.off <= OFF_ROUTE_M, "part %d: the player stays on the route (%.1f m from it at most)" % [d.phase, farthest.off])


## True when the straight walk from "from" to the route point at "to" leaves
## the route between "at" and "to" by more than 0.5 m.
static func _cuts_corner(route: PackedVector3Array, from: Vector3, at: float, to: float) -> bool:
	var a := Vector2(from.x, from.z)
	var end := PlaytestDriver.route_point(route, to)
	var b := Vector2(end.x, end.z)
	var k := at
	while k < to:
		var q := PlaytestDriver.route_point(route, k)
		if Geometry2D.get_closest_point_to_segment(Vector2(q.x, q.z), a, b).distance_to(Vector2(q.x, q.z)) > 0.5:
			return true
		k += 0.5
	return false


## A point 3 cm under the floor at the point (the first surface under it):
## the ray of the tap hits the floor just before it. A ray to a point over the
## floor passes over it at a small angle, and where the floor goes down after
## the point (the slope beside the stairs at a turn), it hits the floor farther away.
static func _floor_y(w: VungTau, p: Vector3) -> float:
	var top := maxf(w.ground_height(p.x, p.z), w.places.floor_at(p.x, p.z)) + 5.0
	var hit := w.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(Vector3(p.x, top, p.z), Vector3(p.x, top - 20.0, p.z)))
	return float((hit.position as Vector3).y) - 0.03 if not hit.is_empty() else w.ground_height(p.x, p.z)


## The distance along the route of the point of the route nearest to "p",
## from 2 m back to 20 m ahead of "at". At a U-turn, the nearest point of the
## whole route can be on the other leg.
static func _distance_near(route: PackedVector3Array, p: Vector3, at: float) -> float:
	var best := at
	var best_gap := INF
	var k := maxf(at - 2.0, 0.0)
	var end := minf(at + 20.0, PlaytestDriver._length(route))
	while k <= end:
		var q := PlaytestDriver.route_point(route, k)
		var gap := Vector2(q.x - p.x, q.z - p.z).length()
		if gap < best_gap:
			best_gap = gap
			best = k
		k += 0.1
	return best


static func _off_route(route: PackedVector3Array, p: Vector3) -> float:
	var best := INF
	for i in route.size() - 1:
		var a := Vector2(route[i].x, route[i].z)
		var b := Vector2(route[i + 1].x, route[i + 1].z)
		best = minf(best, Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), a, b).distance_to(Vector2(p.x, p.z)))
	return best


## The last run: on the plaza, a push to the edge with the joystick.
static func _plaza(d: PlaytestDriver, w: VungTau, entry: Dictionary, route: PackedVector3Array, total: float) -> void:
	var c: Vector3 = entry.center
	var plaza := float(entry.plaza)
	var top := PlaytestDriver.route_point(route, total - 1.0)
	await d.start_at(top, 0.0)
	await d.wait_frames(10)
	var p: Vector3 = d.state().player
	d.expect(Vector2(p.x - c.x, p.z - c.z).length() <= plaza + 1.0, "the end of the route is on the plaza")
	await d.look_at_point(c + Vector3(0, 20.0, 0), 4.0, 15.0)
	await d.screenshot("top_statue")
	# Out to the parapet: away from the statue.
	var out := Vector3(p.x - c.x, 0.0, p.z - c.z).normalized()
	await d.look_at_point(p + out * 10.0 + Vector3(0, Player.EYE_HEIGHT, 0), 6.0, 15.0)
	await d.hold_stick(Vector2(0, -1), 4.0)
	p = d.state().player
	var r := Vector2(p.x - c.x, p.z - c.z).length()
	await d.screenshot("top_parapet")
	d.step("after the push, the player is %.1f m from the middle (the parapet is at %.1f m)" % [r, plaza])
	d.expect(r < plaza, "the player cannot pass the parapet (%.1f m from the middle, the parapet at %.1f m)" % [r, plaza])
	d.expect(p.y > float(entry.base) - 0.5, "the player stays on the plaza (%.1f m, the base at %.1f m)" % [p.y, entry.base])
