class_name MainlandFar
extends Node3D
## Report 0009, Q14: the land around the play area on the horizon (Long Hải,
## Núi Dinh, Cần Giờ) as one far mesh, from data/geo/build/mainland.json
## (tools/geo/build.py, geodata/mainland.py: the Copernicus DEM on a grid of
## 400 m, to 32 km). The heights have the curve of the earth in them. The mesh
## has no shadow, and the fog of the hour (the haze of data/look/grading.json)
## covers it as the other far land. The camera reaches it (VungTau.FAR_VIEW_M).

const FILE := "mainland.json"
## The colors of the far land by height: the low land (fields, mangroves, the
## towns of the coast) and the hills (forest).
const LOW_COLOR := Color("#6A7553")
const HILL_COLOR := Color("#3F5137")
const HILL_FROM_M := 40.0
const HILL_TO_M := 160.0

## On Low the mesh has a cell of this many cells of the file (800 m).
const LOW_STRIDE := 2

## The triangles of the mesh of the preset (PT-69).
var triangles := 0
var mesh_node: MeshInstance3D
var _grid := {}
var _meshes := {}
var _triangles := {}


func setup(w: VungTau) -> bool:
	var path := w.data.root.path_join(FILE)
	if not GeoData.has_file(path):
		return false
	var parsed: Variant = JSON.parse_string(GeoData.read_text(path))
	if not parsed is Dictionary:
		push_error("MainlandFar: %s cannot be read." % path)
		return false
	var step := float(parsed.step)
	var cols := int(parsed.cols)
	var rows := int(parsed.rows)
	var heights: Array = parsed.heights
	var cells: String = str(parsed.cells)
	var x0 := float(parsed.x0)
	var z0 := float(parsed.z0)
	var origin := Vector3(x0 + (cols - 1) * step / 2.0, 0.0, z0 + (rows - 1) * step / 2.0)
	_grid = {"step": step, "cols": cols, "rows": rows, "x0": x0, "z0": z0, "heights": heights}
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	for stride: int in [1, LOW_STRIDE]:
		var mesh := _make_mesh(stride, cells, origin)
		if mesh == null:
			return false
		var node := MeshInstance3D.new()
		node.name = "Mainland" if stride == 1 else "MainlandLow"
		node.mesh = mesh
		node.material_override = material
		node.position = origin
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_meshes[stride] = node
	set_preset(VungTau.ground_preset)
	return true


## Shows the mesh of the preset: on Low the grid of LOW_STRIDE cells (PT-73
## and parked_rows: the limit of 300 000 triangles on Low).
func set_preset(preset: String) -> void:
	var shown := LOW_STRIDE if preset == "low" else 1
	for stride: int in _meshes:
		(_meshes[stride] as MeshInstance3D).visible = stride == shown
	mesh_node = _meshes[shown]
	triangles = _triangles[shown]


## The mesh of the grid with a cell of `stride` cells of the file: a cell is
## land when one of its cells of the file is land.
func _make_mesh(stride: int, cells: String, origin: Vector3) -> ArrayMesh:
	var cols := int(_grid.cols)
	var rows := int(_grid.rows)
	var heights: Array = _grid.heights
	var step := float(_grid.step)
	var x0 := float(_grid.x0)
	var z0 := float(_grid.z0)
	var point := func(r: int, c: int) -> Vector3:
		r = mini(r, rows - 1)
		c = mini(c, cols - 1)
		return Vector3(x0 + c * step, float(heights[r * cols + c]), z0 + r * step) - origin
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for r in range(0, rows - 1, stride):
		for c in range(0, cols - 1, stride):
			var land := false
			for dr in stride:
				for dc in stride:
					if r + dr < rows - 1 and c + dc < cols - 1 and cells.unicode_at((r + dr) * (cols - 1) + c + dc) == 49:  # "1"
						land = true
			if not land:
				continue
			var a: Vector3 = point.call(r, c)
			var b: Vector3 = point.call(r, c + stride)
			var d: Vector3 = point.call(r + stride, c)
			var e: Vector3 = point.call(r + stride, c + stride)
			# Clockwise from above (Godot draws the front).
			for p: Vector3 in [a, b, d, b, e, d]:
				verts.append(p)
				colors.append(LOW_COLOR.lerp(HILL_COLOR, smoothstep(HILL_FROM_M, HILL_TO_M, p.y)))
	if verts.is_empty():
		return null
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in verts.size():
		tool.set_color(colors[i])
		tool.add_vertex(verts[i])
	tool.generate_normals()
	_triangles[stride] = verts.size() / 3
	return tool.commit()


## The height of the far mesh at a point (bilinear; with the curve of the
## earth), or -INF out of the grid (PT-68: the hills on the horizon).
func height_at(x: float, z: float) -> float:
	if _grid.is_empty():
		return -INF
	var col := (x - float(_grid.x0)) / float(_grid.step)
	var row := (z - float(_grid.z0)) / float(_grid.step)
	var c := floori(col)
	var r := floori(row)
	if c < 0 or r < 0 or c >= int(_grid.cols) - 1 or r >= int(_grid.rows) - 1:
		return -INF
	var heights: Array = _grid.heights
	var cols := int(_grid.cols)
	var top := lerpf(float(heights[r * cols + c]), float(heights[r * cols + c + 1]), col - c)
	var bottom := lerpf(float(heights[(r + 1) * cols + c]), float(heights[(r + 1) * cols + c + 1]), col - c)
	return lerpf(top, bottom, row - r)
