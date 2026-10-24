extends RefCounted
# PT-06 layout. At 720×1280, 1080×2400, and 1280×720: open each sheet and
# each kind of talk panel. Use ui_report(). Check that each control is fully
# on the screen, no control covers the top bar, no label hides lines, and
# each button is at least 88 px high at the base width. Check that the
# player is visible when the talk panel is open. Check that the text of each
# button is inside the button.
# sizes: 720x1280 1080x2400 1280x720
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	await _check(d, "intro")
	await d.tap_id("choice.step_outside")
	await _check(d, "greeting")
	await d.tap_id("choice.chua")
	await _check(d, "reply_with_toast")
	await d.tap_id("choice.thanks")
	await _check(d, "near_homestay")
	await d.tap_id("choice.look")
	await _check(d, "homestay_three_choices")
	await d.tap_id("choice.go_out")
	await d.wait_idle()
	await d.tap_id("spot.pho")
	await _check(d, "pho_speaker_phrases_hint")
	await d.tap_id("choice.okay")
	await d.wait_idle()
	await d.tap_id("topbar.notebook")
	await _check(d, "notebook")
	await _scroll_notebook(d)
	await d.tap_id("notebook.close")
	await d.tap_id("topbar.clock")
	await _check(d, "clock_sheet")
	await d.tap_id("clock.wait_1100")
	await d.wait_idle()
	await d.bring_into_view("spot.banhkhot")
	await d.tap_id("spot.banhkhot")
	await _check(d, "banhkhot_long_text")
	await d.tap_id("choice.okay")
	await d.wait_idle()
	# Walk to the beach road: the camera turns to the sea.
	await d.walk_toward(d.main().hem.end_x + 3.0)
	await d.bring_into_view("spot.beach")
	await d.tap_id("spot.beach")
	await _check(d, "beach")
	await d.tap_id("choice.okay")
	await d.wait_idle()
	# Wait until late: the late panel.
	for choice: String in ["clock.wait_2030", "clock.wait_hour", "clock.wait_hour", "clock.wait_hour"]:
		await d.tap_id("topbar.clock")
		await d.wait_frames(3)
		await d.tap_id(choice)
		await d.wait_frames(3)
	await _check(d, "late")
	await d.tap_id("choice.go_home_sleep")
	await _check(d, "morning")


## Opens the notebook with more cards known. Checks the layout after a scroll.
func _scroll_notebook(d: PlaytestDriver) -> void:
	var sheet: NotebookSheet = d.main().notebook_sheet
	var scroll := sheet.scroll
	d.expect(scroll.get_v_scroll_bar().max_value > scroll.size.y, "the notebook has more cards than the screen shows, so it scrolls")


func _check(d: PlaytestDriver, shot: String) -> void:
	await d.wait_idle()
	await d.wait_frames(3)
	var s := d.state()
	var view := Rect2(Vector2.ZERO, s.view_size)
	var bar: Rect2 = s.top_bar_rect
	var report := d.ui_report()
	var problems: Array[String] = []
	for item: Dictionary in report:
		var rect: Rect2 = item.rect
		var name: String = item.test_id if item.test_id != "" else item.name
		var area: Rect2 = item.get("scroll_rect", rect)
		if not _inside(view, area):
			problems.append("%s is not fully on the screen: %s" % [name, area])
		if item.has("scroll_rect") and (rect.position.x < area.position.x - 0.5 or rect.end.x > area.end.x + 0.5):
			problems.append("%s is wider than its scroll area" % name)
		if not item.path.contains("/TopBar") and rect.intersects(bar) and rect.size.x > 0 and rect.size.y > 0:
			# The scroll area clips its children, so only the visible part counts.
			var visible_rect: Rect2 = rect.intersection(area) if item.has("scroll_rect") else rect
			if visible_rect.intersects(bar) and visible_rect.size.y > 0.5:
				problems.append("%s covers the top bar" % name)
		if item.hidden_lines:
			problems.append("%s hides lines (%s of %s show)" % [name, item.get("visible_lines"), item.get("lines")])
		if item.get("outside_button", false):
			problems.append("the text %s is outside its button" % name)
		if item.trimmed:
			problems.append("%s cuts its text" % name)
		if item.button and rect.size.y < UiTheme.BUTTON_MIN_HEIGHT - 0.5:
			problems.append("the button %s is %.1f px high" % [name, rect.size.y])
	for problem in problems:
		d.fail("%s: %s" % [shot, problem])
	if s.mode == "hem":
		var player: Rect2 = s.player_screen_rect
		var free: Rect2 = s.free_rect
		d.expect(_inside(free, player), "%s: the player %s is not in the free part of the screen %s" % [shot, player, free])
		d.expect(not player.intersects(s.panel_rect), "%s: the talk panel covers the player" % shot)
	d.step("layout %s: %d controls" % [shot, report.size()])
	await d.screenshot(shot)


func _inside(outer: Rect2, inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 0.5 and inner.position.y >= outer.position.y - 0.5 \
			and inner.end.x <= outer.end.x + 0.5 and inner.end.y <= outer.end.y + 0.5
