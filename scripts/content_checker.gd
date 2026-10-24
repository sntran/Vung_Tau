class_name ContentChecker
extends RefCounted
## Checks the content data (data/*.json) and returns a list of error texts.
##
## An empty list means that the data is correct. Each error text tells the
## file, the item, and the problem, so that the data is easy to correct.

const STATUS_VALUES := ["confirmed", "source", "check"]
const SPOT_KINDS := ["house", "shop", "stall", "cart", "place"]
const GROUND_TYPES := ["gate", "shop", "wall"]
## The forms of address of plan 0003 (R20).
const ADDRESS_FORMS := ["bà", "cô", "chú", "bác", "anh", "chị", "em"]
## The events that start a message (data/messages.json).
const MESSAGE_EVENTS := ["start", "wake"]
const MINUTES_PER_DAY := 1440
const SUBTITLE_IDS := ["vi", "en", "both", "off"]

var errors: PackedStringArray = []


## Checks all content. "files" has the parsed JSON of each file: cards,
## spots, dialogue, layout, ui, messages, voices, sounds, and manifest (the
## voice manifest). "audio_exists" tells if an audio file exists (the tests
## replace it).
static func check_all(files: Dictionary, audio_exists := Callable()) -> PackedStringArray:
	var checker := ContentChecker.new()
	checker._check_all(files, audio_exists if audio_exists.is_valid() else ResourceLoader.exists)
	return checker.errors


func _check_all(files: Dictionary, audio_exists: Callable) -> void:
	var names := {"cards": "cards.json", "spots": "spots.json", "dialogue": "dialogue/hem.json",
			"layout": "world/hem_layout.json", "ui": "ui.json", "messages": "messages.json",
			"voices": "voices.json", "sounds": "sounds.json", "manifest": "assets/voices/manifest.json"}
	for key: String in names:
		if not _is_dict(files.get(key), names[key], "file"):
			return
	var card_ids := _check_cards(files.cards)
	var lines := _check_dialogue(files.dialogue, card_ids)
	var spot_ids := _check_spots(files.spots, files.dialogue, card_ids, lines)
	_check_layout(files.layout, spot_ids, files.spots)
	_check_ui(files.ui)
	_check_messages(files.messages, files.dialogue, card_ids)
	_check_voices(files.voices, files.dialogue)
	_check_sounds(files.sounds)
	_check_audio(files.dialogue, files.voices, files.manifest, audio_exists)
	for key: String in names:
		if key != "manifest":
			_check_text_nfc(files[key], names[key])


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


