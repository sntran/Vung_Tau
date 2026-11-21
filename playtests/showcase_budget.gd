extends RefCounted
# PT-73 showcase_budget (plan 0026, R16). The draw calls and the triangles at
# each of the five shots of data/showcase/shots.json, at 17:10 (all the people
# of R10 are there): Low at most 600 draw calls and 300 000 triangles, High at
# most 2 000 draw calls and 2 000 000 triangles. As PT-54, the presets run on
# Forward+ (the renderer of a computer); the Mobile renderer of a phone draws
# the same objects. The values go to the log. High measures the shots in two
# runs: a run of five views on Forward+ takes long under lavapipe. Report 0026,
# D-0026-28: at a shot with walker spots (S1, S2, S5), the test measures again
# with each walker of its spots at the point of its way nearest to the eye.
# sizes: 1280x720
# phase: --world=vung_tau --renderer=forward_plus --quality=low --start-time=17:10
# phase: --world=vung_tau --renderer=forward_plus --quality=high --start-time=17:10
# phase: --world=vung_tau --renderer=forward_plus --quality=high --start-time=17:10

const SHOTS := "res://data/showcase/shots.json"
## The eye and the aim of a shot, as PT-72 takes it.
const Shots := preload("res://playtests/showcase_shots.gd")
const LIMITS := {"low": [600, 300000], "high": [2000, 2000000]}
## Report 0026, D-0026-42: on Low each shot keeps a margin of 40 draw calls
## under the limit of R16 for the letters of the hotels and the dressing of
## Tết, so a shot has at most 560 draw calls.
const MARGINS := {"low": 40}
## Report 0026, Q24 (R16): the video memory of each shot on Low, at most (MB).
const MEMORY_LIMITS := {"low": 1024.0}
## Report 0026, D-0026-38: the worst case puts each walker of a spot this far in front of the eye (m).
const HELD_NEAR_M := ShowcasePeople.HELD_NEAR_M
const HELD_FAR_M := ShowcasePeople.HELD_FAR_M
## For each run: the preset, and the first and the last shot (from 0).
const RUNS := [["low", 0, 4], ["high", 0, 2], ["high", 3, 4]]


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.showcase != null, "the Vũng Tàu world has the showcase"):
		return
	if not await d.wait_showcase():
		return
	var run_values: Array = RUNS[d.phase - 1]
	var preset: String = run_values[0]
	d.expect(GameState.settings.quality == preset, "the preset is %s" % GameState.settings.quality)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHOTS))
	if not d.expect(data is Dictionary, "%s can be read" % SHOTS):
		return
	var shots: Array = data.shots
	var camera := d.viewport().get_camera_3d()
	var fov := camera.fov
	var limit: Array = LIMITS[preset]
	for i in range(int(run_values[1]), int(run_values[2]) + 1):
		var shot: Dictionary = shots[i]
		var eye := Shots.eye_of(w, shot)
		await d.fly_to(eye, Shots.aim(shot, eye))
		await d.wait_ground(120.0)
		camera.fov = float(shot.get("fov", fov))
		await d.wait_frames(8)
		var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var triangles := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var people := w.showcase.people.shown_count() if w.showcase.people else 0
		d.step("%s, %s: %d draw calls, %d triangles (%d people); the margin: %d draw calls under %d" % [
				preset, shot.id, draw_calls, triangles, people, int(limit[0]) - draw_calls, limit[0]])
		d.expect(draw_calls <= int(limit[0]), "%s, %s: at most %d draw calls: %d" % [preset, shot.id, limit[0], draw_calls])
		if MARGINS.has(preset):
			d.expect(int(limit[0]) - draw_calls >= int(MARGINS[preset]), "%s, %s: a margin of at least %d draw calls (at most %d): %d" % [
					preset, shot.id, MARGINS[preset], int(limit[0]) - int(MARGINS[preset]), draw_calls])
		d.expect(triangles <= int(limit[1]), "%s, %s: at most %d triangles: %d" % [preset, shot.id, limit[1], triangles])
		_check_memory(d, preset, "%s" % shot.id)
		await d.screenshot("%s_%s" % [shot.id, preset])
		# D-0026-28: the worst case of the walkers of the spots of the shot: each
		# at the point of its way nearest to the eye.
		var held := w.showcase.people.hold_spot_walkers(str(shot.id), camera) if w.showcase.people else 0
		d.step("%s, %s: %d walkers of its spots held in the frame, %d of them at %.0f m to %.0f m in front of the eye (the others at the nearest point of their way in the frame)" % [
				preset, shot.id, held, held - w.showcase.people.held_far if w.showcase.people else 0, HELD_NEAR_M, HELD_FAR_M])
		if held > 0:
			# Report 0026, D-0026-38: each held walker is in the frame, 3 m to 10 m in front of the eye.
			var out := PackedStringArray()
			for q: Vector3 in w.showcase.people.held_points:
				var ahead := (q - camera.global_position).dot(-camera.global_transform.basis.z)
				var middle := q + Vector3(0, 0.9, 0)
				var far_ok := w.showcase.people.held_far > 0
				if ahead < HELD_NEAR_M - 0.1 or (ahead > HELD_FAR_M + 0.1 and not far_ok) or not camera.is_position_in_frustum(middle):
					out.append("(%.1f, %.1f): %.1f m in front, %s" % [q.x, q.z, ahead, "in the frame" if camera.is_position_in_frustum(middle) else "out of the frame"])
			d.expect(out.is_empty(), "%s, %s: the %d held walkers are in the frame, %.0f m to %.0f m in front of the eye%s" % [
					preset, shot.id, held, HELD_NEAR_M, HELD_FAR_M, "" if out.is_empty() else ": " + "; ".join(out)])
			await d.wait_frames(8)
			draw_calls = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			triangles = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			d.step("%s, %s, the %d walkers of its spots at their points nearest to the eye: %d draw calls, %d triangles; the margin: %d draw calls under %d" % [
					preset, shot.id, held, draw_calls, triangles, int(limit[0]) - draw_calls, limit[0]])
			d.expect(draw_calls <= int(limit[0]), "%s, %s, the walkers near: at most %d draw calls: %d" % [preset, shot.id, limit[0], draw_calls])
			if MARGINS.has(preset):
				d.expect(int(limit[0]) - draw_calls >= int(MARGINS[preset]), "%s, %s, the walkers near: a margin of at least %d draw calls (at most %d): %d" % [
						preset, shot.id, MARGINS[preset], int(limit[0]) - int(MARGINS[preset]), draw_calls])
			d.expect(triangles <= int(limit[1]), "%s, %s, the walkers near: at most %d triangles: %d" % [preset, shot.id, limit[1], triangles])
			_check_memory(d, preset, "%s, the walkers near" % shot.id)
			await d.screenshot("%s_%s_walkers_near" % [shot.id, preset])
			w.showcase.people.release_walkers()
		camera.fov = fov
	d.fly_end()


## Report 0026, Q24: Low (the phones, the web build, and a computer with no
## graphics card share the memory with the processor) uses at most 1 024 MB of
## video memory at each shot, also in the worst case.
static func _check_memory(d: PlaytestDriver, preset: String, what: String) -> void:
	var used := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
	var textures := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0
	d.step("%s, %s: %.0f MB of video memory (%.0f MB textures)" % [preset, what, used, textures])
	if MEMORY_LIMITS.has(preset):
		d.expect(used <= float(MEMORY_LIMITS[preset]), "%s, %s: at most %.0f MB of video memory: %.0f MB" % [
				preset, what, MEMORY_LIMITS[preset], used])
