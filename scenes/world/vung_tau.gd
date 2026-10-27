class_name VungTau
extends Node3D
## The real ground of Vũng Tàu (plan 0005): ground chunks, the sea with the
## tide, the sky, the sun, the roads, the trees (plan 0020), and the landmark markers.
##
## The ground is in chunks of 256 m. Each chunk with data has a far mesh from
## the overview grid all the time, so there is never a hole. Near the player,
## a worker thread makes a finer mesh, and the far mesh hides when the fine
## mesh is ready. Near chunks also have collision, roads, and trees.
##
## The ground has detail levels by distance (report 0005, D-0005-10): a near
## chunk is 4 x 4 patches of 64 m, each with a grid of 2 m, 4 m, or 8 m by its
## distance; a mid chunk has a grid of 8 m; and a far tile has a grid of 16 m,
## 32 m, or 64 m. The skirts of the meshes hide the gaps between the levels.
## The sun shadow uses a mesh of 8 m for each near chunk.

## The detail of a chunk: the far mesh only, the mid mesh (8 m), or the near mesh (2 m).
enum Detail { FAR, MID, NEAR }

## The near chunks (collision, roads, and trees) are nearer than this.
const NEAR_DISTANCE := 300.0
## The distance at which a chunk goes back to less detail, so that it does not change at each step.
const HYSTERESIS := 60.0
const MID_STRIDE := 4
## A near chunk has PATCHES x PATCHES patches.
const PATCHES := 4
## A patch changes its grid back to a coarser one only this much farther than the limit.
const PATCH_HYSTERESIS := 20.0
## A far tile has FAR_TILE x FAR_TILE chunks.
const FAR_TILE := 4
## The ground detail of each quality preset (D-0005-10): the distances (m) to
## which a near patch has a grid of 2 m and of 4 m (then 8 m), the distance of
## the mid chunks (a grid of 8 m), and the distances to which a far tile has a
## grid of 16 m and of 32 m (then 64 m). Low uses the coarser grids sooner.
const GROUND_DETAIL := {
	"low": {"near": [50.0, 140.0], "mid": 400.0, "far": [700.0, 1500.0]},
	"medium": {"near": [100.0, 250.0], "mid": 800.0, "far": [2000.0, 4000.0]},
	"high": {"near": [150.0, 400.0], "mid": 1000.0, "far": [2500.0, 5000.0]},
	"ultra": {"near": [150.0, 400.0], "mid": 1000.0, "far": [3000.0, 6000.0]},
}

## The ground detail now (Quality.apply() sets it with set_ground_detail()).
static var ground_detail: Dictionary = GROUND_DETAIL.high
static var ground_preset := "high"
## The boulders stay this far from the line of the Hòn Bà path (more than
## their size) and from the shrine of Hòn Bà (m), so that the player walks there
## and sees the islet at the end of the path.
const PATH_CLEAR := 4.0
## On the islet and near it, the walk along the path is narrower (m more than the size of the boulders).
const ISLAND_PATH_CLEAR := 0.5
## The boulders of a small island also lie on the low rocks (rock mask
## LOW_ROCK_MIN or more) up to this distance from it (m).
const ISLAND_REACH := 10.0
const LOW_ROCK_MIN := 0.3
const SHRINE_CLEAR := 12.0
## The boulders stay this far from the trunk of a hill tree, more than their radius (m).
const TRUNK_CLEAR := 1.0
## The player cannot walk into water deeper than this (R13).
const MAX_WATER_DEPTH := 0.5
## A point at this distance or less from the line of the Hòn Bà ridge is on
## the ridge, when its ground is not higher than the ridge top plus RIDGE_ABOVE.
const RIDGE_MARGIN := 1.0
const RIDGE_ABOVE := 0.3
const MAX_TASKS := 2
const MAX_APPLY_PER_FRAME := 1
## Trees and scrub do not grow lower than this.
const FOREST_LOWEST := 2.0
## A point is tree ground when the tree cover (cover.png, R) is more than this.
const FOREST_COVER := 0.5
## The calm water around Bãi Trước: little foam (report 0005, D-0005-07).
const CALM_BAY_RADIUS := 1200.0
const NIGHT_AMBIENT := Color("#2B3754")
const TWILIGHT_AMBIENT := Color("#C8A48E")
const DAY_AMBIENT := Color("#BCD0E2")
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
## The tide model (D12), or null when tide.json is not there.
var tide: TideModel
## The highest sea level of the last 12 hours.
var last_high := -100.0
## The sea level now, in meters above mean sea level.
var sea_level := 0.0
## The line of the Hòn Bà ridge in game coordinates, its top height, and its width (R8h).
var ridge_points := PackedVector2Array()
var ridge_top := -INF
var ridge_width := 4.0
## The load time in milliseconds of each near chunk, for PT-37.
var load_times: Array[float] = []
var _ground_material: ShaderMaterial
var _sea_material: ShaderMaterial
var _road_materials: Dictionary = {}
## The band of rocks around the Hòn Bà path (R8h): polygons in game X, Z.
var band_polygons: Array[PackedVector2Array] = []
var street_trees: StreetTrees
## All trees in their three forms (plan 0020).
var trees: TreeField
## The far form of the hill trees (D-0005-01).
var canopy: HillCanopy
## The outlines of the small islands in game X, Z, and their bounds.
var _islands: Array[PackedVector2Array] = []
var _island_bounds: Array[Rect2] = []
## The hill tree values (data/trees/types.json, "hills"), their areas, and
## the sizes of the variants of each hill type: type -> [[height, radius], ...].
var _hill_settings: Dictionary = {}
var _hill_areas: Array = []
var _hill_sizes: Dictionary = {}
## The land cover (cover.png: R tree cover, G bushes, B grass, A bare ground),
## the canopy heights (canopy.png) and their place, and the tree tops of the
## canopy map in each near chunk: Vector2i -> PackedFloat32Array of x, z,
## height, crown radius (report 0005, D-0005-09; plan 0020, R10a).
var _cover_image: Image
var _canopy_image: Image
var _canopy_place: Dictionary = {}
var _canopy_trees: Dictionary = {}
var sea_objects: SeaObjects
var roadworks: Roadworks
## The season values of the game day (R12a), from Season.of_day().
var season: Dictionary = {}
var _season_day := -1
var _surface_image: Image
## The rock mask (1 for the bare rock of the rocky coasts and the islands).
var _rock_image: Image
## The preset of the far boulders now.
var _boulder_preset := ""
var _chunks: Dictionary = {}  # Vector2i -> {"detail", "wanted", "far", "tile", "fine", "busy", "asked", "patches", "heights"}
var _far_tiles: Dictionary = {}  # Vector2i -> MeshInstance3D
var _far_strides: Dictionary = {}  # Vector2i -> the grid step of the tile now, in overview samples
## The preset of the far clumps of the hill trees now.
var _canopy_preset := ""
var _done: Array = []
var _mutex := Mutex.new()
var _tasks := 0
var _focus := Vector3.ZERO


