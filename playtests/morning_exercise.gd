extends RefCounted
# PT-58 morning_exercise (plan 0023, R9d). Start at 05:30 at Bãi Trước, on the
# paved promenade at the edge of the park, on Low. The aerobics group does its
# routine (the tai chi group with fans waits for World, Q8). Checks: each
# person of data/world/exercise.json is there and moves; no two people are at
# the same time of the routine (each one starts at its own time); the player
# walks into the group with the joystick and does not go through a person;
# with the Clock app the player waits one hour: at 06:30 the group goes away,
# and the player can walk where the people stood. Godot prints no errors.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=05:30 --quality=low --renderer=forward_plus

const GROUP := "aerobics"
## The player and a person do not overlap: the distance of their middles is
## at least this (the radius of the player and of the body of a person, less 5 cm).
const MIN_GAP := 0.45


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.exercise != null, "the Vũng Tàu world has the morning exercise"):
		return
	if not d.expect(w.exercise.groups.has(GROUP), "the group %s is there: %s" % [GROUP, w.exercise.groups.keys()]):
		return
	var g: Dictionary = w.exercise.groups[GROUP]
	var people: Array = g.people
	d.expect(people.size() == 7, "the group has a leader and 6 people: %d" % people.size())
	d.expect((g.node as Node3D).visible, "the group shows at 05:30")
	var off_paving := []
	for m: WorldModel in people:
		var road := w.road_at(m.global_position)
		if road.is_empty() or str(road.get("surface", "")) in ["sand", "grass", "dirt"]:
			off_paving.append("%s %s" % [m.id, road])
	d.step("the way under the leader: %s" % [w.road_at((people[0] as WorldModel).global_position)])
	d.expect(off_paving.is_empty(), "each person stands on the paved promenade at the edge of the park: %s" % [off_paving])
	var center := Vector3.ZERO
	for m: WorldModel in people:
		center += m.global_position
	center /= float(people.size())
	var leader: WorldModel = people[0]
	var facing := (center - leader.global_position) * Vector3(1, 0, 1)
	facing = facing.normalized()
	# The player stands on the promenade, 9 m behind the leader, and looks at the group.
	var start := leader.global_position - facing * 9.0
	await d.start_at(start, rad_to_deg(atan2(-facing.x, -facing.z)))
	await d.wait_ground(120.0)
	await d.wait_frames(10)
	await d.screenshot("group")
	await _check_motion(d, people)
	# Walk through the group: from the leader to the back row.
	var path := PackedVector3Array([start, leader.global_position + facing * 0.6, center, center + facing * 6.0])
	var closest := {"gap": INF, "who": ""}
	var check := func() -> void:
		var p: Vector3 = d.state().player
		for m: WorldModel in people:
			var gap := Vector2(p.x - m.global_position.x, p.z - m.global_position.z).length()
			if gap < closest.gap:
				closest.gap = gap
				closest.who = m.id
	await d.stick_along(path, PlaytestDriver._length(path), check, 4.0, true)
	await d.screenshot("in_the_group")
	d.step("the player came within %.2f m of %s" % [closest.gap, closest.who])
	d.expect(closest.gap >= MIN_GAP, "the player does not go through a person: %.2f m from %s, it must be %.2f m or more" % [
			closest.gap, closest.who, MIN_GAP])
	# 06:30: the group goes away.
	await d.open_app("clock")
	await d.tap_phone_id("clock.wait_hour")
	await d.lower_phone()
	await d.wait_frames(10)
	var minutes: int = d.state().time
	d.step("the time after the wait: %02d:%02d" % [minutes / 60, minutes % 60])
	d.expect(minutes >= 6 * 60 + 30, "the time is 06:30 or later")
	d.expect(not (g.node as Node3D).visible, "at 06:30 the group goes away")
	var blocked := 0
	for shape: CollisionShape3D in g.bodies:
		if not shape.disabled:
			blocked += 1
	d.expect(blocked == 0, "the bodies of the people go away too: %d stay" % blocked)
	await d.look_at_point(center + Vector3(0, 1.0, 0))
	await d.screenshot("after_0630")


## Each person moves, and no two people are at the same time of the routine.
static func _check_motion(d: PlaytestDriver, people: Array) -> void:
	var times: Array[float] = []
	var moved := 0
	for m: WorldModel in people:
		times.append(m.animation_time())
	var before := _hands(people)
	await d.wait_seconds(0.5)
	var after := _hands(people)
	for i in people.size():
		if before[i].distance_to(after[i]) > 0.01:
			moved += 1
	d.expect(moved == people.size(), "each person moves in 0.5 s: %d of %d" % [moved, people.size()])
	d.step("the times of the routine: %s" % [times.map(func(t: float) -> String: return "%.2f" % t)])
	var same := 0
	for i in times.size():
		if times[i] < 0.0:
			d.fail("%s does not play the routine" % (people[i] as WorldModel).id)
		for j in range(i + 1, times.size()):
			if absf(times[i] - times[j]) < 0.05:
				same += 1
	d.expect(same == 0, "no two people move in the same frame of the routine: %d pairs" % same)


## The point of the right hand of each person (the bone of the hand of the first level).
static func _hands(people: Array) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for m: WorldModel in people:
		var point := m.global_position
		for node in m.find_children("*", "Skeleton3D", true, false):
			var skeleton := node as Skeleton3D
			var bone := skeleton.find_bone("hand_r")
			if bone >= 0:
				point = skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
				break
		result.append(point)
	return result
