class_name Hem
extends Node3D
## The hẻm, built from data/world/hem_layout.json.
##
## Units are meters. The hẻm runs along the X axis. X = 0 is the homestay.
## Bãi Trước is at the high X end. The house fronts of the main row are at
## Z = -hem_width / 2 and face +Z. The opposite row faces them at
## Z = +hem_width / 2. A row of houses faces the beach road.

## The helper of the hủ tiếu gõ cart clacks the bamboo sticks.
signal clacked(position: Vector3)

const TubeHouseScene := preload("res://scenes/world/tube_house.tscn")
const NpcScene := preload("res://scenes/actors/npc.tscn")
const BeachScene := preload("res://scenes/world/beach.tscn")

const FLOOR_LAYER := Layers.FLOOR
const TOUCH_LAYER := Layers.TOUCH
## The collision height of a stool of the cà phê cóc (see _build_stall).
const STOOL_SOLID_HEIGHT := 0.6
const HELPER_SPEED := 0.9
## The navigation mesh uses this cell size. The map cell size must be the same.
const NAV_CELL := 0.15

var hem_width := 2.8
## The places across the hẻm, from its width (plan 0004, R11a): the carts on
## the street in front of the steps, and where the player stands.
var cart_z := -0.68
var lot_stand_z := -0.75
var cart_stand_z := 0.42
var npc_z := -0.95
var npc_stand_z := -0.2
var helper_z := 0.3
## The repeated small parts of all houses (rail bars, pots, AC units).
var parts: HouseParts
var house_depth := 14.0
var start_x := 0.0
var end_x := 0.0
var houses: Dictionary = {}
var lot_x: Dictionary = {}
var stand_points: Dictionary = {}
var npc_stand_points: Dictionary = {}
## The focus point of each spot (where the center dot must point).
var focus_points: Dictionary = {}
var carts: Dictionary = {}
var npcs: Dictionary = {}
var helper: Npc
## The TV upstairs at Phở Cô Sáu. It is on after the shop closes (plan 0003, R2).
var tv: AudioStreamPlayer3D
var beach: Beach
var nav_region: NavigationRegion3D
var clack_count := 0
## The game time of the last clack, in seconds from the start of the scene.
var clack_time := 0.0

var _spot_lots: Dictionary = {}
var _cart_areas: Dictionary = {}
var _cart_bodies: Dictionary = {}
var _spot_lights: Dictionary = {}
var _street_lights: Array[OmniLight3D] = []
var _street_lamps: Array[MeshInstance3D] = []
var _stall_open: Dictionary = {}
var _stall_closed: Dictionary = {}
var _stall_bodies: Dictionary = {}
var _helper_phase := 0.0
var _clack_left := 0.0
var _scene_time := 0.0
var _minutes := -1
var _present_key := ""
var _nav_source: NavigationMeshSourceGeometryData3D
var _baking := false
var _bake_again := false


func _ready() -> void:
	build()


func build() -> void:
	var layout: Dictionary = Content.layout
	hem_width = float(layout.hem_width)
	house_depth = float(layout.house_depth)
	var half := hem_width / 2.0
	cart_z = -half + TubeHouse.STEP_DEPTH + 0.42
	lot_stand_z = -half + 0.65
	cart_stand_z = cart_z + 1.1
	npc_z = -half + 0.45
	npc_stand_z = npc_z + 0.75
	helper_z = 0.3
	parts = HouseParts.new()
	parts.name = "HouseParts"
	add_child(parts)
	var floor_height := float(layout.floor_height)
	var lots: Array = layout.lots
	start_x = -float(lots[0].width) / 2.0
	var x := start_x
	var row: Array[TubeHouse] = []
	for lot: Dictionary in lots:
		var w := float(lot.width)
		var center := x + w / 2.0
		lot_x[lot.id] = center
		row.append(_build_lot(lot, center, floor_height))
		x += w
	end_x = x
	_add_row(row)
	_build_opposite_row(layout.opposite_lots, floor_height)
	for cart: Dictionary in layout.carts:
		_build_cart(cart)
	for npc_data: Dictionary in layout.npcs:
		_build_npc(npc_data)
	_build_helper()
	_build_tv(floor_height)
	_build_ground()
	_build_street_lamps()
	beach = BeachScene.instantiate()
	beach.setup(layout.beach)
	beach.position = Vector3(end_x, 0, 0)
	add_child(beach)
	beach.build()
	stand_points[beach.spot_id] = beach.position + beach.stand_point()
	focus_points[beach.spot_id] = beach.position + beach.focus_point()
	_build_beach_road_rows(layout.beach_road_lots, floor_height)
	_build_cables()
	parts.commit()
	_build_floor_collider()
	_build_navigation()
	_clack_left = randf_range(4.0, 5.0)


