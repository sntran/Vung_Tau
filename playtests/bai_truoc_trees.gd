extends RefCounted
# PT-53 bai_truoc_trees (plan 0020). Views of Bãi Trước: from the sand of the
# main beach toward the park, from the park along the shore, from Quang Trung
# road, and from the water (the view of D-0005-02). Each view checks that
# coconut palms are in the frame (the trees of the TreeField near the view,
# R10). The test also checks that no tree stands on the sand of the main beach
# or in the water (R11).
# High takes the views in two runs (the first two views, then the other two):
# with the patches of the start chunks (report 0005, D-0005-10), one run of the
# four views took more than 300 s in CI. Low takes the four views in one run.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=16:30 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=16:30 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=16:30 --quality=low --renderer=forward_plus

## A view must show this many coconut palms, or more.
const MIN_PALMS := 3
## The trees that the test looks for: within this distance of the eye (the water view: of the beach).
const NEAR_M := 160.0
## A tree stands in the water when its ground is lower than this (the high tides are about +1.4 m).
const WATER_M := 1.0


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts with --world=vung_tau"):
		return
	# Forward+ under lavapipe needs more time for the first ground.
	await d.wait_ground(120.0)
	var preset: String = ["high", "high", "low"][d.phase - 1]
	var beach := w.data.landmark("bai_truoc")
	if not d.expect(not beach.is_empty(), "the data has Bãi Trước"):
		return
	# The chunks of the start point are made at once: they must show their ground too (report 0005, D-0005-10).
	d.expect(w.chunks_without_ground().is_empty(), "each near chunk shows its ground: %s have no patches" % [
			w.chunks_without_ground()])
	d.step("the trees of each type: %s" % [w.trees.counts])
	_check_places(d, w, beach)
	var all_views := views(w, beach)
	# The views of this run: the first half or the second half on High, all on Low.
	var half := ceili(all_views.size() / 2.0)
	var run_views: Array = [all_views.slice(0, half), all_views.slice(half), all_views][d.phase - 1]
	for view: Dictionary in run_views:
		await d.fly_to(view.eye, view.target)
		await d.wait_ground(60.0)
		await d.wait_frames(6)
		await d.screenshot("%s_%s" % [view.name, preset])
		var around: Vector3 = view.get("around", view.eye)
		var palms := 0
		for entry: Array in w.trees.trees_near("coconut", around, float(view.get("radius", NEAR_M))):
			var p: Vector3 = entry[0]
			if _in_frame(d, p + Vector3(0, 8.0, 0)):
				palms += 1
		d.expect(palms >= MIN_PALMS, "%s: %d coconut palms are in the frame, it must be %d or more" % [
				view.name, palms, MIN_PALMS])
		d.step("%s: the tree forms now: %s" % [view.name, w.trees.shown])
	d.fly_end()


## No tree stands on the sand of the main beach or in the water (R11).
static func _check_places(d: PlaytestDriver, w: VungTau, beach: Dictionary) -> void:
	var outline := PackedVector2Array()
	for p: Array in beach.get("outline", []):
		outline.append(Vector2(p[0], p[1]))
	var center := Vector3(beach.position[0], 0.0, beach.position[1])
	var on_sand := []
	var in_water := []
	var all := w.trees.all_trees_near(center, 1200.0)
	for entry: Array in all:
		var p: Vector3 = entry[0]
		if outline.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), outline):
			on_sand.append("%s at (%.0f, %.0f)" % [entry[1], p.x, p.z])
		if w.ground_height(p.x, p.z) < WATER_M:
			in_water.append("%s at (%.0f, %.0f), ground %.1f m" % [entry[1], p.x, p.z, w.ground_height(p.x, p.z)])
	d.step("%d trees within 1200 m of Bãi Trước" % all.size())
	d.expect(outline.size() >= 3, "the data has the outline of the main beach")
	d.expect(on_sand.is_empty(), "no tree stands on the sand of the main beach: %s" % [on_sand.slice(0, 8)])
	d.expect(in_water.is_empty(), "no tree stands in the water: %d, %s" % [in_water.size(), in_water.slice(0, 8)])


static func _in_frame(d: PlaytestDriver, point: Vector3) -> bool:
	var camera := d.viewport().get_camera_3d()
	if camera.is_position_behind(point):
		return false
	return d.viewport().get_visible_rect().has_point(camera.unproject_position(point))


## The views: [{name, eye, target, around, radius}].
static func views(w: VungTau, beach: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var outline: Array = beach.get("outline", [])
	var center := Vector3(beach.position[0], 0.0, beach.position[1])
	var quang_trung := _road_points(w, "Quang Trung")
	# The land side of the beach: toward the nearest point of Quang Trung.
	var road_point := _nearest(quang_trung, center)
	var inland := (road_point - center) * Vector3(1, 0, 1)
	inland = inland.normalized() if inland.length() > 1.0 else Vector3.RIGHT
	var along := Vector3(-inland.z, 0.0, inland.x)
	var sand := center
	sand.y = maxf(w.ground_height(sand.x, sand.z), 0.5) + Player.EYE_HEIGHT
	result.append({"name": "beach_sand", "eye": sand, "target": road_point + Vector3(0, 6.0, 0)})
	var park := center + inland * maxf(15.0, (road_point - center).length() * 0.5)
	park.y = w.ground_height(park.x, park.z) + Player.EYE_HEIGHT
	result.append({"name": "park", "eye": park, "target": park + along * 80.0 + Vector3(0, 3.0, 0)})
	if quang_trung.size() > 2:
		var on_road := road_point + Vector3(0, Player.EYE_HEIGHT, 0)
		var i := quang_trung.find(road_point)
		var ahead := quang_trung[mini(i + 6, quang_trung.size() - 1)] if i + 6 < quang_trung.size() else quang_trung[maxi(i - 6, 0)]
		result.append({"name": "quang_trung", "eye": on_road, "target": ahead + Vector3(0, 3.0, 0)})
	# From the water: in front of the beach, 400 m out and 25 m high.
	var water := center - inland * 400.0 + Vector3(0, 25.0, 0)
	result.append({"name": "from_water", "eye": water, "target": center + Vector3(0, 6.0, 0), "around": center,
			"radius": 300.0})
	if outline.is_empty():
		push_warning("PT-53: the beach has no outline.")
	return result


static func _road_points(w: VungTau, road_name: String) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for road: Dictionary in w.data.roads:
		if road.name == road_name:
			for p: Array in road.points:
				result.append(Vector3(p[0], p[1], p[2]))
	return result


static func _nearest(points: Array[Vector3], to: Vector3) -> Vector3:
	var best := to + Vector3(60.0, 0.0, 0.0)
	var best_d := INF
	for p: Vector3 in points:
		var dd := Vector2(p.x - to.x, p.z - to.z).length()
		if dd < best_d:
			best_d = dd
			best = p
	return best
