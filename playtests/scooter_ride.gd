extends RefCounted
# PT-80 scooter_ride (plan 0018). On Low at 17:00, from the start point
# bai_truoc. Run 1: the player walks to the parked scooter of the start with
# the joystick, looks at it (the action "Ride"), and gets on with the action
# button. The player rides south on Quang Trung and west on Hạ Long at the top
# speed to its junction at Cầu Đá (in front of Hải Âu), turns there to the
# south on Hạ Long, and brakes to a stop. (The service road to the port goes
# down steps: a scooter does not go there, D5.) Run 2: the game starts on the scooter of the
# start (--ride, R8); a setup step puts the rider on Hạ Long at Cầu Đá. The
# player rides to the south, brakes, rides over the curb onto the walk on the
# sea wall, into its parapet (the scooter stops, with the bump, and no error),
# and gets off.
# The scooter stands on its stand there; the player walks away and back, and
# rides it again. Screenshots at each step (the handlebars in the view, the
# turn with the lean, the stop at the wall).
# Checks (D2, D4, D5, R1, R9): the speed never goes over 40 km/h; 0 to 20 km/h
# in about 4 s and 30 to 10 km/h in about 1.4 s (counted in physics steps,
# so the same at 3 frames each second as at 60); the scooter never goes into a
# solid thing, the sand, or the water; the clock moves by the time of the
# frames, not by the distance; the budget of plan 0009 on Low with the
# scooter in the view (at most 600 draw calls and 300 000 triangles); the
# longest frame and the count of the frames
# longer than three times the median frame along the ride (R9: the limit comes
# after the first measure), also in out/frames.json.
# sizes: 1280x720
# phase: --world=vung_tau --start=bai_truoc --start-time=17:00 --quality=low
# phase: --world=vung_tau --start=bai_truoc --start-time=17:05 --quality=low --ride
# phase: --world=vung_tau --start=bai_truoc --start-time=17:10 --quality=low --ride
# phase: --world=vung_tau --start=bai_truoc --start-time=17:15 --quality=low --ride
# phase: --world=vung_tau --start=bai_truoc --start-time=17:20 --quality=low --ride

## The roads of the ride (OSM ways): Quang Trung to the south, Hạ Long to the
## west and its last part to the junction at Cầu Đá, and Hạ Long from the
## junction to the south (also the road of run 2).
const QUANG_TRUNG_SOUTH := 1558591261
const HA_LONG := [200554629, 1423071603]
const HA_LONG_SOUTH := 200554632
const TOP_KMH := 40.0
## The ride on Hạ Long to the south after the turn (m).
const AFTER_TURN := 60.0
## Run 2: the point on Hạ Long at Cầu Đá (x, z); the walk on the sea wall is to its west.
const PORT_POINT := Vector2(-211.0, 449.0)
## Run 2: the ride across the edge of the sidewalk of Quang Trung (x, z).
const CURB_FROM := Vector3(99.5, 0.0, 60.0)
const CURB_TO := Vector3(91.0, 0.0, 60.0)
## Run 3 (report 0018, D-0018-01): the curb of the sidewalk of the park on
## Quang Trung (15 cm over the road; the sidewalk is 2.5 m wide, from x 94.75
## to x 97.25 at z 60). At 3 km/h: from the road to the west, straight up the
## curb, then to the north along the sidewalk. At 20 km/h: from the road to
## the north, up the curb at a small angle, then along the sidewalk.
const CURB_SLOW := [Vector3(102.0, 0.0, 60.0), Vector3(96.2, 0.0, 60.0), Vector3(96.6, 0.0, 64.0),
		Vector3(97.2, 0.0, 69.0), Vector3(97.6, 0.0, 73.0)]
const CURB_FAST := [Vector3(99.8, 0.0, 30.0), Vector3(95.9, 0.0, 58.0), Vector3(96.6, 0.0, 64.0),
		Vector3(97.3, 0.0, 70.0), Vector3(97.8, 0.0, 76.0)]
## After the curb, the scooter rides at least this far on the sidewalk (m).
const ON_SIDEWALK := 5.0
## Run 5 (plan 0018, D10, D11, D13): Nguyễn Trãi, the road to the east from
## Quang Trung south of the start of Bãi Trước.
const NGUYEN_TRAI := "Nguyễn Trãi"
## After the turn the rider lets go on Nguyễn Trãi this far from Quang Trung (m).
const LET_GO_AT := 45.0
## The two roads of Quang Trung (one for each way).
const QUANG_TRUNG := [1558591261, 200554615]

var _max_kmh := 0.0
var _overlaps: Array = []
var _bad_ground: Array = []
var _frames: Array[float] = []
var _last_usec := 0
var _phys_start := -1
var _phys_20 := -1
var _lean_max := 0.0
var _watch_stop := false
var _phys_stop := -1
var _phys_brake := -1
var _brake_kmh := 0.0


func run(d: PlaytestDriver) -> void:
	if d.phase == 2:
		# Before the ground and the showcase are ready (report 0018, D-0018-03).
		await _first_push(d)
	await d.wait_ground(120.0)
	if d.phase == 1:
		await _run_1(d)
	elif d.phase == 2:
		await _run_2(d)
	elif d.phase == 3:
		await _run_3(d)
	elif d.phase == 4:
		await _run_4(d)
	else:
		await _run_5(d)


