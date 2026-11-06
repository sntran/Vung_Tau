extends RefCounted
# PT-51 change_passport (plan 0007, R5). Send the passport of a woman of 25.
# Talk with Cô Sáu: she says "con". While she waits for an answer, open the
# Settings app, "Change passport details", and change the year of birth so
# that the traveler is 50. Answer with Play: the reply and her next line use
# the new words ("Dạ, em cảm ơn chị", then "em"). No error.
# sizes: 1280x720
# phase: --fresh-save --start-time=07:00


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	if not await d.set_passport("female", "1993-06-15"):
		return
	await d.lower_phone()
	var line := await d.talk_to("cosau")
	d.expect(line == "cosau.open", "Cô Sáu says the line of the open shop: %s" % line)
	var before := Content.spoken(line).vi
	d.expect(before.contains(" con"), "for a woman of 25, Cô Sáu says \"con\": %s" % before)
	if not await d.wait_answer():
		return
	await d.open_app("settings")
	await d.tap_phone_id("settings.passport")
	d.expect(d.main().phone.app == "passport", "\"Change passport details\" opens the Passport app: %s" % d.main().phone.app)
	if not await d.set_passport("female", "1968-06-15", false):
		return
	d.expect(GameState.traveler() == {"gender": "female", "age": 50}, "the change takes effect at once: %s" % [GameState.traveler()])
	await d.screenshot("changed")
	d.expect(await d.answer("cam_on", "play"), "the reply is in the phrasebook")
	var stream: AudioStream = d.main().phone_voice.stream
	var playing := stream.resource_path.get_file().get_basename() if stream else ""
	d.expect(playing == "reply.cosau.open.cam_on@chi-em", "the phone plays \"Dạ, em cảm ơn chị\": %s" % playing)
	var next := await d.wait_line("cosau", 20.0, false)
	await d.wait_frames(3)
	var shown := " ".join(d.subtitle().get("lines", []))
	d.expect(next == "cosau.thanks" and shown.contains("em"), "Cô Sáu answers with the new words: %s, %s" % [next, shown])
	d.expect(d.playing_clip("cosau") == "cosau.thanks@em-chi", "the voice is the clip of the new words: %s" % d.playing_clip("cosau"))
	await d.screenshot("answer")
	await d.wait_quiet()
