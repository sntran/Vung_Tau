extends GutTest
## Plan 0018: the motion of the scooter (D2, D4) and the parked scooters (R4).

const STEP := 1.0 / 60.0


func _run(motion: ScooterMotion, seconds: float, throttle: float, brake: float, steer: float, dt := STEP) -> void:
	var steps := int(round(seconds / dt))
	for i in steps:
		motion.step(dt, throttle, brake, steer)


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
	assert_almost_eq(motion.max_steer(), 8.0, 0.001, "8° at the top speed (D4)")
	motion.speed = 5.0
	motion.steer = 0.0
	_run(motion, 2.0, 0.0, 0.0, 1.0)
	assert_almost_eq(motion.steer, motion.max_steer(), 0.5, "full right gives the largest turn")
	assert_almost_eq(motion.turn_radius(), ScooterMotion.WHEELBASE / tan(deg_to_rad(motion.steer)), 0.001,
			"the turn radius comes from the wheelbase")


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
