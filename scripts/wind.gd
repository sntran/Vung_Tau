class_name Wind
extends RefCounted
## The wind of the game (plan 0020, D6, R8). The tree shaders read the global
## shader values wind_direction (the direction on the ground that the wind
## blows to, in game X and Z) and wind_strength (0 calm, 1 strong). The values
## of the day and the night are in data/trees/types.json ("wind").

## The strength and the direction now.
static var strength := 0.3
static var direction := Vector2(0.8, 0.6)
## True when the wind stays as it is and the clock does not change it (a play-test setup, PT-55).
static var held := false


## Sets the wind.
static func apply(to_direction: Vector2, to_strength: float) -> void:
	direction = to_direction.normalized() if to_direction.length() > 0.001 else Vector2(1.0, 0.0)
	strength = clampf(to_strength, 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("wind_direction", direction)
	RenderingServer.global_shader_parameter_set("wind_strength", strength)


## Sets the wind and keeps it: the clock does not change it any more.
static func hold(to_direction: Vector2, to_strength: float) -> void:
	held = true
	apply(to_direction, to_strength)


## The wind of a clock time from the values of the file: stronger in the
## afternoon, weaker at night. from_degrees is where the wind comes from
## (0 north, 90 east).
static func of_time(values: Dictionary, minutes: int) -> Dictionary:
	var hour := minutes / 60.0
	var day := float(values.get("day", 0.45))
	var night := float(values.get("night", 0.2))
	# Strongest at 15:00, weakest at 03:00.
	var t := 0.5 + 0.5 * cos((hour - 15.0) / 24.0 * TAU)
	var from := deg_to_rad(float(values.get("from_degrees", 45.0)))
	# Game X is east and game Z is south. The wind blows away from where it comes from.
	var to := Vector2(-sin(from), cos(from))
	return {"direction": to, "strength": lerpf(night, day, t)}
