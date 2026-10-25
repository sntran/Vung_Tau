extends RefCounted
# PT-32 budget (plan 0004, R14). Measure the draw calls and the triangles at
# three fixed views on each preset. Low: 600 draw calls or fewer and 300 000
# triangles or fewer. High: 2 000 draw calls or fewer and 2 000 000 triangles
# or fewer. The values go to the log and to budget_PRESET.json. AGENTS.md has
# the measured values.
# sizes: 1280x720
# phase: --renderer=forward_plus --quality=low --start-time=12:00 --fresh-save
# phase: --renderer=forward_plus --quality=medium --start-time=12:00 --fresh-save
# phase: --renderer=forward_plus --quality=high --start-time=12:00 --fresh-save
# phase: --renderer=forward_plus --quality=ultra --start-time=12:00 --fresh-save

const PRESETS := ["low", "medium", "high", "ultra"]
const LIMITS := {"low": [600, 300000], "high": [2000, 2000000]}


func run(d: PlaytestDriver) -> void:
	var preset: String = PRESETS[d.phase - 1]
	d.expect(GameState.settings.quality == preset, "the preset is %s" % GameState.settings.quality)
	var results := []
	var views := d.hem_views()
	for view: Dictionary in [views[0], views[1], views[3]]:
		await d.fly_to(view.eye, view.target)
		await d.wait_frames(6)
		var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var triangles := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var objects := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		results.append({"view": view.name, "draw_calls": draw_calls, "triangles": triangles, "objects": objects})
		d.step("%s, view %s: %d draw calls, %d triangles, %d objects" % [preset, view.name, draw_calls, triangles, objects])
		if LIMITS.has(preset):
			var limit: Array = LIMITS[preset]
			d.expect(draw_calls <= limit[0], "%s, view %s: %d draw calls, not more than %d" % [preset, view.name, draw_calls, limit[0]])
			d.expect(triangles <= limit[1], "%s, view %s: %d triangles, not more than %d" % [preset, view.name, triangles, limit[1]])
		await d.screenshot("%s_%s" % [view.name, preset])
	d.fly_end()
	var file := FileAccess.open(d.out_dir.path_join("budget_%s.json" % preset), FileAccess.WRITE)
	file.store_string(JSON.stringify({"preset": preset, "renderer": RenderingServer.get_current_rendering_method(),
			"views": results}, "\t"))
	file.close()
