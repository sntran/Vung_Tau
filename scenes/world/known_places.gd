class_name KnownPlaces
extends Node3D
## The known places of Vũng Tàu (plan 0008): the statue on Núi Nhỏ, the
## lighthouse, Bạch Dinh, the statue of Bãi Dâu, Miếu Hòn Bà, and the jetty of
## Cầu Đá.
##
## data/geo/landmarks.json has a "place" record for each place (D1): the
## sizes with their sources, the status, the stand-in, and the Lens card.
## tools/geo/build.py finds the position, the outline, or the line of each
## place in OSM, and makes the ground under it level (R2). This node makes:
## - the stand-in of each place with the status Source or Confirmed (D3a, R3):
##   a plain shape of the real size, with a far form of 300 triangles or less
##   that shows to 4 km (D8, R9);
## - the base on the ground with a skirt (D7, R2) and the collision (R7);
## - the stairs of the places on the OSM lines of steps, with steps of 15 cm
##   to 18 cm and a landing at each turn (R6, R15), and the jetty of Cầu Đá.
## A place with the status "Check" gets nothing (D2).

const CONFIG := "res://data/geo/landmarks.json"
## R6: the height of a step.
const STEP_MIN := 0.15
const STEP_MAX := 0.18
const STEP := 0.165
## A step of the stairs comes where the ground is this part of a step from the tread.
const STEP_FOLLOW := 0.6
## The cell of the height map of the collision of stairs, in meters.
const STAIR_CELL := 0.25
## The invisible slope beside the stairs: its width.
const SKIRT_M := 1.0
## The treads stand this much over the ground of the cut (tools/geo/build.py, cut_stairs()).
const STAIR_LIFT := 0.12
## The steps climb to a landing with this grade or less (0.59 is the most for steps of 16.5 cm on treads of 28 cm).
const LEAD_GRADE := 0.58
## The shortest tread when the steps catch up with the ground (a ramp of 36.9° on the noses, under the 40° of the player).
const TREAD_FAST_M := 0.22
## The shortest tread of the stairs, in meters.
const TREAD_M := 0.28
## A turn of more than this has a landing (R6).
const TURN_DEG := 30.0
const LANDING_M := 1.2
## The near form ends here, and the far form shows to FAR_END (R9: from 3 km).
const NEAR_END := 450.0
const FAR_END := 4500.0
const PARAPET_HEIGHT := 1.0
const PARAPET_WIDTH := 0.3
## The jetty: its deck is this much over the highest tide of the game year.
const JETTY_OVER_TIDE := 0.6
const JETTY_CURB := 0.35
const JETTY_WALL := 1.1

## The places by id: {"id", "config", "record", "place", "node", "base", "top", "center"}.
var places: Dictionary = {}
## The stairs: [{"way", "place", "points": PackedVector3Array (the walk line), "steps": int}].
var stairs: Array[Dictionary] = []
## The jetty: {"line": PackedVector3Array, "deck": float, "width": float} or {}.
var jetty: Dictionary = {}
var world: VungTau
var _materials: Dictionary = {}


## The place records of data/geo/landmarks.json, by id.
static func configs(path := CONFIG) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var result := {}
	if parsed is Dictionary:
		for entry: Dictionary in parsed.get("landmarks", []):
			if entry.has("place"):
				result[entry.id] = entry
	return result


## The problems of the place records (R1, PT-59): each place has a status, a
## Lens card, and a source for each size; a place with "Check" has no model
## and no stand-in; a place with a stand-in has a position in the play area.
static func check(entries: Dictionary, records: Dictionary, bounds := Rect2()) -> Array[String]:
	var problems: Array[String] = []
	for id: String in entries:
		var place: Dictionary = entries[id].place
		var status := str(place.get("status", ""))
		if status not in ["Confirmed", "Source", "Check"]:
			problems.append("%s: the status \"%s\" is not Confirmed, Source, or Check" % [id, status])
		if str(place.get("name_en", "")) == "":
			problems.append("%s: no English name" % id)
		if status == "Check":
			if place.get("model") != null:
				problems.append("%s: a place with Check has a model order" % id)
			if str(place.get("kind", "none")) != "none":
				problems.append("%s: a place with Check has a stand-in" % id)
			continue
		var lens: Dictionary = place.get("lens", {})
		for key in ["phrase_vi", "phrase_en", "text"]:
			if str(lens.get(key, "")) == "":
				problems.append("%s: the Lens card has no %s" % [id, key])
		var sizes: Dictionary = place.get("sizes", {})
		if sizes.is_empty():
			problems.append("%s: no sizes" % id)
		for size_name: String in sizes:
			if str(sizes[size_name].get("source", "")) == "":
				problems.append("%s: the size %s has no source" % [id, size_name])
		var record: Dictionary = records.get(id, {})
		if not record.get("found", false):
			problems.append("%s: OSM has no position" % id)
		elif bounds.has_area() and not bounds.has_point(Vector2(record.position[0], record.position[1])):
			problems.append("%s: the position is out of the play area" % id)
	return problems


