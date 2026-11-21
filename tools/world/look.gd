extends SceneTree
## Renders GLB files of World from some views, for the review of a model of
## this game next to its photos (docs/world-models.md, section 4).
##
##   godot --path . --rendering-method mobile --resolution 640x640 -s tools/world/look.gd -- OUT_DIR NAME.glb ...
##
## For each GLB: OUT_DIR/STEM_front.png, _side.png, _three_quarters.png, and
## _above.png. The front of a model is +Z (the import of a GLB of World). The
## sun comes from the front left and above, as in PT-56.

const VIEWS := {"front": [0.0, 8.0], "side": [90.0, 8.0], "three_quarters": [40.0, 18.0], "above": [30.0, 55.0]}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("look.gd: OUT_DIR NAME.glb ...")
		quit(1)
		return
	var out_dir := args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#d9dde2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c8d0dc")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	root.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 35.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	root.add_child(camera)
	camera.current = true
	for path: String in args.slice(1):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) != OK:
			push_error("look.gd: cannot read %s" % path)
			continue
		var model := doc.generate_scene(state) as Node3D
		_vertex_colors(model)
		root.add_child(model)
		var box := _bounds(model)
		var center := box.get_center()
		var radius := maxf(box.size.length() / 2.0, 0.05)
		var distance := radius / tan(deg_to_rad(camera.fov / 2.0)) * 1.15
		camera.near = maxf(distance / 200.0, 0.005)
		camera.far = distance * 10.0
		for view: String in VIEWS:
			var turn := deg_to_rad(float(VIEWS[view][0]))
			var rise := deg_to_rad(float(VIEWS[view][1]))
			var dir := Vector3(sin(turn) * cos(rise), sin(rise), cos(turn) * cos(rise))
			camera.global_position = center + dir * distance
			camera.look_at(center, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
			for i in 6:
				await process_frame
			var image := root.get_texture().get_image()
			image.save_png(out_dir.path_join("%s_%s.png" % [path.get_file().get_basename().replace(".", "_"), view]))
		model.queue_free()
		await process_frame
		print("look.gd: %s %s" % [path.get_file(), box.size])
	quit(0)


func _bounds(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var v := child as VisualInstance3D
		var b := v.global_transform * v.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## The colors at the points of a sculpture of World (COLOR_0) show, as in the
## game (WorldModel): a material with no image map takes them.
func _vertex_colors(node: Node) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (child as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as StandardMaterial3D
			if m != null and m.albedo_texture == null and (mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0:
				m.vertex_color_use_as_albedo = true
