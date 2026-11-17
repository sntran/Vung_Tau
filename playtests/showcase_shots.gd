extends RefCounted
# PT-72 showcase_shots (plan 0026, R15). The five shots of the showcase of
# Bãi Trước (data/showcase/shots.json): each shot at 17:10 and at 12:00, on Low
# (the Mobile renderer) and on High (Forward+). tools/showcase/sheets.py puts
# the screenshots in docs/showcase/ with the link of the photo of each shot.
# The camera stands at the eye of the shot, with the field of view of the shot:
# a setup step, as fly_to() of PT-33. A shot is a frame of the short video of
# D7, so the screen UI (the phone button, the center dot) is hidden while it is
# taken. A shot fails when its ground is not ready.
# High takes the shots in three runs for each time: one run of five shots on
# Forward+ takes more than 300 s under lavapipe, and in CI a run of three shots
# of the frames of the photos (report 0026, D-0026-02) took more than 300 s. The last run makes the sheet
# of each shot (sheet_ID.jpg): the photo (its copy in docs/reference/photos/,
# R17), then a column for Low and High, a row for each time.
# Report 0026 (D-0026-02): a shot is the view of its photo. PT-72 checks that
# the eye is at the place of the photo, that each subject of the photo is in
# the frame and that no stand-in hides it, and that each stand-in in the frame
# has its storeys from a source (Q6). D-0026-05: in the box "hill" of a shot,
# the patches of the far trees (the variation of the brightness of blocks of
# BLOCK px) are at most HILL_MAX times those of the photo in its box. D-0026-06:
# at 12:00, the water in the box "water" is green grey, not cyan or the pale
# sky: its saturation is at most WATER_MAX_SATURATION and its value at most
# WATER_MAX_VALUE (the water of the photos of 2014 to 2021: #5d91ab to
# #a3b4b7, #6d7f92 in the photo of S1).
# sizes: 1280x720
# phase: --world=vung_tau --start-time=17:10 --quality=low
# phase: --world=vung_tau --start-time=12:00 --quality=low
# phase: --world=vung_tau --start-time=17:10 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=17:10 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=17:10 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=12:00 --quality=high --renderer=forward_plus
# phase: --start-time=12:00

const SHOTS := "res://data/showcase/shots.json"
const SHEETS_FROM := SHOTS
## For each phase: the preset, the time, and the first and the last shot (from 0).
const RUNS := [
	["low", "1710", 0, 4],
	["low", "1200", 0, 4],
	["high", "1710", 0, 1],
	["high", "1710", 2, 3],
	["high", "1710", 4, 4],
	["high", "1200", 0, 1],
	["high", "1200", 2, 3],
	["high", "1200", 4, 4],
]


## A cell of a sheet.
const SHEET_CELL := Vector2i(640, 360)
## The copies of the open photos (plan 0026, R17).
const PHOTOS := "res://docs/reference/photos/"
## A stand-in farther than this from the eye does not count as in the frame.
const VIEW_RANGE := 800.0
## The blocks of the measure of the patches (px of a frame of 1280 px).
const BLOCK := 16
const HILL_MAX := 1.5
const WATER_MAX_SATURATION := 0.35
## The water of the photos is 0.45 to 0.7 bright (the value of its mean color).
const WATER_MAX_VALUE := 0.72


func run(d: PlaytestDriver) -> void:
	if d.phase > RUNS.size():
		_make_sheets(d)
		return
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts with --world=vung_tau"):
		return
	if not await d.wait_showcase():
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
		var eye := eye_of(w, shot)
		await d.fly_to(eye, aim(shot, eye))
		d.expect(await d.wait_ground(120.0), "%s: the ground is ready" % shot.id)
		camera.fov = float(shot.get("fov", fov))
		if run_values[0] == "low" and run_values[1] == "1710":
			_check_view(d, w, camera, shot, eye)
		ui.visible = false
		await d.wait_frames(8)
		_check_look(d, shot, str(run_values[0]), str(run_values[1]))
		await d.screenshot("%s_%s_%s" % [shot.id, run_values[0], run_values[1]])
		ui.visible = true
		d.step("%s (%s): eye (%.1f, %.1f, %.1f), fov %.0f" % [shot.id, shot.name, eye.x, eye.y, eye.z, camera.fov])
		camera.fov = fov
	d.fly_end()


## The eye of a shot: eye_height over the ground, or over the floor of a known place.
static func eye_of(w: VungTau, shot: Dictionary) -> Vector3:
	var eye := Vector3(float(shot.eye[0]), 0.0, float(shot.eye[1]))
	w.prepare_at(eye, 400.0)
	var floor_y := w.places.floor_at(eye.x, eye.z) if w.places != null else -INF
	eye.y = maxf(w.ground_height(eye.x, eye.z), floor_y) + float(shot.get("eye_height", 1.6))
	return eye


