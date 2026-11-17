extends RefCounted
# PT-75 showcase_people (plan 0026, R10, R11). At 17:00 the area of the
# showcase has 30 to 50 people, and at 12:00 fewer. Nobody stands in another
# person, in a tree, or in a wall or a part of the showcase. The walkers walk:
# each of them moves along its way in 2 s of game time. The row of parked
# scooters in front of the bars of Quang Trung is there. The swimmers of R10
# wait for the swim clothes and the swim rings of World (request Q-W6): the
# test says that there are none yet. Screenshots of the people of the park and
# of the walk. Report 0026, D-0026-07: at 17:00, PT-75 counts the people in the
# frame of each shot of data/showcase/shots.json (nearer than PEOPLE_RANGE, not
# behind a building) and expects at least the "people" of the shot.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=17:00 --quality=low
# phase: --world=vung_tau --start-time=12:00 --quality=low

## The eye and the aim of a shot, as PT-72 takes it.
const Shots := preload("res://playtests/showcase_shots.gd")
## A person farther than this from the eye of a shot does not count in it (m).
const PEOPLE_RANGE := 90.0
## Two people closer than this (m, from foot to foot) stand in each other.
const MIN_GAP := 0.5
## A person nearer than this (m) to the trunk of a tree stands in it.
const TREE_GAP := 0.35
const VIEWS := [
	["park", Vector3(46.0, 0.0, 84.0), Vector3(30.0, 0.0, 20.0)],
	["walk", Vector3(-97.0, 0.0, -311.0), Vector3(-50.0, 0.0, -255.0)],
]


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.showcase != null and await d.wait_showcase() and w.showcase.people != null,
			"the showcase has its people"):
		return
	var people: ShowcasePeople = w.showcase.people
	await d.wait_frames(10)
	var noon := d.phase == 2
	var count := people.shown_count()
	if noon:
		d.expect(count > 0 and count < 30, "at 12:00 there are fewer people: %d" % count)
	else:
		d.expect(count >= 30 and count <= 50, "at 17:00 there are 30 to 50 people: %d" % count)
	d.step("the swimmers of R10 wait for the swim clothes and the swim rings of World (Q-W6): 0 swimmers")
	# Where each person stands.
	var feet: Array[Vector3] = []
	for entry: Dictionary in people.walkers + people.sitters:
		var model: WorldModel = entry.model
		if model.visible:
			feet.append(model.global_position)
	var crowded := 0
	for i in feet.size():
		for j in range(i + 1, feet.size()):
			if Vector2(feet[i].x - feet[j].x, feet[i].z - feet[j].z).length() < MIN_GAP:
				crowded += 1
	d.expect(crowded == 0, "nobody stands in another person: %d pairs closer than %.1f m" % [crowded, MIN_GAP])
	var in_trees := 0
	for p in feet:
		if not w.trees.all_trees_near(p, TREE_GAP).is_empty():
			in_trees += 1
	d.expect(in_trees == 0, "nobody stands in a tree: %d people" % in_trees)
	# A wall or a part: the collision of the showcase at the height of the knees.
	var space := w.get_world_3d().direct_space_state
	var in_walls := 0
	for p in feet:
		var query := PhysicsPointQueryParameters3D.new()
		query.position = p + Vector3(0, 0.5, 0)
		query.collision_mask = Layers.FLOOR | Layers.SOLID
		for hit: Dictionary in space.intersect_point(query, 8):
			var collider: Object = hit.collider
			if collider is Node and (collider as Node).name != "Sitters":
				in_walls += 1
				break
	d.expect(in_walls == 0, "nobody stands in a wall or a part: %d people" % in_walls)
	# The walkers walk.
	var before: Array[Vector3] = []
	for entry: Dictionary in people.walkers:
		before.append((entry.model as WorldModel).global_position)
	await d.wait_seconds(2.0)
	var moved := 0
	var shown := 0
	for i in people.walkers.size():
		var model: WorldModel = people.walkers[i].model
		if model.visible:
			shown += 1
			if model.global_position.distance_to(before[i]) > 0.5:
				moved += 1
	d.expect(moved == shown, "each walker walks: %d of %d moved in 2 s" % [moved, shown])
	var parked: Dictionary = w.parked.rows.get("quang_trung_bars", {}) if w.parked else {}
	d.expect(not parked.is_empty() and (parked.points as Array).size() > 0, "the scooters stand in front of the bars of Quang Trung")
	if not noon:
		await _count_in_shots(d, w, people)
	for view: Array in VIEWS:
		var eye: Vector3 = view[1]
		var target: Vector3 = view[2]
		eye.y = w.ground_height(eye.x, eye.z) + Player.EYE_HEIGHT
		target.y = w.ground_height(target.x, target.z) + 1.0
		await d.fly_to(eye, target)
		await d.wait_ground(60.0)
		await d.wait_frames(6)
		await d.screenshot("%s_%s" % [view[0], "1200" if noon else "1700"])
	d.fly_end()


## Report 0026, D-0026-07: the people in the frame of each shot at 17:00.
func _count_in_shots(d: PlaytestDriver, w: VungTau, people: ShowcasePeople) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(Shots.SHOTS))
	if not d.expect(data is Dictionary, "the shots can be read"):
		return
	var camera := d.viewport().get_camera_3d()
	var fov := camera.fov
	for shot: Dictionary in data.shots:
		var eye := Shots.eye_of(w, shot)
		await d.fly_to(eye, Shots.aim(shot, eye))
		camera = d.viewport().get_camera_3d()
		camera.fov = float(shot.get("fov", fov))
		await d.wait_ground(60.0)
		await d.wait_frames(3)
		var count := 0
		for entry: Dictionary in people.walkers + people.sitters:
			var model: WorldModel = entry.model
			if not model.visible:
				continue
			var head := model.global_position + Vector3(0, 1.5, 0)
			if eye.distance_to(head) > PEOPLE_RANGE or camera.is_position_behind(head) or not camera.is_position_in_frustum(head):
				continue
			if Shots._hidden_by(w, eye, head) != "":
				continue
			count += 1
		var least := int(shot.get("people", 0))
		d.step("%s: %d people in the frame (at least %d)" % [shot.id, count, least])
		d.expect(count >= least, "%s: at 17:00 the frame has at least %d people: %d" % [shot.id, least, count])
		await d.screenshot("people_%s" % shot.id)
	camera.fov = fov
	d.fly_end()
