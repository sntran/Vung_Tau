class_name ContentChecker
extends RefCounted
## Checks the content data (data/*.json) and returns a list of error texts.
##
## An empty list means that the data is correct. Each error text tells the
## file, the item, and the problem, so that the data is easy to correct.

const STATUS_VALUES := ["confirmed", "source", "check"]
const SPOT_KINDS := ["house", "shop", "stall", "cart", "place"]
const GROUND_TYPES := ["gate", "shop", "wall"]
const CHOICE_STYLES := ["", "primary", "quiet"]
## Special values for "next" in a dialogue choice.
## "@hem" shows the hẻm panel. "@spot" shows the line of the near spot.
const SPECIAL_NEXT := ["@hem", "@spot"]
const MINUTES_PER_DAY := 1440

var errors: PackedStringArray = []


## Checks all content. Each argument is the parsed JSON of one file.
static func check_all(cards: Variant, spots: Variant, dialogue: Variant, layout: Variant,
		ui: Variant) -> PackedStringArray:
	var checker := ContentChecker.new()
	checker._check_all(cards, spots, dialogue, layout, ui)
	return checker.errors


func _check_all(cards: Variant, spots: Variant, dialogue: Variant, layout: Variant,
		ui: Variant) -> void:
	if not _is_dict(cards, "cards.json", "file"):
		return
	if not _is_dict(spots, "spots.json", "file"):
		return
	if not _is_dict(dialogue, "dialogue/hem.json", "file"):
		return
	if not _is_dict(layout, "world/hem_layout.json", "file"):
		return
	if not _is_dict(ui, "ui.json", "file"):
		return
	var card_ids := _check_cards(cards)
	var line_ids := _check_dialogue(dialogue, card_ids)
	var spot_ids := _check_spots(spots, card_ids, line_ids)
	_check_layout(layout, spot_ids, spots)
	_check_ui(ui)
	_check_text_nfc(cards, "cards.json")
	_check_text_nfc(spots, "spots.json")
	_check_text_nfc(dialogue, "dialogue/hem.json")
	_check_text_nfc(layout, "world/hem_layout.json")
	_check_text_nfc(ui, "ui.json")


func _error(file: String, where: String, text: String) -> void:
	errors.append("%s: %s: %s" % [file, where, text])


func _is_dict(value: Variant, file: String, where: String) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		_error(file, where, "must be a JSON object")
		return false
	return true


## Records an error when a required field is missing or has the wrong type.
func _require(item: Dictionary, field: String, type: int, file: String, where: String) -> bool:
	if not item.has(field):
		_error(file, where, "required field \"%s\" is missing" % field)
		return false
	var value: Variant = item[field]
	var ok := typeof(value) == type
	# JSON numbers are floats. An integer field accepts a float with no fraction.
	if type == TYPE_INT and typeof(value) == TYPE_FLOAT:
		ok = is_equal_approx(value, roundf(value))
	if type == TYPE_FLOAT and typeof(value) == TYPE_INT:
		ok = true
	if ok and type == TYPE_STRING and String(value).strip_edges() == "":
		_error(file, where, "field \"%s\" is empty" % field)
		return false
	if not ok:
		_error(file, where, "field \"%s\" has the wrong type" % field)
	return ok


func _check_status(item: Dictionary, file: String, where: String) -> void:
	if _require(item, "status", TYPE_STRING, file, where):
		if not STATUS_VALUES.has(item.status):
			_error(file, where, "status \"%s\" must be one of %s" % [item.status, STATUS_VALUES])


func _check_minute(value: Variant, file: String, where: String, field: String) -> void:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		_error(file, where, "\"%s\" must be a number of minutes" % field)
		return
	if value < 0 or value > MINUTES_PER_DAY:
		_error(file, where, "\"%s\" is %s; it must be in the range 0 to 1440 minutes" % [field, value])


