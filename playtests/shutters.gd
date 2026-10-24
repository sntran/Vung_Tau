extends RefCounted
# PT-29 shutters (plan 0004, R7). At 04:40, 05:40, 10:40, and 12:10, the
# shutter of Phở Cô Sáu is half, open, half, and closed. The shutter does not
# go through the sign or the step. In run 1, the Clock app moves the time to
# 05:40, and the shutter rolls up with a short animation.
# phase: --start-time=04:40
# phase: --start-time=05:40 --fresh-save
# phase: --start-time=10:40 --fresh-save
# phase: --start-time=12:10 --fresh-save

const EXPECTED := {1: "half", 2: "open", 3: "half", 4: "closed"}


func run(d: PlaytestDriver) -> void:
	await d.skip_intro()
	var hem: Hem = d.main().hem
	var house: TubeHouse = hem.houses["pho_co_sau"]
	await _check(d, house, EXPECTED[d.phase])
	if d.phase != 1:
		return
	# Wait one hour: the shop opens, and the shutter rolls up.
	await d.open_app("clock")
	var shown: Array[float] = []
	var sample := func() -> void: shown.append(house.shutter_shown())
	d.main().get_tree().process_frame.connect(sample)
	await d.tap_phone_id("clock.wait_hour")
	await d.lower_phone()
	await d.wait_seconds(TubeHouse.SHUTTER_SECONDS + 0.5)
	d.main().get_tree().process_frame.disconnect(sample)
	var between := shown.filter(func(h: float) -> bool: return h > 0.1 and h < TubeHouse.HALF_HEIGHT - 0.1)
	d.expect(not between.is_empty(), "the shutter rolls up with an animation: %d frames between half and open" % between.size())
	await _check(d, house, "open")


func _check(d: PlaytestDriver, house: TubeHouse, expected: String) -> void:
	var s := d.state()
	d.expect(s.shutters.pho == expected, "at %s the shutter of Phở Cô Sáu is %s, not %s" % [s.time_text, s.shutters.pho, expected])
	var box := house.shutter_box()
	for part: String in ["sign", "step", "awning"]:
		if house.part_boxes.has(part) and box.size != Vector3.ZERO:
			var other: AABB = house.part_boxes[part]
			d.expect(not box.grow(-0.001).intersects(other.grow(-0.001)),
					"at %s the shutter %s does not go through the %s %s" % [s.time_text, box, part, other])
	await d.look_at_point(house.global_position + Vector3(0, 1.6, 0), 4.0)
	await d.screenshot("shutter_%s" % expected)
