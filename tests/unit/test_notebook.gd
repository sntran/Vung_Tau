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


## Plan 0018, R1 (D6): one second of the frames is one second of the clock.
func test_frames_move_the_clock() -> void:
	for i in 59 * 60:
		state.advance(1.0 / 60.0)
	assert_eq(state.minutes, 360, "59 s of frames are less than one minute")
	for i in 60:
		state.advance(1.0 / 60.0)
	assert_eq(state.minutes, 361, "60 s of frames give 1 minute")
	assert_almost_eq(state.seconds, 0.0, 0.01)
	state.advance(150.0)
	assert_eq(state.minutes, 363, "150 s more are two minutes and 30 s")
	assert_almost_eq(state.seconds, 30.0, 0.01)


func test_the_clock_runs_with_the_frames_only_when_it_runs() -> void:
	state.clock_running = false
	await wait_frames(10)
	assert_eq(state.seconds, 0.0, "the clock does not move while the world loads at the start")
	state.clock_running = true
	await wait_frames(10)
	assert_gt(state.seconds, 0.0, "the frames move the clock")


func test_a_walk_does_not_move_the_clock() -> void:
	state.add_walk(100.0)
	assert_eq(state.minutes, 360, "a walk of 100 m gives no minute")
	assert_almost_eq(state.walked_total_m, 100.0, 0.001, "the play tests still read the walked meters")


func test_a_time_cost_a_wait_and_the_sleep_still_move_the_clock() -> void:
	state.add_minutes(15)
	assert_eq(state.minutes, 375, "an action with a time cost of 15 minutes")
	state.advance(20.0)
	state.wait_until(600)
	assert_eq(state.minutes, 600, "a wait of the Clock app")
	assert_eq(state.seconds, 0.0, "a wait starts the minute at 0 s")
	state.sleep_until_morning()
	assert_eq(state.minutes, 345, "the sleep")


func test_frames_stop_at_the_last_minute() -> void:
	state.set_minutes(1438)
	state.advance(200.0)
	assert_eq(state.minutes, 1439, "the clock stops at 23:59 until the player sleeps")
	state.advance(200.0)
	assert_eq(state.minutes, 1439)


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
