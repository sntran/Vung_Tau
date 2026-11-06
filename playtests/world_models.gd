extends RefCounted
# PT-56 world_models (plan 0023, R11). The review sheet of each model of
# data/world/orders.json: a test ground over the sea west of Bãi Trước, with
# the sun and the sky of the Vũng Tàu world, at 12:00 on Low and on High. For
# each model and each level (near, mid, far): a screenshot from the front,
# from the side, and from three quarters, with only that level shown.
# Checks: no magenta pixel and no surface with no material of the game; the
# model stands on the ground (its lowest point at the floor, ±1 cm); the levels
# have the ranges of the preset; at each change of level the mean color of the
# model area changes by 12 % or less. The last phase makes one sheet for each
# model (sheet_ID.png): a row for each preset and level, a column for each
# view. Each preset is in phases of GROUP_SIZE models, so that a phase takes
# less than the time limit under lavapipe.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=12:00 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --start-time=12:00

const RUNS := ["low", "high"]
## The views: the angle of the camera around the model from its front (+Z).
const VIEWS := {"front": 0.0, "side": 90.0, "three_quarters": 40.0}
const VIEW_ORDER := ["front", "side", "three_quarters"]
## The test ground, over the sea west of Bãi Trước.
const ORIGIN := Vector3(-3200.0, 4.0, 600.0)
const SPACING := 12.0
const MAX_LEVEL_CHANGE := 0.12
const SHEET_CELL := Vector2i(320, 180)
## The models of one phase, and the phases of one preset.
const GROUP_SIZE := 2
const GROUPS := 5


func run(d: PlaytestDriver) -> void:
	if d.phase == RUNS.size() * GROUPS + 1:
		_make_sheets(d)
		return
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts with --world=vung_tau"):
		return
	var preset: String = RUNS[(d.phase - 1) / GROUPS]
	var group := (d.phase - 1) % GROUPS
	_build_ground(w)
	var ids := WorldModel.ids()
	d.expect(ids.size() <= GROUP_SIZE * GROUPS, "the phases have room for the %d models" % ids.size())
	var models: Array[WorldModel] = []
	for i in range(group * GROUP_SIZE, mini((group + 1) * GROUP_SIZE, ids.size())):
		var model := WorldModel.make(ids[i], Color("#B0302A"))
		if not d.expect(model != null, "%s loads with the materials of the game" % ids[i]):
			continue
		model.position = _base(i)
		w.add_child(model)
		models.append(model)
	if models.is_empty():
		return
	await d.fly_to(models[0].position + Vector3(0, 3.0, 8.0), models[0].position)
	await d.wait_ground(120.0)
	for i in models.size():
		var model := models[i]
		_check_model(d, model, preset)
		for level: String in WorldModel.levels_of(model.id):
			_show_only(model, level)
			for view: String in VIEW_ORDER:
				await _look(d, model, VIEWS[view], _distance(model))
				var stats := _stats(d, model)
				d.expect(stats.magenta == 0, "%s %s %s: no magenta pixel (%d)" % [model.id, level, view, stats.magenta])
				d.expect(stats.pixels > 0, "%s %s %s: the model is on the screen" % [model.id, level, view])
				await d.screenshot("%s_%s_%s_%s" % [model.id, preset, level, view])
		_show_all(model)
		await _check_level_changes(d, model)
	d.fly_end()


static func _base(i: int) -> Vector3:
	return ORIGIN + Vector3(i * SPACING, 0.0, 0.0)


## The distance of the camera: the whole model fills about half of the screen.
static func _distance(model: WorldModel) -> float:
	var box := model.level_aabb(WorldModel.levels_of(model.id)[0])
	return maxf(maxf(box.size.x, box.size.z), box.size.y) * 1.6 + 0.8


static func _check_model(d: PlaytestDriver, model: WorldModel, preset: String) -> void:
	for level: String in WorldModel.levels_of(model.id):
		var box := model.level_aabb(level)
		d.expect(absf(box.position.y) <= 0.01, "%s %s: the model stands on the ground (lowest point %.3f m)" % [
				model.id, level, box.position.y])
		for node in model.level(level).find_children("*", "MeshInstance3D", true, false):
			var m := node as MeshInstance3D
			for s in m.mesh.get_surface_count():
				if m.get_surface_override_material(s) == null:
					d.fail("%s %s: the surface %d of %s has no material of the game" % [model.id, level, s, m.name])
	var r: Vector3 = WorldModel.RANGES[preset]
	d.expect(WorldModel.ranges == r, "the ranges of the preset %s: %s" % [preset, WorldModel.ranges])
	if model.level("near") != null:
		var near := model.level("near").find_children("*", "GeometryInstance3D", true, false)[0] as GeometryInstance3D
		d.expect(is_equal_approx(near.visibility_range_end, r.x), "%s: the near level ends at %.0f m (%.0f)" % [
				model.id, r.x, near.visibility_range_end])
	if model.level("mid") != null and model.level("near") != null:
		var mid := model.level("mid").find_children("*", "GeometryInstance3D", true, false)[0] as GeometryInstance3D
		d.expect(is_equal_approx(mid.visibility_range_begin, r.x) and is_equal_approx(mid.visibility_range_end, r.y),
				"%s: the mid level shows from %.0f m to %.0f m (%.0f to %.0f)" % [model.id, r.x, r.y,
				mid.visibility_range_begin, mid.visibility_range_end])
	d.step("%s: %s" % [model.id, model.receipt().get("sources", [])])


## Only one level shows: the test turns the others off for the screenshot.
static func _show_only(model: WorldModel, level: String) -> void:
	for name: String in WorldModel.LEVELS:
		var node := model.level(name)
		if node != null:
			node.visible = name == level
			for g in node.find_children("*", "GeometryInstance3D", true, false):
				(g as GeometryInstance3D).visibility_range_begin = 0.0
				(g as GeometryInstance3D).visibility_range_end = 0.0


