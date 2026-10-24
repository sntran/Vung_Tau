class_name TubeHouse
extends Node3D
## One house of the hẻm, built from parameters and a seed with the house
## detail kit of plan 0004 (R7 to R10): a front wall with real depth, recessed
## windows, balconies, the ground floor, the roof, and the clutter of a real
## street. The kinds are a tube house (nhà ống), a villa, and a mini-hotel.
##
## The origin is the center of the front wall at the floor. The front faces +Z.
## A shop has a rolling metal shutter (cửa cuốn) with three positions. The
## ground floor of a shop is an open room that the player can walk into.

enum Shutter { OPEN, HALF, CLOSED }

## The ground floor opening of a shop.
const OPENING_HEIGHT := 2.6
## The rolled shutter box at the top of the opening.
const ROLL_HEIGHT := 0.3
## The height of the shutter in the HALF position.
const HALF_HEIGHT := 1.1
## The depth of the open room on the ground floor of a shop.
const ROOM_DEPTH := 4.0
## The thickness of the walls of the room.
const WALL := 0.2
## The thickness of the front wall. The windows are recessed into it.
const FRONT := 0.25
## The tiled step in front of the house: walkable (lower than Player.STEP_HEIGHT).
const STEP_HEIGHT := 0.08
const STEP_DEPTH := 0.3
## The time of the shutter animation in seconds.
const SHUTTER_SECONDS := 1.2

@export var width := 4.5
@export var floors := 3
@export var floor_height := 3.2
@export var depth := 12.0
@export_enum("gate", "shop", "wall") var ground := "gate"
@export var sign_text := ""
@export var sign_bg := Color("#C4362C")
@export var sign_fg := Color("#F2C33C")
@export var balcony := false
## "tube", "villa", or "hotel".
@export var kind := "tube"
## "old" (louvered wooden shutters) or "new" (glass with aluminum frames).
@export var style := "old"
@export var paint := Color("#E9E4DC")
## The second color of a striped wall, or the alpha 0 for no stripes.
@export var stripe := Color(0, 0, 0, 0)
## 0 is clean new paint. 1 is old, faded, and stained paint.
@export var paint_age := 0.4
@export var seed := 0
## "flat" (a roof terrace), "metal" (corrugated metal), or "tiles" (a pitched
## terracotta roof). Empty: from the kind and the seed.
@export var roof := ""
## "none", "ground" (tiles on the ground floor front), or "full" (the whole front).
@export var front_tiles := "none"
## The height of the house at each side (left is -X). The part of the side
## wall above the neighbor shows bare plaster or brick (R9). A negative value
## means the same height as this house.
@export var left_neighbor_height := -1.0
@export var right_neighbor_height := -1.0
## The colors of the accent parts. The alpha 0 means "from the palette".
@export var shutter_color := Color(0, 0, 0, 0)
@export var trim_color := Color(0, 0, 0, 0)

var shutter := Shutter.CLOSED
## The static body with the collision shapes of the house.
var solid: StaticBody3D
## The collector of the repeated small parts. The hẻm gives one for all houses.
var parts: HouseParts
## The meshes by material key, for the play tests and the look review.
var meshes: Dictionary = {}
## The axis-aligned boxes of the main parts in the local space, for PT-31:
## {name: AABB}.
var part_boxes: Dictionary = {}
var _shutter_node: MeshInstance3D
var _shutter_shape: CollisionShape3D
var _shutter_tween: Tween
var _glow_nodes: Array[Node3D] = []
var _built := false
var _own_parts := false
var _rng := RandomNumberGenerator.new()
var _batch := MeshBatch.new()
## The windows of an upper floor: [[center x, width]].
var _windows: Array = []
var _window_top := 2.4
var _sill := 0.9
var _recess := 0.2


func _ready() -> void:
	build()


## The height of the top of the front wall (without the parapet).
func wall_height() -> float:
	return floors * floor_height


## The height of the highest part of the house (the parapet or the roof).
func top_height() -> float:
	return wall_height() + _parapet_height() + (1.6 if _roof_kind() == "tiles" else 0.0)


## Makes the geometry and the collision shapes. The function does nothing
## when the house is already built.
func build() -> void:
	if _built:
		return
	_built = true
	_rng.seed = seed
	if parts == null:
		parts = HouseParts.new()
		parts.name = "Parts"
		add_child(parts)
		_own_parts = true
	if shutter_color.a == 0.0:
		shutter_color = HousePalette.accent("shutters", _rng)
	if trim_color.a == 0.0:
		trim_color = paint.darkened(0.12) if style == "old" else paint.lightened(0.1)
	_recess = _rng.randf_range(0.15, 0.25)
	solid = Greybox.solid_body(self)
	_plan_windows()
	_build_body()
	_build_front()
	match ground:
		"shop":
			_build_shop()
		"gate":
			_build_gate()
		"wall":
			_build_wall()
	for i in range(1, floors):
		_build_floor(i)
	_build_step()
	_build_roof()
	_build_side_walls()
	_build_clutter()
	if sign_text != "":
		_build_sign()
	meshes = _batch.commit(self, HouseMaterials.all(), "House")
	_set_instance_values()
	if _own_parts:
		parts.commit()
	set_shutter(shutter)
	set_glow(false)


# --- The plan of the front ----------------------------------------------------

func _plan_windows() -> void:
	_windows.clear()
	if kind == "hotel":
		# Many small windows: two on each floor.
		var w := minf(0.9, width * 0.22)
		_windows.append([-width * 0.24, w])
		_windows.append([width * 0.24, w])
		_sill = 1.0
		_window_top = 2.3
	else:
		_windows.append([0.0, clampf(width * 0.5, 1.4, 2.4)])
		_sill = 0.9
		_window_top = 2.4


func _roof_kind() -> String:
	if roof != "":
		return roof
	if kind == "villa":
		return "tiles"
	if kind == "hotel":
		return "flat"
	return "metal" if seed % 5 < 3 else "flat"


func _parapet_height() -> float:
	return 1.0 if _roof_kind() == "flat" else 0.45


func _front_key() -> String:
	return HouseMaterials.TILES if front_tiles == "full" else HouseMaterials.PLASTER


func _box(key: String, size: Vector3, center: Vector3, color := Color.WHITE, part := "") -> void:
	if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
		return
	_batch.box(key, size, center, color)
	if part != "":
		part_boxes[part] = AABB(center - size / 2.0, size)


