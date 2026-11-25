class_name Showcase
extends Node3D
## The showcase of Bãi Trước (plan 0026): the parts of the ground of the area
## that the roads and the known places do not make (R2 to R4, R6), and a
## stand-in for each building that World does not have yet (R7).
##
## data/showcase/bai_truoc.json gives the outline of the area and each part:
## the median of Quang Trung with its curb in red and white bands and its
## hedge, the sidewalks, the granite borders of the paths of the park, the low
## wall of the walk of the sea, the sea wall of Hạ Long, and the stand-ins.
## Each part follows an OSM way of data/geo/build/roads.json. The parts are a
## few meshes, one for each color, and one collision shape.

## Half the thickness of the low wall of the beach at its foot (tuong_bai_tam: width 0.42 m).
## The two sides of a low wall that differ by more than this (m, 2 m out) give the sand side by their heights.
## The point of the walk next to an opening of the low wall, out of the wall (m).
const STEP_WALK_M := 0.3
const SAND_SIDE_STEP := 0.15
const WALL_HALF_WIDTH := 0.21
const CONFIG := "res://data/showcase/bai_truoc.json"
const BUILDINGS := "res://data/geo/build/buildings.json"
const PLACES := "res://data/world/places/bai_truoc.json"
const TEXTURES := "res://assets/textures/look"
const SURFACE_SHADER := "res://shaders/showcase_surface.gdshader"
## As RoadBuilder.LIFT: the road surface is this much over its line.
const LIFT := 0.04
## Report 0026, D-0026-30: the asphalt between the two roads of a median where
## the median ends, up to this gap between their edges (m).
const MEDIAN_END_GAP := 12.0
## The color of a part that a model of this game replaces: the part keeps its
## collision and draws nothing (report 0026, D-0026-09).
const HIDDEN := "hidden"
## The step of the points of a part along its way.
const STEP := 2.0
## A part stops this far from the edge of another road (a junction).
const JUNCTION_MARGIN := 1.0
## A stand-in leaves this much room (m) on each side of the deck of the jetty.
const PASSAGE_MARGIN := 0.6
## The passage from the land goes to this point behind the shore end of the
## jetty (m): a straight approach on the line of the deck, so that a slow
## computer (2.8 m in a frame at 3 frames per second) does not miss the open
## end of the deck (PT-74 run 8).
const JETTY_BEHIND := 10.0
## The inner edge of the walk on the sea wall is this far in front of the curb of the road (m).
const CURB_FRONT := 0.02
## The walk on the sea wall is this much higher over the sidewalk of the road that it covers (m).
const OVER_SIDEWALK_LIFT := 0.02
## The way of the people goes on the road this far from the curb of the walk (m).
const ROAD_INSIDE := 1.5
## The base of a low wall along the beach: the highest ground this far across
## (m), and its steepest grade (D-0026-16).
const WALL_ACROSS := 0.6
const WALL_GRADE := 0.1
const WALL_SMOOTH_PASSES := 3
## The smoothing raises the walk on the sea wall by this much at most (m): the
## step from the road to the walk stays under the step of the player (report
## 0026, D-0026-11: the smoothing raised it 0.12 m where the road climbs).
const WALK_SMOOTH_MAX := 0.01
## The walk on the sea wall is at least this much over the ground under it (m):
## the build of the geodata puts the ground under it this much under its top.
const WALK_OVER_GROUND := 0.03
## The steepest grade of the walk on the sea wall, and the passes of its smoothing.
const WALK_GRADE := 0.09
const WALK_SMOOTH_PASSES := 4
## The shortest piece of the walk on the sea wall (m).
const SEA_WALK_MIN_RUN := 8.0
## Where two ways of the sea wall meet, their widths change over this length (m).
const WIDTH_BLEND := 10.0
## The middle of the walk goes on at least this much (m) from one point to the next.
const WALK_ADVANCE := 0.5
## The types of the ways that do not cut the walk on the sea wall.
const SEA_WALL_NOT_CUT_BY := ["footway", "path", "steps", "pedestrian", "cycleway", "track"]
## The source of the trees of the showcase in the tree field.
const TREE_SOURCE := Vector2i(-2000000, -2000000)

var world: VungTau
var data: Dictionary = {}
var outline := PackedVector2Array()
var park := PackedVector2Array()
## The length in meters of each kind of part, for the play tests.
var lengths: Dictionary = {}
## The stand-ins: [{osm, name, center (Vector3), top, outline (PackedVector2Array)}].
var stand_ins: Array[Dictionary] = []
## The OSM buildings of the area with no storeys from a source: not built.
var stand_ins_left_out: Array[String] = []
## The footprints of public data of the area (Overture Maps; report 0026, D-0026-03).
const FOOTPRINTS := "res://data/geo/build/footprints.json"
## The models of World at their places (D3): [{id, model, footprint (PackedVector2Array), base}].
var models: Array[Dictionary] = []
## The people of R10, or null.
var people: ShowcasePeople
## The outlines of the raised lawns (R4): the people of R10 sit on them.
var planter_rings: Array[PackedVector2Array] = []
## True when the lamps are on (R14).
var lamps_lit := false
var _lamps_set := false
## The lights of the street lamps (R14) and the colors of the heads that glow at night.
var lamp_lights: Array[OmniLight3D] = []
var glow_colors: Array[String] = []
## The materials of the models of World that glow at night (the panes of a lamp).
var glow_materials: Array[StandardMaterial3D] = []
## The openings of the low walls along the beach (R10): {at (Vector3), along (the
## direction of the wall)}.
var wall_openings: Array[Dictionary] = []
## The lamps of R9: {kind, at (the base), height}.
var lamps: Array[Dictionary] = []
## The way of the people along the sea wall of Hạ Long (PT-74): points every
## STEP m, on the walk (its top) or on the road where the walk has a gap, and
## for each point 1 when it is on the walk.
var sea_walk := PackedVector3Array()
var sea_walk_on := PackedByteArray()
## The road beside each point of sea_walk, 2 m in from the curb.
var sea_road := PackedVector3Array()
## The base lines of the low walls along the beach (D-0026-16; PT-71 checks
## that they are smooth).
var wall_lines: Array[PackedVector3Array] = []
## The edges of the parts that a player walks on (report 0026, D-0026-11):
## [{kind, a, b (the ends of the edge on the top of the part), out (the
## direction out of the part)}]. PT-71 scans the step at each edge.
var walk_edges: Array[Dictionary] = []
## The fine mask of the ground (R the lawns, G the paving) and its place, or null.
var ground_mask: Image
var ground_origin := Vector2.ZERO
var ground_step := 0.5

## The pieces of the walls that are models of this game (report 0026,
## D-0026-09): one row of MultiMeshes, the near, mid and far levels.
var wall_row: WorldRow
## The sloped granite pieces under the low wall of the beach (ke_da_bai_truoc):
## a row of their own, with the ranges of "under_ranges" of "wall_pieces" and
## no shadow (they lie on the sand). PT-73: in the row of the walls, S5 on Low
## had 312 688 triangles (the limit is 300 000).
var under_row: WorldRow
## The spans of the fences (the fence of the Grand Hotel): a row of their own,
## with the ranges of "fence_ranges" of "wall_pieces". In the row of the walls
## (the mid level to 12 m on Low), the fence of S4 showed its far level on Low.
var fence_row: WorldRow
## The lift of the levels of a model in a row (_lift_of()), for each model.
static var _lifts: Dictionary = {}
## The end of the range of the squares of a part in chunks (the color -> m).
var _far_ends: Dictionary = {}
## Report 0026, D-0026-17: the hedges, the round bushes, the flowers of the
## flower beds, and the benches of the park (park_plants), in one row.
var park_row: WorldRow
## The low lamps of the paths of the park: the hedges leave a gap at each.
var path_lamp_points: Array[Vector3] = []
## The places of the plants of the park, for PT-71: {"kind", "at", "radius"}.
var park_plants: Array[Dictionary] = []
## The long boats on the sand (report 0026, D-0026-20): {"at", "along" (unit, to
## the bow), "half" (half the length)}. The swimmers keep away from them.
var beached_boats: Array[Dictionary] = []

## The world builds the parts when the player comes near (report 0026, D-0026-12).
signal built

var _roads: Dictionary = {}  # OSM id -> the road Dictionary of roads.json
## The roads near the area: [[id, type, line, half width, box]] (see _other_roads()).
var _near_roads: Array = []
var _near_roads_read := false
## A model of World higher than this (m) is a building: it has a body that stops the player.
const MODEL_BODY_MIN_HEIGHT := 2.5
## The steps of the build that are not done yet (Callables).
var _steps: Array[Callable] = []
var _built := false
## The last clock time of update_time(), or -1.
var _minutes := -1
## The box of the outline (x, z of the game).
var _bounds := Rect2()
## The ids of the models of World at their places, and the state of the load of their files.
var _place_ids: Array[String] = []
## The ranges of the models of World of the places, for each preset (D6).
var _place_ranges := {}
var _requested := false
## True in build_all(): a step does not wait for the files of a model.
var _forced := false
## Set by a step that waits for the files of a model.
var _waiting := false
var _meshes: Dictionary = {}  # color (String) -> _Mesh
var _collision := PackedVector3Array()
var _materials: Dictionary = {}


func setup(w: VungTau, path := CONFIG) -> bool:
	world = w
	var parsed: Variant = JSON.parse_string(GeoData.read_text(path))
	if not parsed is Dictionary:
		push_error("Showcase: cannot read %s." % path)
		return false
	data = parsed
	outline = _points(data.get("outline", []))
	park = _points(data.get("park", []))
	if not outline.is_empty():
		_bounds = Rect2(outline[0], Vector2.ZERO)
		for p in outline:
			_bounds = _bounds.expand(p)
	for road: Dictionary in w.data.roads:
		_roads[int(road.id)] = road
	# The mask of the lawns and the paving is on the ground also from far.
	_ground(w.data.root.path_join("showcase.json"))
	# The other parts are steps that the world does when the player comes
	# near the area (report 0026, D-0026-12).
	_steps.clear()
	_place_steps(PLACES)
	if data.has("median"):
		_steps.append(_median.bind(data.median))
	for sidewalk: Dictionary in data.get("sidewalks", []):
		_steps.append(_sidewalk.bind(sidewalk))
	if data.has("path_borders"):
		_steps.append(_path_borders.bind(data.path_borders))
	for wall: Dictionary in data.get("walls", []):
		_steps.append(_walls.bind(wall))
	for sea_wall: Dictionary in data.get("sea_walls", []):
		_steps.append(_sea_wall.bind(sea_wall))
	for fence: Dictionary in data.get("fences", []):
		_steps.append(_fence.bind(fence))
	for row: Dictionary in data.get("lamp_rows", []):
		_steps.append(_lamp_row.bind(row))
	if data.has("path_lamps"):
		_steps.append(_path_lamps.bind(data.path_lamps))
	if data.has("park_plants"):
		_steps.append(_park_plants.bind(data.park_plants))
	if data.has("stand_ins"):
		_steps.append(_stand_ins.bind(data.stand_ins))
	var beached: Variant = data.get("beached", [])
	for cfg: Dictionary in (beached if beached is Array else [beached]):
		_steps.append(_beached.bind(cfg))
	_steps.append(_commit)
	# R10: the people, after the parts (they sit on the raised lawns).
	_steps.append(_add_people)
	return true


## The distance (m) from the point to the box of the area (0 in the box).
func distance_to(p: Vector3) -> float:
	var dx := maxf(maxf(_bounds.position.x - p.x, p.x - _bounds.end.x), 0.0)
	var dz := maxf(maxf(_bounds.position.y - p.z, p.z - _bounds.end.y), 0.0)
	return Vector2(dx, dz).length()


## True when all the parts are there.
func is_built() -> bool:
	return _built


## Does the next steps of the build, for "budget_ms" ms at most and at least
## one step (report 0026, D-0026-12).
func build_some(budget_ms: float) -> void:
	WorldModel.release_dropped()
	if not _requested:
		_requested = true
		for id: String in _place_ids:
			WorldModel.request(id, _place_ranges)
	var end := Time.get_ticks_msec() + budget_ms
	while not _steps.is_empty():
		_waiting = false
		var step: Callable = _steps[0]
		step.call()
		if _waiting:
			# The files of the model load in other threads: the next frame.
			break
		_steps.pop_front()
		if Time.get_ticks_msec() >= end:
			break
	if _steps.is_empty() and not _built:
		_built = true
		if _minutes >= 0:
			_lamps_set = false
			update_time(_minutes)
		built.emit()


## Does all the steps of the build that are left.
func build_all() -> void:
	_forced = true
	build_some(INF)
	_forced = false


func _add_people() -> void:
	if not GeoData.has_file(ShowcasePeople.PATH):
		return
	people = ShowcasePeople.new()
	people.name = "People"
	add_child(people)
	people.setup(world, self)


## The clock time: the people of the hour (R10).
func update_time(minutes: int) -> void:
	_minutes = minutes
	if not _built:
		return
	if people:
		people.update_time(minutes)
	var on := DayLight.lamps_on(minutes)
	if on == lamps_lit and lamp_lights.size() > 0 and _lamps_set:
		return
	_lamps_set = true
	lamps_lit = on
	for light in lamp_lights:
		light.visible = on
	for color in glow_colors:
		var m := _materials.get(color) as StandardMaterial3D
		if m:
			m.emission_enabled = true
			m.emission = Color(color)
			m.emission_energy_multiplier = float(data.get("lamp_glow", 3.0)) if on else 0.0
	for m in glow_materials:
		m.emission_enabled = true
		m.emission = Color("#ece8da")
		m.emission_energy_multiplier = float(data.get("lamp_glow", 3.0)) if on else 0.0


## True when the point (x, z of the game) is in the area.
func contains(x: float, z: float) -> bool:
	return outline.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2(x, z), outline)


# --- The parts ----------------------------------------------------------------

## R3, R4: the lawns and the paving of the park (a fine mask of the ground),
## the raised lawns of the walk of the sea, and the low wall of granite along
## the beach, from data/geo/build/showcase.json (tools/geo/build.py).
func _ground(path: String) -> void:
	if not GeoData.has_file(path):
		push_warning("Showcase: %s is not there. Run tools/geo/build.py." % path)
		return
	var parsed: Variant = JSON.parse_string(GeoData.read_text(path))
	if not parsed is Dictionary:
		push_error("Showcase: cannot read %s." % path)
		return
	var info: Dictionary = parsed.get("ground", {})
	var file: String = world.data.root.path_join(str(info.get("file", "")))
	if not info.is_empty() and GeoData.has_file(file):
		ground_mask = Image.new()
		ground_mask.load_png_from_buffer(FileAccess.get_file_as_bytes(file))
		ground_step = float(info.get("step", 0.5))
		ground_origin = Vector2(float(info.x0), float(info.z0))
		world.set_showcase_ground(ImageTexture.create_from_image(ground_mask), ground_origin,
				Vector2(ground_mask.get_width(), ground_mask.get_height()) * ground_step)
		var paving: Dictionary = data.get("ground", {}).get("paving_texture", {})
		var sets := _texture_sets()
		if sets.has(str(paving.get("texture", ""))):
			var folder := TEXTURES.path_join(str(paving.texture))
			world.set_showcase_paving(load(folder.path_join("diffuse.jpg")), float(sets[paving.texture].get("size_m", 2.0)),
					Color(str(paving.get("tint", "#FFFFFF"))), Color(str(paving.get("mean", "#A89F90"))),
					float(paving.get("gain", 1.0)))
		var areas: Dictionary = parsed.get("areas", {})
		_add_length("lawn_m2", float(areas.get("lawn_m2", 0.0)))
		_add_length("paving_m2", float(areas.get("paving_m2", 0.0)))
	var cfg: Dictionary = data.get("ground", {})
	for planter: Dictionary in parsed.get("planters", []):
		_planter(_points(planter.outline), cfg.get("planters", {}), str(planter.get("osm", "")))
	for wall: Dictionary in parsed.get("walls", []):
		var line := PackedVector3Array()
		for point: Array in wall.points:
			line.append(Vector3(float(point[0]), world.ground_height(float(point[0]), float(point[1])), float(point[1])))
		var base := _wall_base(_dense(line, STEP))
		wall_lines.append(base)
		_balustrade(base, cfg.get("beach_wall", {}))
		_wall_poles(base, cfg.get("beach_wall", {}).get("poles", {}))