func _make_house(lot: Dictionary, floor_height: float) -> TubeHouse:
	var house: TubeHouse = TubeHouseScene.instantiate()
	house.name = "Lot_%s" % lot.id
	house.width = float(lot.width)
	house.floors = int(lot.floors)
	house.floor_height = floor_height
	house.kind = lot.get("kind", "tube")
	house.style = lot.get("style", "old")
	house.paint = Color(lot.paint)
	house.paint_age = float(lot.get("paint_age", 0.4))
	house.seed = int(lot.get("seed", 0))
	house.roof = lot.get("roof", "")
	house.front_tiles = lot.get("front_tiles", "none")
	house.balcony = bool(lot.balcony)
	house.ground = lot.ground
	house.depth = house_depth
	house.parts = parts
	if lot.has("sign"):
		house.sign_text = lot.sign.text
		house.sign_bg = Color(lot.sign.bg)
		house.sign_fg = Color(lot.sign.fg)
	return house


## Gives each house of a row the heights of its neighbors (the part of a side
## wall above a shorter neighbor is bare, R9), then builds the houses.
func _add_row(row: Array[TubeHouse]) -> void:
	for i in row.size():
		row[i].left_neighbor_height = row[i - 1].top_height() if i > 0 else 0.0
		row[i].right_neighbor_height = row[i + 1].top_height() if i < row.size() - 1 else 0.0
	for house in row:
		add_child(house)


## Makes the house of a lot of the main row. The house is built later, in _add_row().
func _build_lot(lot: Dictionary, center: float, floor_height: float) -> TubeHouse:
	var house := _make_house(lot, floor_height)
	house.position = Vector3(center, 0, -hem_width / 2.0)
	houses[lot.id] = house
	if not lot.has("spot"):
		return house
	var spot_id: String = lot.spot
	_spot_lots[spot_id] = lot.id
	stand_points[spot_id] = Vector3(center, 0, lot_stand_z)
	var area := _make_touch_area("spot_id", spot_id, Vector3(float(lot.width) - 0.3, 2.9, 0.4))
	area.position = Vector3(center, 1.45, -hem_width / 2.0 + 0.2)
	focus_points[spot_id] = _focus_point(spot_id, Vector3(center, 1.6, -hem_width / 2.0))
	# One warm light for each place. The hẻm has not more than 8 dynamic lights.
	var light := OmniLight3D.new()
	light.name = "Light_%s" % spot_id
	light.light_color = Color("#FFD9A0")
	light.light_energy = 1.4
	light.omni_range = 5.0
	light.position = Vector3(center, 2.4, -hem_width / 2.0 + 1.0)
	light.visible = false
	add_child(light)
	_spot_lights[spot_id] = light
	if lot.ground == "wall":
		_build_stall(spot_id, center, float(lot.width))
	return house


## Returns the focus point of a spot: the "focus" offset in spots.json from
## the place of the spot, or the default point.
func _focus_point(spot_id: String, default: Vector3) -> Vector3:
	var spot := Content.spot(spot_id)
	if spot.has("focus"):
		var offset: Array = spot.focus
		return default + Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
	return default


