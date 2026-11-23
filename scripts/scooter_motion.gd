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
## With no throttle and no brake, the scooter slows by this (m/s²).
const COAST := 0.4
## Back with the feet, when the scooter stands and the player holds the brake (D8).
const PUSH_BACK := 0.5
## The turn of the handlebars at a low speed and at the top speed (D4), in degrees.
const STEER_SLOW := 35.0
const STEER_FAST := 8.0
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


## One step of "dt" seconds. "throttle" and "brake" are 0 to 1; "steer_input"
## is -1 (left) to 1 (right).
func step(dt: float, throttle: float, brake: float, steer_input: float) -> void:
	throttle = clampf(throttle, 0.0, 1.0)
	brake = clampf(brake, 0.0, 1.0)
	if brake > 0.01:
		if speed > 0.01:
			speed = maxf(speed - BRAKE * brake * dt, 0.0)
		elif throttle <= 0.01:
			# The scooter stands: the feet push it back slowly (D8).
			speed = -PUSH_BACK * brake
	elif throttle > 0.01:
		if speed < 0.0:
			speed = minf(speed + BRAKE * dt, 0.0)
		else:
			speed = minf(speed + ACCELERATION * throttle * dt, TOP_SPEED)
	else:
		speed = move_toward(speed, 0.0, COAST * dt)
	speed = clampf(speed, -PUSH_BACK, TOP_SPEED)
	var target := clampf(steer_input, -1.0, 1.0) * max_steer()
	steer = move_toward(steer, target, STEER_RATE * dt)
	var turn_rate := yaw_rate()
	# A turn to the right makes the heading smaller (Player.yaw turns to the left).
	heading -= rad_to_deg(turn_rate) * dt
	var lean_target := clampf(rad_to_deg(atan(speed * turn_rate / GRAVITY)), -MAX_LEAN, MAX_LEAN)
	lean = move_toward(lean, lean_target, 30.0 * dt)
	# The wheels: about 0.25 m of radius.
	wheel_turn = fmod(wheel_turn + rad_to_deg(speed * dt / 0.25), 360.0)


## The largest turn of the handlebars at the speed now (D4): 35° when slow, 8° at the top speed.
func max_steer() -> float:
	return lerpf(STEER_SLOW, STEER_FAST, clampf(absf(speed) / TOP_SPEED, 0.0, 1.0))


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
