extends RefCounted
# PT-18 talk_listen (plan 0003). Start at 06:00. The first message from cô
# Nga arrives. Go to Bà Tư and talk with the phone down. Her audio plays, and
# the Vietnamese subtitle shows. Raise the phone, open Listen. The transcript
# is empty. Choose "Dạ, bà nói lại được không ạ?". She says the line again.
# Turn on Listen, and ask again. The transcript shows the line in Vietnamese
# and English. Answer with Play, then on a second visit with I'll say it.
# Check the two different answers.
# Report 0003: with Listen on and an empty transcript, the hint says that the
# app listens (D-0003-01). A tap on "say again" in the last 0.2 s of a line
# makes the person say the same line again (D-0003-02). The banner of a saved
# line covers no part of the phone (D-0003-07).
# sizes: 1280x720 2400x1080
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	var s := d.state()
	d.expect(s.messages.has("welcome") and s.phone_dot, "the first message from cô Nga arrives: %s" % [s.messages])
	# The player does not know her name before she says it (D-0003-04).
	d.expect(not GameState.has_met("batu"), "the player does not know Bà Tư before the first talk")
	var names := {}
	var record := func() -> void:
		var shown := d.subtitle()
		if not shown.is_empty() and not shown.get("caption", false):
			names[shown.get("line_id", "")] = shown.get("speaker", "")
	d.main().get_tree().process_frame.connect(record)
	var line := await d.talk_to("batu")
	d.main().get_tree().process_frame.disconnect(record)
	d.expect(names.get("batu.intro", "") == "Bà Tư", "she says who she is, and her name shows from that line on: %s" % [names])
	# A talk at a normal distance: 1.0 m to 1.2 m (D-0004-05).
	var npc_at: Vector3 = (d.find("npc.batu") as Node3D).global_position
	var player_at: Vector3 = d.main().player.global_position
	var talk_m := Vector2(player_at.x - npc_at.x, player_at.z - npc_at.z).length()
	d.expect(talk_m >= 1.0 and talk_m <= 1.2, "the player talks at %.2f m from Bà Tư, from 1.0 m to 1.2 m" % talk_m)
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
	d.expect(_hint(d) == Content.ui_text("listen_empty"), "with Listen off, the hint tells the player to turn it on")
	await d.tap_phone_id("listen.toggle")
	d.expect(d.state().listen_on, "Listen is on")
	await d.wait_frames(2)
	d.expect(_hint(d) == Content.ui_text("listen_empty_on"), "with Listen on, the hint says that the app listens: \"%s\"" % _hint(d))
	await d.answer("say_again", "play")
	line = await d.wait_line("batu")
	# "Say again" at the end of her line: she says the same line again (D-0003-02).
	# The game plays 10 times slower here: on a slow computer, one frame can be
	# longer than the last 0.2 s of the line, and the wait or the tap missed it.
	var m: Node = d.main()
	await d.wait_until(func() -> bool: return m.speech.has("batu") and float(m.speech.batu.left) < 1.0, 15.0,
			"the last second of her line")
	d.set_time_scale(0.1)
	await d.wait_until(func() -> bool: return m.speech.has("batu") and float(m.speech.batu.left) < 0.2, 30.0,
			"the last 0.2 s of her line")
	await d.tap_phone_id("reply.say_again.play")
	d.set_time_scale(1.0)
	line = await d.wait_line("batu")
	d.expect(line == "batu.greet", "after \"say again\" at the end of her line, she says it again, not \"%s\"" % line)
	d.expect(m.talk.get("state", "") == "speaking", "the talk goes on: %s" % m.talk.get("state", ""))
	await d.wait_answer()
	var transcript := d.transcript()
	d.expect(transcript.size() == 2 and transcript[0].vi == vi and transcript[0].en == Content.line("batu.greet").en
			and transcript[0].speaker == "Bà Tư", "the transcript shows the line in Vietnamese and English: %s" % [transcript])
	await d.screenshot("transcript")
	# Save a line: the banner shows, and it covers no part of the phone (D-0003-07).
	await d.tap_phone_id("listen.entry.0")
	await d.wait_frames(2)
	var banner := d.find("phone.banner") as Control
	d.expect(banner != null and d.state().banner_visible, "the banner \"saved\" shows")
	if banner != null:
		for part: String in ["phone.home", "listen.toggle"]:
			var control := d.find(part) as Control
			d.expect(control != null and not banner.get_global_rect().intersects(control.get_global_rect()),
					"the banner does not cover %s" % part)
	await d.screenshot("banner")
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


static func _hint(d: PlaytestDriver) -> String:
	var hint: Label = d.find("listen.hint") as Label
	return hint.text if hint != null else ""
