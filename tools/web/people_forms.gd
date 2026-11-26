extends SceneTree
## Plan 0031, D13 and R13: the measure of the import of the pictures of the
## people. Run it after an import of the people with the form to measure
## (gltf/embedded_image_handling of their .import files), with a picture
## (the renderer of the web build):
##   xvfb-run -a -s "-screen 0 2560x2560x24" godot --path . --rendering-driver opengl3 \
##     --rendering-method gl_compatibility --resolution 960x540 -s tools/web/people_forms.gd -- OUT_DIR FORM
## It writes OUT_DIR/FORM.json (the load time of the scenes of the people, the
## memory of their textures with all of them in the scene, the size of the
## imported scenes) and OUT_DIR/FORM_sheet.png (walker_1 at 5 m: the mid level,
## then the far level).

const PACKS := "res://data/web/packs.json"
const SHEET_MODEL := "walker_1"
const SHEET_DISTANCE := 5.0
## The field of view of the sheet: the person fills the height of the picture.


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://people_forms"
	var form: String = args[1] if args.size() > 1 else "now"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var files: Array = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACKS))
	for pack: Dictionary in parsed.packs:
		if pack.id == "people":
			files = pack.files
	var result := {"form": form, "scenes": files.size()}
	# The size of the imported scenes (the files of the pack, with no .import).
	var bytes := 0
	for file: String in files:
		var cfg := ConfigFile.new()
		cfg.load(file + ".import")
		for dest: String in cfg.get_value("deps", "dest_files", []):
			bytes += FileAccess.get_file_as_bytes(dest).size()
	result.importedMB = snappedf(bytes / 1e6, 0.1)
	# The load time of all the scenes, and their textures in a scene.
	var root := Node3D.new()
	get_root().add_child(root)
	var before := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	var t0 := Time.get_ticks_usec()
	var scenes: Array[PackedScene] = []
	for file: String in files:
		scenes.append(load(file) as PackedScene)
	result.loadMs = snappedf((Time.get_ticks_usec() - t0) / 1000.0, 1.0)
	var x := 0.0
	for scene in scenes:
		var node := scene.instantiate() as Node3D
		node.position = Vector3(x, -100.0, 0.0)
		root.add_child(node)
		x += 2.0
	for i in 3:
		await process_frame
	var after := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	result.textureMB = snappedf((after - before) / 1048576.0, 0.1)
	result.staticMB = snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1)
	root.queue_free()
	await process_frame
	await _sheet(out_dir, form)
	var file := FileAccess.open(out_dir.path_join(form + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("people_forms.gd: %s" % JSON.stringify(result))
	quit(0)


## walker_1 at 5 m in the light of noon: the mid level, then the far level, side by side.
func _sheet(out_dir: String, form: String) -> void:
	var images: Array[Image] = []
	for level: String in ["mid", "far"]:
		var stage := Node3D.new()
		get_root().add_child(stage)
		var env := WorldEnvironment.new()
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.62, 0.75, 0.9)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.55, 0.58, 0.62)
		env.environment = environment
		stage.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
		stage.add_child(sun)
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(40, 40)
		ground.mesh = plane
		var ground_material := StandardMaterial3D.new()
		ground_material.albedo_color = Color(0.55, 0.53, 0.5)
		ground.material_override = ground_material
		stage.add_child(ground)
		var scene := load(WorldModel.ROOT + SHEET_MODEL + WorldModel.SUFFIX[level]) as PackedScene
		stage.add_child(scene.instantiate())
		var camera := Camera3D.new()
		camera.fov = 24.0
		stage.add_child(camera)
		camera.look_at_from_position(Vector3(0.0, 1.6, SHEET_DISTANCE), Vector3(0.0, 1.0, 0.0))
		camera.current = true
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		images.append(get_root().get_texture().get_image())
		stage.queue_free()
		await process_frame
	# The middle of each picture: the person, not the ground around it.
	var h := images[0].get_height()
	var w := 360
	var x0 := (images[0].get_width() - w) / 2
	var sheet := Image.create(w * 2, h, false, images[0].get_format())
	sheet.blit_rect(images[0], Rect2i(x0, 0, w, h), Vector2i(0, 0))
	sheet.blit_rect(images[1], Rect2i(x0, 0, w, h), Vector2i(w, 0))
	sheet.save_png(out_dir.path_join(form + "_sheet.png"))
