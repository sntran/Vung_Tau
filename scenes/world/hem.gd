class_name Hem
extends Node3D
## The hẻm, built from data/world/hem_layout.json.
##
## Units are meters. The hẻm runs along the X axis. X = 0 is the homestay.
## Bãi Trước is at the high X end. The house fronts are at Z = -hem_width / 2
## and face +Z. The camera looks at them from the +Z side.

## The helper of the hủ tiếu gõ cart clacks the bamboo sticks.
signal clacked(position: Vector3)

const TubeHouseScene := preload("res://scenes/world/tube_house.tscn")
const NpcScene := preload("res://scenes/actors/npc.tscn")
const BeachScene := preload("res://scenes/world/beach.tscn")

const FLOOR_LAYER := 1
const TOUCH_LAYER := 2
## The walk area of the hẻm in Z. The player stays out of the carts in front of the houses.
const NAV_Z_MIN := -0.75
const NAV_Z_MAX := 1.5
const CART_Z := -1.3
const LOT_STAND_Z := -0.75
const CART_STAND_Z := 0.0
const NPC_STAND_Z := -0.6
const HELPER_Z := 1.0
const HELPER_SPEED := 0.9
const CLACK_BUBBLE_SECONDS := 1.1

var hem_width := 3.5
var start_x := 0.0
var end_x := 0.0
var houses: Dictionary = {}
var lot_x: Dictionary = {}
var stand_points: Dictionary = {}
var npc_stand_points: Dictionary = {}
var carts: Dictionary = {}
var npcs: Dictionary = {}
var helper: Npc
var beach: Beach
var nav_region: NavigationRegion3D
var clack_count := 0

var _spot_lots: Dictionary = {}
var _cart_areas: Dictionary = {}
var _spot_lights: Dictionary = {}
var _street_lights: Array[OmniLight3D] = []
var _street_lamps: Array[MeshInstance3D] = []
var _stall_open: Dictionary = {}
var _stall_closed: Dictionary = {}
var _helper_phase := 0.0
var _clack_left := 0.0
var _minutes := 0


func _ready() -> void:
	build()


func build() -> void:
	var layout: Dictionary = Content.layout
	hem_width = float(layout.hem_width)
	var floor_height := float(layout.floor_height)
	var lots: Array = layout.lots
	start_x = -float(lots[0].width) / 2.0
	var x := start_x
	for lot: Dictionary in lots:
		var w := float(lot.width)
		var center := x + w / 2.0
		lot_x[lot.id] = center
		_build_lot(lot, center, floor_height)
		x += w
	end_x = x
	for cart: Dictionary in layout.carts:
		_build_cart(cart)
	for npc_data: Dictionary in layout.npcs:
		_build_npc(npc_data)
	_build_helper()
	_build_ground()
	_build_street_lamps()
	beach = BeachScene.instantiate()
	beach.setup(layout.beach)
	beach.position = Vector3(end_x, 0, 0)
	add_child(beach)
	beach.build()
	stand_points[beach.spot_id] = beach.position + beach.stand_point()
	_build_floor_collider()
	_build_navigation()
	_clack_left = randf_range(4.0, 5.0)


func _build_lot(lot: Dictionary, center: float, floor_height: float) -> void:
	var house: TubeHouse = TubeHouseScene.instantiate()
	house.name = "Lot_%s" % lot.id
	house.width = float(lot.width)
	house.floors = int(lot.floors)
	house.floor_height = floor_height
	house.wall_color = Color(lot.wall_color)
	house.trim_color = Color(lot.trim_color)
	house.balcony = bool(lot.balcony)
	house.shutter_color = Color(lot.shutter_color)
	house.ground = lot.ground
	house.depth = 11.0 + fmod(center * 1.7, 3.0)
	if lot.has("sign"):
		house.sign_text = lot.sign.text
		house.sign_bg = Color(lot.sign.bg)
		house.sign_fg = Color(lot.sign.fg)
	house.position = Vector3(center, 0, -hem_width / 2.0)
	add_child(house)
	houses[lot.id] = house
	if not lot.has("spot"):
		return
	var spot_id: String = lot.spot
	_spot_lots[spot_id] = lot.id
	stand_points[spot_id] = Vector3(center, 0, LOT_STAND_Z)
	var area := _make_touch_area("spot_id", spot_id, Vector3(float(lot.width) - 0.3, 2.9, 0.4))
	area.position = Vector3(center, 1.45, -hem_width / 2.0 + 0.2)
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


