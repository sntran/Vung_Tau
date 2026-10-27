extends RefCounted
# PT-54 tree_budget (plan 0020, R12). Measure the draw calls, the triangles,
# and the frame time (under lavapipe, only for comparison) at three views of
# the Vũng Tàu world on each preset: the top of Núi Nhỏ, the Bãi Trước road
# (Quang Trung), and the Bãi Sau road (Thùy Vân). The test measures each view
# again without the trees. R12 sets the limits of the whole view (Low: 600
# draw calls and 300 000 triangles; High: 2 000 and 2 000 000). The ground of
# plan 0005 alone is more than the limit of Low (plan 0020, Q7), so the test
# checks the part of the trees: not more than half of each limit. It records
# the whole view against R12 in the log and in tree_budget_PRESET.json.
# sizes: 1280x720
# phase: --world=vung_tau --renderer=forward_plus --quality=low --start-time=12:00
# phase: --world=vung_tau --renderer=forward_plus --quality=medium --start-time=12:00
# phase: --world=vung_tau --renderer=forward_plus --quality=high --start-time=12:00
# phase: --world=vung_tau --renderer=forward_plus --quality=ultra --start-time=12:00

const PRESETS := ["low", "medium", "high", "ultra"]
const LIMITS := {"low": [600, 300000], "high": [2000, 2000000]}
## The part of each limit that the trees can use.
const TREE_PART := 0.5


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts with --world=vung_tau"):
		return
	var preset: String = PRESETS[d.phase - 1]
	d.expect(GameState.settings.quality == preset, "the preset is %s" % GameState.settings.quality)
	var results := []
	for view: Dictionary in views(w):
		await d.fly_to(view.eye, view.target)
		await d.wait_ground(90.0)
		await d.wait_frames(6)
		var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var triangles := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var objects := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		var start := Time.get_ticks_usec()
		await d.wait_frames(5)
		var frame_ms := (Time.get_ticks_usec() - start) / 5000.0
		results.append({"view": view.name, "draw_calls": draw_calls, "triangles": triangles, "objects": objects,
				"frame_ms": frame_ms, "trees": w.trees.shown.duplicate()})
		d.step("%s, view %s: %d draw calls, %d triangles, %d objects, %.0f ms for each frame, trees %s" % [
				preset, view.name, draw_calls, triangles, objects, frame_ms, w.trees.shown])
		await d.screenshot("%s_%s" % [view.name, preset])
		# The same view without the trees, to see the part of the trees.
		w.trees.visible = false
		await d.wait_frames(3)
		var bare_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var bare_triangles := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		w.trees.visible = true
		await d.wait_frames(2)
		results[-1].without_trees = {"draw_calls": bare_calls, "triangles": bare_triangles}
		d.step("%s, view %s without the trees: %d draw calls, %d triangles" % [preset, view.name, bare_calls, bare_triangles])
		if LIMITS.has(preset):
			var limit: Array = LIMITS[preset]
			d.step("%s, view %s: the whole view against R12: %d of %d draw calls, %d of %d triangles" % [
					preset, view.name, draw_calls, limit[0], triangles, limit[1]])
			var tree_calls := draw_calls - bare_calls
			var tree_triangles := triangles - bare_triangles
			d.expect(tree_calls <= limit[0] * TREE_PART, "%s, view %s: the trees add %d draw calls, not more than %d" % [
					preset, view.name, tree_calls, int(limit[0] * TREE_PART)])
			d.expect(tree_triangles <= limit[1] * TREE_PART, "%s, view %s: the trees add %d triangles, not more than %d" % [
					preset, view.name, tree_triangles, int(limit[1] * TREE_PART)])
	d.fly_end()
	var file := FileAccess.open(d.out_dir.path_join("tree_budget_%s.json" % preset), FileAccess.WRITE)
	file.store_string(JSON.stringify({"preset": preset, "renderer": RenderingServer.get_current_rendering_method(),
			"views": results}, "\t"))
	file.close()


## The views: the top of Núi Nhỏ looking north over the town, Quang Trung
## along the road, and Thùy Vân along the road.
static func views(w: VungTau) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var hill := w.data.landmark("nui_nho")
	if not hill.is_empty():
		var top := Vector3(hill.position[0], 0.0, hill.position[1])
		top.y = w.ground_height(top.x, top.z) + Player.EYE_HEIGHT
		result.append({"name": "nui_nho_top", "eye": top, "target": top + Vector3(0, -60.0, -500.0)})
	for road_name: String in ["Quang Trung", "Thùy Vân"]:
		var points := _road_points(w, road_name)
		if points.size() < 12:
			continue
		var at := points[points.size() / 2]
		var ahead := points[points.size() / 2 + 8]
		result.append({"name": "bai_truoc_road" if road_name == "Quang Trung" else "bai_sau_road",
				"eye": at + Vector3(0, Player.EYE_HEIGHT, 0), "target": ahead + Vector3(0, Player.EYE_HEIGHT, 0)})
	return result


## The points of the longest road with the name.
static func _road_points(w: VungTau, road_name: String) -> Array[Vector3]:
	var best: Array = []
	for road: Dictionary in w.data.roads:
		if road.name == road_name and road.points.size() > best.size():
			best = road.points
	var result: Array[Vector3] = []
	for p: Array in best:
		result.append(Vector3(p[0], p[1], p[2]))
	return result
