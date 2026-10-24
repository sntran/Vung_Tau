extends GutTest
## Tests for the save format and save and load (R13).

const GameStateScript := preload("res://autoload/game_state.gd")
const PATH := "user://test/save_format.json"


func after_each() -> void:
	DirAccess.remove_absolute(PATH)


func _state() -> Dictionary:
	return {
		"day": 3, "minutes": 725, "walk_m": 2.5, "cards": ["anSang", "coc"],
		"flags": {"intro_done": true}, "sound": false, "player": Vector3(13.25, 0, -0.6),
	}


func test_round_trip() -> void:
	var data := SaveFormat.from_json(SaveFormat.to_json(_state()))
	assert_eq(data.day, 3)
	assert_eq(data.minutes, 725)
	assert_almost_eq(data.walk_m, 2.5, 0.001)
	assert_eq(data.cards, ["anSang", "coc"] as Array[String])
	assert_eq(data.flags, {"intro_done": true})
	assert_eq(data.sound, false)
	assert_almost_eq(data.player.x, 13.25, 0.001)
	assert_almost_eq(data.player.z, -0.6, 0.001)


func test_save_has_version() -> void:
	var json: Dictionary = JSON.parse_string(SaveFormat.to_json(_state()))
	assert_eq(int(json.version), SaveFormat.VERSION)


func test_other_version_is_not_loaded() -> void:
	var json: Dictionary = JSON.parse_string(SaveFormat.to_json(_state()))
	json.version = SaveFormat.VERSION + 1
	assert_eq(SaveFormat.from_json(JSON.stringify(json)), {})
	json.erase("version")
	assert_eq(SaveFormat.from_json(JSON.stringify(json)), {})


func test_bad_text_is_not_loaded() -> void:
	assert_eq(SaveFormat.from_json(""), {})
	assert_eq(SaveFormat.from_json("not json"), {})
	assert_eq(SaveFormat.from_json("[1, 2]"), {})
	assert_eq(SaveFormat.from_json("{\"version\": 1}"), {})
	assert_eq(SaveFormat.from_json("{\"version\": 1, \"day\": 1, \"minutes\": 5000, \"cards\": [], \"player\": {\"x\": 0, \"z\": 0}}"), {})


func test_duplicate_cards_are_removed() -> void:
	var state := _state()
	state.cards = ["coc", "coc", "anSang"]
	assert_eq(SaveFormat.from_json(SaveFormat.to_json(state)).cards, ["coc", "anSang"] as Array[String])


func test_game_state_save_and_load() -> void:
	var a: Node = autofree(GameStateScript.new())
	a.save_path = PATH
	a.new_game()
	a.learn("anSang")
	a.add_minutes(30)
	a.player_pos = Vector3(9, 0, 0)
	a.save_game()
	var b: Node = autofree(GameStateScript.new())
	b.save_path = PATH
	assert_true(b.load_game())
	assert_eq(b.minutes, 390)
	assert_eq(b.cards, ["anSang"] as Array[String])
	assert_almost_eq(b.player_pos.x, 9.0, 0.001)


func test_game_state_other_version_starts_new_game() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{\"version\": 999, \"day\": 7}")
	file.close()
	var state: Node = autofree(GameStateScript.new())
	state.save_path = PATH
	assert_false(state.load_game())
	assert_eq(state.day, 1)
	assert_eq(state.minutes, 360)


func test_game_state_broken_file_starts_new_game() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{ broken")
	file.close()
	var state: Node = autofree(GameStateScript.new())
	state.save_path = PATH
	assert_false(state.load_game())
	assert_eq(state.day, 1)