# --- The body and the front wall --------------------------------------------------

## The house behind the front wall. A shop has an open room on the ground floor.
func _build_body() -> void:
	var height := wall_height()
	var back := depth - FRONT
	if ground == "shop":
		var upper := height - OPENING_HEIGHT
		_box(HouseMaterials.PLASTER, Vector3(width, upper, back), Vector3(0, OPENING_HEIGHT + upper / 2.0, -FRONT - back / 2.0),
				Color.WHITE, "body")
		var behind := depth - ROOM_DEPTH
		_box(HouseMaterials.PLASTER, Vector3(width, OPENING_HEIGHT, behind), Vector3(0, OPENING_HEIGHT / 2.0, -ROOM_DEPTH - behind / 2.0))
		for side: float in [-1.0, 1.0]:
			_box(HouseMaterials.PLASTER, Vector3(WALL, OPENING_HEIGHT, ROOM_DEPTH - FRONT),
					Vector3(side * (width - WALL) / 2.0, OPENING_HEIGHT / 2.0, -FRONT - (ROOM_DEPTH - FRONT) / 2.0))
		Greybox.solid_shape(solid, Vector3(width, upper, depth), Vector3(0, OPENING_HEIGHT + upper / 2.0, -depth / 2.0))
		Greybox.solid_shape(solid, Vector3(width, OPENING_HEIGHT, behind), Vector3(0, OPENING_HEIGHT / 2.0, -ROOM_DEPTH - behind / 2.0))
		for side: float in [-1.0, 1.0]:
			Greybox.solid_shape(solid, Vector3(WALL, OPENING_HEIGHT, ROOM_DEPTH),
					Vector3(side * (width - WALL) / 2.0, OPENING_HEIGHT / 2.0, -ROOM_DEPTH / 2.0))
	else:
		_box(HouseMaterials.PLASTER, Vector3(width, height, back), Vector3(0, height / 2.0, -FRONT - back / 2.0),
				Color.WHITE, "body")
		Greybox.solid_shape(solid, Vector3(width, height, depth), Vector3(0, height / 2.0, -depth / 2.0))


## The front wall of the upper floors, with openings for the windows, the
## floor lines, and the parapet.
func _build_front() -> void:
	var key := _front_key()
	var z := -FRONT / 2.0
	var half := width / 2.0
	for i in range(1, floors):
		var y0 := i * floor_height
		var sill := _sill_of(i)
		var top := y0 + _window_top
		# Below the windows, above the windows, and the piers between them.
		_box(key, Vector3(width, sill - y0, FRONT), Vector3(0, (y0 + sill) / 2.0, z))
		_box(key, Vector3(width, y0 + floor_height - top, FRONT), Vector3(0, (top + y0 + floor_height) / 2.0, z))
		var left := -half
		for window: Array in _windows:
			var x0: float = window[0] - window[1] / 2.0
			_box(key, Vector3(x0 - left, top - sill, FRONT), Vector3((left + x0) / 2.0, (sill + top) / 2.0, z))
			left = window[0] + window[1] / 2.0
		_box(key, Vector3(half - left, top - sill, FRONT), Vector3((left + half) / 2.0, (sill + top) / 2.0, z))
		# The floor line sticks out a little from the wall.
		_box(HouseMaterials.DETAIL, Vector3(width + 0.04, 0.12, 0.08), Vector3(0, y0 + 0.02, 0.04), trim_color)
	# The parapet at the top of the front wall.
	var height := wall_height()
	var parapet := _parapet_height()
	_box(key, Vector3(width, parapet, FRONT), Vector3(0, height + parapet / 2.0, z), Color.WHITE, "parapet")
	_box(HouseMaterials.DETAIL, Vector3(width + 0.06, 0.08, FRONT + 0.06), Vector3(0, height + parapet + 0.04, z), trim_color)


## The height of the sill of the window on the floor. A balcony has a door.
func _sill_of(floor_index: int) -> float:
	var y0 := floor_index * floor_height
	return y0 + (0.05 if _has_balcony(floor_index) else _sill)


func _has_balcony(floor_index: int) -> bool:
	if floor_index < 1:
		return false
	if kind == "hotel":
		return floor_index % 2 == 0
	return balcony


# --- The ground floor ----------------------------------------------------------------

func _build_shop() -> void:
	var key := _front_key()
	var w := width - WALL * 2.0
	# The front wall above the opening.
	var above := floor_height - OPENING_HEIGHT
	if floors > 1:
		_box(key, Vector3(width, above, FRONT), Vector3(0, OPENING_HEIGHT + above / 2.0, -FRONT / 2.0))
	else:
		_box(key, Vector3(width, 0.4, FRONT), Vector3(0, OPENING_HEIGHT + 0.2, -FRONT / 2.0))
	_build_ground_piers(WALL, OPENING_HEIGHT)
	var interior := Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	# The inside faces of the room: a tile floor, a back wall, and a ceiling.
	Greybox.box(interior, Vector3(w, 0.02, ROOM_DEPTH), Vector3(0, 0.01, -ROOM_DEPTH / 2.0),
			Color("#D8CFC0"), "RoomFloor")
	Greybox.box(interior, Vector3(w, OPENING_HEIGHT, 0.02), Vector3(0, OPENING_HEIGHT / 2.0, -ROOM_DEPTH + 0.01),
			Color("#E8DCC8"), "RoomBack")
	Greybox.box(interior, Vector3(w, 0.02, ROOM_DEPTH), Vector3(0, OPENING_HEIGHT - 0.01, -ROOM_DEPTH / 2.0),
			Color("#F2EEE6"), "RoomCeiling")
	# The counter with the pot at the back, a table, and stools.
	Greybox.solid_box(interior, solid, Vector3(w * 0.45, 0.9, 0.6), Vector3(-w * 0.2, 0.45, -ROOM_DEPTH + 0.5),
			Color("#C9D1D3"), "Counter")
	Greybox.cylinder(interior, 0.22, 0.4, Vector3(-w * 0.2, 1.1, -ROOM_DEPTH + 0.5), Color("#B7BFC1"), "Pot")
	Greybox.solid_box(interior, solid, Vector3(0.9, 0.62, 0.6), Vector3(w * 0.18, 0.31, -1.8),
			Color("#C9D1D3"), "Table")
	for x: float in [w * 0.18 - 0.6, w * 0.18 + 0.6]:
		Greybox.stool(interior, Vector3(x, 0, -1.8), Color("#D8433A") if x < w * 0.18 else Color("#2F72C4"))
		Greybox.solid_shape(solid, Vector3(0.3, 0.32, 0.3), Vector3(x, 0.16, -1.8))
	var lamp := Greybox.lamp(interior, Vector3(w * 0.6, 0.06, 0.06), Vector3(0, OPENING_HEIGHT - 0.1, -2.0),
			Color("#FFE7A0"), "Lamp")
	_glow_nodes.append(lamp)
	# The rolled shutter box is inside the top of the opening, behind the
	# front, so that the sign in front of the wall does not touch it.
	_box(HouseMaterials.METAL, Vector3(w, ROLL_HEIGHT, 0.3), Vector3(0, OPENING_HEIGHT - ROLL_HEIGHT / 2.0, -FRONT - 0.15),
			Color("#8E979A"), "shutter_roll")
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, 1.0, 0.03)
	_shutter_node = MeshInstance3D.new()
	_shutter_node.name = "Shutter"
	_shutter_node.mesh = mesh
	_shutter_node.material_override = _shutter_material()
	add_child(_shutter_node)
	# The shutter stops the player when it is closed or half open.
	_shutter_shape = Greybox.solid_shape(solid, Vector3(w, OPENING_HEIGHT, 0.1), Vector3(0, OPENING_HEIGHT / 2.0, 0.05))
	_build_awning(w)