## Sets the ground detail for a quality preset (D-0005-10).
static func set_ground_detail(preset: String) -> void:
	ground_preset = preset if GROUND_DETAIL.has(preset) else "low"
	ground_detail = GROUND_DETAIL[ground_preset]


## Builds the world. Returns false when the geodata is not there.
func setup(folder := GeoData.ROOT) -> bool:
	data = GeoData.open(folder)
	if data == null:
		push_error("VungTau: no geodata in %s. Run the geodata workflow." % folder)
		return false
	tide = TideModel.open(data.root.path_join("tide.json"))
	var ridge: Dictionary = data.world.get("hon_ba_ridge", {})
	for p: Array in ridge.get("points", []):
		ridge_points.append(Vector2(p[0], p[1]))
	ridge_top = float(ridge.get("top_m", -INF))
	ridge_width = float(ridge.get("width_m", 4.0))
	for polygon: Dictionary in ridge.get("band", {}).get("polygons", []):
		var points := PackedVector2Array()
		for p: Array in polygon.get("outline", []):
			points.append(Vector2(p[0], p[1]))
		band_polygons.append(points)
	for island: Dictionary in data.world.get("islands", []):
		var outline := PackedVector2Array()
		for p: Array in island.get("outline", []):
			outline.append(Vector2(p[0], p[1]))
		if outline.size() < 3:
			continue
		var bounds := Rect2(outline[0], Vector2.ZERO)
		for p: Vector2 in outline:
			bounds = bounds.expand(p)
		_islands.append(outline)
		_island_bounds.append(bounds)
	_make_environment()
	_read_cover()
	_make_materials()
	_make_sea()
	_make_far_ground()
	_make_markers()
	canopy = HillCanopy.new()
	canopy.name = "HillCanopy"
	add_child(canopy)
	canopy.setup(self)
	set_canopy(true)
	trees = TreeField.new()
	trees.name = "Trees"
	add_child(trees)
	trees.setup(TreeLibrary.shared())
	_read_hill_settings()
	street_trees = StreetTrees.new()
	street_trees.setup(data.root.path_join("trees.json"), trees)
	sea_objects = SeaObjects.new()
	sea_objects.name = "SeaObjects"
	add_child(sea_objects)
	sea_objects.setup(data.root.path_join("sea_objects.json"))
	roadworks = Roadworks.new()
	roadworks.name = "Roadworks"
	add_child(roadworks)
	if not roadworks.setup(data.root.path_join("roadworks.json")):
		roadworks.queue_free()
		roadworks = null
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
		_build_chunk(key, Detail.NEAR, _patch_strides(key))
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


## True when the player can stand at the point: the water is not deeper than
## 0.5 m (R13). On the Hòn Bà ridge, the ridge must be dry. A step from the
## point "from" that does not go into deeper water is also allowed, so that
## the player can always walk back out of the water (the floor of the data is
## almost flat in places, and the tide can rise under the player).
func can_stand(point: Vector3, from := Vector3.INF) -> bool:
	var ground := ground_height(point.x, point.z)
	if is_on_ridge(point) and ground <= ridge_top + RIDGE_ABOVE:
		return sea_level < ground
	if ground >= sea_level - MAX_WATER_DEPTH:
		return true
	return from != Vector3.INF and ground >= ground_height(from.x, from.z)


## True when the point is on the Hòn Bà rock path: on its line or in its band of rocks.
func is_on_ridge(point: Vector3) -> bool:
	if ridge_points.size() < 2:
		return false
	var at := Vector2(point.x, point.z)
	for polygon: PackedVector2Array in band_polygons:
		if Geometry2D.is_point_in_polygon(at, polygon):
			return true
	for i in ridge_points.size() - 1:
		var closest := Geometry2D.get_closest_point_to_segment(at, ridge_points[i], ridge_points[i + 1])
		if closest.distance_to(at) <= ridge_width / 2.0 + RIDGE_MARGIN:
			return true
	return false


## True when the Hòn Bà ridge is dry: the sea is below the ridge top.
func is_ridge_dry() -> bool:
	return sea_level < ridge_top


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


## Shows or hides the far form of the hill trees: the clumps, and the canopy
## and the tree cover of the ground (D-0005-01). PT-33 compares the hills
## with it and without it (then the ground under the trees is grass).
func set_canopy(on: bool) -> void:
	canopy.visible = on
	_ground_material.set_shader_parameter("tree_cover", 1.0 if on else 0.0)
	_ground_material.set_shader_parameter("canopy_near", (HillCanopy.NEAR_HIDE - 80.0) if on else 1.0e9)
	_ground_material.set_shader_parameter("canopy_far", (HillCanopy.NEAR_HIDE + 120.0) if on else 2.0e9)


## The detail of the chunk at a game point, for the tests.
func detail_at(point: Vector3) -> int:
	var state: Dictionary = _chunks.get(data.chunk_of(point.x, point.z), {})
	return state.get("detail", -1)


