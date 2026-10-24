extends RefCounted
# PT-31 geo_anchors. Take a screenshot at each town anchor and at each structure
# in R1, with the marker visible.
# The places are all the landmarks of data/geo/landmarks.json: the structures
# of R1 and the town anchors of R6a (the bus station, the markets, the big
# roundabout, and the junction of five roads). The camera looks at each marker
# from 70 m away, from a direction where no hill is in the way. Each run takes
# a part of the places, so that each run is shorter than 180 s under lavapipe.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00

const RUNS := 3
const DISTANCE := 70.0
const EYE_ABOVE := 25.0


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts"):
		return
	await d.wait_ground()
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
