class_name TubeHouse
extends Node3D
## One tube house (nhà ống), built from parameters.
##
## The origin is the center of the front wall at the floor. The front faces +Z.
## A shop has a rolling metal shutter (cửa cuốn) with three positions.

enum Shutter { OPEN, HALF, CLOSED }

## The ground floor opening of a shop.
const OPENING_HEIGHT := 2.6
## The rolled shutter box at the top of the opening.
const ROLL_HEIGHT := 0.3
## The height of the shutter in the HALF position.
const HALF_HEIGHT := 1.1

@export var width := 4.5
@export var floors := 3
@export var floor_height := 3.2
@export var depth := 12.0
@export var wall_color := Color("#E8D27A")
@export var trim_color := Color("#B8963A")
@export var balcony := false
@export var shutter_color := Color("#3F7FA6")
@export_enum("gate", "shop", "wall") var ground := "gate"
@export var sign_text := ""
@export var sign_bg := Color("#C4362C")
@export var sign_fg := Color("#F2C33C")

var shutter := Shutter.CLOSED
var _shutter_node: MeshInstance3D
var _glow_nodes: Array[Node3D] = []
var _built := false


func _ready() -> void:
	build()


## Makes the geometry. The function does nothing when the house is already built.
func build() -> void:
	if _built:
		return
	_built = true
	var height := floors * floor_height
	Greybox.box(self, Vector3(width, height, depth), Vector3(0, height / 2.0, -depth / 2.0),
			wall_color, "Body")
	# Parapet at the top of the front wall.
	Greybox.box(self, Vector3(width, 0.5, 0.25), Vector3(0, height + 0.25, -0.12), trim_color,
			"Parapet")
	match ground:
		"shop":
			_build_shop()
		"gate":
			_build_gate()
		"wall":
			_build_wall()
	for i in range(1, floors):
		_build_floor(i)
	if sign_text != "":
		var sign_width := width - 0.4 if ground == "shop" else minf(width * 0.6, 2.6)
		Greybox.sign_board(self, sign_text, Vector2(sign_width, 0.5),
				Vector3(0, OPENING_HEIGHT + 0.35, 0.12), sign_bg, sign_fg)
	set_shutter(shutter)
	set_glow(false)


func _build_shop() -> void:
	var w := width - 0.5
	var interior := Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	Greybox.box(interior, Vector3(w, OPENING_HEIGHT, 0.04), Vector3(0, OPENING_HEIGHT / 2.0, 0.02),
			Color("#6B5240"), "Back")
	Greybox.box(interior, Vector3(w * 0.4, 0.9, 0.5), Vector3(-w * 0.25, 0.45, 0.3),
			Color("#C9D1D3"), "Counter")
	Greybox.cylinder(interior, 0.22, 0.4, Vector3(-w * 0.25, 1.1, 0.3), Color("#B7BFC1"), "Pot")
	Greybox.box(interior, Vector3(0.8, 0.05, 0.6), Vector3(w * 0.22, 0.6, 0.35), Color("#C9D1D3"),
			"Table")
	Greybox.stool(interior, Vector3(w * 0.1, 0, 0.75), Color("#D8433A"))
	Greybox.stool(interior, Vector3(w * 0.34, 0, 0.75), Color("#2F72C4"))
	var lamp := Greybox.lamp(interior, Vector3(w * 0.8, 0.06, 0.06), Vector3(0, OPENING_HEIGHT - 0.15, 0.08),
			Color("#FFE7A0"), "Lamp")
	_glow_nodes.append(lamp)
	Greybox.box(self, Vector3(w + 0.2, ROLL_HEIGHT, 0.3), Vector3(0, OPENING_HEIGHT + ROLL_HEIGHT / 2.0 - 0.15, 0.15),
			Color("#8E979A"), "ShutterRoll")
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, 1.0, 0.04)
	_shutter_node = MeshInstance3D.new()
	_shutter_node.name = "Shutter"
	_shutter_node.mesh = mesh
	_shutter_node.material_override = Greybox.material(Color("#A7AFB2"))
	add_child(_shutter_node)


