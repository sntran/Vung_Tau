extends RefCounted
# PT-79 street_houses (plan 0009, phase 3, R7 to R9). The houses of World on
# the first street of data/geo/streets.json (Trương Công Định, from Quang
# Trung at Cảng vụ toward chợ Xóm Lưới): the tube houses of World on the lots
# of the boxes of the town (status Source) and of the free fronts (report
# 0009, Q12: status Check). One run for each side of the street, on Low at
# 12:00. The player walks on the sidewalk with the joystick (real input). The
# checks: each house of the file is built; the player is never in a lot (the
# houses are solid: report 0009, section 8.6); a walk into a front stops at the
# front; the frame is not one flat color; the budget of PT-69 holds (Low: at
# most 600 draw calls and 300 000 triangles). Screenshots along the street
# and at the fronts, at the places of the street photos of Mapillary.
# The right side is in two runs: each run is shorter than 180 s of game time.
# phase: --world=vung_tau --start-time=12:00 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=low --renderer=forward_plus

## Each run: the side, the places of its screenshots (m from the start of the
## side), and the walk into a front at its end.
const RUNS := [["left", [0.0, 50.0, 100.0], true], ["right", [0.0, 50.0, 100.0], false],
		["right", [150.0, 200.0], true]]
## The sidewalk: this far from the fronts toward the street (m).
const SIDEWALK_M := 1.2
const LIMITS := {"draw_calls": 600, "triangles": 300000}


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w.houses != null, "the world has the houses of the streets (data/geo/build/houses.json)"):
		return
	var houses := w.houses
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(w.data.root.path_join(StreetHouses.FILE)))
	d.expect(houses.houses.size() == parsed.houses.size() and houses.skipped == 0,
			"each house of the file is built: %d of %d (skipped %d)" % [houses.houses.size(), parsed.houses.size(), houses.skipped])
	var run_values: Array = RUNS[d.phase - 1]
	var side: String = run_values[0]
	var shots: Array = run_values[1]
	var lots: Array[Dictionary] = []
	for house in houses.houses:
		if house.side == side:
			lots.append(house)
	var check := 0
	for house in lots:
		check += 1 if house.status == "Check" else 0
	d.step("the %s side: %d houses (%d of Q12, status Check)" % [side, lots.size(), check])
	if not d.expect(lots.size() >= 2, "the %s side has houses" % side):
		return
	var route := _sidewalk(lots)
	var length := d.route_distance(route, route[route.size() - 1])
	# Setup: the run starts at its first place on the sidewalk.
	var first := d.route_point(route, minf(float(shots[0]), length))
	var ahead := d.route_point(route, minf(float(shots[0]) + 10.0, length))
	await d.start_at(first, rad_to_deg(atan2(-(ahead.x - first.x), -(ahead.z - first.z))))
	var inside := [""]
	var watch := func() -> void:
		var p: Vector3 = d.state().player
		var i := houses.house_at(p.x, p.z)
		if i >= 0 and inside[0] == "":
			inside[0] = "%s at (%.1f, %.1f)" % [houses.houses[i].id, p.x, p.z]
	for at: float in shots:
		if at > length:
			break
		if at > float(shots[0]):
			await d.stick_along(route, at, watch, 10.0, true)
		var here: Vector3 = d.state().player
		var along := d.route_point(route, minf(d.route_distance(route, here) + 25.0, length))
		await d.look_at_point(Vector3(along.x, here.y + 1.4, along.z), 6.0, 20.0)
		await d.wait_ground(60.0)
		await d.screenshot("%s_%03d_along" % [side, int(at)])
		d.expect_not_flat("%s at %d m, along the street" % [side, int(at)])
		_budget(d, "%s at %d m" % [side, int(at)])
		# The fronts: a house of the side 12 m ahead, at an angle.
		var ahead_point := d.route_point(route, minf(d.route_distance(route, here) + 12.0, length))
		var nearest := _nearest(lots, ahead_point)
		await d.look_at_point(Vector3(nearest.front[0], float(nearest.base) + 3.0, nearest.front[1]), 6.0, 20.0)
		await d.screenshot("%s_%03d_front" % [side, int(at)])
		d.step("%s at %d m: the front of %s (%s, %s, %s)" % [side, int(at), nearest.id, nearest.model, nearest.status,
				", ".join(nearest.get("photos", [])) if nearest.has("photos") else "no photo"])
	d.expect(inside[0] == "", "the player on the sidewalk is never in a lot: %s" % inside[0])
	if not run_values[2]:
		return
	# Walk into a front: the house stops the player at its front.
	var target := _nearest(lots, d.state().player)
	var door := Vector3(target.front[0], float(target.base), target.front[1])
	var into := Vector3(target.x, float(target.base), target.z)
	# First to the sidewalk 0.8 m in front of the front, then on into the house.
	var near := door + (door - into).normalized() * 0.8
	var here: Vector3 = d.state().player
	await d.stick_along(PackedVector3Array([here, near]), here.distance_to(near), Callable(), 2.0, true)
	await d.look_at_point(into + Vector3(0, 1.5, 0), 6.0, 20.0)
	var before: Vector3 = d.state().player
	d.step("in front of %s: %.2f m from its front" % [target.id, Vector2(before.x, before.z).distance_to(Vector2(door.x, door.z))])
	# The joystick up (screen y to the top) walks forward.
	await d.hold_stick(Vector2(0, -1), 3.0)
	var stop: Vector3 = d.state().player
	var past := (Vector2(stop.x, stop.z) - Vector2(door.x, door.z)).dot((Vector2(into.x, into.z) - Vector2(door.x, door.z)).normalized())
	d.step("a walk into the front of %s stops %.2f m past its front (at %s)" % [target.id, past, stop])
	# The screenshot along the fronts, from where the walk stopped.
	var along_front := Vector3(stop.x, stop.y, stop.z) + Vector3(-(into.z - door.z), 0.0, into.x - door.x).normalized() * 20.0
	await d.look_at_point(along_front + Vector3(0, 1.4, 0), 6.0, 20.0)
	await d.screenshot("%s_into_front" % side)
	d.expect(past > -1.0 and past < 0.3 and houses.house_at(stop.x, stop.z) < 0,
			"the house %s stops the player at its front: %.2f m past it (the player came to it)" % [target.id, past])


