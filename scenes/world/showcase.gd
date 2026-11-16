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

const CONFIG := "res://data/showcase/bai_truoc.json"
const BUILDINGS := "res://data/geo/build/buildings.json"
const PLACES := "res://data/world/places/bai_truoc.json"
const TEXTURES := "res://assets/textures/look"
const SURFACE_SHADER := "res://shaders/showcase_surface.gdshader"
## As RoadBuilder.LIFT: the road surface is this much over its line.
const LIFT := 0.04
## The step of the points of a part along its way.
const STEP := 2.0
## A part stops this far from the edge of another road (a junction).
const JUNCTION_MARGIN := 1.0
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
## The lamps of R9: {kind, at (the base), height}.
var lamps: Array[Dictionary] = []
## The fine mask of the ground (R the lawns, G the paving) and its place, or null.
var ground_mask: Image
var ground_origin := Vector2.ZERO
var ground_step := 0.5

var _roads: Dictionary = {}  # OSM id -> the road Dictionary of roads.json
var _meshes: Dictionary = {}  # color (String) -> _Mesh
var _collision := PackedVector3Array()
var _materials: Dictionary = {}


func setup(w: VungTau, path := CONFIG) -> bool:
	world = w
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Showcase: cannot read %s." % path)
		return false
	data = parsed
	outline = _points(data.get("outline", []))
	park = _points(data.get("park", []))
	for road: Dictionary in w.data.roads:
		_roads[int(road.id)] = road
	_places(PLACES)
	_ground(w.data.root.path_join("showcase.json"))
	if data.has("median"):
		_median(data.median)
	for sidewalk: Dictionary in data.get("sidewalks", []):
		_sidewalk(sidewalk)
	if data.has("path_borders"):
		_path_borders(data.path_borders)
	for wall: Dictionary in data.get("walls", []):
		_walls(wall)
	for sea_wall: Dictionary in data.get("sea_walls", []):
		_sea_wall(sea_wall)
	for row: Dictionary in data.get("lamp_rows", []):
		_lamp_row(row)
	if data.has("path_lamps"):
		_path_lamps(data.path_lamps)
	if data.has("stand_ins"):
		_stand_ins(data.stand_ins)
	if data.has("beached"):
		_beached(data.beached)
	_commit()
	# R10: the people, after the parts (they sit on the raised lawns).
	if FileAccess.file_exists(ShowcasePeople.PATH):
		people = ShowcasePeople.new()
		people.name = "People"
		add_child(people)
		people.setup(w, self)
	return true


## The clock time: the people of the hour (R10).
func update_time(minutes: int) -> void:
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


## True when the point (x, z of the game) is in the area.
func contains(x: float, z: float) -> bool:
	return outline.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2(x, z), outline)


# --- The parts ----------------------------------------------------------------

## R3, R4: the lawns and the paving of the park (a fine mask of the ground),
## the raised lawns of the walk of the sea, and the low wall of granite along
## the beach, from data/geo/build/showcase.json (tools/geo/build.py).
func _ground(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("Showcase: %s is not there. Run tools/geo/build.py." % path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Showcase: cannot read %s." % path)
		return
	var info: Dictionary = parsed.get("ground", {})
	var file: String = world.data.root.path_join(str(info.get("file", "")))
	if not info.is_empty() and FileAccess.file_exists(file):
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
		_planter(_points(planter.outline), cfg.get("planters", {}))
	for wall: Dictionary in parsed.get("walls", []):
		var line := PackedVector3Array()
		for point: Array in wall.points:
			line.append(Vector3(float(point[0]), world.ground_height(float(point[0]), float(point[1])), float(point[1])))
		_balustrade(_dense(line, STEP), cfg.get("beach_wall", {}))


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
func _planter(ring: PackedVector2Array, cfg: Dictionary) -> void:
	if ring.size() < 3:
		return
	var h := float(cfg.get("height", 0.45))
	var border := float(cfg.get("border", 0.25))
	var color := str(cfg.get("color", "#aaa69c"))
	var top_of := func(p: Vector2) -> float: return world.ground_height(p.x, p.y) + h
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
			_mesh(c).triangle(t[0], t[1], t[2], Vector3.UP)
			_collision.append_array([t[0], t[1], t[2]])
	top.call(ring, color, 0.0)
	if lawn.size() >= 3:
		top.call(lawn, str(cfg.get("top_color", "#4f6e35")), 0.02)
	_add_length("planter", 1.0)


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
	var half := float(cfg.get("width", 0.4)) / 2.0
	var base := float(cfg.get("base", 0.3))
	var rail := float(cfg.get("height", 0.8))
	var rail_depth := float(cfg.get("rail", 0.14))
	var post_every := float(cfg.get("post_every", 2.4))
	var post_half := float(cfg.get("post", 0.32)) / 2.0
	var along := 0.0
	var next_post := 0.0
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		a.y = world.ground_height(a.x, a.z) + LIFT
		b.y = world.ground_height(b.x, b.z) + LIFT
		var length := a.distance_to(b)
		_box_along(color, a, b, half, -0.2, base)
		_box_along(color, a, b, half * 0.85, rail - rail_depth, rail)
		while next_post <= along + length:
			var t := (next_post - along) / maxf(length, 0.001)
			var at := a.lerp(b, t)
			var dir := (b - a).normalized()
			_box_along(color, at - dir * post_half, at + dir * post_half, post_half, base, rail - rail_depth)
			next_post += post_every
		along += length
	_add_length("beach_wall", along)


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
	for p: Vector3 in _dense(_line(a), STEP):
		var q := _nearest(line_b, p)
		var across := Vector3(q.x - p.x, 0.0, q.z - p.z)
		var gap := across.length() - float(a.width) / 2.0 - float(b.width) / 2.0
		var mid := (p + q) / 2.0
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
			_add_length("sidewalk", e0.distance_to(e1))


## R3: the granite borders of the lawns along both edges of the paths of the park.
func _path_borders(cfg: Dictionary) -> void:
	var types: Array = cfg.get("types", ["footway", "pedestrian"])
	var height := float(cfg.get("height", 0.14))
	var width := float(cfg.get("width", 0.16))
	var color := str(cfg.get("color", "#8f8c86"))
	var paths: Array[int] = []
	for id: int in _roads:
		if str(_roads[id].type) in types:
			paths.append(id)
	for id: int in paths:
		var road: Dictionary = _roads[id]
		var half := float(road.width) / 2.0 + width / 2.0
		var others := _other_roads([id])
		for sign: float in [-1.0, 1.0]:
			for run: PackedVector3Array in _runs(_line(road), func(p: Vector3, side: Vector3) -> bool:
					var at := p + side * sign * half
					return park.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), park) \
							and not _near_other(at, others, width)):
				_ridge(color, run, sign * half, width, height)
				_add_length("path_border", _length(run))


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
				_balustrade(line, cfg)
			else:
				_ridge(str(cfg.get("color", "#8a867e")), run, offset, width, float(cfg.get("height", 0.55)))
			_add_length("wall", _length(run))


