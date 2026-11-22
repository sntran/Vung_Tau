extends RefCounted
# PT-69 town_budget (plan 0009, phase 2, R10). The draw calls, the triangles,
# and the video memory at the views of PT-68 (data/geo/town_views.json) at
# 18:00, on Low and on High (Forward+, as PT-73). R10: Low has at most 300 000
# triangles at each view. The draw calls: at most 600 on Low and 2 000 on
# High, as PT-73 (report 0009, Q10). High measures the views in two runs.
# sizes: 1280x720
# phase: --world=vung_tau --renderer=forward_plus --quality=low --start-time=18:00
# phase: --world=vung_tau --renderer=forward_plus --quality=high --start-time=18:00
# phase: --world=vung_tau --renderer=forward_plus --quality=high --start-time=18:00

const Views := preload("res://playtests/town_views.gd")
const TRIANGLES := {"low": 300000}
## Report 0009, Q10.
const DRAW_CALLS := {"low": 600, "high": 2000}
## For each run: the preset, and the first and the last view (from 0).
const RUNS := [["low", 0, 3], ["high", 0, 1], ["high", 2, 3]]


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.town != null, "the Vũng Tàu world has the boxes of the town"):
		return
	var run_values: Array = RUNS[d.phase - 1]
	var preset: String = run_values[0]
	d.expect(GameState.settings.quality == preset, "the preset is %s" % GameState.settings.quality)
	var views := Views.read_views(w)
	var camera := d.viewport().get_camera_3d()
	var fov := camera.fov
	for i in range(int(run_values[1]), int(run_values[2]) + 1):
		if i >= views.size():
			break
		var view: Dictionary = views[i]
		w.prepare_at(view.eye, VungTau.ground_detail.mid)
		w.town.prepare_at(view.eye, TownField.range_end)
		await d.fly_to(view.eye, view.target)
		camera.fov = float(view.fov)
		await d.wait_ground(120.0)
		await d.wait_frames(8)
		var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var triangles := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var memory := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
		d.step("%s, %s: %d draw calls, %d triangles, %.0f MB of video memory; the town: %d boxes in the frame, %d triangles in all its chunks; the tall boxes (D-0009-14): %d meshes, %d triangles" % [
				preset, view.id, draw_calls, triangles, memory, Views.boxes_in_frame(w, camera), w.town.triangles,
				w.town.tall_meshes, w.town.tall_triangles])
		if TRIANGLES.has(preset):
			d.expect(triangles <= int(TRIANGLES[preset]), "%s, %s: at most %d triangles (R10): %d" % [
					preset, view.id, TRIANGLES[preset], triangles])
		d.expect(draw_calls <= int(DRAW_CALLS[preset]), "%s, %s: at most %d draw calls (Q10): %d" % [
				preset, view.id, DRAW_CALLS[preset], draw_calls])
		await d.screenshot("%s_%s" % [view.id, preset])
	camera.fov = fov
	d.fly_end()
