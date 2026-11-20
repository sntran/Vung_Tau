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
# has its storeys from a source (Q6). D-0026-14: no stand-in is a main subject
# of a shot: a stand-in covers at most MAX_STAND_IN of the frame (the part of
# the frame of the box of its corners, times the part of the points of its
# faces to the eye that a ray from the eye reaches). D-0026-05: in the box "hill" of a shot,
# the patches of the far trees (the variation of the brightness of blocks of
# BLOCK px) are at most HILL_MAX times those of the photo in its box;
# D-0026-15: also the colors: at 12:00 and at 17:10 the mean hue, saturation,
# and value of the box are near those of the photo (HILL_MAX_HUE,
# HILL_MAX_SATURATION, HILL_MAX_VALUE), and the spread of the chroma of the
# blocks (pink and teal roofs on the hill) is at most HILL_MAX times that of the
# photo. D-0026-06:
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

## D-0026-23 (audit 5): the size of the patches of the box "hill": the
## autocorrelation length of its brightness (the mean of the lags along x and
## along y at which the autocorrelation falls to one half) is at most
## HILL_MAX_LENGTH times that of the photo. A check of the edges let a fine
## noise of two pixels pass with no change of the shapes: the photo of S1 had
## 4 px, the game 17 px at 12:00 and 11 px at 17:10 (patches 3 to 4 times the
## size of the crowns of the photo).
const HILL_MAX_LENGTH := 1.5
## D-0026-40: the box "roof" of a shot (the roof of the hall in S1) has the hue
## and the saturation of the photo, within these.
const ROOF_MAX_HUE := 12.0
const ROOF_MAX_SATURATION := 0.12
## D-0026-24: the radius of the crown of a palm or a pine, and the step of the search for trees along the line.
const CROWN_RADIUS := {"coconut": 3.0, "casuarina": 2.5, "araucaria": 2.5, "frangipani": 2.0, "fan_palm": 1.5}
const TREE_LOOK_M := 8.0
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
## D-0026-15: the mean color of the box "hill" and of the photo in its box.
const HILL_MAX_HUE := 25.0
const HILL_MAX_SATURATION := 0.15
const HILL_MAX_VALUE := 0.12
const WATER_MAX_SATURATION := 0.35
## The water of the photos is 0.45 to 0.7 bright (the value of its mean color).
const WATER_MAX_VALUE := 0.72
## A stand-in covers at most this part of a frame (D-0026-14: the grey boxes of
## Khách sạn Bưu điện and Cao ốc Sen Biển in S1).
const MAX_STAND_IN := 0.02
## A fence nearer than this to the eye of a shot shows its near or mid level (m).
const FENCE_NEAR_M := 30.0


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
		d.expect_not_flat("%s at %s on %s" % [shot.id, run_values[1], run_values[0]])
		ui.visible = true
		d.step("%s (%s): eye (%.1f, %.1f, %.1f), fov %.0f; %s" % [shot.id, shot.name, eye.x, eye.y, eye.z, camera.fov, memory_text()])
		camera.fov = fov
	d.fly_end()


