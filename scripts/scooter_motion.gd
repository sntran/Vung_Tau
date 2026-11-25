class_name ScooterMotion
extends RefCounted
## The motion of a scooter (plan 0018, D2, D4): a simple model of a
## two-wheeler, not a physics vehicle. The speed, the turn of the
## handlebars, and a turn radius from the wheelbase. The player body
## (a CharacterBody3D) moves by the velocity of this model.
##
## step() runs in each physics step (60 each second), so the motion is the
## same at each frame rate of the screen.

## The legal top speed of a 50 cm³ moped: 40 km/h (D2).
const TOP_SPEED := 40.0 / 3.6
## From 0 to 40 km/h in about 8 s (D2).
const ACCELERATION := TOP_SPEED / 8.0
## The brake: about 4 m/s² (D2).
const BRAKE := 4.0
## D10: when the rider wants less speed than now, or lets go, the engine
## slows the scooter by this (m/s²): from 40 km/h to 20 km/h in 3.7 s.
const ENGINE_SLOW := 1.5
## D11: the stick held hard to a side (TIGHT_FROM to 1.0 of its sideways part)
## lowers the speed that the scooter keeps from the top speed to TIGHT_SPEED,
## at TIGHT_SLOW at most. With the keys, after KEY_TIGHT_S of the key held.
const TIGHT_FROM := 0.8
const TIGHT_SPEED := 12.0 / 3.6
const TIGHT_SLOW := 2.5
const KEY_TIGHT_S := 0.4
## Back with the feet, when the scooter stands and the player holds the brake (D8).
const PUSH_BACK := 0.5
## The largest turn of the handlebars (D4), in degrees.
const STEER_SLOW := 35.0
## D4 (changed 2026-11-23): the turn of the handlebars gives at most this
## side acceleration (m/s², about 0.35 g) at the speed now: about 30° at
## 10 km/h, 8° at 20 km/h, and 2° at 40 km/h.
const SIDE_ACCELERATION := 3.5
## The handlebars turn not faster than this, in degrees each second.
const STEER_RATE := 90.0
## The distance between the axles (m): the scooter of World, a Honda Vision 110.
const WHEELBASE := 1.255
## The lean in a turn, at most (D3), in degrees.
const MAX_LEAN := 8.0
const GRAVITY := 9.8

## The speed along the heading (m/s); less than 0 when the player pushes back.
var speed := 0.0
## The heading in degrees, as Player.yaw: the front is Basis(UP, heading) * -Z.
var heading := 0.0
## The turn of the handlebars, in degrees: more than 0 is to the right.
var steer := 0.0
## The lean, in degrees: more than 0 is to the right.
var lean := 0.0
## The turn of the wheels, in degrees (for the joints of World).
var wheel_turn := 0.0
## How long a key has held the turn hard to a side (s), for D11.
var _key_hard_s := 0.0


## One step of "dt" seconds. "throttle" is the part of the stick that is up
## (0 to 1), "brake" the part that is down (0 to 1); "steer_input" is -1 (left)
## to 1 (right). "keys": the input comes from keys (D11: the tight turn after
## KEY_TIGHT_S).
func step(dt: float, throttle: float, brake: float, steer_input: float, keys := false) -> void:
	throttle = clampf(throttle, 0.0, 1.0)
	brake = clampf(brake, 0.0, 1.0)
	steer_input = clampf(steer_input, -1.0, 1.0)
	var cap := tight_speed(absf(steer_input), dt, keys)
	if brake > 0.01:
		if speed > 0.01:
			speed = maxf(speed - BRAKE * brake * dt, 0.0)
		elif throttle <= 0.01:
			# The scooter stands: the feet push it back slowly (D8).
			speed = -PUSH_BACK * brake
	elif speed < 0.0:
		speed = minf(speed + BRAKE * dt, 0.0)
	else:
		# D10: the stick gives the speed that the rider wants; D11: a tight turn keeps less.
		var target := minf(throttle * TOP_SPEED, cap)
		if speed < target:
			speed = minf(speed + ACCELERATION * dt, target)
		elif speed > target:
			var slow := TIGHT_SLOW if speed > cap else ENGINE_SLOW
			speed = maxf(speed - slow * dt, target)
	speed = clampf(speed, -PUSH_BACK, TOP_SPEED)
	var limit := max_steer()
	var target := clampf(steer_input, -1.0, 1.0) * limit
	steer = clampf(move_toward(steer, target, STEER_RATE * dt), -limit, limit)
	var turn_rate := yaw_rate()
	# A turn to the right makes the heading smaller (Player.yaw turns to the left).
	heading -= rad_to_deg(turn_rate) * dt
	var lean_target := clampf(rad_to_deg(atan(speed * turn_rate / GRAVITY)), -MAX_LEAN, MAX_LEAN)
	lean = move_toward(lean, lean_target, 30.0 * dt)
	# The wheels: about 0.25 m of radius.
	wheel_turn = fmod(wheel_turn + rad_to_deg(speed * dt / 0.25), 360.0)


## D11: the speed that the scooter keeps for the sideways part of the stick
## (0 to 1): the top speed to TIGHT_FROM, then down to TIGHT_SPEED at 1.0.
## With the keys, only after KEY_TIGHT_S of the key held.
func tight_speed(side: float, dt := 0.0, keys := false) -> float:
	var part := clampf((side - TIGHT_FROM) / (1.0 - TIGHT_FROM), 0.0, 1.0)
	if keys:
		_key_hard_s = _key_hard_s + dt if side >= TIGHT_FROM else 0.0
		if _key_hard_s < KEY_TIGHT_S:
			part = 0.0
	else:
		_key_hard_s = 0.0
	return lerpf(TOP_SPEED, TIGHT_SPEED, part)


## The largest turn of the handlebars at the speed now (D4).
func max_steer() -> float:
	return max_steer_at(speed)


## The largest turn of the handlebars at a speed (m/s): at most STEER_SLOW,
## and at most the turn that gives SIDE_ACCELERATION. The side acceleration
## is speed² / radius, and the radius is WHEELBASE / tan(steer).
static func max_steer_at(at_speed: float) -> float:
	var v2 := at_speed * at_speed
	if v2 < 0.0001:
		return STEER_SLOW
	return minf(STEER_SLOW, rad_to_deg(atan(SIDE_ACCELERATION * WHEELBASE / v2)))


## The turn rate (rad/s): more than 0 turns to the right.
func yaw_rate() -> float:
	if absf(steer) < 0.01:
		return 0.0
	return speed * tan(deg_to_rad(steer)) / WHEELBASE


## The turn radius (m), or INF when the handlebars are straight.
func turn_radius() -> float:
	if absf(steer) < 0.01:
		return INF
	return WHEELBASE / tan(deg_to_rad(absf(steer)))


## The direction of the front.
func forward() -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(heading)) * Vector3(0, 0, -1)


## The velocity on the ground.
func velocity() -> Vector3:
	return forward() * speed


## Stops at once (a hit, D5).
func stop() -> void:
	speed = 0.0


## The speed in km/h.
func speed_kmh() -> float:
	return speed * 3.6
