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
# frames, not by the distance; the longest frame and the count of the frames
# longer than three times the median frame along the ride (R9: the limit comes
# after the first measure), also in out/frames.json.
# sizes: 1280x720
# phase: --world=vung_tau --start=bai_truoc --start-time=17:00 --quality=low
# phase: --world=vung_tau --start=bai_truoc --start-time=17:05 --quality=low --ride

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
	await d.wait_ground(120.0)
	if d.phase == 1:
		await _run_1(d)
	else:
		await _run_2(d)


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
	var clock_start := d.state()
	# The ride: Quang Trung, Hạ Long, the junction, the port.
	var route := _route(d, s.player)
	var length := PlaytestDriver.route_length(route)
	d.step("the route: %.0f m" % length)
	var junction := PlaytestDriver.route_distance(route, _road_points(d, HA_LONG_SOUTH)[0])
	var checker := _check.bind(d)
	var ok := await d.ride_along(route, junction - 25.0, TOP_KMH, checker)
	d.expect(ok, "the scooter rides Quang Trung and Hạ Long to the junction")
	s = d.state()
	await d.screenshot("hai_long_at_speed")
	d.step("at %.1f km/h at %s" % [s.speed_kmh, s.player])
	_lean_max = 0.0
	# In the turn: the screenshot with the lean, where the route turns most.
	var most := junction
	var most_bend := 0.0
	var at := junction - 20.0
	while at < junction + 30.0:
		var bend := PlaytestDriver._route_bend(route, at, at + 5.0)
		if bend > most_bend:
			most_bend = bend
			most = at + 2.5
		at += 1.0
	await d.ride_along(route, most, 20.0, checker)
	s = d.state()
	d.step("in the turn: %.1f km/h, lean %.1f°, steer %.1f°" % [s.speed_kmh, s.lean, s.steer])
	await d.screenshot("turn_lean")
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


func _run_2(d: PlaytestDriver) -> void:
	var s := d.state()
	if not d.expect(s.riding, "with --ride the game starts on the scooter of the start (R8)"):
		return
	await d.screenshot("ride_at_start")
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
	# The curb: to the right, up the edge of the sidewalk of Quang Trung (about 0.16 m).
	s = d.state()
	var here: Vector3 = s.player
	var road_y: float = here.y
	var front := Basis(Vector3.UP, deg_to_rad(s.heading)) * Vector3(0, 0, -1)
	var right := front.cross(Vector3.UP).normalized()
	# To the right until the scooter stands on the sidewalk: 0.1 m over the
	# road next to it (the point of Quang Trung at the same distance along it).
	var rise := func() -> float:
		var at: Vector3 = d.state().player
		return at.y - PlaytestDriver.route_point(road, PlaytestDriver.route_distance(road, at)).y
	var on_sidewalk := func() -> bool: return rise.call() > 0.1
	# This way passes between the lamp poles of the sidewalk.
	var onto := PackedVector3Array([here, here + front * 3.0 + right * 2.0, here + front * 6.0 + right * 8.0])
	var bumps_before: int = s.bumps
	await d.ride_along(onto, PlaytestDriver.route_length(onto) - 0.5, 8.0, checker, false, 30.0, on_sidewalk)
	await d.hold_stick(Vector2(0, 1), 1.5)
	s = d.state()
	road_y = s.player.y - float(rise.call())
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