func _check_hours(item: Dictionary, file: String, where: String) -> void:
	if not item.has("hours"):
		_error(file, where, "required field \"hours\" is missing")
		return
	var hours: Variant = item.hours
	if hours == null:
		return
	if typeof(hours) != TYPE_DICTIONARY:
		_error(file, where, "\"hours\" must be null or an object with \"open\" and \"close\"")
		return
	for field: String in ["open", "close"]:
		if not hours.has(field):
			_error(file, where, "required field \"hours.%s\" is missing" % field)
			return
		_check_minute(hours[field], file, where, "hours.%s" % field)
	if hours.open >= hours.close:
		_error(file, where, "\"hours.open\" must be before \"hours.close\"")


## Checks "from" and "before" in a time rule.
func _check_time_rule(rule: Dictionary, file: String, where: String) -> void:
	for field: String in ["from", "before"]:
		if rule.has(field):
			_check_minute(rule[field], file, where, field)


func _check_vector3(value: Variant, file: String, where: String, field: String) -> void:
	if typeof(value) != TYPE_ARRAY or value.size() != 3:
		_error(file, where, "\"%s\" must be a list of 3 numbers (meters)" % field)
		return
	for number: Variant in value:
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT]:
			_error(file, where, "\"%s\" must be a list of 3 numbers (meters)" % field)
			return


func _check_card_refs(refs: Variant, card_ids: Dictionary, file: String, where: String) -> void:
	if typeof(refs) != TYPE_ARRAY:
		_error(file, where, "\"learn\" must be a list of card IDs")
		return
	for card_id: Variant in refs:
		if not card_ids.has(card_id):
			_error(file, where, "card ID \"%s\" does not exist" % card_id)


func _check_cards(cards: Dictionary) -> Dictionary:
	var file := "cards.json"
	var ids := {}
	if not _require(cards, "groups", TYPE_ARRAY, file, "file"):
		return ids
	if not _require(cards, "cards", TYPE_ARRAY, file, "file"):
		return ids
	for i in cards.cards.size():
		var card: Variant = cards.cards[i]
		var where := "card %d" % i
		if not _is_dict(card, file, where):
			continue
		if _require(card, "id", TYPE_STRING, file, where):
			where = "card \"%s\"" % card.id
			if ids.has(card.id):
				_error(file, where, "card ID is not unique")
			ids[card.id] = true
		for field: String in ["title", "vi", "body", "hint"]:
			_require(card, field, TYPE_STRING, file, where)
		if _require(card, "group", TYPE_STRING, file, where):
			if not cards.groups.has(card.group):
				_error(file, where, "group \"%s\" is not in \"groups\"" % card.group)
		_check_status(card, file, where)
	return ids


