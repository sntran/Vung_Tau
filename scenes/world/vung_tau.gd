class_name VungTau
extends Node3D
## The real ground of Vũng Tàu (plan 0003): ground chunks, the sea, the sky,
## the sun, the roads, simple trees, and the landmark markers.
##
## The ground is in chunks of 256 m. Each chunk with data has a far mesh from
## the overview grid all the time, so there is never a hole. Near the player,
## a worker thread makes a finer mesh, and the far mesh hides when the fine
## mesh is ready. Near chunks also have collision, roads, and trees.

## The detail of a chunk: the far mesh only, the mid mesh (8 m), or the near mesh (2 m).
enum Detail { FAR, MID, NEAR }

const NEAR_DISTANCE := 300.0
const MID_DISTANCE := 1000.0
## The distance at which a chunk goes back to less detail, so that it does not change at each step.
const HYSTERESIS := 60.0
const MID_STRIDE := 4
## A far tile has FAR_TILE x FAR_TILE chunks.
const FAR_TILE := 4
## The player cannot walk into water deeper than this (R13).
const MAX_WATER_DEPTH := 0.5
const MAX_TASKS := 2
const MAX_APPLY_PER_FRAME := 1
const TREE_SPACING := 9.0
const MARKER_HEIGHT := 30.0
const MARKER_SPACING := 120.0
const MARKER_STACK := 16.0
const TEXTURE_ROOT := "res://assets/textures/ground/"
const TEXTURE_COLORS := {"sand": Color("#D9C79E"), "grass": Color("#6E8A47"), "rock": Color("#7D766C"),
		"town": Color("#B3ADA3"), "wood": Color("#3F5A2C"), "asphalt": Color("#4A4A4C"),
		"concrete": Color("#A9A59C")}

var data: GeoData
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var environment: Environment
var sea: MeshInstance3D
## The load time in milliseconds of each near chunk, for PT-22.
var load_times: Array[float] = []
var _ground_material: ShaderMaterial
var _sea_material: ShaderMaterial
var _road_materials: Dictionary = {}
var _tree_mesh: Mesh
var _surface_image: Image
var _chunks: Dictionary = {}  # Vector2i -> {"detail", "wanted", "far", "tile", "fine", "busy", "asked"}
var _far_tiles: Dictionary = {}  # Vector2i -> MeshInstance3D
var _done: Array = []
var _mutex := Mutex.new()
var _tasks := 0
var _focus := Vector3.ZERO


## Builds the world. Returns false when the geodata is not there.
func setup(folder := GeoData.ROOT) -> bool:
	data = GeoData.open(folder)
	if data == null:
		push_error("VungTau: no geodata in %s. Run the geodata workflow." % folder)
		return false
	_make_environment()
	_make_materials()
	_make_sea()
	_make_far_ground()
	_make_markers()
	return true


## Builds the near chunks around the point at once (not in a worker thread), so
## that the ground has collision before the player stands on it.
func prepare_at(point: Vector3, radius := 64.0) -> void:
	_focus = point
	for key: Vector2i in _chunks:
		if _distance_to_chunk(key) > radius or _chunks[key].detail == Detail.NEAR:
			continue
		_chunks[key].asked = Time.get_ticks_msec()
		_chunks[key].busy = true
		_tasks += 1
		_build_chunk(key, Detail.NEAR)
		_chunks[key].wanted = Detail.NEAR
	while true:
		_mutex.lock()
		var left := _done.size()
		_mutex.unlock()
		if left == 0:
			break
		_apply_done()


# --- Queries -----------------------------------------------------------------

## The ground height at a game point (exact near the player).
func ground_height(x: float, z: float) -> float:
	return data.height_at(x, z, true)


## True when the player can stand at the point: the water is not deeper than 0.5 m.
func can_stand(point: Vector3) -> bool:
	return ground_height(point.x, point.z) >= -MAX_WATER_DEPTH


## The road at a game point, or {}.
func road_at(point: Vector3) -> Dictionary:
	return data.road_at(point.x, point.z)


