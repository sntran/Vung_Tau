extends RefCounted
# PT-06 layout. Open each sheet and each kind of talk panel. Use ui_report().
# Check that each control is fully on the screen, no control covers the top
# bar or the center dot, no label hides lines, the text of each button is in
# the button, and each button is at least 88 px high at the 720 px base height.
# The scenario has 2 runs, so that each run is shorter than 180 s at
# 2400×1080 under lavapipe. The second run starts from the save file of the
# first run.
# phase: --start-time=06:00
# phase:


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	if d.phase == 1:
		await _first_run(d)
	else:
		await _second_run(d)


func _first_run(d: PlaytestDriver) -> void:
	await PlaytestLayout.check(d, "intro")
	await d.tap_id("choice.step_outside")
	await PlaytestLayout.check(d, "greeting")
	await d.tap_id("choice.chua")
	await PlaytestLayout.check(d, "reply_with_toast")
	await d.tap_id("choice.thanks")
	await PlaytestLayout.check(d, "near_homestay")
	await d.tap_id("choice.look")
	await PlaytestLayout.check(d, "homestay_three_choices")
	await d.tap_id("choice.go_out")
	await d.bring_into_view("spot.pho")
	await d.tap_id("spot.pho")
	await PlaytestLayout.check(d, "pho_speaker_phrases_hint")
	await d.tap_id("choice.okay")
	await d.tap_id("topbar.notebook")
	await PlaytestLayout.check(d, "notebook")
	var scroll: ScrollContainer = d.main().notebook_sheet.scroll
	d.expect(scroll.get_v_scroll_bar().max_value > scroll.size.y, "the notebook has more cards than the screen shows, so it scrolls")
	await d.tap_id("notebook.close")
	await d.tap_id("topbar.settings")
	await PlaytestLayout.check(d, "settings")
	await d.tap_id("settings.close")


func _second_run(d: PlaytestDriver) -> void:
	await d.tap_id("topbar.clock")
	await PlaytestLayout.check(d, "clock_sheet")
	await d.tap_id("clock.wait_1100")
	await d.bring_into_view("spot.banhkhot")
	await d.tap_id("spot.banhkhot")
	await PlaytestLayout.check(d, "banhkhot_long_text")
	await d.tap_id("choice.okay")
	await d.walk_toward(d.main().hem.end_x + 3.0, 0.0)
	await d.bring_into_view("spot.beach")
	await d.tap_id("spot.beach")
	await PlaytestLayout.check(d, "beach")
	await d.tap_id("choice.okay")
	for choice: String in ["clock.wait_2030", "clock.wait_hour", "clock.wait_hour", "clock.wait_hour"]:
		await d.tap_id("topbar.clock")
		await d.wait_frames(3)
		await d.tap_id(choice)
		await d.wait_frames(3)
	await PlaytestLayout.check(d, "late")
	await d.tap_id("choice.go_home_sleep")
	await PlaytestLayout.check(d, "morning")
