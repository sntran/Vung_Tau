extends GutTest
## Tests for the notebook and the game state (R10, R12).

const GameStateScript := preload("res://autoload/game_state.gd")

var state: Node


func before_each() -> void:
	state = GameStateScript.new()
	state.save_path = "user://test/notebook_save.json"
	state.new_game()
	add_child_autofree(state)


func after_all() -> void:
	DirAccess.remove_absolute("user://test/notebook_save.json")


func test_new_game() -> void:
	assert_eq(state.day, 1)
	assert_eq(state.minutes, 360)
	assert_eq(state.cards, [] as Array[String])


func test_learn_keeps_each_card_one_time() -> void:
	watch_signals(state)
	assert_true(state.learn("anSang"))
	assert_false(state.learn("anSang"), "the second learn is not new")
	assert_eq(state.cards, ["anSang"] as Array[String])
	assert_signal_emit_count(state, "card_learned", 1)


func test_learn_unknown_card_does_nothing() -> void:
	assert_false(state.learn("no_such_card"))
	assert_eq(state.cards.size(), 0)


func test_walk_moves_the_clock() -> void:
	state.add_walk(7.9)
	assert_eq(state.minutes, 360, "7.9 m is less than one minute")
	state.add_walk(0.1)
	assert_eq(state.minutes, 361, "8 m is one minute")
	state.add_walk(20.0)
	assert_eq(state.minutes, 363, "20 m more is two minutes and 4 m left over")
	assert_almost_eq(state.walk_m, 4.0, 0.001)


func test_clock_stops_at_last_minute() -> void:
	state.set_minutes(1430)
	state.add_minutes(60)
	assert_eq(state.minutes, 1439)


func test_wait_until_only_moves_forward() -> void:
	state.wait_until(660)
	assert_eq(state.minutes, 660)
	state.wait_until(600)
	assert_eq(state.minutes, 660)


func test_sleep_until_morning() -> void:
	watch_signals(state)
	state.set_minutes(1200)
	state.player_pos = Vector3(20, 0, 1)
	state.sleep_until_morning()
	assert_eq(state.day, 2)
	assert_eq(state.minutes, 345)
	assert_eq(state.player_pos, GameStateScript.HOME_DOOR)
	assert_signal_emitted(state, "slept")


func test_late() -> void:
	state.set_minutes(1409)
	assert_false(state.is_late())
	state.set_minutes(1410)
	assert_true(state.is_late())