## True when each chunk has the detail that it needs, and no worker is busy.
func is_settled() -> bool:
	if _tasks > 0:
		return false
	for key: Vector2i in _chunks:
		var state: Dictionary = _chunks[key]
		if state.wanted != state.detail:
			return false
		var patches: Dictionary = state.get("patches", {})
		for at: Vector2i in patches:
			if patches[at].stride != _patch_stride(key, at, patches[at].stride):
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
	if tide:
		var now := GameCalendar.unix_time(day, minutes)
		sea_level = tide.level(now)
		# The highest water of the last 12 hours: the sand below it is still wet (D-0005-09).
		var high := sea_level
		for i in range(1, 25):
			high = maxf(high, tide.level(now - i * 1800.0))
		last_high = high
	sea.position.y = sea_level
	_ground_material.set_shader_parameter("sea_level", sea_level)
	_ground_material.set_shader_parameter("last_high", last_high)
	if day != _season_day:
		_apply_season(day)
	if roadworks:
		roadworks.update_time(minutes)
	if not Wind.held:
		var wind := Wind.of_time(TreeLibrary.shared().settings.get("wind", {}), minutes)
		Wind.apply(wind.direction, wind.strength)
	var origin: Dictionary = data.world.get("origin", {})
	var sun_now := SunPosition.at(float(origin.get("lat", 10.35)), float(origin.get("lon", 107.08)),
			GameCalendar.day_of_year(day), minutes)
	var elevation: float = sun_now.elevation
	var direction := SunPosition.direction(elevation, sun_now.azimuth)
	_point_light(sun, direction)
	# The light starts before sunrise: at civil twilight (-6 degrees), people see well.
	var sun_up := smoothstep(-3.0, 6.0, elevation)
	var twilight := smoothstep(-9.0, 1.0, elevation)
	var high := smoothstep(4.0, 25.0, elevation)
	sun.visible = elevation > -3.0
	sun.light_energy = 1.2 * sun_up
	sun.light_color = Color("#FFA45C").lerp(Color("#FFF6E8"), high)
	moon.visible = elevation < 2.0
	moon.light_energy = 0.15 * (1.0 - twilight)
	# The physical sky gives almost no light near sunrise, so the ambient light
	# is a color: blue at night, warm in the twilight, the sky color in the day.
	var ambient := NIGHT_AMBIENT.lerp(TWILIGHT_AMBIENT, twilight).lerp(DAY_AMBIENT, high)
	environment.ambient_light_color = ambient
	environment.ambient_light_energy = lerpf(0.35, 0.75, twilight)
	environment.tonemap_exposure = lerpf(1.5, 1.0, high)
	environment.fog_light_color = ambient.darkened(0.15)
	environment.fog_light_energy = lerpf(0.25, 1.0, twilight)
	var colors := sky_colors(elevation)
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	sky_material.sky_top_color = colors[0]
	sky_material.sky_horizon_color = colors[1]
	sky_material.ground_horizon_color = colors[1].darkened(0.2)
	sky_material.ground_bottom_color = colors[0].darkened(0.6)


## The plants follow the season of the game date (R12a): the hill grass, the
## hill trees, and the street trees.
func _apply_season(day: int) -> void:
	_season_day = day
	season = Season.of_day(day)
	_ground_material.set_shader_parameter("dryness", season.dryness)
	TreeLibrary.shared().apply_season(day)
	if canopy:
		canopy.apply_season(season)


## The colors of the sky (the top and the horizon) for the sun elevation in degrees.
static func sky_colors(elevation: float) -> Array[Color]:
	var keys := [
		[-12.0, Color("#03070F"), Color("#0A1324")],
		[-6.0, Color("#16234A"), Color("#4B4A6A")],
		[-1.0, Color("#33528A"), Color("#E0875A")],
		[6.0, Color("#4D7DBE"), Color("#F0B07C")],
		[20.0, Color("#4C8BD0"), Color("#BCD6EA")],
	]
	if elevation <= keys[0][0]:
		return [keys[0][1], keys[0][2]]
	for i in range(1, keys.size()):
		if elevation <= keys[i][0]:
			var t: float = (elevation - keys[i - 1][0]) / (keys[i][0] - keys[i - 1][0])
			return [(keys[i - 1][1] as Color).lerp(keys[i][1], t), (keys[i - 1][2] as Color).lerp(keys[i][2], t)]
	return [keys[-1][1], keys[-1][2]]


static func _point_light(light: DirectionalLight3D, toward_light: Vector3) -> void:
	var up := Vector3.UP if absf(toward_light.y) < 0.99 else Vector3.FORWARD
	light.basis = Basis.looking_at(-toward_light, up)


# --- Streaming ---------------------------------------------------------------

func _process(delta: float) -> void:
	if data == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera:
		_focus = camera.global_position
	sea.global_position = Vector3(snappedf(_focus.x, 64.0), sea_level, snappedf(_focus.z, 64.0))
	if sea_objects:
		sea_objects.update_sea(sea_level, delta)
	if canopy and _canopy_preset != ground_preset:
		_canopy_preset = ground_preset
		canopy.set_preset(ground_preset)
	if _boulder_preset != ground_preset:
		_boulder_preset = ground_preset
		for key: Vector2i in _chunks:
			if _chunks[key].fine:
				BoulderBuilder.set_preset(_chunks[key].fine, ground_preset)
	_update_wanted()
	_start_tasks()
	_update_patches()
	_update_far_strides()
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
		elif distance < float(ground_detail.mid) + margin:
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
	var strides := _patch_strides(best) if state.wanted == Detail.NEAR else {}
	WorkerThreadPool.add_task(_build_chunk.bind(best, int(state.wanted), strides), false, "ground chunk")


