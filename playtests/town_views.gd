extends RefCounted
# PT-68 town_views (plan 0009, phase 2, R6). Screenshots of the whole town from
# the views of data/geo/town_views.json: the top of Núi Nhỏ, the top of Núi
# Lớn, the Hải Đăng road, and the bus view of plan 0010, at 12:00 and 18:00,
# on Low (Forward+, as PT-72). Each view has the place, the direction, and the
# field of view of its open photo when one exists (python
# tools/town/sheets.py puts each view next to its photo in docs/town/). The
# architect looks at the views. The checks: the boxes of the town in the range
# of the preset are made before the screenshot, the frame is not one flat color,
# and the boxes of the town show in the frame (a ray test against the ground
# and the roofs, report 0009, D-0009-18: a view of the town with no building is
# a broken view).
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
		# Report 0009, D-0009-18: the boxes that show (a ray test), not the boxes in the frustum.
		var seen := w.town.boxes_seen(camera, TownField.range_end)
		d.step("%s at %s: %d boxes of the town show in the frame, %d in the frustum (%d made, %d left out: a model, a stand-in, or a known place draws them)" % [
				view.id, time, seen, boxes_in_frame(w, camera), w.town.made, w.town.left_out])
		d.expect(seen >= int(view.get("min_boxes", 50)), "%s: the town shows in the frame: %d boxes (at least %d)" % [
				view.id, seen, int(view.get("min_boxes", 50))])
		if view.has("near_boxes"):
			# Report 0009, D-0009-22: the shops at the street (the boxes of the raster).
			var near: Dictionary = view.near_boxes
			var near_seen := w.town.boxes_seen(camera, float(near.within_m))
			d.step("%s at %s: %d boxes nearer than %.0f m show" % [view.id, time, near_seen, float(near.within_m)])
			d.expect(near_seen >= int(near.min), "%s: the boxes at the street show: %d nearer than %.0f m (at least %d)" % [
					view.id, near_seen, float(near.within_m), int(near.min)])
		await d.screenshot("%s_%s" % [view.id, time])
		d.expect_not_flat("%s at %s" % [view.id, time])
		for lake_name: String in view.get("lakes", []):
			_check_lake(d, w, camera, view, lake_name)
		if view.has("compare") and time == "1200":
			_compare(d, view)
		if view.has("towers") and time == "1200":
			_compare_towers(d, w, camera, view)
		for hill: Dictionary in view.get("hills", []):
			_check_hill(d, w, camera, view, hill)
		if view.get("edge", false):
			var frame := d.viewport().get_texture().get_image()
			var edge := edge_values(w, camera, view, frame)
			d.step("%s at %s: the mean value of the frame %.0f m to %.0f m in front of the end of the range of the boxes %.2f, past it %.2f" % [
					view.id, time, EDGE_BAND.y, EDGE_BAND.x, edge.x, edge.y])
			d.expect(absf(edge.x - edge.y) <= EDGE_MAX, "%s at %s: no line at the end of the range of the boxes (D-0009-14): the mean values %.2f and %.2f, at most %.2f apart" % [
					view.id, time, edge.x, edge.y, EDGE_MAX])
	camera.fov = fov
	d.fly_end()


## The views: the eye (a point in degrees, at a height over the ground, or at
## eye_y over the mean sea level), the direction of the view (heading in
## degrees from the north to the east, pitch in degrees up), and the vertical
## field of view of the photo (report 0009, D-0009-18: from the photo, as the
## shots of plan 0026).
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
		if v.has("eye_y"):
			# An eye in the air (the cabin of the cable car), m over the mean sea level.
			eye.y = float(v.eye_y)
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
		if v.has("near_boxes"):
			out[-1]["near_boxes"] = v.near_boxes
		out[-1]["hills"] = []
		for hill: Dictionary in v.get("hills", []):
			var at := w.data.projection.to_game(float(hill.lon), float(hill.lat))
			(out[-1]["hills"] as Array).append({"name": str(hill.name), "x": at.x, "z": at.y})
		out[-1]["lakes"] = v.get("lakes", [])
		if v.has("compare") and not v.get("photos", []).is_empty():
			out[-1]["compare"] = v.compare
			out[-1]["photo"] = str(v.photos[0].file)
		if v.has("towers") and not v.get("photos", []).is_empty():
			out[-1]["towers"] = v.towers
			out[-1]["photo"] = str(v.photos[0].file)
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


