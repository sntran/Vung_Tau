extends RefCounted
# PT-37 geo_chunks. Walk 2 km with tap to walk. At each frame, a ray down from
# the camera hits the ground or the sea. Record the time to load each chunk. No
# chunk takes more than 2 s under lavapipe. Each near chunk shows its ground
# (all its patches, report 0005, D-0005-10), also the chunks of the start point.
# The walk is on Thùy Vân, the road along Bãi Sau. The game runs 5 times
# faster, and the walk is in 4 runs of 500 m, so that each run is shorter than
# 180 s under lavapipe. Each run starts where the last run stops (a setup step).
# The start of the world (report 0026, D-0026-12): the build of the world takes
# at most 20 s, and the first frame comes at most 26.4 s after the start of the
# engine. In the workspace: 3.4 s and 11 s (13 s with no shader cache); in CI,
# with no shader cache, the first frame came at 45 s. With a showcase that
# waited for all its parts: 33 s and 46 s in the workspace (more than 300 s for
# a whole run in CI). Plan 0031, R17: at most 26.4 s, 1.5 times the first
# frame after the cuts of D17 (17.6 s in the workspace). PT-37 also checks the
# cuts of D17: at most 16 chunks of the town and no far stairs of the known
# places before the first frame; on a computer the test street and the town
# of the start stay before the first frame (only the web build cuts them).
# Run 5 takes the start of the web build (--web-start, plan 0031, R20): no
# test street, and at most 16 chunks of the town before the first frame. It
# checks the start only.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00 --web-start

const LENGTH := 2000.0
const RUNS := 4
const STEP := 14.0
const MAX_LOAD_MS := 2000.0
const MAX_BUILD_MS := 20000
## Plan 0031, R17: the first frame at most 1.5 times the time after the cuts
## of D17 (16.4 s and 18.7 s in the workspace on 2026-11-27; 14 s in CI before the cuts).
const MAX_FIRST_FRAME_MS := 26400
## Plan 0031, D17: on the web, before the first frame the town makes only the
## chunks near the start (at most this count); on a computer all of them.
const MAX_FIRST_FRAME_TOWN_CHUNKS := 16


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts"):
		return
	var main := d.main()
	d.step("the world is built in %.1f s, and the first frame comes %.1f s after the start of the engine" % [
			main.world_build_ms / 1000.0, main.first_frame_ms / 1000.0])
	d.expect(main.world_build_ms >= 0 and main.world_build_ms <= MAX_BUILD_MS,
			"the build of the world takes at most %d s: %.1f s" % [MAX_BUILD_MS / 1000, main.world_build_ms / 1000.0])
	d.expect(main.first_frame_ms >= 0 and main.first_frame_ms <= MAX_FIRST_FRAME_MS,
			"the first frame comes at most %d s after the start: %.1f s" % [MAX_FIRST_FRAME_MS / 1000, main.first_frame_ms / 1000.0])
	if GameState.has_arg("web-start"):
		# Plan 0031, R20 (run 5): the start of the web build on a computer
		# (--web-start): no test street, and only the town near the start
		# before the first frame.
		d.expect(Hem.builds == 0, "with the start of the web build the Vũng Tàu world does not build the test street: %d builds" % Hem.builds)
		d.expect(main.first_frame_town_chunks >= 0 and main.first_frame_town_chunks <= MAX_FIRST_FRAME_TOWN_CHUNKS,
				"with the start of the web build the town makes at most %d chunks before the first frame (the chunks near the start): %d" % [
				MAX_FIRST_FRAME_TOWN_CHUNKS, main.first_frame_town_chunks])
	else:
		# Plan 0031, D17: only the web build leaves out the test street. On a computer
		# the world without it drew each frame about 20 % slower (Hem._ready()).
		d.expect(Hem.builds == 1, "on a computer the Vũng Tàu world builds the test street one time: %d builds" % Hem.builds)
		# Only the web build makes the town of the start after the first frame. On a
		# computer the tasks of the town then waited for the compile of the
		# pipelines: the first wait of PT-33 took more than 30 s in CI.
		d.expect(main.first_frame_town_chunks > MAX_FIRST_FRAME_TOWN_CHUNKS,
				"on a computer the town makes the chunks of the start before the first frame: %d chunks" % main.first_frame_town_chunks)
	d.expect(main.first_frame_far_stairs == 0,
			"before the first frame the known places build no stairs farther than %d m from the start (they do not show): %d" % [
			int(KnownPlaces.NEAR_END), main.first_frame_far_stairs])
	await d.wait_ground()
	if d.phase > RUNS:
		# The run of R20 checks the start only; the walk is in runs 1 to RUNS.
		d.expect(w.chunks_without_ground().is_empty(), "with the start of the web build, each near chunk shows its ground: %s have no patches" % [
				w.chunks_without_ground()])
		await d.screenshot("web_start")
		return
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
	# The chunks of the start point are made at once, not in a worker thread.
	d.expect(w.chunks_without_ground().is_empty(), "at the start, each near chunk shows its ground: %s have no patches" % [
			w.chunks_without_ground()])
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
		var over_sea := eye.y > w.sea_level and w.ground_height(eye.x, eye.z) < w.sea_level
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
	await d.wait_ground(60.0)
	d.expect(w.chunks_without_ground().is_empty(), "at the end, each near chunk shows its ground: %s have no patches" % [
			w.chunks_without_ground()])
	await d.screenshot("end_%d" % d.phase)