func setup(w: VungTau, path := CONFIG) -> bool:
	world = w
	var entries := configs(path)
	var records := {}
	for record: Dictionary in w.data.landmarks:
		records[record.id] = record
	for problem in check(entries, records):
		push_error("KnownPlaces: %s." % problem)
	var roads := {}
	for road: Dictionary in w.data.roads:
		roads[int(road.id)] = road
	for id: String in entries:
		var place: Dictionary = entries[id].place
		var record: Dictionary = records.get(id, {})
		if place.get("status", "") == "Check" or not record.get("found", false):
			continue
		var node := Node3D.new()
		node.name = "Place_" + id
		add_child(node)
		var entry := {"id": id, "config": entries[id], "record": record, "place": place, "node": node}
		places[id] = entry
		match str(place.kind):
			"statue":
				_statue(entry)
			"tower":
				_tower(entry)
			"villa":
				_villa(entry)
			"column", "shrine":
				_prism_place(entry)
			"jetty":
				_jetty(entry)
		entry.radius = _radius(entry)
		for way_id: Variant in place.get("stairs", []):
			if roads.has(int(way_id)):
				_stairs(entry, roads[int(way_id)])
	return true


# --- Stand-ins ------------------------------------------------------------------

func _size(place: Dictionary, name: String, fallback: float) -> float:
	var value: Variant = place.get("sizes", {}).get(name, {}).get("value", fallback)
	return float(value) if value is float or value is int else fallback


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_materials[key] = m
	return _materials[key]


func _color(place: Dictionary, key: String, fallback: String) -> Color:
	return Color(str(place.get("colors", {}).get(key, fallback)))


## The height of the base: the level ground that the build made (R2).
func _base_height(record: Dictionary) -> float:
	if record.has("base_height"):
		return float(record.base_height)
	var low := INF
	for p: Array in record.get("outline", []):
		low = minf(low, world.ground_height(p[0], p[1]))
	if low == INF:
		low = world.ground_height(record.position[0], record.position[1])
	return low + 0.1


