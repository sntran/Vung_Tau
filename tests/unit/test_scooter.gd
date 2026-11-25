extends GutTest
## Plan 0018: the motion of the scooter (D2, D4) and the parked scooters (R4).

const STEP := 1.0 / 60.0


func _run(motion: ScooterMotion, seconds: float, throttle: float, brake: float, steer: float, dt := STEP, keys := false) -> void:
	var steps := int(round(seconds / dt))
	for i in steps:
		motion.step(dt, throttle, brake, steer, keys)


func test_top_speed_and_the_time_to_it() -> void:
	var motion := ScooterMotion.new()
	_run(motion, 4.0, 1.0, 0.0, 0.0)
	assert_almost_eq(motion.speed_kmh(), 20.0, 0.3, "0 to 20 km/h in 4 s (D2: 0 to 40 km/h in about 8 s)")
	_run(motion, 4.0, 1.0, 0.0, 0.0)
	assert_almost_eq(motion.speed_kmh(), 40.0, 0.3, "40 km/h after 8 s")
	_run(motion, 20.0, 1.0, 0.0, 0.0)
	assert_almost_eq(motion.speed_kmh(), 40.0, 0.001, "never more than 40 km/h (D2)")


func test_the_brake_and_the_push_back() -> void:
	var motion := ScooterMotion.new()
	motion.speed = 10.0
	_run(motion, 1.0, 0.0, 1.0, 0.0)
	assert_almost_eq(motion.speed, 6.0, 0.05, "the brake takes 4 m/s² (D2)")
	_run(motion, 2.0, 0.0, 1.0, 0.0)
	assert_lt(motion.speed, 0.0, "when the scooter stands, the brake pushes it back with the feet (D8)")
	assert_almost_eq(motion.speed, -ScooterMotion.PUSH_BACK, 0.001, "slowly: 0.5 m/s")


func test_the_turn_of_the_handlebars_gets_smaller_with_the_speed() -> void:
	var motion := ScooterMotion.new()
	assert_almost_eq(motion.max_steer(), 35.0, 0.001, "35° when the scooter stands")
	motion.speed = ScooterMotion.TOP_SPEED
	assert_almost_eq(motion.max_steer(), 2.0, 0.1, "about 2° at the top speed (D4)")
	motion.speed = 5.0
	motion.steer = 0.0
	_run(motion, 2.0, 0.0, 0.0, 1.0)
	assert_almost_eq(motion.steer, motion.max_steer(), 0.5, "full right gives the largest turn")
	assert_almost_eq(motion.turn_radius(), ScooterMotion.WHEELBASE / tan(deg_to_rad(motion.steer)), 0.001,
			"the turn radius comes from the wheelbase")


## R5 (D4, changed 2026-11-23): the full turn at 5, 10, 20, 30, and 40 km/h
## gives a side acceleration of at most 3.5 m/s². The turn of the handlebars
## is at most 35°: about 30° at 10 km/h, 8° at 20 km/h, 2° at 40 km/h.
func test_the_full_turn_gives_at_most_3_5_m_s2_to_the_side() -> void:
	var expected := {5.0: 35.0, 10.0: 29.7, 20.0: 8.1, 30.0: 3.6, 40.0: 2.0}
	for kmh: float in expected:
		for side: float in [1.0, -1.0]:
			var motion := ScooterMotion.new()
			motion.speed = kmh / 3.6
			var most := 0.0
			# The full turn, with the full stick up.
			for i in 120:
				var throttle := 1.0 if motion.speed < kmh / 3.6 else 0.0
				motion.step(STEP, throttle, 0.0, side)
				most = maxf(most, _side_acceleration(motion))
			assert_lte(most, ScooterMotion.SIDE_ACCELERATION + 0.01,
					"%.0f km/h, side %+.0f: %.2f m/s² to the side (R5)" % [kmh, side, most])
			assert_almost_eq(ScooterMotion.max_steer_at(kmh / 3.6), float(expected[kmh]), 0.3,
					"%.0f km/h: the largest turn of the handlebars %.1f°" % [kmh, ScooterMotion.max_steer_at(kmh / 3.6)])
			# The full stick to a side also slows the scooter (D11): the turn is the largest at the speed now.
			assert_almost_eq(absf(motion.steer), motion.max_steer(), 0.5,
					"%.0f km/h: the full stick gives the largest turn at the speed now (%.1f km/h)" % [kmh, motion.speed_kmh()])
			assert_lte(absf(motion.steer), ScooterMotion.STEER_SLOW + 0.001, "at most 35°")
	# A turn held while the scooter speeds up: the turn gets smaller with the speed.
	var motion := ScooterMotion.new()
	motion.speed = 2.0
	for i in 600:
		motion.step(STEP, 1.0, 0.0, 1.0)
		assert_lte(_side_acceleration(motion), ScooterMotion.SIDE_ACCELERATION + 0.01,
				"a held turn while the speed goes up: %.1f km/h" % motion.speed_kmh())