## Report 0026, D-0026-19: the blue poles of the walk of the sea, in_m to the
## land side of the low wall of the beach (the side with the higher ground), with
## the long arm over the walk.
func _wall_poles(line: PackedVector3Array, cfg: Dictionary) -> void:
	if cfg.is_empty() or line.size() < 2:
		return
	var sides := _sides(line)
	for at: Array in _every(line, float(cfg.get("every_m", 30.0)), float(cfg.get("from_end_m", 10.0))):
		var p: Vector3 = at[0]
		var along: Vector3 = at[1]
		var right := Vector3(-along.z, 0.0, along.x).normalized()
		var land := right if world.ground_height(p.x + right.x * 2.0, p.z + right.z * 2.0) \
				> world.ground_height(p.x - right.x * 2.0, p.z - right.z * 2.0) else -right
		# Report 0026, D-0026-33: not in an opening of the wall.
		var foot := _on_ground(_clear_of_openings(p + land * float(cfg.get("in_m", 1.0))))
		if not contains(foot.x, foot.z) or _in_model(foot):
			continue
		# A model with a long arm turns it to the right side of "along": to the land.
		_lamp(str(cfg.get("kind", "")), foot, along if right.dot(land) > 0.0 else -along)


## The base of a low wall along the edge of the walk (report 0026, D-0026-16):
## the wall stands at the edge between the walk and the sand (a drop of up to
## 2 m), so the ground on its line jumps between the two, and the top of its
## pieces was a saw-tooth. The base is the highest ground within WALL_ACROSS
## m across (the walk), then WALL_SMOOTH_PASSES times a mean of 5 points and
## a grade of at most WALL_GRADE.
func _wall_base(line: PackedVector3Array) -> PackedVector3Array:
	var sides := _sides(line)
	var raw := PackedFloat32Array()
	for i in line.size():
		var high := -INF
		for k: float in [-WALL_ACROSS, 0.0, WALL_ACROSS]:
			var q := line[i] + sides[i] * k
			high = maxf(high, world.ground_height(q.x, q.z))
		raw.append(high)
	var mean := raw
	for pass_index in WALL_SMOOTH_PASSES:
		var next := PackedFloat32Array()
		for i in mean.size():
			var total := 0.0
			var n := 0
			for k in range(maxi(0, i - 2), mini(mean.size(), i + 3)):
				total += mean[k]
				n += 1
			next.append(total / n)
		mean = _limit_grade(line, next, WALL_GRADE)
	var result := PackedVector3Array()
	for i in line.size():
		result.append(Vector3(line[i].x, mean[i], line[i].z))
	return result


## The lawn (R) and the paving (G) of the fine mask at a point, from 0 to 1.
func ground_at(x: float, z: float) -> Color:
	if ground_mask == null:
		return Color(0, 0, 0, 0)
	var col := int(floor((x - ground_origin.x) / ground_step))
	var row := int(floor((z - ground_origin.y) / ground_step))
	if col < 0 or row < 0 or col >= ground_mask.get_width() or row >= ground_mask.get_height():
		return Color(0, 0, 0, 0)
	return ground_mask.get_pixel(col, row)


## R4: a raised lawn: a border of granite round its outline, "height" m over
## the ground at each corner (its top follows the slope of the walk), and the
## lawn inside the border.
func _planter(ring: PackedVector2Array, cfg: Dictionary, osm := "") -> void:
	if ring.size() < 3:
		return
	# A raised lawn that is a model of World (D-0026-08) is at its place of
	# data/world/places/: the stand-in keeps its collision and its seats only.
	var model_id := str(cfg.get("models", {}).get(osm, ""))
	var stand_in := model_id == "" or WorldModel.order(model_id).is_empty()
	var h := float(cfg.get("height", 0.45))
	var border := float(cfg.get("border", 0.25))
	var color := str(cfg.get("color", "#aaa69c"))
	# Report 0026, D-0026-29: the top is one plane, fitted to the ground at the
	# corners (the slope of the walk). With the ground at each corner, the top
	# and the lawn were two bent faces with other diagonals, and the grey top
	# came over a third of the lawn.
	var plane := _ground_plane(ring)
	var top_of := func(p: Vector2) -> float: return plane.x + plane.y * p.x + plane.z * p.y + h
	var clockwise := _area(ring) < 0.0
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		var edge := (b - a).normalized()
		var out := Vector3(edge.y, 0, -edge.x) if not clockwise else Vector3(-edge.y, 0, edge.x)
		var a_low := Vector3(a.x, world.ground_height(a.x, a.y) - 0.1, a.y)
		var b_low := Vector3(b.x, world.ground_height(b.x, b.y) - 0.1, b.y)
		var a_top := Vector3(a.x, top_of.call(a), a.y)
		var b_top := Vector3(b.x, top_of.call(b), b.y)
		if stand_in:
			_mesh(color).quad(a_low, b_low, b_top, a_top, out)
		_collision.append_array([a_low, b_low, b_top, a_low, b_top, a_top])
	# The top: the border ring and the lawn inside it.
	var inner := Geometry2D.offset_polygon(ring, -border)
	var lawn := PackedVector2Array()
	for part: PackedVector2Array in inner:
		if not Geometry2D.is_polygon_clockwise(part) or part.size() > lawn.size():
			lawn = part
	planter_rings.append(ring)
	var top := func(points: PackedVector2Array, c: String, lift: float) -> void:
		var indices := Geometry2D.triangulate_polygon(points)
		for k in range(0, indices.size(), 3):
			var t := []
			for n in 3:
				var q := points[indices[k + n]]
				t.append(Vector3(q.x, top_of.call(q) + lift, q.y))
			if stand_in:
				_mesh(c).triangle(t[0], t[1], t[2], Vector3.UP)
			_collision.append_array([t[0], t[1], t[2]])
	top.call(ring, color, 0.0)
	if lawn.size() >= 3:
		top.call(lawn, str(cfg.get("top_color", "#4f6e35")), 0.02)
	_add_length("planter", 1.0)
	if not stand_in:
		_add_length("planter_models", 1.0)


## The plane a + b x + c z (as Vector3(a, b, c)) nearest to the ground at the
## points of a ring (least squares); a level plane for fewer than 3 points.
func _ground_plane(ring: PackedVector2Array) -> Vector3:
	var n := float(ring.size())
	var sx := 0.0
	var sz := 0.0
	var sh := 0.0
	for q in ring:
		sx += q.x
		sz += q.y
		sh += world.ground_height(q.x, q.y)
	if ring.size() < 3:
		return Vector3(sh / maxf(n, 1.0), 0.0, 0.0)
	var mx := sx / n
	var mz := sz / n
	var mh := sh / n
	var xx := 0.0
	var xz := 0.0
	var zz := 0.0
	var xh := 0.0
	var zh := 0.0
	for q in ring:
		var dx := q.x - mx
		var dz := q.y - mz
		var dh := world.ground_height(q.x, q.y) - mh
		xx += dx * dx
		xz += dx * dz
		zz += dz * dz
		xh += dx * dh
		zh += dz * dh
	var det := xx * zz - xz * xz
	if absf(det) < 0.000001:
		return Vector3(mh, 0.0, 0.0)
	var b := (xh * zz - zh * xz) / det
	var c := (zh * xx - xh * xz) / det
	return Vector3(mh - b * mx - c * mz, b, c)


## A flat face of the outline at the height y, that looks up.
func _flat(color: String, ring: PackedVector2Array, y: float) -> void:
	var indices := Geometry2D.triangulate_polygon(ring)
	for k in range(0, indices.size(), 3):
		var p := ring[indices[k]]
		var q := ring[indices[k + 1]]
		var r := ring[indices[k + 2]]
		_mesh(color).triangle(Vector3(p.x, y, p.y), Vector3(q.x, y, q.y), Vector3(r.x, y, r.y), Vector3.UP)


## R4: the low wall of granite blocks along the beach (the photo of S5, 2014):
## a base, square posts, and a top rail with gaps under it.
func _balustrade(line: PackedVector3Array, cfg: Dictionary) -> void:
	if line.size() < 2:
		return
	var color := str(cfg.get("color", "#b3ada1"))
	# The spans of the model of the low wall (report 0026, D-0026-09): the
	# parts of the stand-in keep their collision and draw nothing.
	var model_id := str(cfg.get("model", ""))
	var span := float(_option(model_id, "length", 1.35)) if _has_model(model_id) else 0.0
	if span > 0.0:
		color = HIDDEN
	var half := float(cfg.get("width", 0.4)) / 2.0
	var base := float(cfg.get("base", 0.3))
	var rail := float(cfg.get("height", 0.8))
	var rail_depth := float(cfg.get("rail", 0.14))
	var post_every := float(cfg.get("post_every", 2.4))
	var post_half := float(cfg.get("post", 0.32)) / 2.0
	# The openings to the sand (R10): one of "opening_m" in the middle of each
	# "opening_every_m" of the wall.
	var every := float(cfg.get("opening_every_m", 0.0))
	var opening := float(cfg.get("opening_m", 0.0))
	var total := 0.0
	for i in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	var gaps: Array[Vector2] = []
	if every > 0.0 and opening > 0.0 and total >= every:
		var count := floori(total / every)
		var first := (total - (count - 1) * every) / 2.0
		for k in count:
			var mid := first + k * every
			if span > 0.0:
				# Two whole spans of the model (2.7 m for spans of 1.35 m).
				var k0 := roundi(mid / span) - 1
				gaps.append(Vector2(k0 * span, (k0 + 2) * span))
			else:
				gaps.append(Vector2(mid - opening / 2.0, mid + opening / 2.0))
	var along := 0.0
	var next_post := 0.0
	for i in line.size() - 1:
		var a := line[i] + Vector3(0, LIFT, 0)
		var b := line[i + 1] + Vector3(0, LIFT, 0)
		var length := a.distance_to(b)
		var dir := (b - a).normalized()
		for part: Vector2 in _less_gaps(along, along + length, gaps):
			var p0 := a.lerp(b, (part.x - along) / maxf(length, 0.001))
			var p1 := a.lerp(b, (part.y - along) / maxf(length, 0.001))
			_box_along(color, p0, p1, half, -0.2, base)
			_box_along(color, p0, p1, half * 0.85, rail - rail_depth, rail)
		while next_post <= along + length:
			if not _in_gaps(next_post, gaps, post_half):
				var at := a.lerp(b, (next_post - along) / maxf(length, 0.001))
				_box_along(color, at - dir * post_half, at + dir * post_half, post_half, base, rail - rail_depth)
			next_post += post_every
		for gap in gaps:
			var mid := (gap.x + gap.y) / 2.0
			if mid >= along and mid < along + length:
				wall_openings.append({"at": a.lerp(b, (mid - along) / maxf(length, 0.001)), "along": dir,
						"half": (gap.y - gap.x) / 2.0})
		along += length
	_add_length("beach_wall", along)
	_add_length("wall_openings", gaps.size())
	if span > 0.0:
		_wall_spans(model_id, line, span, gaps)
	_steps_down(cfg.get("steps", {}), wall_openings.slice(wall_openings.size() - gaps.size()), half)


## Report 0026, Q19: the granite steps down to the sand in each opening of the
## low wall (bac_xuong_cat): the top edge of the piece at the sand face of the
## wall, at the height of the walk, the steps down to the sand side. The piece
## is scaled up and down to the drop to the sand at its foot. The height of the
## walk is the ground on the side of the walk next to the wall (STEP_WALK_M),
## not the base of the wall: the base is the highest ground near the line, and
## at an opening near a raised lawn the top of the steps was about 1 m over the
## walk (PT-77 checks the top, "top_y", and the foot of the model, "foot").
func _steps_down(cfg: Dictionary, openings: Array, half: float) -> void:
	var model_id := str(cfg.get("model", ""))
	# Each opening records its side of the sand (PT-77 walks through it).
	for opening: Dictionary in openings:
		var along_dir: Vector3 = opening.along
		opening.sand = _sand_side(opening.at, Vector3(-along_dir.z, 0.0, along_dir.x).normalized())
		opening.steps = false
	if not _has_model(model_id):
		return
	var drop := float(_option(model_id, "drop", 1.44))
	var run := float(_option(model_id, "steps", 8)) * float(_option(model_id, "tread", 0.3))
	for opening: Dictionary in openings:
		var at: Vector3 = opening.at
		var along: Vector3 = opening.along
		var sand: Vector3 = opening.sand
		var top := at + sand * half
		var walk := at - sand * (half + STEP_WALK_M)
		top.y = world.ground_height(walk.x, walk.z)
		var foot := top + sand * run
		var fall := top.y - world.ground_height(foot.x, foot.z)
		if fall < float(cfg.get("min_drop_m", 0.25)):
			continue
		var scale := clampf(fall / drop, 0.25, 2.0)
		# The steps go down along +z of the GLB (its top at z = 0, its foot at
		# z = run): +z goes to the sand. Report 0026, D-0026-26: with +z to the
		# walk, the steps went down under the walk, and from the sand the
		# opening showed the end of the steps over the sand.
		var basis := Basis(along, Vector3.UP * scale, sand)
		if basis.determinant() < 0.0:
			basis.x = -basis.x
		var lift := _lift_of(model_id)
		var placed := Transform3D(basis, top - basis.y * lift)
		_row_of_walls().add(model_id, placed)
		opening.steps = true
		# The top and the foot of the steps as the row draws them (the mesh of
		# the row is lifted by "lift"): the top at y = 0 of the GLB, the foot of
		# the last step at z = run, y = -drop.
		opening.top_y = (placed * Vector3(0.0, lift, 0.0)).y
		opening.foot = placed * Vector3(0.0, lift - drop, run)
		_add_length("steps_down", 1.0)


## Report 0026, D-0026-27: the sloped sea wall of granite blocks under a span
## of the low wall of the beach (ke_da_bai_truoc of "under_model" of the wall
## pieces): its top edge at the foot of the wall on the side of the sand, scaled
## in height to the drop from the walk to the sand 0.5 m past it.
func _sea_wall_under(a: Vector3, b: Vector3, sea: Vector3) -> void:
	var model_id := str(data.get("wall_pieces", {}).get("under_model", ""))
	if not _has_model(model_id):
		return
	var half := float(_option(model_id, "width", 0.42)) / 2.0
	var height := float(_option(model_id, "height", 1.2))
	var out := sea * (WALL_HALF_WIDTH + 0.02)
	var a2 := a + out
	var b2 := b + out
	var sand := 0.0
	for q: Vector3 in [a2 + sea * 0.5, b2 + sea * 0.5]:
		sand += world.ground_height(q.x, q.z) / 2.0
	var drop := (a.y + b.y) / 2.0 - sand
	if drop < 0.1 or half <= 0.0:
		return
	_wall_piece(model_id, a2, b2, sea, drop / height, 1.0, _row_under_walls())
	_add_length("beach_sea_wall_pieces", 1.0)


