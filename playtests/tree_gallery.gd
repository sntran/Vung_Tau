extends RefCounted
# PT-52 tree_gallery (plan 0020). A test ground with each tree type and its
# variants in a row: a flat floor over the sea west of Bãi Trước, with the
# sun, the sky, and the season of the Vũng Tàu world. The test takes a
# screenshot of each type at 8 m, 30 m, 120 m, and 400 m, at 07:00, 12:00, and
# 17:30, on day 1 (22 January 2019) and on 3 June 2019, on Low. The High runs
# are in tree_gallery_high.gd. Each run is in phases of a group of types, so
# that a phase takes less than the time limit under lavapipe.
# Checks: each screenshot of a tree has leaf-colored pixels in the crown area.
# At 12:00, at each change of form (the end of the near and of the middle form
# of the preset), the mean color of the crown area changes by 8 % or less
# (R6): the same view with the form before the end and with the form after it. The last phase makes one sheet for each type (sheet_TYPE.png): a row
# for each run, a column for each distance.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=07:00 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=07:00 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=17:30 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=17:30 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=07:00 --start-date=2019-06-03 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=07:00 --start-date=2019-06-03 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --start-date=2019-06-03 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --start-date=2019-06-03 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=17:30 --start-date=2019-06-03 --quality=low --renderer=forward_plus
# phase: --world=vung_tau --start-time=17:30 --start-date=2019-06-03 --quality=low --renderer=forward_plus
# phase: --start-time=12:00

## The runs (a time, a date, and a preset) in the order of the phase lines, and the groups of types in each run.
const RUNS := ["0700_day1_low", "1200_day1_low", "1730_day1_low", "0700_june_low", "1200_june_low", "1730_june_low"]
const GROUPS := 2
const DISTANCES := [8.0, 30.0, 120.0, 400.0]
## The test ground: the middle of the first row, over the sea west of Bãi Trước.
const ORIGIN := Vector3(-3200.0, 4.0, 300.0)
const TYPE_SPACING := 90.0
const VARIANT_SPACING := 20.0
## The source of the gallery trees in the TreeField.
const SOURCE := Vector2i(777777, 777777)
## A crown area must have this part of leaf-colored pixels, or more.
const MIN_LEAF_SHARE := 0.05
## The mean color of the crown area changes by this part, or less, at a change of form (R6).
const MAX_FORM_CHANGE := 0.08
const SHEET_CELL := Vector2i(320, 180)


func runs() -> Array:
	return RUNS


func groups() -> int:
	return GROUPS


func run(d: PlaytestDriver) -> void:
	if d.phase == runs().size() * groups() + 1:
		_make_sheets(d, runs())
		return
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts with --world=vung_tau"):
		return
	var run_name: String = runs()[(d.phase - 1) / groups()]
	var group := (d.phase - 1) % groups()
	var library := w.trees.library
	_build_ground(w)
	var types: Array[String] = []
	for type: String in library.names:
		if library.has_type(type):
			types.append(type)
	d.expect(types.size() == library.names.size(), "each type of data/trees/types.json has its files: %d of %d" % [
			types.size(), library.names.size()])
	for i in types.size():
		var transforms: Array[Transform3D] = []
		var variants: Array[int] = []
		for v in library.variants(types[i]):
			transforms.append(Transform3D(Basis(), _base(i, v)))
			variants.append(v)
		w.trees.add_trees(SOURCE, types[i], transforms, false, variants)
	await d.fly_to(_base(group * ceili(float(types.size()) / groups()), 1) + Vector3(0, 30.0, 60.0), ORIGIN)
	await d.wait_ground(120.0)
	var per_group := ceili(float(types.size()) / groups())
	for i in range(group * per_group, mini((group + 1) * per_group, types.size())):
		var type := types[i]
		var info := library.variant_info(type, 1)
		var crown := _crown(i, info)
		for distance: float in DISTANCES:
			await _look(d, i, info, distance)
			await d.screenshot("%s_%dm_%s" % [type, int(distance), run_name])
			# A type with no far form (the scrub) ends at its middle range: the
			# ground draws the bushes farther away (plan 0020, N3).
			if not library.has_far(type) and distance > TreeLibrary.ranges.y * library.range_scale(type):
				d.step("%s at %d m: no far form, farther than its middle range" % [type, int(distance)])
				continue
			var share := _leaf_share(d, crown)
			d.expect(share >= MIN_LEAF_SHARE, "%s at %d m: %.0f %% of the crown area has a leaf color, it must be %.0f %% or more" % [
					type, int(distance), share * 100.0, MIN_LEAF_SHARE * 100.0])
		if run_name.begins_with("1200"):
			await _check_form_changes(d, w, i, type, info, crown)
	w.trees.remove_source(SOURCE)
	d.fly_end()


