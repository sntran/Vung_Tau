class_name MorningExercise
extends Node3D
## The morning exercise at Bãi Trước (plan 0023, R9d): data/world/exercise.json.
##
## Each person is a model of World (a person order with the routine as its
## animation), and starts the loop at a time of its own. A capsule body keeps
## the player out of each person. The groups show from "from" to "to" only.

const PATH := "res://data/world/exercise.json"
## The body of a person for the collisions of the player.
const BODY_RADIUS := 0.28
const BODY_HEIGHT := 1.7

## The groups by id: {"node", "people": [WorldModel], "bodies": [CollisionShape3D], "from", "to"}.
var groups: Dictionary = {}


func setup(world: VungTau, path := PATH) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("MorningExercise: cannot read %s." % path)
		return false
	for entry: Dictionary in parsed.get("groups", []):
		_add_group(world, entry)
	return true


static func minutes_of(text: String) -> int:
	var parts := text.split(":")
	return int(parts[0]) * 60 + (int(parts[1]) if parts.size() > 1 else 0)


func _add_group(world: VungTau, entry: Dictionary) -> void:
	var group := Node3D.new()
	group.name = "Exercise_" + str(entry.id)
	add_child(group)
	var body := StaticBody3D.new()
	body.name = "Bodies"
	body.collision_layer = Layers.SOLID
	body.collision_mask = 0
	group.add_child(body)
	var facing := Vector3(entry.facing[0], 0.0, entry.facing[1]).normalized()
	var right := facing.cross(Vector3.UP).normalized()
	var leader_at := Vector3(entry.leader_at[0], 0.0, entry.leader_at[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry.get("seed", 1))
	var places: Array = []
	# The leader faces the group; the people face the leader.
	places.append({"id": entry.leader, "at": leader_at, "front": facing})
	var per_row := int(entry.get("per_row", 3))
	var people: Array = entry.get("people", [])
	for i in people.size():
		var column := i % per_row - (per_row - 1) / 2.0
		var row := i / per_row
		var at := leader_at + facing * (float(entry.first_row) + row * float(entry.row_gap)) \
				+ right * column * float(entry.across)
		at += Vector3(rng.randf_range(-0.1, 0.1), 0.0, rng.randf_range(-0.1, 0.1))
		places.append({"id": people[i], "at": at, "front": -facing})
	var models: Array[WorldModel] = []
	var shapes: Array[CollisionShape3D] = []
	for place: Dictionary in places:
		var model := WorldModel.make(str(place.id))
		if model == null:
			continue
		var at: Vector3 = place.at
		at.y = world.ground_height(at.x, at.z)
		model.transform = Transform3D(Basis.looking_at(-(place.front as Vector3), Vector3.UP), at)
		group.add_child(model)
		model.play(str(entry.routine), rng.randf())
		models.append(model)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = BODY_RADIUS
		capsule.height = BODY_HEIGHT
		shape.shape = capsule
		shape.position = at + Vector3(0, BODY_HEIGHT / 2.0, 0)
		body.add_child(shape)
		shapes.append(shape)
	groups[entry.id] = {"node": group, "people": models, "bodies": shapes, "body": body,
			"from": minutes_of(str(entry.get("from", "05:00"))), "to": minutes_of(str(entry.get("to", "06:30")))}


## Shows the groups at their times, with their bodies.
func update_time(minutes: int) -> void:
	for group_id: String in groups:
		var g: Dictionary = groups[group_id]
		var on := minutes >= int(g.from) and minutes < int(g.to)
		var node: Node3D = g.node
		if node.visible == on and node.has_meta("set"):
			continue
		node.set_meta("set", true)
		node.visible = on
		for shape: CollisionShape3D in g.bodies:
			shape.disabled = not on
		for model: WorldModel in g.people:
			model.set_animation_active(on)