## The side of a low wall of the beach that is the sand (side or -side): the
## lower side 2 m out, where the two sides differ by more than SAND_SIDE_STEP;
## else the side with less lawn and paving in the mask of the ground (the walk
## is paving). Report 0026, D-0026-26: at the flat north end of the line the two
## sides have the same height, and the steps of the openings went up on the
## side of the walk; the paths of the park are not paving in the mask, so the
## mask alone took the walk for the sand there.
func _sand_side(at: Vector3, side: Vector3) -> Vector3:
	var high := world.ground_height(at.x + side.x * 2.0, at.z + side.z * 2.0)
	var low := world.ground_height(at.x - side.x * 2.0, at.z - side.z * 2.0)
	if absf(high - low) > SAND_SIDE_STEP:
		return side if high < low else -side
	var a := ground_at(at.x + side.x * 2.0, at.z + side.z * 2.0)
	var b := ground_at(at.x - side.x * 2.0, at.z - side.z * 2.0)
	if absf((a.r + a.g) - (b.r + b.g)) > 0.5:
		return side if a.r + a.g < b.r + b.g else -side
	return side if high < low else -side


## The spans of the model of a low wall along the line, end to end by their
## length, out of the gaps, on the ground; the sand (the lower side) is to +y
## of the model.
func _wall_spans(model_id: String, line: PackedVector3Array, span: float, gaps: Array[Vector2]) -> void:
	var total := _line_length(line)
	var k := 0
	while (k + 0.5) * span <= total:
		var s0 := k * span
		var s1 := minf((k + 1) * span, total)
		k += 1
		var mid := (s0 + s1) / 2.0
		if _in_gaps(mid, gaps, 0.0):
			continue
		# On the base of the wall (the line), not on the ground (D-0026-16).
		var a := _along_line(line, s0) + Vector3(0, LIFT, 0)
		var b := _along_line(line, s1) + Vector3(0, LIFT, 0)
		var middle := (a + b) / 2.0
		var sea := _sand_side(middle, Vector3(-(b - a).z, 0.0, (b - a).x).normalized())
		_wall_piece(model_id, a, b, sea)
		_sea_wall_under(a, b, sea)


## The point at the distance s along the line.
static func _along_line(line: PackedVector3Array, s: float) -> Vector3:
	var left := s
	for i in line.size() - 1:
		var length := line[i].distance_to(line[i + 1])
		if left <= length:
			return line[i].lerp(line[i + 1], left / maxf(length, 0.001))
		left -= length
	return line[line.size() - 1]


## The parts of [from, to] out of the gaps (each a Vector2 of from and to).
static func _less_gaps(from: float, to: float, gaps: Array[Vector2]) -> Array[Vector2]:
	var parts: Array[Vector2] = [Vector2(from, to)]
	for gap in gaps:
		var next: Array[Vector2] = []
		for part in parts:
			if gap.y <= part.x or gap.x >= part.y:
				next.append(part)
				continue
			if gap.x - part.x > 0.01:
				next.append(Vector2(part.x, gap.x))
			if part.y - gap.y > 0.01:
				next.append(Vector2(gap.y, part.y))
		parts = next
	return parts


## True when the distance is in a gap, or nearer to it than "margin".
static func _in_gaps(at: float, gaps: Array[Vector2], margin: float) -> bool:
	for gap in gaps:
		if at > gap.x - margin and at < gap.y + margin:
			return true
	return false


## The asphalt between the two roads of the median, under the median and
## where it ends (report 0026, D-0026-30), with the material of the roads of
## the world, a little under them.
func _median_ends(ends: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for i in ends.size() - 1:
		if ends[i] == null or ends[i + 1] == null:
			continue
		var s0: Array = ends[i]
		var s1: Array = ends[i + 1]
		if not s0[2] and not s1[2]:
			continue
		# Clockwise when seen from above (the front faces in Godot).
		for v: Vector3 in [s0[0], s1[0], s0[1], s0[1], s1[0], s1[1]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z) / RoadBuilder.TEXTURE_M)
			st.add_vertex(v)
		count += 1
	if count == 0:
		return
	var node := MeshInstance3D.new()
	node.name = "MedianEnds"
	node.mesh = st.commit()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if world != null and world._road_materials.has("asphalt"):
		node.material_override = world._road_materials["asphalt"]
	add_child(node)
	_add_length("median_ends", float(count) * STEP)


## R2: the median between the two roads of Quang Trung: a raised lawn with a
## curb in red and white bands at each side, and a hedge in its middle.
func _median(cfg: Dictionary) -> void:
	var ways: Array = cfg.get("ways", [])
	if ways.size() != 2 or not _roads.has(int(ways[0])) or not _roads.has(int(ways[1])):
		push_warning("Showcase: the median needs two roads of roads.json.")
		return
	var a: Dictionary = _roads[int(ways[0])]
	var b: Dictionary = _roads[int(ways[1])]
	var line_b := _line(b)
	var height := float(cfg.get("curb_height", 0.2))
	var curb := float(cfg.get("curb_width", 0.3))
	var colors: Array = cfg.get("curb_colors", ["#b5332c", "#ebe9e1"])
	var band := float(cfg.get("curb_band_m", 1.0))
	var hedge: Dictionary = cfg.get("hedge", {})
	var others := _other_roads([int(ways[0]), int(ways[1])])
	# A cross section at each point of road a: the edge of a and the edge of b.
	var sections: Array = []
	# Report 0026, D-0026-30 (audit 6): where the median ends (near the
	# junction, or where the two roads come together), the space between the
	# two roads is asphalt, not the ground: [the edge of a, the edge of b] or null.
	var ends: Array = []
	for p: Vector3 in _dense(_line(a), STEP):
		var q := _nearest(line_b, p)
		var across := Vector3(q.x - p.x, 0.0, q.z - p.z)
		var gap := across.length() - float(a.width) / 2.0 - float(b.width) / 2.0
		var mid := (p + q) / 2.0
		# The asphalt also under the median: on curves the edges of the roads and
		# of the median left thin slivers of ground (PT-74, run 5). Each section
		# out of the area keeps it too (the segment to the edge of the area);
		# _median_ends() leaves out the segments with both ends out.
		if gap > -3.0 and gap < MEDIAN_END_GAP:
			var d := across.normalized()
			ends.append([p + d * (float(a.width) / 2.0 - 0.3) + Vector3(0, LIFT - 0.005, 0),
					q - d * (float(b.width) / 2.0 - 0.3) + Vector3(0, LIFT - 0.005, 0), contains(mid.x, mid.z)])
		else:
			ends.append(null)
		if not contains(mid.x, mid.z) or gap < float(cfg.get("min_gap_m", 1.2)) or _near_other(mid, others, gap / 2.0):
			sections.append(null)
			continue
		var dir := across.normalized()
		var edge_a := p + dir * (float(a.width) / 2.0)
		var edge_b := q - dir * (float(b.width) / 2.0)
		edge_a.y = p.y + LIFT
		edge_b.y = q.y + LIFT
		sections.append([edge_a, edge_b])
	var top_color := str(cfg.get("top_color", "#4f6e35"))
	var hedge_color := str(hedge.get("color", "#365c2a"))
	var distance := 0.0
	# The middle line of each run of the median: the things on it (R9) stand by distance.
	# A packed array in an Array is a copy when it changes: each run grows in
	# "current" and goes into "runs" when it ends.
	var runs: Array[PackedVector3Array] = []
	var current := PackedVector3Array()
	for i in sections.size() - 1:
		if sections[i] == null or sections[i + 1] == null:
			if current.size() >= 2:
				runs.append(current)
			current = PackedVector3Array()
			continue
		var s0: Array = sections[i]
		var s1: Array = sections[i + 1]
		if current.is_empty():
			current.append((s0[0] + s0[1]) / 2.0 + Vector3(0, height, 0))
		current.append((s1[0] + s1[1]) / 2.0 + Vector3(0, height, 0))
		var length: float = ((s0[0] + s0[1]) / 2.0).distance_to((s1[0] + s1[1]) / 2.0)
		var curb_color := str(colors[int(floor(distance / band)) % colors.size()])
		distance += length
		var up := Vector3(0, height, 0)
		var a0: Vector3 = s0[0]
		var b0: Vector3 = s0[1]
		var a1: Vector3 = s1[0]
		var b1: Vector3 = s1[1]
		var in0 := (b0 - a0).normalized()
		var in1 := (b1 - a1).normalized()
		# The curbs: their faces to the roads and their tops.
		_wall(curb_color, a0, a1, height, -in0)
		_wall(curb_color, b0, b1, height, in0)
		_walk_edge("median: the curb of way %s" % ways[0], a0 + up, a1 + up, -in0)
		_walk_edge("median: the curb of way %s" % ways[1], b0 + up, b1 + up, in0)
		_top(curb_color, a0 + up, a1 + up, a0 + in0 * curb + up, a1 + in1 * curb + up)
		_top(curb_color, b0 - in0 * curb + up, b1 - in1 * curb + up, b0 + up, b1 + up)
		# The lawn between the curbs.
		_top(top_color, a0 + in0 * curb + up, a1 + in1 * curb + up, b0 - in0 * curb + up, b1 - in1 * curb + up)
		# The hedge in the middle.
		if not hedge.is_empty():
			var half := float(hedge.get("width", 1.1)) / 2.0
			var hh := Vector3(0, height + float(hedge.get("height", 0.8)), 0)
			var m0 := (a0 + b0) / 2.0
			var m1 := (a1 + b1) / 2.0
			if m0.distance_to(a0) > half + curb:
				_box_along(hedge_color, m0, m1, half, height, hh.y)
		_add_length("median", length)
	if current.size() >= 2:
		runs.append(current)
	_median_ends(ends)
	var trees: Dictionary = cfg.get("trees", {})
	var lamps: Dictionary = cfg.get("lamps", {})
	var tree_points: Array[Vector3] = []
	for run: PackedVector3Array in runs:
		if not trees.is_empty():
			for at: Array in _every(run, float(trees.spacing_m), float(trees.get("from_end_m", 4.0))):
				tree_points.append(at[0])
		if not lamps.is_empty():
			for at: Array in _every(run, float(lamps.every_m), float(lamps.get("from_end_m", 4.0))):
				_lamp(str(lamps.kind), at[0], at[1])
	if not tree_points.is_empty():
		_add_trees(str(trees.get("type", "araucaria")), tree_points, "median_trees")


## R2: a sidewalk at one side of a road, from its edge, with a curb face.
func _sidewalk(cfg: Dictionary) -> void:
	var road: Dictionary = _roads.get(int(cfg.get("way", 0)), {})
	if road.is_empty():
		push_warning("Showcase: the sidewalk of way %s finds no road." % cfg.get("way"))
		return
	var sign := 1.0 if str(cfg.get("side", "right")) == "right" else -1.0
	var width := float(cfg.get("width", 2.0))
	var height := float(cfg.get("height", 0.18))
	var half := float(road.width) / 2.0
	var others := _other_roads([int(road.id)])
	for run: PackedVector3Array in _runs(_line(road), func(p: Vector3, side: Vector3) -> bool:
			var mid := p + side * sign * (half + width / 2.0)
			return contains(mid.x, mid.z) and not _in_model(mid) and not _near_other(mid, others, width / 2.0)):
		var sides := _sides(run)
		for i in run.size() - 1:
			var e0 := run[i] + sides[i] * sign * half + Vector3(0, LIFT, 0)
			var e1 := run[i + 1] + sides[i + 1] * sign * half + Vector3(0, LIFT, 0)
			var o0 := e0 + sides[i] * sign * width
			var o1 := e1 + sides[i + 1] * sign * width
			var up := Vector3(0, height, 0)
			_wall(str(cfg.get("curb_color", "#c9c6bd")), e0, e1, height, -sides[i] * sign)
			_top(str(cfg.get("color", "#b9a68d")), e0 + up, e1 + up, o0 + up, o1 + up)
			_wall(str(cfg.get("color", "#b9a68d")), o0, o1, height, sides[i] * sign)
			_walk_edge("sidewalk %s: the curb" % cfg.get("way"), e0 + up, e1 + up, -sides[i] * sign)
			_walk_edge("sidewalk %s: the outer edge" % cfg.get("way"), o0 + up, o1 + up, sides[i] * sign)
			_add_length("sidewalk", e0.distance_to(e1))


## R3: the granite borders of the lawns along both edges of the paths of the park.
func _path_borders(cfg: Dictionary) -> void:
	var types: Array = cfg.get("types", ["footway", "pedestrian"])
	var height := float(cfg.get("height", 0.14))
	var width := float(cfg.get("width", 0.16))
	var color := str(cfg.get("color", "#8f8c86"))
	if park.size() < 3:
		return
	var park_box := Rect2(park[0], Vector2.ZERO)
	for p in park:
		park_box = park_box.expand(p)
	park_box = park_box.grow(float(width) + 4.0)
	var paths: Array[int] = []
	for id: int in _roads:
		if not str(_roads[id].type) in types:
			continue
		for p: Array in _roads[id].points:
			if park_box.has_point(Vector2(float(p[0]), float(p[2]))):
				paths.append(id)
				break
	for id: int in paths:
		var road: Dictionary = _roads[id]
		var half := float(road.width) / 2.0 + width / 2.0
		var others := _other_roads([id])
		for sign: float in [-1.0, 1.0]:
			for run: PackedVector3Array in _runs(_line(road), func(p: Vector3, side: Vector3) -> bool:
					var at := p + side * sign * half
					return park.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), park) \
							and not _near_other(at, others, width)):
				_ridge(color, run, sign * half, width, height, float(cfg.get("chunk_m", 0.0)))
				_add_length("path_border", _length(run))
	_far_ends[color] = float(cfg.get("far_m", 0.0))


## R4: a low wall at one side of a way (the wall between the walk of the sea and the beach).
func _walls(cfg: Dictionary) -> void:
	var sign := 1.0 if str(cfg.get("side", "left")) == "right" else -1.0
	for way: Variant in cfg.get("ways", []):
		var road: Dictionary = _roads.get(int(way), {})
		if road.is_empty():
			continue
		var width := float(cfg.get("width", 0.45))
		var offset := sign * (float(road.width) / 2.0 + width / 2.0)
		var others := _other_roads([int(way)])
		for run: PackedVector3Array in _runs(_line(road), func(p: Vector3, side: Vector3) -> bool:
				var at := p + side * offset
				return contains(at.x, at.z) and not _near_other(at, others, width)):
			if str(cfg.get("style", "")) == "balustrade":
				var sides := _sides(run)
				var line := PackedVector3Array()
				for i in run.size():
					line.append(run[i] + sides[i] * offset)
				var base := _wall_base(line)
				wall_lines.append(base)
				_balustrade(base, cfg)
			else:
				_ridge(str(cfg.get("color", "#8a867e")), run, offset, width, float(cfg.get("height", 0.55)))
			_add_length("wall", _length(run))
	# Report 0026, D-0026-30 (audit 6): a wall on its own points (x, z), not
	# along a way: the parapet of the square of the south end over the water.
	for points: Array in cfg.get("lines", []):
		var line := PackedVector3Array()
		for q: Array in points:
			line.append(Vector3(float(q[0]), world.ground_height(float(q[0]), float(q[1])) if world else 0.0, float(q[1])))
		line = _dense(line, STEP)
		if str(cfg.get("style", "")) == "balustrade":
			var base := _wall_base(line)
			wall_lines.append(base)
			_balustrade(base, cfg)
		else:
			_ridge(str(cfg.get("color", "#8a867e")), line, 0.0, float(cfg.get("width", 0.45)), float(cfg.get("height", 0.55)))
		_add_length("wall", _length(line))


