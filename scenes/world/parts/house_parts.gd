class_name HouseParts
extends Node3D
## The many repeated small parts of the houses (plan 0004, R13): rail bars,
## balusters, potted plants, and AC units. Each kind is one MultiMesh for each
## part of the street (CHUNK meters), with a visibility range, so that far
## houses show fewer parts.

const CHUNK := 15.0
## A part farther than this from the camera does not show.
const VISIBLE_RANGE := 70.0
const KINDS: Array[String] = ["rail_bar", "baluster", "pot", "ac_unit"]

## kind -> chunk -> [[transform, color]].
var _parts: Dictionary = {}
var _meshes: Dictionary = {}


## Adds one part. The transform is in the space of this node. The scale of the
## transform gives the size of a rail bar (a unit box).
func add(kind: String, xform: Transform3D, color := Color.WHITE) -> void:
	var chunk := floori(xform.origin.x / CHUNK)
	if not _parts.has(kind):
		_parts[kind] = {}
	if not _parts[kind].has(chunk):
		_parts[kind][chunk] = []
	_parts[kind][chunk].append([xform, color])


## The number of parts of a kind.
func count(kind: String) -> int:
	var total := 0
	for chunk: int in _parts.get(kind, {}):
		total += _parts[kind][chunk].size()
	return total


## Makes the MultiMesh instances. Call it after all houses added their parts.
func commit() -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.7
	for kind: String in _parts:
		for chunk: int in _parts[kind]:
			var list: Array = _parts[kind][chunk]
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = true
			multimesh.mesh = mesh(kind)
			multimesh.instance_count = list.size()
			for i in list.size():
				multimesh.set_instance_transform(i, list[i][0])
				multimesh.set_instance_color(i, list[i][1])
			var instance := MultiMeshInstance3D.new()
			instance.name = "Parts_%s_%d" % [kind, chunk]
			instance.multimesh = multimesh
			instance.material_override = material
			instance.visibility_range_end = VISIBLE_RANGE
			instance.visibility_range_end_margin = 5.0
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			add_child(instance)


## The mesh of one part. A rail bar is a unit box. The others have their real size.
static func mesh(kind: String) -> Mesh:
	var batch := MeshBatch.new()
	match kind:
		"rail_bar":
			batch.box("m", Vector3.ONE, Vector3.ZERO, Color.WHITE)
		"baluster":
			# A vase baluster (con tiện): a base, a round body, a neck, and a top.
			batch.box("m", Vector3(0.12, 0.08, 0.12), Vector3(0, 0.04, 0), Color.WHITE)
			batch.cylinder("m", 0.05, 0.22, Vector3(0, 0.22, 0), Color.WHITE, 8)
			batch.cylinder("m", 0.035, 0.3, Vector3(0, 0.48, 0), Color.WHITE, 8)
			batch.cylinder("m", 0.05, 0.1, Vector3(0, 0.68, 0), Color.WHITE, 8)
			batch.box("m", Vector3(0.12, 0.06, 0.12), Vector3(0, 0.76, 0), Color.WHITE)
		"pot":
			# A clay pot with a plant. The instance color tints only the pot.
			batch.cylinder("m", 0.16, 0.28, Vector3(0, 0.14, 0), Color.WHITE, 8)
			batch.box("m", Vector3(0.36, 0.3, 0.36), Vector3(0, 0.45, 0), Color("#5E8C3A"))
			batch.box("m", Vector3(0.24, 0.24, 0.24), Vector3(0.05, 0.66, -0.03), Color("#4C7A30"))
		"ac_unit":
			# The outdoor unit of an air conditioner, with a round fan grille.
			batch.box("m", Vector3(0.8, 0.55, 0.28), Vector3(0, 0.275, 0), Color.WHITE)
			batch.cylinder("m", 0.2, 0.02, Vector3(-0.12, 0.275, 0.145), Color("#5A5E60"), 12,
					Basis(Vector3.RIGHT, PI / 2.0))
			batch.box("m", Vector3(0.6, 0.04, 0.3), Vector3(0, -0.02, 0), Color("#7A7A74"))
	var result := {}
	var holder := Node3D.new()
	result = batch.commit(holder, {})
	var mesh_instance: MeshInstance3D = result["m"]
	var built := mesh_instance.mesh
	holder.free()
	return built