## R4, R6: the walk on the sea side of Hạ Long, its parapet, and the sea wall
## of stone under it, down the ground to the sea.
func _sea_wall(cfg: Dictionary) -> void:
	var sign := 1.0 if str(cfg.get("side", "right")) == "right" else -1.0
	var walk := float(cfg.get("walk", 3.0))
	var width := float(cfg.get("width", 7.0))
	var parapet := float(cfg.get("parapet", 0.6))
	var until_z := float(cfg.get("until_z", INF))
	var ids: Array[int] = []
	for way: Variant in cfg.get("ways", []):
		ids.append(int(way))
	var others := _other_roads(ids)
	for id in ids:
		var road: Dictionary = _roads.get(id, {})
		if road.is_empty():
			continue
		var half := float(road.width) / 2.0
		for run: PackedVector3Array in _runs(_line(road), func(p: Vector3, side: Vector3) -> bool:
				var at := p + side * sign * (half + walk / 2.0)
				return contains(at.x, at.z) and at.z <= until_z and not _near_other(at, others, walk / 2.0)):
			var sides := _sides(run)
			for i in run.size() - 1:
				var e0 := run[i] + sides[i] * sign * half + Vector3(0, LIFT, 0)
				var e1 := run[i + 1] + sides[i + 1] * sign * half + Vector3(0, LIFT, 0)
				var o0 := e0 + sides[i] * sign * walk
				var o1 := e1 + sides[i + 1] * sign * walk
				var up := Vector3(0, 0.15, 0)
				_wall(str(cfg.get("walk_color", "#b9a68d")), e0, e1, 0.15, -sides[i] * sign)
				_top(str(cfg.get("walk_color", "#b9a68d")), e0 + up, e1 + up, o0 + up, o1 + up)
				# The parapet at the outer edge of the walk.
				_box_along(str(cfg.get("color", "#77746c")), o0 - sides[i] * sign * 0.15 + up,
						o1 - sides[i + 1] * sign * 0.15 + up, 0.15, 0.0, parapet)
				# The face of stone from the walk down to the ground, then over the ground to the sea.
				var g0 := o0 + sides[i] * sign * width
				var g1 := o1 + sides[i + 1] * sign * width
				g0.y = minf(world.ground_height(g0.x, g0.z), o0.y) + 0.05
				g1.y = minf(world.ground_height(g1.x, g1.z), o1.y) + 0.05
				_slope(str(cfg.get("color", "#77746c")), o0 + up, o1 + up, g0, g1, sides[i] * sign)
				_add_length("sea_wall", e0.distance_to(e1))


