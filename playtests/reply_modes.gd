extends RefCounted
# PT-20 reply_modes (plan 0003). For each reply type (a phrase with Play, a
# phrase with I'll say it, English, and an action in the world): give the
# reply to Cô Sáu and check the line ID of the answer.
# sizes: 1280x720 2400x1080
# phase: --start-time=06:00

const CASES := [
	["cam_on", "play", "cosau.thanks"],
	["cam_on", "say", "cosau.thanks_said"],
	["thank_you", "english", "cosau.english"],
	["sit", "action", "cosau.sit"],
]


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	await d.walk_toward(d.main().hem.stand_points["pho"].x, 0.0)
	for item: Array in CASES:
		await d.lower_phone()
		await d.wait_quiet()
		var line := await d.talk_to("cosau")
		d.expect(line == "cosau.open", "Cô Sáu invites the player in, not \"%s\"" % line)
		await d.wait_answer()
		if item[1] == "action":
			# The answer by action: tap her shop (sit down).
			await d.look_at_id("spot.pho")
			await d.tap_id("spot.pho")
		else:
			await d.answer(item[0], item[1])
		var answer := await d.wait_line("cosau")
		d.expect(answer == item[2], "the reply %s (%s) gives %s, not \"%s\"" % [item[0], item[1], item[2], answer])
		await d.wait_frames(2)
		await d.screenshot("%s_%s" % [item[0], item[1]])