## The eye of a shot: eye_height over the ground, or over the floor of a known place.
static func eye_of(w: VungTau, shot: Dictionary) -> Vector3:
	var eye := Vector3(float(shot.eye[0]), 0.0, float(shot.eye[1]))
	w.prepare_at(eye, maxf(400.0, float(VungTau.ground_detail.mid)))
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
		# Report 0026, D-0026-24: a subject that the trees must not hide (the hall
		# with the orange roof of S1, behind the trees of Hạ Long).
		if bool(subject.get("trees", false)):
			var tree := _hidden_by_tree(w, eye, p)
			d.expect(tree == "", "%s: no tree hides %s%s" % [shot.id, subject.name, (" (" + tree + ")") if tree != "" else ""])
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
	var main: Array[String] = []
	var largest := 0.0
	for entry: Dictionary in w.showcase.stand_ins:
		var part := _frame_part(d, w, camera, eye, entry)
		largest = maxf(largest, part)
		if part > MAX_STAND_IN:
			main.append("%s %s (%.1f %% of the frame)" % [entry.osm, entry.name, part * 100.0])
	d.step("%s: the largest stand-in covers %.1f %% of the frame" % [shot.id, largest * 100.0])
	d.expect(main.is_empty(), "%s: no stand-in is a main subject of the shot (at most %.0f %% of the frame): %s" % [
			shot.id, MAX_STAND_IN * 100.0, ", ".join(main)])
	# Audit 3 of the corrections: the fence of the Grand Hotel in S4 on Low was its
	# far level (a row of grey teeth) at 20 m, in the row of the walls.
	if w.showcase.fence_row != null:
		var r: Vector3 = w.showcase.fence_row.custom_ranges.get(WorldModel.preset, WorldModel.ranges)
		var far_near := 0
		for cell: Dictionary in w.showcase.fence_row.cells:
			var to_cell := (cell.node as Node3D).global_position.distance_to(eye)
			if to_cell < FENCE_NEAR_M and to_cell >= r.y:
				far_near += 1
		d.expect(far_near == 0, "%s: no cell of a fence nearer than %.0f m shows its far level: %d (the mid level to %.0f m)" % [
				shot.id, FENCE_NEAR_M, far_near, r.y])


## The part of the frame that a stand-in covers (D-0026-14): the box of the
## corners of its prism on the screen (in the frame), times the part of the
## points of its faces to the eye that a ray from the eye reaches.
static func _frame_part(d: PlaytestDriver, w: VungTau, camera: Camera3D, eye: Vector3, entry: Dictionary) -> float:
	var outline: PackedVector2Array = entry.outline
	var top := float(entry.top)
	if outline.size() < 3 or eye.distance_to(Vector3(outline[0].x, top, outline[0].y)) > VIEW_RANGE:
		return 0.0
	var base := INF
	for q in outline:
		base = minf(base, w.ground_height(q.x, q.y))
	var size := Vector2(d.viewport().get_visible_rect().size)
	var rect := Rect2()
	var first := true
	for q in outline:
		for y: float in [base, top]:
			var p := Vector3(q.x, y, q.y)
			if camera.is_position_behind(p):
				continue
			var at := camera.unproject_position(p)
			rect = Rect2(at, Vector2.ZERO) if first else rect.expand(at)
			first = false
	if first:
		return 0.0
	rect = rect.intersection(Rect2(Vector2.ZERO, size))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return 0.0
	# The points of the faces to the eye: a ray from the eye reaches each one.
	var area := 0.0
	for i in outline.size():
		area += outline[i].cross(outline[(i + 1) % outline.size()])
	var space := camera.get_world_3d().direct_space_state
	var seen := 0
	var total := 0
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var edge := b - a
		# (edge.y, -edge.x) is out of a polygon whose area (the sum of the cross products) is positive.
		var out := Vector2(edge.y, -edge.x).normalized() * (1.0 if area > 0.0 else -1.0)
		var middle := (a + b) / 2.0
		if out.dot(Vector2(eye.x, eye.z) - middle) <= 0.0:
			continue
		for t: float in [0.2, 0.5, 0.8]:
			var q := a.lerp(b, t) + out * 0.05
			for h: float in [0.25, 0.6, 0.9]:
				var p := Vector3(q.x, lerpf(base, top, h), q.y)
				if camera.is_position_behind(p) or not camera.is_position_in_frustum(p):
					continue
				total += 1
				var query := PhysicsRayQueryParameters3D.create(eye, p, Layers.FLOOR)
				var hit := space.intersect_ray(query)
				if hit.is_empty() or (hit.position as Vector3).distance_to(p) < 0.6:
					seen += 1
	if total == 0:
		return 0.0
	var part := rect.get_area() / (size.x * size.y) * float(seen) / total
	if part > 0.001:
		d.step("  the stand-in %s %s: the box of its corners %.1f %% of the frame, %d of %d points seen" % [
				entry.osm, entry.name, rect.get_area() / (size.x * size.y) * 100.0, seen, total])
	return part


