class_name Npc
extends Node3D
## A person in the hẻm. A person with an "npc_id" is touchable: a tap on the
## person walks the player to the person and opens the talk panel.

@export var npc_id := ""
@export var shirt := Color("#E7E2D6")
@export var pants := Color("#5A4A3A")
@export var skin := Color("#C99A72")
@export var hair := Color("#B9B4AA")
@export var height := 1.55

var touch_area: Area3D
var bubble: Label3D
var figure: Node3D
var _bubble_left := 0.0
var _built := false


func _ready() -> void:
	build()


func build() -> void:
	if _built:
		return
	_built = true
	figure = Greybox.person(self, Vector3.ZERO, shirt, pants, skin, hair, height, "Figure")
	bubble = Label3D.new()
	bubble.name = "Bubble"
	bubble.font = preload("res://assets/fonts/BeVietnamPro-Italic.ttf")
	bubble.font_size = 64
	bubble.pixel_size = 0.004
	bubble.modulate = Color("#1D2725")
	bubble.outline_modulate = Color("#FFF8E0")
	bubble.outline_size = 18
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.position = Vector3(0, height + 0.55, 0)
	bubble.visible = false
	add_child(bubble)
	if npc_id != "":
		touch_area = Area3D.new()
		touch_area.name = "Touch"
		touch_area.collision_layer = 2
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
		touch_area.collision_layer = 2 if on else 0


## Shows a small speech bubble for some seconds.
func show_bubble(text: String, seconds: float) -> void:
	bubble.text = text
	bubble.visible = true
	_bubble_left = seconds


func is_bubble_visible() -> bool:
	return bubble.visible and visible


func _process(delta: float) -> void:
	if _bubble_left > 0.0:
		_bubble_left -= delta
		if _bubble_left <= 0.0:
			bubble.visible = false
