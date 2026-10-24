extends RefCounted
# PT-01 boot_intro. Start at 06:00. The first message of cô Nga comes, and
# the phone button has a dot. Read it in the Messages app. Go to Bà Tư. She
# speaks with a subtitle. Answer "Dạ, chưa ạ" with Play (plan 0003). The card
# anSang is in the Sổ tay, and a notification shows. A second visit does not
# add the card again. Then the other path: "Good morning!" in English.
# phase: --start-time=06:00
# phase: --start-time=06:00 --fresh-save


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	await _intro(d)
	if d.phase == 1:
		await _path_chua(d)
	else:
		await _path_english(d)


func _intro(d: PlaytestDriver) -> void:
	var s := d.state()
	d.expect(s.time == 360, "the game starts at 06:00, not %s" % s.time_text)
	d.expect(s.day == 1, "the game starts on day 1")
	d.expect(s.messages.has("welcome"), "the first message of cô Nga came: %s" % [s.messages])
	d.expect(s.phone_dot, "the phone button has a dot for the new message")
	d.expect(s.intro_done, "the intro is done")
	await d.screenshot("start")
	await d.open_app("messages")
	d.expect(d.find("message.welcome") != null, "the Messages app shows the welcome message")
	s = d.state()
	d.expect(s.unread == 0 and not s.phone_dot, "the messages are read, and the dot goes away")
	await d.screenshot("messages")
	await d.lower_phone()
	var line := await d.talk_to("batu")
	d.expect(line == "batu.greet", "Bà Tư greets the player, not \"%s\"" % line)
	await d.wait_frames(3)
	s = d.state()
	d.expect(s.subtitle.get("line_id", "") == "batu.greet", "the subtitle shows her greeting: %s" % [s.subtitle])
	await d.screenshot("greeting")


func _path_chua(d: PlaytestDriver) -> void:
	d.expect(await d.answer("chua", "play"), "the reply \"Dạ, chưa ạ\" is in the phrasebook")
	var line := await d.wait_line("batu")
	d.expect(line == "batu.reply_chua", "Bà Tư answers \"chưa\", not \"%s\"" % line)
	var s := d.state()
	d.expect(s.cards == ["anSang"], "the card anSang is in the Sổ tay: %s" % [s.cards])
	d.expect(s.notification.contains(Content.card("anSang").title) or s.notification.contains("Ăn sáng"),
			"a notification shows: %s" % s.notification)
	await d.screenshot("reply_chua")
	await d.wait_quiet()
	await d.open_app("notebook")
	d.expect(d.find("card.anSang") != null, "the Sổ tay shows the card anSang")
	await d.screenshot("notebook_one_card")
	await d.lower_phone()
	# A second visit to Bà Tư does not add the card again.
	await d.stick_to(Vector3(8.0, 0.0, 0.2))
	await d.wait_idle()
	d.expect(d.state().talk_npc == "", "the talk ended when the player walked away")
	await d.wait_quiet()
	line = await d.talk_to("batu")
	d.expect(line == "batu.greet", "a second tap on Bà Tư plays her greeting, not \"%s\"" % line)
	await d.answer("chua", "play")
	await d.wait_line("batu")
	d.expect(d.state().cards == ["anSang"], "the card is in the Sổ tay one time only")


func _path_english(d: PlaytestDriver) -> void:
	d.expect(await d.answer("good_morning", "english"), "the English reply is in the phrasebook")
	var line := await d.wait_line("batu")
	d.expect(line == "batu.reply_english", "Bà Tư answers in English, not \"%s\"" % line)
	var s := d.state()
	d.expect(s.cards == ["anSang"], "the card anSang is in the Sổ tay: %s" % [s.cards])
	await d.screenshot("reply_english")
	await d.wait_quiet()
	d.expect(d.state().messages.has("an_sang_english"), "cô Nga sends a tip after the English answer")