## The start point of the player: on the coast road near Bãi Trước, facing the beach.
func spawn() -> Dictionary:
	var coast: String = data.homestay.get("coast_road", "")
	var best := Vector3.ZERO
	var best_distance := INF
	for road: Dictionary in data.roads:
		if coast == "" or road.name != coast:
			continue
		for p: Array in road.points:
			var d := Vector2(p[0], p[2]).length()
			if d < best_distance:
				best_distance = d
				best = Vector3(p[0], p[1], p[2])
	var beach := data.landmark("bai_truoc")
	var look := Vector2.ZERO
	if not beach.is_empty():
		look = Vector2(beach.position[0], beach.position[1])
	var to := look - Vector2(best.x, best.z)
	var yaw := rad_to_deg(atan2(-to.x, -to.y)) if to.length() > 1.0 else 0.0
	best.y = ground_height(best.x, best.z) + 0.05
	return {"position": best, "yaw": yaw}


## The detail of the chunk at a game point, for the tests.
func detail_at(point: Vector3) -> int:
	var state: Dictionary = _chunks.get(data.chunk_of(point.x, point.z), {})
	return state.get("detail", -1)


## True when each chunk has the detail that it needs, and no worker is busy.
func is_settled() -> bool:
	if _tasks > 0:
		return false
	for state: Dictionary in _chunks.values():
		if state.wanted != state.detail:
			return false
	return true


func loaded_counts() -> Dictionary:
	var counts := {"far": 0, "mid": 0, "near": 0, "busy": _tasks}
	for state: Dictionary in _chunks.values():
		counts[["far", "mid", "near"][state.detail]] += 1
	return counts


# --- Time and light ----------------------------------------------------------

## Sets the sun and the sky for the clock time (D9, R14).
func update_time(minutes: int, day: int) -> void:
	var origin: Dictionary = data.world.get("origin", {})
	var sun_now := SunPosition.at(float(origin.get("lat", 10.35)), float(origin.get("lon", 107.08)),
			SunPosition.day_of_year(day), minutes)
	var elevation: float = sun_now.elevation
	var direction := SunPosition.direction(elevation, sun_now.azimuth)
	_point_light(sun, direction)
	# The light starts before sunrise: at civil twilight (-6 degrees), people see well.
	var sun_up := smoothstep(-2.0, 10.0, elevation)
	var twilight := smoothstep(-9.0, 2.0, elevation)
	sun.visible = elevation > -2.0
	sun.light_energy = 1.2 * sun_up
	sun.light_color = Color("#FFA45C").lerp(Color("#FFF6E8"), smoothstep(2.0, 25.0, elevation))
	moon.visible = elevation < 2.0
	moon.light_energy = 0.15 * (1.0 - twilight)
	environment.ambient_light_energy = lerpf(0.35, 1.0, twilight)
	environment.background_energy_multiplier = lerpf(0.12, 1.0, twilight)
	environment.tonemap_exposure = lerpf(1.7, 1.0, sun_up)
	environment.fog_light_color = Color("#1A2236").lerp(Color("#C2D3E2"), twilight)


static func _point_light(light: DirectionalLight3D, toward_light: Vector3) -> void:
	var up := Vector3.UP if absf(toward_light.y) < 0.99 else Vector3.FORWARD
	light.basis = Basis.looking_at(-toward_light, up)


# --- Streaming ---------------------------------------------------------------

func _process(_delta: float) -> void:
	if data == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera:
		_focus = camera.global_position
	sea.global_position = Vector3(snappedf(_focus.x, 64.0), 0.0, snappedf(_focus.z, 64.0))
	_update_wanted()
	_start_tasks()
	_apply_done()


func _distance_to_chunk(key: Vector2i) -> float:
	var size := data.chunk_size
	var dx := maxf(maxf(key.x * size - _focus.x, _focus.x - (key.x + 1) * size), 0.0)
	var dz := maxf(maxf(key.y * size - _focus.z, _focus.z - (key.y + 1) * size), 0.0)
	return Vector2(dx, dz).length()