## Runs in a worker thread: decodes the heights and makes the mesh arrays. A
## near chunk gets its patches with the grids of "strides" (patch -> samples),
## and a shadow mesh of 8 m.
func _build_chunk(key: Vector2i, detail: int, strides: Dictionary) -> void:
	var result := {"key": key, "detail": detail}
	var heights := data.chunk_heights(key)
	if not heights.is_empty():
		var n := data.samples
		var count := (n - 1) / MID_STRIDE + 1
		result.ground = TerrainBuilder.arrays(heights, n, n, 0, 0, count, MID_STRIDE, data.grid)
		if detail == Detail.NEAR:
			result.heights = heights
			result.strides = strides
			result.patches = {}
			for at: Vector2i in strides:
				result.patches[at] = _patch_arrays(heights, at, strides[at])
			result.shape = TerrainBuilder.height_shape(heights, n, data.grid)
			var origin := Vector3(key.x * data.chunk_size, 0.0, key.y * data.chunk_size)
			result.roads = RoadBuilder.build(data, key, origin)
			result.trees = _tree_transforms(key, heights)
			result.boulders = _boulder_transforms(key, heights, result.trees)
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
		if result.has("patch"):
			_show_patch(result)
			continue
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
	ground.mesh = TerrainBuilder.mesh(result.ground, _ground_material)
	node.add_child(ground)
	state.patches = {}
	state.erase("heights")
	if result.has("patches"):
		# The mesh of 8 m only casts the sun shadow, and the patches show the ground.
		ground.name = "Shadow"
		ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		state.heights = result.heights
		for at: Vector2i in result.patches:
			var patch := MeshInstance3D.new()
			patch.name = "Ground_%d_%d" % [at.x, at.y]
			patch.position = Vector3(at.x, 0.0, at.y) * (data.chunk_size / PATCHES)
			patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			patch.mesh = TerrainBuilder.mesh(result.patches[at], _ground_material)
			node.add_child(patch)
			state.patches[at] = {"node": patch, "stride": int(result.strides[at]), "busy": false}
	else:
		ground.name = "Ground"
		ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		_add_trees(key, result.trees)
		for boulders: MultiMeshInstance3D in BoulderBuilder.nodes(result.boulders, node.position, ground_preset):
			node.add_child(boulders)
	else:
		trees.remove_source(key)
	var was_far: bool = state.detail == Detail.FAR
	state.fine = node
	state.detail = result.detail
	if was_far:
		_rebuild_far_tile(state.tile)


## The grid of a patch (in samples of 2 m: 1, 2, or 4) for its distance from
## the view. "current" is the grid now: a patch goes back to a coarser grid only
## PATCH_HYSTERESIS farther than the limit.
func _patch_stride(key: Vector2i, at: Vector2i, current: int) -> int:
	var size := data.chunk_size / PATCHES
	var x0 := key.x * data.chunk_size + at.x * size
	var z0 := key.y * data.chunk_size + at.y * size
	var dx := maxf(maxf(x0 - _focus.x, _focus.x - (x0 + size)), 0.0)
	var dz := maxf(maxf(z0 - _focus.z, _focus.z - (z0 + size)), 0.0)
	var distance := Vector2(dx, dz).length()
	var limits: Array = ground_detail.near
	var stride := 4
	for level in limits.size():
		var limit := float(limits[level])
		# Keep a finer grid a little farther than its limit.
		if current != 0 and current <= (1 << level):
			limit += PATCH_HYSTERESIS
		if distance < limit:
			stride = 1 << level
			break
	return stride


## The grids of all patches of a near chunk now: patch -> samples.
func _patch_strides(key: Vector2i) -> Dictionary:
	var strides := {}
	for j in PATCHES:
		for i in PATCHES:
			strides[Vector2i(i, j)] = _patch_stride(key, Vector2i(i, j), 0)
	return strides


## The near chunks that show no ground (a near chunk must have all its
## patches), for the tests (report 0005, D-0005-10).
func chunks_without_ground() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for key: Vector2i in _chunks:
		var state: Dictionary = _chunks[key]
		if state.detail == Detail.NEAR and state.get("patches", {}).size() != PATCHES * PATCHES:
			result.append(key)
	return result


## Runs in a worker thread: the mesh arrays of a patch with a grid of "stride" samples.
func _patch_arrays(heights: PackedFloat32Array, at: Vector2i, stride: int) -> Array:
	var cells := (data.samples - 1) / PATCHES
	return TerrainBuilder.arrays(heights, data.samples, data.samples, at.x * cells, at.y * cells, cells / stride + 1,
			stride, data.grid)


## Starts a worker for each patch that needs another grid, the nearest first.
func _update_patches() -> void:
	if _tasks >= MAX_TASKS:
		return
	var best_key := Vector2i.ZERO
	var best_at := Vector2i.ZERO
	var best_stride := 0
	var best_distance := INF
	for key: Vector2i in _chunks:
		var state: Dictionary = _chunks[key]
		var patches: Dictionary = state.get("patches", {})
		if patches.is_empty() or state.busy:
			continue
		for at: Vector2i in patches:
			var patch: Dictionary = patches[at]
			var stride := _patch_stride(key, at, patch.stride)
			if patch.busy or stride == patch.stride:
				continue
			# The patches that need a finer grid go first.
			var order: float = float(stride) * 1000.0 + float(state.distance)
			if order < best_distance:
				best_distance = order
				best_key = key
				best_at = at
				best_stride = stride
	if best_distance == INF:
		return
	var state: Dictionary = _chunks[best_key]
	state.patches[best_at].busy = true
	_tasks += 1
	WorkerThreadPool.add_task(_build_patch.bind(best_key, best_at, best_stride, state.heights), false, "ground patch")


## Runs in a worker thread.
func _build_patch(key: Vector2i, at: Vector2i, stride: int, heights: PackedFloat32Array) -> void:
	var result := {"key": key, "patch": at, "stride": stride, "ground": _patch_arrays(heights, at, stride)}
	_mutex.lock()
	_done.append(result)
	_mutex.unlock()


func _show_patch(result: Dictionary) -> void:
	var state: Dictionary = _chunks.get(result.key, {})
	var patches: Dictionary = state.get("patches", {})
	if not patches.has(result.patch):
		return
	var patch: Dictionary = patches[result.patch]
	patch.busy = false
	patch.stride = result.stride
	(patch.node as MeshInstance3D).mesh = TerrainBuilder.mesh(result.ground, _ground_material)


