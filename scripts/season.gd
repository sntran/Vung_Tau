class_name Season
extends RefCounted
## The seasons of Vũng Tàu for the plants (plan 0005, R12a). The dry season is
## November to April: the hills are partly dry, with brown and orange grass and
## bare trees. The rainy season is May to October: the hills are green. Flame
## trees (phượng vĩ) show red flowers around May and June.

## The dryness of the hill grass on the 15th of each month (January first).
## April is the driest (my April photos). Day 1 (22 January) is between the
## rainy and the driest look (report 0005, D-0005-09).
const DRYNESS := [0.45, 0.7, 0.95, 1.0, 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.15, 0.3]
## The flowers of the flame trees on the 15th of each month.
const FLAME_FLOWERS := [0.0, 0.0, 0.0, 0.15, 0.85, 1.0, 0.3, 0.0, 0.0, 0.0, 0.0, 0.0]
## The leaves of the flame trees: they lose most leaves late in the dry season.
const FLAME_LEAVES := [0.45, 0.3, 0.3, 0.5, 0.9, 1.0, 1.0, 1.0, 1.0, 1.0, 0.85, 0.65]


## "dry" or "rainy".
static func name_of(month: int) -> String:
	return "rainy" if month >= 5 and month <= 10 else "dry"


## The value of a table of month values for a date, with a smooth change
## between the middles of the months.
static func _between(table: Array, month: int, day: int) -> float:
	var at := (month - 1) + (day - 15) / 30.0
	var first := floori(at)
	var part := at - first
	var a: float = table[posmod(first, 12)]
	var b: float = table[posmod(first + 1, 12)]
	return lerpf(a, b, part)


## The value of a table of 12 month values (January first) for a date.
static func by_month(table: Array, month: int, day: int) -> float:
	return _between(table, month, day)


## 0 (green) to 1 (the driest) for the hill grass.
static func dryness(month: int, day: int) -> float:
	return _between(DRYNESS, month, day)


## 0 to 1: the flowers of the flame trees.
static func flame_flowers(month: int, day: int) -> float:
	return _between(FLAME_FLOWERS, month, day)


## 0 to 1: the leaves of the flame trees.
static func flame_leaves(month: int, day: int) -> float:
	return _between(FLAME_LEAVES, month, day)


## The part of the hill trees that are bare: some trees lose their leaves in
## the dry season.
static func bare_share(month: int, day: int) -> float:
	return dryness(month, day) * 0.35


## All values for a day of the game.
static func of_day(game_day: int) -> Dictionary:
	var date := GameCalendar.date_of(game_day)
	return {"name": name_of(date.month), "dryness": dryness(date.month, date.day),
			"flame_flowers": flame_flowers(date.month, date.day), "flame_leaves": flame_leaves(date.month, date.day),
			"bare_share": bare_share(date.month, date.day)}