func _check_dialogue(dialogue: Dictionary, card_ids: Dictionary) -> Dictionary:
	var file := "dialogue/hem.json"
	var ids := {}
	var speakers: Dictionary = {}
	if _require(dialogue, "speakers", TYPE_DICTIONARY, file, "file"):
		speakers = dialogue.speakers
		for key: String in speakers:
			var speaker: Variant = speakers[key]
			if _is_dict(speaker, file, "speaker \"%s\"" % key):
				_require(speaker, "name", TYPE_STRING, file, "speaker \"%s\"" % key)
				_require(speaker, "color", TYPE_STRING, file, "speaker \"%s\"" % key)
	if _require(dialogue, "strings", TYPE_DICTIONARY, file, "file"):
		for field: String in ["status_open", "status_closed"]:
			_require(dialogue.strings, field, TYPE_STRING, file, "strings")
	if not _require(dialogue, "lines", TYPE_DICTIONARY, file, "file"):
		return ids
	for line_id: String in dialogue.lines:
		ids[line_id] = true
	for line_id: String in dialogue.lines:
		var line: Variant = dialogue.lines[line_id]
		var where := "line \"%s\"" % line_id
		if not _is_dict(line, file, where):
			continue
		_require(line, "text", TYPE_STRING, file, where)
		_check_status(line, file, where)
		if line.has("speaker") and not speakers.has(line.speaker):
			_error(file, where, "speaker \"%s\" does not exist" % line.speaker)
		if line.has("phrases"):
			if typeof(line.phrases) != TYPE_ARRAY:
				_error(file, where, "\"phrases\" must be a list")
			else:
				for phrase: Variant in line.phrases:
					if _is_dict(phrase, file, where + " phrase"):
						_require(phrase, "vi", TYPE_STRING, file, where + " phrase")
						_require(phrase, "en", TYPE_STRING, file, where + " phrase")
		if not _require(line, "choices", TYPE_ARRAY, file, where):
			continue
		if line.choices.is_empty():
			_error(file, where, "a line must have one or more choices")
		var choice_ids := {}
		for i in line.choices.size():
			var choice: Variant = line.choices[i]
			var cwhere := "%s choice %d" % [where, i]
			if not _is_dict(choice, file, cwhere):
				continue
			if _require(choice, "id", TYPE_STRING, file, cwhere):
				cwhere = "%s choice \"%s\"" % [where, choice.id]
				if choice_ids.has(choice.id):
					_error(file, cwhere, "choice ID is not unique in the line")
				choice_ids[choice.id] = true
			_require(choice, "label", TYPE_STRING, file, cwhere)
			_check_choice(choice, ids, card_ids, file, cwhere)
	return ids


## Checks the fields that a dialogue choice and a clock choice can have.
func _check_choice(choice: Dictionary, line_ids: Dictionary, card_ids: Dictionary, file: String,
		where: String) -> void:
	if choice.has("style") and not CHOICE_STYLES.has(choice.style):
		_error(file, where, "style \"%s\" must be one of %s" % [choice.style, CHOICE_STYLES])
	if choice.has("next"):
		if typeof(choice.next) != TYPE_STRING:
			_error(file, where, "\"next\" must be a line ID")
		elif not SPECIAL_NEXT.has(choice.next) and not line_ids.has(choice.next):
			_error(file, where, "\"next\" points to line ID \"%s\" that does not exist" % choice.next)
	if choice.has("learn"):
		_check_card_refs(choice.learn, card_ids, file, where)
	if choice.has("minutes"):
		if typeof(choice.minutes) not in [TYPE_INT, TYPE_FLOAT] or choice.minutes <= 0:
			_error(file, where, "\"minutes\" must be a number more than 0")
	if choice.has("until"):
		_check_minute(choice.until, file, where, "until")
	if choice.has("open") and choice.open != "clock":
		_error(file, where, "\"open\" must be \"clock\"")


func _check_line_rules(item: Dictionary, card_ids: Dictionary, line_ids: Dictionary, file: String,
		where: String) -> void:
	if not _require(item, "lines", TYPE_ARRAY, file, where):
		return
	var rules: Array = item.lines
	if rules.is_empty():
		_error(file, where, "\"lines\" must have one or more rules")
		return
	for i in rules.size():
		var rule: Variant = rules[i]
		var rwhere := "%s rule %d" % [where, i]
		if not _is_dict(rule, file, rwhere):
			continue
		if _require(rule, "line", TYPE_STRING, file, rwhere):
			if not line_ids.has(rule.line):
				_error(file, rwhere, "line ID \"%s\" does not exist" % rule.line)
		_check_time_rule(rule, file, rwhere)
		if rule.has("learn"):
			_check_card_refs(rule.learn, card_ids, file, rwhere)
	var last: Variant = rules[rules.size() - 1]
	if typeof(last) == TYPE_DICTIONARY and (last.has("open") or last.has("from") or last.has("before")):
		_error(file, where, "the last rule in \"lines\" must have no condition")