func _update_wanted() -> void:
	for key: Vector2i in _chunks:
		var state: Dictionary = _chunks[key]
		var distance := _distance_to_chunk(key)
		var margin := HYSTERESIS if state.detail != Detail.FAR else 0.0
		var wanted := Detail.FAR
		if distance < NEAR_DISTANCE + (margin if state.detail == Detail.NEAR else 0.0):
			wanted = Detail.NEAR
		elif distance < MID_DISTANCE + margin:
			wanted = Detail.MID
		state.wanted = wanted
		state.distance = distance
		if wanted == Detail.FAR and state.detail != Detail.FAR:
			_show_far(key)


func _start_tasks() -> void:
	if _tasks >= MAX_TASKS:
		return
	# The nearest chunk that needs a finer mesh goes first.
	var best := Vector2i.ZERO
	var best_distance := INF
	for key: Vector2i in _chunks:
		var state: Dictionary = _chunks[key]
		if state.busy or state.wanted == Detail.FAR or state.wanted == state.detail:
			continue
		if state.distance < best_distance:
			best_distance = state.distance
			best = key
	if best_distance == INF:
		return
	var state: Dictionary = _chunks[best]
	state.busy = true
	state.asked = Time.get_ticks_msec()
	_tasks += 1
	WorkerThreadPool.add_task(_build_chunk.bind(best, int(state.wanted)), false, "ground chunk")


## Runs in a worker thread: decodes the heights and makes the mesh arrays.
func _build_chunk(key: Vector2i, detail: int) -> void:
	var result := {"key": key, "detail": detail}
	var heights := data.chunk_heights(key)
	if not heights.is_empty():
		var n := data.samples
		var stride := 1 if detail == Detail.NEAR else MID_STRIDE
		var count := (n - 1) / stride + 1
		result.ground = TerrainBuilder.arrays(heights, n, n, 0, 0, count, stride, data.grid)
		if detail == Detail.NEAR:
			result.shape = TerrainBuilder.height_shape(heights, n, data.grid)
			var origin := Vector3(key.x * data.chunk_size, 0.0, key.y * data.chunk_size)
			result.roads = RoadBuilder.build(data, key, origin)
			result.trees = _tree_transforms(key, heights)
	_mutex.lock()
	_done.append(result)
	_mutex.unlock()


func _apply_done() -> void:
	_mutex.lock()
	var ready := _done.slice(0, MAX_APPLY_PER_FRAME)
	_done = _done.slice(MAX_APPLY_PER_FRAME)
	_mutex.unlock()
	for result: Dictionary in ready:
		_tasks -= 1
		var key: Vector2i = result.key
		var state: Dictionary = _chunks[key]
		state.busy = false
		if not result.has("ground") or state.wanted != result.detail:
			continue
		_show_fine(key, result)
		if result.detail == Detail.NEAR:
			load_times.append(Time.get_ticks_msec() - float(state.asked))


func _show_fine(key: Vector2i, result: Dictionary) -> void:
	var state: Dictionary = _chunks[key]
	if state.fine:
		state.fine.queue_free()
	var node := Node3D.new()
	node.name = "Chunk_%d_%d" % [key.x, key.y]
	node.position = Vector3(key.x * data.chunk_size, 0.0, key.y * data.chunk_size)
	add_child(node)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = TerrainBuilder.mesh(result.ground, _ground_material)
	node.add_child(ground)
	if result.has("shape"):
		var body := StaticBody3D.new()
		body.name = "Collision"
		body.collision_layer = Layers.FLOOR
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = result.shape
		var half := data.chunk_size / 2.0
		shape.position = Vector3(half, 0.0, half)
		shape.scale = Vector3.ONE * data.grid
		body.add_child(shape)
		node.add_child(body)
		_add_roads(node, body, result.roads)
		_add_trees(node, result.trees)
	var was_far: bool = state.detail == Detail.FAR
	state.fine = node
	state.detail = result.detail
	if was_far:
		_rebuild_far_tile(state.tile)


