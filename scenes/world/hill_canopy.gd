class_name HillCanopy
extends Node3D
## The far form of the hill trees (report 0005, D-0005-01). The near chunks
## have the hill trees only within about 300 m, so the hills were bare grass
## in the views. Here each cell of the overview grid (16 m) with wood or hill
## ground (VungTau.is_forest(), the same rule as the near trees) gets one or
## two round crown clumps (9 m to 14 m wide). The clumps of each tile of TILE meters are one
## MultiMesh. Near the player, the near chunks have the real trees, so the
## shader hides the clumps nearer than NEAR_HIDE meters.

const TILE := 1024.0
const VISIBLE_RANGE := 3600.0
const NEAR_HIDE := 280.0
## The part of the forest cells that get a clump, and the part that get a second one.
const DENSITY := 0.9
const SECOND := 0.5
## The detail of the clumps (report 0005, D-0005-10). The sparse clumps are
## the first clump of each fourth cell (one cell of each 2 x 2); the other
## clumps are the dense clumps. For each preset: the mesh of the sparse clumps
## (one crown of 5 m on Low, a clump on the others), their scale near and far
## (the shader changes it between the two distances of "scale_m"), and the
## distance to which the dense clumps show (0: never). Far away, the sparse
## clumps are larger, so that they cover about as much of the hills as all
## the clumps.
const DETAIL := {
	"low": {"crown": true, "scale": [2.0, 4.5], "scale_m": [400.0, 1600.0], "dense_m": 0.0},
	"medium": {"crown": false, "scale": [1.0, 2.4], "scale_m": [900.0, 1500.0], "dense_m": 1000.0},
	"high": {"crown": false, "scale": [1.0, 2.4], "scale_m": [1300.0, 2000.0], "dense_m": 1500.0},
	"ultra": {"crown": false, "scale": [1.0, 2.4], "scale_m": [1800.0, 2600.0], "dense_m": 2000.0},
}

## The number of clumps, and the number of sparse clumps.
var count := 0
var sparse_count := 0
## The material of the sparse clumps and of the dense clumps.
var material: ShaderMaterial
var dense_material: ShaderMaterial
var _mesh: Mesh
var _crown_mesh: Mesh
## The MultiMeshInstance3D of the sparse clumps and of the dense clumps of each tile.
var _sparse: Array[MultiMeshInstance3D] = []
var _dense: Array[MultiMeshInstance3D] = []


func setup(world: VungTau) -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/canopy.gdshader")
	material.set_shader_parameter("near_hide", NEAR_HIDE)
	dense_material = material.duplicate()
	var overview := world.data.overview
	if overview.is_empty():
		return
	var step: float = overview.step
	var width: int = overview.width
	var rows: int = overview.height
	var heights: PackedFloat32Array = overview.heights
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var tiles := {}
	for row in range(1, rows - 1):
		for col in range(1, width - 1):
			var h := heights[row * width + col]
			if h < VungTau.FOREST_LOWEST:
				continue
			var slope := maxf(absf(heights[row * width + col + 1] - heights[row * width + col - 1]),
					absf(heights[(row + 1) * width + col] - heights[(row - 1) * width + col])) / (2.0 * step)
			var x := float(overview.x0) + col * step
			var z := float(overview.z0) + row * step
			if not world.is_forest(x, z, h, slope):
				continue
			for i in 2:
				if rng.randf() > (DENSITY if i == 0 else SECOND):
					break
				var p := Vector2(x + rng.randf_range(-0.5, 0.5) * step, z + rng.randf_range(-0.5, 0.5) * step)
				var key := Vector2i(floori(p.x / TILE), floori(p.y / TILE))
				if not tiles.has(key):
					tiles[key] = [[], []]
				var sparse := i == 0 and row % 2 == 0 and col % 2 == 0
				var size := rng.randf_range(1.0, 1.5)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size * rng.randf_range(0.8, 1.1), size))
				# The clumps stand a little into the ground: the overview grid is
				# smoother than the near ground.
				var y := world.data.overview_height(p.x, p.y) - 1.5
				tiles[key][0 if sparse else 1].append(Transform3D(basis, Vector3(p.x, y, p.y)))
	_mesh = clump_mesh()
	_crown_mesh = crown_mesh()
	for key: Vector2i in tiles:
		_sparse.append(_add_tile(key, tiles[key][0], material, "Sparse"))
		_dense.append(_add_tile(key, tiles[key][1], dense_material, "Dense"))
		sparse_count += tiles[key][0].size()


