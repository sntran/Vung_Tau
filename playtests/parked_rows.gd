extends RefCounted
# PT-57 parked_rows (plan 0023, R8, R9a). In the Vũng Tàu world, the row of 40
# parked scooters on Phan Bội Châu near chợ Xóm Lưới, at 19:00 on Low. The
# player walks along the street with the joystick. Checks: the row has 40
# scooters on the sidewalks, at 10° to 30° from the line of the curb, with the
# front wheel turned and the stand down; on the walk, the triangles of each
# frame stay under the limit of 300 000; at 20 m a cell of the row shows the
# mid level and at 50 m the impostor; at the end of the near and of the mid
# level, two screenshots 0.5 m apart are almost the same (the change of level
# does not pop).
# sizes: 1280x720
# phase: --world=vung_tau --start-time=19:00 --quality=low --renderer=forward_plus

const ROW := "cho_xom_luoi"
const COUNT := 40
const MAX_TRIANGLES := 300000
## The mean color of the row area changes by this part, or less, in 0.5 m at a change of level.
const MAX_POP := 0.06
const WALK_M := 70.0


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.parked != null, "the Vũng Tàu world has the parked rows"):
		return
	if not d.expect(w.parked.rows.has(ROW), "the row %s is there: %s" % [ROW, w.parked.rows.keys()]):
		return
	var entry: Dictionary = w.parked.rows[ROW]
	var row: WorldRow = entry.node
	var points: Array = entry.points
	d.expect(row.count() == COUNT, "the row has %d scooters: %d" % [COUNT, row.count()])
	d.expect((row as Node3D).visible, "the row shows at 19:00")
	_check_poses(d, row)
	var center := Vector3.ZERO
	for p: Vector3 in points:
		center += p
	center /= float(points.size())
	# The start: on the road, 35 m before the middle of the row.
	var route := d.road_route("Phan Bội Châu", center, WALK_M + 40.0)
	if not d.expect(route.size() >= 2, "the route along Phan Bội Châu"):
		return
	var start_s := maxf(WorldRow.CELL, PlaytestDriver.route_distance(route, center) - WALK_M / 2.0)
	var start := PlaytestDriver.route_point(route, start_s)
	var ahead := PlaytestDriver.route_point(route, start_s + 5.0)
	await d.start_at(start, rad_to_deg(atan2(-(ahead.x - start.x), -(ahead.z - start.z))))
	await d.wait_ground(120.0)
	await d.wait_frames(5)
	await d.screenshot("start")
	var most := {"triangles": 0}
	var check := func() -> void:
		var triangles := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		if triangles > most.triangles:
			most.triangles = triangles
	var walked := await d.stick_along(route, start_s + WALK_M, check)
	d.expect(walked, "the player walks %.0f m along the row" % WALK_M)
	await d.screenshot("walk_end")
	d.step("the most triangles in a frame of the walk: %d" % most.triangles)
	d.expect(most.triangles < MAX_TRIANGLES, "the triangles of each frame stay under %d on Low: %d" % [
			MAX_TRIANGLES, most.triangles])
	await _check_levels(d, w, row)


## R9a: 10° to 30° from the line of the curb, the front wheel turned, the stand down.
static func _check_poses(d: PlaytestDriver, row: WorldRow) -> void:
	var bad := []
	for item: Dictionary in row._items:
		var pose: Dictionary = item.pose
		if absf(float(pose.get("fork", 0.0))) < Parked.MIN_STEER - 0.01 or float(pose.get("stand", 0.0)) < 45.0:
			bad.append(pose)
	d.expect(bad.is_empty(), "each scooter has its front wheel turned and its stand down: %s" % [bad.slice(0, 4)])


## The cell of the row nearest to the middle, and its center (the center of
## the box of its near MultiMeshes).
static func _cell(row: WorldRow) -> Dictionary:
	var best := {}
	var mid := Vector3.ZERO
	for cell: Dictionary in row.cells:
		mid += (cell.node as Node3D).global_position
	mid /= float(row.cells.size())
	var best_d := INF
	for cell: Dictionary in row.cells:
		var p: Vector3 = (cell.node as Node3D).global_position
		if p.distance_to(mid) < best_d and not cell.near.is_empty():
			best_d = p.distance_to(mid)
			best = cell
	var node: MultiMeshInstance3D = best.near[0]
	var box := node.global_transform * node.get_aabb()
	best.center = box.get_center()
	return best


