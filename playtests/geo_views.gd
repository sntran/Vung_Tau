extends RefCounted
# PT-33 geo_views. Take screenshots from fixed viewpoints: Bãi Trước seen from
# the water, the top of Núi Nhỏ looking north, Mũi Nghinh Phong looking south,
# and Bãi Sau from the beach road. Take each one at 06:00, 12:00, and 18:00.
# I compare them with the real places.
# The report 0005 changes the views (D-0005-02): Bãi Trước is seen from 2.5 km
# out in the bay and 60 m high (the view is 75° wide, so at 2 km the tops of
# the hills are at the edges of the frame), so that it shows as a bay between Núi Lớn and
# Núi Nhỏ. Two views are new: from Núi Lớn looking south-east over Bãi Trước
# to Núi Nhỏ, and from Núi Nhỏ looking north-east along Bãi Sau. Each view
# checks that its places are in the frame. At 12:00, the view from the top of
# Núi Nhỏ checks that the slopes of Núi Lớn show the color of tree crowns,
# not the color of grass (D-0005-01).
# The fourth run takes the same views at 21:00, for the night light (R14).
# The fifth run is on 3 June 2019, in the rainy season (R12a): the hills are
# green, and the flame trees show red flowers. The other runs are on day 1, in
# the dry season: the hills are partly dry. Each run also looks up the Hải Đăng
# road, where the flame trees stand.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=06:00
# phase: --world=vung_tau --start-time=12:00
# phase: --world=vung_tau --start-time=18:00
# phase: --world=vung_tau --start-time=21:00
# phase: --world=vung_tau --start-time=12:00 --start-date=2019-06-03

## The view of Bãi Trước from the bay: the distance out from the line between the two hills, and the height.
const BAY_OUT_M := 2500.0
const BAY_HEIGHT_M := 60.0
## The canopy check (D-0005-01): sample points on Núi Lớn each CANOPY_STEP_M
## meters, higher than CANOPY_LOWEST_M (above the town).
const CANOPY_STEP_M := 40.0
const CANOPY_LOWEST_M := 40.0
const CANOPY_RADIUS_M := 1100.0
## The part of the sampled points that must show a tree crown color.
const CANOPY_SHARE := 0.6
## A crown is darker than the grass by this part of its value (the haze at
## 3 km makes all differences smaller), or greener by this value (G minus R).
const CROWN_DARKER := 0.07
const CROWN_GREENER := 0.04


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts with --world=vung_tau"):
		return
	await d.wait_ground()
	var time: String = ["0600", "1200", "1800", "2100", "june"][d.phase - 1]
	if d.phase == 5:
		d.expect(w.season.name == "rainy" and w.season.dryness < 0.15, "on 3 June the hills are green: %s" % [w.season])
		d.expect(w.season.flame_flowers > 0.9, "on 3 June the flame trees flower: %.2f" % w.season.flame_flowers)
	else:
		d.expect(w.season.name == "dry" and w.season.dryness > 0.4, "on day 1 the hills are partly dry: %s" % [w.season])
	d.step("the far form of the hill trees has %d clumps" % w.canopy.count)
	for view: Dictionary in views(w):
		if view.is_empty():
			continue
		await d.fly_to(view.eye, view.target)
		await d.wait_ground(60.0)
		await d.wait_frames(5)
		await d.screenshot("%s_%s" % [view.name, time])
		for place: String in view.get("frame", []):
			var record := w.data.landmark(place)
			var point := Vector3(record.position[0], maxf(float(record.get("height", 0.0)), 0.0), record.position[1])
			d.expect(in_frame(d, point), "%s: %s is in the frame" % [view.name, record.name_vi])
		if view.name == "nui_nho_north" and (time == "1200" or time == "june"):
			await _check_canopy(d, w, time)
	d.fly_end()


## True when the point is in front of the camera and in the frame.
static func in_frame(d: PlaytestDriver, point: Vector3) -> bool:
	var camera := d.viewport().get_camera_3d()
	if camera.is_position_behind(point):
		return false
	return d.viewport().get_visible_rect().has_point(camera.unproject_position(point))