## Checks the dialogue file. Returns the lines: line ID -> "speech" or "text".
func _check_dialogue(dialogue: Dictionary, card_ids: Dictionary) -> Dictionary:
	var file := "dialogue/hem.json"
	var kinds := {}
	var speakers: Dictionary = {}
	if _require(dialogue, "speakers", TYPE_DICTIONARY, file, "file"):
		speakers = dialogue.speakers
	if _require(dialogue, "say_again", TYPE_DICTIONARY, file, "file"):
		if _require(dialogue.say_again, "vi", TYPE_STRING, file, "say_again") \
				and not "{address}" in dialogue.say_again.vi:
			_error(file, "say_again", "\"vi\" must have \"{address}\"")
		_require(dialogue.say_again, "en", TYPE_STRING, file, "say_again")
		_check_status(dialogue.say_again, file, "say_again")
	if _require(dialogue, "strings", TYPE_DICTIONARY, file, "file"):
		for field: String in ["status_open", "status_closed", "someone"]:
			_require(dialogue.strings, field, TYPE_STRING, file, "strings")
	if not _require(dialogue, "lines", TYPE_DICTIONARY, file, "file"):
		return kinds
	for line_id: String in dialogue.lines:
		var line: Variant = dialogue.lines[line_id]
		if typeof(line) == TYPE_DICTIONARY:
			kinds[line_id] = "speech" if line.has("speaker") else "text"
	for key: String in speakers:
		var where := "speaker \"%s\"" % key
		var speaker: Variant = speakers[key]
		if not _is_dict(speaker, file, where):
			continue
		_require(speaker, "name", TYPE_STRING, file, where)
		_require(speaker, "color", TYPE_STRING, file, where)
		if _require(speaker, "address", TYPE_STRING, file, where) and not ADDRESS_FORMS.has(speaker.address):
			_error(file, where, "address \"%s\" must be one of %s" % [speaker.address, ADDRESS_FORMS])
		if speaker.has("call_after"):
			_check_speech_ref(speaker.call_after, kinds, file, where, "call_after")
			var call: Variant = dialogue.lines.get(speaker.call_after)
			if typeof(call) == TYPE_DICTIONARY and call.get("speaker") != key:
				_error(file, where, "the line \"%s\" of \"call_after\" must have the speaker \"%s\"" % [speaker.call_after, key])
	for line_id: String in dialogue.lines:
		var line: Variant = dialogue.lines[line_id]
		var where := "line \"%s\"" % line_id
		if not _is_dict(line, file, where):
			continue
		_check_status(line, file, where)
		if not line.has("speaker"):
			_require(line, "text", TYPE_STRING, file, where)
			for field: String in ["replies", "actions", "then", "vi"]:
				if line.has(field):
					_error(file, where, "a line without a speaker is a description: it cannot have \"%s\"" % field)
			continue
		if not speakers.has(line.speaker):
			_error(file, where, "speaker \"%s\" does not exist" % line.speaker)
		_require(line, "vi", TYPE_STRING, file, where)
		_require(line, "en", TYPE_STRING, file, where)
		if line.has("text"):
			_error(file, where, "a spoken line has \"vi\" and \"en\", not \"text\"")
		if line.has("say"):
			_require(line, "say", TYPE_STRING, file, where)
		if line.has("voice_style") and (typeof(line.voice_style) != TYPE_STRING \
				or not String(line.voice_style).begins_with("[") or not String(line.voice_style).ends_with("]")):
			_error(file, where, "\"voice_style\" must be a tag like \"[cười]\"")
		if line.has("then"):
			_check_speech_ref(line.then, kinds, file, where, "then")
		if line.has("learn"):
			_check_card_refs(line.learn, card_ids, file, where)
		_check_replies(line, kinds, card_ids, file, where)
	return kinds


## Checks that a field points to a spoken line.
func _check_speech_ref(value: Variant, kinds: Dictionary, file: String, where: String, field: String) -> void:
	if typeof(value) != TYPE_STRING or not kinds.has(value):
		_error(file, where, "\"%s\" points to line ID \"%s\" that does not exist" % [field, value])
	elif kinds[value] != "speech":
		_error(file, where, "\"%s\" points to line \"%s\" that has no speaker" % [field, value])


func _check_replies(line: Dictionary, kinds: Dictionary, card_ids: Dictionary, file: String, where: String) -> void:
	var ids := {}
	for field: String in ["replies", "actions"]:
		if not line.has(field):
			continue
		if typeof(line[field]) != TYPE_ARRAY:
			_error(file, where, "\"%s\" must be a list" % field)
			continue
		for i in line[field].size():
			var entry: Variant = line[field][i]
			var kind := "reply" if field == "replies" else "action"
			var ewhere := "%s %s %d" % [where, kind, i]
			if not _is_dict(entry, file, ewhere):
				continue
			if _require(entry, "id", TYPE_STRING, file, ewhere):
				ewhere = "%s %s \"%s\"" % [where, kind, entry.id]
				if ids.has(entry.id):
					_error(file, ewhere, "the ID is not unique in the line")
				ids[entry.id] = true
			if entry.has("learn"):
				_check_card_refs(entry.learn, card_ids, file, ewhere)
			for next_field: String in ["next", "next_said"]:
				if entry.has(next_field):
					_check_speech_ref(entry[next_field], kinds, file, ewhere, next_field)
			if field == "actions":
				_require(entry, "verb", TYPE_STRING, file, ewhere)
				_require(entry, "next", TYPE_STRING, file, ewhere)
				if _require(entry, "target", TYPE_STRING, file, ewhere) \
						and not (entry.target.begins_with("spot.") or entry.target.begins_with("npc.")):
					_error(file, ewhere, "\"target\" must be a test ID like \"spot.pho\" or \"npc.batu\"")
			elif entry.get("english", false):
				_require(entry, "en", TYPE_STRING, file, ewhere)
				if entry.has("vi"):
					_error(file, ewhere, "an English reply has \"en\" only")
			else:
				_require(entry, "vi", TYPE_STRING, file, ewhere)
				_require(entry, "en", TYPE_STRING, file, ewhere)