## The sidewalk of a side: a point SIDEWALK_M in front of each front, in the order along the street.
func _sidewalk(lots: Array[Dictionary]) -> PackedVector3Array:
	var first := Vector2(lots[0].front[0], lots[0].front[1])
	var last := Vector2(lots[-1].front[0], lots[-1].front[1])
	var way := Vector2.ZERO
	for house in lots:
		way += (Vector2(house.front[0], house.front[1]) - first)
	way = way.normalized()
	var sorted := lots.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (Vector2(a.front[0], a.front[1]) - first).dot(way) < (Vector2(b.front[0], b.front[1]) - first).dot(way))
	var route := PackedVector3Array()
	for house: Dictionary in sorted:
		var front := Vector2(house.front[0], house.front[1])
		var out := (front - Vector2(house.x, house.z)).normalized()
		var p := front + out * SIDEWALK_M
		route.append(Vector3(p.x, float(house.base), p.y))
	return route


func _nearest(lots: Array[Dictionary], p: Vector3) -> Dictionary:
	var best: Dictionary = lots[0]
	for house in lots:
		if Vector2(house.front[0], house.front[1]).distance_to(Vector2(p.x, p.z)) < Vector2(best.front[0], best.front[1]).distance_to(Vector2(p.x, p.z)):
			best = house
	return best


## The draw calls, the triangles, and the video memory of the frame (PT-69: the limits of Low).
func _budget(d: PlaytestDriver, where: String) -> void:
	var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var triangles := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var memory := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
	d.step("%s: %d draw calls, %d triangles, %.0f MB of video memory" % [where, draw_calls, triangles, memory])
	d.expect(draw_calls <= LIMITS.draw_calls and triangles <= LIMITS.triangles, "%s: the budget of Low holds (%d of %d draw calls, %d of %d triangles)" % [
			where, draw_calls, LIMITS.draw_calls, triangles, LIMITS.triangles])
