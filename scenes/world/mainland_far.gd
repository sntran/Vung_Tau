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

var triangles := 0
var mesh_node: MeshInstance3D
var _grid := {}


func setup(w: VungTau) -> bool:
	var path := w.data.root.path_join(FILE)
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
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
	var point := func(r: int, c: int) -> Vector3:
		return Vector3(x0 + c * step, float(heights[r * cols + c]), z0 + r * step) - origin
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for r in rows - 1:
		for c in cols - 1:
			if cells.unicode_at(r * (cols - 1) + c) != 49:  # "1"
				continue
			var a: Vector3 = point.call(r, c)
			var b: Vector3 = point.call(r, c + 1)
			var d: Vector3 = point.call(r + 1, c)
			var e: Vector3 = point.call(r + 1, c + 1)
			# Clockwise from above (Godot draws the front).
			for p: Vector3 in [a, b, d, b, e, d]:
				verts.append(p)
				colors.append(LOW_COLOR.lerp(HILL_COLOR, smoothstep(HILL_FROM_M, HILL_TO_M, p.y)))
	if verts.is_empty():
		return false
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in verts.size():
		tool.set_color(colors[i])
		tool.add_vertex(verts[i])
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	mesh_node = MeshInstance3D.new()
	mesh_node.name = "Mainland"
	mesh_node.mesh = tool.commit()
	mesh_node.material_override = material
	mesh_node.position = origin
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_node)
	triangles = verts.size() / 3
	return true


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