## A shutter with horizontal slats.
func _shutter_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var image := Image.create(4, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		var shade := 0.82 if y % 4 == 0 else 1.0
		for x in 4:
			image.set_pixel(x, y, Color("#A7AFB2") * shade)
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.uv1_scale = Vector3(1, 10, 1)
	material.metallic = 0.5
	material.roughness = 0.5
	return material


## The ground floor front at both sides of the opening (tiled when the house
## has tiles on the ground floor).
func _build_ground_piers(pier: float, opening_height: float) -> void:
	var key := HouseMaterials.TILES if front_tiles != "none" else _front_key()
	for side: float in [-1.0, 1.0]:
		_box(key, Vector3(pier, opening_height, FRONT), Vector3(side * (width - pier) / 2.0, opening_height / 2.0, -FRONT / 2.0))


func _build_gate() -> void:
	var key := _front_key()
	var opening := width - 0.6
	var gate_height := 2.4
	_box(key, Vector3(width, floor_height - gate_height, FRONT), Vector3(0, gate_height + (floor_height - gate_height) / 2.0, -FRONT / 2.0))
	_build_ground_piers(0.3, gate_height)
	# A folding iron gate (cửa xếp): vertical bars and a lattice of crossed bars.
	var gate_z := -FRONT + 0.06
	var iron := Color("#3E3F3A") if style == "old" else HousePalette.accent("rails", _rng)
	var bars := int(opening / 0.11)
	for i in bars + 1:
		var x := -opening / 2.0 + opening * i / bars
		parts.add("rail_bar", _part_xform(Vector3(x, gate_height / 2.0, gate_z), Vector3(0.025, gate_height, 0.025)), iron)
	for row in 3:
		var y := 0.4 + row * 0.8
		for i in bars:
			var x := -opening / 2.0 + opening * (i + 0.5) / bars
			var diagonal := Basis(Vector3.FORWARD, deg_to_rad(55.0 if i % 2 == 0 else -55.0))
			parts.add("rail_bar", _part_xform(Vector3(x, y, gate_z + 0.02), Vector3(0.015, 0.16, 0.015), diagonal), iron)
	_box(HouseMaterials.METAL, Vector3(opening, 0.05, 0.06), Vector3(0, gate_height - 0.03, gate_z), iron)
	_box(HouseMaterials.METAL, Vector3(opening, 0.04, 0.06), Vector3(0, 0.04, gate_z), iron)
	# Behind the gate: the dark front room with a scooter shape.
	_box(HouseMaterials.DETAIL, Vector3(opening, gate_height, 0.04), Vector3(0, gate_height / 2.0, -FRONT - 0.6), Color("#3A3632"))
	var lamp := Greybox.lamp(self, Vector3(0.18, 0.18, 0.12), Vector3(opening / 2.0 - 0.2, 2.6, 0.08),
			Color("#FFE7A0"), "GateLamp")
	_glow_nodes.append(lamp)


func _build_wall() -> void:
	var key := HouseMaterials.TILES if front_tiles != "none" else _front_key()
	# A wall with a door at one side and a small barred window.
	var door_w := 0.9
	var door_h := 2.1
	var door_x := width / 2.0 - 0.3 - door_w / 2.0
	_box(key, Vector3(door_x - door_w / 2.0 + width / 2.0, OPENING_HEIGHT, FRONT),
			Vector3((-width / 2.0 + door_x - door_w / 2.0) / 2.0, OPENING_HEIGHT / 2.0, -FRONT / 2.0))
	_box(key, Vector3(width / 2.0 - door_x - door_w / 2.0, OPENING_HEIGHT, FRONT),
			Vector3((door_x + door_w / 2.0 + width / 2.0) / 2.0, OPENING_HEIGHT / 2.0, -FRONT / 2.0))
	_box(key, Vector3(door_w, OPENING_HEIGHT - door_h, FRONT), Vector3(door_x, door_h + (OPENING_HEIGHT - door_h) / 2.0, -FRONT / 2.0))
	_box(_front_key(), Vector3(width, floor_height - OPENING_HEIGHT, FRONT),
			Vector3(0, OPENING_HEIGHT + (floor_height - OPENING_HEIGHT) / 2.0, -FRONT / 2.0))
	_box(HouseMaterials.DETAIL, Vector3(door_w, door_h, 0.05), Vector3(door_x, door_h / 2.0, -_recess), Color("#6B4A33"))
	_box(HouseMaterials.DETAIL, Vector3(width - 0.4, 0.06, 0.25), Vector3(0, 1.0, 0.12), trim_color)


func _build_awning(opening: float) -> void:
	if _rng.randf() < 0.35:
		return
	var color := HousePalette.accent("awnings", _rng)
	var out := _rng.randf_range(0.6, 0.9)
	var y := OPENING_HEIGHT + 0.1
	var points: Array[Vector3] = [Vector3(-opening / 2.0, y, 0.02), Vector3(opening / 2.0, y, 0.02),
			Vector3(opening / 2.0, y - 0.35, out), Vector3(-opening / 2.0, y - 0.35, out)]
	var key := HouseMaterials.CLOTH if _rng.randf() < 0.6 else HouseMaterials.METAL
	_batch.quad(key, points, color)
	part_boxes["awning"] = AABB(Vector3(-opening / 2.0, y - 0.35, 0.02), Vector3(opening, 0.35, out - 0.02))


func _build_step() -> void:
	var key := HouseMaterials.TILES
	_box(key, Vector3(width, STEP_HEIGHT, STEP_DEPTH), Vector3(0, STEP_HEIGHT / 2.0, STEP_DEPTH / 2.0), Color.WHITE, "step")
	# The step is a floor: the player walks on it, and a tap on it walks there.
	var body := StaticBody3D.new()
	body.name = "Step"
	body.collision_layer = Layers.FLOOR
	body.collision_mask = 0
	add_child(body)
	Greybox.solid_shape(body, Vector3(width, STEP_HEIGHT, STEP_DEPTH), Vector3(0, STEP_HEIGHT / 2.0, STEP_DEPTH / 2.0))


# --- The upper floors -----------------------------------------------------------------

func _build_floor(index: int) -> void:
	var y0 := index * floor_height
	var sill := _sill_of(index)
	var top := y0 + _window_top
	var bars := _rng.randf() < (0.5 if style == "old" else 0.3)
	for window: Array in _windows:
		var x: float = window[0]
		var w: float = window[1]
		var h := top - sill
		var frame := Color("#C9CDCE") if style == "new" else Color("#6B4A33")
		var z := -_recess
		# The frame of the window and the sill that sticks out of the wall.
		_box(HouseMaterials.DETAIL, Vector3(w, 0.06, 0.08), Vector3(x, top - 0.03, z), frame)
		_box(HouseMaterials.DETAIL, Vector3(0.06, h, 0.08), Vector3(x - w / 2.0 + 0.03, (sill + top) / 2.0, z), frame)
		_box(HouseMaterials.DETAIL, Vector3(0.06, h, 0.08), Vector3(x + w / 2.0 - 0.03, (sill + top) / 2.0, z), frame)
		if not _has_balcony(index):
			_box(HouseMaterials.DETAIL, Vector3(w + 0.12, 0.05, _recess + 0.08), Vector3(x, sill - 0.025, (z + 0.08) / 2.0),
					trim_color.darkened(0.1), "sill_%d" % index)
		if style == "old":
			_louvered_shutters(x, w, sill, top, z)
		else:
			_glass(x, w, sill, top, z, frame)
		if bars and not _has_balcony(index):
			var count := int(w / 0.12)
			for i in count + 1:
				var bar_x := x - w / 2.0 + w * i / count
				parts.add("rail_bar", _part_xform(Vector3(bar_x, (sill + top) / 2.0, z + 0.07), Vector3(0.018, h, 0.018)),
						Color("#2E2E2A"))
	if _has_balcony(index):
		_build_balcony(index)


## Two wooden louvered shutters (cửa chớp), each with slats.
func _louvered_shutters(x: float, w: float, sill: float, top: float, z: float) -> void:
	var h := top - sill - 0.06
	var leaf := w / 2.0 - 0.06
	for side: float in [-1.0, 1.0]:
		var cx := x + side * (leaf / 2.0 + 0.01)
		_box(HouseMaterials.DETAIL, Vector3(leaf, 0.05, 0.04), Vector3(cx, top - 0.06, z - 0.02), shutter_color.darkened(0.15))
		_box(HouseMaterials.DETAIL, Vector3(leaf, 0.05, 0.04), Vector3(cx, sill + 0.03, z - 0.02), shutter_color.darkened(0.15))
		var slats := int(h / 0.09)
		for i in slats:
			var y := sill + 0.06 + (i + 0.5) * (h - 0.06) / slats
			_batch.box(HouseMaterials.DETAIL, Vector3(leaf - 0.02, 0.07, 0.015), Vector3(cx, y, z - 0.02), shutter_color,
					Basis(Vector3.RIGHT, deg_to_rad(-35.0)))


## A glass window with an aluminum frame and a middle bar.
func _glass(x: float, w: float, sill: float, top: float, z: float, frame: Color) -> void:
	var h := top - sill - 0.06
	_box(HouseMaterials.GLASS, Vector3(w - 0.1, h, 0.02), Vector3(x, sill + 0.03 + h / 2.0, z - 0.03), Color("#41525A"))
	_box(HouseMaterials.DETAIL, Vector3(0.04, h, 0.05), Vector3(x, sill + 0.03 + h / 2.0, z - 0.01), frame)
	_box(HouseMaterials.DETAIL, Vector3(w - 0.1, 0.04, 0.05), Vector3(x, sill + 0.03 + h * 0.7, z - 0.01), frame)


func _build_balcony(index: int) -> void:
	var y0 := index * floor_height
	var out := _rng.randf_range(0.6, 1.2) if kind != "hotel" else 0.6
	var w := width - 0.2
	var cx := 0.0
	if kind == "hotel":
		# Narrow balconies, with room for the vertical sign at the right corner.
		w = width - 1.1
		cx = -0.45
	_box(HouseMaterials.DETAIL, Vector3(w, 0.12, out), Vector3(cx, y0 + 0.06, out / 2.0), paint.darkened(0.08), "balcony_%d" % index)
	var rail_height := 1.0
	var style_index := _rng.randi() % 3
	if kind == "villa":
		style_index = 3
	var color := HousePalette.accent("rails", _rng)
	var front_z := out - 0.04
	match style_index:
		0, 1:
			# Plain vertical bars, or bars with an iron pattern.
			var count := int(w / 0.11)
			for i in count + 1:
				var x := -w / 2.0 + w * i / count
				parts.add("rail_bar", _part_xform(Vector3(cx + x, y0 + 0.12 + rail_height / 2.0, front_z), Vector3(0.02, rail_height, 0.02)), color)
			if style_index == 1:
				for i in count:
					var x := -w / 2.0 + w * (i + 0.5) / count
					parts.add("rail_bar", _part_xform(Vector3(cx + x, y0 + 0.62, front_z), Vector3(0.014, 0.14, 0.014),
							Basis(Vector3.FORWARD, deg_to_rad(45.0 if i % 2 == 0 else -45.0))), color)
			_box(HouseMaterials.METAL, Vector3(w, 0.05, 0.06), Vector3(cx, y0 + 0.12 + rail_height, front_z), color)
		2:
			# Stainless steel tubes.
			for i in 3:
				_batch.cylinder(HouseMaterials.METAL, 0.022, w, Vector3(cx, y0 + 0.45 + i * 0.3, front_z), Color("#C7CBCC"), 8,
						Basis(Vector3.FORWARD, PI / 2.0))
			for x: float in [-w / 2.0, 0.0, w / 2.0]:
				_batch.cylinder(HouseMaterials.METAL, 0.025, rail_height, Vector3(cx + x, y0 + 0.12 + rail_height / 2.0, front_z),
						Color("#C7CBCC"), 8)
		3:
			# Vase balusters (con tiện) with a top rail, on a villa.
			var count := int(w / 0.18)
			for i in count + 1:
				var x := -w / 2.0 + w * i / count
				parts.add("baluster", Transform3D(global_basis_for_parts(), to_global_part(Vector3(cx + x, y0 + 0.12, front_z))), Color("#EDE8DC"))
			_box(HouseMaterials.DETAIL, Vector3(w, 0.08, 0.16), Vector3(cx, y0 + 0.12 + 0.82, front_z), Color("#EDE8DC"))
	# Plants on a deep balcony: away from the wall, where the AC units hang,
	# and away from the rail. Each pot has its own place along the balcony.
	if out >= 0.9 and _rng.randf() < 0.7:
		var slots := int((w - 0.4) / 0.45)
		var used := {}
		for i in _rng.randi_range(1, mini(3, slots)):
			var slot := _rng.randi() % slots
			if used.has(slot):
				continue
			used[slot] = true
			var pot_x := cx - w / 2.0 + 0.2 + 0.225 + slot * 0.45
			parts.add("pot", Transform3D(global_basis_for_parts(), to_global_part(Vector3(pot_x, y0 + 0.12,
					_rng.randf_range(0.52, out - 0.26)))), Color("#B4634A"))


# --- The roof ---------------------------------------------------------------------------

func _build_roof() -> void:
	var height := wall_height()
	match _roof_kind():
		"flat":
			_flat_roof(height)
		"metal":
			_metal_roof(height)
		"tiles":
			_tile_roof(height)


## A flat roof terrace with a parapet, and the things on it.
func _flat_roof(height: float) -> void:
	var concrete := Color("#B9B6AC")
	_box(HouseMaterials.DETAIL, Vector3(width, 0.12, depth - FRONT), Vector3(0, height + 0.06, -FRONT - (depth - FRONT) / 2.0), concrete)
	for side: float in [-1.0, 1.0]:
		_box(HouseMaterials.PLASTER, Vector3(0.15, 0.8, depth - FRONT), Vector3(side * (width / 2.0 - 0.075), height + 0.4, -FRONT - (depth - FRONT) / 2.0))
	_box(HouseMaterials.PLASTER, Vector3(width, 0.8, 0.15), Vector3(0, height + 0.4, -depth + 0.075))
	var back := -depth * 0.55
	# A stainless steel water tank: vertical or horizontal.
	if _rng.randf() < 0.85:
		var tank_x := _rng.randf_range(-width / 2.0 + 0.7, width / 2.0 - 0.7)
		if _rng.randf() < 0.5:
			_batch.cylinder(HouseMaterials.METAL, 0.5, 1.3, Vector3(tank_x, height + 0.12 + 0.95, back), Color("#D8DCDD"), 14)
			_box(HouseMaterials.METAL, Vector3(0.9, 0.3, 0.9), Vector3(tank_x, height + 0.27, back), Color("#6E6F6A"))
			part_boxes["tank"] = AABB(Vector3(tank_x - 0.5, height + 0.12, back - 0.5), Vector3(1.0, 1.48, 1.0))
		else:
			_batch.cylinder(HouseMaterials.METAL, 0.45, 1.5, Vector3(tank_x, height + 0.12 + 0.8, back), Color("#D8DCDD"), 14,
					Basis(Vector3.FORWARD, PI / 2.0))
			_box(HouseMaterials.METAL, Vector3(1.2, 0.35, 0.7), Vector3(tank_x, height + 0.3, back), Color("#6E6F6A"))
			part_boxes["tank"] = AABB(Vector3(tank_x - 0.75, height + 0.12, back - 0.45), Vector3(1.5, 1.13, 0.9))
	# A solar water heater: a dark panel or glass tubes on a stand.
	if _rng.randf() < 0.55:
		var heater_z := back - 2.2
		var tilt := Basis(Vector3.RIGHT, deg_to_rad(-25.0))
		if _rng.randf() < 0.5:
			_batch.box(HouseMaterials.GLASS, Vector3(1.8, 0.06, 1.0), Vector3(0, height + 0.75, heater_z), Color("#1E2A3A"), tilt)
		else:
			for i in 12:
				_batch.cylinder(HouseMaterials.GLASS, 0.03, 1.2, Vector3(-0.8 + i * 0.145, height + 0.75, heater_z), Color("#2A3440"), 6,
						tilt * Basis(Vector3.RIGHT, PI / 2.0), false)
		_batch.cylinder(HouseMaterials.METAL, 0.15, 1.8, Vector3(0, height + 1.2, heater_z - 0.45), Color("#D8DCDD"), 10,
				Basis(Vector3.FORWARD, PI / 2.0))
		part_boxes["heater"] = AABB(Vector3(-0.9, height + 0.12, heater_z - 0.65), Vector3(1.8, 1.25, 1.2))
	# A laundry line with clothes.
	if _rng.randf() < 0.6:
		var line_z := -FRONT - 1.2
		var line_y := height + 1.7
		for side: float in [-1.0, 1.0]:
			_box(HouseMaterials.METAL, Vector3(0.04, 1.6, 0.04), Vector3(side * (width / 2.0 - 0.3), height + 0.92, line_z), Color("#5A5A55"))
		_batch.tube(HouseMaterials.DETAIL, PackedVector3Array([Vector3(-width / 2.0 + 0.3, line_y, line_z), Vector3(width / 2.0 - 0.3, line_y, line_z)]),
				0.008, Color("#333333"))
		for i in _rng.randi_range(2, 5):
			var cloth_x := _rng.randf_range(-width / 2.0 + 0.5, width / 2.0 - 0.8)
			var cloth_w := _rng.randf_range(0.3, 0.6)
			var cloth_h := _rng.randf_range(0.4, 0.7)
			var color := Color.from_hsv(_rng.randf(), _rng.randf_range(0.2, 0.7), _rng.randf_range(0.6, 0.95))
			_batch.quad(HouseMaterials.CLOTH, [Vector3(cloth_x, line_y - cloth_h, line_z), Vector3(cloth_x + cloth_w, line_y - cloth_h, line_z),
					Vector3(cloth_x + cloth_w, line_y, line_z), Vector3(cloth_x, line_y, line_z)] as Array[Vector3], color)
	# Foam boxes with plants along the parapet.
	if _rng.randf() < 0.7:
		for i in _rng.randi_range(2, 4):
			var box_x := -width / 2.0 + 0.45 + i * 0.6
			if box_x > width / 2.0 - 0.4:
				break
			_box(HouseMaterials.DETAIL, Vector3(0.5, 0.3, 0.35), Vector3(box_x, height + 0.27, -FRONT - 0.35), Color("#F2F2EE"))
			_box(HouseMaterials.DETAIL, Vector3(0.45, 0.25, 0.3), Vector3(box_x, height + 0.5, -FRONT - 0.35), Color("#5E8C3A"))
	# Rebar that sticks up at the corners for a future floor.
	if _rng.randf() < 0.45:
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var base := Vector3(corner.x * (width / 2.0 - 0.15), height + 0.8, -FRONT - 0.15 if corner.y < 0 else -depth + 0.15)
			for k in 4:
				_box(HouseMaterials.DETAIL, Vector3(0.016, 0.7, 0.016), base + Vector3((k % 2) * 0.1 - 0.05, 0.35, (k / 2) * 0.1 - 0.05),
						Color("#5A3E30"))
	_build_rooftop_antennas(height + 0.12)


## A metal roof that slopes from the front parapet to the back, with a round
## turbine vent.
func _metal_roof(height: float) -> void:
	var color := HousePalette.metal_roof(_rng)
	var front_y := height + _parapet_height() - 0.05
	var back_y := height + 0.15
	var z0 := -FRONT
	var z1 := -depth - 0.2
	# The roof does not go past the side walls, into the house next door.
	var h := width / 2.0
	_batch.quad(HouseMaterials.METAL_ROOF, [Vector3(-h, back_y, z1), Vector3(h, back_y, z1), Vector3(h, front_y, z0), Vector3(-h, front_y, z0)] as Array[Vector3], Color.WHITE)
	part_boxes["roof"] = AABB(Vector3(-h, back_y, z1), Vector3(h * 2.0, front_y - back_y, z0 - z1))
	_metal_roof_color = color.color
	if _rng.randf() < 0.5:
		var t := 0.4
		var vent := Vector3(_rng.randf_range(-width / 4.0, width / 4.0), lerpf(front_y, back_y, t), lerpf(z0, z1, t))
		_batch.cylinder(HouseMaterials.METAL, 0.12, 0.3, vent + Vector3(0, 0.15, 0), Color("#C7CBCC"), 10)
		_batch.cylinder(HouseMaterials.METAL, 0.22, 0.25, vent + Vector3(0, 0.42, 0), Color("#C7CBCC"), 12)
	_build_rooftop_antennas(back_y)


## A pitched roof of terracotta tiles (villas), with the ridge along the depth.
func _tile_roof(height: float) -> void:
	var color := HousePalette.roof_tile(_rng)
	_tile_roof_color = color
	var top := height + 1.6
	# The eaves go out at the front and the back, not into the houses next door.
	var h := width / 2.0
	var z0 := 0.3
	var z1 := -depth - 0.3
	var eave := height + 0.2
	_batch.quad(HouseMaterials.TILE_ROOF, [Vector3(-h, eave, z0), Vector3(-h, eave, z1), Vector3(0, top, z1), Vector3(0, top, z0)] as Array[Vector3], Color.WHITE)
	_batch.quad(HouseMaterials.TILE_ROOF, [Vector3(h, eave, z1), Vector3(h, eave, z0), Vector3(0, top, z0), Vector3(0, top, z1)] as Array[Vector3], Color.WHITE)
	# The gable at the front.
	_batch.quad(HouseMaterials.PLASTER, [Vector3(-width / 2.0, height + 0.45, -0.01), Vector3(width / 2.0, height + 0.45, -0.01),
			Vector3(0, top - 0.1, -0.01), Vector3(0, top - 0.1, -0.01)] as Array[Vector3], Color.WHITE)
	part_boxes["roof"] = AABB(Vector3(-h, eave, z1), Vector3(h * 2.0, top - eave, z0 - z1))


## Satellite dishes, TV antennas, and sometimes a cell tower.
func _build_rooftop_antennas(base_y: float) -> void:
	var z := -depth * 0.3
	if _rng.randf() < 0.35:
		var x := _rng.randf_range(-width / 2.0 + 0.5, width / 2.0 - 0.5)
		_box(HouseMaterials.METAL, Vector3(0.05, 0.6, 0.05), Vector3(x, base_y + 0.3, z), Color("#7A7A74"))
		_batch.cylinder(HouseMaterials.DETAIL, 0.32, 0.05, Vector3(x, base_y + 0.75, z + 0.1), Color("#E6E6E0"), 14,
				Basis(Vector3.RIGHT, deg_to_rad(60.0)))
	if _rng.randf() < 0.4:
		var x := _rng.randf_range(-width / 2.0 + 0.4, width / 2.0 - 0.4)
		_box(HouseMaterials.METAL, Vector3(0.03, 2.2, 0.03), Vector3(x, base_y + 1.1, z - 1.0), Color("#8A8A84"))
		for i in 4:
			_box(HouseMaterials.METAL, Vector3(0.9 - i * 0.15, 0.02, 0.02), Vector3(x, base_y + 1.5 + i * 0.18, z - 1.0), Color("#8A8A84"))
	if kind == "hotel" and seed % 7 == 0:
		# A cell tower: a lattice mast with panels.
		var mast_z := -depth * 0.6
		for corner: Vector2 in [Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, 0.3)]:
			_box(HouseMaterials.METAL, Vector3(0.05, 6.0, 0.05), Vector3(corner.x, base_y + 3.0, mast_z + corner.y), Color("#9A9A94"))
		for i in 6:
			_box(HouseMaterials.METAL, Vector3(0.6, 0.03, 0.03), Vector3(0, base_y + 0.5 + i, mast_z - 0.3), Color("#9A9A94"))
		for side: float in [-1.0, 1.0]:
			_box(HouseMaterials.DETAIL, Vector3(0.2, 1.0, 0.1), Vector3(side * 0.45, base_y + 5.5, mast_z), Color("#E6E6E0"))