## Checks a list of time rules in "field". Each rule points to a line of
## the kind ("speech" or "text"). "speaker" (when it is not "") is the speaker
## that each spoken line must have.
func _check_line_rules(item: Dictionary, field: String, kind: String, card_ids: Dictionary,
		lines: Dictionary, dialogue: Dictionary, file: String, where: String, speaker := "") -> void:
	if not _require(item, field, TYPE_ARRAY, file, where):
		return
	var rules: Array = item[field]
	if rules.is_empty():
		_error(file, where, "\"%s\" must have one or more rules" % field)
		return
	for i in rules.size():
		var rule: Variant = rules[i]
		var rwhere := "%s %s rule %d" % [where, field, i]
		if not _is_dict(rule, file, rwhere):
			continue
		if _require(rule, "line", TYPE_STRING, file, rwhere):
			if not lines.has(rule.line):
				_error(file, rwhere, "line ID \"%s\" does not exist" % rule.line)
			elif lines[rule.line] != kind:
				_error(file, rwhere, "line \"%s\" must be %s" % [rule.line,
						"a spoken line" if kind == "speech" else "a description (no speaker)"])
			elif speaker != "" and dialogue.lines[rule.line].get("speaker") != speaker:
				_error(file, rwhere, "line \"%s\" must have the speaker \"%s\"" % [rule.line, speaker])
		_check_time_rule(rule, file, rwhere)
		if rule.has("learn"):
			_check_card_refs(rule.learn, card_ids, file, rwhere)
	var last: Variant = rules[rules.size() - 1]
	if typeof(last) == TYPE_DICTIONARY and (last.has("open") or last.has("from") or last.has("before")):
		_error(file, where, "the last rule in \"%s\" must have no condition" % field)


func _check_spots(spots: Dictionary, dialogue: Dictionary, card_ids: Dictionary, lines: Dictionary) -> Dictionary:
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
			for field: String in ["name", "en"]:
				_require(spot, field, TYPE_STRING, file, where)
			if spot.has("verb"):
				_require(spot, "verb", TYPE_STRING, file, where)
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
			_check_line_rules(spot, "lens", "text", card_ids, lines, dialogue, file, where)
	if _require(spots, "npcs", TYPE_ARRAY, file, "file"):
		var speakers: Dictionary = dialogue.get("speakers", {})
		for i in spots.npcs.size():
			var npc: Variant = spots.npcs[i]
			var where := "npc %d" % i
			if not _is_dict(npc, file, where):
				continue
			var npc_id := ""
			if _require(npc, "id", TYPE_STRING, file, where):
				npc_id = npc.id
				where = "npc \"%s\"" % npc.id
				if not speakers.has(npc.id):
					_error(file, where, "the person has no speaker \"%s\" in dialogue/hem.json" % npc.id)
			_require(npc, "name", TYPE_STRING, file, where)
			_check_hours(npc, file, where)
			_check_status(npc, file, where)
			if npc.get("talk", true):
				_require(npc, "verb", TYPE_STRING, file, where)
				_check_line_rules(npc, "lines", "speech", card_ids, lines, dialogue, file, where, npc_id)
			elif npc.has("lines"):
				_error(file, where, "a person with \"talk\": false has no \"lines\"")
			for field: String in ["chat", "calls"]:
				if not npc.has(field):
					continue
				var fwhere := "%s %s" % [where, field]
				if not _is_dict(npc[field], file, fwhere):
					continue
				if _require(npc[field], "line", TYPE_STRING, file, fwhere):
					_check_speech_ref(npc[field].line, lines, file, fwhere, "line")
				if _require(npc[field], "every_s", TYPE_FLOAT, file, fwhere) and npc[field].every_s <= 0:
					_error(file, fwhere, "\"every_s\" must be more than 0")
	if _require(spots, "boats_in", TYPE_DICTIONARY, file, "file"):
		_check_time_rule(spots.boats_in, file, "boats_in")
	return ids