## A sidewalk stall (cà phê cóc): stools and people when open, a stack of stools when closed.
func _build_stall(spot_id: String, center: float, width: float) -> void:
	var z := -hem_width / 2.0
	var open := Node3D.new()
	open.name = "StallOpen_%s" % spot_id
	open.position = Vector3(center, 0, z)
	add_child(open)
	var colors := ["#2F72C4", "#D8433A", "#2F72C4", "#2F9C5A"]
	for i in colors.size():
		Greybox.stool(open, Vector3(-width / 2.0 + 0.8 + i * 0.85, 0, 0.45), Color(colors[i]))
	Greybox.person(open, Vector3(-width / 2.0 + 1.65, 0, 0.45), Color("#F2F2F2"), Color("#273445"),
			Color("#C99A72"), Color("#151515"), 1.15, "Sitter1")
	Greybox.person(open, Vector3(-width / 2.0 + 2.5, 0, 0.45), Color("#E9C7D8"), Color("#3D3D55"),
			Color("#C99A72"), Color("#2B1C14"), 1.15, "Sitter2")
	for i in 3:
		Greybox.box(open, Vector3(0.07, 0.1, 0.07), Vector3(-width / 2.0 + 1.2 + i * 0.9, 1.08, 0.18),
				Color("#6B3E1E"))
	var closed := Node3D.new()
	closed.name = "StallClosed_%s" % spot_id
	closed.position = Vector3(center, 0, z)
	add_child(closed)
	for i in 4:
		Greybox.stool(closed, Vector3(width / 2.0 - 0.6, i * 0.06, 0.3), Color(colors[i]))
	_stall_open[spot_id] = open
	_stall_closed[spot_id] = closed


func _build_cart(cart: Dictionary) -> void:
	var spot_id: String = cart.spot
	var x := float(lot_x[cart.lot]) + float(cart.offset)
	var root := Node3D.new()
	root.name = "Cart_%s" % spot_id
	root.position = Vector3(x, 0, CART_Z)
	add_child(root)
	Greybox.cart(root, Vector3.ZERO, Color(cart.color), cart.sign.text, Color(cart.sign.bg),
			Color(cart.sign.fg))
	Greybox.person(root, Vector3(0.35, 0, -0.55), Color("#F0D6A0"), Color("#5A4A3A"),
			Color("#C99A72"), Color("#2A211C"), 1.55, "Seller")
	var area := _make_touch_area("spot_id", spot_id, Vector3(1.5, 1.9, 0.9))
	area.position = Vector3(x, 0.95, CART_Z)
	carts[spot_id] = root
	_cart_areas[spot_id] = area
	stand_points[spot_id] = Vector3(x, 0, CART_STAND_Z)


func _build_npc(data: Dictionary) -> void:
	var npc: Npc = NpcScene.instantiate()
	npc.npc_id = data.npc
	npc.name = "Npc_%s" % data.npc
	var x := float(lot_x[data.lot]) + float(data.offset)
	npc.position = Vector3(x, 0, -hem_width / 2.0 + 0.45)
	add_child(npc)
	npcs[data.npc] = npc
	npc_stand_points[data.npc] = Vector3(x, 0, NPC_STAND_Z)


