extends RefCounted
# PT-18 talk_listen (plan 0003). Start at 06:00. The first message from cô
# Nga arrives. Go to Bà Tư and talk with the phone down. Her audio plays, and
# the Vietnamese subtitle shows. Raise the phone, open Listen. The transcript
# is empty. Choose "Dạ, bà nói lại được không ạ?". She says the line again.
# Turn on Listen, and ask again. The transcript shows the line in Vietnamese
# and English. Answer with Play, then on a second visit with I'll say it.
# Check the two different answers.
# sizes: 1280x720 2400x1080
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	var s := d.state()
	d.expect(s.messages.has("welcome") and s.phone_dot, "the first message from cô Nga arrives: %s" % [s.messages])
	var line := await d.talk_to("batu")
	d.expect(line == "batu.greet", "Bà Tư greets the player, not \"%s\"" % line)
	d.expect(d.audio_playing("batu"), "her audio plays")
	await d.wait_frames(2)
	s = d.state()
	d.expect(not s.phone_up, "the phone is down")
	d.expect(s.subtitle.get("line_id", "") == "batu.greet" and s.subtitle.get("speaker", "") == "Bà Tư",
			"the Vietnamese subtitle shows: %s" % [s.subtitle])
	var vi: String = Content.line("batu.greet").vi
	d.expect(" ".join(s.subtitle.get("lines", [])).contains(vi.substr(0, 10)), "the subtitle is in Vietnamese: %s" % [s.subtitle])
	await d.screenshot("subtitle")
	await d.open_app("listen")
	d.expect(d.transcript().is_empty(), "the transcript is empty: Listen was off (R20)")
	await d.wait_answer()
	d.expect(d.find("reply.say_again") != null, "the phrasebook has \"Dạ, bà nói lại được không ạ?\"")
	d.expect(Content.say_again("batu").vi == "Dạ, bà nói lại được không ạ?", "the form of address is \"bà\" for Bà Tư")
	await d.answer("say_again", "play")
	line = await d.wait_line("batu")
	d.expect(line == "batu.greet", "she says the line again, not \"%s\"" % line)
	d.expect(d.transcript().is_empty(), "the line is not in the transcript: Listen is off")
	await d.wait_answer()
	await d.tap_phone_id("listen.toggle")
	d.expect(d.state().listen_on, "Listen is on")
	await d.answer("say_again", "play")
	line = await d.wait_line("batu")
	await d.wait_answer()
	var transcript := d.transcript()
	d.expect(transcript.size() == 1 and transcript[0].vi == vi and transcript[0].en == Content.line("batu.greet").en
			and transcript[0].speaker == "Bà Tư", "the transcript shows the line in Vietnamese and English: %s" % [transcript])
	await d.screenshot("transcript")
	await d.answer("chua", "play")
	var first := await d.wait_line("batu")
	d.expect(first == "batu.reply_chua", "the answer to Play is \"batu.reply_chua\", not \"%s\"" % first)
	await d.wait_quiet()
	# A second visit: walk away, come back, and answer with "I'll say it".
	await d.lower_phone()
	await d.stick_to(Vector3(8.0, 0.0, 0.2))
	await d.wait_quiet()
	line = await d.talk_to("batu")
	d.expect(line == "batu.greet", "the second visit starts with the greeting, not \"%s\"" % line)
	await d.wait_answer()
	await d.open_app("listen")
	await d.tap_phone_id("reply.chua.say")
	d.expect(d.find("said.phrase") != null, "I'll say it shows the phrase large, with its tones")
	await d.screenshot("say_it")
	await d.tap_phone_id("said.done")
	var second := await d.wait_line("batu")
	d.expect(second == "batu.reply_chua_said", "the answer to I'll say it is warmer: \"%s\"" % second)
	d.expect(first != second, "the two answers are different")
	await d.wait_frames(3)
	await d.screenshot("warmer_answer")