## Report 0009, D-0009-15: the town in the frame against the town in its
## photo (the boxes of "compare"): the mean value (the brightest channel) and
## the share of the pixels that are near white (a value over 0.8 and a
## saturation under 0.2).
func _compare(d: PlaytestDriver, view: Dictionary) -> void:
	var frame := d.viewport().get_texture().get_image()
	var photo := Image.load_from_file("res://docs/reference/photos/" + str(view.photo))
	if not d.expect(photo != null, "%s: the photo %s is in docs/reference/photos/" % [view.id, view.photo]):
		return
	var game := town_look(frame, view.compare.game)
	var real := town_look(photo, view.compare.photo)
	d.step("%s: the town in the frame has the mean value %.2f and %.0f %% near white; in the photo %.2f and %.0f %%" % [
			view.id, game.x, game.y * 100.0, real.x, real.y * 100.0])
	d.expect(absf(game.x - real.x) <= float(view.compare.max_value_gap),
			"%s: the town has the brightness of the photo (D-0009-15): the mean value %.2f, the photo %.2f (at most %.2f apart)" % [
				view.id, game.x, real.x, float(view.compare.max_value_gap)])
	d.expect(game.y - real.y <= float(view.compare.max_white_gap),
			"%s: the town is not near white (D-0009-15): %.0f %% of its pixels, the photo %.0f %% (at most %.0f points more)" % [
				view.id, game.y * 100.0, real.y * 100.0, float(view.compare.max_white_gap) * 100.0])


## Report 0009, D-0009-24: the towers in the frame against the towers of the
## photo: the mean saturation and the mean value of their fronts. In the game,
## each building of TALL_M or more nearer than "within_m", in the frame, with a
## clear line to the middle of its top part, and at least MIN_TOWER_PX high:
## the middle of its box on the screen (the middle half across, from 10 % to
## 60 % down from its top). In the photo, the boxes of "towers.photo".
const MIN_TOWER_PX := 24.0


func _compare_towers(d: PlaytestDriver, w: VungTau, camera: Camera3D, view: Dictionary) -> void:
	var frame := d.viewport().get_texture().get_image()
	var photo := Image.load_from_file("res://docs/reference/photos/" + str(view.photo))
	var spec: Dictionary = view.towers
	var game := Vector3.ZERO
	var count := 0
	var bold := 0
	for tower: Dictionary in w.town.towers():
		var ring: PackedVector2Array = tower.outline
		var middle := Vector2.ZERO
		for p in ring:
			middle += p / ring.size()
		var top_middle := Vector3(middle.x, lerpf(float(tower.base), float(tower.top), 0.7), middle.y)
		if camera.global_position.distance_to(top_middle) > float(spec.get("within_m", 3000.0)):
			continue
		# The line to a point in front of the face of the tower (the middle is in its own box).
		var reach := 0.0
		for p in ring:
			reach = maxf(reach, p.distance_to(middle))
		var front := top_middle + (camera.global_position - top_middle).normalized() * (reach + 1.0)
		if not camera.is_position_in_frustum(top_middle) or not w.town.clear_line(camera.global_position, front):
			continue
		var rect := Rect2()
		var first := true
		for p in ring:
			for y: float in [float(tower.base), float(tower.top)]:
				var at := camera.unproject_position(Vector3(p.x, y, p.y))
				rect = Rect2(at, Vector2.ZERO) if first else rect.expand(at)
				first = false
		if rect.size.y < MIN_TOWER_PX:
			continue
		var inner := Rect2(rect.position + Vector2(rect.size.x * 0.25, rect.size.y * 0.1), Vector2(rect.size.x * 0.5, rect.size.y * 0.5))
		var look := _sat_value(frame, inner.intersection(Rect2(Vector2.ZERO, frame.get_size())))
		if look.z == 0.0:
			continue
		game += Vector3(look.x, look.y, 1.0)
		count += 1
		var c := Color(str(tower.color))
		bold += 1 if (maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))) / maxf(maxf(c.r, maxf(c.g, c.b)), 0.001) > 0.15 else 0
	var real := Vector3.ZERO
	for box: Array in spec.photo:
		var r := Rect2(float(box[0]) * photo.get_width(), float(box[1]) * photo.get_height(),
				(float(box[2]) - float(box[0])) * photo.get_width(), (float(box[3]) - float(box[1])) * photo.get_height())
		var look := _sat_value(photo, r)
		real += Vector3(look.x, look.y, 1.0)
	if not d.expect(count > 0 and real.z > 0.0, "%s: towers in the frame (%d) and in the photo (%d)" % [view.id, count, int(real.z)]):
		return
	var g := Vector2(game.x, game.y) / float(count)
	var p := Vector2(real.x, real.y) / real.z
	d.step("%s: %d towers in the frame (%d with a color over a saturation of 0.15): the saturation %.2f and the value %.2f; in the photo (%d towers) %.2f and %.2f" % [
			view.id, count, bold, g.x, g.y, int(real.z), p.x, p.y])
	d.expect(absf(g.x - p.x) <= float(spec.max_saturation_gap), "%s: the towers have the saturation of the photo (D-0009-24): %.2f, the photo %.2f (at most %.2f apart)" % [
			view.id, g.x, p.x, float(spec.max_saturation_gap)])
	d.expect(absf(g.y - p.y) <= float(spec.max_value_gap), "%s: the towers have the value of the photo (D-0009-24): %.2f, the photo %.2f (at most %.2f apart)" % [
			view.id, g.y, p.y, float(spec.max_value_gap)])


