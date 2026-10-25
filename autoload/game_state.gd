extends Node
## The state of the game: clock, day, notebook, flags, and the player position.
##
## The state is saved to user://save.json after each change. With the
## command line argument --save-path=PATH, the game uses PATH instead.

signal time_changed(minutes: int, day: int)
signal card_learned(card_id: String)
signal slept
signal sound_changed(on: bool)
## A new message from the host family (plan 0003, R24).
signal message_received(message: Dictionary)

const DEFAULT_SAVE_PATH := "user://save.json"
## The homestay door. The player stands here after "Sleep until morning".
const HOME_DOOR := Vector3(0.0, 0.0, -0.6)

var day := 1
var minutes := GameClock.START_MINUTES
var cards: Array[String] = []
var flags: Dictionary = {}
var sound := true
var player_pos := HOME_DOOR
## The view direction of the player in degrees. The yaw turns around the vertical axis.
var yaw := GameClock.HOME_YAW
var pitch := 0.0
var settings: Dictionary = SaveFormat.DEFAULT_SETTINGS.duplicate()
## The speakers that the player has met (talked with). The Listen app shows
## their names (plan 0003, R19).
var met: Array[String] = []
## The phrases that the player saved from the Listen app to the Sổ tay (R22).
var phrases: Array[Dictionary] = []
## The messages that came, in order: {id, text, day, minutes}.
var messages: Array[Dictionary] = []
## The number of messages that the player has not read.
var unread := 0
## Meters walked since the last full game minute.
var walk_m := 0.0
## All meters walked in this run of the game. Play tests read this value.
var walked_total_m := 0.0
var save_path := DEFAULT_SAVE_PATH

var _save_queued := false


func _init() -> void:
	var path := arg_value("save-path")
	if path != "":
		save_path = path
	load_game()


func _ready() -> void:
	# The first start selects the quality preset (plan 0004, D3).
	if settings.quality == "":
		set_settings({"quality": Quality.default_preset()})
	restart_for_renderer()


## Starts the game again when the quality preset needs another renderer
## (plan 0004, R4). Not in the play tests, in the editor, or when the command
## line selects the renderer. Returns true when the game starts again.
func restart_for_renderer() -> bool:
	if arg_value("playtest") != "" or OS.has_feature("editor") or Quality.renderer_fixed_by_command_line() \
			or not Quality.needs_restart(settings.quality):
		return false
	save_game()
	OS.set_restart_on_exit(true, Quality.restart_args(settings.quality))
	get_tree().quit()
	return true


## Returns the value of a command line argument "--name=value", or "" when it is not there.
static func arg_value(arg_name: String) -> String:
	var prefix := "--%s=" % arg_name
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""


func new_game() -> void:
	day = 1
	minutes = GameClock.START_MINUTES
	cards = []
	flags = {}
	sound = true
	player_pos = HOME_DOOR
	yaw = GameClock.HOME_YAW
	pitch = 0.0
	settings = SaveFormat.DEFAULT_SETTINGS.duplicate()
	walk_m = 0.0
	# Cô Nga introduces herself in her first message, so the player knows her from the start.
	met = ["nga"]
	phrases = []
	messages = []
	unread = 0


## Loads the save file. When there is no correct save, starts a new game.
## Returns true when a save was loaded.
func load_game() -> bool:
	new_game()
	if not FileAccess.file_exists(save_path):
		return false
	var data := SaveFormat.from_json(FileAccess.get_file_as_string(save_path))
	if data.is_empty():
		print("The save file %s has a different version or is not correct. A new game starts." % save_path)
		return false
	day = data.day
	minutes = data.minutes
	walk_m = data.walk_m
	flags = data.flags
	sound = data.sound
	player_pos = data.player
	yaw = data.yaw
	pitch = data.pitch
	settings = data.settings
	met = data.met
	phrases = data.phrases
	messages = data.messages
	unread = data.unread
	cards = []
	for card_id: String in data.cards:
		if Content.has_card(card_id):
			cards.append(card_id)
	return true