## The row of houses on the other side of the hẻm. They face the main row.
func _build_opposite_row(lots: Array, floor_height: float) -> void:
	var x := start_x
	var row: Array[TubeHouse] = []
	for lot: Dictionary in lots:
		var w := float(lot.width)
		var house := _make_house(lot, floor_height)
		house.position = Vector3(x + w / 2.0, 0, hem_width / 2.0)
		house.rotation_degrees.y = 180.0
		houses[lot.id] = house
		row.append(house)
		x += w
	# The row faces -Z, so its left side is at the high X end.
	row.reverse()
	_add_row(row)


## The rows of houses along the beach road, at both sides of the end of the
## hẻm. They face the beach road (+X).
func _build_beach_road_rows(lots: Array, floor_height: float) -> void:
	for side: float in [-1.0, 1.0]:
		var z := side * (hem_width / 2.0 + house_depth)
		var row: Array[TubeHouse] = []
		for lot: Dictionary in lots:
			var w := float(lot.width)
			var house := _make_house(lot, floor_height)
			house.name = "Road_%s_%s" % [lot.id, "south" if side < 0 else "north"]
			house.depth = 12.0
			house.position = Vector3(end_x, 0, z + side * w / 2.0)
			house.rotation_degrees.y = 90.0
			row.append(house)
			z += side * w
		# The houses face +X: the left side is at the low Z end.
		if side > 0.0:
			row.reverse()
		_add_row(row)


## A sidewalk stall (cà phê cóc): stools and people when open, a stack of stools when closed.
func _build_stall(spot_id: String, center: float, width: float) -> void:
	var z := -hem_width / 2.0
	var open := Node3D.new()
	open.name = "StallOpen_%s" % spot_id
	open.position = Vector3(center, 0, z)
	add_child(open)
	var open_body := Greybox.solid_body(open, "StallSolid")
	var colors := ["#2F72C4", "#D8433A", "#2F72C4", "#2F9C5A"]
	for i in colors.size():
		var stool_pos := Vector3(-width / 2.0 + 0.8 + i * 0.85, 0, 0.45)
		Greybox.stool(open, stool_pos, Color(colors[i]))
		# The collision is higher than the stool: the player can step up 0.2 m,
		# and the round bottom of the capsule climbs a 0.32 m box. A person
		# does not walk onto a stool.
		Greybox.solid_shape(open_body, Vector3(0.32, STOOL_SOLID_HEIGHT, 0.32),
				stool_pos + Vector3(0, STOOL_SOLID_HEIGHT / 2.0, 0))
	for sitter: Array in [[1.65, "#F2F2F2", "#273445", "#151515"], [2.5, "#E9C7D8", "#3D3D55", "#2B1C14"]]:
		Greybox.person(open, Vector3(-width / 2.0 + sitter[0], 0, 0.45), Color(sitter[1]), Color(sitter[2]),
				Color("#C99A72"), Color(sitter[3]), 1.15, "Sitter")
	for i in 3:
		Greybox.box(open, Vector3(0.07, 0.1, 0.07), Vector3(-width / 2.0 + 1.2 + i * 0.9, 1.08, 0.18),
				Color("#6B3E1E"))
	var closed := Node3D.new()
	closed.name = "StallClosed_%s" % spot_id
	closed.position = Vector3(center, 0, z)
	add_child(closed)
	var closed_body := Greybox.solid_body(closed, "StackSolid")
	for i in 4:
		Greybox.stool(closed, Vector3(width / 2.0 - 0.6, i * 0.06, 0.3), Color(colors[i]))
	Greybox.solid_shape(closed_body, Vector3(0.34, 0.6, 0.34), Vector3(width / 2.0 - 0.6, 0.3, 0.3))
	_stall_open[spot_id] = open
	_stall_closed[spot_id] = closed
	_stall_bodies[spot_id] = [open_body, closed_body]


