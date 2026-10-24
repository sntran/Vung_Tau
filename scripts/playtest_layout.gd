class_name PlaytestLayout
extends RefCounted
## The layout checks for the play tests PT-06 and PT-17.


## Checks the screen and saves a screenshot. Records a failure for each problem:
## a control that is not fully on the screen, a control on the top bar or on
## the center dot, a label that hides lines or cuts its text, button text out
## of its button, and a button lower than 88 px.
static func check(d: PlaytestDriver, shot: String) -> void:
	await d.wait_idle()
	await d.wait_frames(3)
	var s := d.state()
	var view := Rect2(Vector2.ZERO, s.view_size)
	var bar: Rect2 = s.top_bar_rect
	var dot: Vector2 = view.get_center()
	var report := d.ui_report()
	var problems: Array[String] = []
	for item: Dictionary in report:
		var rect: Rect2 = item.rect
		var name: String = item.test_id if item.test_id != "" else item.name
		var area: Rect2 = item.get("scroll_rect", rect)
		if not inside(view, area):
			problems.append("%s is not fully on the screen: %s" % [name, area])
		if item.has("scroll_rect") and (rect.position.x < area.position.x - 0.5 or rect.end.x > area.end.x + 0.5):
			problems.append("%s is wider than its scroll area" % name)
		var visible_rect: Rect2 = rect.intersection(area) if item.has("scroll_rect") else rect
		if not item.path.contains("/TopBar") and visible_rect.size.y > 0.5 and visible_rect.intersects(bar):
			problems.append("%s covers the top bar" % name)
		# In the hẻm, nothing covers the center dot. A sheet covers all of the world.
		if s.mode == "hem" and not item.path.contains("CenterDot") and not item.path.contains("Joystick") \
				and visible_rect.grow(-0.5).has_point(dot):
			problems.append("%s covers the center dot" % name)
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
	d.step("layout %s: %d controls" % [shot, report.size()])
	await d.screenshot(shot)


static func inside(outer: Rect2, inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 0.5 and inner.position.y >= outer.position.y - 0.5 \
			and inner.end.x <= outer.end.x + 0.5 and inner.end.y <= outer.end.y + 0.5


## Starts a drag on each visible button in the hẻm. The drag must not start
## the joystick or turn the view: the button takes the touch.
static func check_buttons_take_touches(d: PlaytestDriver, shot: String) -> void:
	var s := d.state()
	if s.mode != "hem":
		return
	for item: Dictionary in d.ui_report():
		if not item.button or item.test_id == "":
			continue
		var rect: Rect2 = item.rect
		var yaw: float = d.state().yaw
		var start := rect.get_center()
		# Drag down out of the button, so that the release does not press it.
		var end := start + Vector2(0, rect.size.y / 2.0 + 30.0)
		await d.drag(d.to_screen(start), d.to_screen(end), 0.3)
		var after := d.state()
		d.expect(not after.joystick_visible and absf(wrapf(float(after.yaw) - yaw, -180.0, 180.0)) < 0.5,
				"%s: a drag that starts on the button %s starts the joystick or turns the view" % [shot, item.test_id])
		if after.mode != "hem":
			d.fail("%s: a drag on %s opened %s" % [shot, item.test_id, after.mode])
			return