## The roads of the data by id: their points, in order, from "from" on.
func _road_points(d: PlaytestDriver, id: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for road: Dictionary in d.world().data.roads:
		if int(road.id) == id:
			for p: Array in road.points:
				out.append(Vector3(p[0], p[1], p[2]))
	return out


## The road of Quang Trung that goes the way of the scooter, from the scooter on.
func _carriageway(d: PlaytestDriver, s: Dictionary) -> PackedVector3Array:
	var front := Basis(Vector3.UP, deg_to_rad(s.heading)) * Vector3(0, 0, -1)
	for id: int in QUANG_TRUNG:
		var points := _road_points(d, id)
		var route := PackedVector3Array(points)
		var at := PlaytestDriver.route_distance(route, s.player)
		var a := PlaytestDriver.route_point(route, at)
		var b := PlaytestDriver.route_point(route, at + 5.0)
		if Vector3(b.x - a.x, 0, b.z - a.z).normalized().dot(front) > 0.7:
			return route
	return PackedVector3Array()


func _route(d: PlaytestDriver, from: Vector3) -> PackedVector3Array:
	var route := PackedVector3Array()
	var south := _road_points(d, QUANG_TRUNG_SOUTH)
	var nearest := 0
	for i in south.size():
		if Vector2(south[i].x - from.x, south[i].z - from.z).length() < Vector2(south[nearest].x - from.x, south[nearest].z - from.z).length():
			nearest = i
	for i in range(nearest, south.size()):
		route.append(south[i])
	for id: int in HA_LONG:
		for p in _road_points(d, id):
			route.append(p)
	var turn := _road_points(d, HA_LONG_SOUTH)
	var along := 0.0
	for i in range(1, turn.size()):
		along += Vector2(turn[i].x - turn[i - 1].x, turn[i].z - turn[i - 1].z).length()
		route.append(turn[i])
		if along > AFTER_TURN + 20.0:
			break
	return route


## The checks of each frame while the player rides.
func _check(d: PlaytestDriver) -> void:
	var s := d.state()
	if not s.riding:
		return
	_max_kmh = maxf(_max_kmh, s.speed_kmh)
	_lean_max = maxf(_lean_max, absf(s.lean))
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_frames.append((now - _last_usec) / 1000.0)
	_last_usec = now
	if _phys_start < 0 and s.speed_kmh > 0.5:
		_phys_start = Engine.get_physics_frames()
	if _phys_20 < 0 and s.speed_kmh >= 20.0:
		_phys_20 = Engine.get_physics_frames()
	var player: Player = d.main().player
	if _watch_stop and _phys_brake < 0 and player.move_input.y < -0.9:
		_phys_brake = Engine.get_physics_frames()
		_brake_kmh = s.speed_kmh
	if _watch_stop and _phys_brake >= 0 and _phys_stop < 0 and s.speed_kmh < 1.0:
		_phys_stop = Engine.get_physics_frames()
	var overlaps: Array = d.player_overlaps()
	if not overlaps.is_empty() and _overlaps.size() < 5:
		_overlaps.append("%s at %s" % [overlaps, s.player])
	var riding: Riding = d.main().riding
	if not riding._can_ride(s.player, s.player) and _bad_ground.size() < 5:
		_bad_ground.append(s.player)


func _run_1(d: PlaytestDriver) -> void:
	var start := d.state()
	var riding: Riding = d.main().riding
	var index := riding.scooters.nearest(start.player, 12.0)
	if not d.expect(index >= 0, "a parked scooter stands within 10 m of the start bai_truoc (R8)"):
		return
	var scooter: Transform3D = riding.scooters.parked[index].at
	var gap := Vector2(scooter.origin.x - start.player.x, scooter.origin.z - start.player.z).length()
	d.expect(gap <= 10.0, "the scooter of the start is %.1f m from the start point (at most 10 m, R8)" % gap)
	# Walk with the joystick to the left side of the scooter, and look at it.
	var front := scooter.basis.z.normalized()
	var left := Vector3.UP.cross(front).normalized()
	var beside := scooter.origin + left * 1.3
	var walk := PackedVector3Array([start.player, beside])
	await d.stick_along(walk, PlaytestDriver.route_distance(walk, beside), Callable(), 12.0, true)
	await d.look_at_point(scooter.origin + Vector3(0, 0.6, 0), 2.0)
	await d.wait_frames(3)
	var s := d.state()
	d.expect(s.action_verb == Riding.verb("scooter_ride"), "the center dot shows the action \"%s\" at the scooter, not \"%s\" (R4)" % [
			Riding.verb("scooter_ride"), s.action_verb])
	await d.screenshot("look_at_scooter")
	await d.tap_id("action")
	await d.wait_frames(5)
	s = d.state()
	if not d.expect(s.riding, "the action button gets the player on the scooter (D1)"):
		return
	d.expect(s.action_verb == Riding.verb("scooter_get_off"), "on the scooter the action button is \"Get off\" (D7): \"%s\"" % s.action_verb)
	await d.screenshot("on_seat")
	await _budget(d, "on the seat at the start")
	var clock_start := d.state()
	# The ride: Quang Trung, Hạ Long, the junction, the port.
	var route := _route(d, s.player)
	var length := PlaytestDriver.route_length(route)
	d.step("the route: %.0f m" % length)
	var junction := PlaytestDriver.route_distance(route, _road_points(d, HA_LONG_SOUTH)[0])
	var checker := _check.bind(d)
	# The top speed to 60 m before the junction: then the rider slows to 20 km/h
	# for the turn (D4: a street corner needs 20 km/h or less).
	var ok := await d.ride_along(route, junction - 60.0, TOP_KMH, checker)
	d.expect(ok, "the scooter rides Quang Trung and Hạ Long to the junction")
	s = d.state()
	await d.screenshot("hai_long_at_speed")
	await _budget(d, "on Hạ Long at the top speed")
	d.step("at %.1f km/h at %s" % [s.speed_kmh, s.player])
	_lean_max = 0.0
	# In the turn at the junction, at 20 km/h: the screenshot while the stick
	# holds the turn, at the first lean of 3° or more (report 0018, D-0018-04).
	var in_turn := {}
	var leaning := func() -> bool:
		var now := d.state()
		if absf(float(now.lean)) < 3.0 or float(now.speed_kmh) > 25.0:
			return false
		in_turn.merge(now, true)
		return true
	await d.ride_along(route, junction + AFTER_TURN, 20.0, checker, false, 170.0, leaning, "turn_lean")
	if d.expect(not in_turn.is_empty(), "the scooter leans 3° or more in the turn (D3)"):
		d.step("in the turn, at the screenshot: %.1f km/h, lean %.1f°, steer %.1f°" % [in_turn.speed_kmh, in_turn.lean, in_turn.steer])
		d.expect(absf(float(in_turn.steer)) >= 1.0, "the screenshot of the turn is taken while the handlebars turn: %.1f°" % in_turn.steer)
	ok = await d.ride_along(route, junction + AFTER_TURN, 20.0, checker, true)
	d.expect(ok, "the scooter turns at the junction at Cầu Đá to the south on Hạ Long")
	d.step("the largest lean in the turn: %.1f°" % _lean_max)
	d.expect(_lean_max > 1.0 and _lean_max <= ScooterMotion.MAX_LEAN + 0.01, "the view leans into the turn, at most 8° (D3): %.1f°" % _lean_max)
	await d.screenshot("turned_south")
	# The brake: full brake from 30 km/h or less, to a stop.
	await d.hold_stick(Vector2(0, 1), 3.0)
	s = d.state()
	d.expect(absf(s.speed_kmh) < 2.0, "the brake stops the scooter: %.1f km/h" % s.speed_kmh)
	await d.screenshot("stopped_on_ha_long")
	_report(d)
	var end := d.state()
	var clock: float = end.clock_s - clock_start.clock_s
	var frames: float = end.frame_s - clock_start.frame_s
	d.expect(absf(clock - frames) <= 1.5, "the clock moved %.1f s in %.1f s of frames on a ride of %.0f m (R1)" % [clock, frames, length])


## Plan 0018, acceptance 3: the budget of plan 0009 (R10, Q10) on Low with the
## scooter in the view: at most 600 draw calls and 300 000 triangles.
func _budget(d: PlaytestDriver, where: String) -> void:
	await d.wait_frames(2)
	var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var triangles := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	d.step("%s: %d draw calls, %d triangles" % [where, draw_calls, triangles])
	d.expect(draw_calls <= 600, "%s: at most 600 draw calls on Low with the scooter (plan 0009, Q10): %d" % [where, draw_calls])
	d.expect(triangles <= 300000, "%s: at most 300 000 triangles on Low with the scooter (plan 0009, R10): %d" % [where, triangles])


func _report(d: PlaytestDriver) -> void:
	d.expect(_max_kmh <= TOP_KMH + 0.1, "the speed never goes over 40 km/h: %.2f km/h (D2)" % _max_kmh)
	d.expect(_max_kmh >= TOP_KMH - 1.0, "the scooter reaches its top speed: %.1f km/h" % _max_kmh)
	if _phys_start >= 0 and _phys_20 >= 0:
		var seconds := (_phys_20 - _phys_start) / float(Engine.physics_ticks_per_second)
		d.expect(absf(seconds - 4.0) <= 0.5, "0 to 20 km/h takes %.2f s of game time (about 4 s, D2)" % seconds)
	d.expect(_overlaps.is_empty(), "the scooter never goes into a solid thing: %s" % [_overlaps])
	d.expect(_bad_ground.is_empty(), "the scooter never goes onto the sand or into the water: %s" % [_bad_ground])
	# R9: the frames along the ride.
	if _frames.size() > 10:
		var sorted := _frames.duplicate()
		sorted.sort()
		var median: float = sorted[sorted.size() / 2]
		var longest: float = sorted[-1]
		var long := 0
		for f: float in _frames:
			if f > 3.0 * median:
				long += 1
		d.step("R9: %d frames along the ride, median %.1f ms, longest %.1f ms, %d frames longer than 3 x the median" % [
				_frames.size(), median, longest, long])
		var file := FileAccess.open(d.out_dir.path_join("frames_%d.json" % d.phase), FileAccess.WRITE)
		file.store_string(JSON.stringify({"frames": _frames.size(), "median_ms": median, "longest_ms": longest,
				"long_frames": long, "fps": Engine.get_frames_per_second()}))
		file.close()


## Run 2 starts here, at the first frame of the run (report 0018, D-0018-03):
## the first screenshot before the first push. While the showcase near the
## start is not built (its sidewalks, the median, the plants of the park), a
## push does not move the scooter, and a caption says to wait. Then the
## scooter rides.
func _first_push(d: PlaytestDriver) -> void:
	var s := d.state()
	if not d.expect(s.riding, "with --ride the game starts on the scooter of the start (R8)"):
		return
	var w := d.world()
	var pending: bool = w != null and w.showcase != null and not w.showcase.is_built()
	d.step("at the first frame of the run the showcase is built: %s" % (not pending))
	await d.screenshot("ride_at_start")
	if pending:
		var from: Vector3 = s.player
		await d.hold_stick(Vector2(0, -1), 1.0)
		s = d.state()
		var moved := Vector2(s.player.x - from.x, s.player.z - from.z).length()
		var still_pending: bool = not w.showcase.is_built()
		d.step("a push of 1 s before the showcase is built: %.2f m, %.1f km/h (the showcase is built now: %s)" % [
				moved, s.speed_kmh, not still_pending])
		if still_pending:
			d.expect(moved < 0.2 and s.speed_kmh < 1.0,
					"the scooter does not move before the showcase near the start is built (D-0018-03): %.2f m, %.1f km/h" % [moved, s.speed_kmh])
			var caption: Dictionary = d.subtitle()
			var wait_text := Content.ui_text("scooter_wait")
			d.expect(wait_text != "" and str(caption).contains(wait_text), "a caption says to wait: %s" % [caption])
			await d.screenshot("wait_for_showcase")
	await d.wait_until(func() -> bool: return w == null or w.showcase == null or w.showcase.is_built(), 120.0,
			"the showcase near the start is built")
	d.step("the showcase near the start is built %.1f s of game time after the start of the run" % Playtest.frame_s)


func _run_2(d: PlaytestDriver) -> void:
	var s := d.state()
	if not d.expect(s.riding, "with --ride the game starts on the scooter of the start (R8)"):
		return
	await d.screenshot("ride_when_built")
	var checker := _check.bind(d)
	# The brake on the straight Quang Trung: up to 30 km/h, then the full brake.
	var road := _carriageway(d, s)
	var from := PlaytestDriver.route_distance(road, s.player)
	await d.ride_along(road, from + 60.0, 30.0, checker)
	s = d.state()
	_phys_stop = -1
	_phys_brake = -1
	_watch_stop = true
	d.main().get_tree().process_frame.connect(checker)
	await d.hold_stick(Vector2(0, 1), 3.0)
	d.main().get_tree().process_frame.disconnect(checker)
	_watch_stop = false
	if _phys_stop > 0:
		var seconds := (_phys_stop - _phys_brake) / float(Engine.physics_ticks_per_second)
		var v0 := _brake_kmh
		var model := v0 / 3.6 / ScooterMotion.BRAKE
		d.expect(absf(seconds - model) <= 0.35, "the full brake stops the scooter from %.1f km/h in %.2f s of game time (%.2f s at 4 m/s², D2)" % [v0, seconds, model])
	else:
		d.expect(false, "the full brake stops the scooter")
	await d.screenshot("brake_stop")
	# The curb: a setup step puts the rider on Quang Trung at (99.5, 60) to
	# the west, to the sidewalk of the park (the showcase): its curb is 15 cm
	# over the surface of the road, 19 cm over the ground under the road (the
	# way from the stop of the brake changed with the frame rate).
	await d.start_at(CURB_FROM, 90.0)
	await d.wait_frames(5)
	s = d.state()
	var here: Vector3 = s.player
	# The rise from the road where the scooter stands now (across the road the
	# ground is level here: 5.14 m to 5.15 m from x 99.5 to 93.75).
	var road_y: float = here.y
	var rise := func() -> float: return float(d.state().player.y) - road_y
	var on_sidewalk := func() -> bool: return rise.call() > 0.12
	var onto := PackedVector3Array([here, Vector3(CURB_TO.x, here.y, CURB_TO.z)])
	var bumps_before: int = s.bumps
	await d.ride_along(onto, PlaytestDriver.route_length(onto) - 0.5, 8.0, checker, false, 30.0, on_sidewalk)
	await d.hold_stick(Vector2(0, 1), 1.5)
	s = d.state()
	d.step("on the sidewalk: %s, %.2f m over the road" % [s.player, s.player.y - road_y])
	d.expect(s.player.y > road_y + 0.1, "the scooter rides up the curb onto the sidewalk: %.2f m up (D5)" % (s.player.y - road_y))
	d.expect(s.riding and s.bumps == bumps_before, "the curb does not stop the scooter")
	await d.screenshot("over_the_curb")
	# The wall: a setup step puts the rider on Hạ Long at Cầu Đá, to the west;
	# the walk on the sea wall stands 0.5 m to 0.75 m over the road there.
	await d.start_at(Vector3(PORT_POINT.x, 0.0, PORT_POINT.y), 90.0)
	await d.wait_frames(5)
	s = d.state()
	bumps_before = s.bumps
	await d.hold_stick(Vector2(0, -0.7), 6.0)
	s = d.state()
	d.step("at the walk: %s, %.1f km/h, %d bumps" % [s.player, s.speed_kmh, s.bumps])
	d.expect(s.bumps > bumps_before, "the scooter hits the face of the walk on the sea wall and stops, with the bump (D5)")
	d.expect(absf(s.speed_kmh) < 1.0, "the scooter stands at the wall: %.1f km/h" % s.speed_kmh)
	d.expect(d.player_overlaps().is_empty(), "the scooter is not in the wall: %s" % [d.player_overlaps()])
	await d.screenshot("stopped_at_wall")
	# Get off: the scooter stays on its stand, the player at its left side.
	await d.tap_id("action")
	await d.wait_frames(5)
	s = d.state()
	if not d.expect(not s.riding, "\"Get off\" gets the player off (D9)"):
		return
	var riding: Riding = d.main().riding
	var index := riding.scooters.nearest(s.player, 3.0)
	if not d.expect(index >= 0, "the scooter stands where the player got off"):
		return
	var parked: Transform3D = riding.scooters.parked[index].at
	await d.look_at_point(parked.origin + Vector3(0, 0.5, 0), 2.0)
	await d.screenshot("got_off")
	# Walk away 8 m and back.
	var walk := PackedVector3Array([s.player, Vector3(s.player.x + 8.0, s.player.y, s.player.z)])
	await d.stick_along(walk, 8.0, Callable(), 12.0, true)
	await d.look_at_point(parked.origin + Vector3(0, 0.6, 0), 2.0)
	await d.screenshot("walked_away")
	var back := PackedVector3Array([d.state().player, parked.origin + Vector3.UP.cross(parked.basis.z).normalized() * 1.3])
	await d.stick_along(back, PlaytestDriver.route_distance(back, back[1]), Callable(), 12.0, true)
	await d.look_at_point(parked.origin + Vector3(0, 0.6, 0), 2.0)
	await d.wait_frames(3)
	s = d.state()
	d.expect(s.action_verb == Riding.verb("scooter_ride"), "the scooter where the player got off can be ridden again: \"%s\"" % s.action_verb)
	await d.tap_id("action")
	await d.wait_frames(5)
	s = d.state()
	d.expect(s.riding, "the player rides the scooter again")
	await d.hold_stick(Vector2(0, 1), 1.0)
	await d.hold_stick(Vector2(0, -1), 2.0)
	s = d.state()
	d.expect(s.speed_kmh > 3.0 or s.bumps > bumps_before, "the scooter rides again: %.1f km/h" % s.speed_kmh)
	await d.screenshot("ride_again")
	d.expect(_overlaps.is_empty(), "the scooter never goes into a solid thing: %s" % [_overlaps])
	d.expect(_bad_ground.is_empty(), "the scooter never goes onto the sand or into the water: %s" % [_bad_ground])


## Run 3 (report 0018, D-0018-01): a scooter rides up a curb of 15 cm at each
## speed from 2 km/h to 40 km/h, and rides on. Up the curb of the park at
## 3 km/h and at 20 km/h, then 5 m on along the sidewalk, with no bump. A
## screenshot on the curb, with the handlebars in the view.
func _run_3(d: PlaytestDriver) -> void:
	if not d.expect(d.state().riding, "with --ride the game starts on the scooter of the start (R8)"):
		return
	await _curb_ride(d, CURB_SLOW, 3.0, "slow")
	await _curb_ride(d, CURB_FAST, 20.0, "fast")
	d.expect(_overlaps.is_empty(), "the scooter never goes into a solid thing: %s" % [_overlaps])
	d.expect(_bad_ground.is_empty(), "the scooter never goes onto the sand or into the water: %s" % [_bad_ground])


func _curb_ride(d: PlaytestDriver, points: Array, kmh: float, label: String) -> void:
	var first: Vector3 = points[0]
	var to: Vector3 = points[1]
	# A setup step: the rider on the road, the front to the second point.
	await d.start_at(first, rad_to_deg(atan2(-(to.x - first.x), -(to.z - first.z))))
	await d.wait_showcase()
	await d.wait_frames(5)
	var s := d.state()
	var road_y: float = s.player.y
	var bumps_before: int = s.bumps
	var route := PackedVector3Array()
	for p: Vector3 in points:
		route.append(Vector3(p.x, road_y, p.z))
	# The floor under the middle of the scooter: the sidewalk is a part of the
	# showcase; a road has no collision of its own (its floor is the ground).
	var player: Player = d.main().player
	var on_sidewalk := func() -> bool:
		var middle := player.ride_middle()
		var query := PhysicsRayQueryParameters3D.create(middle + Vector3(0, 1.0, 0), middle - Vector3(0, 1.0, 0), Layers.FLOOR)
		query.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		return not hit.is_empty() and (hit.collider as Node).name == "ShowcaseBody"
	var bumps_at: Array = []
	var on_bump := func() -> void: bumps_at.append(player.global_position)
	player.bumped.connect(on_bump)
	# Each frame: the speed where the scooter goes up, and the way on the sidewalk after it.
	var up := {"kmh": -1.0, "at": Vector3.ZERO, "on": 0.0, "last": Vector3.ZERO, "off": 0}
	var watch := func() -> void:
		_check(d)
		var now := d.state()
		var on: bool = on_sidewalk.call()
		if float(up.kmh) < 0.0 and on:
			up.kmh = now.speed_kmh
			up.at = now.player
			up.last = now.player
		elif float(up.kmh) >= 0.0:
			var p: Vector3 = now.player
			if on:
				up.on = float(up.on) + Vector2(p.x - up.last.x, p.z - up.last.z).length()
			elif float(up.on) < ON_SIDEWALK:
				up.off = int(up.off) + 1
			up.last = p
	var length := PlaytestDriver.route_length(route)
	await d.ride_along(route, length, kmh, watch, false, 60.0, on_sidewalk)
	# On the curb: the screenshot with the handlebars in the view.
	s = d.state()
	d.step("%s: on the curb at %.1f km/h at %s, the view pitch %.1f° (on the seat %.1f°)" % [
			label, s.speed_kmh, s.player, player.pitch, player.ride_pitch()])
	d.expect(absf(player.pitch - player.ride_pitch()) <= 2.0,
			"%s: the view on the seat looks down to the handlebars on the curb: pitch %.1f°, not %.1f° (D3)" % [label, player.pitch, player.ride_pitch()])
	d.expect(d.grips_in_view(), "%s: the handlebars are in the view on the curb (D3): the grips at %s, the ground pitch %.1f°" % [
			label, d.grips_on_screen(), player.ground_pitch])
	await d.screenshot("curb_%s" % label)
	await d.ride_along(route, length, kmh, watch, true, 60.0)
	player.bumped.disconnect(on_bump)
	s = d.state()
	d.step("%s: up the curb at %.1f km/h at %s; then %.1f m on the sidewalk (%d frames off it before 5 m); at the end %s; bumps at %s" % [
			label, float(up.kmh), up.at, float(up.on), int(up.off), s.player, bumps_at])
	d.expect(float(up.kmh) >= kmh * 0.6 and float(up.kmh) <= kmh * 1.4,
			"%s: the scooter goes up the curb at about %.0f km/h: %.1f km/h" % [label, kmh, float(up.kmh)])
	d.expect(s.bumps == bumps_before, "%s: no bump at the curb (D5, D-0018-01): %d" % [label, s.bumps - bumps_before])
	d.expect(float(up.on) >= ON_SIDEWALK and int(up.off) == 0,
			"%s: after the curb the scooter rides %.1f m on along the sidewalk (at least %.0f m), and does not fall back to the road" % [
			label, float(up.on), ON_SIDEWALK])
	await d.screenshot("on_sidewalk_%s" % label)


## Run 4 (report 0018, D-0018-04): the paths where a scooter must stop.
## "Get off" at more than 2 km/h: the player stays on, and the caption says to
## slow down (D9). A ride into the sand (an opening of the low wall of the
## beach with no steps: the sand is near the height of the walk), down stairs
## (an opening with steps down to the sand), and into the water (Hồ Mây
## Thượng on Núi Lớn, from the road next to it): each stops the scooter with
## the bump and no error, before it goes there (D5).
func _run_4(d: PlaytestDriver) -> void:
	if not d.expect(d.state().riding, "with --ride the game starts on the scooter of the start (R8)"):
		return
	var w := d.world()
	await d.wait_showcase()
	# Get off at a speed.
	await d.hold_stick(Vector2(0, -1), 3.0)
	var s := d.state()
	var kmh: float = s.speed_kmh
	await d.tap_id("action")
	await d.wait_frames(3)
	s = d.state()
	var slow_down := Content.ui_text("scooter_too_fast")
	d.expect(kmh > 2.0 and s.riding, "\"Get off\" at %.1f km/h does not get the player off (D9)" % kmh)
	d.expect(str(d.subtitle()).contains(slow_down), "the caption says \"%s\": %s" % [slow_down, d.subtitle()])
	await d.screenshot("get_off_at_speed")
	await d.hold_stick(Vector2(0, 1), 3.0)
	# The sand and the stairs: two openings of the low wall of the beach.
	var sand_opening := {}
	var steps_opening := {}
	for opening: Dictionary in w.showcase.wall_openings:
		var sand: Vector3 = opening.get("sand", Vector3.ZERO)
		var out: Vector3 = opening.at + sand * 4.5
		if sand == Vector3.ZERO or w.surface_at(out.x, out.z).r < 0.5:
			continue
		if not bool(opening.get("steps", false)) and sand_opening.is_empty():
			sand_opening = opening
		elif bool(opening.get("steps", false)) and steps_opening.is_empty():
			steps_opening = opening
	if d.expect(not sand_opening.is_empty(), "an opening of the low wall has the sand near the height of the walk"):
		await _ride_into(d, sand_opening.at - sand_opening.sand * 4.0, sand_opening.sand, "sand")
	if d.expect(not steps_opening.is_empty(), "an opening of the low wall has steps down to the sand"):
		await _ride_into(d, steps_opening.at - steps_opening.sand * 4.0, steps_opening.sand, "stairs")
	# The water: the road next to Hồ Mây Thượng, to the middle of the lake.
	var lake: Dictionary = w.inland_water.area_named("Hồ Mây Thượng") if w.inland_water != null else {}
	if d.expect(not lake.is_empty(), "the lake Hồ Mây Thượng is in the world"):
		var middle: Vector3 = lake.middle
		var near := Vector3.INF
		for road: Dictionary in w.data.roads:
			for p: Array in road.points:
				var q := Vector3(p[0], p[1], p[2])
				if Vector2(q.x - middle.x, q.z - middle.z).length() < Vector2(near.x - middle.x, near.z - middle.z).length():
					near = q
		var to := Vector3(middle.x - near.x, 0.0, middle.z - near.z).normalized()
		await _ride_into(d, near, to, "water", float(lake.level))
	d.expect(_overlaps.is_empty(), "the scooter never goes into a solid thing: %s" % [_overlaps])


## From "from", rides to the direction at half throttle for at most 10 s. The
## scooter must stop with the bump before it goes onto the sand, down the
## stairs, or into the water: the front wheel is not there, and the scooter
## stands where it stopped.
func _ride_into(d: PlaytestDriver, from: Vector3, direction: Vector3, what: String, water_level := -INF) -> void:
	var w := d.world()
	await d.start_at(from, rad_to_deg(atan2(-direction.x, -direction.z)))
	await d.wait_frames(5)
	var player: Player = d.main().player
	var s := d.state()
	var start_y: float = s.player.y
	var bumps_before: int = s.bumps
	var front_on := {"sand": false, "water": false, "lowest": INF}
	var watch := func() -> void:
		_check(d)
		var p := player.global_position
		front_on.lowest = minf(float(front_on.lowest), p.y)
		var front := player.ride_middle() + player.ride.forward() * Player.AXLE
		if _on_sand(player, w, front):
			front_on.sand = true
		if water_level > -INF and w.ground_height(front.x, front.z) < water_level - 0.05:
			front_on.water = true
	var tree := d.main().get_tree()
	tree.physics_frame.connect(watch)
	await d.hold_stick(Vector2(0, -0.5), 10.0)
	tree.physics_frame.disconnect(watch)
	s = d.state()
	var moved := Vector2(s.player.x - from.x, s.player.z - from.z).length()
	var lowest := float(front_on.lowest)
	d.step("%s: from %s to %s, %.1f m, %.1f km/h, %d bumps, the lowest %.2f m (the start %.2f m), the front on the sand %s, in the water %s" % [
			what, from, s.player, moved, s.speed_kmh, s.bumps - bumps_before, lowest, start_y, front_on.sand, front_on.water])
	d.expect(s.bumps > bumps_before, "%s: the scooter stops with the bump (D5)" % what)
	d.expect(absf(s.speed_kmh) < 1.0 and moved < 12.0, "%s: the scooter stands where it stopped: %.1f km/h, %.1f m" % [what, s.speed_kmh, moved])
	match what:
		"sand":
			d.expect(not front_on.sand, "sand: the front wheel never goes onto the sand (D5)")
		"stairs":
			d.expect(lowest > start_y - 0.25, "stairs: the scooter does not go down the stairs: the lowest %.2f m, the walk %.2f m (D5)" % [lowest, start_y])
		"water":
			d.expect(not front_on.water, "water: the front wheel never goes into the water (D5)")
	await d.screenshot("stopped_at_%s" % what)


## True when the point is on the sand: VungTau.sand_at() (the coarse surface
## mask, less the paving and the lawns of the showcase), on the height map of
## the ground (a road or a part of the showcase is not sand).
func _on_sand(player: Player, w: VungTau, point: Vector3) -> bool:
	if not w.sand_at(point.x, point.z):
		return false
	var query := PhysicsRayQueryParameters3D.create(point + Vector3(0, 1.0, 0), point - Vector3(0, 2.0, 0), Layers.FLOOR)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var body := hit.collider as CollisionObject3D
	if body == null:
		return false
	var shape := body.shape_owner_get_shape(body.shape_find_owner(int(hit.shape)), 0)
	return shape is HeightMapShape3D


## Run 5 (plan 0018, D10, D11, D13): from the start of Bãi Trước, south on
## Quang Trung at the top speed, then left into Nguyễn Trãi with the stick only
## (up, then hard to the side; no brake). The scooter stays on the roads, with
## no bump. On Nguyễn Trãi the rider lets go, and the engine slows the scooter
## at 1.5 m/s². The name of each road shows when the scooter comes onto it,
## with a screenshot of each.
func _run_5(d: PlaytestDriver) -> void:
	var s := d.state()
	if not d.expect(s.riding, "with --ride the game starts on the scooter of the start (R8)"):
		return
	var w := d.world()
	d.expect(s.hint_text == Content.ui_text("scooter_hint_touch") or s.hint_text == Content.ui_text("scooter_hint_keys"),
			"the hint of the first ride shows when the world is ready (D12): \"%s\"" % s.hint_text)
	await d.screenshot("ride_hint")
	await d.wait_showcase()
	await d.wait_frames(3)
	s = d.state()
	# The route: the road of Quang Trung to the south from the scooter, to the
	# end of Nguyễn Trãi at Quang Trung, then along Nguyễn Trãi.
	var nt_points: Array[Vector3] = []
	for road: Dictionary in w.data.roads:
		if road.name == NGUYEN_TRAI:
			for p: Array in road.points:
				nt_points.append(Vector3(p[0], p[1], p[2]))
	if not d.expect(nt_points.size() > 1, "the road Nguyễn Trãi is in the data"):
		return
	if Vector2(nt_points[-1].x - s.player.x, nt_points[-1].z - s.player.z).length() \
			< Vector2(nt_points[0].x - s.player.x, nt_points[0].z - s.player.z).length():
		nt_points.reverse()
	var corner: Vector3 = nt_points[0]
	var route := PackedVector3Array()
	var south := _road_points(d, QUANG_TRUNG_SOUTH)
	var nearest := 0
	for i in south.size():
		if Vector2(south[i].x - s.player.x, south[i].z - s.player.z).length() < Vector2(south[nearest].x - s.player.x, south[nearest].z - s.player.z).length():
			nearest = i
	for i in range(nearest, south.size()):
		if south[i].z > corner.z - 6.0:
			break
		route.append(south[i])
	route.append(Vector3(corner.x - 8.0, corner.y, corner.z))
	for p in nt_points:
		route.append(p)
	var turn_at := PlaytestDriver.route_distance(route, corner)
	d.step("the route: %.0f m to the corner of Nguyễn Trãi at %s" % [turn_at, corner])
	var player: Player = d.main().player
	var bumps_before: int = s.bumps
	var trace := {"off": [], "names": [], "braked": false, "max_kmh": 0.0}
	var watch := func() -> void:
		_check(d)
		var now := d.state()
		trace.max_kmh = maxf(float(trace.max_kmh), now.speed_kmh)
		if player.move_input.y < -0.05:
			trace.braked = true
		if now.road_sign != "" and (trace.names.is_empty() or trace.names[-1] != now.road_sign):
			trace.names.append(now.road_sign)
		var middle := player.ride_middle()
		if not _near_road(w, middle, 2.5) and _on_ground(player, middle) and trace.off.size() < 5:
			trace.off.append(middle)
	# The name of the road shows when the scooter starts on it, and when it comes onto Nguyễn Trãi.
	var on_qt := func() -> bool: return d.state().road_sign == "Quang Trung"
	await d.ride_along(route, turn_at - 20.0, TOP_KMH, watch, false, 120.0, on_qt, "road_quang_trung", true)
	d.expect(d.state().road_sign == "Quang Trung", "the name \"Quang Trung\" shows when the scooter rides on it (D13)")
	var on_nt := func() -> bool: return d.state().road_sign == NGUYEN_TRAI
	await d.ride_along(route, turn_at + LET_GO_AT, TOP_KMH, watch, false, 120.0, on_nt, "road_nguyen_trai", true)
	s = d.state()
	d.expect(s.road_sign == NGUYEN_TRAI, "the name \"%s\" shows when the scooter comes onto it (D13): \"%s\"" % [NGUYEN_TRAI, s.road_sign])
	var ok := await d.ride_along(route, turn_at + LET_GO_AT, 30.0, watch, false, 120.0, Callable(), "", true)
	s = d.state()
	d.step("the turn into Nguyễn Trãi: the top %.1f km/h, %d bumps, off the roads at %s, the names %s, the brake used %s" % [
			float(trace.max_kmh), s.bumps - bumps_before, trace.off, trace.names, trace.braked])
	d.expect(ok, "the scooter rides into Nguyễn Trãi with the stick only")
	d.expect(float(trace.max_kmh) >= TOP_KMH - 2.0, "the scooter goes at the top speed on Quang Trung: %.1f km/h" % float(trace.max_kmh))
	d.expect(not trace.braked, "the turn has no brake (D11)")
	d.expect(s.bumps == bumps_before, "the turn into Nguyễn Trãi has no bump (D11): %d" % (s.bumps - bumps_before))
	d.expect(trace.off.is_empty(), "the scooter stays on the roads: %s" % [trace.off])
	d.expect(trace.names.has("Quang Trung") and trace.names.has(NGUYEN_TRAI), "the names of the roads show: %s (D13)" % [trace.names])
	# D10: the rider lets go on a straight road; the engine slows the scooter at 1.5 m/s².
	var v0: float = s.speed_kmh / 3.6
	var frame0 := Engine.get_physics_frames()
	await d.wait_seconds(1.5)
	s = d.state()
	var seconds := (Engine.get_physics_frames() - frame0) / float(Engine.physics_ticks_per_second)
	var slow: float = (v0 - s.speed_kmh / 3.6) / maxf(seconds, 0.001)
	d.step("let go at %.1f km/h: %.1f km/h after %.2f s, %.2f m/s²" % [v0 * 3.6, s.speed_kmh, seconds, slow])
	d.expect(v0 * 3.6 > 10.0 and absf(slow - ScooterMotion.ENGINE_SLOW) <= 0.2,
			"with no stick the engine slows the scooter at 1.5 m/s² (D10): %.2f m/s² from %.1f km/h" % [slow, v0 * 3.6])
	await d.screenshot("let_go_slows")
	d.expect(_overlaps.is_empty(), "the scooter never goes into a solid thing: %s" % [_overlaps])


## True when the floor under the point is the height map of the ground (not a
## road surface of the showcase or a part).
func _on_ground(player: Player, point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3(0, 1.0, 0), point - Vector3(0, 2.0, 0), Layers.FLOOR)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var body := hit.collider as CollisionObject3D
	if body == null:
		return false
	return body.shape_owner_get_shape(body.shape_find_owner(int(hit.shape)), 0) is HeightMapShape3D


## True when a road is at the point or within "margin" of it (the asphalt of
## a junction between the two roads of Quang Trung is between their widths:
## at Nguyễn Trãi it is about 4.4 m wide).
func _near_road(w: VungTau, point: Vector3, margin: float) -> bool:
	for offset: Vector3 in [Vector3.ZERO, Vector3(margin, 0, 0), Vector3(-margin, 0, 0), Vector3(0, 0, margin), Vector3(0, 0, -margin)]:
		if not w.road_at(point + offset).is_empty():
			return true
	return false
