extends RefCounted
# PT-08 night. Start at 20:30. Check that the lights are on (screenshot).
# Wait for two clack sounds and check that the caption "[lóc cóc]" shows
# (plan 0003, R14). Point the Lens app at the hủ tiếu gõ cart. Check the
# description.
# phase: --start-time=20:30


func run(d: PlaytestDriver) -> void:
	await d.skip_intro()
	var s := d.state()
	d.expect(s.lights_on > 0, "at 20:30 the lights are on")
	d.expect(s.lights_in_view <= 8, "not more than 8 dynamic lights in view: %d" % s.lights_in_view)
	await d.screenshot("lights_on")
	# Two clacks, each with the caption. The clacks come each 4 to 5 seconds.
	# The times are game time. At a low frame rate, the game time is slower
	# than the real time.
	var times: Array[float] = []
	for i in 2:
		var count: int = d.state().clack_count
		if not await d.wait_until(func() -> bool: return d.state().clack_count > count, 7.0, "clack %d" % (i + 1)):
			return
		times.append(float(d.state().clack_time))
		await d.wait_frames(2)
		var caption: Dictionary = d.subtitle()
		d.expect(caption.get("caption", false) and caption.lines[0] == "[lóc cóc]",
				"the caption shows with clack %d: %s" % [i + 1, caption])
		await d.screenshot("clack_%d" % (i + 1))
	var interval := times[1] - times[0]
	d.expect(interval >= 3.8 and interval <= 5.3, "the clacks are %.2f s apart, not 4 to 5 s" % interval)
	await d.bring_into_view("spot.go")
	await d.tap_id("spot.go")
	await d.wait_idle()
	await d.open_app("lens")
	await d.look_at_id("spot.go")
	await d.wait_frames(3)
	s = d.state()
	d.expect(d.main().lens_card().get("line", "") == "spot.go.look", "the Lens shows the hủ tiếu gõ: %s" % d.main().lens_card())
	d.expect(s.cards.has("clack"), "the card clack is in the Sổ tay")
	d.expect(s.lights_in_view <= 8, "not more than 8 dynamic lights in view: %d" % s.lights_in_view)
	await d.screenshot("go_cart")