static func _show_all(model: WorldModel) -> void:
	for name: String in WorldModel.LEVELS:
		var node := model.level(name)
		if node != null:
			node.visible = true
	model.apply_ranges()


static func _look(d: PlaytestDriver, model: WorldModel, angle: float, distance: float) -> void:
	var box := model.level_aabb(WorldModel.levels_of(model.id)[0])
	var center := model.global_position + Vector3(0, box.size.y * 0.5, 0)
	var dir := Vector3(sin(deg_to_rad(angle)), 0.0, cos(deg_to_rad(angle)))
	var eye := center + dir * distance + Vector3(0, maxf(0.6, distance * 0.25), 0)
	await d.fly_to(eye, center)
	await d.wait_frames(4)


## The screen box of the model.
static func _screen_box(d: PlaytestDriver, model: WorldModel) -> Rect2:
	var camera := d.viewport().get_camera_3d()
	var box := model.level_aabb(WorldModel.levels_of(model.id)[0])
	var rect := Rect2()
	var first := true
	for i in 8:
		var p := model.global_transform * box.get_endpoint(i)
		if camera.is_position_behind(p):
			continue
		var s := camera.unproject_position(p)
		rect = Rect2(s, Vector2.ZERO) if first else rect.expand(s)
		first = false
	return rect.intersection(d.viewport().get_visible_rect())


static func _stats(d: PlaytestDriver, model: WorldModel) -> Dictionary:
	var box := _screen_box(d, model)
	var image := d.viewport().get_texture().get_image()
	var scale := Vector2(image.get_size()) / d.viewport().get_visible_rect().size
	var from := Vector2i((box.position * scale).floor())
	var to := Vector2i((box.end * scale).floor())
	var step := maxi(1, (to.x - from.x) / 120)
	var total := 0
	var magenta := 0
	var sum := Color(0, 0, 0)
	for y in range(maxi(from.y, 0), mini(to.y, image.get_height()), step):
		for x in range(maxi(from.x, 0), mini(to.x, image.get_width()), step):
			var c := image.get_pixel(x, y)
			total += 1
			sum += c
			if c.r > 0.8 and c.b > 0.8 and c.g < 0.3:
				magenta += 1
	var n := maxf(total, 1)
	return {"pixels": total, "magenta": magenta, "mean": Color(sum.r / n, sum.g / n, sum.b / n)}


## At the end of the near and of the mid level: the same view with the level
## before the end and with the level after it.
static func _check_level_changes(d: PlaytestDriver, model: WorldModel) -> void:
	var r := WorldModel.ranges
	var used := WorldModel.levels_of(model.id)
	for i in used.size() - 1:
		var at: float = r.x if i == 0 else r.y
		await _look(d, model, VIEWS.three_quarters, at)
		var means: Array[Color] = []
		for level: String in [used[i], used[i + 1]]:
			_show_only(model, level)
			await d.wait_frames(4)
			means.append(_stats(d, model).mean)
		_show_all(model)
		var a: Color = means[0]
		var b: Color = means[1]
		var change := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() / maxf(Vector3(a.r, a.g, a.b).length(), 0.05)
		d.step("%s, %s to %s at %.0f m: the change is %.1f %%" % [model.id, used[i], used[i + 1], at, change * 100.0])
		d.expect(change <= MAX_LEVEL_CHANGE, "%s, %s to %s at %.0f m: the mean color of the model area changes by %.1f %%, it must be %.0f %% or less" % [
				model.id, used[i], used[i + 1], at, change * 100.0, MAX_LEVEL_CHANGE * 100.0])


static func _build_ground(w: VungTau) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 200.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#8C8270")
	material.roughness = 0.95
	plane.material = material
	var floor := MeshInstance3D.new()
	floor.name = "WorldModelGround"
	floor.mesh = plane
	floor.position = ORIGIN + Vector3(150.0, -0.002, 0.0)
	w.add_child(floor)


## The last phase: one sheet for each model from the screenshots of the other phases.
static func _make_sheets(d: PlaytestDriver) -> void:
	var files := DirAccess.get_files_at(d.out_dir)
	for model_id: String in WorldModel.ids():
		var levels := WorldModel.levels_of(model_id)
		var rows: Array[String] = []
		for preset: String in RUNS:
			for level: String in levels:
				rows.append("%s_%s" % [preset, level])
		var sheet := Image.create(SHEET_CELL.x * VIEW_ORDER.size(), SHEET_CELL.y * rows.size(), false, Image.FORMAT_RGB8)
		sheet.fill(Color("#202020"))
		var found := 0
		for r in rows.size():
			for c in VIEW_ORDER.size():
				var suffix := "-%s_%s_%s.png" % [model_id, rows[r], VIEW_ORDER[c]]
				for file: String in files:
					if file.ends_with(suffix):
						var image := Image.load_from_file(d.out_dir.path_join(file))
						image.convert(Image.FORMAT_RGB8)
						image.resize(SHEET_CELL.x, SHEET_CELL.y, Image.INTERPOLATE_BILINEAR)
						sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SHEET_CELL), Vector2i(c * SHEET_CELL.x, r * SHEET_CELL.y))
						found += 1
						break
		sheet.save_png(d.out_dir.path_join("sheet_%s.png" % model_id))
		d.step("sheet_%s.png: %d of %d screenshots (rows: %s; columns: %s)" % [model_id, found,
				rows.size() * VIEW_ORDER.size(), ", ".join(rows), ", ".join(VIEW_ORDER)])
		d.expect(found == rows.size() * VIEW_ORDER.size(), "sheet_%s.png has all its screenshots" % model_id)
