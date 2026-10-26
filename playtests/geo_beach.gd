extends RefCounted
# PT-35 geo_beach. Walk from the road across the sand to the water. The player
# stops at the 0.5 m depth and the message shows. The depth is from the sea
# level of the tide at that time (R13).
# The sea floor comes from public data (R8g, Q14). Each run checks the water
# depth at 100 m and 250 m from the sand of the main beach, on the line of
# data/geo/build/world.json (sea_floor.bai_truoc_profile): the ground of the
# game has the height of the data there, and the depth is the sea level of
# the tide minus that height. Run 1 is at the high tide of day 1 (15:30), and
# run 2 at the low tide (08:30), with a screenshot from the sand at each tide.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=15:30
# phase: --world=vung_tau --start-time=08:30


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts"):
		return
	await d.wait_ground()
	var beach := w.data.landmark("bai_truoc")
	if not d.expect(not beach.is_empty(), "the data has Bãi Trước"):
		return
	if d.phase == 2:
		await _check_depths(d, w)
		return
	var start: Vector3 = d.state().player
	d.expect(not str(d.state().road_name).is_empty(), "the player starts on a road: %s" % d.state().road_name)
	await d.screenshot("road")
	# From the road to the center of the beach, then on in the same direction.
	var center := Vector3(beach.position[0], 0.0, beach.position[1])
	var direction := Vector3(center.x - start.x, 0.0, center.z - start.z).normalized()
	var route := PackedVector3Array([start, start + direction * 400.0])
	d.set_time_scale(3.0)
	var sand := [false]
	var message := [false]
	var water := Content.ui_text("water_too_deep")
	var check := func() -> void:
		var s := d.state()
		if float(s.ground) < 2.0 and str(s.road_name).is_empty():
			sand[0] = true
		if s.subtitle.get("lines", [""])[0] == water:
			message[0] = true
	await d.stick_along(route, 400.0, check, 15.0, true)
	d.set_time_scale(1.0)
	var s := d.state()
	d.expect(sand[0], "the player walks on the sand")
	var depth: float = float(s.sea_level) - float(s.ground)
	d.expect(depth > 0.3 and depth <= VungTau.MAX_WATER_DEPTH + 0.02,
			"the player stops at the 0.5 m depth: the water is %.2f m deep" % depth)
	d.expect(message[0], "the message \"%s\" shows when the water stops the player" % water)
	# More joystick into the sea does not move the player into deeper water, and
	# the message shows again.
	var before: Vector3 = s.player
	await d.hold_stick(Vector2(0, -1), 1.5)
	s = d.state()
	d.expect(s.subtitle.get("lines", [""])[0] == water, "the message shows again: %s" % [s.subtitle])
	await d.screenshot("water_too_deep")
	await d.wait_idle()
	var after: Vector3 = d.state().player
	d.expect(float(d.state().sea_level) - float(d.state().ground) <= VungTau.MAX_WATER_DEPTH + 0.02,
			"the player does not go into deeper water")
	d.expect(Vector2(after.x - before.x, after.z - before.z).length() < 1.0, "the player stays at the edge")
	# The player can walk back to the beach.
	await d.look_at_point(Vector3(start.x, after.y + Player.EYE_HEIGHT, start.z), 5.0)
	await d.hold_stick(Vector2(0, -1), 3.0)
	await d.wait_idle()
	d.expect(float(d.state().ground) > float(s.ground) + 0.1, "the player walks back out of the water: the ground is %+.2f m, it was %+.2f m (the player moved %.1f m)" % [
			float(d.state().ground), float(s.ground), Vector2(d.state().player.x - after.x, d.state().player.z - after.z).length()])
	await d.screenshot("back_on_the_beach")
	await _check_depths(d, w)


## The water depth at 100 m and 250 m from the sand of the main beach (R8g):
## the ground of the game has the height of the data, and the depth follows
## the tide.
func _check_depths(d: PlaytestDriver, w: VungTau) -> void:
	var floor_data: Dictionary = w.data.world.get("sea_floor", {})
	var line: Dictionary = floor_data.get("bai_truoc_profile", {})
	if not d.expect(not line.is_empty(), "world.json has the line of the sea floor in front of Bãi Trước"):
		return
	var start := Vector2(line.start[0], line.start[1])
	var direction := Vector2(line.direction[0], line.direction[1]).normalized()
	var tide := "high tide" if d.phase == 1 else "low tide"
	for distance: float in floor_data.get("check_distances_m", [100.0, 250.0]):
		var expected := _height_on_line(line.points, distance)
		var at := start + direction * distance
		var ground := w.ground_height(at.x, at.y)
		d.expect(absf(ground - expected) < 0.2, "%.0f m from the sand, the sea floor is at %+.2f m, the data says %+.2f m" % [
				distance, ground, expected])
		var depth := maxf(w.sea_level - ground, 0.0)
		d.step("%s (sea %+.2f m): the water is %.2f m deep at %.0f m from the sand (the data: %.2f m)" % [
				tide, w.sea_level, depth, distance, maxf(w.sea_level - expected, 0.0)])
		d.expect(absf(depth - maxf(w.sea_level - expected, 0.0)) < 0.2, "the depth at %.0f m follows the tide and the data" % distance)
	var eye := Vector3(start.x, 0.0, start.y) - Vector3(direction.x, 0.0, direction.y) * 10.0
	eye.y = w.ground_height(eye.x, eye.z) + Player.EYE_HEIGHT
	var target := Vector3(start.x, 0.0, start.y) + Vector3(direction.x, 0.0, direction.y) * 250.0
	target.y = w.sea_level
	await d.fly_to(eye, target)
	await d.wait_ground(60.0)
	await d.wait_frames(5)
	await d.screenshot("sea_floor_" + tide.replace(" ", "_"))
	d.fly_end()


static func _height_on_line(points: Array, distance: float) -> float:
	for i in points.size() - 1:
		var a: Array = points[i]
		var b: Array = points[i + 1]
		if distance >= float(a[0]) and distance <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (distance - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001))
	return float(points[points.size() - 1][1])
