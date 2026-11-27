class_name FrameStats
extends RefCounted
## Plan 0031, R18 and R19: the frames after "can move" (ms of real time): their
## count, the median frame, and the longest frame. The page reads them
## (window.vungTau.frames: tools/web/check.js, PT-85), and the line of the
## times gives the longest frame.

var _frames: PackedFloat32Array = PackedFloat32Array()
var _longest := 0.0


func add(ms: float) -> void:
	_frames.append(ms)
	_longest = maxf(_longest, ms)


func count() -> int:
	return _frames.size()


func longest_ms() -> float:
	return _longest


## The median frame, or 0 with no frames.
func median_ms() -> float:
	if _frames.is_empty():
		return 0.0
	var sorted := _frames.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func to_dict() -> Dictionary:
	return {"count": count(), "medianMs": median_ms(), "longestMs": longest_ms()}