## R4, R6: the walk on the sea side of Hạ Long, its parapet, and the sea wall
## of stone under it, down the ground to the sea.
func _sea_wall(cfg: Dictionary) -> void:
	var sign := 1.0 if str(cfg.get("side", "right")) == "right" else -1.0
	var walk := float(cfg.get("walk", 3.0))
	var width := float(cfg.get("width", 7.0))
	var parapet := float(cfg.get("parapet", 0.6))
	var until_z := float(cfg.get("until_z", INF))
	var color := str(cfg.get("color", "#77746c"))
	var walk_color := str(cfg.get("walk_color", "#b9a68d"))
	# The pieces of the parapet (report 0026, D-0026-09): a panel of red brown
	# granite every pillar_every_m among the pieces of grey granite.
	var parapet_id := str(cfg.get("parapet_model", ""))
	var pillar_id := str(cfg.get("pillar_model", ""))
	var pieces := _has_model(parapet_id) and _has_model(pillar_id)
	var pillar_every := float(cfg.get("pillar_every_m", 10.0))
	var parapet_color := HIDDEN if pieces else color
	if pieces:
		parapet = float(_option(parapet_id, "height", parapet))
	var inset := float(_option(parapet_id, "cap_width", 0.45)) / 2.0
	# Report 0026, D-0026-27: the pieces of the sloped sea wall of Hạ Long
	# (ke_ha_long), each scaled in height to the drop at its place; the plain
	# slope keeps its collision and draws nothing.
	var slope_id := str(cfg.get("slope_model", ""))
	var slope_pieces := _has_model(slope_id)
	var slope_color := HIDDEN if slope_pieces else color
	var slope_height := float(_option(slope_id, "height", 3.3))
	var pillar_length := float(_option(pillar_id, "length", 0.75))
	var next_pillar := pillar_every / 2.0
	# Report 0026, D-0026-31: the cast green posts with five globes along the
	# parapet, on the walk (lamps of data/showcase/bai_truoc.json).
	var lamps: Dictionary = cfg.get("lamps", {})
	var lamp_kind := str(lamps.get("kind", ""))
	var lamp_every := float(lamps.get("every_m", 40.0))
	var lamp_in := float(lamps.get("in_m", 0.65))
	var next_lamp := float(lamps.get("first_m", lamp_every / 2.0))
	# The walk goes from the curb of the road: it covers the sidewalk of the road
	# on the sea side (report 0026, D-0026-04: a strip of bare ground was between
	# the road and the walk).
	var over := RoadBuilder.SIDEWALK_WIDTH if bool(cfg.get("over_sidewalk", false)) else 0.0
	var ids: Array[int] = []
	for way: Variant in cfg.get("ways", []):
		ids.append(int(way))
	# A road that goes to the sea side cuts the walk (a junction). A footway
	# along the road does not: the walk is the way of the people there (the
	# OSM path of the sea along Hạ Long), and a road on the side of the hill
	# does not reach the walk (PT-74: the walk had gaps of 90 m over the bank).
	var others := _other_roads(ids, SEA_WALL_NOT_CUT_BY)
	# The ways of the sea wall are one line: where two ways meet, the walks of
	# the two ways overlapped and the way of the people went 4 m back (report
	# 0026, D-0026-01). The width of the road changes over WIDTH_BLEND m.
	for piece: Array in _sea_wall_lines(ids):
		var all_points: PackedVector3Array = piece[0]
		var all_halves: PackedFloat32Array = piece[1]
		var all_sides := _sides(all_points)
		# On the inner side of a sharp corner of the road, the middles of the walk
		# bunch together and go back: the points where the middle does not go on
		# by WALK_ADVANCE m are left out (report 0026, D-0026-01).
		var dense := PackedVector3Array()
		var halves := PackedFloat32Array()
		var sides := PackedVector3Array()
		var last_middle := Vector3.INF
		for i in all_points.size():
			var middle := all_points[i] + all_sides[i] * sign * (all_halves[i] + walk / 2.0)
			# _sides() gives the side (−forward.z, 0, forward.x): the forward from the side.
			var forward := Vector3(all_sides[i].z, 0.0, -all_sides[i].x)
			if last_middle != Vector3.INF and (middle - last_middle).dot(forward) < WALK_ADVANCE and i < all_points.size() - 1:
				continue
			last_middle = middle
			dense.append(all_points[i])
			halves.append(all_halves[i])
			sides.append(all_sides[i])
		var flags: Array[bool] = []
		for i in dense.size():
			var at := dense[i] + sides[i] * sign * (halves[i] + walk / 2.0)
			flags.append(contains(at.x, at.z) and at.z <= until_z
					and not _reaches_side(dense[i], sides[i] * sign, halves[i], at, others, walk / 2.0))
		var on := _long_runs(dense, flags, SEA_WALK_MIN_RUN)
		var tops := _walk_tops(dense, sides, halves, sign, walk, over)
		# The first and the last point of a run of the walk with a closed end
		# (below): the way of the people stays on the road there, and goes onto
		# the walk at the next point. A player that went onto the walk at the end
		# point climbed the curb beside the box of the closed end, and the step
		# up stopped on the box (PT-74, run 7: at the junction near Khách sạn Hải
		# Âu, 2 of 5 runs).
		var closed_ends := {}
		for i in dense.size():
			if on[i] and i > 0 and i < dense.size() - 1 and (not on[i - 1] or not on[i + 1]):
				closed_ends[i] = true
		# The way of the people (PT-74).
		for i in dense.size():
			# On the road, clear of the curb of the walk (the walk covers the sidewalk).
			var road := _on_ground(dense[i] + sides[i] * sign * (halves[i] - maxf(2.0, over + ROAD_INSIDE)))
			sea_road.append(road)
			if on[i] and not closed_ends.has(i):
				var middle := dense[i] + sides[i] * sign * (halves[i] + walk / 2.0)
				middle.y = tops[i]
				sea_walk.append(middle)
			else:
				sea_walk.append(road)
			sea_walk_on.append(1 if on[i] and not closed_ends.has(i) else 0)
		# The parts of each run of the walk.
		var i := 0
		while i < dense.size():
			if not on[i]:
				i += 1
				continue
			var first := i
			while i < dense.size() and on[i]:
				i += 1
			var last := i - 1
			var along := 0.0
			next_pillar = pillar_every / 2.0
			for k in range(first, last):
				var side0 := sides[k] * sign
				var side1 := sides[k + 1] * sign
				# The inner edge is 2 cm in front of the curb of the road, so that its
				# face hides the curb.
				var e0 := dense[k] + side0 * (halves[k] - over - (CURB_FRONT if over > 0.0 else 0.0))
				var e1 := dense[k + 1] + side1 * (halves[k + 1] - over - (CURB_FRONT if over > 0.0 else 0.0))
				e0.y = tops[k]
				e1.y = tops[k + 1]
				var o0 := dense[k] + side0 * (halves[k] + walk)
				var o1 := dense[k + 1] + side1 * (halves[k + 1] + walk)
				o0.y = tops[k]
				o1.y = tops[k + 1]
				# The face at the curb, from below the ground up to the walk.
				var face := maxf(tops[k] - world.ground_height(e0.x, e0.z), tops[k + 1] - world.ground_height(e1.x, e1.z)) + 0.1
				_wall(walk_color, e0 - Vector3(0, face, 0), e1 - Vector3(0, face, 0), face, -side0)
				_walk_edge("the walk of Hạ Long: the curb", e0, e1, -side0)
				var step := Vector2(e1.x - e0.x, e1.z - e0.z).length()
				_top_along(walk_color, e0, e1, o0, o1, along, along + step, e0.distance_to(o0))
				along += step
				_add_length("sea_walk_along", step)
				# The parapet at the outer edge of the walk.
				_box_along(parapet_color, o0 - side0 * 0.15, o1 - side1 * 0.15, 0.15, 0.0, parapet)
				if pieces:
					var p0 := o0 - side0 * inset
					var p1 := o1 - side1 * inset
					var cut := [0.0, 1.0]
					var kinds := [parapet_id]
					var start := along - step
					if next_pillar < along:
						var t0 := clampf((next_pillar - start) / maxf(step, 0.001), 0.0, 1.0)
						var t1 := clampf((next_pillar + pillar_length - start) / maxf(step, 0.001), 0.0, 1.0)
						cut = [0.0, t0, t1, 1.0]
						kinds = [parapet_id, pillar_id, parapet_id]
						next_pillar += pillar_every
					for n in kinds.size():
						if float(cut[n + 1]) - float(cut[n]) > 0.02:
							_wall_piece(kinds[n], p0.lerp(p1, cut[n]), p0.lerp(p1, cut[n + 1]), side0)
				if lamp_kind != "" and next_lamp < along:
					var t_lamp := clampf((next_lamp - (along - step)) / maxf(step, 0.001), 0.0, 1.0)
					var foot := (o0 - side0 * lamp_in).lerp(o1 - side1 * lamp_in, t_lamp)
					var lamp_along := (o1 - o0)
					lamp_along.y = 0.0
					_lamp(lamp_kind, _clear_of_openings(foot), lamp_along.normalized())
					next_lamp += lamp_every
				# The face of stone from the walk down to the ground, then over the ground to the sea.
				var g0 := o0 + side0 * width
				var g1 := o1 + side1 * width
				g0.y = minf(world.ground_height(g0.x, g0.z), o0.y) + 0.05
				g1.y = minf(world.ground_height(g1.x, g1.z), o1.y) + 0.05
				_slope(slope_color, o0, o1, g0, g1, side0)
				if slope_pieces:
					var drop := ((o0.y - g0.y) + (o1.y - g1.y)) / 2.0
					if drop > 0.1:
						# A small drop has a short run: the piece keeps its angle (with
						# the run of 8 m at a drop of 0.3 m the slope lay almost flat
						# over the beach).
						_wall_piece(slope_id, o0, o1, side0, drop / slope_height, minf(1.0, drop / slope_height))
						_add_length("sea_wall_pieces", 1.0)
				_add_length("sea_wall", e0.distance_to(e1))
			# A closed end where the walk stops at a junction: past the end of the
			# walk the ground falls to the beach (D-0026-01), so a player leaves the
			# walk only to the road. At the end of the line, the walk stays open.
			for end in [first, last]:
				if end == 0 or end == dense.size() - 1:
					continue
				var side := sides[end] * sign
				var e := dense[end] + side * (halves[end] - over)
				e.y = tops[end]
				var o := e + side * (walk + over)
				var inward := (dense[mini(end + 1, last)] - dense[end]).normalized() if end == first \
						else (dense[maxi(end - 1, first)] - dense[end]).normalized()
				_box_along(color, e + inward * 0.15, o + inward * 0.15, 0.15, -0.15, parapet)


## The ways of the sea wall as lines every STEP m, with the half width of the
## road at each point: [[PackedVector3Array, PackedFloat32Array], ...]. Ways that
## meet (an end within 1 m of the next start) are one line, and the width
## changes over WIDTH_BLEND m around the point where they meet.
func _sea_wall_lines(ids: Array[int]) -> Array:
	var pieces: Array = []
	var line := PackedVector3Array()
	var halves := PackedFloat32Array()
	for id in ids:
		var road: Dictionary = _roads.get(id, {})
		if road.is_empty():
			continue
		var points := _line(road)
		var half := float(road.width) / 2.0
		if line.size() > 0 and line[line.size() - 1].distance_to(points[0]) > 1.0:
			pieces.append([line, halves])
			line = PackedVector3Array()
			halves = PackedFloat32Array()
		for k in points.size():
			if k == 0 and line.size() > 0:
				continue
			line.append(points[k])
			halves.append(half)
	if line.size() >= 2:
		pieces.append([line, halves])
	var result: Array = []
	for piece: Array in pieces:
		var points: PackedVector3Array = piece[0]
		var widths: PackedFloat32Array = piece[1]
		var dense := PackedVector3Array()
		var dense_halves := PackedFloat32Array()
		for i in points.size() - 1:
			var count := maxi(1, ceili(points[i].distance_to(points[i + 1]) / STEP))
			for k in count:
				var t := float(k) / count
				dense.append(points[i].lerp(points[i + 1], t))
				dense_halves.append(lerpf(widths[i], widths[i + 1], t))
		dense.append(points[points.size() - 1])
		dense_halves.append(widths[widths.size() - 1])
		# The change of width over WIDTH_BLEND m (a mean over the points around).
		var reach := maxi(1, roundi(WIDTH_BLEND / 2.0 / STEP))
		var smooth := PackedFloat32Array()
		for i in dense.size():
			var total := 0.0
			var n := 0
			for k in range(maxi(0, i - reach), mini(dense.size(), i + reach + 1)):
				total += dense_halves[k]
				n += 1
			smooth.append(total / n)
		result.append([dense, smooth])
	return result


## For each flag, true when it is in a run of two flags or more that is not
## shorter than "min_length" m.
static func _long_runs(dense: PackedVector3Array, flags: Array[bool], min_length: float) -> Array[bool]:
	var result: Array[bool] = []
	result.resize(dense.size())
	var first := -1
	for i in dense.size() + 1:
		if i < dense.size() and flags[i]:
			if first < 0:
				first = i
			continue
		if first >= 0:
			var length := 0.0
			for k in range(first, i - 1):
				length += dense[k].distance_to(dense[k + 1])
			if i - first >= 2 and length >= min_length:
				for k in range(first, i):
					result[k] = true
			first = -1
	return result


## The height of the top of the walk at each point: 0.15 m over the ground at
## the curb, and over the ground under the walk, so that the ground does not
## come through it (report 0026, D-0026-04), then smoothed along the walk.
func _walk_tops(dense: PackedVector3Array, sides: PackedVector3Array, halves: PackedFloat32Array, sign: float, walk: float,
		over := 0.0) -> PackedFloat32Array:
	var raw := PackedFloat32Array()
	var last := dense.size() - 1
	for i in dense.size():
		var e := dense[i] + sides[i] * sign * (halves[i] - over)
		# The ground over the road (the height of the road at the same place
		# along the walk: on a road that climbs, the ground halfway to the next
		# point is higher by the climb, and the walk was 0.1 m too high).
		var high := world.ground_height(e.x, e.z) - dense[i].y
		# Across the walk, and halfway to the next point (the ground between the points).
		var next := dense[mini(i + 1, last)] + sides[mini(i + 1, last)] * sign * (halves[mini(i + 1, last)] - over)
		for t: float in [0.0, 0.5]:
			var base := e.lerp(next, t)
			var road_y := lerpf(dense[i].y, dense[mini(i + 1, last)].y, t)
			var k := 0.0
			while k <= walk + over + 0.01:
				var q := base + sides[i] * sign * minf(k, walk + over)
				high = maxf(high, world.ground_height(q.x, q.z) - road_y)
				k += 0.5
		# Over the sidewalk of the road (0.19 m over the road) where the walk covers
		# it, and over the ground under the walk (report 0026, D-0026-11: over the
		# highest ground across the walk, the walk was up to 0.35 m over the road
		# at its curb; the build of the geodata puts the ground under the walk
		# 0.03 m under this top).
		raw.append(dense[i].y + maxf(LIFT + RoadBuilder.CURB + (OVER_SIDEWALK_LIFT if over > 0.0 else 0.0),
				high + WALK_OVER_GROUND))
	# Smooth, but never lower than the point (report 0026, D-0026-04: where the
	# road falls 0.8 m in 4 m, the walk had a step): the grade is at most
	# WALK_GRADE, then the mean of the points around, a few times.
	var result := raw.duplicate()
	for pass_index in WALK_SMOOTH_PASSES:
		result = _limit_grade(dense, result, WALK_GRADE)
		for i in result.size():
			result[i] = minf(result[i], raw[i] + WALK_SMOOTH_MAX)
		var next := PackedFloat32Array()
		for i in result.size():
			var total := 0.0
			var n := 0
			for k in range(maxi(0, i - 2), mini(result.size(), i + 3)):
				total += result[k]
				n += 1
			next.append(clampf(total / n, raw[i], raw[i] + WALK_SMOOTH_MAX))
		result = next
	return result