## A mesh of the near or the far form, with its visibility range.
func _add_mesh(entry: Dictionary, mesh: ArrayMesh, far: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.name = "Far" if far else "Near"
	instance.visibility_range_begin = NEAR_END if far else 0.0
	instance.visibility_range_end = FAR_END if far else NEAR_END
	instance.visibility_range_end_margin = 20.0
	instance.visibility_range_begin_margin = 20.0 if far else 0.0
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	(entry.node as Node3D).add_child(instance)
	entry[instance.name.to_lower()] = instance
	return instance


func _body(entry: Dictionary) -> StaticBody3D:
	if not entry.has("body"):
		var body := StaticBody3D.new()
		body.name = "Solid"
		body.collision_layer = Layers.SOLID | Layers.FLOOR
		body.collision_mask = 0
		(entry.node as Node3D).add_child(body)
		entry.body = body
	return entry.body


func _box_shape(entry: Dictionary, size: Vector3, xform: Transform3D) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = xform
	_body(entry).add_child(shape)


## A regular polygon (n sides) in the x-z plane.
static func ring_points(center: Vector2, radius: float, sides: int, turn := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		var a := turn + TAU * i / sides
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return points


## The statue on Núi Nhỏ (R3, R6): the round plaza with its parapet, the base,
## the terrace, the dome, the figure as a column, and the arms.
func _statue(entry: Dictionary) -> void:
	var place: Dictionary = entry.place
	var record: Dictionary = entry.record
	var c := Vector2(record.position[0], record.position[1])
	var y0 := _base_height(record)
	var plaza := _size(place, "plaza_radius", 15.0)
	var base_w := _size(place, "base_width", 13.0)
	var base_h := _size(place, "base_height", 4.0)
	var terrace_w := _size(place, "terrace_width", 12.5)
	var dome_w := _size(place, "dome_width", 8.0)
	var figure := _size(place, "figure_height", 32.0)
	var robe := _size(place, "robe_width", 4.75)
	var span := _size(place, "arm_span", 18.4)
	var arm_y := _size(place, "arm_height", 27.0)
	var stone := _color(place, "stone", "#E6E4DE")
	var near := SurfaceTool.new()
	near.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ground_low := minf(y0 - 0.1, _lowest_around(c, plaza)) - 0.5
	# The plaza and its skirt (D7).
	_prism(near, ring_points(c, plaza, 32), ground_low, y0)
	# The parapet round the plaza (R6): the player cannot pass it.
	var outer := ring_points(c, plaza, 32)
	for i in 32:
		var a := outer[i]
		var b := outer[(i + 1) % 32]
		var inset := (c - (a + b) / 2.0).normalized() * (PARAPET_WIDTH / 2.0)
		_wall(near, a + inset, b + inset, y0, y0 + PARAPET_HEIGHT, PARAPET_WIDTH)
		var mid := (a + b) / 2.0 + inset
		var along := (b - a)
		_box_shape(entry, Vector3(along.length() + 0.1, PARAPET_HEIGHT + 1.0, PARAPET_WIDTH),
				Transform3D(Basis(Vector3.UP, -atan2(along.y, along.x)), Vector3(mid.x, y0 + (PARAPET_HEIGHT + 1.0) / 2.0, mid.y)))
	var base := ring_points(c, base_w / 2.0, 8, PI / 8.0)
	_prism(near, base, y0, y0 + base_h)
	_prism(near, ring_points(c, terrace_w / 2.0, 8, PI / 8.0), y0 + base_h, y0 + base_h + 0.3)
	var dome_top := y0 + base_h + 0.3 + 1.5
	_prism(near, ring_points(c, dome_w / 2.0, 8, PI / 8.0), y0 + base_h + 0.3, dome_top)
	_prism(near, ring_points(c, robe / 2.0, 8, PI / 8.0), dome_top, dome_top + figure)
	var arms := _arm_box(c, span, arm_y + dome_top, entry)
	_add_box(near, arms)
	near.generate_normals()
	var mesh := near.commit()
	mesh.surface_set_material(0, _material(stone))
	_add_mesh(entry, mesh, false)
	# The floor of the plaza and the solid base of the statue (R7).
	_box_shape(entry, Vector3(plaza * 2.0, 0.6, plaza * 2.0), Transform3D(Basis(), Vector3(c.x, y0 - 0.3, c.y)))
	_box_shape(entry, Vector3(base_w * 0.92, base_h + 2.0, base_w * 0.92), Transform3D(Basis(), Vector3(c.x, y0 + (base_h + 2.0) / 2.0, c.y)))
	# The far form (R9): the base, the figure, and the arms.
	var far := SurfaceTool.new()
	far.begin(Mesh.PRIMITIVE_TRIANGLES)
	_prism(far, base, y0, y0 + base_h)
	_prism(far, ring_points(c, robe / 2.0, 6), y0 + base_h, dome_top + figure)
	_add_box(far, arms)
	far.generate_normals()
	var far_mesh := far.commit()
	far_mesh.surface_set_material(0, _material(stone))
	_add_mesh(entry, far_mesh, true)
	entry.base = y0
	entry.top = dome_top + figure
	entry.center = Vector3(c.x, y0, c.y)
	entry.plaza = plaza


## The arms: a box across the figure, at right angles to the direction of the
## statue (it faces the sea to the south-east; the direction is in the record,
## else the arms go along x).
func _arm_box(c: Vector2, span: float, top: float, entry: Dictionary) -> Dictionary:
	var deg := float(entry.place.get("direction_deg", 0.0))
	return {"center": Vector3(c.x, top - 0.9, c.y), "size": Vector3(span, 1.8, 1.6), "turn": deg_to_rad(deg)}


## The lighthouse (R3): a white tower with a gallery and a lantern.
func _tower(entry: Dictionary) -> void:
	var place: Dictionary = entry.place
	var record: Dictionary = entry.record
	var c := _center(record)
	var y0 := _base_height(record)
	var h := _size(place, "height", 18.0)
	var r := _size(place, "diameter", 3.0) / 2.0
	var stone := _color(place, "stone", "#F1F0EA")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_base_platform(st, entry, y0)
	_prism(st, ring_points(c, r, 12), y0, y0 + h - 2.2)
	# The gallery: a ring floor and a railing, then the lantern.
	_prism(st, ring_points(c, r + 0.8, 12), y0 + h - 2.4, y0 + h - 2.2)
	for i in 12:
		var pts := ring_points(c, r + 0.75, 12)
		_wall(st, pts[i], pts[(i + 1) % 12], y0 + h - 2.2, y0 + h - 1.2, 0.08)
	_prism(st, ring_points(c, r * 0.7, 8), y0 + h - 2.2, y0 + h - 0.4)
	_prism(st, ring_points(c, r * 0.8, 8), y0 + h - 0.4, y0 + h)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _material(stone))
	_add_mesh(entry, mesh, false)
	var far := SurfaceTool.new()
	far.begin(Mesh.PRIMITIVE_TRIANGLES)
	_prism(far, ring_points(c, r, 8), y0, y0 + h)
	_prism(far, ring_points(c, r + 0.8, 8), y0 + h - 2.4, y0 + h - 2.2)
	far.generate_normals()
	var far_mesh := far.commit()
	far_mesh.surface_set_material(0, _material(stone))
	_add_mesh(entry, far_mesh, true)
	_cylinder_shape(entry, c, r, y0, y0 + h)
	entry.base = y0
	entry.top = y0 + h
	entry.center = Vector3(c.x, y0, c.y)


## Bạch Dinh (R3): a box of the real length, width, and height along the long
## side of the OSM outline, with a roof slab.
func _villa(entry: Dictionary) -> void:
	var place: Dictionary = entry.place
	var record: Dictionary = entry.record
	var c := _center(record)
	var y0 := _base_height(record)
	var length := _size(place, "length", 28.0)
	var width := _size(place, "width", 15.0)
	var h := _size(place, "height", 19.0)
	var angle := _long_side_angle(record)
	var basis := Basis(Vector3.UP, -angle)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_base_platform(st, entry, y0)
	_add_box(st, {"center": Vector3(c.x, y0 + (h - 1.2) / 2.0, c.y), "size": Vector3(length, h - 1.2, width), "turn": angle})
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _material(_color(place, "stone", "#EEEBE3")))
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(roof, {"center": Vector3(c.x, y0 + h - 0.6, c.y), "size": Vector3(length + 0.6, 1.2, width + 0.6), "turn": angle})
	roof.generate_normals()
	roof.commit(mesh)
	mesh.surface_set_material(1, _material(_color(place, "roof", "#B5643F")))
	_add_mesh(entry, mesh, false)
	var far := mesh.duplicate() as ArrayMesh
	_add_mesh(entry, far, true)
	_box_shape(entry, Vector3(length, h, width), Transform3D(basis, Vector3(c.x, y0 + h / 2.0, c.y)))
	entry.base = y0
	entry.top = y0 + h
	entry.center = Vector3(c.x, y0, c.y)