## The base of a tree of the gallery.
static func _base(type_index: int, variant: int) -> Vector3:
	return ORIGIN + Vector3(type_index * TYPE_SPACING + (variant - 1) * VARIANT_SPACING, 0.0, 0.0)


## The middle and the radius of the crown of the middle variant.
static func _crown(type_index: int, info: Dictionary) -> Dictionary:
	var height := float(info.height)
	var radius := float(info.radius)
	return {"center": _base(type_index, 1) + Vector3(0, height * 0.62, 0), "rx": radius, "ry": maxf(radius, height * 0.35) * 0.9}


## The camera at a distance from the middle variant, at eye height, toward the crown.
static func _look(d: PlaytestDriver, type_index: int, info: Dictionary, distance: float) -> void:
	var base := _base(type_index, 1)
	var eye := base + Vector3(0, Player.EYE_HEIGHT, sqrt(maxf(distance * distance - 2.89, 1.0)))
	# Far away, the camera looks over the tree, so that the center dot of the screen is not on it.
	var target := base + Vector3(0, float(info.height) * (0.55 if distance > 10.0 else 0.75) + maxf(distance - 60.0, 0.0) * 0.06, 0)
	await d.fly_to(eye, target)
	await d.wait_frames(4)


## The floor of the gallery: a flat plane, the color of dry ground.
static func _build_ground(w: VungTau) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000.0, 1400.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#8C8270")
	material.roughness = 0.95
	plane.material = material
	var floor := MeshInstance3D.new()
	floor.name = "TreeGallery"
	floor.mesh = plane
	floor.position = ORIGIN + Vector3(600.0, -0.02, 150.0)
	w.add_child(floor)


## The screen box of the crown: Rect2 in viewport pixels, clipped to the screen.
static func _crown_box(d: PlaytestDriver, crown: Dictionary) -> Rect2:
	var camera := d.viewport().get_camera_3d()
	var center: Vector3 = crown.center
	var box := Rect2()
	var first := true
	for corner: Vector3 in [Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(-1, 1, 0), Vector3(1, 1, 0), Vector3(0, 0, 0)]:
		var p := center + camera.global_basis.x * corner.x * float(crown.rx) + camera.global_basis.y * corner.y * float(crown.ry)
		if camera.is_position_behind(p):
			continue
		var s := camera.unproject_position(p)
		box = Rect2(s, Vector2.ZERO) if first else box.expand(s)
		first = false
	return box.intersection(d.viewport().get_visible_rect())


## The part of the crown box with a leaf color: green or olive (green is the
## largest channel, or near it), or the red and orange of the dry season.
static func _leaf_share(d: PlaytestDriver, crown: Dictionary) -> float:
	var stats := _crown_stats(d, crown)
	return stats.leaf_share


static func _crown_stats(d: PlaytestDriver, crown: Dictionary) -> Dictionary:
	var box := _crown_box(d, crown)
	var image := d.viewport().get_texture().get_image()
	var scale := Vector2(image.get_size()) / d.viewport().get_visible_rect().size
	var from := Vector2i((box.position * scale).floor())
	var to := Vector2i((box.end * scale).floor())
	var step := maxi(1, (to.x - from.x) / 80)
	var total := 0
	var leaf := 0
	var sum := Color(0, 0, 0)
	for y in range(maxi(from.y, 0), mini(to.y, image.get_height()), step):
		for x in range(maxi(from.x, 0), mini(to.x, image.get_width()), step):
			var c := image.get_pixel(x, y)
			total += 1
			sum += c
			var greenish := c.g >= c.r * 0.92 and c.g > c.b * 1.05
			var autumn := c.r > c.g and c.g > c.b * 1.1 and c.r > c.b * 1.4
			if greenish or autumn:
				leaf += 1
	var n := maxf(total, 1)
	return {"leaf_share": leaf / n, "mean": Color(sum.r / n, sum.g / n, sum.b / n), "pixels": total}


