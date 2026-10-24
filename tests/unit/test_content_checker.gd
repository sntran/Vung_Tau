extends GutTest
## Tests for the content checks (R6, R7, R8).

var cards: Dictionary
var spots: Dictionary
var dialogue: Dictionary
var layout: Dictionary
var ui: Dictionary


func before_each() -> void:
	cards = Content.cards.duplicate(true)
	spots = Content.spots.duplicate(true)
	dialogue = Content.dialogue.duplicate(true)
	layout = Content.layout.duplicate(true)
	ui = Content.ui.duplicate(true)


func _check() -> PackedStringArray:
	return ContentChecker.check_all(cards, spots, dialogue, layout, ui)


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


func test_choice_points_to_missing_line() -> void:
	dialogue.lines["batu.greet"].choices[0].next = "no.such.line"
	_assert_error(_check(), "line ID \"no.such.line\" that does not exist")


func test_spot_points_to_missing_line() -> void:
	_spot("coc").lines[0].line = "no.such.line"
	_assert_error(_check(), "line ID \"no.such.line\" does not exist")


func test_spot_points_to_missing_card() -> void:
	_spot("coc").lines[0].learn = ["no_such_card"]
	_assert_error(_check(), "card ID \"no_such_card\" does not exist")


func test_choice_points_to_missing_card() -> void:
	dialogue.lines["batu.greet"].choices[0].learn = ["no_such_card"]
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
	dialogue.lines["hem.late"].erase("text")
	_assert_error(_check(), "required field \"text\" is missing")


func test_missing_status() -> void:
	cards.cards[0].erase("status")
	_assert_error(_check(), "required field \"status\" is missing")


func test_bad_status_value() -> void:
	cards.cards[0].status = "maybe"
	_assert_error(_check(), "status \"maybe\" must be one of")


func test_last_rule_must_have_no_condition() -> void:
	_spot("coc").lines = [{"open": true, "line": "spot.coc.look"}]
	_assert_error(_check(), "the last rule in \"lines\" must have no condition")


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