## The slopes of Núi Lớn show the color of tree crowns, not the color of grass
## (D-0005-01). The check reads the color at points on the slopes, then hides
## the far form of the trees and reads the same points again. A point shows a
## crown when it is darker or greener than the grass at the same point.
static func _check_canopy(d: PlaytestDriver, w: VungTau, time: String) -> void:
	var points := canopy_points(d, w)
	var with_trees := pixel_colors(d, points)
	var with_ms := await _frame_ms(d)
	w.set_canopy(false)
	await d.wait_frames(3)
	var without_ms := await _frame_ms(d)
	d.step("the frame time under lavapipe (only for comparison, R16): %.0f ms with the far trees, %.0f ms without" % [
			with_ms, without_ms])
	await d.screenshot("nui_nho_north_%s_no_far_trees" % time)
	var grass := pixel_colors(d, points)
	w.set_canopy(true)
	await d.wait_frames(3)
	var crowns := 0
	var tree_sum := Color(0, 0, 0)
	var grass_sum := Color(0, 0, 0)
	for i in points.size():
		tree_sum += with_trees[i]
		grass_sum += grass[i]
		if is_crown_color(with_trees[i], grass[i]):
			crowns += 1
	var total := maxf(points.size(), 1)
	d.step("nui_nho_north, %s: %d of %d points on Núi Lớn show a crown color (mean color %s, without the far trees %s)" % [
			time, crowns, points.size(), (tree_sum / total).to_html(false), (grass_sum / total).to_html(false)])
	d.expect(points.size() >= 50, "the view from Núi Nhỏ shows the slopes of Núi Lớn: %d points" % points.size())
	d.expect(crowns >= CANOPY_SHARE * total, "%d %% of the slopes of Núi Lớn show a crown color, it must be %d %% or more" % [
			roundi(100.0 * crowns / total), roundi(CANOPY_SHARE * 100)])


## The mean time of 10 frames in milliseconds.
static func _frame_ms(d: PlaytestDriver) -> float:
	var start := Time.get_ticks_usec()
	await d.wait_frames(10)
	return (Time.get_ticks_usec() - start) / 10000.0


## The screen points of the slopes of Núi Lớn: points on a grid, on tree
## ground (VungTau.is_forest()) higher than CANOPY_LOWEST_M, in the frame, and
## not behind other ground.
static func canopy_points(d: PlaytestDriver, w: VungTau) -> Array[Vector2]:
	var big := w.data.landmark("nui_lon")
	var camera := d.viewport().get_camera_3d()
	var eye := camera.global_position
	var result: Array[Vector2] = []
	var steps := int(CANOPY_RADIUS_M / CANOPY_STEP_M)
	for j in range(-steps, steps + 1):
		for i in range(-steps, steps + 1):
			var x: float = big.position[0] + i * CANOPY_STEP_M
			var z: float = big.position[1] + j * CANOPY_STEP_M
			var h := w.data.overview_height(x, z)
			if h < CANOPY_LOWEST_M:
				continue
			var slope := maxf(absf(w.data.overview_height(x + 16.0, z) - w.data.overview_height(x - 16.0, z)),
					absf(w.data.overview_height(x, z + 16.0) - w.data.overview_height(x, z - 16.0))) / 32.0
			if not w.is_forest(x, z, h, slope):
				continue
			var point := Vector3(x, h, z)
			if in_frame(d, point) and _clear_view(w, eye, point):
				result.append(camera.unproject_position(point))
	return result


## The colors of the screen at the points.
static func pixel_colors(d: PlaytestDriver, points: Array[Vector2]) -> Array[Color]:
	var image := d.viewport().get_texture().get_image()
	var scale := Vector2(image.get_size()) / d.viewport().get_visible_rect().size
	var result: Array[Color] = []
	for point: Vector2 in points:
		var at := (point * scale).floor()
		result.append(image.get_pixel(clampi(int(at.x), 0, image.get_width() - 1), clampi(int(at.y), 0, image.get_height() - 1)))
	return result


## A tree crown color: darker than the grass at the same point, or greener.
static func is_crown_color(tree: Color, grass: Color) -> bool:
	return grass.v - tree.v > CROWN_DARKER * grass.v or (tree.g - tree.r) - (grass.g - grass.r) > CROWN_GREENER


## True when no ground is between the eye and the point (the overview grid).
static func _clear_view(w: VungTau, eye: Vector3, point: Vector3) -> bool:
	var length := eye.distance_to(point)
	var t := 20.0
	while t < length - 40.0:
		var at := eye.lerp(point, t / length)
		if w.data.overview_height(at.x, at.z) > at.y:
			return false
		t += 20.0
	return true


