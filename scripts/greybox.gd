class_name Greybox
extends RefCounted
## Builds simple shapes with correct proportions ("greybox").
## Plan 0002 replaces these shapes with real models.

static var _materials: Dictionary = {}


## Returns one shared material for each color, so that the renderer can batch the meshes.
static func material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "%s/%s" % [color.to_html(), emission]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	_materials[key] = mat
	return mat


## Adds a box. "pos" is the center of the box.
static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color,
		node_name := "") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	if node_name != "":
		node.name = node_name
	parent.add_child(node)
	return node


## Adds a vertical cylinder. "pos" is the center of the cylinder.
static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3,
		color: Color, node_name := "") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	if node_name != "":
		node.name = node_name
	parent.add_child(node)
	return node


static func sphere(parent: Node3D, radius: float, pos: Vector3, color: Color,
		node_name := "") -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	if node_name != "":
		node.name = node_name
	parent.add_child(node)
	return node


## Adds a lamp: a small box that glows. It is not a dynamic light.
static func lamp(parent: Node3D, size: Vector3, pos: Vector3, color: Color,
		node_name := "") -> MeshInstance3D:
	var node := box(parent, size, pos, color, node_name)
	node.material_override = material(color, 2.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Adds a sign: a colored board with text. The front of the sign faces +Z.
static func sign_board(parent: Node3D, text: String, size: Vector2, pos: Vector3,
		bg: Color, fg: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Sign"
	root.position = pos
	parent.add_child(root)
	box(root, Vector3(size.x, size.y, 0.08), Vector3.ZERO, bg, "Board")
	var label := Label3D.new()
	label.name = "Text"
	label.text = text
	label.font = preload("res://assets/fonts/BeVietnamPro-Bold.ttf")
	label.modulate = fg
	label.outline_size = 0
	label.position = Vector3(0, 0, 0.05)
	label.double_sided = false
	label.shaded = false
	# Make the text fill the board: 0.65 of the board height, and not wider than the board.
	label.font_size = 64
	label.pixel_size = size.y * 0.6 / 64.0
	var text_width := label.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			label.font_size).x * label.pixel_size
	if text_width > size.x * 0.92:
		label.pixel_size *= size.x * 0.92 / text_width
	root.add_child(label)
	return root


## Adds a simple person. The feet are at "pos". The person faces +Z.
static func person(parent: Node3D, pos: Vector3, shirt: Color, pants: Color, skin: Color,
		hair: Color, height := 1.65, node_name := "Person") -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	parent.add_child(root)
	var s := height / 1.65
	box(root, Vector3(0.14, 0.78, 0.16) * s, Vector3(-0.09, 0.39, 0) * s, pants, "LegLeft")
	box(root, Vector3(0.14, 0.78, 0.16) * s, Vector3(0.09, 0.39, 0) * s, pants, "LegRight")
	box(root, Vector3(0.42, 0.58, 0.24) * s, Vector3(0, 1.07, 0) * s, shirt, "Body")
	box(root, Vector3(0.1, 0.55, 0.12) * s, Vector3(-0.27, 1.06, 0) * s, shirt, "ArmLeft")
	box(root, Vector3(0.1, 0.55, 0.12) * s, Vector3(0.27, 1.06, 0) * s, shirt, "ArmRight")
	sphere(root, 0.13 * s, Vector3(0, 1.5, 0) * s, skin, "Head")
	box(root, Vector3(0.27, 0.1, 0.27) * s, Vector3(0, 1.6, -0.02) * s, hair, "Hair")
	return root


## Adds a plastic stool. "pos" is the floor point under the stool.
static func stool(parent: Node3D, pos: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Stool"
	root.position = pos
	parent.add_child(root)
	box(root, Vector3(0.3, 0.04, 0.3), Vector3(0, 0.3, 0), color)
	box(root, Vector3(0.26, 0.28, 0.26), Vector3(0, 0.14, 0), color.darkened(0.15))
	return root


## Adds a street cart. "pos" is the floor point under the center of the cart.
## The front of the cart faces +Z.
static func cart(parent: Node3D, pos: Vector3, color: Color, sign_text: String, sign_bg: Color,
		sign_fg: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Cart"
	root.position = pos
	parent.add_child(root)
	var dark := Color("#333333")
	cylinder(root, 0.22, 0.06, Vector3(-0.45, 0.22, 0.36), dark).rotation_degrees.x = 90
	cylinder(root, 0.22, 0.06, Vector3(0.45, 0.22, 0.36), dark).rotation_degrees.x = 90
	cylinder(root, 0.22, 0.06, Vector3(-0.45, 0.22, -0.36), dark).rotation_degrees.x = 90
	cylinder(root, 0.22, 0.06, Vector3(0.45, 0.22, -0.36), dark).rotation_degrees.x = 90
	box(root, Vector3(1.3, 0.55, 0.65), Vector3(0, 0.62, 0), color, "Body")
	box(root, Vector3(1.2, 0.45, 0.55), Vector3(0, 1.12, 0), Color(0.9, 0.95, 1.0, 0.45), "Glass")
	box(root, Vector3(0.05, 0.9, 0.05), Vector3(-0.6, 1.3, 0.28), dark)
	box(root, Vector3(0.05, 0.9, 0.05), Vector3(0.6, 1.3, 0.28), dark)
	box(root, Vector3(1.35, 0.06, 0.7), Vector3(0, 1.76, 0), color.darkened(0.2), "Roof")
	sign_board(root, sign_text, Vector2(1.3, 0.28), Vector3(0, 1.55, 0.33), sign_bg, sign_fg)
	lamp(root, Vector3(0.12, 0.12, 0.12), Vector3(0, 1.68, 0.2), Color("#FFE7A0"), "Lamp")
	return root


## Adds a palm tree. "pos" is the floor point under the tree.
static func palm(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Palm"
	root.position = pos
	parent.add_child(root)
	var trunk := Color("#7A5A3A")
	for i in 6:
		var seg := cylinder(root, 0.16 - i * 0.012, 1.1, Vector3(i * 0.06, 0.55 + i * 1.05, 0), trunk)
		seg.rotation_degrees.z = -3.0
	var leaf := Color("#3F8A4A")
	for i in 7:
		var holder := Node3D.new()
		holder.position = Vector3(0.36, 6.4, 0)
		holder.rotation_degrees = Vector3(0, i * 360.0 / 7.0, -28)
		root.add_child(holder)
		box(holder, Vector3(2.2, 0.05, 0.42), Vector3(1.05, 0, 0), leaf)
	return root


## Adds a wooden fishing boat. "pos" is the point under the center of the boat.
## The boat points along the X axis.
static func boat(parent: Node3D, pos: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Boat"
	root.position = pos
	parent.add_child(root)
	box(root, Vector3(4.6, 0.7, 1.5), Vector3(0, 0.35, 0), color, "Hull")
	box(root, Vector3(4.7, 0.12, 1.6), Vector3(0, 0.74, 0), Color("#E8E1C8"), "Rim")
	var bow := box(root, Vector3(1.1, 0.7, 1.06), Vector3(2.55, 0.42, 0), color, "Bow")
	bow.rotation_degrees.y = 45
	box(root, Vector3(1.2, 0.8, 1.1), Vector3(-0.8, 1.15, 0), Color("#E8E1C8"), "Cabin")
	# The painted eyes on the bow.
	sphere(root, 0.1, Vector3(2.2, 0.5, 0.76), Color("#F2F2E6"))
	sphere(root, 0.1, Vector3(2.2, 0.5, -0.76), Color("#F2F2E6"))
	return root


## Adds a parked motorbike. "pos" is the floor point under its center.
## The motorbike points along the X axis.
static func scooter(parent: Node3D, pos: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Scooter"
	root.position = pos
	parent.add_child(root)
	var dark := Color("#2A2A2A")
	cylinder(root, 0.26, 0.1, Vector3(-0.65, 0.26, 0), dark).rotation_degrees.x = 90
	cylinder(root, 0.26, 0.1, Vector3(0.65, 0.26, 0), dark).rotation_degrees.x = 90
	box(root, Vector3(1.1, 0.35, 0.36), Vector3(-0.1, 0.5, 0), color, "Body")
	box(root, Vector3(0.6, 0.12, 0.3), Vector3(-0.25, 0.74, 0), dark, "Seat")
	box(root, Vector3(0.14, 0.7, 0.3), Vector3(0.55, 0.75, 0), color, "Front")
	box(root, Vector3(0.06, 0.06, 0.6), Vector3(0.58, 1.1, 0), dark, "Handlebar")
	return root


## Adds a potted plant. "pos" is the floor point under the pot.
static func potted_plant(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Plant"
	root.position = pos
	parent.add_child(root)
	cylinder(root, 0.22, 0.4, Vector3(0, 0.2, 0), Color("#B5603A"), "Pot")
	sphere(root, 0.3, Vector3(0, 0.65, 0), Color("#3F8A4A"))
	sphere(root, 0.22, Vector3(0.15, 0.85, 0.05), Color("#5FAE5E"))
	return root