## Report 0009, Q14: a hill of the mainland of the photo on the horizon: its
## top is in the frame, no other ground is in front of it (the far mesh has the
## curve of the earth; its own slopes within HILL_SLOPES_M of the top do not
## count), and the pixel under the top differs from the sky over it.
func _check_hill(d: PlaytestDriver, w: VungTau, camera: Camera3D, view: Dictionary, hill: Dictionary) -> void:
	if not d.expect(w.mainland != null, "%s: the world has the land of the mainland (Q14)" % view.id):
		return
	var top := Vector3(float(hill.x), w.mainland.height_at(float(hill.x), float(hill.z)), float(hill.z))
	var eye := camera.global_position
	var clear := true
	var blocked := ""
	for k in range(1, 200):
		var p := eye.lerp(top, k / 200.0)
		var ground := maxf(w.ground_height(p.x, p.z), w.mainland.height_at(p.x, p.z))
		if p.y < ground - 1.0 and eye.distance_to(p) < eye.distance_to(top) - HILL_SLOPES_M:
			clear = false
			blocked = " (ground of %.0f m at %.1f km)" % [ground, eye.distance_to(p) / 1000.0]
			break
	var in_frame := camera.is_position_in_frustum(top)
	var frame := d.viewport().get_texture().get_image()
	var at := camera.unproject_position(top) * Vector2(frame.get_size()) / camera.get_viewport().get_visible_rect().size
	var below := Color.BLACK
	var above := Color.BLACK
	var contrast := 0.0
	if in_frame:
		var x := clampi(int(at.x), 0, frame.get_width() - 1)
		below = frame.get_pixel(x, clampi(int(at.y) + 3, 0, frame.get_height() - 1))
		above = frame.get_pixel(x, clampi(int(at.y) - 10, 0, frame.get_height() - 1))
		contrast = maxf(absf(below.r - above.r), maxf(absf(below.g - above.g), absf(below.b - above.b)))
	d.step("%s: %s at %.1f km, its top %.0f m (with the curve of the earth): in the frame %s at (%.0f, %.0f), nothing in front of it %s%s, the land under it and the sky over it differ by %.2f" % [
			view.id, hill.name, eye.distance_to(top) / 1000.0, top.y, in_frame, at.x, at.y, clear, blocked, contrast])
	d.expect(in_frame and clear and contrast >= MIN_HILL_CONTRAST, "%s: %s of the photo shows on the horizon (Q14)" % [view.id, hill.name])


## The least difference of a channel between the land of a far hill and the sky over it.
const MIN_HILL_CONTRAST := 0.03
## The slopes of the hill itself (within this distance of its top, m) are not in front of it.
const HILL_SLOPES_M := 3000.0


## The mean saturation and value of the pixels of the rectangle, and their count (z).
static func _sat_value(image: Image, rect: Rect2) -> Vector3:
	var sat := 0.0
	var value := 0.0
	var n := 0
	for y in range(int(rect.position.y), int(rect.end.y)):
		for x in range(int(rect.position.x), int(rect.end.x)):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var c := image.get_pixel(x, y)
			var v := maxf(c.r, maxf(c.g, c.b))
			sat += (v - minf(c.r, minf(c.g, c.b))) / maxf(v, 0.001)
			value += v
			n += 1
	return Vector3(sat / maxf(n, 1.0), value / maxf(n, 1.0), float(n))


static func town_look(image: Image, box: Array) -> Vector2:
	var total := 0.0
	var white := 0
	var n := 0
	var step := maxi(1, image.get_width() / 640)
	for y in range(int(float(box[1]) * image.get_height()), int(float(box[3]) * image.get_height()), step):
		for x in range(int(float(box[0]) * image.get_width()), int(float(box[2]) * image.get_width()), step):
			var c := image.get_pixel(x, y)
			var value := maxf(c.r, maxf(c.g, c.b))
			var saturation := (value - minf(c.r, minf(c.g, c.b))) / maxf(value, 0.001)
			total += value
			if value > 0.8 and saturation < 0.2:
				white += 1
			n += 1
	return Vector2(total / maxf(n, 1.0), float(white) / maxf(n, 1.0))


## Report 0009, D-0009-16: the water of the land in the photo shows in the
## frame: the middle of the area is in the frame, and the ray to it stays over
## the ground and over the roofs of the boxes.
func _check_lake(d: PlaytestDriver, w: VungTau, camera: Camera3D, view: Dictionary, lake_name: String) -> void:
	if not d.expect(w.inland_water != null, "%s: the world has the water of the land" % view.id):
		return
	var lake := w.inland_water.area_named(lake_name)
	if not d.expect(not lake.is_empty(), "%s: %s is in the water of the land" % [view.id, lake_name]):
		return
	var middle: Vector3 = lake.middle + Vector3(0.0, 0.2, 0.0)
	var in_frame := camera.is_position_in_frustum(middle)
	var clear := w.town.clear_line(camera.global_position, middle)
	d.step("%s: %s at %.0f m, level %.2f m: in the frame %s, nothing in front of it %s" % [
			view.id, lake_name, camera.global_position.distance_to(middle), float(lake.level), in_frame, clear])
	d.expect(in_frame and clear, "%s: %s shows in the frame (D-0009-16)" % [view.id, lake_name])