func _show_far(key: Vector2i) -> void:
	var state: Dictionary = _chunks[key]
	if state.fine:
		state.fine.queue_free()
		state.fine = null
	state.patches = {}
	state.erase("heights")
	trees.remove_source(key)
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

## True when trees grow at the point (h is the ground height): where the land
## cover has trees (ESA WorldCover and the canopy height maps, report 0005,
## D-0005-09), not on sand or in the water. The far forms (HillCanopy) and
## the ground shader use this rule. Safe in a worker thread.
func is_forest(x: float, z: float, h: float, _slope := 0.0) -> bool:
	if _cover_image == null or h < FOREST_LOWEST:
		return false
	return cover_at(x, z).r > FOREST_COVER and _mask_at(Vector2(x, z)).r <= 0.3


## The land cover at a point: R the part of tree cover, G of bushes, B of
## grass, A of bare ground. Safe in a worker thread.
func cover_at(x: float, z: float) -> Color:
	if _cover_image == null:
		return Color(0, 0, 0, 0)
	return _pixel(_cover_image, data.surface, x, z)


## The canopy height (m) at a point: the highest value of its cell of 4 m. Safe in a worker thread.
func canopy_height_at(x: float, z: float) -> float:
	if _canopy_image == null:
		return 0.0
	return _pixel(_canopy_image, _canopy_place, x, z).r * 255.0 * float(_canopy_place.get("scale_m", 0.2))


## The pixel of an image on a grid (x0 and z0 are the center of the first pixel).
static func _pixel(image: Image, place: Dictionary, x: float, z: float) -> Color:
	var step := float(place.get("step", 8.0))
	var col := roundi((x - float(place.get("x0", 0.0))) / step)
	var row := roundi((z - float(place.get("z0", 0.0))) / step)
	if col < 0 or row < 0 or col >= image.get_width() or row >= image.get_height():
		return Color(0, 0, 0, 0)
	return image.get_pixel(col, row)


## True when the point is on a small island (for example Hòn Bà).
func is_on_island(x: float, z: float) -> bool:
	var at := Vector2(x, z)
	for i in _islands.size():
		if _island_bounds[i].has_point(at) and Geometry2D.is_point_in_polygon(at, _islands[i]):
			return true
	return false


## Runs in a worker thread. Returns type -> transforms in world space: a hill
## tree on each tree top of the canopy map in the chunk, with the height of
## the map and the type with the shape of the crown (plan 0020, R10a), and the
## scrub where the canopy and the cover map have a bush and, less dense, under
## the trees (report 0005, D-0005-09). Not on sand, grass, bare ground, in the
## water, or on roads.
func _tree_transforms(key: Vector2i, heights: PackedFloat32Array) -> Dictionary:
	var result := {}
	if _cover_image == null or _surface_image == null:
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var origin := Vector2(key.x * data.chunk_size, key.y * data.chunk_size)
	var scale_range: Array = _hill_settings.get("scale", [0.5, 2.0])
	var tops: PackedFloat32Array = _canopy_trees.get(key, PackedFloat32Array())
	for i in range(0, tops.size(), 4):
		var world := Vector2(tops[i], tops[i + 1])
		var ground := _ground_at(heights, world - origin)
		var height := tops[i + 2] + rng.randf_range(-0.5, 0.5)
		var value := rng.randf()
		var turn := rng.randf() * TAU
		if ground.x < FOREST_LOWEST or _mask_at(world).r > 0.3 or not data.road_at(world.x, world.y).is_empty():
			continue
		var type := hill_type(world, height, tops[i + 3], value)
		var size: Array = _hill_sizes[type][TreeField.variant_at(Vector3(world.x, 0.0, world.y), _hill_sizes[type].size())]
		_add_place(result, type, world, ground.x, clampf(height / size[0], scale_range[0], scale_range[1]), turn)
	var scrub: Dictionary = _hill_settings.get("scrub", {})
	var spacing := float(scrub.get("spacing_m", 3.5))
	var density := float(scrub.get("density", 0.6))
	var under_trees := float(scrub.get("under_trees", 0.25))
	var max_slope := float(scrub.get("max_slope", 0.85))
	var bush_min := float(_canopy_place.get("bush_min_m", 0.6))
	var tree_min := float(_canopy_place.get("tree_min_m", 3.0))
	var scrub_height: float = _hill_sizes.get("scrub", [[2.2, 1.6]])[0][0]
	var count := int(data.chunk_size / spacing)
	for j in count:
		for i in count:
			var local := Vector2((i + rng.randf()) * spacing, (j + rng.randf()) * spacing)
			var value := rng.randf()
			var size := rng.randf_range(0.7, 1.3)
			var turn := rng.randf() * TAU
			var world := origin + local
			var canopy_m := canopy_height_at(world.x, world.y)
			# Only on the bushes and the trees of the cover map: grass and bare
			# ground show the ground (R10a), also with a low canopy on them.
			var cover := cover_at(world.x, world.y)
			var chance := 0.0
			if canopy_m >= bush_min and canopy_m < tree_min and cover.g > 0.3:
				chance = density
			elif canopy_m >= tree_min and cover.r > FOREST_COVER:
				chance = under_trees
			if value > chance:
				continue
			var ground := _ground_at(heights, local)
			if ground.x < FOREST_LOWEST or ground.y > max_slope or _mask_at(world).r > 0.3:
				continue
			if not data.road_at(world.x, world.y).is_empty():
				continue
			if canopy_m < tree_min:
				# A bush has the height of the map.
				size = clampf(canopy_m / scrub_height, 0.5, 1.4)
			_add_place(result, "scrub", world, ground.x, size, turn)
	return result


