class_name Beach
extends Node3D
## Bãi Trước: the beach road, a low wall, sand, a flat sea to the horizon,
## two palm trees, fishing boats, and people who exercise in the early morning.
##
## The origin is the point where the hẻm meets the beach road. The road runs
## along the Z axis. The sea is at the high X end.

const SAND_Y := -0.35
const SEA_Y := -0.5

var road_width := 7.0
var road_depth := 4.0
var sand_width := 14.0
var wall_height := 0.7
var boat_colors: Array = []
var spot_id := "beach"
## The beach road and the sand go this far from the end of the hẻm, in Z.
var play_half_length := 30.0
## The width of the steps from the road down to the sand.
var steps_width := 2.4

var boats_in: Node3D
var boats_out: Node3D
var exercisers: Node3D
var touch_area: Area3D
var _lamps: Array[MeshInstance3D] = []
var _people: Array[Node3D] = []
## The bodies of the boats on the sand and of the people. They stop the player only at dawn.
var _bodies_in: Array[StaticBody3D] = []
var _time := 0.0


## Reads the beach parameters from the "beach" object of hem_layout.json.
func setup(data: Dictionary) -> void:
	road_width = float(data.road_width)
	road_depth = float(data.road_depth)
	sand_width = float(data.sand_width)
	wall_height = float(data.wall_height)
	boat_colors = data.boat_colors
	spot_id = data.spot
	play_half_length = float(data.play_half_length)
	steps_width = float(data.steps_width)


func build() -> void:
	var wall_x := road_width
	var half := play_half_length
	var solid := Greybox.solid_body(self, "BeachSolid")
	# Road surface. The hẻm floor collider covers the walk area of the road.
	Greybox.box(self, Vector3(road_width, 0.1, 80.0), Vector3(road_width / 2.0, -0.05, 0),
			Color("#5E5F5C"), "Road")
	Greybox.box(self, Vector3(0.12, 0.012, 80.0), Vector3(road_width / 2.0, 0.006, 0),
			Color("#E8E1C8"), "RoadLine")
	# The low wall between the road and the sand, with an opening for the steps.
	var wall_h := wall_height - SAND_Y
	var gap := steps_width / 2.0
	for side: float in [-1.0, 1.0]:
		var length := 40.0 - gap
		var center_z := side * (gap + length / 2.0)
		Greybox.solid_box(self, solid, Vector3(0.35, wall_h, length),
				Vector3(wall_x + 0.175, (wall_height + SAND_Y) / 2.0, center_z), Color("#C9C2B0"), "Wall")
		Greybox.box(self, Vector3(0.45, 0.08, length), Vector3(wall_x + 0.175, wall_height + 0.04, center_z),
				Color("#E3DDCC"), "WallTop")
	_build_steps(wall_x)
	# Sand and sea.
	Greybox.box(self, Vector3(sand_width + 4.0, 0.2, 200.0),
			Vector3(wall_x + 0.35 + (sand_width + 4.0) / 2.0, SAND_Y - 0.1, 0), Color("#CDB98A"), "Sand")
	var sea := Greybox.box(self, Vector3(6000.0, 0.1, 6000.0),
			Vector3(wall_x + sand_width + 3000.0, SEA_Y - 0.05, 0), Color("#2F6E8A"), "Sea")
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Greybox.box(self, Vector3(1.2, 0.03, 200.0), Vector3(wall_x + sand_width + 0.2, SAND_Y + 0.01, 0),
			Color("#F4F1E6"), "Foam")
	var sand_floor := StaticBody3D.new()
	sand_floor.name = "SandFloor"
	sand_floor.collision_layer = Layers.FLOOR
	sand_floor.collision_mask = 0
	add_child(sand_floor)
	Greybox.solid_shape(sand_floor, Vector3(sand_width + 4.0, 0.2, half * 2.0),
			Vector3(wall_x + 0.35 + (sand_width + 4.0) / 2.0, SAND_Y - 0.1, 0))
	for palm_pos: Vector3 in [Vector3(wall_x + 1.6, SAND_Y, -3.2), Vector3(wall_x + 2.2, SAND_Y, 3.6)]:
		Greybox.palm(self, palm_pos)
		Greybox.solid_shape(solid, Vector3(0.4, 4.0, 0.4), palm_pos + Vector3(0.1, 2.0, 0))
	# Lamps on the wall. They glow at night. They are not dynamic lights.
	for z in [-9.0, -3.0, 3.0]:
		Greybox.box(self, Vector3(0.08, 3.2, 0.08), Vector3(wall_x + 0.1, wall_height + 1.6, z),
				Color("#3E4442"))
		_lamps.append(Greybox.lamp(self, Vector3(0.35, 0.18, 0.35),
				Vector3(wall_x + 0.1, wall_height + 3.25, z), Color("#FFE7A0"), "WallLamp"))
	_build_bounds(wall_x, half)
	_build_boats()
	_build_exercisers()
	_build_touch_area()


## The steps from the road down to the sand, as a ramp.
func _build_steps(wall_x: float) -> void:
	var run := 2.0
	var drop := -SAND_Y
	var length := sqrt(run * run + drop * drop)
	var angle := atan2(drop, run)
	var center := Vector3(wall_x + run / 2.0, -drop / 2.0 - 0.05, 0)
	var ramp := Greybox.box(self, Vector3(length, 0.1, steps_width), center, Color("#C9C2B0"), "Steps")
	ramp.rotation.z = -angle
	var body := StaticBody3D.new()
	body.name = "StepsFloor"
	body.collision_layer = Layers.FLOOR
	body.collision_mask = 0
	add_child(body)
	var shape := Greybox.solid_shape(body, Vector3(length, 0.1, steps_width), center)
	shape.rotation.z = -angle
	# Painted step lines on the ramp.
	for i in 4:
		var t := (i + 0.5) / 4.0
		var line := Greybox.box(self, Vector3(0.06, 0.02, steps_width),
				Vector3(wall_x + run * t, -drop * t + 0.005, 0), Color("#AFA796"))
		line.rotation.z = -angle