## The statue of Bãi Dâu and Miếu Hòn Bà (R3): the OSM outline as a prism of
## the real height (the shrine has a roof slab).
func _prism_place(entry: Dictionary) -> void:
	var place: Dictionary = entry.place
	var record: Dictionary = entry.record
	var outline := PackedVector2Array()
	for p: Array in record.get("outline", []):
		outline.append(Vector2(p[0], p[1]))
	if outline.size() > 3 and outline[0].distance_to(outline[outline.size() - 1]) < 0.01:
		outline.remove_at(outline.size() - 1)
	var y0 := _base_height(record)
	var h := _size(place, "height", 4.0)
	var c := _center(record)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_base_platform(st, entry, y0)
	var body_top := y0 + h - (0.6 if place.kind == "shrine" else 0.0)
	_prism(st, outline, y0, body_top)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _material(_color(place, "stone", "#ECEAE4")))
	if place.kind == "shrine":
		var roof := SurfaceTool.new()
		roof.begin(Mesh.PRIMITIVE_TRIANGLES)
		_prism(roof, _grow(outline, c, 0.4), body_top, y0 + h)
		roof.generate_normals()
		roof.commit(mesh)
		mesh.surface_set_material(1, _material(_color(place, "roof", "#C8642E")))
	_add_mesh(entry, mesh, false)
	_add_mesh(entry, mesh.duplicate() as ArrayMesh, true)
	var box := _outline_box(outline)
	_box_shape(entry, Vector3(box.size.x, h, box.size.y), Transform3D(Basis(), Vector3(box.get_center().x, y0 + h / 2.0, box.get_center().y)))
	entry.base = y0
	entry.top = y0 + h
	entry.center = Vector3(c.x, y0, c.y)


## The flat base under an outline, with a skirt down to the ground (D7, R2).
func _base_platform(st: SurfaceTool, entry: Dictionary, y0: float) -> void:
	var outline := PackedVector2Array()
	for p: Array in entry.record.get("outline", []):
		outline.append(Vector2(p[0], p[1]))
	if outline.size() < 3:
		return
	if outline[0].distance_to(outline[outline.size() - 1]) < 0.01:
		outline.remove_at(outline.size() - 1)
	var c := _center(entry.record)
	var grown := _grow(outline, c, 0.8)
	var low := INF
	for p in grown:
		low = minf(low, world.ground_height(p.x, p.y))
	_prism(st, grown, minf(low, y0 - 0.1) - 0.5, y0)
	var box := _outline_box(grown)
	_box_shape(entry, Vector3(box.size.x, 0.6, box.size.y), Transform3D(Basis(), Vector3(box.get_center().x, y0 - 0.3, box.get_center().y)))


## The distance from the middle of a place to its farthest edge.
func _radius(entry: Dictionary) -> float:
	if entry.has("plaza"):
		return float(entry.plaza)
	var c := Vector2(entry.get("center", Vector3.ZERO).x, entry.get("center", Vector3.ZERO).z)
	var r := 2.0
	for p: Array in entry.record.get("outline", []):
		r = maxf(r, c.distance_to(Vector2(p[0], p[1])))
	return r


func _center(record: Dictionary) -> Vector2:
	var outline: Array = record.get("outline", [])
	if outline.size() < 3:
		return Vector2(record.position[0], record.position[1])
	var sum := Vector2.ZERO
	var n := 0
	for p: Array in outline:
		sum += Vector2(p[0], p[1])
		n += 1
	return sum / float(n)


static func _grow(points: PackedVector2Array, c: Vector2, by: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(p + (p - c).normalized() * by)
	return result


static func _outline_box(points: PackedVector2Array) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	return box


## The angle of the longest side of the outline, from +x (radians, in the x-z plane).
static func _long_side_angle(record: Dictionary) -> float:
	var outline: Array = record.get("outline", [])
	var best := 0.0
	var best_len := 0.0
	for i in outline.size() - 1:
		var a := Vector2(outline[i][0], outline[i][1])
		var b := Vector2(outline[i + 1][0], outline[i + 1][1])
		if a.distance_to(b) > best_len:
			best_len = a.distance_to(b)
			best = atan2(b.y - a.y, b.x - a.x)
	return best


func _lowest_around(c: Vector2, radius: float) -> float:
	var low := INF
	for p in ring_points(c, radius, 16):
		low = minf(low, world.ground_height(p.x, p.y))
	return low


func _cylinder_shape(entry: Dictionary, c: Vector2, r: float, y0: float, y1: float) -> void:
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = r
	cylinder.height = y1 - y0
	shape.shape = cylinder
	shape.position = Vector3(c.x, (y0 + y1) / 2.0, c.y)
	_body(entry).add_child(shape)


# --- The ground parts (R6, R15) ------------------------------------------------------

## The stairs on an OSM line of steps: the height of the line follows the
## ground, with a landing at each turn; the steps are 15 cm to 18 cm high.
func _stairs(entry: Dictionary, road: Dictionary) -> void:
	var line := PackedVector3Array()
	for p: Array in road.points:
		line.append(Vector3(p[0], world.ground_height(p[0], p[2]) + STAIR_LIFT, p[2]))
	if line.size() < 2:
		return
	var width := maxf(float(road.get("width", 2.0)), 1.5)
	var profile := stair_profile(line)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for tread: Dictionary in profile.treads:
		var a: Vector3 = tread.from
		var b: Vector3 = tread.to
		var along := Vector3(b.x - a.x, 0.0, b.z - a.z)
		var run := along.length()
		if run < 0.05:
			continue
		var top := float(tread.height)
		var mid := (a + b) / 2.0
		_add_box(st, {"center": Vector3(mid.x, top - 0.3, mid.z), "size": Vector3(run + 0.02, 0.6, width),
				"turn": atan2(along.z, along.x)})
		count += 1
	st.generate_normals()
	var mesh := st.commit()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, _material(_color(entry.place, "steps", "#A9A59B")))
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.name = "Stairs_%d" % int(road.id)
		instance.visibility_range_end = NEAR_END
		(entry.node as Node3D).add_child(instance)
	# The collision: one surface on the noses of the steps (R7), with no edges
	# at the joints, and the invisible slopes at its two sides.
	var walk := PackedVector3Array()
	for p: Vector3 in profile.walk:
		if walk.is_empty() or _flat(p).distance_to(_flat(walk[walk.size() - 1])) > 0.02:
			walk.append(p)
	_stair_surface(entry, walk, width)
	stairs.append({"way": int(road.id), "place": entry.id, "points": walk, "steps": profile.steps, "width": width})