## The values with the points raised so that the grade between two points of
## the line is at most "grade" (a value is never lowered).
static func _limit_grade(line: PackedVector3Array, values: PackedFloat32Array, grade: float) -> PackedFloat32Array:
	for i in range(1, values.size()):
		var run := Vector2(line[i].x - line[i - 1].x, line[i].z - line[i - 1].z).length()
		values[i] = maxf(values[i], values[i - 1] - grade * run)
	for i in range(values.size() - 2, -1, -1):
		var run := Vector2(line[i + 1].x - line[i].x, line[i + 1].z - line[i].z).length()
		values[i] = maxf(values[i], values[i + 1] - grade * run)
	return values


## R7: a stand-in for each building of OSM in the area: its outline and its storeys.
func _stand_ins(cfg: Dictionary) -> void:
	var parsed: Variant = JSON.parse_string(GeoData.read_text(BUILDINGS))
	if not parsed is Dictionary:
		return
	var storey := float(cfg.get("storey_m", 3.3))
	var color := str(cfg.get("color", "#c9c4b8"))
	var roof := str(cfg.get("roof_color", "#a89f90"))
	var skip: Array = cfg.get("skip", [])
	for building: Dictionary in parsed.get("buildings", []):
		var ring := _points(building.get("outline", []))
		if ring.size() < 3:
			continue
		if ring[0].distance_to(ring[ring.size() - 1]) < 0.01:
			ring.remove_at(ring.size() - 1)
		var center := Vector2.ZERO
		for p in ring:
			center += p
		center /= ring.size()
		var extra: bool = str(building.get("osm", "")) in (cfg.get("extra", []) as Array)
		if not (contains(center.x, center.y) or extra) or str(building.get("osm", "")) in skip \
				or _in_model(Vector3(center.x, 0, center.y)) or _covers_model(ring):
			continue
		var known: Dictionary = cfg.get("storeys", {}).get(str(building.get("osm", "")), {})
		# A building with no storeys from a source is left out: a guess is not in
		# the game (report 0026, Q6: a stand-in of 1 storey is not correct).
		if known.is_empty() and not building.has("levels") and not building.has("height"):
			stand_ins_left_out.append(str(building.get("osm", "")))
			continue
		var storeys := float(known.get("storeys", building.get("levels", 1)))
		var low := INF
		for p in ring:
			low = minf(low, world.ground_height(p.x, p.y))
		var height := float(known.get("height", building.get("height", storeys * storey)))
		var top := low + height
		for part in _jetty_passage(ring, int(cfg.get("jetty_access", 0))):
			_prism(color, roof, part, low - 0.5, top)
		# A pyramid roof over the walls (the hall with the roof of orange tiles).
		var roof_height := float(known.get("pyramid_roof", 0.0))
		if roof_height > 0.0:
			_pyramid(str(known.get("roof_color", roof)), ring, top, roof_height)
		stand_ins.append({"osm": str(building.get("osm", "")), "name": str(building.get("name", "")),
				"center": Vector3(center.x, low, center.y), "top": top + roof_height, "outline": ring,
				"storeys": storeys, "known": true})
	_footprint_stand_ins(cfg)
	_add_length("stand_ins", stand_ins.size())


## Report 0026, D-0026-03: OSM has no building on the side of the hill of Hạ Long
## between Cao ốc Sen Biển and Hải Âu. data/geo/build/footprints.json has the
## footprints of public data there (Overture Maps, tools/geo/footprints.py). A
## footprint is built as a stand-in only when "footprints" (by its id) gives its
## storeys from a photo; the others stay in footprints_check with the reason.
func _footprint_stand_ins(cfg: Dictionary) -> void:
	var known: Dictionary = cfg.get("footprints", {})
	if known.is_empty() or not GeoData.has_file(FOOTPRINTS):
		return
	var parsed: Variant = JSON.parse_string(GeoData.read_text(FOOTPRINTS))
	if not parsed is Dictionary:
		return
	var storey := float(cfg.get("storey_m", 3.3))
	for footprint: Dictionary in parsed.get("footprints", []):
		var entry: Dictionary = known.get(str(footprint.get("id", "")), {})
		if entry.is_empty():
			continue
		var ring := _points(footprint.get("outline", []))
		if ring.size() >= 2 and ring[0].distance_to(ring[ring.size() - 1]) < 0.01:
			ring.remove_at(ring.size() - 1)
		if ring.size() < 3:
			continue
		var low := INF
		var center := Vector2.ZERO
		for p in ring:
			low = minf(low, world.ground_height(p.x, p.y))
			center += p / ring.size()
		var top := low + float(entry.get("height", float(entry.get("storeys", 1)) * storey))
		_prism(str(cfg.get("color", "#c9c4b8")), str(entry.get("roof_color", cfg.get("roof_color", "#a89f90"))), ring, low - 0.5, top)
		stand_ins.append({"osm": "footprint/" + str(footprint.id), "name": str(entry.get("name", "")),
				"center": Vector3(center.x, low, center.y), "top": top, "outline": ring,
				"storeys": float(entry.get("storeys", 1)), "known": true})


## The outline of a stand-in less a passage along the deck of the jetty of
## Cầu Đá, and a passage from the shore end of the deck to the nearest point of
## the way "access" (the path of the port): OSM puts the old hydrofoil terminal
## around the land end of the old pier, and a solid stand-in there closed the
## jetty (PT-74). With the terminal at its height of the photo, the passage
## along the deck had no way in from the land (report 0026, D-0026-02). Holes
## are dropped.
func _jetty_passage(ring: PackedVector2Array, access := 0) -> Array[PackedVector2Array]:
	var parts: Array[PackedVector2Array] = [ring]
	if world.places == null or world.places.jetty.is_empty():
		return parts
	var line: PackedVector3Array = world.places.jetty.line
	var half := float(world.places.jetty.width) / 2.0 + PASSAGE_MARGIN
	var bands: Array[PackedVector2Array] = []
	for i in line.size() - 1:
		bands.append(_band(Vector2(line[i].x, line[i].z), Vector2(line[i + 1].x, line[i + 1].z), half))
	var way: Dictionary = _roads.get(access, {})
	if not way.is_empty() and line.size() > 1:
		# From a point behind the shore end (on the land) to the nearest point of the way.
		var shore := Vector2(line[0].x, line[0].z)
		var behind := shore + (shore - Vector2(line[1].x, line[1].z)).normalized() * JETTY_BEHIND
		var nearest := Vector2.INF
		for p: Array in way.get("points", []):
			var q := Vector2(float(p[0]), float(p[2]))
			if q.distance_to(behind) < nearest.distance_to(behind):
				nearest = q
		bands.append(_band(shore, behind, half))
		if nearest != Vector2.INF and nearest.distance_to(behind) > 0.5:
			bands.append(_band(behind, nearest, half))
	for band in bands:
		var next: Array[PackedVector2Array] = []
		for part in parts:
			if Geometry2D.intersect_polygons(part, band).is_empty():
				next.append(part)
				continue
			for piece: PackedVector2Array in Geometry2D.clip_polygons(part, band):
				if not Geometry2D.is_polygon_clockwise(piece):
					next.append(piece)
		parts = next
	return parts


## A band of the half width "half" from a to b, 1 m longer at each end.
func _band(a: Vector2, b: Vector2, half: float) -> PackedVector2Array:
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x) * half
	return PackedVector2Array([a - dir + n, b + dir + n, b + dir - n, a - dir - n])


## R7, D3: the models of World at their places, with the ranges of D6.
func _place_steps(path: String) -> void:
	if not GeoData.has_file(path):
		return
	var parsed: Variant = JSON.parse_string(GeoData.read_text(path))
	if not parsed is Dictionary:
		push_error("Showcase: cannot read %s." % path)
		return
	var ranges := {}
	for preset: String in parsed.get("ranges", {}):
		var r: Array = parsed.ranges[preset]
		ranges[preset] = Vector3(float(r[0]), float(r[1]), float(r[2]))
	_place_ranges = ranges
	for place: Dictionary in parsed.get("places", []):
		# A model with the status Check (data/world/drawings/) has its place, but
		# no order in data/world/orders.json: it waits, and its stand-in stays.
		# So does an order whose files wait for the job "Models of World".
		if _has_model(str(place.id)):
			_place_ids.append(str(place.id))
			_steps.append(_place.bind(place, ranges))


## One model of World at its place: one step of the build, because the load
## of a large model takes some time.
func _place(place: Dictionary, ranges: Dictionary) -> void:
	if not _forced and not WorldModel.is_loaded(str(place.id), ranges):
		_waiting = true
		return
	# Report 0026, Q24: with the ranges of the place, a level that the preset
	# does not show (the near level on Low, D6) is not loaded.
	var model := WorldModel.make(str(place.id), WorldMaterials.DEFAULT_PAINT, "", ranges)
	if model == null:
		return
	var facing := Vector2(float(place.facing[0]), float(place.facing[1])).normalized()
	var front := Vector3(float(place.front[0]), 0.0, float(place.front[1]))
	var basis := Basis(Vector3.UP, atan2(facing.x, facing.y))
	front.y = world.ground_height(front.x, front.z)
	model.transform = Transform3D(basis, front - basis * Vector3(float(place.get("front_middle_x", 0.0)), 0, 0))
	add_child(model)
	model.apply_ranges()
	var box := _model_box(model)
	var footprint := PackedVector2Array()
	for corner: Vector3 in [Vector3(box.position.x, 0, box.position.z), Vector3(box.end.x, 0, box.position.z),
			Vector3(box.end.x, 0, box.end.z), Vector3(box.position.x, 0, box.end.z)]:
		var p := model.transform * corner
		footprint.append(Vector2(p.x, p.z))
	models.append({"id": str(place.id), "model": model, "footprint": footprint, "base": front.y, "box": box})
	# A building stops the player: a box from its back to its front line (the
	# canopy over the sidewalk does not stop the player; report 0026, D-0026-11).
	if box.size.y > MODEL_BODY_MIN_HEIGHT and box.position.z < 0.0:
		var body := StaticBody3D.new()
		body.name = "Body_" + str(place.id)
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		var depth := minf(0.0, box.end.z) - box.position.z
		cube.size = Vector3(box.size.x, box.size.y, depth)
		shape.shape = cube
		shape.position = Vector3(box.get_center().x, box.get_center().y, box.position.z + depth / 2.0)
		body.add_child(shape)
		model.add_child(body)


## R5: the basket boats on the sand above the water line.
func _beached(cfg: Dictionary) -> void:
	# A long boat (length_m) lies along the slope of the sand: the line from its
	# stern to its bow follows the ground, and it sinks sink_m into the sand.
	var length := float(cfg.get("length_m", 0.0))
	for point: Array in cfg.get("points", []):
		var p := Vector3(float(point[0]), 0.0, float(point[1]))
		p.y = world.ground_height(p.x, p.z)
		if p.y < float(cfg.get("min_ground", 1.6)):
			push_warning("Showcase: the boat at (%.0f, %.0f) is under the water line (%.2f m)." % [p.x, p.z, p.y])
			continue
		var boat := WorldModel.make(str(cfg.model), WorldMaterials.DEFAULT_PAINT, str(cfg.get("material_set", "")))
		if boat == null:
			return
		var basis := Basis(Vector3.UP, deg_to_rad(float(point[2])))
		if length > 0.0:
			# The bow of the boat of World is to +z (its eyes, PT-75 screenshots).
			var ahead := basis * Vector3(0.0, 0.0, length * 0.5)
			var bow := world.ground_height(p.x + ahead.x, p.z + ahead.z)
			var stern := world.ground_height(p.x - ahead.x, p.z - ahead.z)
			basis = basis * Basis(Vector3.RIGHT, atan2(bow - stern, length))
			p.y = minf(p.y, (bow + stern) * 0.5) - float(cfg.get("sink_m", 0.0))
			beached_boats.append({"at": p, "along": Vector3(ahead.x, 0.0, ahead.z).normalized(), "half": length * 0.5})
		boat.transform = Transform3D(basis, p)
		add_child(boat)
		# The far level casts no shadow (report 0026, PT-73: the shadow pass doubles its triangles).
		var far := boat.level("far")
		if far != null:
			for node in far.find_children("*", "GeometryInstance3D", true, false):
				(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_length("beached", 1.0)


## The box of the mid level of a model, in the frame of the model.
static func _model_box(model: WorldModel) -> AABB:
	var level := model.level("mid")
	if level == null:
		level = model.level("far")
	var box := AABB()
	var first := true
	for node in level.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var t := Transform3D()
		var c: Node = mesh_node
		while c != null and c != model:
			if c is Node3D:
				t = (c as Node3D).transform * t
			c = c.get_parent()
		var b := t * mesh_node.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## True when the point (x, z) is under a model of World.
func _in_model(p: Vector3) -> bool:
	for entry: Dictionary in models:
		if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), entry.footprint):
			return true
	return false


## True when an outline of OSM goes around the middle of a model of World: the
## outline is the same building as the model, or a group of buildings with it
## (report 0026, D-0026-02: an outline of OSM around the whole Grand Hotel made a
## box in front of the model).
func _covers_model(ring: PackedVector2Array) -> bool:
	for entry: Dictionary in models:
		var footprint: PackedVector2Array = entry.footprint
		var middle := Vector2.ZERO
		for p in footprint:
			middle += p
		if Geometry2D.is_point_in_polygon(middle / maxf(footprint.size(), 1.0), ring):
			return true
	return false


# --- Geometry -----------------------------------------------------------------