## D-0026-05 and D-0026-06: the patches of the far hill and the color of the water.
func _check_look(d: PlaytestDriver, shot: Dictionary, preset: String, time: String) -> void:
	var frame := d.viewport().get_texture().get_image()
	# D-0026-29: the top of the raised lawn of S5 is grass, with no grey slab.
	if shot.has("lawn"):
		var green := green_part(frame, shot.lawn.box)
		d.step("%s, %s, %s: %.0f %% of the box of the lawn is green" % [shot.id, preset, time, green * 100.0])
		d.expect(green >= float(shot.lawn.min_green), "%s, %s, %s: the top of the raised lawn is grass: %.0f %% of its box is green (at least %.0f %%)" % [
				shot.id, preset, time, green * 100.0, float(shot.lawn.min_green) * 100.0])
	if shot.has("hill"):
		var game := box_stats(frame, shot.hill.shot)
		var photo_image := Image.load_from_file(photo_path(str(shot.photos[0].file)))
		photo_image.resize(frame.get_width(), int(photo_image.get_height() * float(frame.get_width()) / photo_image.get_width()))
		var photo := box_stats(photo_image, shot.hill.photo)
		d.step("%s, %s: the patches of the hill: %.3f (the photo %.3f)" % [shot.id, preset, game.patches, photo.patches])
		d.expect(float(game.patches) <= float(photo.patches) * HILL_MAX, "%s, %s: the far trees of the hill are not patches: %.3f, at most %.1f times the photo (%.3f)" % [
				shot.id, preset, game.patches, HILL_MAX, photo.patches])
		# D-0026-23: the size of the crowns and of the shade between them, against the photo.
		var game_length := correlation_length(frame, shot.hill.shot)
		var photo_length := correlation_length(photo_image, shot.hill.photo)
		d.step("%s, %s, %s: the autocorrelation length of the hill: %.1f px (the photo %.1f px)" % [
				shot.id, preset, time, game_length, photo_length])
		d.expect(game_length <= photo_length * HILL_MAX_LENGTH,
				"%s, %s, %s: the far forest has crowns of the size of the photo: the autocorrelation length is %.1f px, at most %.1f times the photo (%.1f px)" % [
					shot.id, preset, time, game_length, HILL_MAX_LENGTH, photo_length])
		# D-0026-15: the colors, not only the brightness.
		var g: Color = game.mean
		var f: Color = photo.mean
		var hue := absf(g.h - f.h) * 360.0
		hue = minf(hue, 360.0 - hue)
		d.step("%s, %s, %s: the hill is #%s (hue %.0f, saturation %.2f, value %.2f); the photo #%s (hue %.0f, saturation %.2f, value %.2f); the color patches %.3f (the photo %.3f)" % [
				shot.id, preset, time, g.to_html(false), g.h * 360.0, g.s, g.v, f.to_html(false), f.h * 360.0, f.s, f.v,
				game.color_patches, photo.color_patches])
		d.expect(hue <= HILL_MAX_HUE and absf(g.s - f.s) <= HILL_MAX_SATURATION and absf(g.v - f.v) <= HILL_MAX_VALUE,
				"%s, %s, %s: the hill has the color of the photo: the hue %.0f degrees from it (at most %.0f), the saturation %.2f from it (at most %.2f), the value %.2f from it (at most %.2f)" % [
					shot.id, preset, time, hue, HILL_MAX_HUE, absf(g.s - f.s), HILL_MAX_SATURATION, absf(g.v - f.v), HILL_MAX_VALUE])
		d.expect(float(game.color_patches) <= float(photo.color_patches) * HILL_MAX,
				"%s, %s, %s: the hill has no patches of color (pink, teal roofs): %.3f, at most %.1f times the photo (%.3f)" % [
					shot.id, preset, time, game.color_patches, HILL_MAX, photo.color_patches])
	if shot.has("roof"):
		var game_roof: Color = box_stats(frame, shot.roof.shot).mean
		var photo_roof_image := Image.load_from_file(photo_path(str(shot.photos[0].file)))
		photo_roof_image.resize(frame.get_width(), int(photo_roof_image.get_height() * float(frame.get_width()) / photo_roof_image.get_width()))
		var photo_roof: Color = box_stats(photo_roof_image, shot.roof.photo).mean
		var roof_hue := absf(game_roof.h - photo_roof.h) * 360.0
		roof_hue = minf(roof_hue, 360.0 - roof_hue)
		d.step("%s, %s, %s: the roof of the hall is #%s (hue %.0f, saturation %.2f, value %.2f); the photo #%s (hue %.0f, saturation %.2f, value %.2f)" % [
				shot.id, preset, time, game_roof.to_html(false), game_roof.h * 360.0, game_roof.s, game_roof.v,
				photo_roof.to_html(false), photo_roof.h * 360.0, photo_roof.s, photo_roof.v])
		d.expect(roof_hue <= ROOF_MAX_HUE and absf(game_roof.s - photo_roof.s) <= ROOF_MAX_SATURATION,
				"%s, %s, %s: the roof of the hall has the color of the tiles of the photo: the hue %.0f degrees from it (at most %.0f), the saturation %.2f from it (at most %.2f)" % [
					shot.id, preset, time, roof_hue, ROOF_MAX_HUE, absf(game_roof.s - photo_roof.s), ROOF_MAX_SATURATION])
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
## D-0026-23 (audit 5): the autocorrelation length of the brightness of a box
## (x0, y0, x1, y1 as parts of the image), in pixels: for the lags along x and
## along y, the first lag at which the autocorrelation falls under one half;
## the mean of the two.
static func correlation_length(image: Image, box: Array) -> float:
	var size := image.get_size()
	var x0 := int(float(box[0]) * size.x)
	var y0 := int(float(box[1]) * size.y)
	var w := int(float(box[2]) * size.x) - x0
	var h := int(float(box[3]) * size.y) - y0
	var luma := PackedFloat32Array()
	luma.resize(w * h)
	var mean := 0.0
	for j in h:
		for i in w:
			var c := image.get_pixel(x0 + i, y0 + j)
			var v := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			luma[j * w + i] = v
			mean += v
	mean /= maxf(float(w * h), 1.0)
	var variance := 0.0
	for k in luma.size():
		luma[k] -= mean
		variance += luma[k] * luma[k]
	variance /= maxf(float(luma.size()), 1.0)
	if variance <= 0.0:
		return float(maxi(w, h))
	var lengths := []
	for axis in 2:
		var n := w if axis == 0 else h
		var found := float(n / 2)
		for lag in range(1, n / 2):
			var total := 0.0
			var count := 0
			for j in (h if axis == 0 else h - lag):
				for i in (w - lag if axis == 0 else w):
					var a := luma[j * w + i]
					var b := luma[j * w + i + lag] if axis == 0 else luma[(j + lag) * w + i]
					total += a * b
					count += 1
			if total / maxf(float(count), 1.0) / variance < 0.5:
				found = float(lag)
				break
		lengths.append(found)
	return (lengths[0] + lengths[1]) / 2.0