# --- The side walls and the clutter ---------------------------------------------------------

## The side walls above a shorter neighbor: bare grey plaster or brick, with
## breeze blocks or small vent openings (R9).
func _build_side_walls() -> void:
	var top := wall_height() + _parapet_height()
	for side: float in [-1.0, 1.0]:
		var neighbor := left_neighbor_height if side < 0.0 else right_neighbor_height
		if neighbor < 0.0 or neighbor >= top - 0.2:
			continue
		var x := side * (width / 2.0 + 0.004)
		var key := HouseMaterials.BARE
		var y0 := maxf(neighbor, 0.0)
		var points: Array[Vector3] = []
		if side < 0.0:
			points = [Vector3(x, y0, -depth), Vector3(x, y0, 0), Vector3(x, top, 0), Vector3(x, top, -depth)]
		else:
			points = [Vector3(x, y0, 0), Vector3(x, y0, -depth), Vector3(x, top, -depth), Vector3(x, top, 0)]
		_batch.quad(key, points, Color.WHITE)
		part_boxes["side_%s" % ("left" if side < 0.0 else "right")] = AABB(Vector3(x, y0, -depth), Vector3(0.0, top - y0, depth))
		# Breeze blocks: a grid of small openings high on the bare wall.
		if top - y0 > 2.0 and _rng.randf() < 0.5:
			var center := Vector3(x + side * 0.01, top - 1.4, -depth * _rng.randf_range(0.3, 0.7))
			for row in 3:
				for column in 4:
					_box(HouseMaterials.DETAIL, Vector3(0.02, 0.14, 0.14),
							center + Vector3(0, row * 0.2, column * 0.2 - 0.3), Color("#3A3632"))


