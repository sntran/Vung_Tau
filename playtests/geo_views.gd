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
# At 12:00 on day 1 (report 0005, D-0005-09): in the views from Núi Lớn, from
# Núi Nhỏ, and on the Hải Đăng road, 30 % or more of the land pixels are green
# (green is the largest channel), and the mean value of the land is 0.40 to
# 0.55. In the view from Núi Lớn, 40 % or more of the town pixels have a
# saturation above 0.2.
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
## D-0005-09: the land of the views at 12:00 on day 1.
const LAND_VIEWS := ["nui_lon_south_east", "nui_nho_north", "hai_dang_road"]
const MIN_GREEN := 0.3
const VALUE_RANGE := Vector2(0.4, 0.55)
const MIN_TOWN_SATURATED := 0.4
const LAND_STEP_M := 20.0
const LAND_RADIUS_M := 1500.0
## Report 0020, D-0020-01: things nearer than NEAR_M to the camera (for
## example a tree crown at the eye) cover NEAR_SHARE of a view or less.
const NEAR_M := 3.0
const NEAR_SHARE := 0.05
## The scrub check near the Bãi Sau view (plan 0020, R10a).
const SCRUB_RADIUS_M := 250.0


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
		if time == "1200":
			var near := await near_share(d, w)
			d.step("%s: %.1f %% of the frame is nearer than %.0f m" % [view.name, near * 100.0, NEAR_M])
			d.expect(near <= NEAR_SHARE, "%s: things nearer than %.0f m cover %.1f %% of the frame, %.0f %% or less (D-0020-01)" % [
					view.name, NEAR_M, near * 100.0, NEAR_SHARE * 100.0])
		for place: String in view.get("frame", []):
			var record := w.data.landmark(place)
			var point := Vector3(record.position[0], maxf(float(record.get("height", 0.0)), 0.0), record.position[1])
			d.expect(in_frame(d, point), "%s: %s is in the frame" % [view.name, record.name_vi])
		if view.name == "nui_nho_north" and (time == "1200" or time == "june"):
			await _check_canopy(d, w, time)
		if time == "1200" and view.name in LAND_VIEWS:
			_check_land(d, w, view.name)
		if time == "1200" and view.name == "bai_sau_from_road":
			_check_scrub(d, w, view.eye)
	d.fly_end()


## True when the point is in front of the camera and in the frame.
static func in_frame(d: PlaytestDriver, point: Vector3) -> bool:
	var camera := d.viewport().get_camera_3d()
	if camera.is_position_behind(point):
		return false
	return d.viewport().get_visible_rect().has_point(camera.unproject_position(point))


## The slopes of Núi Lớn show the color of tree crowns, not the color of grass
## (D-0005-01). With the near trees hidden, the check reads the color at
## points on the slopes, then hides the far form of the trees and the tree
## cover of the ground (the ground is grass there then) and reads the same
## points again. A point shows a crown when it is darker or greener than the
## grass at the same point.
static func _check_canopy(d: PlaytestDriver, w: VungTau, time: String) -> void:
	# The near trees of the top of Núi Nhỏ can stand in front of some points:
	# the check is about the far form, so they are hidden for both readings.
	w.trees.visible = false
	await d.wait_frames(3)
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
	w.trees.visible = true
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


## The part of the frame that shows things nearer than NEAR_M (report 0020,
## D-0020-01). The test draws the view two times with the far plane of the
## camera at NEAR_M and the background in two colors: a pixel that is the same
## in both pictures shows a near thing. The phone button and the action button
## are not counted.
static func near_share(d: PlaytestDriver, w: VungTau) -> float:
	var camera := d.viewport().get_camera_3d()
	var env := w.environment
	var saved := [camera.far, env.background_mode, env.background_color, env.fog_enabled, env.reflected_light_source]
	camera.far = NEAR_M
	env.background_mode = Environment.BG_COLOR
	env.fog_enabled = false
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	var pictures: Array[Image] = []
	for color: Color in [Color(1, 0, 1), Color(0, 1, 0)]:
		env.background_color = color
		await d.wait_frames(4)
		pictures.append(d.viewport().get_texture().get_image())
	camera.far = saved[0]
	env.background_mode = saved[1]
	env.background_color = saved[2]
	env.fog_enabled = saved[3]
	env.reflected_light_source = saved[4]
	await d.wait_frames(2)
	var m: Node = d.main()
	var skip: Array[Rect2] = [m.phone.button.get_global_rect()]
	if m.action_button.visible:
		skip.append(m.action_button.get_global_rect())
	var scale := Vector2(pictures[0].get_size()) / d.viewport().get_visible_rect().size
	var near := 0
	var total := 0
	for y in range(0, pictures[0].get_height(), 6):
		for x in range(0, pictures[0].get_width(), 6):
			var at := Vector2(x, y) / scale
			if skip.any(func(r: Rect2) -> bool: return r.has_point(at)):
				continue
			total += 1
			var a := pictures[0].get_pixel(x, y)
			var b := pictures[1].get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.1:
				near += 1
	return float(near) / maxf(total, 1)


