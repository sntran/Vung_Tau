class_name Npc
extends Node3D
## A person in the hẻm. A person with an "npc_id" is touchable: a tap on the
## person walks the player to the person, and the person talks. The person
## speaks through a 3D audio player at the head (plan 0003, R11).

@export var npc_id := ""
@export var shirt := Color("#E7E2D6")
@export var pants := Color("#5A4A3A")
@export var skin := Color("#C99A72")
@export var hair := Color("#B9B4AA")
@export var height := 1.55
## A person that moves is on the layer MOVING. The navigation mesh does not use it.
@export var moving := false
## False for a person that only talks with other people (no touch area).
@export var touchable := true

## The player does not hear the voice at more than this distance (R11).
const VOICE_RANGE := 12.0

var touch_area: Area3D
var body: PhysicsBody3D
var figure: Node3D
var voice: AudioStreamPlayer3D
var _built := false


func _ready() -> void:
	build()


func build() -> void:
	if _built:
		return
	_built = true
	figure = Greybox.person(self, Vector3.ZERO, shirt, pants, skin, hair, height, "Figure")
	voice = AudioStreamPlayer3D.new()
	voice.name = "Voice"
	voice.position = Vector3(0, height - 0.1, 0)
	voice.max_distance = VOICE_RANGE
	voice.unit_size = 3.0
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(voice)
	# The body stops the player.
	body = AnimatableBody3D.new() if moving else StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = Layers.MOVING if moving else Layers.SOLID
	body.collision_mask = 0
	var capsule := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.25
	capsule_shape.height = height
	capsule.shape = capsule_shape
	capsule.position = Vector3(0, height / 2.0, 0)
	body.add_child(capsule)
	add_child(body)
	if npc_id != "" and touchable:
		touch_area = Area3D.new()
		touch_area.name = "Touch"
		touch_area.collision_layer = Layers.TOUCH
		touch_area.collision_mask = 0
		touch_area.monitoring = false
		touch_area.set_meta("npc_id", npc_id)
		touch_area.set_meta("test_id", "npc.%s" % npc_id)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.7, height + 0.1, 0.5)
		shape.shape = box
		shape.position = Vector3(0, (height + 0.1) / 2.0, 0)
		touch_area.add_child(shape)
		add_child(touch_area)


## Shows or hides the person. A hidden person cannot be touched.
func set_present(on: bool) -> void:
	visible = on
	if touch_area:
		touch_area.collision_layer = Layers.TOUCH if on else 0
	if body:
		body.collision_layer = (Layers.MOVING if moving else Layers.SOLID) if on else 0


## Turns the person to face a point (for example the player during a talk).
func face(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() > 0.01:
		rotation.y = atan2(to.x, to.z)


## Returns the direction that the person faces (the front is +Z in local coordinates).
func facing() -> Vector3:
	return global_basis.z


## The position of the head: the voice comes from here.
func head_position() -> Vector3:
	return global_position + Vector3(0, height - 0.1, 0)