func _build_gate() -> void:
	var w := width - 0.6
	Greybox.box(self, Vector3(w, 2.4, 0.04), Vector3(0, 1.2, 0.02), Color("#3A3A34"), "Gate")
	var bars := 10
	for i in bars:
		var x := -w / 2.0 + w * (i + 0.5) / bars
		Greybox.box(self, Vector3(0.04, 2.3, 0.05), Vector3(x, 1.2, 0.06), Color("#8E8A7A"))
	Greybox.box(self, Vector3(w, 0.05, 0.05), Vector3(0, 1.9, 0.06), Color("#8E8A7A"))
	var lamp := Greybox.lamp(self, Vector3(0.18, 0.18, 0.12), Vector3(w / 2.0 - 0.2, 2.6, 0.1),
			Color("#FFE7A0"), "GateLamp")
	_glow_nodes.append(lamp)


func _build_wall() -> void:
	Greybox.box(self, Vector3(width, OPENING_HEIGHT, 0.04), Vector3(0, OPENING_HEIGHT / 2.0, 0.02),
			wall_color.darkened(0.08), "GroundWall")
	Greybox.box(self, Vector3(width - 0.4, 0.06, 0.25), Vector3(0, 1.0, 0.12), trim_color, "Ledge")


func _build_floor(index: int) -> void:
	var y := index * floor_height
	Greybox.box(self, Vector3(width, 0.15, 0.1), Vector3(0, y, 0.05), trim_color, "Trim%d" % index)
	var window_w := width * 0.5
	Greybox.box(self, Vector3(window_w + 0.16, 1.56, 0.06), Vector3(0, y + 1.5, 0.03),
			trim_color.darkened(0.2), "WindowFrame%d" % index)
	Greybox.box(self, Vector3(window_w / 2.0 - 0.04, 1.4, 0.06), Vector3(-window_w / 4.0, y + 1.5, 0.06),
			shutter_color)
	Greybox.box(self, Vector3(window_w / 2.0 - 0.04, 1.4, 0.06), Vector3(window_w / 4.0, y + 1.5, 0.06),
			shutter_color)
	if balcony:
		var bw := width - 0.3
		Greybox.box(self, Vector3(bw, 0.12, 0.8), Vector3(0, y + 0.06, 0.4), trim_color.lightened(0.2),
				"Balcony%d" % index)
		Greybox.box(self, Vector3(bw, 0.05, 0.05), Vector3(0, y + 1.0, 0.78), Color("#4A4A44"))
		var posts := 7
		for i in posts:
			var x := -bw / 2.0 + bw * i / (posts - 1)
			Greybox.box(self, Vector3(0.04, 0.9, 0.04), Vector3(x, y + 0.55, 0.78), Color("#4A4A44"))


## Moves the shutter. A house that is not a shop has no shutter.
func set_shutter(value: Shutter) -> void:
	shutter = value
	if _shutter_node == null:
		return
	var h := 0.0
	match value:
		Shutter.CLOSED:
			h = OPENING_HEIGHT
		Shutter.HALF:
			h = HALF_HEIGHT
		Shutter.OPEN:
			h = 0.0
	_shutter_node.visible = h > 0.0
	_shutter_node.scale = Vector3(1, maxf(h, 0.01), 1)
	_shutter_node.position = Vector3(0, OPENING_HEIGHT - h / 2.0, 0.08)


## Turns the lamps of the house on or off.
func set_glow(on: bool) -> void:
	for node in _glow_nodes:
		var mesh := node as MeshInstance3D
		if on:
			mesh.material_override = Greybox.material(Color("#FFE7A0"), 2.5)
		else:
			mesh.material_override = Greybox.material(Color("#B8B09A"))