## Runs in a worker thread. Returns cell -> transforms in world space: the
## granite boulders on the bare rock of the rocky coasts and the small
## islands (_boulder_ground(); report 0005, D-0005-03 and D-0005-05),
## BoulderBuilder.PER_CELL in each cell of the mask. A cell is
## a square of BoulderBuilder.CELL meters of the chunk. A boulder lies on the
## slope of the ground. Not at the trunk of a hill tree of "trees_placed" (from
## _tree_transforms()), on roads, on the Hòn Bà path, or near the shrine of Hòn Bà.
func _boulder_transforms(key: Vector2i, heights: PackedFloat32Array, trees_placed: Dictionary) -> Dictionary:
	var result := {}
	if _rock_image == null:
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) + 7
	var origin := Vector2(key.x * data.chunk_size, key.y * data.chunk_size)
	var step := float(data.surface.get("step", 8.0))
	var trunks := PackedVector2Array()
	for type: String in trees_placed:
		if type != "scrub":
			for t: Transform3D in trees_placed[type]:
				trunks.append(Vector2(t.origin.x, t.origin.z))
	var shrine := data.landmark("mieu_hon_ba")
	var shrine_at := Vector2(shrine.position[0], shrine.position[1]) if not shrine.is_empty() else Vector2.INF
	var count := int(data.chunk_size / step)
	for j in count:
		for i in count:
			var center := origin + Vector2(i + 0.5, j + 0.5) * step
			if not _boulder_ground(center) and not _boulder_ground(center + Vector2(step, step) * 0.45) \
					and not _boulder_ground(center - Vector2(step, step) * 0.45):
				continue
			for k in BoulderBuilder.PER_CELL:
				var local := Vector2(i + rng.randf(), j + rng.randf()) * step
				# More small boulders than large ones.
				var radius := lerpf(BoulderBuilder.RADIUS.x, BoulderBuilder.RADIUS.y, pow(rng.randf(), 1.3))
				var turn := rng.randf() * TAU
				var tilt := rng.randf_range(-0.2, 0.2)
				var stretch := Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.7, 1.25), rng.randf_range(0.8, 1.3))
				var world := origin + local
				if not _boulder_ground(world) or _near_trunk(trunks, world, radius + TRUNK_CLEAR):
					continue
				var extent := radius * maxf(stretch.x, stretch.z)
				# A boulder can reach a little over the edge of a road (the steps to the shrine of Hòn Bà are narrow).
				if world.distance_to(shrine_at) < SHRINE_CLEAR or _near_road(world, extent * 0.5):
					continue
				var clear := ISLAND_PATH_CLEAR if _island_distance(world) <= ISLAND_REACH else PATH_CLEAR
				if _near_ridge_line(world, extent + clear, shrine_at):
					continue
				# The boulder lies on the slope: its base is parallel to the ground,
				# and a part of it is in the ground.
				var h := _height_at(heights, local)
				var normal := Vector3(_height_at(heights, local - Vector2.RIGHT) - _height_at(heights, local + Vector2.RIGHT), 2.0,
						_height_at(heights, local - Vector2.DOWN) - _height_at(heights, local + Vector2.DOWN)).normalized()
				var lift := normal * radius * (BoulderBuilder.BASE * stretch.y - BoulderBuilder.SINK)
				var basis := Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, tilt) \
						* Basis.from_scale(stretch * radius)
				var cell := Vector2i(int(local.x / BoulderBuilder.CELL), int(local.y / BoulderBuilder.CELL))
				if not result.has(cell):
					result[cell] = [] as Array[Transform3D]
				(result[cell] as Array[Transform3D]).append(Transform3D(basis, Vector3(world.x, h, world.y) + lift))
	return result


## True when a boulder can lie at the point: the bare rock of the rocky coasts
## and the islands (rock mask BoulderBuilder.MASK_MIN or more), all of a small
## island (the mask of 8 m is lower at its edge), and the low rocks near a
## small island, where the Hòn Bà path ends in the boulders of the islet. Safe
## in a worker thread.
func _boulder_ground(at: Vector2) -> bool:
	var value := rock_at(at.x, at.y)
	return value >= BoulderBuilder.MASK_MIN or (value >= LOW_ROCK_MIN and _island_distance(at) <= ISLAND_REACH)


## The distance (m) from the point to the nearest small island, 0 on an island,
## or INF when no island is nearer than ISLAND_REACH. Safe in a worker thread.
func _island_distance(at: Vector2) -> float:
	var best := INF
	for i in _islands.size():
		if not _island_bounds[i].grow(ISLAND_REACH).has_point(at):
			continue
		var outline := _islands[i]
		if Geometry2D.is_point_in_polygon(at, outline):
			return 0.0
		for k in outline.size():
			var closest := Geometry2D.get_closest_point_to_segment(at, outline[k], outline[(k + 1) % outline.size()])
			best = minf(best, closest.distance_to(at))
	return best


## The rock mask at a point: 1 for the bare rock of the rocky coasts and the
## islands, about 0.55 for the low rocks of the Hòn Bà path. Safe in a worker thread.
func rock_at(x: float, z: float) -> float:
	if _rock_image == null:
		return 0.0
	return _pixel(_rock_image, data.surface, x, z).r


## The ground height at a local point of a chunk, between the samples. Safe in a worker thread.
func _height_at(heights: PackedFloat32Array, local: Vector2) -> float:
	return GeoData._bilinear(heights, data.samples, data.samples, local.x / data.grid, local.y / data.grid)


## True when the point is nearer than "margin" to a point of "trunks".
static func _near_trunk(trunks: PackedVector2Array, at: Vector2, margin: float) -> bool:
	for trunk in trunks:
		if trunk.distance_squared_to(at) < margin * margin:
			return true
	return false


## True when the point is nearer than "margin" to the line of the Hòn Bà path,
## but not beyond its end on the islet: there the boulders start (the islet
## end of the line is the end nearer to the shrine).
func _near_ridge_line(at: Vector2, margin: float, shrine_at := Vector2.INF) -> bool:
	var count := ridge_points.size()
	if count < 2:
		return false
	var last := count - 1
	var step := -1
	if shrine_at != Vector2.INF and ridge_points[0].distance_to(shrine_at) < ridge_points[last].distance_to(shrine_at):
		last = 0
		step = 1
	var end := ridge_points[last]
	var before := ridge_points[last + step]
	if (at - end).dot(end - before) > 0.0:
		return false
	for i in count - 1:
		if Geometry2D.get_closest_point_to_segment(at, ridge_points[i], ridge_points[i + 1]).distance_to(at) < margin:
			return true
	return false


