extends GutTest
## Tests for the content checks (plan 0001, R6 to R8; plan 0003, R1 and R4).

var cards: Dictionary
var spots: Dictionary
var dialogue: Dictionary
var layout: Dictionary
var ui: Dictionary
var messages: Dictionary
var voices: Dictionary
var manifest: Dictionary


func before_each() -> void:
	cards = Content.cards.duplicate(true)
	spots = Content.spots.duplicate(true)
	dialogue = Content.dialogue.duplicate(true)
	layout = Content.layout.duplicate(true)
	ui = Content.ui.duplicate(true)
	messages = Content.messages.duplicate(true)
	voices = Content.voices.duplicate(true)
	manifest = Content.manifest.duplicate(true)


func _check(audio_exists := Callable()) -> PackedStringArray:
	return ContentChecker.check_all({"cards": cards, "spots": spots, "dialogue": dialogue, "layout": layout,
			"ui": ui, "messages": messages, "voices": voices, "sounds": Content.sounds, "manifest": manifest},
			audio_exists)


func _assert_error(errors: PackedStringArray, part: String) -> void:
	var found := false
	for error in errors:
		if part in error:
			found = true
	assert_true(found, "expected an error with \"%s\"; errors: %s" % [part, errors])


func _spot(spot_id: String) -> Dictionary:
	for spot: Dictionary in spots.spots:
		if spot.id == spot_id:
			return spot
	return {}


func test_the_real_data_is_correct() -> void:
	assert_eq(Content.errors, PackedStringArray(), "the data in data/ has errors")
	assert_eq(_check(), PackedStringArray())


func test_reply_points_to_missing_line() -> void:
	dialogue.lines["batu.greet"].replies[0].next = "no.such.line"
	_assert_error(_check(), "line ID \"no.such.line\" that does not exist")


func test_reply_must_point_to_a_spoken_line() -> void:
	dialogue.lines["batu.greet"].replies[0].next_said = "spot.coc.look"
	_assert_error(_check(), "points to line \"spot.coc.look\" that has no speaker")


func test_spoken_line_needs_vi_and_en() -> void:
	dialogue.lines["batu.greet"].erase("en")
	_assert_error(_check(), "line \"batu.greet\": required field \"en\" is missing")


func test_action_needs_a_target() -> void:
	dialogue.lines["cosau.open"].actions[0].target = "pho"
	_assert_error(_check(), "\"target\" must be a test ID")


func test_person_line_must_have_the_speaker() -> void:
	for npc: Dictionary in spots.npcs:
		if npc.id == "cosau":
			npc.lines[0].line = "batu.greet"
	_assert_error(_check(), "must have the speaker \"cosau\"")


func test_lens_rule_must_be_a_description() -> void:
	_spot("coc").lens[0].line = "batu.greet"
	_assert_error(_check(), "must be a description")


func test_spot_points_to_missing_line() -> void:
	_spot("coc").lens[0].line = "no.such.line"
	_assert_error(_check(), "line ID \"no.such.line\" does not exist")


func test_spot_points_to_missing_card() -> void:
	_spot("coc").lens[0].learn = ["no_such_card"]
	_assert_error(_check(), "card ID \"no_such_card\" does not exist")


func test_message_needs_a_time_or_an_event() -> void:
	messages.messages[0].erase("after")
	_assert_error(_check(), "a message must have \"at\" or \"after\"")
	messages.messages[0].after = "heard:no.such.line"
	_assert_error(_check(), "line ID \"no.such.line\" that does not exist")


func test_each_speaker_has_a_voice() -> void:
	voices.speakers.erase("bacha")
	_assert_error(_check(), "the speaker \"bacha\" has no voice")


## R4: each spoken line has an audio file with the hash of its text, voice, and model.
func test_manifest_check() -> void:
	assert_eq(_check(), PackedStringArray(), "the real manifest is correct")
	# A changed text: the hash does not match.
	dialogue.lines["batu.greet"].vi = "Ủa, con dậy rồi hả?"
	_assert_error(_check(), "clip \"batu.greet\": the text, the voice, or the model changed")
	dialogue.lines["batu.greet"].vi = Content.dialogue.lines["batu.greet"].vi
	# A changed voice.
	voices.speakers.batu = "Kim Thanh"
	_assert_error(_check(), "clip \"batu.greet\": the text, the voice, or the model changed")
	voices.speakers.batu = Content.voices.speakers.batu
	# A clip with no entry, and a missing file.
	manifest.clips.erase("cosau.open")
	_assert_error(_check(), "clip \"cosau.open\": the clip has no audio file")
	manifest = Content.manifest.duplicate(true)
	var no_file := func(path: String) -> bool: return not path.ends_with("/nga.hello.ogg")
	_assert_error(_check(no_file), "the file res://assets/voices/nga.hello.ogg is missing")