## AC units, a meter box, a down pipe, and potted plants on the step.
func _build_clutter() -> void:
	# A down pipe at one side, from the roof to the ground.
	var pipe_x := (width / 2.0 - 0.12) * (1.0 if seed % 2 == 0 else -1.0)
	_batch.cylinder(HouseMaterials.DETAIL, 0.045, wall_height(), Vector3(pipe_x, wall_height() / 2.0, 0.06), Color("#8C8E88"), 8)
	# The electric meter box next to the door.
	_box(HouseMaterials.DETAIL, Vector3(0.3, 0.4, 0.12), Vector3(-pipe_x * 0.8, 1.9, 0.06), Color("#9EA39A"))
	# AC units on the front wall of some floors.
	for i in range(1, floors):
		if _rng.randf() < (0.55 if style == "new" or kind == "hotel" else 0.3):
			var w: float = _windows[0][1]
			# A hotel has its vertical sign at the right corner: the AC units are at the left.
			var to_right := _rng.randf() < 0.5 and kind != "hotel"
			var x: float = _windows[0][0] + (w / 2.0 + 0.5) * (1.0 if to_right else -1.0)
			x = clampf(x, -width / 2.0 + 0.45, width / 2.0 - 0.45)
			parts.add("ac_unit", Transform3D(global_basis_for_parts(), to_global_part(Vector3(x, i * floor_height + 0.35, 0.16))), Color("#E6E6E0"))
	# Potted plants on the step of a home.
	if ground != "shop" and _rng.randf() < 0.6:
		parts.add("pot", Transform3D(global_basis_for_parts(), to_global_part(Vector3(-width / 2.0 + 0.35, STEP_HEIGHT, 0.16))), Color("#B4634A"))