static func _side_acceleration(motion: ScooterMotion) -> float:
	return absf(motion.speed * motion.yaw_rate())


func test_a_turn_to_the_right_leans_to_the_right_at_most_8_degrees() -> void:
	var motion := ScooterMotion.new()
	motion.speed = ScooterMotion.TOP_SPEED
	var heading := motion.heading
	_run(motion, 2.0, 1.0, 0.0, 1.0)
	assert_lt(motion.heading, heading, "a turn to the right makes the heading smaller (as Player.yaw)")
	assert_gt(motion.lean, 0.0, "the lean goes to the right")
	assert_lte(motion.lean, ScooterMotion.MAX_LEAN, "at most 8° (D3)")


## D4: the physics runs 60 steps each second at each frame rate; the motion of
## a ride with the same input is the same. At 3 frames each second the input
## changes only at each frame (20 steps), and the path stays the same.
func test_the_motion_is_the_same_at_each_frame_rate() -> void:
	var fast := ScooterMotion.new()
	var slow := ScooterMotion.new()
	var fast_at := Vector3.ZERO
	var slow_at := Vector3.ZERO
	for second in 10:
		var steer := 0.6 if second % 4 < 2 else -0.4
		for i in 60:
			fast.step(STEP, 1.0, 0.0, steer)
			fast_at += fast.velocity() * STEP
		# 3 frames: the input of the frame for 20 steps each.
		for frame in 3:
			for i in 20:
				slow.step(STEP, 1.0, 0.0, steer)
				slow_at += slow.velocity() * STEP
	assert_almost_eq(fast.speed, slow.speed, 0.0001, "the same speed")
	assert_almost_eq(fast.heading, slow.heading, 0.0001, "the same heading")
	assert_lt(fast_at.distance_to(slow_at), 0.001, "the same place")


func test_a_scooter_leaves_its_row_and_comes_back() -> void:
	var row := WorldRow.new()
	add_child_autofree(row)
	var red := Color("#B0302A")
	for i in 3:
		row.add(Parked.MODEL, Transform3D(Basis(), Vector3(i * 1.0, 0, 0)), red, {"stand": 60.0})
	row.build()
	var items := row.items_of(Parked.MODEL)
	assert_eq(items.size(), 3, "the row gives its scooters")
	row.set_hidden(1, true)
	var hidden := 0
	var shown := 0
	for cell: Dictionary in row.cells:
		for node: MultiMeshInstance3D in cell.near:
			var buffer := node.multimesh.buffer
			for i in node.multimesh.instance_count:
				var size := Vector3(buffer[16 * i], buffer[16 * i + 4], buffer[16 * i + 8]).length()
				if size < 0.001:
					hidden += 1
				else:
					shown += 1
	assert_gt(hidden, 0, "the ridden scooter has no size in the MultiMeshes of its cell")
	assert_gt(shown, 0, "the other scooters stay")
	assert_true(row.items_of(Parked.MODEL)[1].hidden)
	row.set_hidden(1, false)
	assert_false(row.items_of(Parked.MODEL)[1].hidden, "it can come back")


## R12 (D10): the stick gives the speed that the rider wants. Half up holds
## 20 km/h within 1 km/h, from below and from above.
func test_half_up_holds_20_km_h() -> void:
	var motion := ScooterMotion.new()
	_run(motion, 10.0, 0.5, 0.0, 0.0)
	assert_almost_eq(motion.speed_kmh(), 20.0, 1.0, "half up from a stop: 20 km/h (D10)")
	_run(motion, 10.0, 0.5, 0.0, 0.0)
	assert_almost_eq(motion.speed_kmh(), 20.0, 1.0, "half up holds 20 km/h")
	motion.speed = ScooterMotion.TOP_SPEED
	_run(motion, 10.0, 0.5, 0.0, 0.0)
	assert_almost_eq(motion.speed_kmh(), 20.0, 1.0, "half up from 40 km/h: down to 20 km/h")