## True when a road is at the point or at "extent" from it in one of the four directions. Safe in a worker thread.
func _near_road(at: Vector2, extent: float) -> bool:
	for offset: Vector2 in [Vector2.ZERO, Vector2(extent, 0.0), Vector2(-extent, 0.0), Vector2(0.0, extent), Vector2(0.0, -extent)]:
		if not data.road_at(at.x + offset.x, at.y + offset.y).is_empty():
			return true
	return false


## The hill type of a tree top: in an area with extra types (teak on Núi Lớn),
## a part of the tall trees is of the extra type; else the type whose crown
## has the shape of the canopy patch (crown radius / height), and a height
## near the type height. value is a random value from 0 to 1. Safe in a worker thread.
func hill_type(world: Vector2, height: float, radius: float, value: float) -> String:
	for area: Dictionary in _hill_areas:
		if world.distance_to(area.center) > area.radius or height < area.min_height:
			continue
		for type: String in area.extra:
			if value < float(area.extra[type]):
				return type
			value -= float(area.extra[type])
	var p := Vector3(world.x, 0.0, world.y)
	var ratio := maxf(radius, 0.5) / maxf(height, 1.0)
	var weight := float(_hill_settings.get("height_weight", 0.5))
	var best := ""
	var best_score := INF
	for type: String in _hill_settings.get("types", ["hill_a"]):
		var sizes: Array = _hill_sizes.get(type, [])
		if sizes.is_empty():
			continue
		var size: Array = sizes[TreeField.variant_at(p, sizes.size())]
		var score := absf(log(ratio * size[0] / size[1])) + weight * absf(log(height / size[0]))
		if score < best_score:
			best_score = score
			best = type
	return best


## The height and the slope (rise for each meter) of the ground at a local point of a chunk.
func _ground_at(heights: PackedFloat32Array, local: Vector2) -> Vector2:
	var n := data.samples
	var col := clampi(int(local.x / data.grid), 1, n - 2)
	var row := clampi(int(local.y / data.grid), 1, n - 2)
	var h := heights[row * n + col]
	var slope := maxf(absf(heights[row * n + col + 1] - heights[row * n + col - 1]),
			absf(heights[(row + 1) * n + col] - heights[(row - 1) * n + col])) / (2.0 * data.grid)
	return Vector2(h, slope)


static func _add_place(result: Dictionary, type: String, world: Vector2, h: float, size: float, turn: float) -> void:
	if not result.has(type):
		result[type] = [] as Array[Transform3D]
	var basis := Basis(Vector3.UP, turn).scaled(Vector3.ONE * size)
	(result[type] as Array[Transform3D]).append(Transform3D(basis, Vector3(world.x, h - 0.1, world.y)))


func _read_hill_settings() -> void:
	var library := TreeLibrary.shared()
	_hill_settings = library.settings.get("hills", {})
	_hill_areas.clear()
	for area: Dictionary in _hill_settings.get("areas", []):
		var landmark := data.landmark(str(area.get("landmark", "")))
		if landmark.is_empty():
			continue
		var p: Array = landmark.position
		_hill_areas.append({"center": Vector2(p[0], p[1]), "radius": float(area.radius_m), "extra": area.get("extra", {}),
				"min_height": float(area.get("extra_min_height_m", 0.0))})
	_hill_sizes.clear()
	for type: String in _hill_settings.get("types", []) + ["scrub"] + _extra_types():
		if not library.has_type(type):
			continue
		var sizes := []
		for v in library.variants(type):
			var info := library.variant_info(type, v)
			sizes.append([maxf(float(info.height), 0.5), maxf(float(info.radius), 0.5)])
		_hill_sizes[type] = sizes


func _extra_types() -> Array:
	var result := []
	for area: Dictionary in _hill_areas:
		result.append_array(area.extra.keys())
	return result


## The land cover, the canopy heights, and the tree tops of the canopy map.
func _read_cover() -> void:
	var cover: Dictionary = data.world.get("cover", {})
	var cover_path := data.root.path_join(str(cover.get("file", "cover.png")))
	if not FileAccess.file_exists(cover_path):
		push_warning("VungTau: no %s. Run tools/geo/landcover.py and tools/geo/build.py." % cover_path)
		return
	_cover_image = Image.new()
	_cover_image.load_png_from_buffer(FileAccess.get_file_as_bytes(cover_path))
	_canopy_place = cover.get("canopy", {})
	var canopy_path := data.root.path_join(str(_canopy_place.get("file", "canopy.png")))
	if FileAccess.file_exists(canopy_path):
		_canopy_image = Image.new()
		_canopy_image.load_png_from_buffer(FileAccess.get_file_as_bytes(canopy_path))
	var trees_path := data.root.path_join(str(cover.get("trees", "canopy_trees.json")))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(trees_path)) if FileAccess.file_exists(trees_path) else null
	if not parsed is Dictionary:
		push_warning("VungTau: no tree tops in %s." % trees_path)
		return
	# A packed array in a container is a copy when it changes, so the lists grow in an Array first.
	var lists := {}
	var flat: Array = parsed.get("trees", [])
	for i in range(0, flat.size() - 3, 4):
		var key := Vector2i(floori(float(flat[i]) / data.chunk_size), floori(float(flat[i + 1]) / data.chunk_size))
		if not lists.has(key):
			lists[key] = []
		lists[key].append_array([flat[i], flat[i + 1], flat[i + 2], flat[i + 3]])
	for key: Vector2i in lists:
		_canopy_trees[key] = PackedFloat32Array(lists[key])


## The surface mask at a point: R sand, G town, B wood, A the distance to the coast.
func surface_at(x: float, z: float) -> Color:
	return _mask_at(Vector2(x, z))


func _mask_at(world: Vector2) -> Color:
	var step: float = float(data.surface.get("step", 8.0))
	var x := int((world.x - float(data.surface.get("x0", 0.0))) / step)
	var y := int((world.y - float(data.surface.get("z0", 0.0))) / step)
	if x < 0 or y < 0 or x >= _surface_image.get_width() or y >= _surface_image.get_height():
		return Color(0, 0, 0, 0)
	return _surface_image.get_pixel(x, y)