## The collision of stairs (R7): a height map, as the ground has. In the
## width of the stairs, a cell has the height of the nearest point of the walk
## line (the noses of the steps). In SKIRT_M beside the stairs, the height goes
## from the edge to the ground (at most SKIRT_M * 0.8 down or up), so that a
## player who walks beside the stairs can walk onto them. Farther out, the map
## is under the ground. Boxes on each part of the line had edges at the joints,
## and one surface on the line had steep folds on the inner side of a bend.
func _stair_surface(entry: Dictionary, walk: PackedVector3Array, width: float) -> void:
	if walk.size() < 2:
		return
	var half := width / 2.0
	var reach := half + SKIRT_M
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for p in walk:
		low = Vector2(minf(low.x, p.x), minf(low.y, p.z))
		high = Vector2(maxf(high.x, p.x), maxf(high.y, p.z))
	low -= Vector2.ONE * (reach + STAIR_CELL)
	high += Vector2.ONE * (reach + STAIR_CELL)
	var nx := ceili((high.x - low.x) / STAIR_CELL) + 1
	var nz := ceili((high.y - low.y) / STAIR_CELL) + 1
	var best_d := PackedFloat32Array()
	var best_h := PackedFloat32Array()
	best_d.resize(nx * nz)
	best_d.fill(INF)
	best_h.resize(nx * nz)
	for i in walk.size() - 1:
		var a := walk[i]
		var b := walk[i + 1]
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var ab := b2 - a2
		var length2 := maxf(ab.length_squared(), 0.0001)
		var c0 := maxi(0, floori((minf(a.x, b.x) - reach - low.x) / STAIR_CELL))
		var c1 := mini(nx - 1, ceili((maxf(a.x, b.x) + reach - low.x) / STAIR_CELL))
		var r0 := maxi(0, floori((minf(a.z, b.z) - reach - low.y) / STAIR_CELL))
		var r1 := mini(nz - 1, ceili((maxf(a.z, b.z) + reach - low.y) / STAIR_CELL))
		for r in range(r0, r1 + 1):
			for c in range(c0, c1 + 1):
				var q := Vector2(low.x + c * STAIR_CELL, low.y + r * STAIR_CELL)
				var t := clampf((q - a2).dot(ab) / length2, 0.0, 1.0)
				var d := q.distance_to(a2 + ab * t)
				var k := r * nx + c
				if d < best_d[k]:
					best_d[k] = d
					best_h[k] = lerpf(a.y, b.y, t)
	# Farther out, the map is far under the ground (the ground has its own collision).
	var deep := INF
	for p in walk:
		deep = minf(deep, p.y)
	deep -= 20.0
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for r in nz:
		for c in nx:
			var k := r * nx + c
			var d := best_d[k]
			var h := best_h[k]
			if d <= half:
				heights[k] = h
			elif d <= reach:
				var x := low.x + c * STAIR_CELL
				var z := low.y + r * STAIR_CELL
				var g := clampf(world.ground_height(x, z), h - SKIRT_M * 0.8, h + SKIRT_M * 0.8)
				heights[k] = lerpf(h, g, (d - half) / SKIRT_M)
			else:
				heights[k] = deep
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	var scaled := PackedFloat32Array()
	scaled.resize(heights.size())
	for k in heights.size():
		scaled[k] = heights[k] / STAIR_CELL
	shape.map_data = scaled
	var node := CollisionShape3D.new()
	node.shape = shape
	# Godot puts the middle of the map at the origin of the node, with 1 m
	# between samples: the node has a uniform scale of STAIR_CELL.
	var center := Vector3(low.x + (nx - 1) * STAIR_CELL / 2.0, 0.0, low.y + (nz - 1) * STAIR_CELL / 2.0)
	node.transform = Transform3D(Basis().scaled(Vector3.ONE * STAIR_CELL), center)
	_body(entry).add_child(node)