func _build_cart(cart: Dictionary) -> void:
	var spot_id: String = cart.spot
	var x := float(lot_x[cart.lot]) + float(cart.offset)
	var root := Node3D.new()
	root.name = "Cart_%s" % spot_id
	root.position = Vector3(x, 0, cart_z)
	add_child(root)
	Greybox.cart(root, Vector3.ZERO, Color(cart.color), cart.sign.text, Color(cart.sign.bg),
			Color(cart.sign.fg))
	Greybox.person(root, Vector3(0.35, 0, -0.55), Color("#F0D6A0"), Color("#5A4A3A"),
			Color("#C99A72"), Color("#2A211C"), 1.55, "Seller")
	var body := Greybox.solid_body(root, "CartSolid")
	Greybox.solid_shape(body, Vector3(1.4, 1.8, 0.75), Vector3(0, 0.9, 0))
	Greybox.solid_shape(body, Vector3(0.45, 1.55, 0.35), Vector3(0.35, 0.78, -0.55))
	var area := _make_touch_area("spot_id", spot_id, Vector3(1.5, 1.9, 0.9))
	area.position = Vector3(x, 0.95, cart_z)
	carts[spot_id] = root
	_cart_areas[spot_id] = area
	_cart_bodies[spot_id] = body
	stand_points[spot_id] = Vector3(x, 0, cart_stand_z)
	focus_points[spot_id] = _focus_point(spot_id, Vector3(x, 1.2, cart_z))


func _build_npc(data: Dictionary) -> void:
	var npc: Npc = NpcScene.instantiate()
	npc.npc_id = data.npc
	npc.name = "Npc_%s" % data.npc
	npc.touchable = Content.npc(data.npc).get("talk", true)
	for field: String in ["shirt", "pants", "skin", "hair"]:
		if data.has(field):
			npc.set(field, Color(data[field]))
	if data.has("height"):
		npc.height = float(data.height)
	var x := float(lot_x[data.lot]) + float(data.offset)
	npc.position = Vector3(x, 0, npc_z)
	add_child(npc)
	npcs[data.npc] = npc
	npc_stand_points[data.npc] = Vector3(x, 0, npc_stand_z)


func _build_helper() -> void:
	helper = NpcScene.instantiate()
	helper.name = "GoHelper"
	helper.shirt = Color("#D9D2C0")
	helper.pants = Color("#3A3A34")
	helper.hair = Color("#1B1B1B")
	helper.height = 1.45
	helper.moving = true
	helper.position = Vector3(10, 0, helper_z)
	add_child(helper)
	# The two bamboo sticks.
	Greybox.box(helper, Vector3(0.04, 0.04, 0.3), Vector3(0.3, 0.95, 0.15), Color("#C8A24A"))
	Greybox.box(helper, Vector3(0.04, 0.04, 0.22), Vector3(0.3, 1.0, 0.12), Color("#C8A24A"))


func _build_tv(floor_height: float) -> void:
	tv = AudioStreamPlayer3D.new()
	tv.name = "Tv"
	tv.stream = Tones.tv()
	tv.max_distance = float(Content.sound("tv").get("range_m", 8.0))
	tv.unit_size = 2.0
	tv.volume_db = -8.0
	tv.position = Vector3(float(lot_x[_spot_lots.get("pho", "")]) if _spot_lots.has("pho") else 0.0,
			floor_height * 1.5, -hem_width / 2.0 - 1.5)
	add_child(tv)


## True when the TV upstairs is on: Phở Cô Sáu is closed for the day.
func tv_on(minutes: int) -> bool:
	var spot := Content.spot("pho")
	return not spot.is_empty() and Content.rule_for(spot, "lens", minutes).get("line", "") == "spot.pho.closed_after"