## The trees of a near chunk go into the tree field, in place of the trees before.
func _add_trees(key: Vector2i, placed: Dictionary) -> void:
	trees.remove_source(key)
	for type: String in placed:
		trees.add_trees(key, type, placed[type])


# --- Setup -------------------------------------------------------------------

func _make_environment() -> void:
	# The physical sky is black at sunrise and sunset under the Mobile renderer,
	# so the sky is procedural, with colors for the real sun elevation.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sun_angle_max = 20.0
	sky_material.sun_curve = 0.1
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.background_color = Color("#0B1426")
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.00004
	environment.fog_sky_affect = 0.0
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
	var rock_path := data.root.path_join(str(data.surface.get("rock", "rock.png")))
	var rock_texture: Texture2D = null
	if FileAccess.file_exists(rock_path):
		_rock_image = Image.new()
		_rock_image.load_png_from_buffer(FileAccess.get_file_as_bytes(rock_path))
		rock_texture = ImageTexture.create_from_image(_rock_image)
		_ground_material.set_shader_parameter("rock_mask", rock_texture)
	_ground_material.set_shader_parameter("mask_origin", mask_origin)
	_ground_material.set_shader_parameter("mask_size", size)
	if _cover_image:
		_ground_material.set_shader_parameter("cover_mask", ImageTexture.create_from_image(_cover_image))
	if _canopy_image:
		var canopy_step := float(_canopy_place.get("step", 4.0))
		_ground_material.set_shader_parameter("canopy_heights", ImageTexture.create_from_image(_canopy_image))
		_ground_material.set_shader_parameter("canopy_origin", Vector2(float(_canopy_place.x0), float(_canopy_place.z0)) - Vector2.ONE * canopy_step / 2.0)
		_ground_material.set_shader_parameter("canopy_size", Vector2(_canopy_image.get_width(), _canopy_image.get_height()) * canopy_step)
		_ground_material.set_shader_parameter("canopy_unit", 255.0 * float(_canopy_place.get("scale_m", 0.2)))
		_ground_material.set_shader_parameter("tree_min", float(_canopy_place.get("tree_min_m", 3.0)))
	_ground_material.set_shader_parameter("roof_colors", roof_colors())
	_sea_material = ShaderMaterial.new()
	_sea_material.shader = load("res://shaders/water.gdshader")
	_sea_material.set_shader_parameter("surface_mask", mask_texture)
	_sea_material.set_shader_parameter("mask_origin", mask_origin)
	_sea_material.set_shader_parameter("mask_size", size)
	_sea_material.set_shader_parameter("coast_range", float(data.surface.get("coast_range_m", 64.0)))
	_sea_material.set_shader_parameter("wave_normal_a", _noise_texture(1, 0.012, true))
	_sea_material.set_shader_parameter("wave_normal_b", _noise_texture(2, 0.03, true))
	_sea_material.set_shader_parameter("foam_noise", _noise_texture(3, 0.02, false))
	_sea_material.set_shader_parameter("rock_mask", rock_texture)
	# Bãi Trước is a calm bay: no white surf at the swimming beach (my photos, D-0005-07).
	var bay := data.landmark("bai_truoc")
	if not bay.is_empty():
		_sea_material.set_shader_parameter("calm_center", Vector2(bay.position[0], bay.position[1]))
		_sea_material.set_shader_parameter("calm_radius", CALM_BAY_RADIUS)
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
	var rock_ridge: Dictionary = data.world.get("hon_ba_ridge", {})
	_ground_material.set_shader_parameter("pool_level", float(rock_ridge.get("top_m", -100.0)) - 0.12)


## Eight roof colors of data/world/palette.json for the town seen from far
## (D-0005-09): the tiles, the metal sheets, and one concrete terrace.
static func roof_colors() -> Array[Color]:
	var result: Array[Color] = []
	var file := "res://data/world/palette.json"
	var palette: Variant = JSON.parse_string(FileAccess.get_file_as_string(file)) if FileAccess.file_exists(file) else null
	if palette is Dictionary:
		for hex: String in (palette.roof_tiles.colors as Array).slice(0, 2):
			result.append(Color(hex))
		var metal: Array = palette.metal_roofs.colors.duplicate()
		metal.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Color(a.color).s > Color(b.color).s)
		for entry: Dictionary in metal.slice(0, 5):
			result.append(Color(str(entry.color)))
		result.append(Color(str(palette.terraces.colors[0].color)))
	while result.size() < 8:
		result.append(Color("#B28469"))
	return result


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
		# The far mesh with a grid of 1, 2, and 4 overview samples (16 m, 32 m, 64 m).
		var arrays := {}
		for stride: int in [1, 2, 4]:
			arrays[stride] = TerrainBuilder.arrays(overview.heights, overview.width, overview.height, col0, row0,
					per / stride + 1, stride, step)
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
		_far_strides[tile] = _far_stride(tile)
		_rebuild_far_tile(tile)


## The grid of a far tile (in overview samples: 1, 2, or 4) for its distance from the view.
func _far_stride(tile: Vector2i) -> int:
	var size := FAR_TILE * data.chunk_size
	var dx := maxf(maxf(tile.x * size - _focus.x, _focus.x - (tile.x + 1) * size), 0.0)
	var dz := maxf(maxf(tile.y * size - _focus.z, _focus.z - (tile.y + 1) * size), 0.0)
	var distance := Vector2(dx, dz).length()
	var limits: Array = ground_detail.far
	for level in limits.size():
		if distance < float(limits[level]):
			return 1 << level
	return 4


## Makes the far tiles again whose grid must change (one each frame).
func _update_far_strides() -> void:
	for tile: Vector2i in _far_tiles:
		var stride := _far_stride(tile)
		if stride != _far_strides[tile]:
			_far_strides[tile] = stride
			_rebuild_far_tile(tile)
			return


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
			var arrays: Array = state.far[_far_strides.get(tile, 1)]
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
