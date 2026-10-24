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

var cards: Dictionary = {}
var spots: Dictionary = {}
var dialogue: Dictionary = {}
var layout: Dictionary = {}
var ui: Dictionary = {}
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
	var parsed := {}
	for path: String in [CARDS_PATH, SPOTS_PATH, DIALOGUE_PATH, LAYOUT_PATH, UI_PATH]:
		parsed[path] = read_json(path)
	cards = _as_dict(parsed[CARDS_PATH])
	spots = _as_dict(parsed[SPOTS_PATH])
	dialogue = _as_dict(parsed[DIALOGUE_PATH])
	layout = _as_dict(parsed[LAYOUT_PATH])
	ui = _as_dict(parsed[UI_PATH])
	errors.append_array(ContentChecker.check_all(parsed[CARDS_PATH], parsed[SPOTS_PATH],
			parsed[DIALOGUE_PATH], parsed[LAYOUT_PATH], parsed[UI_PATH]))
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


## Returns the first line rule that agrees with the time. "item" is a spot
## or an NPC. The rule "open" agrees when the open state is the same.
func line_rule(item: Dictionary, minutes: int) -> Dictionary:
	var open := GameClock.is_open(item.get("hours"), minutes)
	for rule: Dictionary in item.get("lines", []):
		if rule.has("open") and bool(rule.open) != open:
			continue
		if GameClock.in_range(rule, minutes):
			return rule
	return {}


## Returns the hẻm tip rule for the time and the known cards.
func hem_tip(minutes: int, known_cards: Array) -> Dictionary:
	for rule: Dictionary in spots.get("hem_tips", []):
		if rule.has("missing_card") and known_cards.has(rule.missing_card):
			continue
		if GameClock.in_range(rule, minutes):
			return rule
	return {}


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