func _check_messages(messages: Dictionary, dialogue: Dictionary, card_ids: Dictionary) -> void:
	var file := "messages.json"
	if _require(messages, "sender", TYPE_DICTIONARY, file, "file"):
		_require(messages.sender, "name", TYPE_STRING, file, "sender")
		_require(messages.sender, "color", TYPE_STRING, file, "sender")
		if _require(messages.sender, "speaker", TYPE_STRING, file, "sender") \
				and not dialogue.get("speakers", {}).has(messages.sender.speaker):
			_error(file, "sender", "speaker \"%s\" does not exist" % messages.sender.speaker)
	if not _require(messages, "messages", TYPE_ARRAY, file, "file"):
		return
	var ids := {}
	var lines: Dictionary = dialogue.get("lines", {})
	for i in messages.messages.size():
		var message: Variant = messages.messages[i]
		var where := "message %d" % i
		if not _is_dict(message, file, where):
			continue
		if _require(message, "id", TYPE_STRING, file, where):
			where = "message \"%s\"" % message.id
			if ids.has(message.id):
				_error(file, where, "message ID is not unique")
			ids[message.id] = true
		_require(message, "text", TYPE_STRING, file, where)
		_check_status(message, file, where)
		if not message.has("at") and not message.has("after"):
			_error(file, where, "a message must have \"at\" or \"after\"")
		for field: String in ["at", "before"]:
			if message.has(field):
				_check_minute(message[field], file, where, field)
		if message.has("day") and (typeof(message.day) not in [TYPE_INT, TYPE_FLOAT] or message.day < 1):
			_error(file, where, "\"day\" must be a day number (1 or more)")
		if message.has("after"):
			var after := str(message.after)
			if after.begins_with("heard:") or after.begins_with("lens:"):
				if not lines.has(after.get_slice(":", 1)):
					_error(file, where, "\"after\" points to line ID \"%s\" that does not exist" % after.get_slice(":", 1))
			elif not MESSAGE_EVENTS.has(after):
				_error(file, where, "\"after\" must be %s, \"heard:LINE\", or \"lens:LINE\"" % [MESSAGE_EVENTS])
		if message.has("unless_card") and not card_ids.has(message.unless_card):
			_error(file, where, "card ID \"%s\" does not exist" % message.unless_card)


func _check_voices(voices: Dictionary, dialogue: Dictionary) -> void:
	var file := "voices.json"
	for field: String in ["model", "package", "phone"]:
		_require(voices, field, TYPE_STRING, file, "file")
	if not _require(voices, "speakers", TYPE_DICTIONARY, file, "file"):
		return
	for speaker_id: String in dialogue.get("speakers", {}):
		if typeof(voices.speakers.get(speaker_id)) != TYPE_STRING:
			_error(file, "speakers", "the speaker \"%s\" has no voice" % speaker_id)