## The point that the camera of a shot looks at: "heading" is in degrees from
## the south (+z) to the east (+x), "pitch" in degrees up (from the photo).
static func aim(shot: Dictionary, eye: Vector3) -> Vector3:
	var heading := deg_to_rad(float(shot.heading))
	var pitch := deg_to_rad(float(shot.get("pitch", 0.0)))
	return eye + Vector3(sin(heading) * cos(pitch), sin(pitch), cos(heading) * cos(pitch)) * 100.0


## Report 0026, D-0026-02: the eye is at the place of the photo, each subject of
## the photo is in the frame and no stand-in hides it, and each stand-in in the
## frame has its storeys from a source (Q6: a stand-in of 1 storey, a guess, is
## not correct in a shot).
func _check_view(d: PlaytestDriver, w: VungTau, camera: Camera3D, shot: Dictionary, eye: Vector3) -> void:
	var photos: Array = shot.get("photos", [])
	if not d.expect(not photos.is_empty() and (photos[0] as Dictionary).has("place"), "%s has its photo and the place of the photo" % shot.id):
		return
	var place: Dictionary = photos[0].place
	var gap := Vector2(float(place.at[0]), float(place.at[1])).distance_to(Vector2(eye.x, eye.z))
	d.expect(gap <= float(place.within), "%s: the eye is %.1f m from the place of its photo (at most %.0f m: %s)" % [
			shot.id, gap, float(place.within), place.from])
	var subjects: Array = shot.get("subjects", [])
	d.expect(not subjects.is_empty(), "%s names what its photo shows (subjects)" % shot.id)
	for subject: Dictionary in subjects:
		var p := Vector3(float(subject.at[0]), float(subject.at[1]), float(subject.at[2]))
		d.expect(not camera.is_position_behind(p) and camera.is_position_in_frustum(p), "%s: %s is in the frame" % [shot.id, subject.name])
		var hidden := _hidden_by(w, eye, p)
		d.expect(hidden == "", "%s: no stand-in hides %s%s" % [shot.id, subject.name, (" (" + hidden + ")") if hidden != "" else ""])
	var guessed: Array[String] = []
	for entry: Dictionary in w.showcase.stand_ins:
		if entry.known:
			continue
		var outline: PackedVector2Array = entry.outline
		var points: Array[Vector2] = [Vector2.ZERO]
		for q in outline:
			points[0] += q / outline.size()
			points.append(q)
		for q: Vector2 in points:
			var top := Vector3(q.x, float(entry.top), q.y)
			if eye.distance_to(top) < VIEW_RANGE and not camera.is_position_behind(top) and camera.is_position_in_frustum(top) \
					and _hidden_by(w, eye, top, str(entry.osm)) != "":
				continue
			if eye.distance_to(top) < VIEW_RANGE and not camera.is_position_behind(top) and camera.is_position_in_frustum(top):
				guessed.append("%s %s" % [entry.osm, entry.name])
				break
	d.step("%s: %d stand-ins with a guessed number of storeys in the frame" % [shot.id, guessed.size()])
	d.expect(guessed.is_empty(), "%s: each stand-in in the frame has its storeys from a source (Q6): %s" % [shot.id, ", ".join(guessed)])


## D-0026-05 and D-0026-06: the patches of the far hill and the color of the water.
func _check_look(d: PlaytestDriver, shot: Dictionary, preset: String, time: String) -> void:
	var frame := d.viewport().get_texture().get_image()
	if shot.has("hill"):
		var game := box_stats(frame, shot.hill.shot)
		var photo_image := Image.load_from_file(ProjectSettings.globalize_path(PHOTOS + str(shot.photos[0].file)))
		photo_image.resize(frame.get_width(), int(photo_image.get_height() * float(frame.get_width()) / photo_image.get_width()))
		var photo := box_stats(photo_image, shot.hill.photo)
		d.step("%s, %s: the patches of the hill: %.3f (the photo %.3f)" % [shot.id, preset, game.patches, photo.patches])
		d.expect(float(game.patches) <= float(photo.patches) * HILL_MAX, "%s, %s: the far trees of the hill are not patches: %.3f, at most %.1f times the photo (%.3f)" % [
				shot.id, preset, game.patches, HILL_MAX, photo.patches])
	if shot.has("water") and time == "1200":
		var water := box_stats(frame, shot.water)
		var color: Color = water.mean
		d.step("%s, %s: the water at 12:00 is #%s (saturation %.2f)" % [shot.id, preset, color.to_html(false), color.s])
		d.expect(color.s <= WATER_MAX_SATURATION, "%s, %s: the water at 12:00 is green grey, not cyan: saturation %.2f (at most %.2f)" % [
				shot.id, preset, color.s, WATER_MAX_SATURATION])
		d.expect(color.v <= WATER_MAX_VALUE, "%s, %s: the water at 12:00 is not the pale sky: its value is %.2f (at most %.2f)" % [
				shot.id, preset, color.v, WATER_MAX_VALUE])


