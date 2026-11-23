class_name Scooters
extends Node3D
## The parked scooters that the player can ride (plan 0018, D1, R4).
##
## A scooter is in a row of World (data/world/parked_rows.json: a WorldRow),
## or a WorldModel of its own (the test street, the start points of R8, and
## each scooter where the player got off). When the player rides one, it
## leaves its row; where the player gets off, it stays on its stand as a
## model of its own, with a solid body, and anyone can ride it again. Only
## one scooter moves at a time.

## The player looks at a scooter within this distance to ride it (R4).
const RIDE_RANGE := 2.0
## The box of a scooter for the look (m): width, height, length.
const BOX := Vector3(0.7, 1.2, 1.9)
## The box of the solid body of a parked scooter of its own.
const SOLID := Vector3(0.45, 1.1, 1.8)

## Each scooter: {"at": Transform3D in the world (front to +Z), "paint", "pose",
## "row": WorldRow or null, "index": the index in the row, "node": WorldModel
## or null, "solid": CollisionShape3D or null}.
var parked: Array[Dictionary] = []
var _body: StaticBody3D


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "ScooterSolids"
	_body.collision_layer = Layers.SOLID
	_body.collision_mask = 0
	add_child(_body)


## The scooters of a row of World.
func add_row(row: WorldRow) -> void:
	for item: Dictionary in row.items_of(Parked.MODEL):
		parked.append({"at": item.at, "paint": item.paint, "pose": item.pose, "row": row,
				"index": item.index, "node": null, "solid": null})


## A scooter that is a model of its own, with its solid shape (or null).
func add_node(node: WorldModel, solid: CollisionShape3D = null) -> void:
	parked.append({"at": node.global_transform, "paint": node.paint,
			"pose": {}, "row": null, "index": -1, "node": node, "solid": solid})


## Parks a scooter at the transform (front to +Z): on its center stand, with a
## solid body. "model" is the WorldModel of the scooter, or null for a new one.
func park(at: Transform3D, paint: Color, model: WorldModel = null) -> Dictionary:
	if model == null:
		model = WorldModel.make(Parked.MODEL, paint)
		if model == null:
			return {}
	model.name = "Scooter_%d" % parked.size()
	model.paint = paint
	add_child(model)
	model.global_transform = at
	model.set_pose({"stand": Parked.stand_angle(), "fork": 0.0, "side_stand": 0.0})
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SOLID
	shape.shape = box
	shape.transform = Transform3D(at.basis.orthonormalized(), at.origin + Vector3(0, SOLID.y / 2.0, 0))
	_body.add_child(shape)
	var entry := {"at": at, "paint": paint, "pose": {}, "row": null, "index": -1, "node": model, "solid": shape}
	parked.append(entry)
	return entry


## True when the scooter shows now (a row of some hours is hidden at the other hours).
func is_there(entry: Dictionary) -> bool:
	if entry.row != null:
		return (entry.row as Node3D).is_visible_in_tree() and not _row_hidden(entry)
	return entry.node != null and is_instance_valid(entry.node) and (entry.node as Node3D).is_visible_in_tree()


func _row_hidden(entry: Dictionary) -> bool:
	for item: Dictionary in (entry.row as WorldRow).items_of(Parked.MODEL):
		if item.index == entry.index:
			return item.hidden
	return true


## The index of the scooter that the player looks at, within RIDE_RANGE of the
## player ("feet"), or -1. The ray of the view must go through its box.
func looked_at(eye: Vector3, forward: Vector3, feet: Vector3) -> int:
	var best := -1
	var best_t := INF
	for i in parked.size():
		var entry: Dictionary = parked[i]
		var at: Transform3D = entry.at
		var flat := Vector2(at.origin.x - feet.x, at.origin.z - feet.z)
		if flat.length() > RIDE_RANGE + BOX.z / 2.0:
			continue
		if not is_there(entry):
			continue
		# The nearest point of the box to the feet must be within RIDE_RANGE.
		var local_feet := at.affine_inverse() * feet
		var nearest := Vector3(clampf(local_feet.x, -BOX.x / 2.0, BOX.x / 2.0), 0.0,
				clampf(local_feet.z, -BOX.z / 2.0, BOX.z / 2.0))
		if Vector2(local_feet.x - nearest.x, local_feet.z - nearest.z).length() > RIDE_RANGE:
			continue
		var t := _ray_box(at.affine_inverse() * eye, at.basis.inverse() * forward)
		if t < best_t:
			best_t = t
			best = i
	return best


## The distance along the ray (local frame of the scooter) to its box, or INF.
static func _ray_box(origin: Vector3, direction: Vector3) -> float:
	var lo := Vector3(-BOX.x / 2.0, 0.0, -BOX.z / 2.0)
	var hi := Vector3(BOX.x / 2.0, BOX.y, BOX.z / 2.0)
	var t0 := 0.0
	var t1 := 10.0
	for axis in 3:
		var d := direction[axis]
		if absf(d) < 0.00001:
			if origin[axis] < lo[axis] or origin[axis] > hi[axis]:
				return INF
			continue
		var a := (lo[axis] - origin[axis]) / d
		var b := (hi[axis] - origin[axis]) / d
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
		if t0 > t1:
			return INF
	return t0


## Takes the scooter out of its place for a ride: returns a WorldModel of it
## (not in the tree) and its transform. Only one scooter moves at a time.
func take(index: int) -> Dictionary:
	if index < 0 or index >= parked.size():
		return {}
	var entry: Dictionary = parked[index]
	parked.remove_at(index)
	var model: WorldModel = entry.node
	if model != null and is_instance_valid(model):
		if model.get_parent() != null:
			model.get_parent().remove_child(model)
	else:
		model = WorldModel.make(Parked.MODEL, entry.paint)
	if entry.row != null:
		(entry.row as WorldRow).set_hidden(entry.index, true)
	if entry.solid != null and is_instance_valid(entry.solid):
		(entry.solid as CollisionShape3D).queue_free()
	return {"model": model, "at": entry.at, "paint": entry.paint}


## The scooter nearest to a point, or -1.
func nearest(point: Vector3, max_distance := INF) -> int:
	var best := -1
	var best_d := max_distance
	for i in parked.size():
		var d := Vector2(parked[i].at.origin.x - point.x, parked[i].at.origin.z - point.z).length()
		if d < best_d and is_there(parked[i]):
			best_d = d
			best = i
	return best