func _check_sounds(sounds: Dictionary) -> void:
	var file := "sounds.json"
	if not _require(sounds, "sounds", TYPE_DICTIONARY, file, "file"):
		return
	for sound_id: String in sounds.sounds:
		var where := "sound \"%s\"" % sound_id
		if not _is_dict(sounds.sounds[sound_id], file, where):
			continue
		var sound: Dictionary = sounds.sounds[sound_id]
		if not sound.has("caption") or typeof(sound.caption) != TYPE_STRING:
			_error(file, where, "required field \"caption\" is missing")
		_require(sound, "range_m", TYPE_FLOAT, file, where)
		_check_status(sound, file, where)


## Checks that each clip has an audio file with the correct hash (R4).
func _check_audio(dialogue: Dictionary, voices: Dictionary, manifest: Dictionary, audio_exists: Callable) -> void:
	var file := "assets/voices/manifest.json"
	var clips: Variant = manifest.get("clips")
	if typeof(clips) != TYPE_DICTIONARY:
		_error(file, "file", "required field \"clips\" is missing")
		return
	if typeof(voices.get("speakers")) != TYPE_DICTIONARY:
		return
	for clip: Dictionary in VoiceClips.expected(dialogue, voices):
		var where := "clip \"%s\"" % clip.id
		var entry: Variant = clips.get(clip.id)
		if typeof(entry) != TYPE_DICTIONARY:
			_error(file, where, "the clip has no audio file. Run tools/voices/build.py (CI: the voices workflow).")
			continue
		if entry.get("hash") != clip.hash:
			_error(file, where, "the text, the voice, or the model changed. Run tools/voices/build.py (CI: the voices workflow).")
		if typeof(entry.get("duration_s")) not in [TYPE_INT, TYPE_FLOAT] or entry.duration_s <= 0.0:
			_error(file, where, "\"duration_s\" must be more than 0")
		if not audio_exists.call(VoiceClips.path(clip.id)):
			_error(file, where, "the file %s is missing" % VoiceClips.path(clip.id))


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
	for field: String in ["notebook_title", "notebook_count", "notebook_locked", "notebook_hint",
			"clock_title", "clock_hint", "settings_title", "settings_sensitivity", "settings_invert",
			"settings_gyro", "settings_fov", "settings_tap_walk", "center_view", "too_far", "phone_button",
			"home", "listen_on", "listen_off", "listen_empty", "listen_save_hint", "phrasebook_title",
			"phrasebook_empty", "reply_play", "reply_say", "reply_english", "said_title", "said_done",
			"phrase_saved", "lens_empty", "lens_person", "messages_empty", "notify_card", "notify_message",
			"clock_day", "clock_rest", "clock_sleep_away", "notebook_phrases", "notebook_no_phrases",
			"settings_sound", "settings_subtitles", "settings_subtitle_size", "settings_subtitle_box"]:
		_require(ui, field, TYPE_STRING, file, "file")
	if _require(ui, "apps", TYPE_DICTIONARY, file, "file"):
		for app: String in ["listen", "lens", "messages", "notebook", "clock", "settings"]:
			_require(ui.apps, app, TYPE_STRING, file, "apps")
	if _require(ui, "subtitle_languages", TYPE_DICTIONARY, file, "file"):
		for language: String in SUBTITLE_IDS:
			_require(ui.subtitle_languages, language, TYPE_STRING, file, "subtitle_languages")
	if _require(ui, "tones", TYPE_DICTIONARY, file, "file"):
		for tone: String in ["ngang", "huyền", "sắc", "hỏi", "ngã", "nặng"]:
			_require(ui.tones, tone, TYPE_STRING, file, "tones")
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
			if choice.has("minutes") and (typeof(choice.minutes) not in [TYPE_INT, TYPE_FLOAT] or choice.minutes <= 0):
				_error(file, where, "\"minutes\" must be a number more than 0")
			if choice.has("until"):
				_check_minute(choice.until, file, where, "until")


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