func _build_sign() -> void:
	if kind == "hotel":
		_vertical_sign()
		return
	var sign_width := width - 0.4 if ground == "shop" else minf(width * 0.6, 2.6)
	Greybox.sign_board(self, sign_text, Vector2(sign_width, 0.5),
			Vector3(0, OPENING_HEIGHT + 0.35, 0.05), sign_bg, sign_fg)
	part_boxes["sign"] = AABB(Vector3(-sign_width / 2.0, OPENING_HEIGHT + 0.1, 0.0), Vector3(sign_width, 0.5, 0.1))


## A vertical sign at the corner of a hotel ("KHÁCH SẠN"), with one letter
## under the other. It sticks out of the front, so people see it from the street.
func _vertical_sign() -> void:
	var letters: Array[String] = []
	for character in sign_text:
		if character != " ":
			letters.append(character)
	var step := 0.42
	var height := step * letters.size() + 0.2
	var root := Node3D.new()
	root.name = "Sign"
	root.position = Vector3(width / 2.0 - 0.15, wall_height() - 0.3 - height / 2.0, 0.45)
	root.rotation_degrees.y = 90.0
	add_child(root)
	Greybox.box(root, Vector3(0.6, height, 0.1), Vector3.ZERO, sign_bg, "Board")
	for side: float in [-1.0, 1.0]:
		for i in letters.size():
			var label := Label3D.new()
			label.text = letters[i]
			label.font = preload("res://assets/fonts/BeVietnamPro-Bold.ttf")
			label.modulate = sign_fg
			label.outline_size = 0
			label.shaded = false
			label.double_sided = false
			label.font_size = 64
			label.pixel_size = 0.3 / 64.0
			label.position = Vector3(0, height / 2.0 - 0.1 - step * (i + 0.5), side * 0.06)
			label.rotation_degrees.y = 0.0 if side > 0.0 else 180.0
			root.add_child(label)
	part_boxes["sign"] = AABB(Vector3(width / 2.0 - 0.2, root.position.y - height / 2.0, 0.15), Vector3(0.1, height, 0.6))