## Sets the clumps of a quality preset (DETAIL).
func set_preset(preset: String) -> void:
	var detail: Dictionary = DETAIL.get(preset, DETAIL.low)
	material.set_shader_parameter("clump_scale", detail.scale[0])
	material.set_shader_parameter("clump_scale_far", detail.scale[1])
	material.set_shader_parameter("scale_range", Vector2(detail.scale_m[0], detail.scale_m[1]))
	for instance: MultiMeshInstance3D in _sparse:
		instance.multimesh.mesh = _crown_mesh if detail.crown else _mesh
	for instance: MultiMeshInstance3D in _dense:
		instance.visible = float(detail.dense_m) > 0.0
		instance.visibility_range_end = float(detail.dense_m)


func _add_tile(key: Vector2i, transforms: Array, tile_material: Material, kind: String) -> MultiMeshInstance3D:
	var origin := Vector3((key.x + 0.5) * TILE, 0.0, (key.y + 0.5) * TILE)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		var t: Transform3D = transforms[i]
		multimesh.set_instance_transform(i, Transform3D(t.basis, t.origin - origin))
	count += transforms.size()
	var instance := MultiMeshInstance3D.new()
	instance.name = "%s_%d_%d" % [kind, key.x, key.y]
	instance.multimesh = multimesh
	instance.material_override = tile_material
	instance.position = origin
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = VISIBLE_RANGE
	instance.visibility_range_end_margin = 200.0
	add_child(instance)
	return instance


## Sets the season (plan 0005, R12a): the dry leaves and the bare trees, as on the near hill trees.
func apply_season(season: Dictionary) -> void:
	for each: ShaderMaterial in [material, dense_material]:
		each.set_shader_parameter("dryness", season.dryness * 0.8)
		each.set_shader_parameter("bare_share", season.bare_share)


## The mesh of one clump: three round crowns, about 9 m wide and 8 m high
## in all. The base is at the origin. The vertex color is darker low on each
## crown, for the shade under the leaves.
static func clump_mesh() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_crown(tool, Vector3(0.0, 4.2, 0.0), Vector3(4.2, 3.8, 4.2))
	_crown(tool, Vector3(1.8, 5.6, 1.0), Vector3(3.0, 2.8, 3.0))
	_crown(tool, Vector3(-1.6, 5.0, -1.2), Vector3(2.8, 2.6, 2.8))
	tool.index()
	return tool.commit()


## The mesh of one sparse clump on Low: one round crown (24 triangles), 5 m
## wide and 4 m high.
static func crown_mesh() -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Darker than a crown of a clump: one crown has no shade of the other crowns on it.
	_crown(tool, Vector3(0.0, 2.2, 0.0), Vector3(2.6, 2.0, 2.6), 0.4, 0.75)
	tool.index()
	return tool.commit()


## A half ellipsoid with a short skirt below it: 6 sides and 2 rings (24 triangles).
static func _crown(tool: SurfaceTool, center: Vector3, radius: Vector3, low_shade := 0.55, top_shade := 1.0) -> void:
	const SIDES := 6
	const RINGS := 2
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for r in RINGS + 1:
		# From 30 degrees below the middle to the top.
		var angle := lerpf(-PI / 6.0, PI / 2.0, float(r) / RINGS)
		var ring := PackedVector3Array()
		var ring_normals := PackedVector3Array()
		for s in SIDES:
			var around := TAU * s / SIDES
			var unit := Vector3(cos(angle) * cos(around), sin(angle), cos(angle) * sin(around))
			ring.append(center + unit * radius)
			ring_normals.append((unit / radius).normalized())
		rings.append(ring)
		normals.append(ring_normals)
	for r in RINGS:
		for s in SIDES:
			var n := (s + 1) % SIDES
			var quad := [[r, s], [r + 1, s], [r + 1, n], [r, s], [r + 1, n], [r, n]]
			for corner: Array in quad:
				var shade := lerpf(low_shade, top_shade, float(corner[0]) / RINGS)
				tool.set_color(Color(shade, shade, shade))
				tool.set_normal(normals[corner[0]][corner[1]])
				tool.add_vertex(rings[corner[0]][corner[1]])