## The same hash as tools/voices/build.py (tools/voices/tests/test_build.py checks the same value).
func test_clip_hash_is_the_same_as_the_voice_build() -> void:
	assert_eq(VoiceClips.clip_hash("Dạ, chưa ạ.", "Mai Anh", "VieNeu-TTS-v3-Turbo vieneu==3.8.3"),
			"1264a4278e2d8c788c4537d24b974a8d7e290f7618357d25a5643d26b7249ca3")


## R20: the form of address of the "say again" phrase matches the speaker.
func test_say_again_form_of_address() -> void:
	assert_eq(Content.say_again("batu").vi, "Dạ, bà nói lại được không ạ?")
	assert_eq(Content.say_again("cosau").vi, "Dạ, cô nói lại được không ạ?")
	assert_eq(Content.say_again("bacha").vi, "Dạ, bác nói lại được không ạ?")
	assert_eq(Content.say_again("chubay").vi, "Dạ, chú nói lại được không ạ?")
	dialogue.speakers.batu.address = "ông bà"
	_assert_error(_check(), "address \"ông bà\" must be one of")


func test_reply_points_to_missing_card() -> void:
	dialogue.lines["batu.greet"].replies[0].learn = ["no_such_card"]
	_assert_error(_check(), "card ID \"no_such_card\" does not exist")


func test_hours_out_of_range() -> void:
	_spot("coc").hours.close = 1500
	_assert_error(_check(), "must be in the range 0 to 1440 minutes")
	_spot("coc").hours.close = 1320
	_spot("coc").hours.open = -5
	_assert_error(_check(), "must be in the range 0 to 1440 minutes")


func test_hours_open_after_close() -> void:
	_spot("coc").hours.open = 1400
	_assert_error(_check(), "\"hours.open\" must be before \"hours.close\"")


func test_missing_required_fields() -> void:
	cards.cards[0].erase("title")
	_assert_error(_check(), "required field \"title\" is missing")
	cards.cards[0].title = "x"
	_spot("pho").erase("hours")
	_assert_error(_check(), "required field \"hours\" is missing")
	_spot("pho").hours = null
	dialogue.lines["spot.coc.look"].erase("text")
	_assert_error(_check(), "required field \"text\" is missing")


func test_missing_status() -> void:
	cards.cards[0].erase("status")
	_assert_error(_check(), "required field \"status\" is missing")


func test_bad_status_value() -> void:
	cards.cards[0].status = "maybe"
	_assert_error(_check(), "status \"maybe\" must be one of")


func test_last_rule_must_have_no_condition() -> void:
	_spot("coc").lens = [{"open": true, "line": "spot.coc.look"}]
	_assert_error(_check(), "the last rule in \"lens\" must have no condition")


func test_text_not_in_nfc() -> void:
	# "phở" with a combining hook above (U+0309) on "ơ": not NFC.
	cards.cards[0].title = "pho" + String.chr(0x031B) + String.chr(0x0309)
	_assert_error(_check(), "not in Unicode NFC form")


func test_all_real_text_is_nfc() -> void:
	for card: Dictionary in Content.card_list():
		assert_false(ContentChecker.has_combining_mark(card.title + card.body), card.id)


func test_layout_spot_must_exist() -> void:
	layout.carts[0].spot = "no_such_spot"
	_assert_error(_check(), "spot ID \"no_such_spot\" does not exist")


func test_every_spot_has_a_place() -> void:
	layout.carts.remove_at(0)
	_assert_error(_check(), "the spot has no place in the layout")


func test_all_facts_have_status() -> void:
	for card: Dictionary in Content.card_list():
		assert_has(ContentChecker.STATUS_VALUES, card.status, card.id)
	for spot: Dictionary in Content.spot_list():
		assert_has(ContentChecker.STATUS_VALUES, spot.status, spot.id)
	for line_id: String in Content.dialogue.lines:
		assert_has(ContentChecker.STATUS_VALUES, Content.line(line_id).status, line_id)


func test_intro_must_introduce_the_person() -> void:
	# Report 0003, D-0003-04: the first talk starts with a line that introduces the person.
	for npc: Dictionary in spots.npcs:
		if npc.id == "batu":
			npc.intro = "batu.greet"
	_assert_error(_check(), "must have \"introduces\": \"batu\"")


func test_introduces_must_be_the_speaker() -> void:
	dialogue.lines["cosau.intro"].introduces = "batu"
	_assert_error(_check(), "\"introduces\" must be the speaker of the line")
