class_name SensorSource
extends RefCounted
## The source of the gyroscope data. The game reads the gyroscope only through
## this object (plan 0002, R27). The play-test system replaces it with a
## ScriptedSensorSource.


## Returns the view turn rate from the gyroscope in radians per second:
## x is the yaw rate (positive turns left), y is the pitch rate (positive looks up).
##
## The yaw is the turn around the vertical axis of the world, so it works in
## each screen orientation. The vertical axis comes from the gravity sensor.
## Godot gives the gravity as the reaction force, which points up.
func look_rate() -> Vector2:
	var rate := Input.get_gyroscope()
	if rate.length_squared() < 1e-8:
		return Vector2.ZERO
	var up := Input.get_gravity()
	if up.length_squared() < 0.01:
		# No gravity sensor: guess that the phone is upright in landscape.
		up = Vector3(1, 0, 0)
	up = up.normalized()
	# The camera looks out of the back of the phone (-Z in the phone frame).
	var right := Vector3(0, 0, -1).cross(up).normalized()
	return Vector2(rate.dot(up), rate.dot(right))


## Returns the view turn from the gyroscope in radians during "delta" seconds
## of game time. The play-test system uses game time for its checks.
func turn(delta: float) -> Vector2:
	return look_rate() * delta


## True when the phone has a gyroscope that gives data now.
func has_data() -> bool:
	return Input.get_gyroscope().length_squared() > 1e-8
