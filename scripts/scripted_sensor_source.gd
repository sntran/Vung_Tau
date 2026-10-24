class_name ScriptedSensorSource
extends SensorSource
## A gyroscope source for the play tests. It gives a fixed rate for some
## seconds of game time. At a low frame rate, the game time is slower than the
## real time, so the source does not use the real time.

var rate := Vector2.ZERO
var _left := 0.0


## Gives the rate (x: yaw, y: pitch, in radians per second) for some seconds.
func play(look: Vector2, seconds: float) -> void:
	rate = look
	_left = seconds


## True while the rate plays.
func playing() -> bool:
	return _left > 0.0


func look_rate() -> Vector2:
	return rate if _left > 0.0 else Vector2.ZERO


func turn(delta: float) -> Vector2:
	var time := minf(delta, _left)
	_left = maxf(0.0, _left - delta)
	return rate * time


func has_data() -> bool:
	return true
