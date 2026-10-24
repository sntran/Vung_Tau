extends GutTest
## Tests for the opening hours (R11): a spot is open when open <= minutes < close.


func test_null_hours_are_always_open() -> void:
	assert_true(GameClock.is_open(null, 0))
	assert_true(GameClock.is_open(null, 1439))


func test_edge_minutes() -> void:
	var hours := {"open": 330, "close": 630}
	assert_false(GameClock.is_open(hours, 329), "closed one minute before open")
	assert_true(GameClock.is_open(hours, 330), "open at the open minute")
	assert_true(GameClock.is_open(hours, 629), "open one minute before close")
	assert_false(GameClock.is_open(hours, 630), "closed at the close minute")


func test_float_hours_from_json() -> void:
	var hours := {"open": 330.0, "close": 630.0}
	assert_true(GameClock.is_open(hours, 330))
	assert_false(GameClock.is_open(hours, 630))


func test_all_spots_in_the_data() -> void:
	for spot: Dictionary in Content.spot_list():
		var hours: Variant = spot.hours
		if hours == null:
			continue
		var open := int(hours.open)
		var close := int(hours.close)
		assert_false(GameClock.is_open(hours, open - 1), "%s closed at %d" % [spot.id, open - 1])
		assert_true(GameClock.is_open(hours, open), "%s open at %d" % [spot.id, open])
		assert_true(GameClock.is_open(hours, close - 1), "%s open at %d" % [spot.id, close - 1])
		assert_false(GameClock.is_open(hours, close), "%s closed at %d" % [spot.id, close])


func test_pho_line_rules_by_time() -> void:
	var pho := Content.spot("pho")
	assert_eq(Content.line_rule(pho, 300).line, "spot.pho.closed_before")
	assert_eq(Content.line_rule(pho, 330).line, "spot.pho.open")
	assert_eq(Content.line_rule(pho, 629).line, "spot.pho.open")
	assert_eq(Content.line_rule(pho, 630).line, "spot.pho.sold_out")
	assert_eq(Content.line_rule(pho, 719).line, "spot.pho.sold_out")
	assert_eq(Content.line_rule(pho, 720).line, "spot.pho.closed_after")
	assert_eq(Content.line_rule(pho, 100).line, "spot.pho.closed_after")


func test_beach_line_rules_by_time() -> void:
	var beach := Content.spot("beach")
	assert_eq(Content.line_rule(beach, 269).line, "spot.beach.night")
	assert_eq(Content.line_rule(beach, 270).line, "spot.beach.dawn")
	assert_eq(Content.line_rule(beach, 450).line, "spot.beach.day")
	assert_eq(Content.line_rule(beach, 960).line, "spot.beach.evening")
	assert_eq(Content.line_rule(beach, 1290).line, "spot.beach.night")
