extends RefCounted
# PT-36 geo_hill. Walk up the road to the top of Núi Nhỏ. The player never goes
# through the ground. The player cannot walk up a slope that is steeper than
# 45° where there is no road.
# The road from Hạ Long to the lighthouse is about 2.8 km long. The game runs
# 6 times faster, and the walk is in 8 runs, so that each run is shorter than
# 180 s under lavapipe. Each run starts where the last run stops (a setup step).
# The last run finds a slope that is steeper than 45° for 6 m on Núi Nhỏ or Núi
# Lớn, with no road near it, and checks it.
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

const WALK_RUNS := 8


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts"):
		return
	await d.wait_ground()
	if d.phase > WALK_RUNS:
		await _steep_slope(d, w)
		return
	var road: Dictionary = w.data.homestay.get("lighthouse_road", {})
	if not d.expect(not road.is_empty(), "the data has the lighthouse road"):
		return
	var route := PackedVector3Array()
	for p: Array in road.points:
		route.append(Vector3(p[0], 0.0, p[1]))
	var total := PlaytestDriver._length(route)
	var from := total * (d.phase - 1) / WALK_RUNS
	var to := total * d.phase / WALK_RUNS
	var point := PlaytestDriver.route_point(route, from)
	var next := PlaytestDriver.route_point(route, from + 5.0)
	await d.start_at(point, rad_to_deg(atan2(-(next.x - point.x), -(next.z - point.z))))
	await d.screenshot("start_%d" % d.phase)
	# The ground under the player: a ray down from the eye hits the ground
	# collision. When the feet are below that point, the player is in the ground.
	var lowest := [INF]
	var space: PhysicsDirectSpaceState3D = d.main().get_world_3d().direct_space_state
	var check := func() -> void:
		var s := d.state()
		var eye: Vector3 = s.eye
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye - Vector3(0, 3.0, 0),
				Layers.FLOOR))
		if hit.is_empty():
			lowest[0] = minf(lowest[0], -Player.EYE_HEIGHT)
		else:
			lowest[0] = minf(lowest[0], float(s.player.y) - float(hit.position.y))
	d.set_time_scale(6.0)
	await d.stick_along(route, to - 2.0, check, 20.0)
	d.set_time_scale(1.0)
	var s := d.state()
	d.expect(lowest[0] > -0.1, "the player never goes through the ground: %.2f m" % lowest[0])
	await d.screenshot("end_%d" % d.phase)
	if d.phase == WALK_RUNS:
		var light := w.data.landmark("hai_dang")
		var top := Vector2(light.position[0], light.position[1])
		var distance := top.distance_to(Vector2(s.player.x, s.player.z))
		d.expect(distance < 40.0, "the player is at the top of Núi Nhỏ, %.0f m from the lighthouse" % distance)
		d.expect(float(s.ground) > 120.0, "the player is high on the hill: %.0f m" % s.ground)


## Finds a slope steeper than 45 degrees on Núi Nhỏ or Núi Lớn, with no road
## near it, and walks up it with the joystick.
func _steep_slope(d: PlaytestDriver, w: VungTau) -> void:
	var best := {}
	var best_slope := 0.0
	var points: Array[Vector2] = []
	for hill_id: String in ["nui_nho", "nui_lon"]:
		var hill := w.data.landmark(hill_id)
		if hill.is_empty():
			continue
		for gx in range(-600, 601, 6):
			for gz in range(-600, 601, 6):
				points.append(Vector2(hill.position[0], hill.position[1]) + Vector2(gx, gz))
	for p: Vector2 in points:
		if true:
			var h := w.ground_height(p.x, p.y)
			if h < 3.0:
				continue
			var dx := (w.ground_height(p.x + 2.0, p.y) - w.ground_height(p.x - 2.0, p.y)) / 4.0
			var dz := (w.ground_height(p.x, p.y + 2.0) - w.ground_height(p.x, p.y - 2.0)) / 4.0
			var slope := rad_to_deg(atan(Vector2(dx, dz).length()))
			if slope <= best_slope or slope < 50.0:
				continue
			# The slope must stay steeper than 45 degrees for 6 m up from its foot.
			var up := Vector2(dx, dz).normalized()
			var foot := p - up * 2.0
			var steep := true
			for k in 3:
				var low := foot + up * (2.0 * k)
				if w.ground_height(low.x + up.x * 2.0, low.y + up.y * 2.0) - w.ground_height(low.x, low.y) < 2.0:
					steep = false
			if not steep or w.ground_height(foot.x, foot.y) < 1.0:
				continue
			var side := Vector2(-up.y, up.x)
			var near_road := false
			for offset: Vector2 in [Vector2.ZERO, up * 6.0, -up * 8.0, up * 14.0, side * 8.0, -side * 8.0]:
				if not w.data.road_at(foot.x + offset.x, foot.y + offset.y).is_empty():
					near_road = true
			if near_road:
				continue
			best_slope = slope
			best = {"top": p, "foot": foot - up * 0.6, "up": up}
	if not d.expect(not best.is_empty(), "there is a slope steeper than 45° for 6 m, with no road near it, on Núi Nhỏ or Núi Lớn"):
		return
	var foot: Vector2 = best.foot
	var up: Vector2 = best.up
	await d.start_at(Vector3(foot.x, 0.0, foot.y), rad_to_deg(atan2(-up.x, -up.y)))
	var start: Vector3 = d.state().player
	await d.screenshot("steep_slope_%d_degrees" % int(best_slope))
	await d.hold_stick(Vector2(0, -1), 5.0)
	await d.wait_idle()
	var end: Vector3 = d.state().player
	await d.screenshot("steep_slope_after")
	# The slope goes up more than 6 m in its first 6 m: a player who can walk up it goes up more than 6 m.
	d.expect(end.y - start.y < 1.0, "the player cannot walk up the %.0f° slope: %.2f m up" % [best_slope, end.y - start.y])
	d.expect(float(d.state().player.y) - float(d.state().ground) > -0.15, "the player is not in the ground")