## The viewpoints, from the landmarks in the data.
static func views(w: VungTau) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var front := w.data.landmark("bai_truoc")
	var big := w.data.landmark("nui_lon")
	var hill := w.data.landmark("nui_nho")
	var back := w.data.landmark("bai_sau")
	if d_ok(front) and d_ok(big) and d_ok(hill):
		# Out in the bay, at right angles to the line between the two hills, on
		# the side away from the land (D-0005-02).
		var big_top := _top(w, big)
		var small_top := _top(w, hill)
		var middle := (big_top + small_top) / 2.0
		middle.y = 0.0
		var along := (small_top - big_top) * Vector3(1, 0, 1)
		var out := Vector3(along.z, 0.0, -along.x).normalized()
		var land: Vector3 = w.spawn().position
		if out.dot(Vector3(front.position[0] - land.x, 0.0, front.position[1] - land.z)) < 0.0:
			out = -out
		result.append({"name": "bai_truoc_from_water", "eye": middle + out * BAY_OUT_M + Vector3(0, BAY_HEIGHT_M, 0),
				"target": middle + Vector3(0, 10.0, 0), "frame": ["nui_lon", "nui_nho", "bai_truoc"]})
		# Higher than the trees of the top, looking at Bãi Trước with Núi Nhỏ behind it.
		result.append({"name": "nui_lon_south_east", "eye": big_top + Vector3(0, 18.0, 0),
				"target": Vector3(front.position[0], 0.0, front.position[1]),
				"frame": ["nui_nho", "bai_truoc"]})
	if d_ok(hill):
		var top := _top(w, hill)
		result.append({"name": "nui_nho_north", "eye": top, "target": top + Vector3(0, -40.0, -400.0),
				"frame": ["nui_lon"]})
		if d_ok(back):
			result.append({"name": "nui_nho_north_east", "eye": top,
					"target": Vector3(back.position[0], 0.0, back.position[1]), "frame": ["bai_sau"]})
	var cape := w.data.landmark("mui_nghinh_phong")
	if d_ok(cape):
		var point := Vector3(cape.position[0], 0.0, cape.position[1])
		point.y = maxf(w.ground_height(point.x, point.z), 0.0) + 6.0
		result.append({"name": "nghinh_phong_south", "eye": point, "target": point + Vector3(0, -10.0, 400.0)})
	var hai_dang := _road_points(w, "Hải Đăng")
	if hai_dang.size() > 10:
		# From the bottom of the Hải Đăng road, up the road.
		var bottom := hai_dang[0] + Vector3(0, Player.EYE_HEIGHT, 0)
		result.append({"name": "hai_dang_road", "eye": bottom, "target": hai_dang[10] + Vector3(0, 2.0, 0)})
	if d_ok(back):
		var beach := Vector3(back.position[0], 0.0, back.position[1])
		var road := _nearest_road_point(w, beach)
		road.y = w.ground_height(road.x, road.z) + Player.EYE_HEIGHT
		result.append({"name": "bai_sau_from_road", "eye": road, "target": beach + Vector3(0, 1.0, 0)})
	return result


static func d_ok(record: Dictionary) -> bool:
	return not record.is_empty()


## The points of the longest road with the name, from its lowest end.
static func _road_points(w: VungTau, road_name: String) -> Array[Vector3]:
	var best: Array = []
	for road: Dictionary in w.data.roads:
		if road.name == road_name and road.points.size() > best.size():
			best = road.points
	var result: Array[Vector3] = []
	for p: Array in best:
		result.append(Vector3(p[0], p[1], p[2]))
	if result.size() > 1 and result[0].y > result[result.size() - 1].y:
		result.reverse()
	return result


## The eye point 12 m above the ground at the top of a hill.
static func _top(w: VungTau, record: Dictionary) -> Vector3:
	var top := Vector3(record.position[0], 0.0, record.position[1])
	top.y = w.ground_height(top.x, top.z) + 12.0
	return top


## The nearest point of a main road to the point.
static func _nearest_road_point(w: VungTau, point: Vector3) -> Vector3:
	var best := point
	var best_distance := INF
	for road: Dictionary in w.data.roads:
		if road.type not in ["primary", "secondary", "tertiary"]:
			continue
		for p: Array in road.points:
			var d := Vector2(p[0] - point.x, p[2] - point.z).length()
			if d < best_distance:
				best_distance = d
				best = Vector3(p[0], p[1], p[2])
	return best
