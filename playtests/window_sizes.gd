extends RefCounted
# PT-30 window_sizes (plan 0004, R1). At 1280 × 720, 1920 × 1080, 2560 × 1080
# (21:9), and 1920 × 1200 (16:10): the phone, the subtitles, and the center dot
# are fully visible and do not overlap. The window can change size: after a
# change to another shape, the layout is correct again.
# sizes: 1280x720 1920x1080 2560x1080 1920x1200
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
	await d.skip_intro()
	await PlaytestLayout.check(d, "start")
	# A subtitle: Bà Tư speaks.
	await d.talk_to("batu")
	await d.wait_line()
	await _check_overlap(d, "subtitle")
	await d.raise_phone()
	await _check_overlap(d, "subtitle_phone_up")
	await d.open_app("listen")
	await _check_overlap(d, "listen")
	await d.lower_phone()
	# The player changes the size of the window to another shape.
	var size0 := DisplayServer.window_get_size()
	var other := Vector2i(int(size0.y * 1.6), size0.y) if float(size0.x) / size0.y > 1.7 else Vector2i(int(size0.y * 2.37), size0.y)
	DisplayServer.window_set_size(other)
	await d.wait_frames(10)
	d.step("window size %s to %s" % [size0, DisplayServer.window_get_size()])
	await d.raise_phone()
	await _check_overlap(d, "resized_phone_up")
	await d.lower_phone()
	DisplayServer.window_set_size(size0)
	await d.wait_frames(10)
	await PlaytestLayout.check(d, "size_back")


## The layout checks, and the phone, the subtitles, and the center dot do not overlap.
func _check_overlap(d: PlaytestDriver, shot: String) -> void:
	var s := d.state()
	var view := Rect2(Vector2.ZERO, s.view_size)
	var dot: Vector2 = view.get_center()
	var subtitle: Rect2 = s.subtitle_rect
	if s.phone_up:
		var phone: Rect2 = s.phone_rect
		d.expect(PlaytestLayout.inside(view, phone), "%s: the phone is fully visible: %s in %s" % [shot, phone, view])
		d.expect(not phone.has_point(dot), "%s: the phone does not cover the center dot" % shot)
		if subtitle.size != Vector2.ZERO:
			d.expect(not phone.intersects(subtitle), "%s: the subtitles are not under the phone" % shot)
	if subtitle.size != Vector2.ZERO:
		d.expect(PlaytestLayout.inside(view, subtitle), "%s: the subtitles are fully visible: %s" % [shot, subtitle])
		d.expect(not subtitle.has_point(dot), "%s: the subtitles do not cover the center dot" % shot)
	await PlaytestLayout.check(d, shot)
