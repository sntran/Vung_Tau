class_name StartProfile
extends RefCounted
## Plan 0031, D17 and R17: the profile of the start. Each part of the start
## marks its end; a part is the time from the mark before. The first mark
## counts from the start of the engine. On a computer the argument
## --start-profile prints the parts when the scooter or the player can move;
## on the web the page gets them (window.vungTau.profile, tools/web/check.js).

static var _parts: Array = []
static var _last_usec := -1


## The end of a part of the start.
static func mark(part: String) -> void:
	var now := Time.get_ticks_usec()
	var from := _last_usec if _last_usec >= 0 else 0
	_parts.append([part, (now - from) / 1000.0])
	_last_usec = now


## The parts: [name, ms], in order.
static func parts() -> Array:
	return _parts.duplicate(true)


## The sum of the parts (ms).
static func total_ms() -> float:
	var sum := 0.0
	for part: Array in _parts:
		sum += float(part[1])
	return sum


## The parts as lines of text.
static func text() -> String:
	var lines: Array[String] = []
	for part: Array in _parts:
		lines.append("%8.0f ms  %s" % [float(part[1]), part[0]])
	lines.append("%8.0f ms  in all" % total_ms())
	return "\n".join(lines)


## The parts as JSON for the page.
static func json() -> String:
	return JSON.stringify(_parts)


static func clear() -> void:
	_parts.clear()
	_last_usec = -1