func _check_spots(spots: Dictionary, card_ids: Dictionary, line_ids: Dictionary) -> Dictionary:
	var file := "spots.json"
	var ids := {}
	if _require(spots, "spots", TYPE_ARRAY, file, "file"):
		for i in spots.spots.size():
			var spot: Variant = spots.spots[i]
			var where := "spot %d" % i
			if not _is_dict(spot, file, where):
				continue
			if _require(spot, "id", TYPE_STRING, file, where):
				where = "spot \"%s\"" % spot.id
				if ids.has(spot.id):
					_error(file, where, "spot ID is not unique")
				ids[spot.id] = spot
			for field: String in ["name", "en", "look_label", "verb"]:
				_require(spot, field, TYPE_STRING, file, where)
			if spot.has("verb_open") and typeof(spot.verb_open) != TYPE_STRING:
				_error(file, where, "field \"verb_open\" has the wrong type")
			if spot.has("focus"):
				_check_vector3(spot.focus, file, where, "focus")
			if _require(spot, "kind", TYPE_STRING, file, where) and not SPOT_KINDS.has(spot.kind):
				_error(file, where, "kind \"%s\" must be one of %s" % [spot.kind, SPOT_KINDS])
			_check_hours(spot, file, where)
			if spot.get("kind", "") == "cart" and spot.get("hours") == null:
				_error(file, where, "a cart must have opening hours")
			_check_status(spot, file, where)
			if spot.has("shutter_half"):
				if typeof(spot.shutter_half) != TYPE_ARRAY:
					_error(file, where, "\"shutter_half\" must be a list of time rules")
				else:
					for rule: Variant in spot.shutter_half:
						if _is_dict(rule, file, where + " shutter_half"):
							_check_time_rule(rule, file, where + " shutter_half")
			_check_line_rules(spot, card_ids, line_ids, file, where)
	if _require(spots, "npcs", TYPE_ARRAY, file, "file"):
		for i in spots.npcs.size():
			var npc: Variant = spots.npcs[i]
			var where := "npc %d" % i
			if not _is_dict(npc, file, where):
				continue
			if _require(npc, "id", TYPE_STRING, file, where):
				where = "npc \"%s\"" % npc.id
			_require(npc, "name", TYPE_STRING, file, where)
			_require(npc, "verb", TYPE_STRING, file, where)
			_check_hours(npc, file, where)
			_check_status(npc, file, where)
			_check_line_rules(npc, card_ids, line_ids, file, where)
	if _require(spots, "boats_in", TYPE_DICTIONARY, file, "file"):
		_check_time_rule(spots.boats_in, file, "boats_in")
	if _require(spots, "hem_tips", TYPE_ARRAY, file, "file"):
		var tips := {"lines": spots.hem_tips}
		_check_line_rules(tips, card_ids, line_ids, file, "hem_tips")
		for tip: Variant in spots.hem_tips:
			if typeof(tip) == TYPE_DICTIONARY and tip.has("missing_card") \
					and not card_ids.has(tip.missing_card):
				_error(file, "hem_tips", "card ID \"%s\" does not exist" % tip.missing_card)
	return ids


func _check_sign(item: Dictionary, file: String, where: String) -> void:
	if not item.has("sign"):
		return
	if _is_dict(item.sign, file, where + " sign"):
		for field: String in ["text", "bg", "fg"]:
			_require(item.sign, field, TYPE_STRING, file, where + " sign")