## Walls that the player cannot see. They stop the player at the ends of the
## play area and at the water.
func _build_bounds(wall_x: float, half: float) -> void:
	var bounds := StaticBody3D.new()
	bounds.name = "Bounds"
	bounds.collision_layer = Layers.SOLID
	bounds.collision_mask = 0
	add_child(bounds)
	var water_x := wall_x + sand_width - 0.3
	Greybox.solid_shape(bounds, Vector3(0.3, 4.0, half * 2.0), Vector3(water_x, 1.0, 0))
	for side: float in [-1.0, 1.0]:
		Greybox.solid_shape(bounds, Vector3(water_x + 1.0, 4.0, 0.3), Vector3(water_x / 2.0, 1.0, side * half))


func _build_boats() -> void:
	boats_in = Node3D.new()
	boats_in.name = "BoatsIn"
	add_child(boats_in)
	boats_out = Node3D.new()
	boats_out.name = "BoatsOut"
	add_child(boats_out)
	var x0 := road_width + 0.35
	for i in boat_colors.size():
		var color := Color(boat_colors[i])
		var on_sand := Greybox.boat(boats_in, Vector3(x0 + 8.5 + i * 1.2, SAND_Y, -5.0 + i * 3.6), color)
		on_sand.rotation_degrees.y = 12.0 - i * 9.0
		var boat_body := Greybox.solid_body(on_sand, "BoatSolid")
		Greybox.solid_shape(boat_body, Vector3(5.6, 1.6, 1.6), Vector3(0.3, 0.8, 0))
		_bodies_in.append(boat_body)
		var at_sea := Greybox.boat(boats_out, Vector3(x0 + 70.0 + i * 45.0, SEA_Y, -30.0 + i * 28.0), color)
		at_sea.rotation_degrees.y = 30.0 * i
	# A basket of fish next to the boats.
	Greybox.cylinder(boats_in, 0.35, 0.3, Vector3(x0 + 6.8, SAND_Y + 0.15, -1.2), Color("#9C7A4A"), "Basket")
	Greybox.box(boats_in, Vector3(0.5, 0.05, 0.5), Vector3(x0 + 6.8, SAND_Y + 0.32, -1.2), Color("#B8C4CC"), "Fish")


func _build_exercisers() -> void:
	exercisers = Node3D.new()
	exercisers.name = "Exercisers"
	add_child(exercisers)
	var x0 := road_width + 0.35
	var shirts := ["#F2F2F2", "#E9C7D8", "#C4362C", "#2F72C4", "#F2C33C"]
	for i in shirts.size():
		var pos := Vector3(x0 + 2.5 + (i % 3) * 1.4, SAND_Y, -1.8 + i * 1.1)
		var person := Greybox.person(exercisers, pos, Color(shirts[i]), Color("#273445"),
				Color("#C99A72"), Color("#1B1B1B"), 1.6, "Exerciser%d" % i)
		person.rotation_degrees.y = -90.0
		_people.append(person)
		var person_body := Greybox.solid_body(person, "PersonSolid")
		Greybox.solid_shape(person_body, Vector3(0.6, 1.6, 0.4), Vector3(0, 0.8, 0))
		_bodies_in.append(person_body)


func _build_touch_area() -> void:
	touch_area = Area3D.new()
	touch_area.name = "BeachTouch"
	touch_area.collision_layer = Layers.TOUCH
	touch_area.collision_mask = 0
	touch_area.monitoring = false
	touch_area.set_meta("spot_id", spot_id)
	touch_area.set_meta("test_id", "spot.%s" % spot_id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# The area is higher than the wall, so a tap from the road can reach it.
	box.size = Vector3(5.0, 2.2, 6.0)
	shape.shape = box
	touch_area.add_child(shape)
	touch_area.position = Vector3(road_width + 2.6, 0.9, -1.5)
	add_child(touch_area)


## The point where the player stands to look at the beach, in local coordinates.
func stand_point() -> Vector3:
	return Vector3(road_width - 0.75, 0, 0)


## The focus point of the beach, in local coordinates: the top of the steps.
func focus_point() -> Vector3:
	return Vector3(road_width + 0.8, 0.5, 0)


## Shows the boats on the sand and the people at dawn. At other times, the boats are at sea.
func update_time(minutes: int, boats_rule: Dictionary) -> void:
	var dawn := GameClock.in_range(boats_rule, minutes)
	boats_in.visible = dawn
	exercisers.visible = dawn
	boats_out.visible = not dawn
	for body in _bodies_in:
		body.collision_layer = Layers.SOLID if dawn else 0
	var on := DayLight.lamps_on(minutes)
	for lamp in _lamps:
		lamp.material_override = Greybox.material(Color("#FFE7A0"), 2.5) if on \
				else Greybox.material(Color("#B8B09A"))


func _process(delta: float) -> void:
	if not exercisers.visible:
		return
	# The people swing their arms.
	_time += delta
	for i in _people.size():
		var swing := sin(_time * 3.0 + i) * 70.0
		_people[i].get_node("ArmLeft").rotation_degrees.x = swing
		_people[i].get_node("ArmRight").rotation_degrees.x = -swing
