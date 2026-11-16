extends RefCounted
# PT-72 showcase_shots (plan 0026, R15). The five shots of the showcase of
# Bãi Trước (data/showcase/shots.json): each shot at 17:10 and at 12:00, on Low
# (the Mobile renderer) and on High (Forward+). tools/showcase/sheets.py puts
# the screenshots in docs/showcase/ with the link of the photo of each shot.
# The camera stands at the eye of the shot, with the field of view of the shot:
# a setup step, as fly_to() of PT-33. A shot is a frame of the short video of
# D7, so the screen UI (the phone button, the center dot) is hidden while it is
# taken. A shot fails when its ground is not ready.
# High takes the shots in two runs for each time: one run of five shots on
# Forward+ takes more than 300 s under lavapipe. The last run makes the sheet
# of each shot (sheet_ID.jpg): a column for Low and High, a row for each time.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=17:10 --quality=low
# phase: --world=vung_tau --start-time=12:00 --quality=low
# phase: --world=vung_tau --start-time=17:10 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=17:10 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --start-time=12:00

const SHOTS := "res://data/showcase/shots.json"
const SHEETS_FROM := SHOTS
## For each phase: the preset, the time, and the first and the last shot (from 0).
const RUNS := [
	["low", "1710", 0, 4],
	["low", "1200", 0, 4],
	["high", "1710", 0, 2],
	["high", "1710", 3, 4],
	["high", "1200", 0, 2],
	["high", "1200", 3, 4],
]


## A cell of a sheet.
const SHEET_CELL := Vector2i(640, 360)


func run(d: PlaytestDriver) -> void:
	if d.phase > RUNS.size():
		_make_sheets(d)
		return
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts with --world=vung_tau"):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHOTS))
	if not d.expect(data is Dictionary and data.has("shots"), "%s has the shots" % SHOTS):
		return
	var shots: Array = data.shots
	d.expect(shots.size() == 5, "the showcase has five shots (R15): %d" % shots.size())
	var run_values: Array = RUNS[d.phase - 1]
	var camera := d.viewport().get_camera_3d()
	var fov := camera.fov
	var ui: Control = d.main().ui_root
	for i in range(int(run_values[2]), mini(int(run_values[3]), shots.size() - 1) + 1):
		var shot: Dictionary = shots[i]
		var eye := Vector3(float(shot.eye[0]), 0.0, float(shot.eye[1]))
		w.prepare_at(eye, 400.0)
		var floor_y := w.places.floor_at(eye.x, eye.z) if w.places != null else -INF
		eye.y = maxf(w.ground_height(eye.x, eye.z), floor_y) + float(shot.get("eye_height", 1.6))
		var target := Vector3(float(shot.target[0]), float(shot.target[1]), float(shot.target[2]))
		await d.fly_to(eye, target)
		d.expect(await d.wait_ground(120.0), "%s: the ground is ready" % shot.id)
		camera.fov = float(shot.get("fov", fov))
		ui.visible = false
		await d.wait_frames(8)
		await d.screenshot("%s_%s_%s" % [shot.id, run_values[0], run_values[1]])
		ui.visible = true
		d.step("%s (%s): eye (%.1f, %.1f, %.1f), fov %.0f" % [shot.id, shot.name, eye.x, eye.y, eye.z, camera.fov])
		camera.fov = fov
	d.fly_end()


## The last run: one sheet for each shot from the screenshots of the other runs.
static func _make_sheets(d: PlaytestDriver) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHEETS_FROM))
	if not d.expect(data is Dictionary, "%s has the shots" % SHEETS_FROM):
		return
	var files := DirAccess.get_files_at(d.out_dir)
	var times: Array = ["1710", "1200"]
	var presets: Array = ["low", "high"]
	for shot: Dictionary in data.shots:
		var sheet := Image.create(SHEET_CELL.x * presets.size(), SHEET_CELL.y * times.size(), false, Image.FORMAT_RGB8)
		sheet.fill(Color("#202020"))
		var found := 0
		for r in times.size():
			for c in presets.size():
				var suffix := "-%s_%s_%s.png" % [shot.id, presets[c], times[r]]
				for file: String in files:
					if file.ends_with(suffix):
						var image := Image.load_from_file(d.out_dir.path_join(file))
						image.convert(Image.FORMAT_RGB8)
						image.resize(SHEET_CELL.x, SHEET_CELL.y, Image.INTERPOLATE_BILINEAR)
						sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SHEET_CELL), Vector2i(c * SHEET_CELL.x, r * SHEET_CELL.y))
						found += 1
						break
		sheet.save_jpg(d.out_dir.path_join("sheet_%s.jpg" % shot.id), 0.85)
		d.step("sheet_%s.jpg: %d of 4 screenshots" % [shot.id, found])
		d.expect(found == 4, "sheet_%s.jpg has all its screenshots" % shot.id)

