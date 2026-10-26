class_name GameCalendar
extends RefCounted
## The real calendar of the game (plan 0005, D13). Day 1 is a real date
## (data/calendar.json). The command line argument --start-date=YYYY-MM-DD
## makes day 1 another date (the play tests use it, like --start-time).

const PATH := "res://data/calendar.json"
const TIME_ZONE_S := 7 * 3600

static var _day_one_jd := -1


## The Julian day number of day 1.
static func day_one_jd() -> int:
	if _day_one_jd < 0:
		var text := GameState.arg_value("start-date")
		if text == "":
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			text = str(data.get("day_one", "2019-01-22")) if data is Dictionary else "2019-01-22"
		var parts := text.split("-")
		_day_one_jd = Lunar.jd_from_date(int(parts[2]), int(parts[1]), int(parts[0]))
	return _day_one_jd


## The solar date {year, month, day} of a day of the game.
static func date_of(game_day: int) -> Dictionary:
	return Lunar.date_from_jd(day_one_jd() + game_day - 1)


## The lunar date {day, month, year, leap} of a day of the game.
static func lunar_of(game_day: int) -> Dictionary:
	var date := date_of(game_day)
	return Lunar.from_solar(date.day, date.month, date.year)


## The day of the year (1 to 366) of a day of the game.
static func day_of_year(game_day: int) -> int:
	var date := date_of(game_day)
	return Lunar.jd_from_date(date.day, date.month, date.year) - Lunar.jd_from_date(1, 1, date.year) + 1


## The time in seconds since 1970-01-01 (UTC) of a moment of the game.
static func unix_time(game_day: int, minutes: float) -> float:
	# The Julian day 2440588 is 1970-01-01.
	var days := day_one_jd() + game_day - 1 - 2440588
	return days * 86400.0 + minutes * 60.0 - TIME_ZONE_S


## The date as text: "22/1/2019 · 17/12 âm lịch".
static func text(game_day: int) -> String:
	var date := date_of(game_day)
	var lunar := lunar_of(game_day)
	return "%d/%d/%d · %d/%d%s âm lịch" % [date.day, date.month, date.year, lunar.day, lunar.month,
			" nhuận" if lunar.leap else ""]
