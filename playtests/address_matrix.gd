extends RefCounted
# PT-49 address_matrix (plan 0007, R6 to R12). One run for each traveler:
# male 25, female 25, male 40, female 40, male 60, female 60. Send the
# passport, turn on Listen, and talk with each person who can talk: Bà Tư, Cô
# Sáu, Bác Hà, and Cô Út at 08:00, then cô Nga after one hour (she comes at
# 09:00). For each line that the player hears, the subtitle, the Listen entry,
# and the voice clip use the words of the rules (data/address.json), with no
# field left. The phrasebook replies and the "say again" phrase use them too,
# and the reply that the phone plays is the clip of its variant. A screenshot
# of the subtitle of each person.
# sizes: 1280x720
# phase: --fresh-save --start-time=08:00
# phase: --fresh-save --start-time=08:00
# phase: --fresh-save --start-time=08:00
# phase: --fresh-save --start-time=08:00
# phase: --fresh-save --start-time=08:00
# phase: --fresh-save --start-time=08:00

const TRAVELERS := [["male", 25], ["female", 25], ["male", 40], ["female", 40], ["male", 60], ["female", 60]]
const MORNING := ["batu", "cosau", "bacha", "cout"]

var _gender := ""
var _age := 0
## line ID -> {speaker, text, clip}: what the player saw and heard.
var _heard := {}


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	_gender = TRAVELERS[d.phase - 1][0]
	_age = TRAVELERS[d.phase - 1][1]
	# Born on 15 June: the age on day 1 (22 January 2019) is _age.
	if not await d.set_passport(_gender, "%d-06-15" % (2018 - _age)):
		return
	d.expect(GameState.traveler() == {"gender": _gender, "age": _age}, "the traveler: %s" % [GameState.traveler()])
	await d.open_app("listen")
	await d.tap_phone_id("listen.toggle")
	await d.lower_phone()
	var record := func() -> void: _record(d)
	d.main().get_tree().process_frame.connect(record)
	for npc_id: String in MORNING:
		await _talk(d, npc_id)
	await d.open_app("clock")
	await d.tap_phone_id("clock.wait_hour")
	await d.lower_phone()
	await _talk(d, "nga")
	d.main().get_tree().process_frame.disconnect(record)
	_check_heard(d)


## Talks with the person: the first line (after the introduction), the
## phrasebook, and an answer with Play.
func _talk(d: PlaytestDriver, npc_id: String) -> void:
	var line_id := await d.talk_to(npc_id)
	if not d.expect(line_id != "", "%s speaks" % npc_id):
		return
	await d.screenshot("%s_%s_%d" % [npc_id, _gender, _age])
	# Some lines have no answer (a call of a seller): then the talk ends.
	if Content.line(line_id).get("replies", []).is_empty():
		await d.wait_quiet()
		return
	if not await d.wait_answer():
		return
	var words := PlaytestDriver.expected_words(npc_id, _gender, _age)
	await d.open_app("listen")
	var answer_line: String = d.main().talk.answer
	var played := ""
	for reply: Dictionary in Content.line(answer_line).get("replies", []):
		if reply.get("english", false):
			continue
		var expected := Address.resolve_line(Content.address, reply, words)
		var shown := _vietnamese_text(d.find("reply.%s" % reply.id))
		d.expect(shown == expected.vi, "%s: the reply %s is \"%s\": \"%s\"" % [npc_id, reply.id, expected.vi, shown])
		if played == "":
			played = reply.id
	var say_again := Address.resolve_line(Content.address, Content.dialogue.say_again, words)
	d.expect(_vietnamese_text(d.find("reply.say_again")) == say_again.vi,
			"%s: \"say again\" is \"%s\": \"%s\"" % [npc_id, say_again.vi, _vietnamese_text(d.find("reply.say_again"))])
	if played != "":
		var reply_line: Dictionary = {}
		for reply: Dictionary in Content.line(answer_line).replies:
			if reply.id == played:
				reply_line = reply
		var clip := VoiceClips.variant_id(VoiceClips.reply_id(answer_line, played),
				Address.key(words, Address.line_fields(reply_line)))
		await d.tap_phone_id("reply.%s.play" % played)
		var stream: AudioStream = d.main().phone_voice.stream
		var playing := stream.resource_path.get_file().get_basename() if stream else ""
		d.expect(playing == clip, "%s: the phone plays the clip %s: %s" % [npc_id, clip, playing])
		await d.wait_line(npc_id, 20.0, false)
	await d.wait_quiet()
	await d.lower_phone()


## Records each line that shows: the subtitle, and the clip that plays.
func _record(d: PlaytestDriver) -> void:
	var shown := d.subtitle()
	if shown.is_empty() or shown.get("caption", false):
		return
	var line_id: String = shown.get("line_id", "")
	if line_id == "" or _heard.has(line_id):
		return
	var speaker: String = Content.line(line_id).get("speaker", "")
	_heard[line_id] = {"speaker": shown.get("speaker", ""), "text": " ".join(shown.get("lines", [])),
			"clip": d.playing_clip(speaker) if d.main().hem.npcs.has(speaker) else ""}


func _check_heard(d: PlaytestDriver) -> void:
	var people := {}
	for line_id: String in _heard:
		var line := Content.line(line_id)
		var npc_id: String = line.speaker
		people[npc_id] = true
		var words := PlaytestDriver.expected_words(npc_id, _gender, _age)
		var expected := Address.resolve_line(Content.address, line, words)
		var item: Dictionary = _heard[line_id]
		d.expect(_squash(item.text) == _squash(expected.vi), "%s: the subtitle is \"%s\": \"%s\"" % [line_id, expected.vi, item.text])
		d.expect(not str(item.text).contains("{"), "%s: no field is left in the subtitle" % line_id)
		var clip := VoiceClips.variant_id(line_id, Address.key(words, Address.line_fields(line)))
		d.expect(item.clip == clip, "%s: the voice is the clip %s: %s" % [line_id, clip, item.clip])
		var entry := _transcript_entry(d, expected.vi)
		d.expect(not entry.is_empty(), "%s: the Listen app has \"%s\"" % [line_id, expected.vi])
		if not entry.is_empty():
			d.expect(not str(entry.en).contains("{"), "%s: no field is left in the English line: %s" % [line_id, entry.en])
	for npc_id: String in MORNING + ["nga"]:
		d.expect(people.has(npc_id), "the player heard %s: %s" % [npc_id, people.keys()])
	d.step("%s %d: %d lines checked" % [_gender, _age, _heard.size()])


func _transcript_entry(d: PlaytestDriver, vi: String) -> Dictionary:
	for entry: Dictionary in d.transcript():
		if entry.vi == vi:
			return entry
	return {}


## The text of the Vietnamese label in a reply of the phrasebook.
static func _vietnamese_text(node: Node) -> String:
	if node == null:
		return ""
	for child in node.find_children("*", "Label", true, false):
		if (child as Label).theme_type_variation == "Vietnamese":
			return (child as Label).text
	return ""


## The text without spaces: the subtitle breaks a long line in two.
static func _squash(text: String) -> String:
	return text.replace(" ", "").replace("\n", "")
