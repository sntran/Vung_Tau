extends RefCounted
# PT-08 night. Start at 20:30. Check that the lights are on (screenshot).
# Wait for two clack sounds and check that the bubble shows. Tap the hủ tiếu
# gõ cart. Check the line ID.
# phase: --start-time=20:30


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	await d.tap_id("choice.step_outside")
	await d.tap_id("choice.good_morning")
	await d.tap_id("choice.okay")
	await d.wait_idle()
	var s := d.state()
	d.expect(s.lights_on > 0, "at 20:30 the lights are on")
	d.expect(s.lights_in_view <= 8, "not more than 8 dynamic lights in view: %d" % s.lights_in_view)
	await d.screenshot("lights_on")
	# Two clacks, each with the bubble. The clacks come each 4 to 5 seconds.
	var times: Array[int] = []
	for i in 2:
		var count: int = d.state().clack_count
		if not await d.wait_until(func() -> bool: return d.state().clack_count > count, 7.0, "clack %d" % (i + 1)):
			return
		times.append(Time.get_ticks_msec())
		d.expect(d.state().bubble_visible, "the bubble shows with clack %d" % (i + 1))
		await d.screenshot("clack_%d" % (i + 1))
	var interval := (times[1] - times[0]) / 1000.0
	d.expect(interval >= 3.8 and interval <= 5.3, "the clacks are %.2f s apart, not 4 to 5 s" % interval)
	await d.wait_until(func() -> bool: return not d.state().bubble_visible, 3.0, "the bubble hides")
	await d.bring_into_view("spot.go")
	await d.tap_id("spot.go")
	await d.wait_idle()
	s = d.state()
	d.expect(s.line == "spot.go.look", "the hủ tiếu gõ line shows, not %s" % s.line)
	d.expect(s.cards.has("clack"), "the card clack is in the notebook")
	d.expect(s.lights_in_view <= 8, "not more than 8 dynamic lights in view: %d" % s.lights_in_view)
	await d.screenshot("go_cart")
