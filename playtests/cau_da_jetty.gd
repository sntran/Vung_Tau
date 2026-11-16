extends RefCounted
# PT-62 cau_da_jetty (plan 0008, R6, R7, Q4). Walk the jetty of Cầu Đá from the
# shore to its end and back, with the joystick. Checks: the deck goes on to
# the shore, the player comes to the end, and comes back; the player does not fall
# from the deck (the height stays at the deck, and the player stays inside its
# width). Screenshots at the start, at the end, and back. The walk of about
# 350 m takes more than the time limit of a run, so each way is in two phases:
# 1 and 2 go out to the end, 3 and 4 come back to the shore.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.places != null and not w.places.jetty.is_empty(), "the jetty of Cầu Đá"):
		return
	var jetty: Dictionary = w.places.jetty
	var line: PackedVector3Array = jetty.line
	var deck := float(jetty.deck)
	var width := float(jetty.width)
	var length := PlaytestDriver._length(line)
	# The part of the line at the deck height (the part over the sea).
	var deck_length := 0.0
	for i in line.size() - 1:
		if absf(line[i].y - deck) < 0.01 and absf(line[i + 1].y - deck) < 0.01:
			deck_length += Vector2(line[i + 1].x - line[i].x, line[i + 1].z - line[i].z).length()
	d.step("the jetty: %.0f m long, %.1f m wide, the deck at %.2f m" % [length, width, deck])
	var route := line.duplicate()
	if d.phase >= 3:
		route.reverse()
	d.expect(bool(jetty.get("shore", false)), "the jetty goes on to the shore (Q4)")
	var half := length / 2.0
	var from := 1.0 if d.phase % 2 == 1 else half
	var to := half if d.phase % 2 == 1 else length - 2.0
	var start := PlaytestDriver.route_point(route, from)
	var ahead := PlaytestDriver.route_point(route, from + 4.0)
	await d.start_at(start, rad_to_deg(atan2(-(ahead.x - start.x), -(ahead.z - start.z))))
	await d.screenshot("start_%d" % d.phase)
	var low := {"y": INF, "off": 0.0}
	var check := func() -> void:
		var p: Vector3 = d.state().player
		# On the part over the sea, the player stays on the deck.
		var at := PlaytestDriver.route_distance(line, p)
		if at > PlaytestDriver._length(line) - deck_length:
			low.y = minf(low.y, p.y)
		var off := INF
		for i in line.size() - 1:
			off = minf(off, Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(line[i].x, line[i].z),
					Vector2(line[i + 1].x, line[i + 1].z)).distance_to(Vector2(p.x, p.z)))
		low.off = maxf(low.off, off)
	var walked := await d.stick_along(route, to, check)
	await d.screenshot("end_%d" % d.phase)
	d.step("run %d: the lowest point on the deck %.2f m, at most %.2f m from the middle line" % [d.phase, low.y, low.off])
	d.expect(walked, "run %d: the player walks from %.0f m to %.0f m" % [d.phase, from, to])
	d.expect(low.y >= deck - 0.3, "run %d: the player does not fall from the deck (%.2f m, the deck %.2f m)" % [d.phase, low.y, deck])
	d.expect(low.off <= width / 2.0, "run %d: the player stays on the deck (%.2f m from the middle)" % [d.phase, low.off])
