class_name SaveFormat
extends RefCounted
## The format of the save file. The file is JSON with a "version" field.
## A save with a different version is not loaded. The game then starts new.

const VERSION := 2

## The settings of a new game (plan 0002, R18).
const DEFAULT_SETTINGS := {
	"look_sensitivity": 1.0,
	"invert_y": false,
	"gyro": true,
	"fov": 75.0,
	"tap_walk": true,
}


## Returns the save data as a JSON text.
static func to_json(state: Dictionary) -> String:
	var data := {
		"version": VERSION,
		"day": int(state.day),
		"minutes": int(state.minutes),
		"walk_m": float(state.walk_m),
		"cards": Array(state.cards),
		"flags": Dictionary(state.flags),
		"sound": bool(state.sound),
		"player": {"x": float(state.player.x), "y": float(state.player.y), "z": float(state.player.z),
				"yaw": float(state.yaw), "pitch": float(state.pitch)},
		"settings": Dictionary(state.settings),
	}
	return JSON.stringify(data, "\t")


## Parses a save text. Returns an empty dictionary when the text is not a
## correct save of this version.
static func from_json(text: String) -> Dictionary:
	# JSON.new().parse() does not print an engine error for a bad text.
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	if not data.has("version") or typeof(data.version) not in [TYPE_INT, TYPE_FLOAT]:
		return {}
	if int(data.version) != VERSION:
		return {}
	var day: Variant = data.get("day")
	var minutes: Variant = data.get("minutes")
	var cards: Variant = data.get("cards")
	var player: Variant = data.get("player")
	if typeof(day) not in [TYPE_INT, TYPE_FLOAT] or int(day) < 1:
		return {}
	if typeof(minutes) not in [TYPE_INT, TYPE_FLOAT] \
			or int(minutes) < 0 or int(minutes) > GameClock.LAST_MINUTE:
		return {}
	if typeof(cards) != TYPE_ARRAY:
		return {}
	if typeof(player) != TYPE_DICTIONARY \
			or typeof(player.get("x")) not in [TYPE_INT, TYPE_FLOAT] \
			or typeof(player.get("z")) not in [TYPE_INT, TYPE_FLOAT]:
		return {}
	var card_list: Array[String] = []
	for card: Variant in cards:
		if typeof(card) == TYPE_STRING and not card_list.has(card):
			card_list.append(card)
	var flags: Variant = data.get("flags", {})
	var settings := DEFAULT_SETTINGS.duplicate()
	var saved_settings: Variant = data.get("settings", {})
	if typeof(saved_settings) == TYPE_DICTIONARY:
		for key: String in settings:
			if saved_settings.has(key) and typeof(saved_settings[key]) == typeof(settings[key]):
				settings[key] = saved_settings[key]
			elif saved_settings.has(key) and typeof(settings[key]) == TYPE_FLOAT \
					and typeof(saved_settings[key]) == TYPE_INT:
				settings[key] = float(saved_settings[key])
	return {
		"day": int(day),
		"minutes": int(minutes),
		"walk_m": clampf(float(data.get("walk_m", 0.0)), 0.0, GameClock.METERS_PER_MINUTE),
		"cards": card_list,
		"flags": flags if typeof(flags) == TYPE_DICTIONARY else {},
		"sound": bool(data.get("sound", true)),
		"player": Vector3(float(player.x), float(player.get("y", 0.0)), float(player.z)),
		"yaw": float(player.get("yaw", GameClock.HOME_YAW)),
		"pitch": clampf(float(player.get("pitch", 0.0)), -80.0, 80.0),
		"settings": settings,
	}
