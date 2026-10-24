class_name ScriptedSensorSource
extends SensorSource
## A gyroscope source for the play tests. It gives a fixed rate until a time.

var rate := Vector2.ZERO
var _end_msec := 0


## Gives the rate (x: yaw, y: pitch, in radians per second) for some seconds.
func play(look: Vector2, seconds: float) -> void:
	rate = look
	_end_msec = Time.get_ticks_msec() + int(seconds * 1000.0)


func look_rate() -> Vector2:
	if Time.get_ticks_msec() >= _end_msec:
		return Vector2.ZERO
	return rate


func has_data() -> bool:
	return true
