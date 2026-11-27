extends GutTest
## Report 0031, D-0031-06: in CI the player of PT-74 run 1 was inside the body
## of a walker for 174 physics steps. A walker moved once in each frame and
## checked its gap to the player only at the end of the move. In a long frame
## of game time (the run plays 6 times faster, and CI gave about 4 frames each
## second: 1.3 s to 1.7 s of game time in a frame) a walker moved more than two
## times its gap and came out past the player, through the place of the body
## of the player. A walker now moves in steps of at most STEP_M in a frame.


func _walker(people: ShowcasePeople, at: float) -> Dictionary:
	var model := WorldModel.make("walker_1")
	people.add_child(model)
	var line := PackedVector3Array([Vector3(0, 0, 0), Vector3(40, 0, 0)])
	var w := {"model": model, "body": null, "line": line, "length": 40.0, "at": at, "speed": 1.6,
			"sign": 1.0, "side": 0.0, "now": 0.0, "room": 0.7, "stopped": false, "shot": "", "held": false}
	people.walkers.append(w)
	model.transform = people._walker_transform(w)
	return w


func test_a_walker_does_not_pass_through_the_player_in_a_long_frame() -> void:
	var people := ShowcasePeople.new()
	add_child_autofree(people)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.current = true
	# The player 2 m in front of the walker: out of STOP_GAP, so the walker walks.
	camera.global_position = Vector3(7.0, 1.6, 0.0)
	var w := _walker(people, 5.0)
	people._process(1.7)
	var x := (w.model as WorldModel).global_position.x
	assert_lt(x, 7.0 - ShowcasePeople.KEEP_GAP + 0.001, "the walker stays in front of the player: x %.2f" % x)
