extends RefCounted
# PT-06 layout. Show each app of the phone (plan 0003), a subtitle, and a
# notification. Use ui_report(). Check that each control is fully on the
# screen, no control covers the center dot, the subtitles are clear of the
# phone and the joystick zone, no label hides lines, the text of each button
# is in the button, and each button is at least 88 px high at the 720 px base
# height. The scenario has 2 runs, so that each run is shorter than 180 s at
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
	await PlaytestLayout.check(d, "start")
	await d.raise_phone()
	await PlaytestLayout.check(d, "phone_home")
	await d.open_app("messages")
	await PlaytestLayout.check(d, "messages")
	await d.open_app("listen")
	await d.tap_phone_id("listen.toggle")
	await d.lower_phone()
	await d.talk_to("batu")
	await d.wait_frames(3)
	await PlaytestLayout.check(d, "subtitle")
	await d.open_app("listen")
	await d.wait_answer()
	await d.wait_frames(3)
	await PlaytestLayout.check(d, "phrasebook_and_subtitle")
	await d.tap_phone_id("reply.chua.say")
	await PlaytestLayout.check(d, "say_it_with_tones")
	await d.tap_phone_id("said.done")
	await d.wait_line("batu")
	await d.wait_frames(3)
	await PlaytestLayout.check(d, "answer_notification")
	await d.wait_quiet()
	await d.open_app("notebook")
	await PlaytestLayout.check(d, "notebook")
	var scroll: ScrollContainer = d.main().phone.apps.notebook
	d.expect(scroll.get_v_scroll_bar().max_value > scroll.size.y, "the Sổ tay has more cards than the screen shows, so it scrolls")
	await d.open_app("settings")
	await PlaytestLayout.check(d, "settings")


func _second_run(d: PlaytestDriver) -> void:
	await d.open_app("clock")
	await PlaytestLayout.check(d, "clock")
	await d.tap_phone_id("clock.wait_1100")
	await d.lower_phone()
	await d.bring_into_view("spot.banhkhot")
	await d.tap_id("spot.banhkhot")
	await d.wait_idle()
	await d.open_app("lens")
	await d.look_at_id("spot.banhkhot")
	await PlaytestLayout.check(d, "lens_long_text")
	await d.lower_phone()
	await d.walk_toward(d.main().hem.end_x + 3.0, 0.0)
	await d.open_app("lens")
	await d.look_at_id("spot.beach")
	await PlaytestLayout.check(d, "lens_beach")
	await d.open_app("listen")
	await PlaytestLayout.check(d, "listen_transcript")