# --- Values of the materials -----------------------------------------------------------------

var _metal_roof_color := Color.WHITE
var _tile_roof_color := Color.WHITE


func _set_instance_values() -> void:
	var window: Array = _windows[0]
	var info := Vector4(wall_height() + _parapet_height(), floor_height, float(window[1]) / 2.0, float(window[0]))
	for key: String in [HouseMaterials.PLASTER, HouseMaterials.BARE]:
		if not meshes.has(key):
			continue
		var instance: MeshInstance3D = meshes[key]
		instance.set_instance_shader_parameter("paint_color", paint)
		instance.set_instance_shader_parameter("stripe_color", stripe)
		instance.set_instance_shader_parameter("paint_age", paint_age)
		instance.set_instance_shader_parameter("seed", float(seed % 1000) * 0.137)
		instance.set_instance_shader_parameter("wall_info", info)
		instance.set_instance_shader_parameter("half_width", width / 2.0)
	if meshes.has(HouseMaterials.METAL_ROOF):
		var roof_instance: MeshInstance3D = meshes[HouseMaterials.METAL_ROOF]
		roof_instance.set_instance_shader_parameter("roof_color", _metal_roof_color)
		roof_instance.set_instance_shader_parameter("rust", clampf(paint_age + _rng.randf_range(-0.2, 0.2), 0.0, 1.0))
		roof_instance.set_instance_shader_parameter("seed", float(seed % 1000) * 0.071)
		roof_instance.set_instance_shader_parameter("ridges_along_z", 1.0)
	if meshes.has(HouseMaterials.TILE_ROOF):
		var tile_instance: MeshInstance3D = meshes[HouseMaterials.TILE_ROOF]
		tile_instance.set_instance_shader_parameter("roof_color", _tile_roof_color)
		tile_instance.set_instance_shader_parameter("age", paint_age)
		tile_instance.set_instance_shader_parameter("seed", float(seed % 1000) * 0.053)
	if meshes.has(HouseMaterials.TILES):
		var tiles_instance: MeshInstance3D = meshes[HouseMaterials.TILES]
		var tile_rng := RandomNumberGenerator.new()
		tile_rng.seed = seed + 7
		tiles_instance.set_instance_shader_parameter("tile_color", HousePalette.accent("tiles", tile_rng))
		tiles_instance.set_instance_shader_parameter("second_color", HousePalette.accent("tiles", tile_rng))
		tiles_instance.set_instance_shader_parameter("pattern", 2.0 if front_tiles == "full" else float(seed % 2))
		tiles_instance.set_instance_shader_parameter("tile_size", 0.3 if front_tiles != "full" else 0.2)
		tiles_instance.set_instance_shader_parameter("seed", float(seed % 1000) * 0.31)
	# The bare side walls: grey plaster, or brick on some old houses (R9).
	if meshes.has(HouseMaterials.BARE):
		var bare_instance: MeshInstance3D = meshes[HouseMaterials.BARE]
		bare_instance.set_instance_shader_parameter("bare", 2.0 if style == "old" and seed % 3 == 0 else 1.0)