## The file of a photo of docs/reference/photos/. Godot does not export docs/
## (docs/.gdignore), so a run of an exported game (R21: the macOS build on a
## computer with a graphics card) gives the folder of a checkout: --photos=DIR.
static func photo_path(file: String) -> String:
	var folder := GameState.arg_value("photos")
	return (folder if folder != "" else ProjectSettings.globalize_path(PHOTOS)).path_join(file)


## R21: the memory of the game at a shot: the memory of the engine, the video
## memory, and the memory of the textures and the buffers (MB).
static func memory_text() -> String:
	return "the memory: %.0f MB static, %.0f MB video (%.0f MB textures, %.0f MB buffers)" % [
			OS.get_static_memory_usage() / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0]


## The part of the pixels of a box (parts of the frame) whose green is more than
## their red and their blue (grass in the light of the day).
static func green_part(image: Image, box: Array) -> float:
	var size := image.get_size()
	var green := 0
	var count := 0
	for y in range(int(float(box[1]) * size.y), int(float(box[3]) * size.y), 2):
		for x in range(int(float(box[0]) * size.x), int(float(box[2]) * size.x), 2):
			var c := image.get_pixel(x, y)
			count += 1
			if c.g > c.r * 1.05 and c.g > c.b * 1.05:
				green += 1
	return float(green) / maxf(count, 1.0)


