class_name MeshBatch
extends RefCounted
## Collects many boxes and cylinders into a few meshes, one for each material
## (plan 0004, R13). Each shape has its color in the vertex colors, so one
## material draws many parts in one draw call.
##
## The vertex positions stay in the local space of the parent, so a shader can
## use them for the patterns of a wall.

var _tools: Dictionary = {}
var _counts: Dictionary = {}


func _tool(key: String) -> SurfaceTool:
	if not _tools.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = tool
		_counts[key] = 0
	return _tools[key]


## True when no shape uses the material key.
func is_empty(key: String) -> bool:
	return int(_counts.get(key, 0)) == 0


## A box with the center and the size, turned by the basis.
func box(key: String, size: Vector3, center: Vector3, color: Color, basis := Basis()) -> void:
	var tool := _tool(key)
	_counts[key] += 1
	var h := size / 2.0
	# Each face: the normal, then the four corners in the order of a quad.
	var faces := [
		[Vector3(0, 0, 1), [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3(0, 0, -1), [Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)]],
		[Vector3(1, 0, 0), [Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)]],
		[Vector3(-1, 0, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3(0, 1, 0), [Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3(0, -1, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)]],
	]
	for face: Array in faces:
		var normal: Vector3 = basis * face[0]
		var corners: Array = face[1]
		var points: Array[Vector3] = []
		for corner: Vector3 in corners:
			points.append(center + basis * corner)
		_quad(tool, points, normal, color)


## A quad with four corners in counterclockwise order, seen from the front.
func quad(key: String, points: Array[Vector3], color: Color) -> void:
	var tool := _tool(key)
	_counts[key] += 1
	var normal := (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	_quad(tool, points, normal, color)


## An upright cylinder (or a cylinder along the basis Y axis).
func cylinder(key: String, radius: float, height: float, center: Vector3, color: Color, segments := 10,
		basis := Basis(), caps := true) -> void:
	var tool := _tool(key)
	_counts[key] += 1
	var half := height / 2.0
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var points: Array[Vector3] = [
			center + basis * (d1 * radius + Vector3(0, -half, 0)),
			center + basis * (d0 * radius + Vector3(0, -half, 0)),
			center + basis * (d0 * radius + Vector3(0, half, 0)),
			center + basis * (d1 * radius + Vector3(0, half, 0)),
		]
		var normal := basis * ((d0 + d1) / 2.0).normalized()
		_quad(tool, points, normal, color)
		if caps:
			var top := center + basis * Vector3(0, half, 0)
			var bottom := center + basis * Vector3(0, -half, 0)
			_triangle(tool, [top, points[2], points[3]] as Array[Vector3], basis * Vector3.UP, color)
			_triangle(tool, [bottom, points[0], points[1]] as Array[Vector3], basis * Vector3.DOWN, color)


## A tube along a line of points (for example a sagging cable).
func tube(key: String, line: PackedVector3Array, radius: float, color: Color, segments := 4) -> void:
	var tool := _tool(key)
	_counts[key] += 1
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var axis := (b - a).normalized()
		var side := axis.cross(Vector3.UP)
		if side.length() < 0.01:
			side = axis.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(axis).normalized()
		for s in segments:
			var a0 := TAU * s / segments
			var a1 := TAU * (s + 1) / segments
			var d0 := side * cos(a0) + up * sin(a0)
			var d1 := side * cos(a1) + up * sin(a1)
			var points: Array[Vector3] = [a + d0 * radius, b + d0 * radius, b + d1 * radius, a + d1 * radius]
			_quad(tool, points, ((d0 + d1) / 2.0).normalized(), color)


func _quad(tool: SurfaceTool, points: Array[Vector3], normal: Vector3, color: Color) -> void:
	_triangle(tool, [points[0], points[1], points[2]] as Array[Vector3], normal, color)
	_triangle(tool, [points[0], points[2], points[3]] as Array[Vector3], normal, color)


func _triangle(tool: SurfaceTool, points: Array[Vector3], normal: Vector3, color: Color) -> void:
	# Godot uses clockwise front faces: add the points in the reverse order.
	for i in [0, 2, 1]:
		tool.set_color(color)
		tool.set_normal(normal)
		tool.set_uv(Vector2(points[i].x + points[i].z, points[i].y))
		tool.add_vertex(points[i])


## Makes one MeshInstance3D for each material key and adds it to the parent.
## Returns them by key.
func commit(parent: Node3D, materials: Dictionary, prefix := "Batch") -> Dictionary:
	var result := {}
	for key: String in _tools:
		if is_empty(key):
			continue
		var tool: SurfaceTool = _tools[key]
		var instance := MeshInstance3D.new()
		instance.name = "%s_%s" % [prefix, key]
		instance.mesh = tool.commit()
		if materials.has(key):
			instance.material_override = materials[key]
		parent.add_child(instance)
		result[key] = instance
	return result