## The transform of a rail bar in the space of the parts collector.
func _part_xform(center: Vector3, size: Vector3, basis := Basis()) -> Transform3D:
	return Transform3D((global_basis_for_parts() * basis).scaled_local(size), to_global_part(center))


## A point of this house in the space of the parts collector.
func to_global_part(local: Vector3) -> Vector3:
	return _to_parts_space() * local


func global_basis_for_parts() -> Basis:
	return _to_parts_space().basis


## The transform from this house to the parts collector. The hẻm gives the
## houses their place before it builds them, so this works before _ready().
func _to_parts_space() -> Transform3D:
	if _own_parts:
		return Transform3D.IDENTITY
	var house := transform
	var parent := get_parent() as Node3D
	var collector_parent := parts.get_parent() as Node3D
	if parent != null and parent == collector_parent:
		return parts.transform.affine_inverse() * house
	return house


# --- The shutter and the lamps ------------------------------------------------------------------

## Moves the shutter. A house that is not a shop has no shutter. A closed or
## half open shutter stops the player. With "animate", the shutter rolls in
## SHUTTER_SECONDS (R7).
func set_shutter(value: Shutter, animate := false) -> void:
	var changed := value != shutter
	shutter = value
	if _shutter_node == null:
		return
	var h := _shutter_height(value)
	_shutter_shape.set_deferred("disabled", value == Shutter.OPEN)
	if _shutter_tween:
		_shutter_tween.kill()
	if animate and changed and is_inside_tree():
		_shutter_node.visible = true
		_shutter_tween = create_tween()
		_shutter_tween.tween_method(_place_shutter, shutter_shown(), h, SHUTTER_SECONDS)
	else:
		_place_shutter(h)


func _shutter_height(value: Shutter) -> float:
	match value:
		Shutter.CLOSED:
			return OPENING_HEIGHT
		Shutter.HALF:
			return HALF_HEIGHT
	return 0.0


## The height of the shutter that shows now (during the animation too).
func shutter_shown() -> float:
	if _shutter_node == null or not _shutter_node.visible:
		return 0.0
	return _shutter_node.scale.y if _shutter_node.scale.y > 0.02 else 0.0


func _place_shutter(h: float) -> void:
	_shutter_node.visible = h > 0.01
	_shutter_node.scale = Vector3(1, maxf(h, 0.01), 1)
	# The shutter runs inside the opening, behind the front of the wall and
	# behind the step.
	_shutter_node.position = Vector3(0, OPENING_HEIGHT - h / 2.0, -FRONT * 0.5)


## The box of the shutter now, in the local space (for PT-29).
func shutter_box() -> AABB:
	if _shutter_node == null or not _shutter_node.visible:
		return AABB()
	var h := shutter_shown()
	var w := width - WALL * 2.0
	return AABB(Vector3(-w / 2.0, OPENING_HEIGHT - h, _shutter_node.position.z - 0.015), Vector3(w, h, 0.03))


## Turns the lamps of the house on or off.
func set_glow(on: bool) -> void:
	for node in _glow_nodes:
		var mesh := node as MeshInstance3D
		if on:
			mesh.material_override = Greybox.material(Color("#FFE7A0"), 2.5)
		else:
			mesh.material_override = Greybox.material(Color("#B8B09A"))
