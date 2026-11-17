extends RefCounted
# PT-73 showcase_budget (plan 0026, R16). The draw calls and the triangles at
# each of the five shots of data/showcase/shots.json, at 17:10 (all the people
# of R10 are there): Low at most 600 draw calls and 300 000 triangles, High at
# most 2 000 draw calls and 2 000 000 triangles. As PT-54, the presets run on
# Forward+ (the renderer of a computer); the Mobile renderer of a phone draws
# the same objects. The values go to the log. High measures the shots in two
# runs: a run of five views on Forward+ takes long under lavapipe.
# sizes: 1280x720
# phase: --world=vung_tau --renderer=forward_plus --quality=low --start-time=17:10
# phase: --world=vung_tau --renderer=forward_plus --quality=high --start-time=17:10
# phase: --world=vung_tau --renderer=forward_plus --quality=high --start-time=17:10

const SHOTS := "res://data/showcase/shots.json"
## The eye and the aim of a shot, as PT-72 takes it.
const Shots := preload("res://playtests/showcase_shots.gd")
const LIMITS := {"low": [600, 300000], "high": [2000, 2000000]}
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
		d.step("%s, %s: %d draw calls, %d triangles (%d people)" % [preset, shot.id, draw_calls, triangles, people])
		d.expect(draw_calls <= int(limit[0]), "%s, %s: at most %d draw calls: %d" % [preset, shot.id, limit[0], draw_calls])
		d.expect(triangles <= int(limit[1]), "%s, %s: at most %d triangles: %d" % [preset, shot.id, limit[1], triangles])
		await d.screenshot("%s_%s" % [shot.id, preset])
		camera.fov = fov
	d.fly_end()