func _points(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p: Array in values:
		result.append(Vector2(float(p[0]), float(p[1])))
	return result


func _line(road: Dictionary) -> PackedVector3Array:
	var result := PackedVector3Array()
	for p: Array in road.points:
		result.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	return result


## The points of the line, with at most "step" meters between two of them.
func _dense(line: PackedVector3Array, step: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in line.size() - 1:
		var count := maxi(1, ceili(line[i].distance_to(line[i + 1]) / step))
		for k in count:
			result.append(line[i].lerp(line[i + 1], float(k) / count))
	if line.size() > 0:
		result.append(line[line.size() - 1])
	return result


## Points along the line, "every" m, the first "from_end" m from its start and
## none nearer than from_end to its end: [point, the direction of the line].
static func _every(line: PackedVector3Array, every: float, from_end: float) -> Array:
	var result := []
	if every <= 0.0 or line.size() < 2:
		return result
	var total := 0.0
	for i in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	var at := from_end
	var along := 0.0
	for i in line.size() - 1:
		var length := line[i].distance_to(line[i + 1])
		while at <= along + length and at <= total - from_end:
			var t := (at - along) / maxf(length, 0.001)
			result.append([line[i].lerp(line[i + 1], t), (line[i + 1] - line[i]).normalized()])
			at += every
		along += length
	return result


## The unit vector to the right side of the line at each point (as RoadBuilder).
static func _sides(line: PackedVector3Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	result.resize(line.size())
	for i in line.size():
		var before := line[maxi(i - 1, 0)]
		var after := line[mini(i + 1, line.size() - 1)]
		var forward := Vector3(after.x - before.x, 0, after.z - before.z).normalized()
		result[i] = Vector3(-forward.z, 0, forward.x)
	return result


## The parts of the dense line where keep(point, right side) is true.
func _runs(line: PackedVector3Array, keep: Callable) -> Array[PackedVector3Array]:
	var dense := _dense(line, STEP)
	var sides := _sides(dense)
	var result: Array[PackedVector3Array] = []
	var current := PackedVector3Array()
	for i in dense.size():
		if keep.call(dense[i], sides[i]):
			current.append(dense[i])
		else:
			if current.size() >= 2:
				result.append(current)
			current = PackedVector3Array()
	if current.size() >= 2:
		result.append(current)
	return result


func _length(line: PackedVector3Array) -> float:
	var result := 0.0
	for i in line.size() - 1:
		result += line[i].distance_to(line[i + 1])
	return result


func _nearest(line: PackedVector3Array, p: Vector3) -> Vector3:
	var best := line[0]
	var best_d := INF
	for i in line.size() - 1:
		var q := Geometry3D.get_closest_point_to_segment(p, line[i], line[i + 1])
		var d := Vector2(q.x - p.x, q.z - p.z).length()
		if d < best_d:
			best_d = d
			best = q
	return best


## The roads near the area that are not in "ids": [[line, half width, box]].
## The roads near the area are found one time (report 0026, D-0026-12).
func _other_roads(ids: Array, skip_types: Array = []) -> Array:
	if not _near_roads_read:
		_near_roads_read = true
		for id: int in _roads:
			var road: Dictionary = _roads[id]
			var line := _line(road)
			var near := false
			for p in line:
				if contains(p.x, p.z):
					near = true
					break
			if near:
				var box := Rect2(Vector2(line[0].x, line[0].z), Vector2.ZERO)
				for p in line:
					box = box.expand(Vector2(p.x, p.z))
				_near_roads.append([id, str(road.get("type", "")), line, float(road.width) / 2.0,
						box.grow(float(road.width) / 2.0 + 12.0)])
	var result := []
	for entry: Array in _near_roads:
		if entry[0] in ids or entry[1] in skip_types:
			continue
		result.append([entry[2], entry[3], entry[4]])
	return result


## True when another road is within "extra" m (and the margin) of the point
## "at" and goes past the edge (half) of the road at "p" on the side "side"
## (a junction on that side).
func _reaches_side(p: Vector3, side: Vector3, half: float, at: Vector3, others: Array, extra: float) -> bool:
	for entry: Array in others:
		if not (entry[2] as Rect2).has_point(Vector2(at.x, at.z)):
			continue
		var line: PackedVector3Array = entry[0]
		for i in line.size() - 1:
			var q := Geometry3D.get_closest_point_to_segment(at, line[i], line[i + 1])
			if Vector2(q.x - at.x, q.z - at.z).length() < float(entry[1]) + extra + JUNCTION_MARGIN \
					and Vector2(q.x - p.x, q.z - p.z).dot(Vector2(side.x, side.z)) > half - 0.5:
				return true
	return false


## True when a point is within "extra" m (and the margin) of the edge of another road.
func _near_other(p: Vector3, others: Array, extra: float) -> bool:
	for entry: Array in others:
		if not (entry[2] as Rect2).has_point(Vector2(p.x, p.z)):
			continue
		var line: PackedVector3Array = entry[0]
		for i in line.size() - 1:
			var q := Geometry3D.get_closest_point_to_segment(p, line[i], line[i + 1])
			if Vector2(q.x - p.x, q.z - p.z).length() < float(entry[1]) + extra + JUNCTION_MARGIN:
				return true
	return false


## An edge of a part that a player walks on (see walk_edges).
func _walk_edge(kind: String, a: Vector3, b: Vector3, out: Vector3) -> void:
	walk_edges.append({"kind": kind, "a": a, "b": b, "out": Vector3(out.x, 0.0, out.z).normalized()})


## R9: trees of plan 0020 at the points, in the tree field of the world (its
## own source, so a change of the showcase does not touch the other trees).
func _add_trees(type: String, points: Array[Vector3], kind: String) -> void:
	if world.trees == null:
		return
	var transforms: Array[Transform3D] = []
	for p in points:
		var seed := hash(Vector2i(roundi(p.x * 4.0), roundi(p.z * 4.0)))
		var size := 0.85 + 0.3 * float(posmod(seed, 1000)) / 1000.0
		var turn := TAU * float(posmod(seed / 1000, 1000)) / 1000.0
		transforms.append(Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * size), p))
	world.trees.add_trees(TREE_SOURCE, type, transforms, true)
	world.trees.commit_far_tiles()
	_add_length(kind, transforms.size())


func _add_length(kind: String, value: float) -> void:
	lengths[kind] = float(lengths.get(kind, 0.0)) + value


# --- The meshes ---------------------------------------------------------------

func _mesh(color: String) -> _Mesh:
	if not _meshes.has(color):
		_meshes[color] = _Mesh.new()
	return _meshes[color]


## A pyramid roof on a ring at the height "base", with its top "height" m over
## the middle of the ring.
func _pyramid(color: String, ring: PackedVector2Array, base: float, height: float) -> void:
	var middle := Vector2.ZERO
	for p in ring:
		middle += p
	middle /= maxf(ring.size(), 1.0)
	var apex := Vector3(middle.x, base + height, middle.y)
	for i in ring.size():
		var a := Vector3(ring[i].x, base, ring[i].y)
		var b := Vector3(ring[(i + 1) % ring.size()].x, base, ring[(i + 1) % ring.size()].y)
		var normal := (b - a).cross(apex - a).normalized()
		if normal.y < 0.0:
			normal = -normal
		_mesh(color).triangle(a, b, apex, normal)
		_collision.append_array([a, b, apex])


## A face that looks up: the corners a0, a1 along one edge, b0, b1 along the other.
func _top(color: String, a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> void:
	_mesh(color).quad(a0, a1, b1, b0, Vector3.UP)
	_collision.append_array([a0, a1, b1, a0, b1, b0])


## A face that looks up, with its texture along the line a0 to a1 (report 0026,
## D-0026-04): v0 and v1 are the distances (m) of a0 and a1 along the line, and
## "across" the distance (m) from the edge a to the edge b.
func _top_along(color: String, a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3, v0: float, v1: float, across: float) -> void:
	_mesh(color).quad(a0, a1, b1, b0, Vector3.UP,
			PackedVector2Array([Vector2(0.0, v0), Vector2(0.0, v1), Vector2(across, v1), Vector2(across, v0)]))
	_collision.append_array([a0, a1, b1, a0, b1, b0])


## A vertical face from the line a to b, "height" m high, that looks to "normal".
func _wall(color: String, a: Vector3, b: Vector3, height: float, normal: Vector3) -> void:
	var up := Vector3(0, height, 0)
	_mesh(color).quad(a, b, b + up, a + up, normal.normalized())
	_collision.append_array([a, b, b + up, a, b + up, a + up])


## A face from the top edge (a0, a1) down to the low edge (g0, g1), that looks to "out" and up.
func _slope(color: String, a0: Vector3, a1: Vector3, g0: Vector3, g1: Vector3, out: Vector3) -> void:
	var normal := (a1 - a0).cross(g0 - a0).normalized()
	if normal.dot(out + Vector3.UP) < 0.0:
		normal = -normal
	_mesh(color).quad(a0, a1, g1, g0, normal)
	_collision.append_array([a0, a1, g1, a0, g1, g0])


## A box along a segment: "half" m to each side of it, from "low" to "high" m over its points.
func _box_along(color: String, p0: Vector3, p1: Vector3, half: float, low: float, high: float) -> void:
	var forward := Vector3(p1.x - p0.x, 0, p1.z - p0.z)
	if forward.length() < 0.01:
		return
	forward = forward.normalized()
	var side := Vector3(-forward.z, 0, forward.x) * half
	var lo := Vector3(0, low, 0)
	var hi := Vector3(0, high, 0)
	_top(color, p0 - side + hi, p1 - side + hi, p0 + side + hi, p1 + side + hi)
	_wall(color, p0 - side + lo, p1 - side + lo, high - low, -side)
	_wall(color, p0 + side + lo, p1 + side + lo, high - low, side)
	_wall(color, p0 - side + lo, p0 + side + lo, high - low, -forward)
	_wall(color, p1 - side + lo, p1 + side + lo, high - low, forward)


## A low ridge (a border or a wall) along a line, at the offset to the right side.
## With "chunk_m", each segment goes to the mesh of its square of chunk_m
## (the color, "|", and the square), which shows to the end of "far_m" of its part.
func _ridge(color: String, line: PackedVector3Array, offset: float, width: float, height: float, chunk_m := 0.0) -> void:
	var sides := _sides(line)
	for i in line.size() - 1:
		var a := line[i] + sides[i] * offset + Vector3(0, LIFT, 0)
		var b := line[i + 1] + sides[i + 1] * offset + Vector3(0, LIFT, 0)
		var key := color
		if chunk_m > 0.0:
			var mid := (a + b) / 2.0
			key = "%s|%d_%d" % [color, floori(mid.x / chunk_m), floori(mid.z / chunk_m)]
		_box_along(key, a, b, width / 2.0, 0.0, height)


## A tube from a to b with "sides" faces, radius r0 at a and r1 at b (a pole,
## an arm). A solid tube is in the collision.
func _tube(color: String, a: Vector3, b: Vector3, r0: float, r1: float, sides := 6, solid := false) -> void:
	var axis := (b - a).normalized()
	var ref := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var u := axis.cross(ref).normalized()
	var v := axis.cross(u).normalized()
	for k in sides:
		var t0 := TAU * float(k) / sides
		var t1 := TAU * float(k + 1) / sides
		var d0 := u * cos(t0) + v * sin(t0)
		var d1 := u * cos(t1) + v * sin(t1)
		var corners := [a + d0 * r0, a + d1 * r0, b + d1 * r1, b + d0 * r1]
		_mesh(color).quad(corners[0], corners[1], corners[2], corners[3], (d0 + d1).normalized())
		if solid:
			_collision.append_array([corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]])


## A ball of the radius at the point (a globe of a lamp): rings of quads.
func _ball(color: String, center: Vector3, radius: float, rings := 4, segments := 6) -> void:
	for i in rings:
		var a0 := PI * float(i) / rings - PI / 2.0
		var a1 := PI * float(i + 1) / rings - PI / 2.0
		for j in segments:
			var b0 := TAU * float(j) / segments
			var b1 := TAU * float(j + 1) / segments
			var p := [Vector3(cos(a0) * cos(b0), sin(a0), cos(a0) * sin(b0)), Vector3(cos(a0) * cos(b1), sin(a0), cos(a0) * sin(b1)),
					Vector3(cos(a1) * cos(b1), sin(a1), cos(a1) * sin(b1)), Vector3(cos(a1) * cos(b0), sin(a1), cos(a1) * sin(b0))]
			var normal: Vector3 = (p[0] + p[1] + p[2] + p[3]).normalized()
			_mesh(color).quad(center + p[0] * radius, center + p[1] * radius, center + p[2] * radius, center + p[3] * radius, normal)


## R9: a row of lamps at one side of a way, "offset_m" past its edge, in the area.
func _lamp_row(cfg: Dictionary) -> void:
	var road: Dictionary = _roads.get(int(cfg.get("way", 0)), {})
	if road.is_empty():
		push_warning("Showcase: the lamp row of way %s finds no road." % cfg.get("way"))
		return
	var sign := 1.0 if str(cfg.get("side", "right")) == "right" else -1.0
	var offset := sign * (float(road.width) / 2.0 + float(cfg.get("offset_m", 0.6)))
	var others := _other_roads([int(road.id)])
	for run: PackedVector3Array in _runs(_line(road), func(p: Vector3, side: Vector3) -> bool:
			var at := p + side * offset
			return contains(at.x, at.z) and not _in_model(at) and not _near_other(at, others, 1.0)):
		var sides := _sides(run)
		var line := PackedVector3Array()
		for i in run.size():
			line.append(run[i] + sides[i] * offset)
		for at: Array in _every(line, float(cfg.get("every_m", 30.0)), float(cfg.get("from_end_m", 8.0))):
			# A model with a long arm turns it to its right side: over the way
			# when the lamp is at the left of the way.
			var along: Vector3 = at[1]
			if bool(cfg.get("long_arm_over_way", false)) and sign > 0.0:
				along = -along
			_lamp(str(cfg.get("kind", "")), _clear_of_openings(at[0]), along)


## Report 0026, D-0026-33: a pole of a row of lamps stands at least
## OPENING_CLEAR_M from the side of an opening of the low wall (a blue pole
## stood at the top of the steps of two openings). A point near an opening
## moves along the wall to the nearer side, OPENING_CLEAR_M past it.
const OPENING_CLEAR_M := 1.5
## A pole nearer than this to the line of the wall is a pole of the wall (m).
const OPENING_NEAR_M := 3.0


func _clear_of_openings(p: Vector3) -> Vector3:
	for opening: Dictionary in wall_openings:
		var along: Vector3 = opening.along
		along.y = 0.0
		along = along.normalized()
		var offset: Vector3 = p - opening.at
		offset.y = 0.0
		var side := offset.dot(along)
		var across := (offset - along * side).length()
		# 0.2 m more: the wall bends, and the pole is on the ground of the side.
		var clear := float(opening.get("half", 1.35)) + OPENING_CLEAR_M + 0.2
		if across <= OPENING_NEAR_M and absf(side) < clear:
			var moved := p + along * ((clear if side >= 0.0 else -clear) - side)
			moved.y = world.ground_height(moved.x, moved.z)
			return moved
	return p


## R9: the low lamps along the paths of the park, at alternate sides.
func _path_lamps(cfg: Dictionary) -> void:
	var types: Array = cfg.get("types", ["footway"])
	var every := float(cfg.get("every_m", 14.0))
	var count := 0
	for id: int in _roads:
		var road: Dictionary = _roads[id]
		if not str(road.type) in types:
			continue
		var half := float(road.width) / 2.0 + float(cfg.get("offset_m", 0.5))
		var line := _line(road)
		var sides := _sides(line)
		var k := 0
		for at: Array in _every(line, every, float(cfg.get("from_end_m", 3.0))):
			var point: Vector3 = at[0]
			var dir: Vector3 = at[1]
			var side := Vector3(-dir.z, 0, dir.x).normalized() * (1.0 if k % 2 == 0 else -1.0)
			k += 1
			var p := point + side * half
			if park.size() < 3 or not Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), park) or _in_model(p):
				continue
			_lamp(str(cfg.get("kind", "path_lamp")), p, dir)
			path_lamp_points.append(p)
			count += 1
	_add_length("path_lamps", count)