## The treads of stairs on a line: {"treads": [{"from", "to", "height"}],
## "walk": the line of the noses of the steps, "steps": the count of steps}.
## All steps of the stairs have the same height, STEP_MIN to STEP_MAX (from
## the rise of the whole stairs). The steps follow the ground: along the line,
## a step goes up or down where the ground is more than STEP_FOLLOW of a step
## from the tread, with a tread of TREAD_M or more. A turn of more than
## TURN_DEG has a flat landing of LANDING_M (R6), with no step on it, at the
## ground of its middle (_stair_goal()).
static func stair_profile(line: PackedVector3Array) -> Dictionary:
	var s := PackedFloat32Array([0.0])
	for i in range(1, line.size()):
		s.append(s[i - 1] + Vector2(line[i].x - line[i - 1].x, line[i].z - line[i - 1].z).length())
	var total := s[s.size() - 1]
	var landings: Array[Vector2] = []  # [from, to] along the line
	for i in range(1, line.size() - 1):
		var d0 := Vector2(line[i].x - line[i - 1].x, line[i].z - line[i - 1].z)
		var d1 := Vector2(line[i + 1].x - line[i].x, line[i + 1].z - line[i].z)
		if d0.length() > 0.01 and d1.length() > 0.01 and absf(rad_to_deg(d0.angle_to(d1))) > TURN_DEG:
			var a := maxf(s[i] - LANDING_M / 2.0, 0.0)
			var b := minf(s[i] + LANDING_M / 2.0, total)
			if not landings.is_empty() and a <= landings[-1].y:
				landings[-1].y = b
			else:
				landings.append(Vector2(a, b))
	var base := line[0].y
	var rise := absf(_height_at(line, s, total) - base)
	var step := STEP
	var steps := roundi(rise / STEP)
	if steps > 0 and rise / steps >= STEP_MIN and rise / steps <= STEP_MAX:
		step = rise / steps
	var treads: Array[Dictionary] = []
	var walk := PackedVector3Array([_point_at(line, s, 0.0, base)])
	var h := base
	var tread_from := 0.0
	var count := 0
	var at := TREAD_M
	while at < total - 0.01:
		var on_landing := false
		for l: Vector2 in landings:
			if at >= l.x - 0.01 and at <= l.y + 0.01:
				on_landing = true
		var gap := _stair_goal(line, s, landings, at) - h
		# A tread is TREAD_M or more in a straight line: at a bend of the line,
		# the length along the line is longer than the tread. Steps that are
		# more than two steps from the ground (after landings) catch up with
		# treads of TREAD_FAST_M.
		var tread := TREAD_FAST_M if absf(gap) > step * 2.0 else TREAD_M
		var far := _flat(_point_at(line, s, at, h)).distance_to(_flat(walk[walk.size() - 1])) >= tread
		if not on_landing and far and absf(gap) > step * STEP_FOLLOW:
			treads.append({"from": _point_at(line, s, tread_from, h), "to": _point_at(line, s, at, h), "height": h})
			h += signf(gap) * step
			walk.append(_point_at(line, s, at, h))
			tread_from = at
			count += 1
		at += 0.05
	# The top: the steps that are left, if the ground there is higher or lower,
	# with treads of TREAD_M or more.
	var end_h := base + roundf((_height_at(line, s, total) - base) / step) * step
	while absf(end_h - h) > step * 0.5:
		var nose := tread_from + maxf(TREAD_M, (total - tread_from) / 2.0)
		if nose > total - 0.05 or _flat(_point_at(line, s, nose, h)).distance_to(_flat(walk[walk.size() - 1])) < TREAD_M * 0.99:
			break
		treads.append({"from": _point_at(line, s, tread_from, h), "to": _point_at(line, s, nose, h), "height": h})
		h += signf(end_h - h) * step
		walk.append(_point_at(line, s, nose, h))
		tread_from = nose
		count += 1
	treads.append({"from": _point_at(line, s, tread_from, h), "to": _point_at(line, s, total, h), "height": h})
	walk.append(_point_at(line, s, total, h))
	return {"treads": treads, "walk": walk, "steps": count}


## The height that the steps follow at "at": the ground, but not lower than a
## slope of LEAD_GRADE down from each landing. A landing has the ground of its
## middle, and the steps climb to it in time (the ground of the cut climbs 0.5
## at most, so the steps come back to the ground soon after the landing).
static func _stair_goal(line: PackedVector3Array, s: PackedFloat32Array, landings: Array[Vector2], at: float) -> float:
	var goal := _height_at(line, s, at)
	for l: Vector2 in landings:
		var top := _height_at(line, s, (l.x + l.y) / 2.0)
		var away := l.x - at if at < l.x else (at - l.y if at > l.y else 0.0)
		goal = maxf(goal, top - away * LEAD_GRADE)
	return goal


static func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


static func _height_at(line: PackedVector3Array, s: PackedFloat32Array, at: float) -> float:
	for i in range(1, line.size()):
		if at <= s[i] or i == line.size() - 1:
			var t := clampf((at - s[i - 1]) / maxf(s[i] - s[i - 1], 0.001), 0.0, 1.0)
			return lerpf(line[i - 1].y, line[i].y, t)
	return line[0].y


static func _point_at(line: PackedVector3Array, s: PackedFloat32Array, at: float, height: float) -> Vector3:
	for i in range(1, line.size()):
		if at <= s[i] or i == line.size() - 1:
			var t := clampf((at - s[i - 1]) / maxf(s[i] - s[i - 1], 0.001), 0.0, 1.0)
			var p := line[i - 1].lerp(line[i], t)
			return Vector3(p.x, height, p.z)
	return Vector3(line[0].x, height, line[0].z)


