class_name StreetHouses
extends Node3D
## Plan 0009, phase 3 (R7 to R9): the houses of World on the lots of the
## streets (data/geo/build/houses.json, tools/geo/geodata/street_houses.py).
##
## The near and the mid levels of the houses are in a WorldRow (MultiMeshes in
## cells). Past the mid range each lot is a box with the colors of the town,
## to the range of the town, so the far town keeps its look; TownField leaves
## out the boxes of the town under the lots (footprints are kept parts). Each
## house has a solid box: the player walks on the sidewalk and the street,
## not through a house (report 0009, section 8.6).

const FILE := "houses.json"
## The ranges of the levels of a house (near, mid) for each preset (m); the
## box of the lot shows from the mid range to the range of the town.
const RANGES := {
	"low": Vector2(0.0, 60.0),
	"medium": Vector2(20.0, 90.0),
	"high": Vector2(30.0, 120.0),
	"ultra": Vector2(40.0, 160.0),
}
## The boxes of the lots are in squares of this size (m): a visibility range is for a node.
const BOX_CELL := 32.0
## The roof of the box of a lot from far (a flat terrace of the palette).
const ROOF_COLOR := Color("#8C8A84")

## The streets of the file (id, name, ways, length_m, width_m, houses).
var streets: Array = []
## Each house of the file that the game builds (with its "paint").
var houses: Array[Dictionary] = []
## The outline of each house (game x, z): the town leaves out its boxes there.
var footprints: Array[PackedVector2Array] = []
var row: WorldRow
var body: StaticBody3D
## The boxes of the lots from far, by square.
var far_boxes: Array[MeshInstance3D] = []
## The houses that the file has and the game does not build (no files of the
## model yet, or a part of the world that draws its own building there).
var skipped := 0
## The triangles of the boxes from far.
var box_triangles := 0
var _material: StandardMaterial3D


func setup(w: VungTau) -> bool:
	var path := w.data.root.path_join(FILE)
	if not GeoData.has_file(path):
		return false
	var parsed: Variant = JSON.parse_string(GeoData.read_text(path))
	if not parsed is Dictionary:
		push_error("StreetHouses: %s cannot be read." % path)
		return false
	streets = parsed.get("streets", [])
	var palette: Variant = JSON.parse_string(GeoData.read_text("res://data/world/palette.json"))
	var walls: Array = palette.get("walls", []) if palette is Dictionary else []
	# The ground floor and the top of each model over the lowest point of its mid level.
	var sizes := {}
	for model_id: String in parsed.get("models", []):
		if not Showcase._has_model(model_id):
			continue
		var template := WorldModel.make(model_id, WorldMaterials.DEFAULT_PAINT, "house")
		if template == null:
			continue
		var mid := template.level("mid")
		var box := template.level_aabb("mid")
		# WorldModel puts the lowest point (the footing) on y = 0: the ground floor of World is at the lift.
		var sink := mid.position.y if mid != null else 0.0
		sizes[model_id] = {"sink": sink, "height": box.end.y - sink}
		template.free()
	row = WorldRow.new()
	row.name = "Houses"
	# Cells of 40 m: each cell has a MultiMesh for each mesh of each model (the
	# draw calls of PT-69); the houses of plan 0009 use the set "house" (R7a).
	row.cell_size = 40.0
	row.material_set = "house"
	for preset: String in RANGES:
		var r: Vector2 = RANGES[preset]
		row.custom_ranges[preset] = Vector3(r.x, r.y, r.y)
	add_child(row)
	body = StaticBody3D.new()
	body.name = "HouseSolids"
	body.collision_layer = Layers.SOLID
	body.collision_mask = 0
	add_child(body)
	for house: Dictionary in parsed.get("houses", []):
		if not sizes.has(house.model):
			skipped += 1
			continue
		var ring := PackedVector2Array()
		for p: Array in house.outline:
			ring.append(Vector2(p[0], p[1]))
		var size: Dictionary = sizes[house.model]
		var scale_v := Vector3(house.scale[0], house.scale[1], house.scale[2])
		var basis := Basis(Vector3.UP, deg_to_rad(float(house.yaw))).scaled(scale_v)
		var at := Transform3D(basis, Vector3(house.x, float(house.base) - float(size.sink) * scale_v.y, house.z))
		var paint := _paint(str(house.id), walls)
		row.add(house.model, at, paint)
		house["paint"] = paint
		house["top"] = float(house.base) + float(size.height) * scale_v.y
		houses.append(house)
		footprints.append(ring)
		_add_solid(house, ring)
	row.build()
	_make_far_boxes()
	# WorldModel.set_ranges() calls apply_ranges() on the nodes of this group.
	add_to_group(WorldRow.GROUP)
	return true