func _make_touch_area(meta_key: String, item_id: String, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = "Touch_%s" % item_id
	area.collision_layer = TOUCH_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta(meta_key, item_id)
	area.set_meta("test_id", "%s.%s" % ["spot" if meta_key == "spot_id" else "npc", item_id])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	return area


func _build_ground() -> void:
	var length := end_x - start_x
	var mid := (start_x + end_x) / 2.0
	# The concrete floor with cracks and patches (R11).
	var hem_floor := Greybox.box(self, Vector3(length, 0.1, hem_width), Vector3(mid, -0.05, 0), Color("#A9A69C"), "HemFloor")
	var concrete := ShaderMaterial.new()
	concrete.shader = load("res://scenes/world/parts/concrete_floor.gdshader")
	concrete.set_shader_parameter("half_width", hem_width / 2.0)
	var noise := HouseMaterials.noise_textures()
	concrete.set_shader_parameter("noise_smooth", noise[0])
	concrete.set_shader_parameter("noise_detail", noise[1])
	hem_floor.material_override = concrete
	# A drain gutter in the middle of the hẻm, with a cover each 3 m.
	var drain := MeshBatch.new()
	drain.box("detail", Vector3(length, 0.012, 0.18), Vector3(mid, 0.006, 0), Color("#6F6C64"))
	var cover_x := start_x + 1.5
	while cover_x < end_x - 0.5:
		drain.box("metal", Vector3(0.5, 0.02, 0.3), Vector3(cover_x, 0.01, 0), Color("#4A4842"))
		for i in 5:
			drain.box("detail", Vector3(0.04, 0.022, 0.26), Vector3(cover_x - 0.2 + i * 0.1, 0.012, 0), Color("#2A2925"))
		cover_x += 3.0
	var drain_meshes := drain.commit(self, HouseMaterials.all(), "Drain")
	for instance: MeshInstance3D in drain_meshes.values():
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body := Greybox.solid_body(self, "HemSolid")
	# The end of the hẻm at the low X end is a wall.
	Greybox.solid_box(self, body, Vector3(0.3, 4.2, hem_width + 0.6), Vector3(start_x - 0.15, 2.1, 0),
			Color("#B9A98A"), "EndWall")
	# Parked motorbikes and plants in front of the gates on the opposite row.
	var scooter_colors := ["#C4362C", "#2F72C4", "#2A2A2A"]
	var props := [[1.6, "scooter"], [6.5, "plant"], [11.0, "scooter"], [19.5, "scooter"], [24.5, "plant"]]
	for i in props.size():
		var prop_x: float = start_x + float(props[i][0])
		var prop_z := hem_width / 2.0 - 0.42
		if props[i][1] == "plant":
			Greybox.potted_plant(self, Vector3(prop_x, 0, prop_z))
			Greybox.solid_shape(body, Vector3(0.5, 1.0, 0.5), Vector3(prop_x, 0.5, prop_z))
		else:
			Greybox.scooter(self, Vector3(prop_x, 0, prop_z), Color(scooter_colors[i % scooter_colors.size()]))
			Greybox.solid_shape(body, Vector3(1.8, 1.1, 0.6), Vector3(prop_x, 0.55, prop_z))
	# The city behind the houses.
	var far := Color("#7F98A3")
	for i in 9:
		var h := 12.0 + fmod(i * 37.0, 8.0)
		for side: float in [-1.0, 1.0]:
			Greybox.box(self, Vector3(5.5, h, 4.0),
					Vector3(start_x - 4.0 + i * 4.4, h / 2.0, side * (22.0 + fmod(i * 13.0, 6.0))), far)


## Concrete poles with thick, sagging bundles of many cables along the hẻm and
## across it (R7). They are one of the strongest features of the street.
func _build_cables() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4207
	var batch := MeshBatch.new()
	var body := Greybox.solid_body(self, "PoleSolid")
	var half := hem_width / 2.0
	var poles: Array[Vector3] = []
	var x := start_x + 1.2
	var side := 1.0
	while x < end_x:
		poles.append(Vector3(x, 0, side * (half - 0.14)))
		x += rng.randf_range(7.0, 9.0)
		side = -side
	var pole_height := 7.2
	for pole in poles:
		# A concrete pole: square, narrower at the top.
		batch.box("detail", Vector3(0.22, pole_height * 0.5, 0.22), pole + Vector3(0, pole_height * 0.25, 0), Color("#9C9A92"))
		batch.box("detail", Vector3(0.16, pole_height * 0.5, 0.16), pole + Vector3(0, pole_height * 0.75, 0), Color("#A6A49C"))
		batch.box("detail", Vector3(0.9, 0.08, 0.08), pole + Vector3(0, pole_height - 0.5, 0), Color("#8A8880"))
		Greybox.solid_shape(body, Vector3(0.22, 3.0, 0.22), pole + Vector3(0, 1.5, 0))
		# A coil of spare cable on the pole.
		batch.cylinder("cable", 0.22, 0.12, pole + Vector3(0, 5.2, 0), Color("#1C1C1C"), 10)
	var cable_colors := [Color("#151515"), Color("#202020"), Color("#2A2A2A"), Color("#3A3A3A"), Color("#4A4A48")]
	for i in poles.size():
		var a := poles[i] + Vector3(0, pole_height - 0.7, 0)
		# Along the hẻm to the next pole.
		if i + 1 < poles.size():
			var b := poles[i + 1] + Vector3(0, pole_height - 0.7, 0)
			_cable_bundle(batch, a, b, rng.randi_range(10, 18), rng, cable_colors)
		# Across the hẻm to the houses at the other side, for the homes.
		var other := Vector3(poles[i].x + rng.randf_range(-1.5, 1.5), pole_height - 2.0, -signf(poles[i].z) * (half + 0.05))
		_cable_bundle(batch, a + Vector3(0, -0.3, 0), other, rng.randi_range(3, 7), rng, cable_colors)
	var instances := batch.commit(self, HouseMaterials.all(), "Cables")
	if instances.has("cable"):
		(instances["cable"] as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A bundle of cables from a to b. Each cable sags a little more or less, so the
## bundle is thick and untidy.
func _cable_bundle(batch: MeshBatch, a: Vector3, b: Vector3, count: int, rng: RandomNumberGenerator,
		colors: Array) -> void:
	var length := a.distance_to(b)
	for c in count:
		var offset := Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))
		var sag := length * rng.randf_range(0.035, 0.07)
		var points := PackedVector3Array()
		var steps := maxi(6, int(length / 0.7))
		for s in steps + 1:
			var t := float(s) / steps
			var point := a.lerp(b, t) + offset * (1.0 - absf(t - 0.5) * 1.2)
			point.y -= sag * 4.0 * t * (1.0 - t)
			points.append(point)
		batch.tube("cable", points, rng.randf_range(0.007, 0.016), colors[rng.randi() % colors.size()], 4)