static func box_stats(image: Image, box: Array) -> Dictionary:
	var size := image.get_size()
	var x0 := int(float(box[0]) * size.x)
	var y0 := int(float(box[1]) * size.y)
	var x1 := int(float(box[2]) * size.x)
	var y1 := int(float(box[3]) * size.y)
	var total := Color(0, 0, 0)
	var count := 0
	var blocks: Array[float] = []
	var block_colors: Array[Color] = []
	for by in range(y0, y1 - BLOCK + 1, BLOCK):
		for bx in range(x0, x1 - BLOCK + 1, BLOCK):
			var light := 0.0
			var n := 0
			var block_total := Color(0, 0, 0)
			for y in range(by, by + BLOCK, 2):
				for x in range(bx, bx + BLOCK, 2):
					var c := image.get_pixel(x, y)
					total += c
					block_total += c
					count += 1
					light += c.get_luminance()
					n += 1
			blocks.append(light / maxf(n, 1.0))
			block_colors.append(Color(block_total.r / maxf(n, 1.0), block_total.g / maxf(n, 1.0), block_total.b / maxf(n, 1.0)))
	var mean_light := 0.0
	for v in blocks:
		mean_light += v / maxf(blocks.size(), 1.0)
	var spread := 0.0
	for v in blocks:
		spread += (v - mean_light) * (v - mean_light) / maxf(blocks.size(), 1.0)
	var mean := Color(total.r / maxf(count, 1.0), total.g / maxf(count, 1.0), total.b / maxf(count, 1.0))
	# The spread of the color (the chroma) of the blocks: the distance of the
	# chroma of each block (red - green, yellow - blue) from the mean chroma.
	var mean_a := 0.0
	var mean_b := 0.0
	for c: Color in block_colors:
		mean_a += (c.r - c.g) / maxf(block_colors.size(), 1.0)
		mean_b += ((c.r + c.g) / 2.0 - c.b) / maxf(block_colors.size(), 1.0)
	var chroma_spread := 0.0
	for c: Color in block_colors:
		var da := c.r - c.g - mean_a
		var db := (c.r + c.g) / 2.0 - c.b - mean_b
		chroma_spread += (da * da + db * db) / maxf(block_colors.size(), 1.0)
	return {"mean": mean, "patches": sqrt(spread), "color_patches": sqrt(chroma_spread)}


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


## The tree whose crown is on the line from the eye to the point (D-0026-24), or "".
## The crown of a tree is a ball at 0.8 of the mean height of its type, of half
## its crown width (or CROWN_RADIUS for a palm or a pine), from data/trees/types.json.
static func _hidden_by_tree(w: VungTau, eye: Vector3, p: Vector3) -> String:
	if w.trees == null:
		return ""
	var types: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/trees/types.json")) as Dictionary).get("types", {})
	var length := eye.distance_to(p)
	var seen := {}
	var s := 0.0
	while s < length - 3.0:
		var at := eye.lerp(p, s / length)
		for entry: Array in w.trees.all_trees_near(at, TREE_LOOK_M):
			var base: Vector3 = entry[0]
			var key := "%.1f,%.1f" % [base.x, base.z]
			if seen.has(key):
				continue
			seen[key] = true
			var info: Dictionary = types.get(str(entry[1]), {})
			var heights: Array = info.get("height", [10.0, 10.0])
			var h := (float(heights[0]) + float(heights[1])) / 2.0
			var radius := float(info.get("crown_width", CROWN_RADIUS.get(str(entry[1]), 6.0) * 2.0)) / 2.0 * 0.8
			var crown := base + Vector3(0.0, h * 0.8, 0.0)
			var q := Geometry3D.get_closest_point_to_segment(crown, eye, p)
			if q.distance_to(crown) < radius and q.distance_to(p) > 2.0:
				return "%s at (%.1f, %.1f), %.0f m from the eye" % [entry[1], base.x, base.z, eye.distance_to(q)]
		s += TREE_LOOK_M
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
			var path := photo_path(str(photo.get("file", "")))
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