func _check_layout(layout: Dictionary, spot_ids: Dictionary, spots: Dictionary) -> void:
	var file := "world/hem_layout.json"
	_require(layout, "hem_width", TYPE_FLOAT, file, "file")
	_require(layout, "floor_height", TYPE_FLOAT, file, "file")
	if _require(layout, "house_depth", TYPE_FLOAT, file, "file") and layout.house_depth < TubeHouse.ROOM_DEPTH + 1.0:
		_error(file, "file", "\"house_depth\" must be more than the shop room depth plus 1 m")
	for row: String in ["opposite_lots", "beach_road_lots"]:
		if _require(layout, row, TYPE_ARRAY, file, "file"):
			for i in layout[row].size():
				var lot: Variant = layout[row][i]
				var where := "%s %d" % [row, i]
				if _is_dict(lot, file, where):
					_check_lot_shape(lot, file, where)
					if lot.has("spot"):
						_error(file, where, "a lot in \"%s\" cannot have a spot" % row)
	var placed := {}
	var lot_ids := {}
	if _require(layout, "lots", TYPE_ARRAY, file, "file"):
		for i in layout.lots.size():
			var lot: Variant = layout.lots[i]
			var where := "lot %d" % i
			if not _is_dict(lot, file, where):
				continue
			if _require(lot, "id", TYPE_STRING, file, where):
				where = "lot \"%s\"" % lot.id
				lot_ids[lot.id] = true
			_check_lot_shape(lot, file, where)
			if lot.has("spot"):
				_check_placed_spot(lot.spot, spot_ids, placed, file, where)
	if _require(layout, "carts", TYPE_ARRAY, file, "file"):
		for i in layout.carts.size():
			var cart: Variant = layout.carts[i]
			var where := "cart %d" % i
			if not _is_dict(cart, file, where):
				continue
			if _require(cart, "spot", TYPE_STRING, file, where):
				where = "cart \"%s\"" % cart.spot
				_check_placed_spot(cart.spot, spot_ids, placed, file, where)
				if spot_ids.has(cart.spot) and spot_ids[cart.spot].get("kind") != "cart":
					_error(file, where, "spot \"%s\" is not a cart" % cart.spot)
			if _require(cart, "lot", TYPE_STRING, file, where) and not lot_ids.has(cart.lot):
				_error(file, where, "lot \"%s\" does not exist" % cart.lot)
			_require(cart, "offset", TYPE_FLOAT, file, where)
			_require(cart, "color", TYPE_STRING, file, where)
			_check_sign(cart, file, where)
	if _require(layout, "npcs", TYPE_ARRAY, file, "file"):
		var npc_ids := {}
		for npc: Variant in spots.get("npcs", []):
			if typeof(npc) == TYPE_DICTIONARY and npc.has("id"):
				npc_ids[npc.id] = true
		for i in layout.npcs.size():
			var npc: Variant = layout.npcs[i]
			var where := "npc %d" % i
			if not _is_dict(npc, file, where):
				continue
			if _require(npc, "npc", TYPE_STRING, file, where) and not npc_ids.has(npc.npc):
				_error(file, where, "npc \"%s\" does not exist in spots.json" % npc.npc)
			if _require(npc, "lot", TYPE_STRING, file, where) and not lot_ids.has(npc.lot):
				_error(file, where, "lot \"%s\" does not exist" % npc.lot)
			_require(npc, "offset", TYPE_FLOAT, file, where)
	if _require(layout, "beach", TYPE_DICTIONARY, file, "file"):
		var beach: Dictionary = layout.beach
		for field: String in ["road_width", "road_depth", "sand_width", "wall_height", "play_half_length",
				"steps_width"]:
			_require(beach, field, TYPE_FLOAT, file, "beach")
		_require(beach, "boat_colors", TYPE_ARRAY, file, "beach")
		if _require(beach, "spot", TYPE_STRING, file, "beach"):
			_check_placed_spot(beach.spot, spot_ids, placed, file, "beach")
	for spot_id: String in spot_ids:
		if not placed.has(spot_id):
			_error(file, "spot \"%s\"" % spot_id, "the spot has no place in the layout")


