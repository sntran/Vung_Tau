class_name GameClock
extends RefCounted
## Clock math. Time is the number of minutes from midnight (0 to 1439).

const MINUTES_PER_DAY := 1440
## The last minute of a day. The clock stops here until the player sleeps.
const LAST_MINUTE := 1439
## A new game starts at 06:00.
const START_MINUTES := 360
## After "Sleep until morning", the day starts at 05:45.
const WAKE_MINUTES := 345
## At 23:30 or later, the only choice is "Go home and sleep".
const LATE_MINUTES := 1410
## Walking: 1 game minute for each 8 m.
const METERS_PER_MINUTE := 8.0


## Returns the time as text, for example "6:00" or "18:30".
static func format_time(minutes: int) -> String:
	var m := posmod(minutes, MINUTES_PER_DAY)
	return "%d:%02d" % [m / 60, m % 60]


## Parses "HH:MM" and returns the minutes. Returns -1 when the text is not a time.
static func parse_time(text: String) -> int:
	var parts := text.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return -1
	var h := parts[0].to_int()
	var m := parts[1].to_int()
	if h < 0 or h > 23 or m < 0 or m > 59:
		return -1
	return h * 60 + m


## Returns true when the spot is open. "hours" is null (always open) or
## a dictionary with "open" and "close". A spot is open when open <= minutes < close.
static func is_open(hours: Variant, minutes: int) -> bool:
	if hours == null:
		return true
	return minutes >= int(hours.open) and minutes < int(hours.close)


## Returns true when the minutes agree with a time rule.
## A rule can have "from" (inclusive) and "before" (exclusive). A rule with
## neither value agrees with all minutes.
static func in_range(rule: Dictionary, minutes: int) -> bool:
	if rule.has("from") and minutes < int(rule.from):
		return false
	if rule.has("before") and minutes >= int(rule.before):
		return false
	return true


## Returns the part of the day for the minutes. "parts" is the list
## "parts_of_day" from ui.json. Each part has "before", "vi", and "en".
static func part_of_day(minutes: int, parts: Array) -> Dictionary:
	for part: Dictionary in parts:
		if minutes < int(part.before):
			return part
	return parts[parts.size() - 1] if not parts.is_empty() else {"vi": "", "en": ""}


## Returns the time after the player waits, or -1 when the choice moves no time.
## "choice" has "minutes" (wait that long) or "until" (wait until that time).
## The time stops at the last minute of the day.
static func wait_target(choice: Dictionary, minutes: int) -> int:
	var target := -1
	if choice.has("minutes"):
		target = mini(minutes + int(choice.minutes), LAST_MINUTE)
	elif choice.has("until"):
		target = int(choice.until)
	if target <= minutes:
		return -1
	return target


## Returns the clock choices that the player can use now. A wait choice shows
## only when its time is later than now. The sleep choice always shows.
static func clock_choices(choices: Array, minutes: int) -> Array:
	var result := []
	for choice: Dictionary in choices:
		if choice.get("sleep", false) or wait_target(choice, minutes) >= 0:
			result.append(choice)
	return result