## Report 0026, D-0026-17 (Q19): the park of the photos of 2014 to 2021. Low
## clipped hedges at the edge of the lawns along the paths, with a gap at each
## low lamp, at each bench, and at each junction; a group of round clipped
## bushes behind the hedge at some corners where paths meet; round flower beds
## on the lawn behind long hedges; and granite benches in gaps of the hedges,
## to the path. Each plant is on the lawn of the ground mask, in the park, and
## away from the trunks of the trees.
func _park_plants(cfg: Dictionary) -> void:
	if park.size() < 3:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 26))
	var hedge: Dictionary = cfg.get("hedges", {})
	var border := float(data.get("path_borders", {}).get("width", 0.16))
	var types: Array = hedge.get("types", ["footway"])
	var park_box := Rect2(park[0], Vector2.ZERO)
	for q in park:
		park_box = park_box.expand(q)
	var lines: Array[PackedVector3Array] = []
	for id: int in _roads:
		var road: Dictionary = _roads[id]
		if not str(road.type) in types:
			continue
		var line := _line(road)
		var in_box := false
		for q in line:
			in_box = in_box or park_box.has_point(Vector2(q.x, q.z))
		if not in_box:
			continue
		var offset := float(road.width) / 2.0 + border + float(hedge.get("offset_m", 0.3))
		var others := _other_roads([id])
		var gap := float(hedge.get("junction_gap_m", 1.5))
		for sign: float in [-1.0, 1.0]:
			for run: PackedVector3Array in _runs(line, func(q: Vector3, side: Vector3) -> bool:
					var at := q + side * sign * offset
					return Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), park) and _lawn(at) \
							and not _near_other(at, others, gap) and not _in_model(at)):
				var sides := _sides(run)
				var shifted := PackedVector3Array()
				for i in run.size():
					shifted.append(_on_ground(run[i] + sides[i] * sign * offset))
				# The lawn side of the hedge.
				var lawn := sides[shifted.size() / 2] * sign
				if _length(shifted) >= float(hedge.get("min_run_m", 4.0)):
					lines.append(shifted)
					_hedge_line(cfg, shifted, lawn, rng)


## True when the ground mask of the park has lawn at the point.
func _lawn(p: Vector3) -> bool:
	return ground_at(p.x, p.z).r > 0.5


## True when the trunk of a tree is nearer than "radius" m to the point.
func _in_tree(p: Vector3, radius: float) -> bool:
	return world.trees != null and not world.trees.all_trees_near(p, radius).is_empty()


## The pieces of one hedge, the benches in its gaps, the group of bushes at its
## two ends, and a flower bed behind its middle.
func _hedge_line(cfg: Dictionary, line: PackedVector3Array, lawn: Vector3, rng: RandomNumberGenerator) -> void:
	var hedge: Dictionary = cfg.get("hedges", {})
	var bench: Dictionary = cfg.get("benches", {})
	var model := str(hedge.get("model", ""))
	var piece := float(_option(model, "length", 2.0))
	var total := _length(line)
	# The gaps: [from, to] along the line.
	var gaps: Array[Vector2] = []
	var lamp_gap := float(hedge.get("lamp_gap_m", 0.35))
	for lamp in path_lamp_points:
		var q := _nearest(line, lamp)
		if Vector2(q.x - lamp.x, q.z - lamp.z).length() < 1.0:
			var s := _distance_along(line, q)
			gaps.append(Vector2(s - lamp_gap, s + lamp_gap))
	var benches: Array[float] = []
	var bench_model := str(bench.get("model", ""))
	if _has_model(bench_model):
		var length := float(_option(bench_model, "length", 1.2))
		var every := float(bench.get("every_m", 24.0))
		var s := every * 0.5
		while s < total - every * 0.25:
			var free := true
			for g in gaps:
				free = free and (s + length < g.x - 0.2 or s - length > g.y + 0.2)
			if free:
				benches.append(s)
				gaps.append(Vector2(s - length * 0.5 - 0.2, s + length * 0.5 + 0.2))
			s += every
	gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	if _has_model(model):
		for span: Vector2 in _less_gaps(0.0, total, gaps):
			var count := maxi(roundi((span.y - span.x) / piece), 1)
			if span.y - span.x < piece * 0.4:
				continue
			var step := (span.y - span.x) / count
			for k in count:
				var a := _along_line(line, span.x + step * k)
				var b := _along_line(line, span.x + step * (k + 1))
				_row_piece(model, a, b, lawn)
				_add_length("hedge", a.distance_to(b))
	for s in benches:
		var at := _along_line(line, s)
		var along := (_along_line(line, s + 0.5) - _along_line(line, s - 0.5)).normalized()
		# The bench looks to the path: its front (+z of the GLB) away from the lawn.
		var basis := Basis(Vector3.UP, atan2(-lawn.x, -lawn.z))
		_row_add(bench_model, Transform3D(basis, at))
		park_plants.append({"kind": "bench", "at": at, "radius": 0.6, "along": along})
	# The round bushes at the corners.
	var bushes: Dictionary = cfg.get("bushes", {})
	if _has_model(str(bushes.get("model", ""))):
		for end: float in [1.0, total - 1.0]:
			if rng.randf() < float(bushes.get("part", 0.5)):
				var corner := _along_line(line, clampf(end + (2.0 if end < total * 0.5 else -2.0), 0.0, total))
				_bush_group(bushes, corner + lawn * float(bushes.get("behind_m", 1.8)), lawn, rng)
	# A flower bed behind the middle of a long hedge.
	var beds: Dictionary = cfg.get("flower_beds", {})
	if _has_model(str(beds.get("model", ""))) and total >= float(beds.get("min_run_m", 30.0)) \
			and rng.randf() < float(beds.get("part", 0.5)):
		var radius := rng.randf_range(float(beds.radius_m[0]), float(beds.radius_m[1]))
		_flower_bed(beds, _along_line(line, total * 0.5) + lawn * (float(beds.get("behind_m", 2.0)) + radius), radius)


## A group of 3 to 5 round bushes, the tallest at the back.
func _bush_group(cfg: Dictionary, center: Vector3, lawn: Vector3, rng: RandomNumberGenerator) -> void:
	var model := str(cfg.model)
	var count := rng.randi_range(int(cfg.get("count", [3, 5])[0]), int(cfg.get("count", [3, 5])[1]))
	var width := float(_option(model, "width", 1.4))
	var placed := 0
	for k in count:
		var a := TAU * k / count + rng.randf_range(-0.3, 0.3)
		var r := 0.0 if k == 0 else width * 0.55
		var p := _on_ground(center + Vector3(cos(a), 0.0, sin(a)) * r)
		if not _lawn(p) or _in_tree(p, width * 0.6 + 0.3) or _in_model(p) \
				or not Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), park):
			continue
		# The bush at the back (on the lawn side) is the tall one.
		var back := Vector2(p.x - center.x, p.z - center.z).dot(Vector2(lawn.x, lawn.z)) > 0.2
		var scale := rng.randf_range(1.25, 1.5) if back and placed == 0 else rng.randf_range(0.85, 1.05)
		_row_add(model, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale), p - Vector3(0, 0.03, 0)))
		park_plants.append({"kind": "bush", "at": p, "radius": width * 0.5 * scale})
		placed += 1
	if placed > 0:
		_add_length("bush_groups", 1.0)


## A round flower bed: a granite border and the flowers inside it.
func _flower_bed(cfg: Dictionary, center: Vector3, radius: float) -> void:
	var model := str(cfg.model)
	for k in 12:
		var a := TAU * k / 12.0
		var p := center + Vector3(cos(a), 0.0, sin(a)) * radius
		if not _lawn(p) or _in_model(p) or not Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), park):
			return
	if not _lawn(center) or _in_tree(center, radius + 0.4):
		return
	var ring := PackedVector3Array()
	for k in 33:
		var a := TAU * k / 32.0
		ring.append(_on_ground(center + Vector3(cos(a), 0.0, sin(a)) * radius))
	var border: Dictionary = data.get("path_borders", {})
	_ridge(str(border.get("color", "#8f8c86")), ring, 0.0, float(cfg.get("border_m", 0.16)), float(cfg.get("border_height_m", 0.12)))
	# Larger clumps, fewer of them: each clump is 400 triangles at the mid level.
	var grow := float(cfg.get("clump_scale", 1.0))
	var clump := float(_option(model, "width", 0.4)) * grow * float(cfg.get("spacing", 0.9))
	var row := 0
	var z := -radius
	while z <= radius:
		var x := -radius + (clump * 0.5 if row % 2 == 1 else 0.0)
		while x <= radius:
			if Vector2(x, z).length() <= radius - clump * 0.5:
				var p := _on_ground(center + Vector3(x, 0.0, z))
				_row_add(model, Transform3D(Basis(Vector3.UP, fposmod(x * 7.3 + z * 3.1, TAU)).scaled(Vector3.ONE * grow), p))
			x += clump
		z += clump * 0.866
		row += 1
	park_plants.append({"kind": "flower_bed", "at": center, "radius": radius})
	_add_length("flower_beds", 1.0)


## The distance along the line to its point nearest to p.
func _distance_along(line: PackedVector3Array, p: Vector3) -> float:
	var best := 0.0
	var best_d := INF
	var along := 0.0
	for i in line.size() - 1:
		var q := Geometry3D.get_closest_point_to_segment(p, line[i], line[i + 1])
		var d := q.distance_to(p)
		if d < best_d:
			best_d = d
			best = along + line[i].distance_to(q)
		along += line[i].distance_to(line[i + 1])
	return best


## A model in the row of the park.
func _row_add(model_id: String, at: Transform3D) -> void:
	if park_row == null:
		park_row = WorldRow.new()
		park_row.name = "ParkPlants"
		var cfg: Dictionary = data.get("park_plants", {})
		park_row.cell_size = float(cfg.get("cell_m", WorldRow.CELL))
		for preset: String in cfg.get("ranges", {}):
			var r: Array = cfg.ranges[preset]
			park_row.custom_ranges[preset] = Vector3(float(r[0]), float(r[1]), float(r[2]))
		add_child(park_row)
	park_row.add(model_id, at)


## A piece along a line (a hedge) in the row of the park: as _wall_piece.
func _row_piece(model_id: String, a: Vector3, b: Vector3, side: Vector3) -> void:
	var length := float(_option(model_id, "length", 2.0))
	if a.distance_to(b) < 0.05:
		return
	var flat := Vector3(side.x, 0.0, side.z).normalized()
	var basis := Basis(-(b - a) / length, Vector3.UP, flat)
	if basis.determinant() < 0.0:
		basis.x = -basis.x
	_row_add(model_id, Transform3D(basis, (a + b) / 2.0))


## R9: a stand-in lamp of the kind of "lamp_kinds" at the point (its base),
## its arms across the direction "along" (the direction of the road).
func _lamp(kind: String, at: Vector3, along: Vector3) -> void:
	var cfg: Dictionary = data.get("lamp_kinds", {}).get(kind, {})
	if cfg.is_empty():
		push_warning("Showcase: no lamp kind %s." % kind)
		return
	var base := at
	base.y = maxf(at.y, world.ground_height(at.x, at.z))
	var model_id := str(cfg.get("model", ""))
	# A model whose files wait for the job "Models of World" keeps its stand-in.
	if model_id != "" and _has_model(model_id):
		_world_lamp(kind, model_id, cfg, base, along)
		return
	var h := float(cfg.get("height", 8.0))
	var pole := str(cfg.get("pole_color", "#7fb3cf"))
	var top := base + Vector3(0, h, 0)
	_tube(pole, base, top, float(cfg.get("base_radius", 0.12)), float(cfg.get("top_radius", 0.06)), 6, true)
	var flat := Vector3(along.x, 0, along.z)
	var side := Vector3(-flat.z, 0, flat.x).normalized() if flat.length() > 0.01 else Vector3.RIGHT
	var head := str(cfg.get("head_color", "#ecebe6"))
	match str(cfg.get("shape", "arms")):
		"arms":
			# Curved arms: up and out from under the top, a head at each end.
			var length := float(cfg.get("arm_length", 1.5))
			var rise := float(cfg.get("arm_rise", 0.6))
			var start := top - Vector3(0, 0.3, 0)
			var arms := int(cfg.get("arms", 2))
			for k in arms:
				var out := side * (1.0 if k == 0 else -1.0)
				var bend := start + out * length * 0.45 + Vector3(0, rise * 0.75, 0)
				var end := start + out * length + Vector3(0, rise, 0)
				_tube(pole, start, bend, 0.04, 0.035, 5)
				_tube(pole, bend, end, 0.035, 0.03, 5)
				var size: Array = cfg.get("head", [0.55, 0.12, 0.24])
				_box_along(head, end - out * float(size[0]) * 0.2, end + out * float(size[0]) * 0.8,
						float(size[2]) / 2.0, -float(size[1]), 0.0)
		"globes":
			# Globes on short arms round the top, and one on the top.
			var count := int(cfg.get("globes", 4))
			var radius := float(cfg.get("globe_radius", 0.18))
			var reach := float(cfg.get("arm_length", 0.45))
			var ring := top - Vector3(0, 0.35, 0)
			for k in count:
				var out := side.rotated(Vector3.UP, TAU * float(k) / count)
				_tube(pole, ring, ring + out * reach + Vector3(0, 0.1, 0), 0.025, 0.025, 4)
				_ball(head, ring + out * reach + Vector3(0, 0.1 + radius, 0), radius)
			_ball(head, top + Vector3(0, radius, 0), radius)
		"box_lamp":
			# A low square lamp (the stand-in of den_vuon_thap): a body of frosted panes
			# (the head color: it glows at night) under a wider cap (the pole color).
			var body := float(cfg.get("body", 0.32)) / 2.0
			var cap := float(cfg.get("cap", 0.4)) / 2.0
			var cap_low := h - float(cfg.get("cap_height", 0.08))
			var dir := flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
			_box_along(head, base - dir * body, base + dir * body, body, -0.05, cap_low)
			_box_along(pole, base - dir * cap, base + dir * cap, cap, cap_low, h)
		"bollard":
			# A low square post with a lantern head.
			var half := float(cfg.get("half", 0.09))
			_box_along(pole, base - flat.normalized() * half, base + flat.normalized() * half, half, -0.05, h - 0.2)
			_box_along(head, base - flat.normalized() * half * 1.3, base + flat.normalized() * half * 1.3, half * 1.3, h - 0.2, h - 0.04)
			_box_along(pole, base - flat.normalized() * half * 1.6, base + flat.normalized() * half * 1.6, half * 1.6, h - 0.04, h)
	_add_length("lamps", 1.0)
	lamps.append({"kind": kind, "at": base, "height": h})
	# R14: the head glows at night, and a street lamp lights the ground.
	if not glow_colors.has(head):
		glow_colors.append(head)
	_lamp_light(cfg, top)


## R14: the light of a lamp of the kind (its "light"), at the top of the lamp.
func _lamp_light(cfg: Dictionary, top: Vector3) -> void:
	var light_cfg: Dictionary = cfg.get("light", {})
	if light_cfg.is_empty():
		return
	var light := OmniLight3D.new()
	light.light_color = Color(str(light_cfg.get("color", "#FFD9A0")))
	light.light_energy = float(light_cfg.get("energy", 1.5))
	light.omni_range = float(light_cfg.get("range", 12.0))
	light.shadow_enabled = false
	light.position = top + Vector3(0, float(light_cfg.get("y", 0.0)), 0)
	light.visible = false
	add_child(light)
	lamp_lights.append(light)