## Plan 0020, R10a: the scrub near the view stands on the bushes and the
## trees of the cover map, not on the sand, the grass, or the bare ground
## behind Bãi Sau (the canopy map has low heights there too).
static func _check_scrub(d: PlaytestDriver, w: VungTau, eye: Vector3) -> void:
	var wrong := []
	var near: Array = w.trees.trees_near("scrub", eye, SCRUB_RADIUS_M)
	for entry: Array in near:
		var p: Vector3 = entry[0]
		var cover := w.cover_at(p.x, p.z)
		if cover.g <= 0.3 and cover.r <= VungTau.FOREST_COVER:
			wrong.append("(%.0f, %.0f) cover %s" % [p.x, p.z, cover])
	d.step("bai_sau_from_road: %d scrub bushes within %.0f m" % [near.size(), SCRUB_RADIUS_M])
	d.expect(wrong.is_empty(), "bai_sau_from_road: no scrub on sand, grass, or bare ground: %d, %s" % [
			wrong.size(), wrong.slice(0, 6)])


## D-0005-09: the colors of the land in the view, from points on a grid of
## the ground that are in the frame and not behind other ground.
static func _check_land(d: PlaytestDriver, w: VungTau, view_name: String) -> void:
	var camera := d.viewport().get_camera_3d()
	var eye := camera.global_position
	var land: Array[Vector2] = []
	var land_near: Array[bool] = []
	var town: Array[Vector2] = []
	# On a road the land is near; on a hill top the view goes far.
	var high := eye.y - w.ground_height(eye.x, eye.z) > 5.0
	var radius := LAND_RADIUS_M if high else 400.0
	var step := LAND_STEP_M if high else 5.0
	var steps := int(radius / step)
	for j in range(-steps, steps + 1):
		for i in range(-steps, steps + 1):
			var x := eye.x + i * step
			var z := eye.z + j * step
			var h := w.data.overview_height(x, z)
			if h < maxf(w.last_high, 1.0) + 0.5:
				continue
			var point := Vector3(x, h, z)
			if not in_frame(d, point) or not _clear_view(w, eye, point):
				continue
			var screen := camera.unproject_position(point)
			land.append(screen)
			land_near.append(eye.distance_to(point) < 300.0)
			var mask := w.surface_at(x, z)
			# The town: the built-up class of the cover map (no cover channel), not sand.
			var cover := w.cover_at(x, z)
			if mask.r < 0.3 and cover.r + cover.g + cover.b + cover.a < 0.3:
				town.append(screen)
	var colors := pixel_colors(d, land)
	var green := 0
	var value := 0.0
	var near_sum := Vector2.ZERO
	for k in colors.size():
		var c := colors[k]
		if c.g >= c.r and c.g >= c.b:
			green += 1
		value += c.v
		if land_near[k]:
			near_sum += Vector2(c.v, 1.0)
	d.step("%s: eye %.0f m above the ground; %d points nearer than 300 m, with a mean value of %.2f" % [
			view_name, eye.y - w.ground_height(eye.x, eye.z), near_sum.y, near_sum.x / maxf(near_sum.y, 1.0)])
	var n := maxf(colors.size(), 1)
	d.step("%s, 12:00 day 1: %d land points, %.0f %% green, mean value %.2f" % [view_name, colors.size(), 100.0 * green / n, value / n])
	d.expect(colors.size() >= 30, "%s: the view shows land: %d points" % [view_name, colors.size()])
	d.expect(green >= MIN_GREEN * n, "%s: %.0f %% of the land is green, it must be %.0f %% or more (D-0005-09)" % [
			view_name, 100.0 * green / n, MIN_GREEN * 100.0])
	d.expect(value / n >= VALUE_RANGE.x and value / n <= VALUE_RANGE.y, "%s: the mean value of the land is %.2f, it must be %.2f to %.2f (D-0005-09)" % [
			view_name, value / n, VALUE_RANGE.x, VALUE_RANGE.y])
	if view_name == "nui_lon_south_east":
		var town_colors := pixel_colors(d, town)
		var saturated := 0
		for c: Color in town_colors:
			if c.s > 0.2:
				saturated += 1
		var t := maxf(town_colors.size(), 1)
		d.step("%s: %d town points, %.0f %% with a saturation above 0.2" % [view_name, town_colors.size(), 100.0 * saturated / t])
		d.expect(town_colors.size() >= 30, "%s: the view shows the town: %d points" % [view_name, town_colors.size()])
		d.expect(saturated >= MIN_TOWN_SATURATED * t, "%s: %.0f %% of the town has a saturation above 0.2, it must be %.0f %% or more (D-0005-09)" % [
				view_name, 100.0 * saturated / t, MIN_TOWN_SATURATED * 100.0])


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
		var north := _over_trees(w, top)
		result.append({"name": "nui_nho_north", "eye": north, "target": north + Vector3(0, -40.0, -400.0),
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


## The eye a little higher than the trees of the canopy map within 8 m (the
## hill trees have the heights of the map), so that a crown at the eye does
## not fill the view.
static func _over_trees(w: VungTau, eye: Vector3) -> Vector3:
	var trees := 0.0
	for j in range(-2, 3):
		for i in range(-2, 3):
			trees = maxf(trees, w.canopy_height_at(eye.x + i * 4.0, eye.z + j * 4.0))
	eye.y = maxf(eye.y, w.ground_height(eye.x, eye.z) + trees + 1.0)
	return eye


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
