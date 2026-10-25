extends RefCounted
# PT-25 look_review (plan 0004). Fixed views of the hẻm at 07:00, 12:00, 17:30,
# and 20:00. Take still screenshots on High and on Low. Both use Forward+
# (D-0004-07). I compare them with docs/content/reference/houses.md.
# The report 0004 adds checks. The view from above (D-0004-03): at 12:00, 25 %
# to 40 % of the pixels of the buildings have a saturation above 0.25
# (D-0004-09). The light follows the time (D-0004-04): the mean brightness of
# the lower half of the view along the hẻm is lower at 20:00 than at 17:30,
# and lower at 17:30 than at 12:00.
# Forward+ with SDFGI takes about 2 s for one frame under lavapipe (D7), so
# each run takes only the screenshots.
# sizes: 1280x720
# phase: --renderer=forward_plus --quality=high --start-time=07:00 --fresh-save
# phase: --renderer=forward_plus --quality=high --start-time=12:00 --fresh-save
# phase: --renderer=forward_plus --quality=high --start-time=17:30 --fresh-save
# phase: --renderer=forward_plus --quality=high --start-time=20:00 --fresh-save
# phase: --renderer=forward_plus --quality=low --start-time=07:00 --fresh-save
# phase: --renderer=forward_plus --quality=low --start-time=12:00 --fresh-save
# phase: --renderer=forward_plus --quality=low --start-time=17:30 --fresh-save
# phase: --renderer=forward_plus --quality=low --start-time=20:00 --fresh-save

const TIMES := ["0700", "1200", "1730", "2000"]
## The share of the building pixels with a saturation above SATURATED (D-0004-09).
const SATURATED := 0.25
const COLORFUL_SHARE := Vector2(0.25, 0.40)
## The distance between two measured pixels.
const SAMPLE_PX := 6


func run(d: PlaytestDriver) -> void:
	var high := d.phase <= 4
	var renderer := RenderingServer.get_current_rendering_method()
	d.expect(renderer == "forward_plus", "the renderer is %s" % renderer)
	d.expect(GameState.settings.quality == ("high" if high else "low"), "the preset is %s" % GameState.settings.quality)
	var environment: Environment = d.main().environment
	d.expect(environment.ssao_enabled == high, "SSAO is on only on High")
	d.expect(d.main().sun.shadow_enabled, "the sun casts shadows (R5)")
	var time: String = TIMES[(d.phase - 1) % 4]
	var tag := "high" if high else "low"
	for view: Dictionary in d.hem_views():
		await d.fly_to(view.eye, view.target)
		# SDFGI and the shadows need some frames to settle.
		await d.wait_frames(8 if high else 4)
		await d.screenshot("%s_%s_%s" % [view.name, time, tag])
		if view.name == "along":
			_check_brightness(d, time, tag)
		if view.name == "top" and time == "1200":
			var share := _colorful_share(d)
			d.step("%s, %s: %.0f %% of the building pixels have a saturation above %.2f" % [tag, time, share * 100.0, SATURATED])
			d.expect(share >= COLORFUL_SHARE.x and share <= COLORFUL_SHARE.y,
					"%s: %.0f %% of the building pixels from above are colorful, it must be %d %% to %d %%" % [
					tag, share * 100.0, int(COLORFUL_SHARE.x * 100), int(COLORFUL_SHARE.y * 100)])
	d.fly_end()


## Records the mean brightness of the lower half of the view. The run at
## 20:00 compares the values of the runs at 12:00, 17:30, and 20:00.
func _check_brightness(d: PlaytestDriver, time: String, tag: String) -> void:
	var image := d.viewport().get_texture().get_image()
	var total := 0.0
	var count := 0
	for y in range(image.get_height() / 2, image.get_height(), SAMPLE_PX):
		for x in range(0, image.get_width(), SAMPLE_PX):
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	var mean := total / maxf(count, 1)
	d.step("%s, %s: the mean brightness of the lower half is %.3f" % [tag, time, mean])
	var file := FileAccess.open(d.out_dir.path_join("brightness_%s_%s.txt" % [tag, time]), FileAccess.WRITE)
	file.store_string(str(mean))
	file.close()
	if time != "2000":
		return
	var values := {}
	for other: String in ["1200", "1730", "2000"]:
		var path := d.out_dir.path_join("brightness_%s_%s.txt" % [tag, other])
		if not d.expect(FileAccess.file_exists(path), "%s: the run at %s recorded its brightness" % [tag, other]):
			return
		values[other] = FileAccess.get_file_as_string(path).to_float()
	d.expect(values["2000"] < values["1730"], "%s: 20:00 (%.3f) is darker than 17:30 (%.3f)" % [tag, values["2000"], values["1730"]])
	d.expect(values["1730"] < values["1200"], "%s: 17:30 (%.3f) is darker than 12:00 (%.3f)" % [tag, values["1730"], values["1200"]])


## Returns the share of the pixels of the buildings with a saturation above
## SATURATED. A ray from the camera through each measured pixel finds what
## the pixel shows. It reads only the physics and the screen.
func _colorful_share(d: PlaytestDriver) -> float:
	var image := d.viewport().get_texture().get_image()
	var camera: Camera3D = d.main().player.camera
	var space := camera.get_world_3d().direct_space_state
	var scale := d.viewport().get_visible_rect().size / Vector2(image.get_size())
	var covered: Array[Rect2] = [d.main().action_button.get_global_rect(), d.main().phone.get_global_rect()]
	var buildings := 0
	var colorful := 0
	for y in range(0, image.get_height(), SAMPLE_PX):
		for x in range(0, image.get_width(), SAMPLE_PX):
			var at := Vector2(x, y) * scale
			if covered.any(func(rect: Rect2) -> bool: return rect.has_point(at)):
				continue
			var from := camera.project_ray_origin(at)
			var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(at) * 200.0, Layers.SOLID)
			var hit := space.intersect_ray(query)
			if hit.is_empty() or _house_of(hit.collider) == null:
				continue
			buildings += 1
			if image.get_pixel(x, y).s > SATURATED:
				colorful += 1
	d.expect(buildings > 1000, "the view from above shows the buildings: %d pixels" % buildings)
	return float(colorful) / maxf(buildings, 1)


func _house_of(node: Object) -> TubeHouse:
	var at := node as Node
	while at != null:
		if at is TubeHouse:
			return at
		at = at.get_parent()
	return null
