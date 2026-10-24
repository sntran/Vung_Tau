extends Node
## Reads the content data from data/*.json and checks it.
##
## All culture text, names, prices, and opening hours come from these files.
## In a debug build, the game stops with a clear message when the data has
## an error (see ContentChecker).

const CARDS_PATH := "res://data/cards.json"
const SPOTS_PATH := "res://data/spots.json"
const DIALOGUE_PATH := "res://data/dialogue/hem.json"
const LAYOUT_PATH := "res://data/world/hem_layout.json"
const UI_PATH := "res://data/ui.json"
const MESSAGES_PATH := "res://data/messages.json"
const VOICES_PATH := "res://data/voices.json"
const SOUNDS_PATH := "res://data/sounds.json"
const MANIFEST_PATH := "res://assets/voices/manifest.json"

var cards: Dictionary = {}
var spots: Dictionary = {}
var dialogue: Dictionary = {}
var layout: Dictionary = {}
var ui: Dictionary = {}
var messages: Dictionary = {}
var voices: Dictionary = {}
var sounds: Dictionary = {}
## The voice manifest of tools/voices/build.py.
var manifest: Dictionary = {}
var errors: PackedStringArray = []

var _cards_by_id: Dictionary = {}
var _spots_by_id: Dictionary = {}
var _npcs_by_id: Dictionary = {}


func _init() -> void:
	load_all()


func _ready() -> void:
	if errors.is_empty():
		return
	for error in errors:
		push_error("Content error: " + error)
	if OS.is_debug_build():
		printerr("The game stops because the data in data/ has %d error(s). Correct the data, then start again." % errors.size())
		get_tree().quit.call_deferred(1)


## Reads and checks all data files. Returns true when the data is correct.
func load_all() -> bool:
	errors = []
	var paths := {"cards": CARDS_PATH, "spots": SPOTS_PATH, "dialogue": DIALOGUE_PATH, "layout": LAYOUT_PATH,
			"ui": UI_PATH, "messages": MESSAGES_PATH, "voices": VOICES_PATH, "sounds": SOUNDS_PATH,
			"manifest": MANIFEST_PATH}
	var parsed := {}
	for key: String in paths:
		parsed[key] = read_json(paths[key])
	cards = _as_dict(parsed.cards)
	spots = _as_dict(parsed.spots)
	dialogue = _as_dict(parsed.dialogue)
	layout = _as_dict(parsed.layout)
	ui = _as_dict(parsed.ui)
	messages = _as_dict(parsed.messages)
	voices = _as_dict(parsed.voices)
	sounds = _as_dict(parsed.sounds)
	manifest = _as_dict(parsed.manifest)
	errors.append_array(ContentChecker.check_all(parsed))
	_cards_by_id = _index(cards.get("cards", []))
	_spots_by_id = _index(spots.get("spots", []))
	_npcs_by_id = _index(spots.get("npcs", []))
	return errors.is_empty()


## Reads a JSON file. Records an error and returns null when the file is not correct JSON.
func read_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		errors.append("%s: the file is missing or empty" % path)
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s: line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _as_dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _index(items: Variant) -> Dictionary:
	var result := {}
	if typeof(items) != TYPE_ARRAY:
		return result
	for item: Variant in items:
		if typeof(item) == TYPE_DICTIONARY and item.has("id"):
			result[item.id] = item
	return result


## Cards in the order of the data file.
func card_list() -> Array:
	return cards.get("cards", [])


func card_groups() -> Array:
	return cards.get("groups", [])


func card(card_id: String) -> Dictionary:
	return _cards_by_id.get(card_id, {})


func has_card(card_id: String) -> bool:
	return _cards_by_id.has(card_id)


func spot_list() -> Array:
	return spots.get("spots", [])


func spot(spot_id: String) -> Dictionary:
	return _spots_by_id.get(spot_id, {})


func npc(npc_id: String) -> Dictionary:
	return _npcs_by_id.get(npc_id, {})


func line(line_id: String) -> Dictionary:
	return dialogue.get("lines", {}).get(line_id, {})


func has_line(line_id: String) -> bool:
	return dialogue.get("lines", {}).has(line_id)


func speaker(speaker_id: String) -> Dictionary:
	return dialogue.get("speakers", {}).get(speaker_id, {})


func string(key: String) -> String:
	return dialogue.get("strings", {}).get(key, "")


func ui_text(key: String) -> String:
	return str(ui.get(key, ""))


## Returns the first rule of the list (a spot "lens" or a person "lines")
## that agrees with the time.
func rule_for(item: Dictionary, field: String, minutes: int) -> Dictionary:
	var open := GameClock.is_open(item.get("hours"), minutes)
	for rule: Dictionary in item.get(field, []):
		if rule.has("open") and bool(rule.open) != open:
			continue
		if GameClock.in_range(rule, minutes):
			return rule
	return {}


func npc_list() -> Array:
	return spots.get("npcs", [])


func is_speech(line_id: String) -> bool:
	return line(line_id).has("speaker")


## The audio clip of a spoken line or a phrase: {file, duration_s, ...} from the manifest.
func clip(clip_id: String) -> Dictionary:
	return manifest.get("clips", {}).get(clip_id, {})


func clip_duration(clip_id: String) -> float:
	return float(clip(clip_id).get("duration_s", 1.5))


func clip_stream(clip_id: String) -> AudioStream:
	var path := VoiceClips.path(clip_id)
	if not ResourceLoader.exists(path):
		return null
	return load(path)


## The "say again" phrase for the speaker (plan 0003, R20): {vi, en}.
func say_again(speaker_id: String) -> Dictionary:
	return {"vi": VoiceClips.say_again_text(dialogue, speaker_id), "en": dialogue.get("say_again", {}).get("en", "")}


func message_list() -> Array:
	return messages.get("messages", [])


func sender() -> Dictionary:
	return messages.get("sender", {})


func sound(sound_id: String) -> Dictionary:
	return sounds.get("sounds", {}).get(sound_id, {})


func ui_dict(key: String) -> Dictionary:
	var value: Variant = ui.get(key, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


## Returns the opening hours as text, for example "5:30–10:30".
func hours_text(hours: Variant) -> String:
	if hours == null:
		return ""
	return "%s–%s" % [GameClock.format_time(int(hours.open)), GameClock.format_time(int(hours.close))]


## Replaces each "{key}" in the text with the value from "params".
static func format(text: String, params: Dictionary) -> String:
	var result := text
	for key: String in params:
		result = result.replace("{%s}" % key, str(params[key]))
	return result
