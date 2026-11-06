extends RefCounted
# PT-50 display_names (plan 0007, R8). For a traveler of 30, 50, and 60: the
# name of Cô Sáu in the subtitle, the Listen app, and the Lens app after her
# introduction. The name is the traveler's word for her and her given name
# ("Cô Sáu" for 30, "Chị Sáu" for 50), or the name of the neighbors when the
# word is "em" ("Cô Sáu" for 60, who is older than she is). The run of 50 is
# not in R8 of the plan, but it is the run where the name changes.
# sizes: 1280x720
# phase: --fresh-save --start-time=07:00
# phase: --fresh-save --start-time=07:00
# phase: --fresh-save --start-time=07:00

const AGES := [30, 50, 60]
const NAMES := ["Cô Sáu", "Chị Sáu", "Cô Sáu"]


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	var age: int = AGES[d.phase - 1]
	var expected: String = NAMES[d.phase - 1]
	if not await d.set_passport("male", "%d-06-15" % (2018 - age)):
		return
	d.expect(Address.display_name(Content.address, "cosau", GameState.traveler()) == expected,
			"the rules give \"%s\" for a man of %d" % [expected, age])
	await d.open_app("listen")
	await d.tap_phone_id("listen.toggle")
	await d.lower_phone()
	var line := await d.talk_to("cosau")
	if not d.expect(line != "", "Cô Sáu speaks after her introduction"):
		return
	await d.wait_frames(3)
	var shown := d.subtitle()
	d.expect(shown.get("speaker", "") == expected, "the subtitle names %s: %s" % [expected, shown.get("speaker", "")])
	await d.screenshot("subtitle_%d" % age)
	await d.open_app("listen")
	var transcript := d.transcript()
	d.expect(not transcript.is_empty() and transcript[-1].speaker == expected,
			"the Listen app names %s: %s" % [expected, transcript.map(func(e: Dictionary) -> String: return e.speaker)])
	await d.screenshot("listen_%d" % age)
	await d.wait_quiet()
	await d.lower_phone()
	await d.look_at_id("npc.cosau")
	await d.open_app("lens")
	await d.wait_frames(3)
	var card: Dictionary = d.main().lens_card()
	d.expect(card.get("kind", "") == "person" and card.get("name", "") == expected,
			"the Lens app names %s: %s" % [expected, card])
	await d.screenshot("lens_%d" % age)
