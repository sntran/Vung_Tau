extends RefCounted
# PT-39 geo_anchors. Take a screenshot at each town anchor and at each structure
# in R1, with the marker visible.
# The places are all the landmarks of data/geo/landmarks.json: the structures
# of R1 and the town anchors of R6a (the bus station, the markets, the big
# roundabout, and the junction of five roads). The camera looks at each marker
# from 70 m away, from a direction where no hill is in the way. Each run takes
# a part of the places, so that each run is shorter than 180 s under lavapipe.
# Runs 4 and 5 (plan 0005, R11a, R13a): the roadworks on the Hải Đăng road at
# 09:00 (workers, the machine sound and its caption) and at 12:00 (the lunch
# break: no workers and no sound), and the objects on the sea.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=09:00
# phase: --world=vung_tau --start-time=12:00

const RUNS := 3
const DISTANCE := 70.0
const EYE_ABOVE := 25.0


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts"):
		return
	await d.wait_ground()
	if d.phase > RUNS:
		await _roadworks(d, w, d.phase == RUNS + 1)
		if d.phase == RUNS + 1:
			await _sea_objects(d, w)
		return
	var records: Array = w.data.landmarks.duplicate()
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	if d.phase == 1:
		var missing := records.filter(func(r: Dictionary) -> bool: return not r.get("found", false)) \
				.map(func(r: Dictionary) -> String: return str(r.id))
		d.expect(missing.is_empty(), "the data has each landmark: %s are not found" % [missing])
	var per_run := ceili(records.size() / float(RUNS))
	for record: Dictionary in records.slice((d.phase - 1) * per_run, d.phase * per_run):
		if not record.get("found", false):
			continue
		var marker := _marker(w, str(record.id))
		if not d.expect(marker != null, "the landmark %s has a marker" % record.id):
			continue
		var eye := _clear_eye(w, d, marker.global_position)
		await d.fly_to(eye, marker.global_position)
		await d.wait_ground(60.0)
		await d.wait_frames(5)
		var camera: Camera3D = d.main().player.camera
		var view := camera.unproject_position(marker.global_position)
		var visible := not camera.is_position_behind(marker.global_position) \
				and d.viewport().get_visible_rect().grow(-20.0).has_point(view)
		d.expect(visible, "the marker \"%s\" shows on the screen" % marker.text)
		d.expect(not _blocked(d, eye, marker.global_position), "no ground is between the camera and the marker \"%s\"" % marker.text)
		await d.screenshot(str(record.id))
	d.fly_end()


## The roadworks: at 09:00 the workers work and the machine plays, and the
## player who walks near sees the caption. At 12:00 it is the lunch break.
func _roadworks(d: PlaytestDriver, w: VungTau, working: bool) -> void:
	if not d.expect(w.roadworks != null, "the Hải Đăng road has roadworks"):
		return
	var works := w.roadworks
	d.expect(works.workers.visible == working, "the workers are %s at %s" % ["there" if working else "not there", _clock()])
	d.expect(works.machine.playing == working, "the machine sound %s at %s" % ["plays" if working else "is off", _clock()])
	var sign: Label3D = works.get_node("SiteSign")
	d.expect(sign.text.contains(str(works.record.contractor)) and sign.text.contains("2027"),
			"the site sign has the contractor and the planned end: %s" % sign.text.replace("\n", " / "))
	if works.record.has("corner"):
		var corner: Array = works.record.corner.point
		d.expect(Vector2(corner[0], corner[1]).distance_to(Vector2(works.excavator_position.x, works.excavator_position.z)) < 15.0,
				"the excavator is at the corner of the homestay hẻm")
	var eye := works.excavator_position + Vector3(14.0, 7.0, 10.0)
	w.prepare_at(eye)
	await d.fly_to(eye, works.excavator_position + Vector3(0, 1.0, 0))
	await d.wait_ground(60.0)
	await d.wait_frames(5)
	await d.screenshot("roadworks_%s" % ("work" if working else "lunch"))
	await d.fly_to(works.sign_position + works.sign_facing * 7.0 + Vector3(0, 1.0, 0), works.sign_position + Vector3(0, 2.0, 0))
	await d.wait_frames(5)
	await d.screenshot("roadworks_sign")
	d.fly_end()
	if working:
		# The player stands on the road, 15 m from the machine.
		var road: Array = works.record.points[0]
		var bottom := Vector3(road[0], road[1], road[2])
		var near := works.excavator_position.lerp(bottom, 15.0 / works.excavator_position.distance_to(bottom))
		await d.start_at(near, 0.0)
		var caption := str(Content.sound("machine").caption)
		var heard := await d.wait_until(func() -> bool:
			var shown := d.subtitle()
			return shown.get("caption", false) and Array(shown.lines).has(caption), 12.0, "the caption of the machine")
		d.expect(heard, "the caption of the machine shows near the roadworks")


## The objects on the sea: the ships at anchor, the fishing boats, the pier, and the groynes.
func _sea_objects(d: PlaytestDriver, w: VungTau) -> void:
	var sea := w.sea_objects
	d.expect(sea.ships.size() >= 10 and sea.ships.size() <= 30, "10 to 30 cargo ships: %d" % sea.ships.size())
	d.expect(sea.boats.size() > 0, "fishing boats in the bay of Bãi Trước: %d" % sea.boats.size())
	d.expect(sea.pier_parts > 0, "the ferry pier: %d parts" % sea.pier_parts)
	d.expect(sea.groyne_count > 0, "the groynes: %d" % sea.groyne_count)
	var boat: Array = sea.boats[0].position
	var target := Vector3(boat[0], 1.0, boat[1])
	var front := w.data.landmark("bai_truoc")
	var beach := Vector3(front.position[0], 0.0, front.position[1])
	var eye := beach + Vector3(0, 6.0, 0)
	w.prepare_at(eye)
	await d.fly_to(eye, target)
	await d.wait_ground(60.0)
	await d.wait_frames(5)
	await d.screenshot("boats_and_ships")
	d.fly_end()


static func _clock() -> String:
	return GameClock.format_time(GameState.minutes)


static func _marker(w: VungTau, landmark_id: String) -> Label3D:
	return w.get_node_or_null("Marker_" + landmark_id) as Label3D


## A camera point 70 m from the marker, from the first of 8 directions where
## the ground is not in the way.
static func _clear_eye(w: VungTau, d: PlaytestDriver, target: Vector3) -> Vector3:
	var first := Vector3.ZERO
	for i in 8:
		var angle := TAU * i / 8.0
		var eye := target + Vector3(cos(angle), 0.0, sin(angle)) * DISTANCE
		w.prepare_at(eye)
		eye.y = maxf(w.ground_height(eye.x, eye.z), 0.0) + EYE_ABOVE
		eye.y = maxf(eye.y, target.y - 10.0)
		if i == 0:
			first = eye
		if not _blocked(d, eye, target):
			return eye
	return first


static func _blocked(d: PlaytestDriver, eye: Vector3, target: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = d.main().get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, target, Layers.FLOOR))
	return not hit.is_empty()