## The level of a cell at a distance: the range of the near, mid, and
## impostor nodes of the cell.
static func _shown(cell: Dictionary, distance: float) -> Array[String]:
	var result: Array[String] = []
	for level: String in ["near", "mid", "impostor"]:
		for node: GeometryInstance3D in cell[level]:
			if distance >= node.visibility_range_begin and distance < node.visibility_range_end:
				result.append(level)
				break
	return result


static func _check_levels(d: PlaytestDriver, w: VungTau, row: WorldRow) -> void:
	var cell := _cell(row)
	var center: Vector3 = cell.center
	# The camera looks at the cell from the street, across the row.
	var road := w.road_at(center)
	var out := Vector3.FORWARD
	var nearest := Vector3.INF
	for p: Vector3 in [center + Vector3(8, 0, 0), center + Vector3(-8, 0, 0), center + Vector3(0, 0, 8), center + Vector3(0, 0, -8)]:
		if not w.road_at(p).is_empty() and (nearest == Vector3.INF):
			nearest = p
	if nearest != Vector3.INF:
		out = (nearest - center) * Vector3(1, 0, 1)
		out = out.normalized()
	d.step("the cell %s at %s, the camera side %s, road %s" % [(cell.node as Node3D).name, center, out, road.get("name", "")])
	for distance: float in [20.0, 50.0]:
		var shown := _shown(cell, distance)
		var expected := "mid" if distance == 20.0 else "impostor"
		d.expect(shown == [expected], "at %.0f m the cell shows the %s level: %s" % [distance, expected, shown])
		await _look(d, w, center, out, distance)
		await d.screenshot("row_%dm" % int(distance))
	var r := WorldModel.ranges
	for end: float in [r.x, r.y]:
		var means: Array[Color] = []
		for distance: float in [end - 0.25, end + 0.25]:
			await _look(d, w, center, out, distance)
			await d.screenshot("pop_%dm_%s" % [int(end), "before" if distance < end else "after"])
			means.append(_mean(d, center))
		var a: Color = means[0]
		var b: Color = means[1]
		var change := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() / maxf(Vector3(a.r, a.g, a.b).length(), 0.05)
		d.step("the change of level at %.0f m: %.1f %%" % [end, change * 100.0])
		d.expect(change <= MAX_POP, "the change of level at %.0f m does not pop: the row area changes by %.1f %%, it must be %.0f %% or less" % [
				end, change * 100.0, MAX_POP * 100.0])
	d.fly_end()


## The camera at a distance from the center of the cell, at eye height, on the road side.
static func _look(d: PlaytestDriver, w: VungTau, center: Vector3, out: Vector3, distance: float) -> void:
	var flat := sqrt(maxf(distance * distance - 1.0, 1.0))
	var eye := center + out * flat
	eye.y = w.ground_height(eye.x, eye.z) + Player.EYE_HEIGHT
	await d.fly_to(eye, center)
	await d.wait_ground(30.0)
	await d.wait_frames(6)


## The mean color of a box of the screen around the cell.
static func _mean(d: PlaytestDriver, center: Vector3) -> Color:
	var camera := d.viewport().get_camera_3d()
	var image := d.viewport().get_texture().get_image()
	var scale := Vector2(image.get_size()) / d.viewport().get_visible_rect().size
	var s := camera.unproject_position(center) * scale
	var size := Vector2(image.get_size()) * 0.18
	var sum := Color(0, 0, 0)
	var n := 0
	for y in range(int(s.y - size.y), int(s.y + size.y), 3):
		for x in range(int(s.x - size.x), int(s.x + size.x), 3):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			sum += image.get_pixel(x, y)
			n += 1
	n = maxi(n, 1)
	return Color(sum.r / n, sum.g / n, sum.b / n)