func _build_street_lamps() -> void:
	var body := Greybox.solid_body(self, "LampSolid")
	for x: float in [7.0, 21.5]:
		var pole_z := hem_width / 2.0 - 0.12
		Greybox.solid_box(self, body, Vector3(0.12, 4.4, 0.12), Vector3(x, 2.2, pole_z), Color("#3E4442"))
		Greybox.box(self, Vector3(0.08, 0.08, 1.2), Vector3(x, 4.35, pole_z - 0.55), Color("#3E4442"))
		_street_lamps.append(Greybox.lamp(self, Vector3(0.3, 0.12, 0.3),
				Vector3(x, 4.25, pole_z - 1.1), Color("#FFE7A0"), "StreetLamp"))
		var light := OmniLight3D.new()
		light.name = "StreetLight"
		light.light_color = Color("#FFE2B0")
		light.light_energy = 1.2
		light.omni_range = 7.0
		light.position = Vector3(x, 4.0, pole_z - 1.1)
		light.visible = false
		add_child(light)
		_street_lights.append(light)


func _build_floor_collider() -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = FLOOR_LAYER
	body.collision_mask = 0
	add_child(body)
	var road_w := beach.road_width
	var half := beach.play_half_length
	var areas := [
		# [size, center]: the hẻm floor and the floors of the shop rooms, then the beach road.
		[Vector3(end_x - start_x, 0.2, hem_width + 2.0 * TubeHouse.ROOM_DEPTH),
				Vector3((start_x + end_x) / 2.0, -0.1, 0)],
		[Vector3(road_w, 0.2, half * 2.0), Vector3(end_x + road_w / 2.0, -0.1, 0)],
	]
	for area: Array in areas:
		Greybox.solid_shape(body, area[0], area[1])


