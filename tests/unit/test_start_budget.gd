extends GutTest
## Plan 0031, D12 and D19: the time of the work of the start in each frame:
## at least START_FRAME_MS, the time of the last frame (the start builds with
## all the time of each frame), at most START_FRAME_MAX_MS; with a limit of
## the frame rate, 80 % of the time of a frame at least. Only the start of the
## web build (GameState.web_start()) takes the time of the last frame; a
## computer keeps START_FRAME_MS (report 0031, round 4: in CI the first frames
## of a run with no shader cache took 28 s to 37 s more with the time of the
## last frame).


func test_a_fast_frame_gives_the_least_time() -> void:
	assert_almost_eq(VungTau.start_budget_ms(30.0, 0), VungTau.START_FRAME_MS, 0.001)


func test_a_slow_frame_gives_its_own_time() -> void:
	assert_almost_eq(VungTau.start_budget_ms(640.0, 0), 640.0, 0.001)


func test_the_time_has_a_limit() -> void:
	assert_almost_eq(VungTau.start_budget_ms(5000.0, 0), VungTau.START_FRAME_MAX_MS, 0.001)


func test_a_limit_of_the_frame_rate_gives_most_of_a_frame() -> void:
	assert_almost_eq(VungTau.start_budget_ms(30.0, 3), 0.8 * 1000.0 / 3.0, 0.01)
	assert_almost_eq(VungTau.start_budget_ms(900.0, 3), 900.0, 0.01)


func test_a_computer_keeps_the_time_of_before() -> void:
	assert_almost_eq(VungTau.start_budget_ms(640.0, 0, false), VungTau.START_FRAME_MS, 0.001)
	assert_almost_eq(VungTau.start_budget_ms(5000.0, 0, false), VungTau.START_FRAME_MS, 0.001)
	assert_almost_eq(VungTau.start_budget_ms(900.0, 3, false), 0.8 * 1000.0 / 3.0, 0.01)


## Plan 0031, D19: only the web build makes the far stairs in steps after "can
## move". A computer makes a whole stairs in a frame, as before (in CI the
## steps of 8 ms held is_settled() for hundreds of slow frames of lavapipe).
func test_the_far_stairs_build_in_steps_only_on_the_web() -> void:
	assert_almost_eq(VungTau.stairs_budget_ms(true), VungTau.STAIRS_FRAME_MS, 0.001)
	assert_eq(VungTau.stairs_budget_ms(false), INF)
