extends RefCounted
# PT-68 town_views (plan 0009, phase 2, R6). Screenshots of the whole town from
# the views of data/geo/town_views.json: the top of Núi Nhỏ, the top of Núi
# Lớn, the Hải Đăng road, and the bus view of plan 0010, at 12:00 and 18:00,
# on Low (Forward+, as PT-72). Each view has the place, the direction, and the
# field of view of its open photo when one exists (python
# tools/town/sheets.py puts each view next to its photo in docs/town/). The
# architect looks at the views. The checks: the boxes of the town in the range
# of the preset are made before the screenshot, the frame is not one flat color,
# and the boxes of the town are in the frame (a view of the town with no
# building is a broken view).
# sizes: 1280x720
# phase: --world=vung_tau --renderer=forward_plus --quality=low --start-time=12:00
# phase: --world=vung_tau --renderer=forward_plus --quality=low --start-time=18:00

const VIEWS := "res://data/geo/town_views.json"
## Report 0009, D-0009-14: the bands of the frame in front of and past the end
## of the range of the boxes (m from it), and the most that their mean values
## (the brightest channel) are apart.
const EDGE_BAND := Vector2(50.0, 250.0)
const EDGE_MAX := 0.06


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.town != null, "the Vũng Tàu world has the boxes of the town"):
		return
	var views := read_views(w)
	if not d.expect(views.size() == 4, "%s has the four views of R6: %d" % [VIEWS, views.size()]):
		return
	var camera := d.viewport().get_camera_3d()
	var fov := camera.fov
	var time := "1200" if d.phase == 1 else "1800"
	for view: Dictionary in views:
		w.prepare_at(view.eye, VungTau.ground_detail.mid)
		w.town.prepare_at(view.eye, TownField.range_end)
		await d.fly_to(view.eye, view.target)
		camera.fov = float(view.fov)
		d.expect(await d.wait_ground(120.0), "%s: the ground and the boxes of the town are ready" % view.id)
		await d.wait_frames(8)
		d.expect(w.town.pending() == 0, "%s: each chunk of the town in the range (%.0f m) is made: %d are not" % [
				view.id, TownField.range_end, w.town.pending()])
		var in_frame := boxes_in_frame(w, camera)
		d.step("%s at %s: %d boxes of the town in the frame (%d made, %d left out: a model, a stand-in, or a known place draws them)" % [
				view.id, time, in_frame, w.town.made, w.town.left_out])
		d.expect(in_frame >= int(view.get("min_boxes", 50)), "%s: the town is in the frame: %d boxes (at least %d)" % [
				view.id, in_frame, int(view.get("min_boxes", 50))])
		await d.screenshot("%s_%s" % [view.id, time])
		d.expect_not_flat("%s at %s" % [view.id, time])
		if view.get("edge", false):
			var frame := d.viewport().get_texture().get_image()
			var edge := edge_values(w, camera, view, frame)
			d.step("%s at %s: the mean value of the frame %.0f m to %.0f m in front of the end of the range of the boxes %.2f, past it %.2f" % [
					view.id, time, EDGE_BAND.y, EDGE_BAND.x, edge.x, edge.y])
			d.expect(absf(edge.x - edge.y) <= EDGE_MAX, "%s at %s: no line at the end of the range of the boxes (D-0009-14): the mean values %.2f and %.2f, at most %.2f apart" % [
					view.id, time, edge.x, edge.y, EDGE_MAX])
	camera.fov = fov
	d.fly_end()


## The views: the eye (a point in degrees, at a height over the ground), the
## direction of the view (heading in degrees from the north to the east, pitch
## in degrees up), and the field of view of the photo.
static func read_views(w: VungTau) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VIEWS))
	if not parsed is Dictionary:
		return out
	for v: Dictionary in parsed.get("views", []):
		var eye := Vector3.ZERO
		if v.has("eye_landmark"):
			# The place of a landmark (as the view from Núi Lớn of PT-33).
			var record := w.data.landmark(str(v.eye_landmark))
			if record.is_empty():
				continue
			eye = Vector3(record.position[0], 0.0, record.position[1])
		else:
			var p := w.data.projection.to_game(float(v.eye[1]), float(v.eye[0]))
			eye = Vector3(p.x, 0.0, p.y)
		w.prepare_at(eye, 64.0)
		eye.y = w.ground_height(eye.x, eye.z) + float(v.get("eye_height", 1.6))
		if v.get("over_trees", false):
			# As PT-33: 1 m over the highest tree of the canopy map within 8 m (the
			# photo is from a railing over the tree tops of the slope).
			var trees := 0.0
			for j in range(-2, 3):
				for i in range(-2, 3):
					trees = maxf(trees, w.canopy_height_at(eye.x + i * 4.0, eye.z + j * 4.0))
			eye.y = maxf(eye.y, w.ground_height(eye.x, eye.z) + trees + 1.0)
		var target := Vector3.ZERO
		if v.has("aim_landmark"):
			var aim := w.data.landmark(str(v.aim_landmark))
			if aim.is_empty():
				continue
			target = Vector3(aim.position[0], 0.0, aim.position[1])
		else:
			var heading := deg_to_rad(float(v.heading))
			var pitch := deg_to_rad(float(v.get("pitch", 0.0)))
			# The north is -z, the east +x.
			target = eye + Vector3(sin(heading) * cos(pitch), sin(pitch), -cos(heading) * cos(pitch)) * 100.0
		out.append({"id": str(v.id), "eye": eye, "target": target, "fov": float(v.get("fov", 70.0)),
				"min_boxes": int(v.get("min_boxes", 50)), "edge": bool(v.get("edge", false))})
	return out


## The count of the town buildings whose middle is in the frame.
static func boxes_in_frame(w: VungTau, camera: Camera3D) -> int:
	var n := 0
	for middle: Vector3 in w.town.middles():
		if camera.is_position_in_frustum(middle) and camera.global_position.distance_to(middle) < TownField.range_end:
			n += 1
	return n


## Report 0009, D-0009-14: the mean value (the brightest channel) of the rows of
## the frame where the ground in the direction of the view is EDGE_BAND m in
## front of the end of the range of the boxes, and past it (the middle 70 % of
## the columns).
static func edge_values(w: VungTau, camera: Camera3D, view: Dictionary, frame: Image) -> Vector2:
	var direction: Vector3 = view.target - view.eye
	direction.y = 0.0
	direction = direction.normalized()
	var rows: Array[float] = []
	for d in [TownField.range_end - EDGE_BAND.y, TownField.range_end - EDGE_BAND.x,
			TownField.range_end + EDGE_BAND.x, TownField.range_end + EDGE_BAND.y]:
		var p: Vector3 = view.eye + direction * d
		p.y = w.ground_height(p.x, p.z)
		rows.append(camera.unproject_position(p).y * frame.get_height() / camera.get_viewport().get_visible_rect().size.y)
	return Vector2(_mean_value(frame, rows[1], rows[0]), _mean_value(frame, rows[3], rows[2]))


static func _mean_value(frame: Image, top: float, bottom: float) -> float:
	var total := 0.0
	var n := 0
	var y0 := clampi(int(minf(top, bottom)), 0, frame.get_height() - 1)
	var y1 := clampi(int(maxf(top, bottom)), y0 + 1, frame.get_height())
	for y in range(y0, y1):
		for x in range(int(frame.get_width() * 0.15), int(frame.get_width() * 0.85), 2):
			var c := frame.get_pixel(x, y)
			total += maxf(c.r, maxf(c.g, c.b))
			n += 1
	return total / maxf(n, 1.0)
