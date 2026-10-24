extends RefCounted
# PT-01 boot_intro. Start at 06:00. The intro shows. Tap "Step outside".
# Bà Tư's greeting shows. Tap "Dạ, chưa ạ". The card anSang is in the
# notebook. The toast shows. Tap "Thanks, Bà Tư". The talk panel shows the
# homestay. Then the other path: "Good morning!" in English.
# phase: --start-time=06:00
# phase: --start-time=06:00 --fresh-save


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	if d.phase == 1:
		await _path_chua(d)
	else:
		await _path_english(d)


func _intro(d: PlaytestDriver) -> void:
	var s := d.state()
	d.expect(s.time == 360, "the game starts at 06:00, not %s" % s.time_text)
	d.expect(s.day == 1, "the game starts on day 1")
	d.expect(s.line == "intro.welcome", "the intro shows, not %s" % s.line)
	d.expect(s.choices == ["choice.step_outside"], "the intro has one choice: %s" % [s.choices])
	await d.screenshot("intro")
	await d.tap_id("choice.step_outside")
	await d.wait_frames(3)
	s = d.state()
	d.expect(s.line == "batu.greet", "Bà Tư's greeting shows, not %s" % s.line)
	d.expect(s.intro_done, "the intro is done")
	d.expect(s.choices == ["choice.chua", "choice.good_morning"], "the greeting has two choices: %s" % [s.choices])
	await d.screenshot("greeting")


func _path_chua(d: PlaytestDriver) -> void:
	await _intro(d)
	await d.tap_id("choice.chua")
	await d.wait_frames(3)
	var s := d.state()
	d.expect(s.line == "batu.reply_chua", "Bà Tư answers \"chưa\", not %s" % s.line)
	d.expect(s.cards == ["anSang"], "the card anSang is in the notebook: %s" % [s.cards])
	d.expect(s.toast_visible, "the toast shows")
	await d.screenshot("reply_chua_toast")
	await d.tap_id("choice.thanks")
	await d.wait_frames(3)
	s = d.state()
	d.expect(s.line == "hem.near" and s.near_spot == "home", "the talk panel shows the homestay: %s %s" % [s.line, s.near_spot])
	await d.screenshot("homestay_panel")
	# The notebook has the card.
	await d.tap_id("topbar.notebook")
	await d.wait_frames(3)
	d.expect(d.state().mode == "notebook", "the notebook opens")
	d.expect(d.find("card.anSang") != null, "the notebook shows the card anSang")
	await d.screenshot("notebook_one_card")
	await d.tap_id("notebook.close")
	await d.wait_frames(3)
	d.expect(d.state().mode == "hem", "the notebook closes")
	# A second visit to Bà Tư does not add the card again.
	await d.bring_into_view("npc.batu")
	await d.tap_id("npc.batu")
	await d.wait_idle()
	d.expect(d.state().line == "batu.greet", "a tap on Bà Tư shows her greeting")
	await d.tap_id("choice.chua")
	await d.wait_frames(3)
	d.expect(d.state().cards == ["anSang"], "the card is in the notebook one time only")
	await d.tap_id("choice.thanks")
	await d.wait_frames(3)


func _path_english(d: PlaytestDriver) -> void:
	await _intro(d)
	await d.tap_id("choice.good_morning")
	await d.wait_frames(3)
	var s := d.state()
	d.expect(s.line == "batu.reply_english", "Bà Tư answers in English, not %s" % s.line)
	d.expect(s.cards == ["anSang"], "the card anSang is in the notebook: %s" % [s.cards])
	d.expect(s.toast_visible, "the toast shows")
	await d.screenshot("reply_english")
	await d.tap_id("choice.okay")
	await d.wait_frames(3)
	s = d.state()
	d.expect(s.line == "hem.near" and s.near_spot == "home", "the talk panel shows the homestay")
	await d.screenshot("homestay_panel")