func to_dict() -> Dictionary:
	return {
		"day": day, "minutes": minutes, "walk_m": walk_m, "cards": cards,
		"flags": flags, "sound": sound, "player": player_pos, "yaw": yaw, "pitch": pitch,
		"settings": settings, "met": met, "phrases": phrases, "messages": messages, "unread": unread,
	}


## Writes the save file now.
func save_game() -> void:
	_save_queued = false
	var dir := save_path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Cannot write the save file %s (error %d)." % [save_path, FileAccess.get_open_error()])
		return
	file.store_string(SaveFormat.to_json(to_dict()))
	file.close()


## Saves at the end of the frame. Many changes in one frame make one save.
func queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	save_game.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func set_minutes(value: int) -> void:
	value = clampi(value, 0, GameClock.LAST_MINUTE)
	if value == minutes:
		return
	minutes = value
	time_changed.emit(minutes, day)
	queue_save()


## Moves the clock forward. The clock stops at 23:59.
func add_minutes(amount: int) -> void:
	if amount > 0:
		set_minutes(minutes + amount)


## Moves the clock forward to the time, when the time is later than now.
func wait_until(target: int) -> void:
	if target > minutes:
		set_minutes(target)


## Adds walked meters. Each 8 m moves the clock forward 1 minute.
func add_walk(meters: float) -> void:
	if meters <= 0.0:
		return
	walked_total_m += meters
	walk_m += meters
	var whole := int(floor(walk_m / GameClock.METERS_PER_MINUTE))
	if whole > 0:
		walk_m -= whole * GameClock.METERS_PER_MINUTE
		add_minutes(whole)


## The next day starts at 05:45. The player stands at the homestay door.
func sleep_until_morning() -> void:
	day += 1
	minutes = GameClock.WAKE_MINUTES
	walk_m = 0.0
	player_pos = HOME_DOOR
	yaw = GameClock.HOME_YAW
	pitch = 0.0
	time_changed.emit(minutes, day)
	slept.emit()
	queue_save()


func is_late() -> bool:
	return minutes >= GameClock.LATE_MINUTES


## Adds the card to the notebook. Returns true when the card is new.
func learn(card_id: String) -> bool:
	if cards.has(card_id) or not Content.has_card(card_id):
		return false
	cards.append(card_id)
	card_learned.emit(card_id)
	queue_save()
	return true


func knows(card_id: String) -> bool:
	return cards.has(card_id)


func set_flag(flag: String, value: Variant = true) -> void:
	if flags.get(flag) == value:
		return
	flags[flag] = value
	queue_save()


func flag(flag_name: String) -> Variant:
	return flags.get(flag_name, false)


func set_sound(on: bool) -> void:
	sound = on
	sound_changed.emit(on)
	queue_save()


## Records the player position and the view. The world calls this when the player stops.
func set_player_pos(pos: Vector3, view_yaw: float, view_pitch: float) -> void:
	player_pos = pos
	yaw = view_yaw
	pitch = view_pitch
	queue_save()


## Changes the settings and saves them.
func set_settings(value: Dictionary) -> void:
	for key: String in value:
		if settings.has(key):
			settings[key] = value[key]
	queue_save()


## Records that the player met the speaker. Returns true when it is new.
func meet(speaker_id: String) -> bool:
	if met.has(speaker_id):
		return false
	met.append(speaker_id)
	queue_save()
	return true


func has_met(speaker_id: String) -> bool:
	return met.has(speaker_id)


## Saves a phrase to the Sổ tay. Returns false when it is there already.
func save_phrase(vi: String, en: String) -> bool:
	for phrase in phrases:
		if phrase.vi == vi:
			return false
	phrases.append({"vi": vi, "en": en})
	queue_save()
	return true


## Returns true when the message came today (or on any day, for a message that does not repeat).
func has_message(message_id: String, repeat := false) -> bool:
	for message in messages:
		if message.id == message_id and (not repeat or message.day == day):
			return true
	return false


## Adds a message. The Messages app shows it.
func add_message(message_id: String, text: String) -> void:
	var message := {"id": message_id, "text": text, "day": day, "minutes": minutes}
	messages.append(message)
	unread += 1
	message_received.emit(message)
	queue_save()


func read_messages() -> void:
	if unread != 0:
		unread = 0
		queue_save()