func _show_far(key: Vector2i) -> void:
	var state: Dictionary = _chunks[key]
	if state.fine:
		state.fine.queue_free()
		state.fine = null
	state.detail = Detail.FAR
	_rebuild_far_tile(state.tile)


func _add_roads(node: Node3D, body: StaticBody3D, roads: Dictionary) -> void:
	for kind: String in ["asphalt", "concrete", "dirt", "sidewalk", "lines"]:
		if roads[kind] == null:
			continue
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, roads[kind])
		mesh.surface_set_material(0, _road_materials[kind])
		var instance := MeshInstance3D.new()
		instance.name = "Road_" + kind
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(instance)
	var faces: PackedVector3Array = roads.collision
	if not faces.is_empty():
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var collision := CollisionShape3D.new()
		collision.name = "Sidewalks"
		collision.shape = shape
		body.add_child(collision)


# --- Trees -------------------------------------------------------------------

## Runs in a worker thread. Trees grow in woods and on the hills, not in towns,
## on sand, on steep rock, or on roads.
func _tree_transforms(key: Vector2i, heights: PackedFloat32Array) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	if _surface_image == null:
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var n := data.samples
	var count := int(data.chunk_size / TREE_SPACING)
	for j in count:
		for i in count:
			var local := Vector2((i + rng.randf()) * TREE_SPACING, (j + rng.randf()) * TREE_SPACING)
			var col := clampi(int(local.x / data.grid), 1, n - 2)
			var row := clampi(int(local.y / data.grid), 1, n - 2)
			var h := heights[row * n + col]
			if h < 2.0:
				continue
			var slope := maxf(absf(heights[row * n + col + 1] - heights[row * n + col - 1]),
					absf(heights[(row + 1) * n + col] - heights[(row - 1) * n + col])) / (2.0 * data.grid)
			if slope > 0.6:
				continue
			var world := Vector2(key.x * data.chunk_size, key.y * data.chunk_size) + local
			var mask := _mask_at(world)
			var wood := mask.b > 0.4
			if mask.r > 0.3 or mask.g > 0.3 or not (wood or h > 12.0):
				continue
			if rng.randf() > (0.8 if wood else 0.45):
				continue
			if not data.road_at(world.x, world.y).is_empty():
				continue
			var size := rng.randf_range(0.7, 1.3)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size)
			result.append(Transform3D(basis, Vector3(local.x, h - 0.1, local.y)))
	return result


func _mask_at(world: Vector2) -> Color:
	var step: float = float(data.surface.get("step", 8.0))
	var x := int((world.x - float(data.surface.get("x0", 0.0))) / step)
	var y := int((world.y - float(data.surface.get("z0", 0.0))) / step)
	if x < 0 or y < 0 or x >= _surface_image.get_width() or y >= _surface_image.get_height():
		return Color(0, 0, 0, 0)
	return _surface_image.get_pixel(x, y)


