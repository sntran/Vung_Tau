extends RefCounted
# PT-30 geo_tide. Start at a dry time from R8i, on the beach below Mũi Nghinh
# Phong. Walk the ridge to Hòn Bà with tap to walk. Then start 3 hours after the
# end of the dry time. The ridge is under water, and the player cannot walk on
# it. Take screenshots of the same view at low tide and high tide.
# Day 17 of the game is 2026-12-24 (day 1 is 2026-12-08, data/calendar.json),
# the 16th day of the lunar month. tools/geo/tide.py gives a dry time from
# 05:35 to 09:15 on that day. The test reads the dry time from
# data/geo/build/tide.json, so a new tide build that moves it fails the test.
# sizes: 1280x720
# phase: --world=vung_tau --day=17 --start-time=06:30
# phase: --world=vung_tau --day=17 --start-time=12:15

const STEP := 12.0
const HOURS_AFTER := 3.0


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts"):
		return
	if not d.expect(w.ridge_points.size() >= 2, "the data has the Hòn Bà ridge"):
		return
	var route := _route(w)
	var dry := _dry_time(d.phase == 1)
	if d.phase == 1:
		d.expect(not dry.is_empty(), "tide.json has a dry time at %s" % _now_text())
		d.expect(w.is_ridge_dry(), "the ridge is dry at low tide: the sea is at %+.2f m" % w.sea_level)
	else:
		d.expect(not dry.is_empty(), "tide.json has a dry time that ends %d hours before %s" % [HOURS_AFTER, _now_text()])
		d.expect(not w.is_ridge_dry(), "the ridge is under water at high tide: the sea is at %+.2f m" % w.sea_level)
	# The same view at low tide and at high tide.
	var islet := route[route.size() - 1]
	var back := (route[0] - islet).normalized()
	var eye := route[0] + back * 25.0 + Vector3(0, 8.0, 0)
	await d.fly_to(eye, islet)
	await d.wait_ground(60.0)
	await d.wait_frames(5)
	await d.screenshot("low_tide" if d.phase == 1 else "high_tide")
	d.fly_end()
	var start := _start_point(w, route[0], back)
	await d.start_at(start, rad_to_deg(atan2(-(islet.x - start.x), -(islet.z - start.z))))
	# At each frame, the player must not stand on the ridge under water.
	var wet := [0]
	var check := func() -> void:
		var s := d.state()
		if bool(s.on_ridge) and float(s.ground) <= w.ridge_top + VungTau.RIDGE_ABOVE and not bool(s.ridge_dry):
			wet[0] += 1
	d.main().get_tree().process_frame.connect(check)
	d.set_time_scale(3.0)
	var length := PlaytestDriver._length(route)
	if d.phase == 1:
		await _tap_walk(d, route, length)
		var walked := PlaytestDriver.route_distance(route, d.state().player)
		d.expect(walked >= length - 6.0, "the player walks the ridge to Hòn Bà: %.0f m of %.0f m" % [walked, length])
		d.expect(w.is_ridge_dry(), "the ridge is still dry at the end of the walk: the sea is at %+.2f m" % w.sea_level)
		await d.screenshot("at_hon_ba")
	else:
		var target := PlaytestDriver.route_point(route, minf(40.0, length))
		await d.look_at_point(target + Vector3(0, 0.05, 0), 6.0, 15.0)
		await d.hold_stick(Vector2(0, -1), 6.0)
		await d.wait_idle()
		var walked := PlaytestDriver.route_distance(route, d.state().player)
		d.expect(walked < length / 2.0, "the player cannot walk on the ridge at high tide: %.0f m of %.0f m" % [walked, length])
		await d.screenshot("stopped_at_high_tide")
	d.set_time_scale(1.0)
	d.main().get_tree().process_frame.disconnect(check)
	d.expect(wet[0] == 0, "the player never stands on the ridge under water: %d frames" % wet[0])


## The line of the ridge from the beach to the islet, with the ground height.
static func _route(w: VungTau) -> PackedVector3Array:
	var points := Array(w.ridge_points)
	var hon_ba: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/geo/hon_ba.json"))
	var islet := w.data.projection.to_game(float(hon_ba.islet.lon), float(hon_ba.islet.lat))
	if points[0].distance_to(islet) < points[points.size() - 1].distance_to(islet):
		points.reverse()
	var route := PackedVector3Array()
	for p: Vector2 in points:
		route.append(Vector3(p.x, w.ground_height(p.x, p.y), p.y))
	return route


## A point where the player can stand, on the line from the beach end of the
## ridge back to the land.
static func _start_point(w: VungTau, beach_end: Vector3, back: Vector3) -> Vector3:
	for i in 40:
		var point := beach_end + back * float(i)
		if w.can_stand(point) and not w.is_on_ridge(point):
			return point
	return beach_end


## Taps the ground along the route, one step at a time, to the end.
func _tap_walk(d: PlaytestDriver, route: PackedVector3Array, length: float) -> void:
	var taps := 0
	while true:
		var here := PlaytestDriver.route_distance(route, d.state().player)
		if here >= length - 2.0:
			break
		var target := PlaytestDriver.route_point(route, minf(here + STEP, length - 1.0))
		var view := d.world_to_view(target + Vector3(0, 0.05, 0))
		var camera: Camera3D = d.main().player.camera
		if camera.is_position_behind(target) or not Rect2(Vector2(40, 140), d.state().view_size - Vector2(80, 180)).has_point(view):
			await d.look_at_point(target + Vector3(0, 0.05, 0), 6.0, 15.0)
		await d.tap_floor(target + Vector3(0, 0.05, 0))
		taps += 1
		await d.wait_until(func() -> bool: return not d.state().walking, 20.0, "the tap walk ends")
		var after := PlaytestDriver.route_distance(route, d.state().player)
		if after < here + 0.5:
			d.fail("the tap walk stops at %.0f m of the ridge" % after)
			return
		if taps > 60:
			d.fail("too many taps")
			return


## The time of the game as text: "2026-12-24 06:30".
static func _now_text() -> String:
	var date := GameCalendar.date_of(GameState.day)
	return "%04d-%02d-%02d %s" % [date.year, date.month, date.day, GameClock.format_time(GameState.minutes)]


## The dry time of tide.json at the time of the game (low tide), or the dry
## time that ended HOURS_AFTER hours before it (high tide). {} if none.
static func _dry_time(low: bool) -> Dictionary:
	var tide: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TideModel.PATH))
	var now := GameCalendar.unix_time(GameState.day, GameState.minutes)
	for dry: Dictionary in tide.get("dry_times", []):
		var start := Time.get_unix_time_from_datetime_string(str(dry.start).substr(0, 16)) - GameCalendar.TIME_ZONE_S
		var end := Time.get_unix_time_from_datetime_string(str(dry.end).substr(0, 16)) - GameCalendar.TIME_ZONE_S
		if low and start <= now and now <= end:
			return dry
		if not low and absf(now - end - HOURS_AFTER * 3600.0) <= 60.0 * 60.0:
			return dry
	return {}
