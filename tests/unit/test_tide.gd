extends GutTest
## Tests for the tide and the calendar (plan 0005, R8f, R17).

const LUNAR_DATES := [
	[[2019, 2, 5], [1, 1, false]], [[2020, 1, 25], [1, 1, false]], [[2021, 2, 12], [1, 1, false]],
	[[2022, 2, 1], [1, 1, false]], [[2023, 1, 22], [1, 1, false]], [[2024, 2, 10], [1, 1, false]],
	[[2025, 1, 29], [1, 1, false]], [[2026, 2, 17], [1, 1, false]], [[2027, 2, 6], [1, 1, false]],
	[[2024, 9, 17], [15, 8, false]], [[2025, 10, 6], [15, 8, false]], [[2023, 9, 29], [15, 8, false]],
	[[2023, 3, 22], [1, 2, true]], [[2020, 5, 23], [1, 4, true]], [[2025, 7, 25], [1, 6, true]],
	[[2025, 8, 23], [1, 7, false]], [[2026, 10, 24], [15, 9, false]], [[2000, 2, 5], [1, 1, false]],
	[[2033, 12, 22], [1, 11, true]], [[2024, 2, 9], [30, 12, false]],
]


func test_sea_level_agrees_with_the_test_values() -> void:
	var model := TideModel.open()
	assert_not_null(model, "data/geo/build/tide.json is there")
	if model == null:
		return
	assert_eq(model.tests.size(), 200)
	var worst := 0.0
	for test: Array in model.tests:
		worst = maxf(worst, absf(model.level(float(test[0])) - float(test[1])))
	assert_true(worst <= 0.02, "the sea level agrees with pyTMD within 0.02 m: %.4f m" % worst)


func test_lunar_dates() -> void:
	for item: Array in LUNAR_DATES:
		var solar: Array = item[0]
		var expected: Array = item[1]
		var lunar := Lunar.from_solar(solar[2], solar[1], solar[0])
		assert_eq([lunar.day, lunar.month, lunar.leap], expected, "%s" % [solar])


func test_julian_days() -> void:
	assert_eq(Lunar.jd_from_date(1, 1, 1970), 2440588)
	assert_eq(Lunar.date_from_jd(2440588), {"day": 1, "month": 1, "year": 1970})
	assert_eq(Lunar.date_from_jd(Lunar.jd_from_date(29, 2, 2028)), {"day": 29, "month": 2, "year": 2028})


func test_game_calendar() -> void:
	var date := GameCalendar.date_of(1)
	assert_eq(date, Lunar.date_from_jd(GameCalendar.day_one_jd()))
	assert_eq(GameCalendar.date_of(2), Lunar.date_from_jd(GameCalendar.day_one_jd() + 1))
	# 06:00 on day 1 (UTC+7) is 23:00 UTC of the day before.
	var unix := GameCalendar.unix_time(1, 360)
	var utc := Time.get_datetime_dict_from_unix_time(int(unix))
	assert_eq(utc.hour, 23)
	assert_true(GameCalendar.text(1).ends_with("âm lịch"))
