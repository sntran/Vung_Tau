extends RefCounted
# PT-19 geo_walk_road. Walk 500 m along the road beside Bãi Trước with the
# joystick. The camera height above the road surface stays 1.6 m ± 0.1 m. The
# road name on the debug screen is the name from OSM.
# The game runs 5 times faster, and the walk is in 2 runs of 250 m, so that
# each run is shorter than 180 s under lavapipe. The player walks at the same
# speed in game time. The second run starts at 250 m on the same route.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=07:00
# phase: --world=vung_tau --start-time=07:00

const LENGTH := 500.0
const RUNS := 2


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts"):
		return
	await d.wait_ground()
	var coast: String = w.data.homestay.get("coast_road", "")
	d.expect(coast != "", "the data has the coast road of Bãi Trước")
	var route := d.road_route(coast, d.state().player, LENGTH + 20.0)
	if not d.expect(PlaytestDriver._length(route) >= LENGTH, "the coast road is %.0f m long, not 500 m" % PlaytestDriver._length(route)):
		return
	# F3 shows the debug screen (a real key event).
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F3
	key.pressed = true
	Input.parse_input_event(key)
	await d.wait_frames(3)
	d.expect(d.state().debug_visible, "F3 shows the debug screen")
	await d.screenshot("start")
	var start: float = PlaytestDriver.route_distance(route, d.state().player)
	var from := start + LENGTH * (d.phase - 1) / RUNS
	var to := start + LENGTH * d.phase / RUNS
	if d.phase > 1:
		var point := PlaytestDriver.route_point(route, from)
		var next := PlaytestDriver.route_point(route, from + 5.0)
		await d.start_at(point, rad_to_deg(atan2(-(next.x - point.x), -(next.z - point.z))))
	d.set_time_scale(5.0)
	var heights := {"min": INF, "max": -INF, "bad": 0}
	var space: PhysicsDirectSpaceState3D = d.main().get_world_3d().direct_space_state
	var check := func() -> void:
		var s := d.state()
		if not s.on_floor:
			return
		# The surface under the eye: a sidewalk, or the road mesh, which is
		# RoadBuilder.LIFT above the ground collision.
		var eye_point: Vector3 = s.eye
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(eye_point,
				eye_point - Vector3(0, 4.0, 0), Layers.FLOOR))
		if hit.is_empty():
			heights.bad += 1
			return
		var surface: float = hit.position.y
		if surface < float(s.ground) + 0.02 and not str(s.road_name).is_empty():
			surface += RoadBuilder.LIFT
		var eye: float = eye_point.y - surface
		heights.min = minf(heights.min, eye)
		heights.max = maxf(heights.max, eye)
		if absf(eye - Player.EYE_HEIGHT) > 0.1:
			heights.bad += 1
	var names := {}
	for part in 3:
		var goal := from + (to - from) * (part + 1) / 3.0
		if not await d.stick_along(route, goal, check, 25.0):
			break
		var s := d.state()
		names[s.road_name] = true
		d.expect(str(s.debug_text).contains("Road: " + coast), "the debug screen shows the road %s: %s" % [coast, s.debug_text])
		await d.screenshot("walk_%d" % (part + 1))
	d.set_time_scale(1.0)
	var walked: float = PlaytestDriver.route_distance(route, d.state().player) - from
	d.expect(walked >= (to - from) - 2.0, "the player walks %.0f m on the road: %.0f m" % [to - from, walked])
	d.expect(heights.bad == 0, "the eye is 1.6 m ± 0.1 m above the road: %.2f to %.2f m" % [heights.min, heights.max])
	d.expect(names.has(coast), "the road name is the OSM name %s: %s" % [coast, names.keys()])
