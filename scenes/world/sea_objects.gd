class_name SeaObjects
extends Node3D
## The objects on the sea of data/geo/build/sea_objects.json (plan 0005,
## R13a): cargo ships at anchor far offshore, small fishing boats in the bay of
## Bãi Trước, the ferry pier, and the rock groynes. The ships and the boats
## float: they move up and down with the tide. The pier and the groynes have
## collision, so the player can walk on them.

const PILE_SPACING := 6.0
const SEA_FLOOR := -4.0

var ships: Array = []
var boats: Array = []
var pier_parts := 0
var groyne_count := 0
var _floating: Node3D
var _boats_node: Node3D
var _time := 0.0


func setup(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	ships = parsed.get("cargo_ships", [])
	boats = parsed.get("fishing_boats", [])
	_floating = Node3D.new()
	_floating.name = "Ships"
	add_child(_floating)
	_boats_node = Node3D.new()
	_boats_node.name = "Boats"
	add_child(_boats_node)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.75
	var ship_batch := MeshBatch.new()
	for ship: Dictionary in ships:
		_add_ship(ship_batch, ship)
	ship_batch.commit(_floating, {"hull": material}, "Ship")
	var boat_batch := MeshBatch.new()
	for boat: Dictionary in boats:
		_add_boat(boat_batch, boat)
	boat_batch.commit(_boats_node, {"hull": material}, "Boat")
	var fixed := MeshBatch.new()
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = Layers.FLOOR
	body.collision_mask = 0
	add_child(body)
	var pier: Dictionary = parsed.get("ferry_pier", {})
	for part: Dictionary in pier.get("parts", []):
		_add_pier(fixed, body, part.points, float(pier.get("width_m", 6.0)), float(pier.get("deck_m", 2.8)))
		pier_parts += 1
	var groynes: Dictionary = parsed.get("groynes", {})
	for line: Dictionary in groynes.get("lines", []):
		_add_groyne(fixed, body, line.points, float(groynes.get("width_m", 4.0)), float(groynes.get("height_m", 1.6)),
				hash(line.osm))
		groyne_count += 1
	fixed.commit(self, {"hull": material}, "Fixed")
	return true


## Ships and boats float on the sea. The boats rock a little.
func update_sea(sea_level: float, delta: float) -> void:
	_time += delta
	_floating.position.y = sea_level
	_boats_node.position.y = sea_level + 0.05 * sin(_time * 1.3)


static func _place(item: Dictionary) -> Transform3D:
	var p: Array = item.position
	return Transform3D(Basis(Vector3.UP, deg_to_rad(-float(item.heading_deg))), Vector3(p[0], 0.0, p[1]))


## A cargo ship at anchor: the hull, the superstructure at the stern, and the
## cargo (containers, hatches, or tanks). The bow is at -Z.
func _add_ship(batch: MeshBatch, ship: Dictionary) -> void:
	var xform := _place(ship)
	var length := float(ship.length_m)
	var beam := length * 0.15
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ship.seed)
	var hull_colors := [Color("#1E2B3A"), Color("#2F2F33"), Color("#5A2420"), Color("#1F3D2E")]
	var hull: Color = hull_colors[rng.randi() % hull_colors.size()]
	var box := func(size: Vector3, center: Vector3, color: Color) -> void:
		batch.box("hull", size, xform * center, color, xform.basis)
	# The hull: red below the water line, the hull color above it, and a pointed bow.
	box.call(Vector3(beam, 3.0, length * 0.86), Vector3(0, -1.5, length * 0.06), Color("#7A2A22"))
	box.call(Vector3(beam, 7.0, length * 0.86), Vector3(0, 3.5, length * 0.06), hull)
	box.call(Vector3(beam * 0.55, 9.0, length * 0.1), Vector3(0, 2.6, -length * 0.42), hull)
	box.call(Vector3(beam * 0.3, 8.5, length * 0.06), Vector3(0, 2.8, -length * 0.49), hull)
	# The superstructure at the stern, with a funnel.
	var stern := length * 0.4
	box.call(Vector3(beam * 0.9, 10.0, length * 0.08), Vector3(0, 12.0, stern), Color("#E8E6E0"))
	box.call(Vector3(beam * 1.05, 1.0, length * 0.04), Vector3(0, 16.2, stern - length * 0.01), Color("#E8E6E0"))
	box.call(Vector3(beam * 0.25, 5.0, length * 0.03), Vector3(0, 19.0, stern + length * 0.02), Color("#C23A2B"))
	match String(ship.kind):
		"container":
			var colors := [Color("#B8452F"), Color("#2E5E8C"), Color("#D8A93A"), Color("#3E7A4B"), Color("#8C8C88"),
					Color("#6B3A7A")]
			var rows := int(length * 0.6 / 13.0)
			for i in rows:
				var z := -length * 0.32 + i * 13.0
				var height := 2.6 * rng.randi_range(2, 5)
				box.call(Vector3(beam * 0.92, height, 12.2), Vector3(0, 7.0 + height / 2.0, z),
						colors[rng.randi() % colors.size()])
		"bulk":
			for i in 5:
				var z := -length * 0.3 + i * length * 0.13
				box.call(Vector3(beam * 0.7, 1.4, length * 0.09), Vector3(0, 7.7, z), Color("#6B6B66"))
				if i < 4:
					box.call(Vector3(1.0, 12.0, 1.0), Vector3(beam * 0.3, 13.0, z + length * 0.065), Color("#D9B23A"))
		_:
			box.call(Vector3(beam * 0.9, 0.4, length * 0.7), Vector3(0, 7.2, -length * 0.02), Color("#3F5A44"))
			box.call(Vector3(beam * 0.15, 1.2, length * 0.66), Vector3(0, 8.0, -length * 0.02), Color("#B9B5AA"))


