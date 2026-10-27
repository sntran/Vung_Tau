class_name BoulderBuilder
extends RefCounted
## The granite boulders of the rocky coasts and of the small islands (report
## 0005, D-0005-03 and D-0005-05): the cape of Mũi Nghinh Phong and the islet
## of Hòn Bà are piles of large grey and brown boulders, not smooth ground.
##
## A boulder is a sphere with a rough, flat shape. The near form has 80
## triangles, and the far form has 20 triangles with the same shape. The
## boulders of each CELL meters of a near chunk are two MultiMeshes: the near
## form to NEAR_M and the far form from NEAR_M to the distance of the quality
## preset (FAR_M). The functions that make the meshes are static, and
## place() uses no nodes, so a worker thread can run it.

## The rock mask value of the boulders (1 is the bare rock of the rocky coasts
## and the islands, about 0.55 the low rocks of the Hòn Bà path).
const MASK_MIN := 0.8
## The boulders in each cell of the rock mask (8 m), and their radius (m).
const PER_CELL := 6
const RADIUS := Vector2(0.8, 2.4)
## The base of a boulder is BASE x its radius below its center (shape_point()),
## and SINK x its radius of it is in the ground.
const BASE := 0.35
const SINK := 0.15
## The side of the square of one MultiMesh (m).
const CELL := 32.0
## The distance (m from the center of a cell) to which the near form shows.
const NEAR_M := 50.0
## The distance (m from the center of a cell) to which the far form shows, for
## each quality preset. The near chunks go to about 300 m (VungTau.NEAR_DISTANCE),
## and the islet of Hòn Bà is about 250 m from the beach end of its path.
const FAR_M := {"low": 300.0, "medium": 340.0, "high": 340.0, "ultra": 340.0}
## The colors of the granite: grey and brown (multiplied by the rock texture).
const GREY := Color(0.29, 0.28, 0.27)
const BROWN := Color(0.34, 0.28, 0.23)

static var _meshes: Array[ArrayMesh] = []
static var _material: ShaderMaterial


## The near form (0) or the far form (1) of a boulder, with the material.
static func mesh(form: int) -> ArrayMesh:
	if _meshes.is_empty():
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/boulder.gdshader")
		var texture_path := VungTau.TEXTURE_ROOT.path_join("rock/diffuse.jpg")
		if ResourceLoader.exists(texture_path):
			_material.set_shader_parameter("rock_texture", load(texture_path))
		_material.set_shader_parameter("grey", GREY)
		_material.set_shader_parameter("brown", BROWN)
		_meshes.append(_make(1))
		_meshes.append(_make(0))
	return _meshes[form]


## The radius of a boulder from its center to its surface in a direction:
## smooth bumps of about a third of the radius, and a flat top and base.
static func shape_point(direction: Vector3) -> Vector3:
	var d := direction.normalized()
	var r := 1.0 + 0.16 * sin(d.x * 3.1 + 0.7) * cos(d.z * 2.7 + 1.3) + 0.12 * sin(d.y * 4.3 + d.x * 2.1 + 2.2) \
			+ 0.08 * cos(d.z * 5.2 - d.y * 3.3)
	var p := d * r
	p.y *= 0.62
	# The top is flatter, and the base is flat in the ground.
	if p.y > 0.45:
		p.y = 0.45 + (p.y - 0.45) * 0.4
	p.y = maxf(p.y, -BASE)
	return p


## An icosahedron with "levels" subdivisions, with the shape of shape_point()
## and flat faces (the facets of a broken granite block). The vertex color R is
## the height in the boulder (0 at the base, 1 at the top).
static func _make(levels: int) -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var points: Array[Vector3] = []
	for p in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		points.append((p as Vector3).normalized())
	var faces: Array[Vector3i] = [Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10),
		Vector3i(0, 10, 11), Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6),
		Vector3i(7, 1, 8), Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8),
		Vector3i(3, 8, 9), Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7),
		Vector3i(9, 8, 1)]
	for level in levels:
		var middles := {}
		var next: Array[Vector3i] = []
		for f: Vector3i in faces:
			var a := _middle(points, middles, f.x, f.y)
			var b := _middle(points, middles, f.y, f.z)
			var c := _middle(points, middles, f.z, f.x)
			next.append_array([Vector3i(f.x, a, c), Vector3i(f.y, b, a), Vector3i(f.z, c, b), Vector3i(a, b, c)])
		faces = next
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for f: Vector3i in faces:
		var a := shape_point(points[f.x])
		var b := shape_point(points[f.y])
		var c := shape_point(points[f.z])
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot(a + b + c) < 0.0:
			normal = -normal
			var swap := b
			b = c
			c = swap
		# Godot uses the clockwise order (seen from the front) for the front faces.
		for corner: Vector3 in [a, c, b]:
			vertices.append(corner)
			normals.append(normal)
			colors.append(Color(clampf((corner.y + 0.35) / 0.8, 0.0, 1.0), 0.0, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.surface_set_material(0, _material)
	return result


static func _middle(points: Array[Vector3], middles: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if not middles.has(key):
		middles[key] = points.size()
		points.append(((points[a] + points[b]) / 2.0).normalized())
	return middles[key]


## The MultiMesh nodes of the boulders of a near chunk, for each cell: the
## near form and the far form. "placed" is cell -> transforms (world space),
## from VungTau._boulder_transforms(). "origin" is the corner of the chunk.
static func nodes(placed: Dictionary, origin: Vector3, preset: String) -> Array[MultiMeshInstance3D]:
	var result: Array[MultiMeshInstance3D] = []
	for cell: Vector2i in placed:
		var transforms: Array = placed[cell]
		for form in 2:
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_custom_data = true
			multi.mesh = mesh(form)
			multi.instance_count = transforms.size()
			for k in transforms.size():
				var t: Transform3D = transforms[k]
				multi.set_instance_transform(k, Transform3D(t.basis, t.origin - origin))
				# The custom data R: from grey (0) to brown (1), and G: a lighter or darker tone.
				var h := hash(t.origin)
				multi.set_instance_custom_data(k, Color(float(h & 255) / 255.0, float((h >> 8) & 255) / 255.0, 0.0, 0.0))
			var instance := MultiMeshInstance3D.new()
			instance.name = "Boulders_%d_%d_%s" % [cell.x, cell.y, ["near", "far"][form]]
			instance.multimesh = multi
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			if form == 0:
				instance.visibility_range_end = NEAR_M
			else:
				instance.visibility_range_begin = NEAR_M
				instance.visibility_range_end = FAR_M.get(preset, FAR_M.low)
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			result.append(instance)
	return result


## The far distance of the preset for the far forms in "node" (after a change of preset).
static func set_preset(node: Node, preset: String) -> void:
	for child in node.get_children():
		if child is MultiMeshInstance3D and child.name.ends_with("_far"):
			(child as MultiMeshInstance3D).visibility_range_end = FAR_M.get(preset, FAR_M.low)