func _build_helper() -> void:
	helper = NpcScene.instantiate()
	helper.name = "GoHelper"
	helper.shirt = Color("#D9D2C0")
	helper.pants = Color("#3A3A34")
	helper.hair = Color("#1B1B1B")
	helper.height = 1.45
	helper.position = Vector3(10, 0, HELPER_Z)
	add_child(helper)
	# The two bamboo sticks.
	Greybox.box(helper, Vector3(0.04, 0.04, 0.3), Vector3(0.3, 0.95, 0.15), Color("#C8A24A"))
	Greybox.box(helper, Vector3(0.04, 0.04, 0.22), Vector3(0.3, 1.0, 0.12), Color("#C8A24A"))


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
	Greybox.box(self, Vector3(length, 0.1, hem_width), Vector3(mid, -0.05, 0), Color("#A9A69C"), "HemFloor")
	Greybox.box(self, Vector3(length, 0.02, 0.25), Vector3(mid, 0.01, -hem_width / 2.0 + 0.125),
			Color("#77746B"), "Gutter")
	Greybox.box(self, Vector3(length, 0.15, 0.3), Vector3(mid, 0.075, hem_width / 2.0 + 0.15),
			Color("#8C897F"), "Curb")
	Greybox.box(self, Vector3(length + 20.0, 0.1, 40.0), Vector3(mid - 10.0, -0.12, hem_width / 2.0 + 20.3),
			Color("#9A978E"), "NearGround")
	# Parked motorbikes and plants on the near side. They are far enough from
	# the walk area that they do not hide the player from the camera.
	var scooter_colors := ["#C4362C", "#2F72C4", "#E8E1C8", "#2A2A2A"]
	var prop_x := start_x + 1.5
	var prop_index := 0
	while prop_x < end_x - 1.0:
		if prop_index % 3 == 2:
			Greybox.potted_plant(self, Vector3(prop_x, 0, hem_width / 2.0 + 1.8))
		else:
			var bike := Greybox.scooter(self, Vector3(prop_x, 0, hem_width / 2.0 + 1.8),
					Color(scooter_colors[prop_index % scooter_colors.size()]))
			bike.rotation_degrees.y = 8.0 if prop_index % 2 == 0 else -6.0
		prop_x += 3.1 + fmod(prop_index * 1.3, 1.4)
		prop_index += 1
	# The end of the hẻm at the low X end is a wall.
	Greybox.box(self, Vector3(0.3, 4.2, hem_width + 0.6), Vector3(start_x - 0.15, 2.1, 0),
			Color("#B9A98A"), "EndWall")
	# The city behind the houses.
	var far := Color("#7F98A3")
	for i in 9:
		var h := 9.0 + fmod(i * 37.0, 8.0)
		Greybox.box(self, Vector3(5.5, h, 4.0), Vector3(start_x - 4.0 + i * 4.4, h / 2.0, -19.0 - fmod(i * 13.0, 6.0)),
				far)
	# Overhead wires.
	for i in 3:
		var wire := Greybox.box(self, Vector3(length, 0.025, 0.025),
				Vector3(mid, 5.6 + i * 0.18, -hem_width / 2.0 + 0.6 + i * 0.25), Color("#222222"))
		wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_street_lamps() -> void:
	for x: float in [7.0, 21.5]:
		Greybox.box(self, Vector3(0.12, 4.4, 0.12), Vector3(x, 2.2, hem_width / 2.0 + 0.1), Color("#3E4442"))
		Greybox.box(self, Vector3(0.08, 0.08, 1.2), Vector3(x, 4.35, hem_width / 2.0 - 0.45), Color("#3E4442"))
		_street_lamps.append(Greybox.lamp(self, Vector3(0.3, 0.12, 0.3),
				Vector3(x, 4.25, hem_width / 2.0 - 1.0), Color("#FFE7A0"), "StreetLamp"))
		var light := OmniLight3D.new()
		light.name = "StreetLight"
		light.light_color = Color("#FFE2B0")
		light.light_energy = 1.2
		light.omni_range = 7.0
		light.position = Vector3(x, 4.0, hem_width / 2.0 - 1.0)
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
	var sand_end := road_w + beach.sand_width
	var areas := [
		# [size, center]
		# The hẻm floor and the ground on the near side. A tap on the near
		# ground walks the player to the nearest point of the walk area.
		[Vector3(end_x - start_x + 6.0, 0.2, hem_width + 24.0),
				Vector3((start_x - 6.0 + end_x) / 2.0, -0.1, 12.0)],
		[Vector3(road_w, 0.2, 20.0), Vector3(end_x + road_w / 2.0, -0.1, 0)],
		[Vector3(sand_end - road_w, 0.2, 30.0), Vector3(end_x + (road_w + sand_end) / 2.0, Beach.SAND_Y - 0.1, 0)],
	]
	for area: Array in areas:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = area[0]
		shape.shape = box
		shape.position = area[1]
		body.add_child(shape)