## The wall paint of a house: a color of the palette by the id of the lot (D8).
static func _paint(lot_id: String, walls: Array) -> Color:
	if walls.is_empty():
		return WorldMaterials.DEFAULT_PAINT
	var total := 0.0
	for w: Dictionary in walls:
		total += float(w.get("weight", 1.0))
	var pick := float(hash(lot_id + "paint") & 0xFFFF) / 65535.0 * total
	for w: Dictionary in walls:
		pick -= float(w.get("weight", 1.0))
		if pick <= 0.0:
			return Color(str(w.color))
	return Color(str(walls[-1].color))


## A solid box on the lot, from the base to the top of the house.
func _add_solid(house: Dictionary, ring: PackedVector2Array) -> void:
	var middle := Vector2.ZERO
	for p in ring:
		middle += p / ring.size()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var height := float(house.top) - float(house.base)
	box.size = Vector3(float(house.width), height, float(house.depth))
	shape.shape = box
	shape.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(house.yaw))),
			Vector3(middle.x, float(house.base) + height / 2.0, middle.y))
	body.add_child(shape)


## The boxes of the lots from far (walls of the paint, a flat roof), in squares
## of BOX_CELL, from the mid range to the range of the town.
func _make_far_boxes() -> void:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.92
	var squares := {}
	for i in houses.size():
		var c: Vector2 = footprints[i][0]
		var key := Vector2i(floori(c.x / BOX_CELL), floori(c.y / BOX_CELL))
		if not squares.has(key):
			squares[key] = []
		squares[key].append(i)
	for key: Vector2i in squares:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var center := Vector3((key.x + 0.5) * BOX_CELL, 0.0, (key.y + 0.5) * BOX_CELL)
		for i: int in squares[key]:
			_add_box(tool, footprints[i], float(houses[i].base), float(houses[i].top), houses[i].paint, center)
		tool.generate_normals()
		var node := MeshInstance3D.new()
		node.name = "far_%d_%d" % [key.x, key.y]
		node.mesh = tool.commit()
		node.material_override = _material
		node.position = center
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		far_boxes.append(node)
	apply_ranges()


func _add_box(tool: SurfaceTool, ring: PackedVector2Array, base: float, top: float, paint: Color, center: Vector3) -> void:
	var n := ring.size()
	# The ring of the lot is in the order of the file; each wall faces out.
	var area := 0.0
	for e in n:
		area += ring[e].x * ring[(e + 1) % n].y - ring[(e + 1) % n].x * ring[e].y
	var order := range(n) if area < 0.0 else range(n - 1, -1, -1)
	var pts: Array[Vector3] = []
	for e in order:
		pts.append(Vector3(ring[e].x, 0.0, ring[e].y) - Vector3(center.x, 0.0, center.z))
	for e in n:
		var a := pts[e]
		var b := pts[(e + 1) % n]
		var quad := [Vector3(a.x, base, a.z), Vector3(b.x, base, b.z), Vector3(b.x, top, b.z), Vector3(a.x, top, a.z)]
		for k in [0, 2, 1, 0, 3, 2]:
			tool.set_color(paint.darkened(0.25) if k < 2 else paint)
			tool.add_vertex(quad[k])
		box_triangles += 2
	for e in range(1, n - 1):
		for p in [pts[0], pts[e + 1], pts[e]]:
			tool.set_color(ROOF_COLOR)
			tool.add_vertex(Vector3(p.x, top, p.z))
		box_triangles += 1


## The ranges of the preset: the boxes of the lots from the mid range of the
## houses to the range of the town.
func apply_ranges() -> void:
	var r: Vector2 = RANGES.get(WorldModel.preset, RANGES.low)
	for node in far_boxes:
		node.visibility_range_begin = r.y
		node.visibility_range_begin_margin = WorldModel.FADE
		node.visibility_range_end = TownField.range_end
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if row:
		row.apply_ranges()


## The index of the house whose lot has the point (game x, z), or -1.
func house_at(x: float, z: float) -> int:
	var p := Vector2(x, z)
	for i in footprints.size():
		if Geometry2D.is_point_in_polygon(p, footprints[i]):
			return i
	return -1
