extends GutTest
## Tests for the clock math (R9, R10).

const PARTS := [
	{"before": 240, "vi": "đêm", "en": "night"},
	{"before": 630, "vi": "sáng", "en": "morning"},
	{"before": 780, "vi": "trưa", "en": "noon"},
	{"before": 1080, "vi": "chiều", "en": "afternoon"},
	{"before": 1320, "vi": "tối", "en": "evening"},
	{"before": 1440, "vi": "đêm", "en": "night"},
]


func test_format_time() -> void:
	assert_eq(GameClock.format_time(0), "0:00")
	assert_eq(GameClock.format_time(360), "6:00")
	assert_eq(GameClock.format_time(345), "5:45")
	assert_eq(GameClock.format_time(1110), "18:30")
	assert_eq(GameClock.format_time(1439), "23:59")


func test_parse_time() -> void:
	assert_eq(GameClock.parse_time("06:00"), 360)
	assert_eq(GameClock.parse_time("21:40"), 1300)
	assert_eq(GameClock.parse_time("0:00"), 0)
	assert_eq(GameClock.parse_time("24:00"), -1)
	assert_eq(GameClock.parse_time("6"), -1)
	assert_eq(GameClock.parse_time("ab:cd"), -1)


func test_start_and_wake_times() -> void:
	assert_eq(GameClock.START_MINUTES, 360, "a new game starts at 06:00")
	assert_eq(GameClock.WAKE_MINUTES, 345, "the next day starts at 05:45")
	assert_eq(GameClock.LATE_MINUTES, 1410, "late starts at 23:30")


func test_part_of_day_edges() -> void:
	assert_eq(GameClock.part_of_day(0, PARTS).vi, "đêm")
	assert_eq(GameClock.part_of_day(239, PARTS).vi, "đêm")
	assert_eq(GameClock.part_of_day(240, PARTS).vi, "sáng")
	assert_eq(GameClock.part_of_day(629, PARTS).vi, "sáng")
	assert_eq(GameClock.part_of_day(630, PARTS).vi, "trưa")
	assert_eq(GameClock.part_of_day(780, PARTS).vi, "chiều")
	assert_eq(GameClock.part_of_day(1080, PARTS).vi, "tối")
	assert_eq(GameClock.part_of_day(1320, PARTS).vi, "đêm")
	assert_eq(GameClock.part_of_day(1439, PARTS).vi, "đêm")


func test_wait_target_hour_stops_at_last_minute() -> void:
	var hour := {"minutes": 60}
	assert_eq(GameClock.wait_target(hour, 360), 420)
	assert_eq(GameClock.wait_target(hour, 1380), 1439, "23:00 + 1 hour stops at 23:59")
	assert_eq(GameClock.wait_target(hour, 1439), -1, "no time to wait at 23:59")


func test_wait_target_until() -> void:
	var until := {"until": 660}
	assert_eq(GameClock.wait_target(until, 360), 660)
	assert_eq(GameClock.wait_target(until, 659), 660)
	assert_eq(GameClock.wait_target(until, 660), -1, "11:00 is not later than 11:00")
	assert_eq(GameClock.wait_target(until, 700), -1)


func test_clock_choices_show_only_later_times() -> void:
	var choices := [
		{"id": "wait_hour", "minutes": 60},
		{"id": "wait_1100", "until": 660},
		{"id": "wait_1500", "until": 900},
		{"id": "wait_1830", "until": 1110},
		{"id": "wait_2030", "until": 1230},
		{"id": "sleep", "sleep": true},
	]
	var ids := func(m: int) -> Array:
		return GameClock.clock_choices(choices, m).map(func(c: Dictionary) -> String: return c.id)
	assert_eq(ids.call(360), ["wait_hour", "wait_1100", "wait_1500", "wait_1830", "wait_2030", "sleep"])
	assert_eq(ids.call(660), ["wait_hour", "wait_1500", "wait_1830", "wait_2030", "sleep"])
	assert_eq(ids.call(1230), ["wait_hour", "sleep"])
	assert_eq(ids.call(1439), ["sleep"])


func test_in_range() -> void:
	var rule := {"from": 270, "before": 450}
	assert_false(GameClock.in_range(rule, 269))
	assert_true(GameClock.in_range(rule, 270))
	assert_true(GameClock.in_range(rule, 449))
	assert_false(GameClock.in_range(rule, 450))
	assert_true(GameClock.in_range({}, 0), "a rule with no condition agrees with all times")