## Checks the fields that give the shape and the colors of a house.
func _check_lot_shape(lot: Dictionary, file: String, where: String) -> void:
	if _require(lot, "id", TYPE_STRING, file, where):
		where = "lot \"%s\"" % lot.id
	if _require(lot, "width", TYPE_FLOAT, file, where) and lot.width <= 0.0:
		_error(file, where, "\"width\" must be more than 0")
	if _require(lot, "floors", TYPE_INT, file, where) and lot.floors < 1:
		_error(file, where, "\"floors\" must be 1 or more")
	for field: String in ["wall_color", "trim_color", "shutter_color"]:
		_require(lot, field, TYPE_STRING, file, where)
	_require(lot, "balcony", TYPE_BOOL, file, where)
	if _require(lot, "ground", TYPE_STRING, file, where) and not GROUND_TYPES.has(lot.ground):
		_error(file, where, "ground \"%s\" must be one of %s" % [lot.ground, GROUND_TYPES])
	_check_sign(lot, file, where)


func _check_placed_spot(spot_id: Variant, spot_ids: Dictionary, placed: Dictionary, file: String,
		where: String) -> void:
	if not spot_ids.has(spot_id):
		_error(file, where, "spot ID \"%s\" does not exist" % spot_id)
		return
	if placed.has(spot_id):
		_error(file, where, "spot \"%s\" has more than one place" % spot_id)
	placed[spot_id] = true


func _check_ui(ui: Dictionary) -> void:
	var file := "ui.json"
	for field: String in ["place_name", "place_sub", "beach_name", "beach_sub", "sound_on",
			"sound_off", "notebook_button", "notebook_title", "notebook_count", "notebook_locked",
			"notebook_hint", "close", "toast_new_card", "clack_bubble", "clock_title", "clock_hint",
			"settings_title", "settings_sensitivity", "settings_invert", "settings_gyro", "settings_fov",
			"settings_tap_walk", "center_view", "too_far"]:
		_require(ui, field, TYPE_STRING, file, "file")
	if _require(ui, "parts_of_day", TYPE_ARRAY, file, "file"):
		var last := 0
		for part: Variant in ui.parts_of_day:
			if not _is_dict(part, file, "parts_of_day"):
				continue
			for field: String in ["vi", "en"]:
				_require(part, field, TYPE_STRING, file, "parts_of_day")
			if _require(part, "before", TYPE_INT, file, "parts_of_day"):
				_check_minute(part.before, file, "parts_of_day", "before")
				if part.before <= last:
					_error(file, "parts_of_day", "\"before\" values must increase")
				last = part.before
		if last != MINUTES_PER_DAY:
			_error(file, "parts_of_day", "the last \"before\" value must be 1440")
	if _require(ui, "clock_choices", TYPE_ARRAY, file, "file"):
		for i in ui.clock_choices.size():
			var choice: Variant = ui.clock_choices[i]
			var where := "clock choice %d" % i
			if not _is_dict(choice, file, where):
				continue
			_require(choice, "id", TYPE_STRING, file, where)
			_require(choice, "label", TYPE_STRING, file, where)
			if not (choice.has("minutes") or choice.has("until") or choice.has("sleep")):
				_error(file, where, "a clock choice must have \"minutes\", \"until\", or \"sleep\"")
			_check_choice(choice, {}, {}, file, where)


## Records an error for each text that is not in Unicode NFC form.
##
## Godot has no Unicode normalization function. All Vietnamese letters have a
## precomposed form in NFC, so a combining diacritical mark (U+0300 to U+036F)
## in a text shows that the text is not in NFC form.
func _check_text_nfc(value: Variant, file: String, path := "") -> void:
	match typeof(value):
		TYPE_STRING:
			if has_combining_mark(value):
				_error(file, path, "text is not in Unicode NFC form: \"%s\"" % value)
		TYPE_DICTIONARY:
			for key: Variant in value:
				_check_text_nfc(value[key], file, "%s.%s" % [path, key] if path else str(key))
		TYPE_ARRAY:
			for i in value.size():
				_check_text_nfc(value[i], file, "%s[%d]" % [path, i])


static func has_combining_mark(text: String) -> bool:
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= 0x0300 and code <= 0x036F:
			return true
	return false
