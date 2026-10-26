extends RefCounted
# PT-39 geo_anchors. Take a screenshot at each town anchor and at each structure
# in R1, with the marker visible.
# The places are all the landmarks of data/geo/landmarks.json: the structures
# of R1 and the town anchors of R6a (the bus station, the markets, the big
# roundabout, and the junction of five roads). The camera looks at each marker
# from 70 m away, from a direction where no hill is in the way. Each run takes
# a part of the places, so that each run is shorter than 180 s under lavapipe.
# Run 4 (plan 0005, R11a, R13a, Q6, Q13): the game is in 2019, before the
# widening of the Hải Đăng road, so the road has no roadworks. The objects on
# the sea: the ships, the fishing boats (100 m or more from the sand in front
# of the swimmers of the main beach), the thúng, the rows of fishing stakes,
# the pier, and the groynes. At 09:00 on day 1 the tide is low, so the flat
# rocks along the sea wall south of the main beach are dry.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=10:00
# phase: --world=vung_tau --start-time=09:00

const RUNS := 3
const DISTANCE := 70.0
const EYE_ABOVE := 25.0
## The boats in front of the main beach are this far from its sand, or more (Q6).
const BOATS_FROM_SAND := 100.0


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts"):
		return
	await d.wait_ground()
	if d.phase > RUNS:
		d.expect(w.roadworks == null and w.get_node_or_null("Roadworks") == null,
				"the Hải Đăng road has no roadworks in 2019 (Q13)")
		await _sea_objects(d, w)
		await _flat_rocks(d, w)
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


## The objects on the sea: the ships at anchor, the fishing boats, the thúng,
## the fishing stakes, the pier, and the groynes.
func _sea_objects(d: PlaytestDriver, w: VungTau) -> void:
	var sea := w.sea_objects
	d.expect(sea.ships.size() >= 10 and sea.ships.size() <= 30, "10 to 30 cargo ships: %d" % sea.ships.size())
	d.expect(sea.boats.size() >= 30, "fishing boats all over the bay of Bãi Trước: %d" % sea.boats.size())
	d.expect(sea.baskets.size() >= 6, "thúng near the sand and beside the boats: %d" % sea.baskets.size())
	d.expect(sea.baskets.any(func(b: Dictionary) -> bool: return int(b.tied_to) >= 0), "some thúng are beside the boats")
	d.expect(sea.stake_count > 50, "rows of fishing stakes off Hạ Long: %d stakes" % sea.stake_count)
	d.expect(sea.pier_parts > 0, "the pier Cảng Cầu Đá: %d parts" % sea.pier_parts)
	d.expect(sea.groyne_count > 0, "the groynes: %d" % sea.groyne_count)
	var sand := _main_beach(w)
	var near := 0
	for boat: Dictionary in sea.boats:
		if str(boat.area).begins_with("Near the sand"):
			continue
		var at := Vector2(boat.position[0], boat.position[1])
		for polygon: PackedVector2Array in sand:
			if _distance_to_polygon(at, polygon) < BOATS_FROM_SAND - 1.0:
				near += 1
	d.expect(near == 0, "no boat of the bay is nearer than %d m to the sand of the main beach: %d" % [BOATS_FROM_SAND, near])
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


## The flat rocks along the sea wall south of the main beach are dry at low tide (Q6).
func _flat_rocks(d: PlaytestDriver, w: VungTau) -> void:
	var shelves: Array = w.data.world.get("rock_shelves", [])
	if not d.expect(not shelves.is_empty(), "the data has the flat rocks along the sea wall"):
		return
	var point: Array = shelves[0].point
	var rocks := Vector3(point[0], 0.0, point[1])
	w.prepare_at(rocks)
	rocks.y = w.ground_height(rocks.x, rocks.z)
	d.expect(rocks.y > w.sea_level, "at %s the flat rocks (%+.2f m) are above the sea (%+.2f m)" % [
			_clock(), rocks.y, w.sea_level])
	var eye := rocks + Vector3(-45.0, 12.0, 25.0)
	await d.fly_to(eye, rocks)
	await d.wait_ground(60.0)
	await d.wait_frames(5)
	await d.screenshot("flat_rocks_low_tide")
	d.fly_end()


## The outlines of the main beach of Bãi Trước (data/geo/build/beaches.json).
static func _main_beach(w: VungTau) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(w.data.root.path_join("beaches.json")))
	for beach: Dictionary in (parsed as Dictionary).get("beaches", []):
		if beach.name != "Bãi Trước":
			continue
		for polygon: Dictionary in beach.polygons:
			var outline := PackedVector2Array()
			for p: Array in polygon.outline:
				outline.append(Vector2(p[0], p[1]))
			result.append(outline)
	return result


static func _distance_to_polygon(at: Vector2, polygon: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(at, polygon):
		return 0.0
	var best := INF
	for i in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(at, polygon[i], polygon[(i + 1) % polygon.size()])
		best = minf(best, closest.distance_to(at))
	return best


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
