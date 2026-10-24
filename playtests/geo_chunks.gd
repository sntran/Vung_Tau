extends RefCounted
# PT-22 geo_chunks. Walk 2 km with tap to walk. At each frame, a ray down from
# the camera hits the ground or the sea. Record the time to load each chunk. No
# chunk takes more than 2 s under lavapipe.
# The walk is on Thùy Vân, the road along Bãi Sau. The game runs 5 times
# faster, and the walk is in 4 runs of 500 m, so that each run is shorter than
# 180 s under lavapipe. Each run starts where the last run stops (a setup step).
# sizes: 1280x720
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00

const LENGTH := 2000.0
const RUNS := 4
const STEP := 14.0
const MAX_LOAD_MS := 2000.0


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts"):
		return
	await d.wait_ground()
	var beach := w.data.landmark("bai_sau")
	var near_beach := Vector3(beach.position[0], 0.0, beach.position[1])
	# The route starts at one end of the road.
	var whole := d.road_route("Thùy Vân", near_beach, 100000.0)
	var route := d.road_route("Thùy Vân", whole[whole.size() - 1], LENGTH + 50.0) if whole.size() > 1 else whole
	if not d.expect(PlaytestDriver._length(route) >= LENGTH, "Thùy Vân is %.0f m long, not 2 km" % PlaytestDriver._length(route)):
		return
	var from := LENGTH * (d.phase - 1) / RUNS
	var to := LENGTH * d.phase / RUNS
	var point := PlaytestDriver.route_point(route, from)
	var next := PlaytestDriver.route_point(route, from + 5.0)
	await d.start_at(point, rad_to_deg(atan2(-(next.x - point.x), -(next.z - point.z))))
	w.load_times.clear()
	var space: PhysicsDirectSpaceState3D = d.main().get_world_3d().direct_space_state
	var misses := [0]
	var frames := [0]
	var frame_ms := [0.0]
	var check := func() -> void:
		var eye: Vector3 = d.state().eye
		frames[0] += 1
		frame_ms[0] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye - Vector3(0, 500, 0),
				Layers.FLOOR))
		var over_sea := eye.y > 0.0 and w.ground_height(eye.x, eye.z) < 0.0
		if hit.is_empty() and not over_sea:
			misses[0] += 1
	d.main().get_tree().process_frame.connect(check)
	d.set_time_scale(5.0)
	var taps := 0
	while true:
		var here := PlaytestDriver.route_distance(route, d.state().player)
		if here >= to - 2.0:
			break
		var target := PlaytestDriver.route_point(route, minf(here + STEP, to))
		var view := d.world_to_view(target + Vector3(0, 0.05, 0))
		var camera: Camera3D = d.main().player.camera
		if camera.is_position_behind(target) or not Rect2(Vector2(40, 140), d.state().view_size - Vector2(80, 180)).has_point(view):
			await d.look_at_point(target + Vector3(0, 0.05, 0), 6.0, 15.0)
			view = d.world_to_view(target + Vector3(0, 0.05, 0))
		await d.tap(d.to_screen(view))
		taps += 1
		await d.wait_until(func() -> bool: return not d.state().walking, 20.0, "the tap walk ends")
		if taps > 200:
			d.fail("too many taps")
			break
	d.set_time_scale(1.0)
	d.main().get_tree().process_frame.disconnect(check)
	var walked := PlaytestDriver.route_distance(route, d.state().player) - from
	d.expect(walked >= (to - from) - 3.0, "the player walks %.0f m with tap to walk: %.0f m in %d taps" % [to - from, walked, taps])
	d.expect(misses[0] == 0, "a ray down from the camera hits the ground or the sea at each frame: %d of %d frames miss" % [misses[0], frames[0]])
	var times: Array = w.load_times
	var slowest := 0.0
	for t: float in times:
		slowest = maxf(slowest, t)
	d.step("chunk load times: %d chunks, slowest %.0f ms" % [times.size(), slowest])
	# The frame time under lavapipe, only for a comparison between builds (R16).
	d.step("frame time under lavapipe: %.0f fps, %.1f ms of process time in a frame" % [
			Engine.get_frames_per_second(), frame_ms[0] / maxf(frames[0], 1.0)])
	d.expect(slowest <= MAX_LOAD_MS, "no chunk takes more than 2 s to load: %.0f ms" % slowest)
	await d.screenshot("end_%d" % d.phase)