## Makes the navigation region. bake_navigation() fills it from the collision
## shapes of the floor and of the solid objects. The player walks on it with
## tap to walk.
func _build_navigation() -> void:
	var mesh := NavigationMesh.new()
	mesh.cell_size = NAV_CELL
	mesh.cell_height = 0.05
	mesh.agent_radius = 0.3
	mesh.agent_height = 1.7
	mesh.agent_max_climb = 0.2
	mesh.agent_max_slope = 30.0
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = Layers.FLOOR | Layers.SOLID
	var half := beach.play_half_length
	mesh.filter_baking_aabb = AABB(Vector3(start_x - 1.0, -1.0, -half),
			Vector3(end_x - start_x + beach.road_width + beach.sand_width + 2.0, 4.0, half * 2.0))
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	nav_region.navigation_mesh = mesh
	add_child(nav_region)
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, NAV_CELL)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, 0.05)


## Bakes the navigation mesh again. A cart that comes or goes changes the walk area.
## With "wait", the bake finishes before the function returns.
func bake_navigation(wait := false) -> void:
	if _baking:
		_bake_again = true
		return
	var mesh := nav_region.navigation_mesh
	_nav_source = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, _nav_source, self)
	if wait:
		NavigationServer3D.bake_from_source_geometry_data(mesh, _nav_source)
		nav_region.navigation_mesh = mesh
		return
	_baking = true
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, _nav_source, _on_baked)


func _on_baked() -> void:
	_baking = false
	var mesh := nav_region.navigation_mesh
	nav_region.navigation_mesh = null
	nav_region.navigation_mesh = mesh
	if _bake_again:
		_bake_again = false
		bake_navigation()


## Returns true when the spot is there now. A cart is there only in its opening hours.
func is_present(spot_id: String, minutes: int) -> bool:
	var spot := Content.spot(spot_id)
	if spot.get("kind") == "cart":
		return GameClock.is_open(spot.hours, minutes)
	return not spot.is_empty()


## Returns the spot of the shop room that contains the point, or "".
func room_at(point: Vector3) -> String:
	for spot_id: String in _spot_lots:
		var house: TubeHouse = houses[_spot_lots[spot_id]]
		if house.ground != "shop":
			continue
		var local := house.to_local(point)
		if absf(local.x) < house.width / 2.0 and local.z < 0.0 and local.z > -TubeHouse.ROOM_DEPTH:
			return spot_id
	return ""


## Returns the shutter position of the shop of the spot.
func shutter_of(spot_id: String) -> TubeHouse.Shutter:
	return houses[_spot_lots[spot_id]].shutter