## A small wooden fishing boat (ghe): a blue hull with a red line, and a cabin.
func _add_boat(batch: MeshBatch, boat: Dictionary) -> void:
	var xform := _place(boat)
	var length := float(boat.length_m)
	var beam := length * 0.3
	var box := func(size: Vector3, center: Vector3, color: Color) -> void:
		batch.box("hull", size, xform * center, color, xform.basis)
	box.call(Vector3(beam, 1.1, length * 0.8), Vector3(0, 0.15, 0.05 * length), Color("#2F64A8"))
	box.call(Vector3(beam * 0.6, 1.0, length * 0.2), Vector3(0, 0.35, -0.48 * length), Color("#2F64A8"))
	box.call(Vector3(beam * 1.02, 0.18, length * 0.82), Vector3(0, 0.62, 0.05 * length), Color("#B8312A"))
	box.call(Vector3(beam * 0.7, 1.4, length * 0.25), Vector3(0, 1.4, 0.18 * length), Color("#D9D2BE"))
	box.call(Vector3(beam * 0.8, 0.12, length * 0.3), Vector3(0, 2.15, 0.18 * length), Color("#3C6A9E"))
	box.call(Vector3(0.12, 3.5, 0.12), Vector3(0, 2.2, -0.15 * length), Color("#6B4E33"))


## The ferry pier: a concrete deck on piles, with a low rail.
func _add_pier(batch: MeshBatch, body: StaticBody3D, points: Array, width: float, deck: float) -> void:
	for i in points.size() - 1:
		var a := Vector3(points[i][0], deck, points[i][1])
		var b := Vector3(points[i + 1][0], deck, points[i + 1][1])
		var length := a.distance_to(b)
		if length < 0.1:
			continue
		var basis := Basis.looking_at((b - a).normalized(), Vector3.UP)
		var middle := (a + b) / 2.0
		batch.box("hull", Vector3(width, 0.5, length + 0.5), middle, Color("#B9B4A8"), basis)
		for side in [-1.0, 1.0]:
			batch.box("hull", Vector3(0.15, 0.9, length), middle + basis * Vector3(side * (width / 2.0 - 0.1), 0.7, 0),
					Color("#D8D4CA"), basis)
		var count := int(length / PILE_SPACING) + 1
		for j in count:
			var at := a.lerp(b, float(j) / maxf(count - 1, 1))
			for side in [-1.0, 1.0]:
				var pile := at + basis * Vector3(side * (width / 2.0 - 0.4), 0, 0)
				batch.box("hull", Vector3(0.5, deck - SEA_FLOOR, 0.5), Vector3(pile.x, (deck + SEA_FLOOR) / 2.0 - 0.25,
						pile.z), Color("#8E8A80"))
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(width, 0.5, length + 0.5)
		shape.shape = box_shape
		shape.transform = Transform3D(basis, middle)
		body.add_child(shape)


## A groyne: a line of rough rocks from the sea wall into the sea.
func _add_groyne(batch: MeshBatch, body: StaticBody3D, points: Array, width: float, height: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in points.size() - 1:
		var a := Vector3(points[i][0], 0.0, points[i][1])
		var b := Vector3(points[i + 1][0], 0.0, points[i + 1][1])
		var length := a.distance_to(b)
		if length < 0.1:
			continue
		var count := int(length / 1.2) + 1
		for j in count:
			var at := a.lerp(b, float(j) / maxf(count - 1, 1))
			for k in 3:
				var size := Vector3(rng.randf_range(1.0, 1.8), rng.randf_range(0.8, 1.4), rng.randf_range(1.0, 1.8))
				var offset := Vector3(rng.randf_range(-width / 2.0, width / 2.0), 0, rng.randf_range(-0.5, 0.5))
				var top := height - absf(offset.x) * 0.25 + rng.randf_range(-0.2, 0.1)
				var tint := rng.randf_range(0.85, 1.1)
				batch.box("hull", Vector3(size.x, top - SEA_FLOOR, size.z), at + offset + Vector3(0, (top + SEA_FLOOR) / 2.0, 0),
						Color("#6E6A62") * tint, Basis(Vector3.UP, rng.randf() * TAU))
		var basis := Basis.looking_at((b - a).normalized(), Vector3.UP)
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(width * 0.8, 0.6, length)
		shape.shape = box_shape
		shape.transform = Transform3D(basis, (a + b) / 2.0 + Vector3(0, height - 0.5, 0))
		body.add_child(shape)