## The jetty of Cầu Đá (R6, R15): a deck of the top width on the OSM line of
## the old stone jetty, over the highest tide, with a stone edge and walls that
## keep the player on it. The land end of the OSM line is in the sea: the deck
## goes on along the line to the shore (Q4), and goes down to the ground there.
func _jetty(entry: Dictionary) -> void:
	var record: Dictionary = entry.record
	var points: Array = record.get("line", [])
	if points.size() < 2:
		push_error("KnownPlaces: the jetty \"%s\" has no line." % entry.id)
		return
	var width := _size(entry.place, "top_width", 4.0)
	var high := float(world.data.world.get("sea_floor", {}).get("game_tide_m", [0.0, 1.4])[1])
	var deck := high + JETTY_OVER_TIDE
	var line := PackedVector3Array()
	for p: Array in points:
		line.append(Vector3(p[0], deck, p[1]))
	# The land end: the end with the higher ground.
	var g0 := world.ground_height(line[0].x, line[0].z)
	var g1 := world.ground_height(line[line.size() - 1].x, line[line.size() - 1].z)
	if g1 > g0:
		line.reverse()
	# On along the line to the shore: the first point with ground over the highest tide.
	var out := Vector3(line[0].x - line[1].x, 0.0, line[0].z - line[1].z).normalized()
	var shore := Vector3.INF
	for k in range(1, 151):
		var p := line[0] + out * float(k)
		var g := world.ground_height(p.x, p.z)
		if g > high + 0.2:
			shore = Vector3(p.x, maxf(g, deck - 3.0), p.z) + out * 2.0
			shore.y = world.ground_height(shore.x, shore.z)
			break
	if shore != Vector3.INF:
		line.insert(0, shore)
	var stone := _color(entry.place, "stone", "#8E8A80")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var low := deck - 6.0
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		# The parts overlap at the joints, but not at the two ends.
		if i > 0:
			a -= dir * (width * 0.25)
		if i < line.size() - 2:
			b += dir * (width * 0.25)
		var d := b - a
		var flat := Vector2(d.x, d.z).length()
		if flat < 0.05:
			continue
		var turn := atan2(d.z, d.x)
		var tilt := atan2(d.y, flat)
		var mid := (a + b) / 2.0
		var side := Vector3(-d.z, 0.0, d.x).normalized()
		var length := d.length()
		var body_low := minf(low, minf(a.y, b.y) - 2.0)
		# The stone body under the deck: its top has the slope of the deck.
		var deck_basis := Basis(Vector3.UP, -turn) * Basis(Vector3.BACK, tilt)
		var body_height := mid.y - body_low
		_add_box(st, {"center": mid - deck_basis.y * (body_height / 2.0), "size": Vector3(length, body_height, width),
				"turn": turn, "tilt": tilt})
		for k: float in [-1.0, 1.0]:
			var edge := mid + side * k * (width / 2.0 - 0.15)
			_add_box(st, {"center": edge + Vector3(0, JETTY_CURB / 2.0, 0), "size": Vector3(length + 0.3, JETTY_CURB, 0.3), "turn": turn, "tilt": tilt})
			_box_shape(entry, Vector3(length + 0.3, JETTY_WALL + 0.6, 0.3),
					Transform3D(deck_basis, edge + deck_basis.y * ((JETTY_WALL + 0.6) / 2.0 - 0.3)))
		_box_shape(entry, Vector3(length, 0.6, width), Transform3D(deck_basis, mid - deck_basis.y * 0.3))
	# The end wall at the sea end.
	var last := line[line.size() - 1]
	var before := line[line.size() - 2]
	var end_dir := Vector3(last.x - before.x, 0.0, last.z - before.z).normalized()
	_box_shape(entry, Vector3(0.3, JETTY_WALL + 0.6, width + 0.6),
			Transform3D(Basis(Vector3.UP, -atan2(end_dir.z, end_dir.x)), last + end_dir * 0.15 + Vector3(0, (JETTY_WALL + 0.6) / 2.0 - 0.3, 0)))
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _material(stone))
	_add_mesh(entry, mesh, false)
	_add_mesh(entry, mesh.duplicate() as ArrayMesh, true)
	jetty.line = line
	jetty.deck = deck
	jetty.width = width
	jetty.shore = shore != Vector3.INF
	entry.base = deck
	entry.top = deck + 1.0
	entry.center = (line[0] + line[line.size() - 1]) / 2.0


## The height of the floor of a place at a game point (x, z): the deck of
## the jetty or the stairs. -INF where no place has a floor. The player can
## stand on such a floor over deep water (VungTau.can_stand()).
func floor_at(x: float, z: float) -> float:
	var best := -INF
	if not jetty.is_empty():
		best = _line_floor(jetty.line, float(jetty.width) / 2.0, Vector2(x, z))
	for s: Dictionary in stairs:
		best = maxf(best, _line_floor(s.points, float(s.width) / 2.0, Vector2(x, z)))
	return best


