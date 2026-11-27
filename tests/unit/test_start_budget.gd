extends GutTest
## Plan 0031, D12 and D19: the time of the work of the start in each frame:
## at least START_FRAME_MS, the time of the last frame (the start builds with
## all the time of each frame), at most START_FRAME_MAX_MS; with a limit of
## the frame rate, 80 % of the time of a frame at least.


func test_a_fast_frame_gives_the_least_time() -> void:
	assert_almost_eq(VungTau.start_budget_ms(30.0, 0), VungTau.START_FRAME_MS, 0.001)


func test_a_slow_frame_gives_its_own_time() -> void:
	assert_almost_eq(VungTau.start_budget_ms(640.0, 0), 640.0, 0.001)


func test_the_time_has_a_limit() -> void:
	assert_almost_eq(VungTau.start_budget_ms(5000.0, 0), VungTau.START_FRAME_MAX_MS, 0.001)


func test_a_limit_of_the_frame_rate_gives_most_of_a_frame() -> void:
	assert_almost_eq(VungTau.start_budget_ms(30.0, 3), 0.8 * 1000.0 / 3.0, 0.01)
	assert_almost_eq(VungTau.start_budget_ms(900.0, 3), 900.0, 0.01)