## The mean color of a box of an image (x0, y0, x1, y1 as parts of its size), and
## "patches": the standard deviation of the brightness of its blocks of BLOCK px.
static func box_stats(image: Image, box: Array) -> Dictionary:
	var size := image.get_size()
	var x0 := int(float(box[0]) * size.x)
	var y0 := int(float(box[1]) * size.y)
	var x1 := int(float(box[2]) * size.x)
	var y1 := int(float(box[3]) * size.y)
	var total := Color(0, 0, 0)
	var count := 0
	var blocks: Array[float] = []
	for by in range(y0, y1 - BLOCK + 1, BLOCK):
		for bx in range(x0, x1 - BLOCK + 1, BLOCK):
			var light := 0.0
			var n := 0
			for y in range(by, by + BLOCK, 2):
				for x in range(bx, bx + BLOCK, 2):
					var c := image.get_pixel(x, y)
					total += c
					count += 1
					light += c.get_luminance()
					n += 1
			blocks.append(light / maxf(n, 1.0))
	var mean_light := 0.0
	for v in blocks:
		mean_light += v / maxf(blocks.size(), 1.0)
	var spread := 0.0
	for v in blocks:
		spread += (v - mean_light) * (v - mean_light) / maxf(blocks.size(), 1.0)
	var mean := Color(total.r / maxf(count, 1.0), total.g / maxf(count, 1.0), total.b / maxf(count, 1.0))
	return {"mean": mean, "patches": sqrt(spread)}


## The stand-in or the model of World that the line from the eye to the point
## goes through under its top, or "" ("skip" is the stand-in of the point). The
## models of World have no collision, so the test uses their footprints and
## the tops of their boxes.
static func _hidden_by(w: VungTau, eye: Vector3, p: Vector3, skip := "") -> String:
	var line := PackedVector2Array([Vector2(eye.x, eye.z), Vector2(p.x, p.z)])
	var flat := line[0].distance_to(line[1])
	var blockers: Array = []
	for entry: Dictionary in w.showcase.stand_ins:
		if str(entry.osm) != skip:
			blockers.append(["%s %s" % [entry.osm, entry.name], entry.outline, float(entry.top)])
	for entry: Dictionary in w.showcase.models:
		var box: AABB = entry.box
		blockers.append([str(entry.id), entry.footprint, float(entry.base) + box.end.y])
	for blocker: Array in blockers:
		# A building that the point is in or on does not hide it.
		if Geometry2D.is_point_in_polygon(line[1], blocker[1]):
			continue
		for piece: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(line, blocker[1]):
			for q in piece:
				var t := line[0].distance_to(q) / maxf(flat, 0.01)
				if t < 0.98 and lerpf(eye.y, p.y, t) < float(blocker[2]):
					return str(blocker[0])
	return ""


## The last run: one sheet for each shot from the screenshots of the other runs.
static func _make_sheets(d: PlaytestDriver) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHEETS_FROM))
	if not d.expect(data is Dictionary, "%s has the shots" % SHEETS_FROM):
		return
	var files := DirAccess.get_files_at(d.out_dir)
	var times: Array = ["1710", "1200"]
	var presets: Array = ["low", "high"]
	for shot: Dictionary in data.shots:
		var sheet := Image.create(SHEET_CELL.x * (presets.size() + 1), SHEET_CELL.y * times.size(), false, Image.FORMAT_RGB8)
		sheet.fill(Color("#202020"))
		# The photo of the shot, at the top left (R17: the open photos are copied).
		for photo: Dictionary in shot.get("photos", []):
			var path := ProjectSettings.globalize_path(PHOTOS + str(photo.get("file", "")))
			if photo.get("open", false) and FileAccess.file_exists(path):
				var image := Image.load_from_file(path)
				image.convert(Image.FORMAT_RGB8)
				var size := Vector2(image.get_size())
				var fit := minf(SHEET_CELL.x / size.x, SHEET_CELL.y / size.y)
				image.resize(int(size.x * fit), int(size.y * fit), Image.INTERPOLATE_BILINEAR)
				sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), (SHEET_CELL - image.get_size()) / 2)
			d.step("sheet_%s.jpg: the photo %s %s" % [shot.id, photo.get("file", ""), "is there" if FileAccess.file_exists(path) else "is not in docs/reference/photos/ (run tools/photos/photos.py)"])
			break
		var found := 0
		for r in times.size():
			for c in presets.size():
				var suffix := "-%s_%s_%s.png" % [shot.id, presets[c], times[r]]
				for file: String in files:
					if file.ends_with(suffix):
						var image := Image.load_from_file(d.out_dir.path_join(file))
						image.convert(Image.FORMAT_RGB8)
						image.resize(SHEET_CELL.x, SHEET_CELL.y, Image.INTERPOLATE_BILINEAR)
						sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SHEET_CELL), Vector2i((c + 1) * SHEET_CELL.x, r * SHEET_CELL.y))
						found += 1
						break
		sheet.save_jpg(d.out_dir.path_join("sheet_%s.jpg" % shot.id), 0.85)
		d.step("sheet_%s.jpg: %d of 4 screenshots" % [shot.id, found])
		d.expect(found == 4, "sheet_%s.jpg has all its screenshots" % shot.id)