## A lamp that is a model of this game (data/world/drawings/, D-0026-08): at
## its base, turned along the road. The surfaces of its role "glow_role" glow at
## night (update_time()).
func _world_lamp(kind: String, model_id: String, cfg: Dictionary, base: Vector3, along: Vector3) -> void:
	var model := WorldModel.make(model_id)
	if model == null:
		return
	var flat := Vector3(along.x, 0, along.z)
	model.transform = Transform3D(Basis(Vector3.UP, atan2(flat.x, flat.z) if flat.length() > 0.01 else 0.0), base)
	model.far_end = float(cfg.get("far_end_m", 0.0))
	# The ranges of the levels of the kind for a preset (the low lamp on Low).
	for preset: String in cfg.get("ranges", {}):
		var r: Array = cfg.ranges[preset]
		model.custom_ranges[preset] = Vector3(float(r[0]), float(r[1]), float(r[2]))
	add_child(model)
	model.apply_ranges()
	var role := str(cfg.get("glow_role", ""))
	if role != "":
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node as MeshInstance3D
			for i in mesh_node.mesh.get_surface_count():
				var source := mesh_node.mesh.surface_get_material(i)
				var used := mesh_node.get_surface_override_material(i) as StandardMaterial3D
				if source != null and source.resource_name == role and used != null and not glow_materials.has(used):
					glow_materials.append(used)
	_add_length("lamps", 1.0)
	_add_length("world_lamps", 1.0)
	var h := float(cfg.get("height", 0.7))
	lamps.append({"kind": kind, "at": base, "height": h, "model": model_id})
	_lamp_light(cfg, base + Vector3(0, h, 0))


## True when the model has its order in data/world/orders.json and its files.
static func _has_model(model_id: String) -> bool:
	if model_id == "" or WorldModel.order(model_id).is_empty():
		return false
	var levels := WorldModel.levels_of(model_id)
	return not levels.is_empty() and ResourceLoader.exists(WorldModel.ROOT + model_id + WorldModel.SUFFIX[levels[0]])


## An option of the order of a model: its value in the order, or the default of
## the param of its blueprint in data.
static func _option(model_id: String, name: String, default: Variant) -> Variant:
	var order: Dictionary = WorldModel.order(model_id).get("order", {})
	var options: Dictionary = order.get("options", {})
	if options.has(name):
		return options[name]
	var blueprint: Variant = order.get("blueprint", {})
	if blueprint is Dictionary:
		for param: Dictionary in blueprint.get("params", []):
			if str(param.get("name", "")) == name and param.has("default"):
				return param["default"]
	return default


## A piece of a wall (a model of this game along x, from its port "start" at
## x = -length/2 to its port "end" at x = length/2, the sea to +y, z up) from
## the point a to the point b: it follows the slope of a to b (a shear), and
## "up" and "out" scale its height and its depth.
func _wall_piece(model_id: String, a: Vector3, b: Vector3, sea: Vector3, up := 1.0, out := 1.0, row: WorldRow = null) -> void:
	var length := float(_option(model_id, "length", 2.0))
	if a.distance_to(b) < 0.05 or length <= 0.0:
		return
	if row == null:
		row = _row_of_walls()
	# The x of World is -x of the GLB: the local -x goes from a to b. A
	# MultiMesh does not turn the faces of a mirrored instance over, so the
	# basis stays right-handed: when the sea is to the other side, the piece
	# goes from b to a (its two ends are the same).
	var flat_sea := Vector3(sea.x, 0.0, sea.z).normalized()
	var basis := Basis(-(b - a) / length, Vector3(0.0, up, 0.0), flat_sea * out)
	if basis.determinant() < 0.0:
		basis.x = -basis.x
	row.add(model_id, Transform3D(basis, (a + b) / 2.0 - basis.y * _lift_of(model_id)))


## The lift of the levels of a model in a WorldRow (WorldModel, R7: the model
## stands on y = 0). A piece of a sea wall or of the steps hangs under its
## port (its top at y = 0 of World, its foot under it), so the row lifted it by
## its depth: the steps stood over the walk, and the slope of Hạ Long, turned
## over to go down, lay as a flat deck over the beach (audit 3 of the
## corrections, D-0026-26 and D-0026-27). The pieces take the lift away.
## The model is made, read, and freed at once: a template of WorldRow is freed
## only by WorldRow.build(), and a play test that quits before the showcase
## builds its rows leaked it (the CI of ad8c8bd: geo_tide, tree_budget).
func _lift_of(model_id: String) -> float:
	if _lifts.has(model_id):
		return _lifts[model_id]
	var lift := 0.0
	var model := WorldModel.make(model_id)
	if model != null:
		for level: String in ["mid", "near", "far"]:
			var node := model.level(level)
			if node != null:
				lift = node.position.y
				break
		model.free()
	_lifts[model_id] = lift
	return lift


## Report 0026, D-0026-22: a fence of a model of this game (the fence of the
## Grand Hotel) along a line on the ground: spans of "span_m" one after another
## (the port end of a span on the port start of the next), out of the gaps (the
## gates), and a collision wall of "height_m" along each span.
func _fence(cfg: Dictionary) -> void:
	var model_id := str(cfg.get("model", ""))
	if not _has_model(model_id):
		return
	var span := float(cfg.get("span_m", 2.8))
	var height := float(cfg.get("height_m", 1.2))
	var line := PackedVector3Array()
	for q: Array in cfg.get("line", []):
		line.append(Vector3(float(q[0]), 0.0, float(q[1])))
	var gaps: Array[Vector2] = []
	for g: Array in cfg.get("gaps", []):
		gaps.append(Vector2(float(g[0]), float(g[1])))
	var total := _line_length(line)
	var k := 0
	while (k + 1) * span <= total + 0.01:
		var s0 := k * span
		var s1 := s0 + span
		k += 1
		if _in_gaps((s0 + s1) / 2.0, gaps, span / 2.0):
			continue
		var a := _along_line(line, s0)
		var b := _along_line(line, s1)
		a.y = world.ground_height(a.x, a.z)
		b.y = world.ground_height(b.x, b.z)
		var dir := b - a
		var side := Vector3(-dir.z, 0.0, dir.x).normalized()
		# The x of World is -x of the GLB; the basis stays right-handed (_wall_piece()).
		var basis := Basis(-dir / span, Vector3.UP, side)
		if basis.determinant() < 0.0:
			basis.x = -basis.x
		_row_of_fences().add(model_id, Transform3D(basis, (a + b) / 2.0))
		var a_top := a + Vector3(0.0, height, 0.0)
		var b_top := b + Vector3(0.0, height, 0.0)
		# Both faces: a trimesh stops a body only on the front of a face.
		_collision.append_array([a, b, b_top, a, b_top, a_top, b, a, a_top, b, a_top, b_top])
		_add_length("fence", span)


## The row of the pieces of the walls (and the steps down to the sand).
func _row_of_walls() -> WorldRow:
	if wall_row == null:
		wall_row = _new_row("WallPieces", "ranges")
	return wall_row


## The row of the spans of the fences.
func _row_of_fences() -> WorldRow:
	if fence_row == null:
		fence_row = _new_row("FencePieces", "fence_ranges")
	return fence_row


## The row of the pieces under the low wall of the beach.
func _row_under_walls() -> WorldRow:
	if under_row == null:
		under_row = _new_row("WallUnderPieces", "under_ranges")
	return under_row


func _new_row(row_name: String, ranges_key: String) -> WorldRow:
	var row := WorldRow.new()
	row.name = row_name
	var cfg: Dictionary = data.get("wall_pieces", {})
	row.cell_size = float(cfg.get("cell_m", WorldRow.CELL))
	for preset: String in cfg.get(ranges_key, {}):
		var r: Array = cfg[ranges_key][preset]
		row.custom_ranges[preset] = Vector3(float(r[0]), float(r[1]), float(r[2]))
	add_child(row)
	return row


## The point on the ground.
func _on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, world.ground_height(p.x, p.z), p.z)


## A prism of the outline from "low" to "top", with a roof of its own color.
func _prism(color: String, roof: String, ring: PackedVector2Array, low: float, top: float) -> void:
	var clockwise := _area(ring) < 0.0
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		var edge := (b - a).normalized()
		var out := Vector3(edge.y, 0, -edge.x) if not clockwise else Vector3(-edge.y, 0, edge.x)
		_wall(color, Vector3(a.x, low, a.y), Vector3(b.x, low, b.y), top - low, out)
	var indices := Geometry2D.triangulate_polygon(ring)
	for k in range(0, indices.size(), 3):
		var p := ring[indices[k]]
		var q := ring[indices[k + 1]]
		var r := ring[indices[k + 2]]
		_mesh(roof).triangle(Vector3(p.x, top, p.y), Vector3(q.x, top, q.y), Vector3(r.x, top, r.y), Vector3.UP)
		_collision.append_array([Vector3(p.x, top, p.y), Vector3(q.x, top, q.y), Vector3(r.x, top, r.y)])


## The length of a line (m).
static func _line_length(line: PackedVector3Array) -> float:
	var result := 0.0
	for i in line.size() - 1:
		result += line[i].distance_to(line[i + 1])
	return result


static func _area(ring: PackedVector2Array) -> float:
	var result := 0.0
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		result += a.x * b.y - b.x * a.y
	return result / 2.0


func _commit() -> void:
	if park_row != null:
		park_row.build()
		_add_length("park_plants", float(park_row.count()))
	if wall_row != null:
		wall_row.build()
		_add_length("wall_pieces", float(wall_row.count()))
	if fence_row != null:
		fence_row.build()
		_add_length("fence_pieces", float(fence_row.count()))
	if under_row != null:
		under_row.build()
		for node: Node in under_row.find_children("*", "GeometryInstance3D", true, false):
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_length("wall_under_pieces", float(under_row.count()))
	for key: String in _meshes:
		if key == HIDDEN:
			continue
		var arrays: Variant = (_meshes[key] as _Mesh).arrays()
		if arrays == null:
			continue
		# A key "COLOR|SQUARE" is a square of a part in chunks (_ridge()).
		var color := key.get_slice("|", 0)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, _material(color))
		var instance := MeshInstance3D.new()
		instance.name = "Part_" + key.trim_prefix("#").replace("|", "_")
		instance.mesh = mesh
		if key != color and float(_far_ends.get(color, 0.0)) > 0.0:
			instance.visibility_range_end = float(_far_ends[color])
			instance.visibility_range_end_margin = 2.0
		add_child(instance)
	if not _collision.is_empty():
		var body := StaticBody3D.new()
		body.name = "ShowcaseBody"
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(_collision)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)


## The material of a color: a texture set of data/look/textures.json when the
## part "materials" of the showcase names the color (R12), or a flat color.
func _material(color: String) -> Material:
	if not _materials.has(color):
		var textured := _textured(data.get("materials", {}).get(color, {}))
		if textured != null:
			_materials[color] = textured
		else:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(color)
			m.roughness = 0.9
			_materials[color] = m
	return _materials[color]


func _textured(cfg: Dictionary) -> ShaderMaterial:
	if cfg.is_empty():
		return null
	var folder := TEXTURES.path_join(str(cfg.get("texture", "")))
	var set_info: Dictionary = _texture_sets().get(str(cfg.get("texture", "")), {})
	if set_info.is_empty() or not ResourceLoader.exists(folder.path_join("diffuse.jpg")):
		push_warning("Showcase: the texture set %s is not in %s." % [cfg.get("texture"), TEXTURES])
		return null
	var m := ShaderMaterial.new()
	m.shader = load(SURFACE_SHADER)
	m.set_shader_parameter("albedo_texture", load(folder.path_join("diffuse.jpg")))
	m.set_shader_parameter("roughness_texture", load(folder.path_join("roughness.jpg")))
	m.set_shader_parameter("size_m", float(set_info.get("size_m", 2.0)))
	m.set_shader_parameter("tint", Color(str(cfg.get("tint", "#FFFFFF"))))
	var tones: Array = cfg.get("tones", [])
	if tones.size() == 2:
		var dark := Color(str(tones[0]))
		var light := Color(str(tones[1]))
		m.set_shader_parameter("tones", true)
		m.set_shader_parameter("tone_dark", dark)
		m.set_shader_parameter("tone_light", light)
		var range_values: Array = cfg.get("tone_range", [0.04, 0.12])
		m.set_shader_parameter("tone_range", Vector2(float(range_values[0]), float(range_values[1])))
		m.set_shader_parameter("mean_color", dark.lerp(light, 0.5))
	else:
		m.set_shader_parameter("mean_color", Color(str(cfg.get("mean", "#808080"))))
	return m


## The texture sets of assets/textures/look/manifest.json (tools/look/textures.py).
func _texture_sets() -> Dictionary:
	var parsed: Variant = JSON.parse_string(GeoData.read_text(TEXTURES.path_join("manifest.json")))
	return parsed.get("sets", {}) if parsed is Dictionary else {}


## The triangles of one color. A face is clockwise when seen from the side of
## its normal: the front of a face in Godot.
## A face can have UVs in meters along a line (UV2.x = 1): the surface shader
## then puts the texture along the line, not on the world axes.
class _Mesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var flags := PackedVector2Array()

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3,
			uv := PackedVector2Array()) -> void:
		if uv.size() == 4:
			triangle(a, b, c, normal, PackedVector2Array([uv[0], uv[1], uv[2]]))
			triangle(a, c, d, normal, PackedVector2Array([uv[0], uv[2], uv[3]]))
			return
		triangle(a, b, c, normal)
		triangle(a, c, d, normal)

	func triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, uv := PackedVector2Array()) -> void:
		var flag := Vector2(1.0, 0.0) if uv.size() == 3 else Vector2.ZERO
		if uv.size() != 3:
			uv = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
		# The cross product of a clockwise face points away from its front.
		if (b - a).cross(c - a).dot(normal) > 0.0:
			var t := b
			b = c
			c = t
			var tu := uv[1]
			uv[1] = uv[2]
			uv[2] = tu
		vertices.append_array([a, b, c])
		normals.append_array([normal, normal, normal])
		uvs.append_array(uv)
		flags.append_array([flag, flag, flag])

	func arrays() -> Variant:
		if vertices.is_empty():
			return null
		var result := []
		result.resize(Mesh.ARRAY_MAX)
		result[Mesh.ARRAY_VERTEX] = vertices
		result[Mesh.ARRAY_NORMAL] = normals
		result[Mesh.ARRAY_TEX_UV] = uvs
		result[Mesh.ARRAY_TEX_UV2] = flags
		return result


## True when the point is on the steps of an opening of the low wall of the
## beach: from the wall to the foot of the steps on the sand, in the width of
## the opening (plan 0018, D5: a scooter does not go down stairs).
func on_steps(point: Vector3) -> bool:
	for opening: Dictionary in wall_openings:
		if not bool(opening.get("steps", false)):
			continue
		var at: Vector3 = opening.at
		var sand: Vector3 = opening.sand
		var along: Vector3 = opening.along
		var foot: Vector3 = opening.get("foot", at)
		var rel := Vector3(point.x - at.x, 0.0, point.z - at.z)
		var out := rel.dot(sand)
		if absf(rel.dot(along)) <= float(opening.half) and out >= -0.3 \
				and out <= Vector3(foot.x - at.x, 0.0, foot.z - at.z).dot(sand) + 0.3:
			return true
	return false
