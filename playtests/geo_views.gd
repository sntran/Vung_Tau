extends RefCounted
# PT-33 geo_views. Take screenshots from fixed viewpoints: Bãi Trước seen from
# the water, the top of Núi Nhỏ looking north, Mũi Nghinh Phong looking south,
# and Bãi Sau from the beach road. Take each one at 06:00, 12:00, and 18:00.
# I compare them with the real places.
# The fourth run takes the same views at 21:00, for the night light (R14).
# The fifth run is on 3 June 2027, in the rainy season (R12a): the hills are
# green, and the flame trees show red flowers. The other runs are on day 1, in
# the dry season: the hills are partly dry. Each run also looks up the Hải Đăng
# road, where the flame trees stand.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=06:00
# phase: --world=vung_tau --start-time=12:00
# phase: --world=vung_tau --start-time=18:00
# phase: --world=vung_tau --start-time=21:00
# phase: --world=vung_tau --start-time=12:00 --start-date=2027-06-03


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
	for view: Dictionary in views(w):
		if view.is_empty():
			continue
		await d.fly_to(view.eye, view.target)
		await d.wait_ground(60.0)
		await d.wait_frames(5)
		await d.screenshot("%s_%s" % [view.name, time])
	d.fly_end()


## The viewpoints, from the landmarks in the data.
static func views(w: VungTau) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var front := w.data.landmark("bai_truoc")
	var start := w.spawn()
	if d_ok(front):
		var beach := Vector3(front.position[0], 0.0, front.position[1])
		var land: Vector3 = start.position
		var out := Vector3(beach.x - land.x, 0.0, beach.z - land.z).normalized()
		result.append({"name": "bai_truoc_from_water", "eye": beach + out * 260.0 + Vector3(0, 4.0, 0),
				"target": beach + Vector3(0, 8.0, 0)})
	var hill := w.data.landmark("nui_nho")
	if d_ok(hill):
		var top := Vector3(hill.position[0], 0.0, hill.position[1])
		top.y = w.ground_height(top.x, top.z) + 12.0
		result.append({"name": "nui_nho_north", "eye": top, "target": top + Vector3(0, -40.0, -400.0)})
	var cape := w.data.landmark("mui_nghinh_phong")
	if d_ok(cape):
		var point := Vector3(cape.position[0], 0.0, cape.position[1])
		point.y = maxf(w.ground_height(point.x, point.z), 0.0) + 6.0
		result.append({"name": "nghinh_phong_south", "eye": point, "target": point + Vector3(0, -10.0, 400.0)})
	if w.roadworks != null:
		var works_line: Array = w.roadworks.record.points
		var bottom := Vector3(works_line[0][0], works_line[0][1] + Player.EYE_HEIGHT, works_line[0][2])
		var up: Array = works_line[mini(10, works_line.size() - 1)]
		result.append({"name": "hai_dang_road", "eye": bottom, "target": Vector3(up[0], up[1] + 2.0, up[2])})
	var back := w.data.landmark("bai_sau")
	if d_ok(back):
		var beach := Vector3(back.position[0], 0.0, back.position[1])
		var road := _nearest_road_point(w, beach)
		road.y = w.ground_height(road.x, road.z) + Player.EYE_HEIGHT
		result.append({"name": "bai_sau_from_road", "eye": road, "target": beach + Vector3(0, 1.0, 0)})
	return result


static func d_ok(record: Dictionary) -> bool:
	return not record.is_empty()


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