## Shows the hẻm for the time: shutters, carts, people, and lights.
func update_time(minutes: int) -> void:
	_minutes = minutes
	var present_key := ""
	var dark := DayLight.lamps_on(minutes)
	for spot_id: String in _spot_lots:
		var spot := Content.spot(spot_id)
		var open := GameClock.is_open(spot.hours, minutes)
		var house: TubeHouse = houses[_spot_lots[spot_id]]
		var shutter := TubeHouse.Shutter.OPEN if open else TubeHouse.Shutter.CLOSED
		if not open:
			for rule: Dictionary in spot.get("shutter_half", []):
				if GameClock.in_range(rule, minutes):
					shutter = TubeHouse.Shutter.HALF
		# The shutter rolls when it changes during the game (R7), not at the start.
		house.set_shutter(shutter, _present_key != "")
		house.set_glow(dark and (open or spot.hours == null))
		_spot_lights[spot_id].visible = dark and (open or spot.hours == null)
		if _stall_open.has(spot_id):
			_stall_open[spot_id].visible = open
			_stall_closed[spot_id].visible = not open
			_stall_bodies[spot_id][0].collision_layer = Layers.SOLID if open else 0
			_stall_bodies[spot_id][1].collision_layer = 0 if open else Layers.SOLID
	for spot_id: String in carts:
		var present := is_present(spot_id, minutes)
		present_key += "1" if present else "0"
		carts[spot_id].visible = present
		_cart_areas[spot_id].collision_layer = TOUCH_LAYER if present else 0
		_cart_bodies[spot_id].collision_layer = Layers.SOLID if present else 0
		var lamp: MeshInstance3D = carts[spot_id].get_node("Cart/Lamp")
		lamp.material_override = Greybox.material(Color("#FFE7A0"), 2.5) if dark \
				else Greybox.material(Color("#B8B09A"))
	for npc_id: String in npcs:
		var npc_present := GameClock.is_open(Content.npc(npc_id).hours, minutes)
		npcs[npc_id].set_present(npc_present)
		present_key += "1" if npc_present else "0"
	helper.set_present(is_present("go", minutes))
	var tv_wanted := tv_on(minutes)
	if tv_wanted and not tv.playing:
		tv.play()
	elif not tv_wanted and tv.playing:
		tv.stop()
	for light in _street_lights:
		light.visible = dark
	for lamp in _street_lamps:
		lamp.material_override = Greybox.material(Color("#FFE7A0"), 2.5) if dark \
				else Greybox.material(Color("#B8B09A"))
	beach.update_time(minutes, Content.spots.boats_in)
	present_key += "1" if beach.boats_in.visible else "0"
	# Bake the walk area again when the carts, the stall, or the shutters change.
	for spot_id: String in _spot_lots:
		present_key += str(houses[_spot_lots[spot_id]].shutter)
		if _stall_open.has(spot_id):
			present_key += "1" if _stall_open[spot_id].visible else "0"
	if present_key != _present_key:
		var first := _present_key == ""
		_present_key = present_key
		bake_navigation.call_deferred(first)


## Returns all dynamic lights in the hẻm that are on.
func lights_on() -> Array[OmniLight3D]:
	var result: Array[OmniLight3D] = []
	for light: OmniLight3D in _spot_lights.values():
		if light.visible:
			result.append(light)
	for light in _street_lights:
		if light.visible:
			result.append(light)
	return result


func _physics_process(delta: float) -> void:
	if not helper.visible:
		return
	# The helper walks up and down the hẻm.
	var amplitude := (end_x - start_x) / 2.0 - 2.0
	var mid := (start_x + end_x) / 2.0
	_helper_phase += delta * HELPER_SPEED / amplitude
	helper.position.x = mid + amplitude * sin(_helper_phase)
	helper.rotation_degrees.y = 90.0 if cos(_helper_phase) > 0.0 else -90.0


func _process(delta: float) -> void:
	if not helper.visible:
		return
	# The helper clacks the sticks each 4 to 5 seconds.
	_scene_time += delta
	_clack_left -= delta
	if _clack_left <= 0.0:
		_clack_left = randf_range(4.0, 5.0)
		clack_count += 1
		clack_time = _scene_time
		clacked.emit(helper.global_position)
