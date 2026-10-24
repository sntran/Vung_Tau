class_name TerrainBuilder
extends RefCounted
## Makes the mesh arrays of a ground chunk from a height grid (plan 0004, D6).
##
## The functions are static and use no nodes, so a worker thread can run them.
## A skirt (a strip that goes down at each edge) hides the gaps between chunks
## of different detail.

const SKIRT_DEPTH := 3.0


## Makes the arrays for a square of "count" x "count" vertices. The vertex
## (i, j) uses the sample (col0 + i * stride, row0 + j * stride) of the grid.
## "spacing" is the distance in meters between two samples of the grid. The
## vertex positions are from the first vertex (0, 0).
static func arrays(heights: PackedFloat32Array, width: int, rows: int, col0: int, row0: int, count: int,
		stride: int, spacing: float) -> Array:
	var step := spacing * stride
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.resize(count * count)
	normals.resize(count * count)
	for j in count:
		var row := clampi(row0 + j * stride, 0, rows - 1)
		for i in count:
			var col := clampi(col0 + i * stride, 0, width - 1)
			var h := heights[row * width + col]
			vertices[j * count + i] = Vector3(i * step, h, j * step)
			# The normal from the heights at the next samples, also outside the square.
			var hl := heights[row * width + clampi(col - stride, 0, width - 1)]
			var hr := heights[row * width + clampi(col + stride, 0, width - 1)]
			var hu := heights[clampi(row - stride, 0, rows - 1) * width + col]
			var hd := heights[clampi(row + stride, 0, rows - 1) * width + col]
			normals[j * count + i] = Vector3(hl - hr, 2.0 * step, hu - hd).normalized()
	for j in count - 1:
		for i in count - 1:
			var a := j * count + i
			indices.append_array([a, a + 1, a + count, a + 1, a + count + 1, a + count])
	_add_skirts(vertices, normals, indices, count)
	var result := []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = vertices
	result[Mesh.ARRAY_NORMAL] = normals
	result[Mesh.ARRAY_INDEX] = indices
	return result


static func _add_skirts(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array,
		count: int) -> void:
	# The four edges, each in the order that makes the skirt face out.
	var edges: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	for k in count:
		edges[0].append(k)  # north, from west to east
		edges[1].append(k * count + count - 1)  # east, from north to south
		edges[2].append((count - 1) * count + (count - 1 - k))  # south, from east to west
		edges[3].append((count - 1 - k) * count)  # west, from south to north
	for edge in edges:
		var first := vertices.size()
		for index in edge:
			vertices.append(vertices[index] - Vector3(0, SKIRT_DEPTH, 0))
			normals.append(normals[index])
		for k in edge.size() - 1:
			var top_a := edge[k]
			var top_b := edge[k + 1]
			var low_a := first + k
			var low_b := first + k + 1
			indices.append_array([top_a, low_a, top_b, top_b, low_a, low_b])


## Makes an ArrayMesh from the arrays. Call this on the main thread.
static func mesh(mesh_arrays: Array, material: Material) -> ArrayMesh:
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	result.surface_set_material(0, material)
	return result


## The collision shape of a chunk: a HeightMapShape3D. Godot puts the center of
## the shape at the center of the map, with 1 m between samples, so the
## collision node must have a uniform scale of "spacing". The heights are
## divided by the scale.
static func height_shape(heights: PackedFloat32Array, count: int, spacing: float) -> HeightMapShape3D:
	var shape := HeightMapShape3D.new()
	shape.map_width = count
	shape.map_depth = count
	var scaled := PackedFloat32Array()
	scaled.resize(heights.size())
	for i in heights.size():
		scaled[i] = heights[i] / spacing
	shape.map_data = scaled
	return shape