## The height of a walk line at a point within "half" of it, or -INF: the
## height at the nearest point of the line (on stairs, the steps farther up
## are also within "half").
static func _line_floor(line: PackedVector3Array, half: float, at: Vector2) -> float:
	var best := -INF
	var nearest := half
	for i in line.size() - 1:
		var a := Vector2(line[i].x, line[i].z)
		var b := Vector2(line[i + 1].x, line[i + 1].z)
		var c := Geometry2D.get_closest_point_to_segment(at, a, b)
		var d := c.distance_to(at)
		if d > nearest + 0.001:
			continue
		var t := 0.0 if a.is_equal_approx(b) else clampf((c - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		var h := lerpf(line[i].y, line[i + 1].y, t)
		# Two parts at the same distance (a joint): the higher one.
		best = h if d < nearest - 0.001 else maxf(best, h)
		nearest = minf(nearest, d)
	return best


# --- Mesh helpers --------------------------------------------------------------

## A vertical prism of a polygon in the x-z plane, from y0 to y1 (sides and top).
static func _prism(st: SurfaceTool, points: PackedVector2Array, y0: float, y1: float) -> void:
	var n := points.size()
	if n < 3:
		return
	var area := 0.0
	for i in n:
		area += points[i].x * points[(i + 1) % n].y - points[(i + 1) % n].x * points[i].y
	var ccw := area > 0.0
	for i in n:
		var a := points[i]
		var b := points[(i + 1) % n]
		var p0 := Vector3(a.x, y0, a.y)
		var p1 := Vector3(b.x, y0, b.y)
		var p2 := Vector3(b.x, y1, b.y)
		var p3 := Vector3(a.x, y1, a.y)
		if ccw:
			st.add_vertex(p0); st.add_vertex(p2); st.add_vertex(p1)
			st.add_vertex(p0); st.add_vertex(p3); st.add_vertex(p2)
		else:
			st.add_vertex(p0); st.add_vertex(p1); st.add_vertex(p2)
			st.add_vertex(p0); st.add_vertex(p2); st.add_vertex(p3)
	var tris := Geometry2D.triangulate_polygon(points)
	for t in range(0, tris.size(), 3):
		var a := points[tris[t]]
		var b := points[tris[t + 1]]
		var c := points[tris[t + 2]]
		var ab := b - a
		var ac := c - a
		if ab.x * ac.y - ab.y * ac.x > 0.0:
			st.add_vertex(Vector3(a.x, y1, a.y)); st.add_vertex(Vector3(c.x, y1, c.y)); st.add_vertex(Vector3(b.x, y1, b.y))
		else:
			st.add_vertex(Vector3(a.x, y1, a.y)); st.add_vertex(Vector3(b.x, y1, b.y)); st.add_vertex(Vector3(c.x, y1, c.y))


## A wall from a to b (x-z), from y0 to y1, with a thickness.
static func _wall(st: SurfaceTool, a: Vector2, b: Vector2, y0: float, y1: float, thickness: float) -> void:
	var d := b - a
	var mid := (a + b) / 2.0
	_add_box(st, {"center": Vector3(mid.x, (y0 + y1) / 2.0, mid.y), "size": Vector3(d.length(), y1 - y0, thickness), "turn": atan2(d.y, d.x)})


## A box: {"center", "size" (along the turn, up, across), "turn" (radians from +x in x-z), "tilt" (radians, optional)}.
static func _add_box(st: SurfaceTool, box: Dictionary) -> void:
	var size: Vector3 = box.size / 2.0
	var basis := Basis(Vector3.UP, -float(box.get("turn", 0.0)))
	if box.has("tilt"):
		basis = basis * Basis(Vector3.BACK, float(box.tilt))
	var c: Vector3 = box.center
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(c + basis * Vector3(size.x * (1 if i & 1 else -1), size.y * (1 if i & 2 else -1), size.z * (1 if i & 4 else -1)))
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for f: Array in faces:
		var q := [corners[f[0]], corners[f[1]], corners[f[2]], corners[f[3]]]
		# Godot draws the faces with a clockwise order seen from the outside.
		st.add_vertex(q[0]); st.add_vertex(q[1]); st.add_vertex(q[2])
		st.add_vertex(q[0]); st.add_vertex(q[2]); st.add_vertex(q[3])


# --- The Lens (D6) and the views (D4) --------------------------------------------------

## The place in the middle of the view: the place whose middle is nearest to
## the view direction, within 6° and 4 km, that the ground does not hide.
func place_in_view(eye: Vector3, forward: Vector3, max_deg := 6.0) -> String:
	var best := ""
	var best_angle := max_deg
	for id: String in places:
		var entry: Dictionary = places[id]
		if not entry.has("center"):
			continue
		var target: Vector3 = entry.center + Vector3(0, (float(entry.top) - float(entry.base)) * 0.6, 0)
		var to := target - eye
		if to.length() > FAR_END:
			continue
		var angle := rad_to_deg(forward.angle_to(to))
		if angle < best_angle and seen(eye, target):
			best_angle = angle
			best = id
	return best


## True when the ground of the game does not hide the point from the eye
## (the same test as tools/geo/geodata/visibility.py, R8).
func seen(eye: Vector3, target: Vector3, step := 1.0) -> bool:
	var flat := Vector2(target.x - eye.x, target.z - eye.z).length()
	var n := maxi(1, int(flat / step))
	for k in range(1, n):
		var t := float(k) / n
		if flat * (1.0 - t) < 3.0:
			break
		var p := eye.lerp(target, t)
		if world.ground_height(p.x, p.z) > p.y:
			return false
	return true


## The part of the points from the ground of a target to its top that the eye
## sees (R8: the same rays as the tools).
func seen_part(eye: Vector3, base: Vector3, top_m: float, samples := 10, step := 1.0) -> float:
	var count := 0
	for i in samples:
		if seen(eye, base + Vector3(0, top_m * (i + 1) / samples, 0), step):
			count += 1
	return float(count) / samples


## The Lens card of a place (D6): {kind: "spot", id, line, name, en, status, text}.
func card(id: String) -> Dictionary:
	if not places.has(id):
		return {}
	var entry: Dictionary = places[id]
	var place: Dictionary = entry.place
	var lens: Dictionary = place.get("lens", {})
	var note := str(configs_note())
	var text := str(lens.get("text", ""))
	if place.get("model") == null and note != "":
		text += " " + note
	return {"kind": "spot", "id": "place." + id, "line": "", "name": str(entry.config.name_vi),
			"en": str(place.get("name_en", "")),
			"status": "%s: %s" % [lens.get("phrase_vi", ""), lens.get("phrase_en", "")], "text": text}


static var _note := ""


## The note of a stand-in in the Lens card (D3a): "stand_in_note" of the file.
static func configs_note(path := CONFIG) -> String:
	if _note == "":
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_note = str(parsed.get("stand_in_note", "")) if parsed is Dictionary else ""
	return _note


## The card of the place in the view, or {}.
func lens_card(eye: Vector3, forward: Vector3) -> Dictionary:
	var id := place_in_view(eye, forward)
	return card(id) if id != "" else {}