## R7: a stand-in for each building of OSM in the area: its outline and its storeys.
func _stand_ins(cfg: Dictionary) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILDINGS))
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
		if not contains(center.x, center.y) or str(building.get("osm", "")) in skip or _in_model(Vector3(center.x, 0, center.y)):
			continue
		var known: Dictionary = cfg.get("storeys", {}).get(str(building.get("osm", "")), {})
		var storeys := float(known.get("storeys", building.get("levels", cfg.get("default_storeys", 1))))
		var low := INF
		for p in ring:
			low = minf(low, world.ground_height(p.x, p.y))
		var height := float(building.get("height", storeys * storey))
		var top := low + height
		_prism(color, roof, ring, low - 0.5, top)
		stand_ins.append({"osm": str(building.get("osm", "")), "name": str(building.get("name", "")),
				"center": Vector3(center.x, low, center.y), "top": top, "outline": ring,
				"storeys": storeys, "known": not known.is_empty() or building.has("levels") or building.has("height")})
	_add_length("stand_ins", stand_ins.size())


## R7, D3: the models of World at their places, with the ranges of D6.
func _places(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Showcase: cannot read %s." % path)
		return
	var ranges := {}
	for preset: String in parsed.get("ranges", {}):
		var r: Array = parsed.ranges[preset]
		ranges[preset] = Vector3(float(r[0]), float(r[1]), float(r[2]))
	for place: Dictionary in parsed.get("places", []):
		var model := WorldModel.make(str(place.id))
		if model == null:
			continue
		model.custom_ranges = ranges
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


## R5: the basket boats on the sand above the water line.
func _beached(cfg: Dictionary) -> void:
	for point: Array in cfg.get("points", []):
		var p := Vector3(float(point[0]), 0.0, float(point[1]))
		p.y = world.ground_height(p.x, p.z)
		if p.y < float(cfg.get("min_ground", 1.6)):
			push_warning("Showcase: the boat at (%.0f, %.0f) is under the water line (%.2f m)." % [p.x, p.z, p.y])
			continue
		var boat := WorldModel.make(str(cfg.model), WorldMaterials.DEFAULT_PAINT, str(cfg.get("material_set", "")))
		if boat == null:
			return
		boat.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(point[2]))), p)
		add_child(boat)
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
func _other_roads(ids: Array) -> Array:
	var result := []
	for id: int in _roads:
		if id in ids:
			continue
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
			result.append([line, float(road.width) / 2.0, box.grow(float(road.width) / 2.0 + 12.0)])
	return result


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


## A face that looks up: the corners a0, a1 along one edge, b0, b1 along the other.
func _top(color: String, a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> void:
	_mesh(color).quad(a0, a1, b1, b0, Vector3.UP)
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
func _ridge(color: String, line: PackedVector3Array, offset: float, width: float, height: float) -> void:
	var sides := _sides(line)
	for i in line.size() - 1:
		var a := line[i] + sides[i] * offset + Vector3(0, LIFT, 0)
		var b := line[i + 1] + sides[i + 1] * offset + Vector3(0, LIFT, 0)
		_box_along(color, a, b, width / 2.0, 0.0, height)


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
			_lamp(str(cfg.get("kind", "")), at[0], at[1])


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
			count += 1
	_add_length("path_lamps", count)


## R9: a stand-in lamp of the kind of "lamp_kinds" at the point (its base),
## its arms across the direction "along" (the direction of the road).
func _lamp(kind: String, at: Vector3, along: Vector3) -> void:
	var cfg: Dictionary = data.get("lamp_kinds", {}).get(kind, {})
	if cfg.is_empty():
		push_warning("Showcase: no lamp kind %s." % kind)
		return
	var base := at
	base.y = maxf(at.y, world.ground_height(at.x, at.z))
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
	var light_cfg: Dictionary = cfg.get("light", {})
	if not light_cfg.is_empty():
		var light := OmniLight3D.new()
		light.light_color = Color(str(light_cfg.get("color", "#FFD9A0")))
		light.light_energy = float(light_cfg.get("energy", 1.5))
		light.omni_range = float(light_cfg.get("range", 12.0))
		light.shadow_enabled = false
		light.position = top + Vector3(0, float(light_cfg.get("y", 0.0)), 0)
		light.visible = false
		add_child(light)
		lamp_lights.append(light)


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
	for color: String in _meshes:
		var arrays: Variant = (_meshes[color] as _Mesh).arrays()
		if arrays == null:
			continue
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, _material(color))
		var instance := MeshInstance3D.new()
		instance.name = "Part_" + color.trim_prefix("#")
		instance.mesh = mesh
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
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXTURES.path_join("manifest.json")))
	return parsed.get("sets", {}) if parsed is Dictionary else {}


## The triangles of one color. A face is clockwise when seen from the side of
## its normal: the front of a face in Godot.
class _Mesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
		triangle(a, b, c, normal)
		triangle(a, c, d, normal)

	func triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
		# The cross product of a clockwise face points away from its front.
		if (b - a).cross(c - a).dot(normal) > 0.0:
			var t := b
			b = c
			c = t
		vertices.append_array([a, b, c])
		normals.append_array([normal, normal, normal])

	func arrays() -> Variant:
		if vertices.is_empty():
			return null
		var result := []
		result.resize(Mesh.ARRAY_MAX)
		result[Mesh.ARRAY_VERTEX] = vertices
		result[Mesh.ARRAY_NORMAL] = normals
		return result
