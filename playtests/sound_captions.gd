extends RefCounted
# PT-24 sound_captions (plan 0003). At 20:30, the hủ tiếu gõ clack plays, and
# the caption "[lóc cóc]" shows. In the afternoon, the TV upstairs at Phở Cô
# Sáu has the caption "[a TV upstairs]".
# sizes: 1280x720 2400x1080
# phase: --start-time=20:30
# phase: --start-time=14:00 --fresh-save


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	if d.phase == 1:
		var count: int = d.state().clack_count
		d.expect(await d.wait_until(func() -> bool: return d.state().clack_count > count, 8.0, "a clack"), "the clack plays")
		await d.wait_frames(2)
		var caption := d.subtitle()
		d.expect(caption.get("caption", false) and caption.get("lines", [""])[0] == "[lóc cóc]",
				"the caption \"[lóc cóc]\" shows: %s" % [caption])
		await d.screenshot("clack_caption")
	else:
		d.expect(d.state().tv_on, "the TV upstairs is on after the phở shop closes")
		await d.walk_toward(d.main().hem.stand_points["pho"].x, 0.0)
		d.expect(await d.wait_until(func() -> bool: return d.subtitle().get("lines", [""])[0] == "[a TV upstairs]",
				10.0, "the TV caption"), "the caption \"[a TV upstairs]\" shows")
		await d.screenshot("tv_caption")