func _add_trees(node: Node3D, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _tree_mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "Trees"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(instance)


# --- Setup -------------------------------------------------------------------

func _make_environment() -> void:
	var sky_material := PhysicalSkyMaterial.new()
	sky_material.rayleigh_coefficient = 2.0
	sky_material.mie_coefficient = 0.004
	sky_material.turbidity = 5.0
	sky_material.ground_color = Color("#3A4A55")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.00008
	environment.fog_sky_affect = 0.1
	var world_environment := WorldEnvironment.new()
	world_environment.name = "Environment"
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = false
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color("#9DB4E8")
	moon.shadow_enabled = false
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_point_light(moon, Vector3(0.3, 0.8, 0.5).normalized())
	add_child(moon)


func _make_materials() -> void:
	var mask_path := data.root.path_join("surface.png")
	if FileAccess.file_exists(mask_path):
		_surface_image = Image.new()
		_surface_image.load_png_from_buffer(FileAccess.get_file_as_bytes(mask_path))
	var mask_texture: Texture2D = ImageTexture.create_from_image(_surface_image) if _surface_image else null
	var origin := Vector2(float(data.surface.get("x0", 0.0)), float(data.surface.get("z0", 0.0)))
	var step := float(data.surface.get("step", 8.0))
	var size := Vector2(float(data.surface.get("columns", 1)) * step, float(data.surface.get("rows", 1)) * step)
	# The mask pixels are samples at their centers.
	var mask_origin := origin - Vector2(step, step) / 2.0
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = load("res://shaders/terrain.gdshader")
	for kind: String in ["sand", "grass", "rock", "town", "wood"]:
		var texture_kind: String = {"town": "concrete", "wood": "grass"}.get(kind, kind)
		_ground_material.set_shader_parameter(kind + "_texture", _texture_or_color(texture_kind, kind))
	_ground_material.set_shader_parameter("surface_mask", mask_texture)
	_ground_material.set_shader_parameter("mask_origin", mask_origin)
	_ground_material.set_shader_parameter("mask_size", size)
	_sea_material = ShaderMaterial.new()
	_sea_material.shader = load("res://shaders/water.gdshader")
	_sea_material.set_shader_parameter("surface_mask", mask_texture)
	_sea_material.set_shader_parameter("mask_origin", mask_origin)
	_sea_material.set_shader_parameter("mask_size", size)
	_sea_material.set_shader_parameter("coast_range", float(data.surface.get("coast_range_m", 64.0)))
	_sea_material.set_shader_parameter("wave_normal_a", _noise_texture(1, 0.012, true))
	_sea_material.set_shader_parameter("wave_normal_b", _noise_texture(2, 0.03, true))
	_sea_material.set_shader_parameter("foam_noise", _noise_texture(3, 0.02, false))
	for kind: String in ["asphalt", "concrete", "dirt", "sidewalk", "lines"]:
		var material := StandardMaterial3D.new()
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.9
		match kind:
			"asphalt":
				material.albedo_texture = _texture_or_color("asphalt", "asphalt")
				material.uv1_scale = Vector3(1.0, 1.0, 1.0)
			"concrete":
				material.albedo_texture = _texture_or_color("concrete", "concrete")
			"dirt":
				material.albedo_color = Color("#9C8462")
			"sidewalk":
				material.albedo_texture = _texture_or_color("concrete", "concrete")
				material.albedo_color = Color("#C9B9A6")
			"lines":
				material.albedo_color = Color("#E8E6DC")
				material.roughness = 0.7
		_road_materials[kind] = material
	_tree_mesh = _make_tree_mesh()


func _texture_or_color(texture_kind: String, color_kind: String) -> Texture2D:
	var path := TEXTURE_ROOT.path_join(texture_kind).path_join("diffuse.jpg")
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
	image.fill(TEXTURE_COLORS.get(color_kind, Color.GRAY))
	return ImageTexture.create_from_image(image)


static func _noise_texture(seed_value: int, frequency: float, normal_map: bool) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.as_normal_map = normal_map
	texture.bump_strength = 6.0
	texture.generate_mipmaps = true
	texture.noise = noise
	return texture


func _make_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(40000, 40000)
	plane.material = _sea_material
	sea = MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)


## The far ground, from the overview grid (16 m). The far meshes of 4 x 4
## chunks are one mesh (a tile), so that there are few draw calls. A tile
## leaves out the chunks that have a finer mesh.
func _make_far_ground() -> void:
	var overview := data.overview
	if overview.is_empty():
		return
	var step := float(overview.step)
	var per := int(data.chunk_size / step)
	for key: Vector2i in data.chunks:
		var col0 := int(roundf((key.x * data.chunk_size - float(overview.x0)) / step))
		var row0 := int(roundf((key.y * data.chunk_size - float(overview.z0)) / step))
		var arrays := TerrainBuilder.arrays(overview.heights, overview.width, overview.height, col0, row0, per + 1, 1,
				step)
		var tile := Vector2i(floori(float(key.x) / FAR_TILE), floori(float(key.y) / FAR_TILE))
		_chunks[key] = {"detail": Detail.FAR, "wanted": Detail.FAR, "far": arrays, "tile": tile, "fine": null,
				"busy": false, "asked": 0, "distance": INF}
		if not _far_tiles.has(tile):
			var instance := MeshInstance3D.new()
			instance.name = "Far_%d_%d" % [tile.x, tile.y]
			instance.position = Vector3(tile.x * FAR_TILE * data.chunk_size, 0.0, tile.y * FAR_TILE * data.chunk_size)
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)
			_far_tiles[tile] = instance
	for tile: Vector2i in _far_tiles:
		_rebuild_far_tile(tile)


