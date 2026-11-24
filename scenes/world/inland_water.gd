class_name InlandWater
extends Node3D
## Report 0009, D-0009-16: the water of the land (Bàu Sen, Bàu Trũng, the lakes
## of Hồ Mây, the ponds, the salt pans, and Rạch Bến Đình): flat water at the
## level of each area, from data/geo/build/inland_water.json (tools/geo/build.py,
## geodata/inland_water.py). The ground under it is 1 m lower, and no tree and
## no box of the town stands on it. One mesh for each square of TILE_M.

const FILE := "inland_water.json"
const TILE_M := 1024.0

## Each area: {"name", "level", "middle" (Vector3, at the level), "box"
## (Rect2 on x, z), "triangles" (PackedVector2Array, three points each)}.
var areas: Array[Dictionary] = []


func setup(w: VungTau) -> bool:
	var path := w.data.root.path_join(FILE)
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("InlandWater: %s cannot be read." % path)
		return false
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(str(parsed.get("color", "#2F3C38")))
	material.roughness = float(parsed.get("roughness", 0.1))
	# The triangles of the build are on the map: show both sides.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tiles := {}
	for area: Dictionary in parsed.get("areas", []):
		var level := float(area.level)
		var flat: Array = area.triangles
		var middle := Vector2.ZERO
		var flat_points := PackedVector2Array()
		var box := Rect2()
		for i in range(0, flat.size() - 5, 6):
			var corners := PackedVector3Array()
			for k in 3:
				corners.append(Vector3(float(flat[i + 2 * k]), level, float(flat[i + 2 * k + 1])))
				middle += Vector2(corners[k].x, corners[k].z) * 2.0 / flat.size()
				var corner := Vector2(corners[k].x, corners[k].z)
				flat_points.append(corner)
				box = Rect2(corner, Vector2.ZERO) if flat_points.size() == 1 else box.expand(corner)
			# The tile of the first corner of the triangle.
			var key := Vector2i(floori(corners[0].x / TILE_M), floori(corners[0].z / TILE_M))
			var verts: PackedVector3Array = tiles.get(key, PackedVector3Array())
			verts.append_array(corners)
			tiles[key] = verts
		areas.append({"name": str(area.get("name", "")), "level": level, "middle": Vector3(middle.x, level, middle.y),
				"box": box, "triangles": flat_points})
	for key: Vector2i in tiles:
		var verts: PackedVector3Array = tiles[key]
		var origin := Vector3((key.x + 0.5) * TILE_M, 0.0, (key.y + 0.5) * TILE_M)
		var normals := PackedVector3Array()
		for v in verts.size():
			verts[v] -= origin
			normals.append(Vector3.UP)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material)
		var node := MeshInstance3D.new()
		node.name = "Water_%d_%d" % [key.x, key.y]
		node.mesh = mesh
		node.position = origin
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	return true


## The area of this name, or an empty Dictionary.
func area_named(area_name: String) -> Dictionary:
	for area in areas:
		if area.name == area_name:
			return area
	return {}


## The level of the water at a point, or -INF where no area of water is
## (plan 0018, D5: a scooter does not go into the water).
func level_at(x: float, z: float) -> float:
	var at := Vector2(x, z)
	for area: Dictionary in areas:
		if not (area.box as Rect2).has_point(at):
			continue
		var t: PackedVector2Array = area.triangles
		for i in range(0, t.size() - 2, 3):
			if Geometry2D.point_is_inside_triangle(at, t[i], t[i + 1], t[i + 2]):
				return float(area.level)
	return -INF