## R6: at the end of the near and of the middle form of the preset, the
## same view (the same camera and light) with the form before the end and
## with the form after it. For each of the two pictures, the test moves the
## ranges of the forms for a moment, so that only that form shows.
static func _check_form_changes(d: PlaytestDriver, w: VungTau, type_index: int, type: String, info: Dictionary,
		crown: Dictionary) -> void:
	var scale := w.trees.library.range_scale(type)
	var saved := TreeLibrary.ranges
	var ends := [{"name": "near to middle", "at": saved.x * scale * w.trees.library.near_scale(type),
			"before": Vector3(saved.x * 3.0, saved.y * 3.0, saved.z), "after": Vector3(saved.x * 0.3, saved.y, saved.z)}]
	if w.trees.library.has_far(type):
		ends.append({"name": "middle to far", "at": saved.y * scale,
				"before": Vector3(saved.x * 0.3, saved.y * 3.0, saved.z * 3.0), "after": Vector3(saved.x * 0.3, saved.y * 0.3, saved.z * 3.0)})
	for end: Dictionary in ends:
		var at: float = end.at
		await _look(d, type_index, info, at)
		var means: Array[Color] = []
		for key: String in ["before", "after"]:
			_set_ranges(end[key])
			await d.wait_frames(4)
			means.append(_crown_stats(d, crown).mean)
		_set_ranges(saved)
		var a: Color = means[0]
		var b: Color = means[1]
		var change := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() / maxf(Vector3(a.r, a.g, a.b).length(), 0.05)
		d.expect(change <= MAX_FORM_CHANGE, "%s, %s at %.0f m: the mean color of the crown area changes by %.1f %% (%s to %s), it must be %.0f %% or less" % [
				type, end.name, at, change * 100.0, a.to_html(false), b.to_html(false), MAX_FORM_CHANGE * 100.0])
	await d.wait_frames(3)


static func _set_ranges(value: Vector3) -> void:
	TreeLibrary.ranges = value
	RenderingServer.global_shader_parameter_set("tree_ranges", value)


## The last phase: one sheet for each type from the screenshots of the other phases.
static func _make_sheets(d: PlaytestDriver, run_names: Array) -> void:
	var files := DirAccess.get_files_at(d.out_dir)
	var library := TreeLibrary.shared()
	for type: String in library.names:
		var sheet := Image.create(SHEET_CELL.x * DISTANCES.size(), SHEET_CELL.y * run_names.size(), false, Image.FORMAT_RGB8)
		sheet.fill(Color("#202020"))
		var found := 0
		for r in run_names.size():
			for c in DISTANCES.size():
				var suffix := "-%s_%dm_%s.png" % [type, int(DISTANCES[c]), run_names[r]]
				for file: String in files:
					if file.ends_with(suffix):
						var image := Image.load_from_file(d.out_dir.path_join(file))
						image.convert(Image.FORMAT_RGB8)
						image.resize(SHEET_CELL.x, SHEET_CELL.y, Image.INTERPOLATE_BILINEAR)
						sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SHEET_CELL), Vector2i(c * SHEET_CELL.x, r * SHEET_CELL.y))
						found += 1
						break
		var path := d.out_dir.path_join("sheet_%s.png" % type)
		sheet.save_png(path)
		d.step("sheet_%s.png: %d of %d screenshots (rows: %s; columns: %s m)" % [type, found, run_names.size() * DISTANCES.size(),
				", ".join(run_names), DISTANCES])
		d.expect(found == run_names.size() * DISTANCES.size(), "sheet_%s.png has all its screenshots" % type)