## Makes the mesh of a far tile from the far arrays of its chunks that show no finer mesh.
func _rebuild_far_tile(tile: Vector2i) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var origin := Vector3(tile.x * FAR_TILE * data.chunk_size, 0.0, tile.y * FAR_TILE * data.chunk_size)
	for j in FAR_TILE:
		for i in FAR_TILE:
			var key := Vector2i(tile.x * FAR_TILE + i, tile.y * FAR_TILE + j)
			var state: Dictionary = _chunks.get(key, {})
			if state.is_empty() or state.detail != Detail.FAR:
				continue
			var arrays: Array = state.far
			var offset := Vector3(key.x * data.chunk_size, 0.0, key.y * data.chunk_size) - origin
			var first := vertices.size()
			for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				vertices.append(v + offset)
			normals.append_array(arrays[Mesh.ARRAY_NORMAL])
			for index: int in arrays[Mesh.ARRAY_INDEX]:
				indices.append(first + index)
	var instance: MeshInstance3D = _far_tiles[tile]
	if vertices.is_empty():
		instance.mesh = null
		return
	var result := []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = vertices
	result[Mesh.ARRAY_NORMAL] = normals
	result[Mesh.ARRAY_INDEX] = indices
	instance.mesh = TerrainBuilder.mesh(result, _ground_material)


func _make_markers() -> void:
	var font: Font = load("res://assets/fonts/BeVietnamPro-SemiBold.ttf")
	var placed: Array[Vector3] = []
	for record: Dictionary in data.landmarks:
		if not record.get("found", false):
			continue
		var label := Label3D.new()
		label.name = "Marker_" + str(record.id)
		label.text = record.name_vi
		label.font = font
		label.font_size = 48
		label.outline_size = 12
		label.modulate = Color("#FFF8E0")
		label.outline_modulate = Color("#3A2A1A")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.0006
		label.set_meta("test_id", "marker." + str(record.id))
		var pos: Array = record.position
		var height := float(record.get("height", data.overview_height(pos[0], pos[1])))
		label.position = Vector3(pos[0], maxf(height, 0.0) + MARKER_HEIGHT, pos[1])
		# Two landmarks at the same place (the lighthouse on the top of Núi Nhỏ):
		# the second label is higher.
		for other: Vector3 in placed:
			if Vector2(other.x - label.position.x, other.z - label.position.z).length() < MARKER_SPACING \
					and absf(other.y - label.position.y) < MARKER_STACK:
				label.position.y = other.y + MARKER_STACK
		placed.append(label.position)
		add_child(label)


static func _make_tree_mesh() -> Mesh:
	# A trunk and a round crown: two surfaces with their own colors.
	var mesh := ArrayMesh.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.18
	trunk.height = 2.4
	trunk.radial_segments = 6
	trunk.rings = 1
	var crown := SphereMesh.new()
	crown.radius = 1.8
	crown.height = 3.0
	crown.radial_segments = 8
	crown.rings = 4
	var parts := [[trunk, Vector3(0, 1.2, 0), Color("#6B4E33")], [crown, Vector3(0, 3.4, 0), Color("#466B32")]]
	for part: Array in parts:
		var tool := SurfaceTool.new()
		tool.append_from(part[0], 0, Transform3D(Basis(), part[1]))
		var material := StandardMaterial3D.new()
		material.albedo_color = part[2]
		material.roughness = 1.0
		tool.set_material(material)
		tool.commit(mesh)
	return mesh