## R12 (D10): with no stick, the engine slows the scooter at 1.5 m/s²: from
## 40 km/h it has 20 km/h after 3.5 s to 4.0 s, and then it stops.
func test_no_stick_slows_at_1_5_m_s2() -> void:
	var motion := ScooterMotion.new()
	motion.speed = ScooterMotion.TOP_SPEED
	var at_20 := -1.0
	var t := 0.0
	while t < 10.0:
		motion.step(STEP, 0.0, 0.0, 0.0)
		t += STEP
		if at_20 < 0.0 and motion.speed_kmh() <= 20.0:
			at_20 = t
	assert_between(at_20, 3.5, 4.0, "no stick: from 40 km/h to 20 km/h in %.2f s (D10: 1.5 m/s²)" % at_20)
	assert_almost_eq(motion.speed, 0.0, 0.001, "and then the scooter stops")


## R12 (D11, D4): the full stick to a side from 40 km/h: the scooter slows to
## 12 km/h (at most 2.5 m/s²) and turns by 90° in a square of 25 m, with at
## most 3.5 m/s² to the side. With the key D, the same after 0.4 s.
func test_the_full_stick_to_a_side_makes_a_tight_turn() -> void:
	for keys: bool in [false, true]:
		var motion := ScooterMotion.new()
		motion.speed = ScooterMotion.TOP_SPEED
		var heading := motion.heading
		var at := Vector3.ZERO
		var most_side := 0.0
		var most_slow := 0.0
		var t := 0.0
		var turned := 0.0
		while t < 10.0 and turned < 90.0:
			var before := motion.speed
			motion.step(STEP, 0.0, 0.0, 1.0, keys)
			at += motion.velocity() * STEP
			t += STEP
			most_side = maxf(most_side, absf(motion.speed * motion.yaw_rate()))
			most_slow = maxf(most_slow, (before - motion.speed) / STEP)
			turned = absf(wrapf(motion.heading - heading, -180.0, 180.0))
		var label := "the key D" if keys else "the stick"
		assert_gte(turned, 90.0, "%s: the scooter turns by 90° (in %.1f s)" % [label, t])
		assert_lte(maxf(absf(at.x), absf(at.z)), 25.0, "%s: in a square of 25 m: %s" % [label, at])
		assert_lte(most_side, ScooterMotion.SIDE_ACCELERATION + 0.01, "%s: at most 3.5 m/s² to the side (D4): %.2f" % [label, most_side])
		assert_lte(most_slow, ScooterMotion.TIGHT_SLOW + 0.01, "%s: it slows at most at 2.5 m/s² (D11): %.2f" % [label, most_slow])
	# The stick at 0.8 to the side keeps the top speed; at 0.9 the middle.
	var half := ScooterMotion.new()
	half.speed = ScooterMotion.TOP_SPEED
	_run(half, 8.0, 1.0, 0.0, 0.79)
	assert_almost_eq(half.speed_kmh(), 40.0, 0.5, "under 0.8 to the side the speed stays (D11)")
	_run(half, 8.0, 1.0, 0.0, 0.9)
	assert_almost_eq(half.speed_kmh(), 26.0, 0.5, "0.9 to the side: the middle of 40 km/h and 12 km/h (D11)")


## D11: with the keys, the tight turn starts after 0.4 s of the key held.
func test_a_key_makes_the_turn_tight_after_0_4_s() -> void:
	var motion := ScooterMotion.new()
	motion.speed = ScooterMotion.TOP_SPEED
	_run(motion, 0.35, 1.0, 0.0, 1.0, STEP, true)
	assert_almost_eq(motion.speed_kmh(), 40.0, 0.1, "in the first 0.4 s of the key the speed stays")
	_run(motion, 1.0, 1.0, 0.0, 1.0, STEP, true)
	assert_lt(motion.speed_kmh(), 35.0, "after 0.4 s of the key the scooter slows for the turn")
	var stick := ScooterMotion.new()
	stick.speed = ScooterMotion.TOP_SPEED
	_run(stick, 0.35, 1.0, 0.0, 1.0)
	assert_lt(stick.speed_kmh(), 39.0, "with the stick the tight turn starts at once")


## D12: the words of the hint for the touch screen, the keys, and a gamepad are in data/ui.json.
func test_the_words_of_the_hint_are_in_the_data() -> void:
	assert_string_contains(Content.ui_text("scooter_hint_touch"), "brake")
	assert_string_contains(Content.ui_text("scooter_hint_keys"), "W go")
	assert_string_contains(Content.ui_text("scooter_hint_keys"), "E get off")
	assert_string_contains(Content.ui_text("scooter_hint_gamepad"), "brake")