## Makes the navigation mesh of the hẻm floor and the beach road.
## The vertices are on a 0.25 m grid, the same as the cell size of the map.
func _build_navigation() -> void:
	var x0 := snappedf(start_x + 0.3, 0.25)
	var x1 := snappedf(end_x, 0.25)
	var x2 := snappedf(end_x + beach.road_width - 0.3, 0.25)
	var zs := -snappedf(beach.road_depth, 0.25)
	var z0 := NAV_Z_MIN
	var z1 := NAV_Z_MAX
	var zn := 2.5
	var mesh := NavigationMesh.new()
	mesh.cell_size = 0.25
	mesh.agent_radius = 0.3
	mesh.vertices = PackedVector3Array([
		Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1),  # 0-3 hẻm
		Vector3(x2, 0, z0), Vector3(x2, 0, z1),  # 4-5 road, middle part
		Vector3(x1, 0, zs), Vector3(x2, 0, zs),  # 6-7 road, low Z part
		Vector3(x1, 0, zn), Vector3(x2, 0, zn),  # 8-9 road, high Z part
	])
	# Godot wants the polygon vertices in clockwise order when seen from above.
	mesh.add_polygon(PackedInt32Array([0, 3, 2, 1]))
	mesh.add_polygon(PackedInt32Array([1, 2, 5, 4]))
	mesh.add_polygon(PackedInt32Array([6, 1, 4, 7]))
	mesh.add_polygon(PackedInt32Array([2, 8, 9, 5]))
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	nav_region.navigation_mesh = mesh
	add_child(nav_region)


## Returns true when the spot is there now. A cart is there only in its opening hours.
func is_present(spot_id: String, minutes: int) -> bool:
	var spot := Content.spot(spot_id)
	if spot.get("kind") == "cart":
		return GameClock.is_open(spot.hours, minutes)
	return not spot.is_empty()


## Shows the hẻm for the time: shutters, carts, people, and lights.
func update_time(minutes: int) -> void:
	_minutes = minutes
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
		house.set_shutter(shutter)
		house.set_glow(dark and (open or spot.hours == null))
		_spot_lights[spot_id].visible = dark and (open or spot.hours == null)
		if _stall_open.has(spot_id):
			_stall_open[spot_id].visible = open
			_stall_closed[spot_id].visible = not open
	for spot_id: String in carts:
		var present := is_present(spot_id, minutes)
		carts[spot_id].visible = present
		_cart_areas[spot_id].collision_layer = TOUCH_LAYER if present else 0
		var lamp: MeshInstance3D = carts[spot_id].get_node("Cart/Lamp")
		lamp.material_override = Greybox.material(Color("#FFE7A0"), 2.5) if dark \
				else Greybox.material(Color("#B8B09A"))
	for npc_id: String in npcs:
		npcs[npc_id].set_present(GameClock.is_open(Content.npc(npc_id).hours, minutes))
	helper.visible = is_present("go", minutes)
	for light in _street_lights:
		light.visible = dark
	for lamp in _street_lamps:
		lamp.material_override = Greybox.material(Color("#FFE7A0"), 2.5) if dark \
				else Greybox.material(Color("#B8B09A"))
	beach.update_time(minutes, Content.spots.boats_in)


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


func _process(delta: float) -> void:
	if not helper.visible:
		return
	# The helper walks up and down the hẻm and clacks the sticks each 4 to 5 seconds.
	var amplitude := (end_x - start_x) / 2.0 - 2.0
	var mid := (start_x + end_x) / 2.0
	_helper_phase += delta * HELPER_SPEED / amplitude
	helper.position.x = mid + amplitude * sin(_helper_phase)
	helper.rotation_degrees.y = 90.0 if cos(_helper_phase) > 0.0 else -90.0
	_clack_left -= delta
	if _clack_left <= 0.0:
		_clack_left = randf_range(4.0, 5.0)
		clack_count += 1
		helper.show_bubble(Content.ui_text("clack_bubble"), CLACK_BUBBLE_SECONDS)
		clacked.emit(helper.global_position)
