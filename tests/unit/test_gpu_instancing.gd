extends GutTest
## Tests for the import of EXT_mesh_gpu_instancing (addons/gpu_instancing).
##
## tests/data/world/instancing.glb comes from make_instancing.py in the
## same folder. It has the layout of a World GLB.

const FILE := "res://tests/data/world/instancing.glb"
const QUARTER := PI / 2.0


# The transform of an instance, from the buffer of the MultiMesh. The
# headless renderer of the tests gives no get_instance_transform().
func _instance(multimesh: MultiMesh, i: int) -> Transform3D:
	var b := multimesh.buffer
	var at := 12 * i
	return Transform3D(
		Vector3(b[at], b[at + 4], b[at + 8]),
		Vector3(b[at + 1], b[at + 5], b[at + 9]),
		Vector3(b[at + 2], b[at + 6], b[at + 10]),
		Vector3(b[at + 3], b[at + 7], b[at + 11]))


# The scene of the test file, read at run time with the extension.
func _read() -> Node:
	var extension := GltfGpuInstancing.new()
	GLTFDocument.register_gltf_document_extension(extension)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(ProjectSettings.globalize_path(FILE), state)
	var scene: Node = document.generate_scene(state) if error == OK else null
	GLTFDocument.unregister_gltf_document_extension(extension)
	assert_eq(error, OK, "Godot reads the test file")
	return scene


func test_a_node_with_instances_is_a_multimesh() -> void:
	var scene := _read()
	if scene == null:
		return
	var row := scene.find_child("row", true, false)
	assert_true(row is MultiMeshInstance3D, "the node with 16 instances is a MultiMeshInstance3D")
	if not row is MultiMeshInstance3D:
		scene.free()
		return
	var multimesh: MultiMesh = row.multimesh
	assert_eq(multimesh.instance_count, 16)
	assert_eq(multimesh.mesh.get_surface_count(), 1, "the mesh of the node")
	assert_eq(multimesh.mesh.surface_get_material(0).resource_name, "brick", "the material of the mesh")
	for i in 16:
		var t := _instance(multimesh, i)
		assert_almost_eq(t.origin, Vector3(0.25 * i, 0.0, 0.0), Vector3.ONE * 1.0e-5, "the place of instance %d" % i)
		var turn := QUARTER if i % 2 else 0.0
		assert_almost_eq(t.basis.get_euler().y, turn, 1.0e-5, "the turn of instance %d" % i)
	# A node with no instances stays a mesh.
	assert_true(scene.find_child("plain", true, false) is MeshInstance3D, "the node with no instances")
	scene.free()


func test_a_mirror_stays_on_the_node_and_a_scale_on_each_instance() -> void:
	var scene := _read()
	if scene == null:
		return
	var mirror := scene.find_child("mirror", true, false) as MultiMeshInstance3D
	assert_not_null(mirror, "the mirror node is a MultiMeshInstance3D")
	if mirror != null:
		# Godot keeps a mirror as a turn and a negative scale: the
		# determinant is the check.
		assert_almost_eq(mirror.transform.basis.determinant(), -1.0, 1.0e-5, "the renderer turns the faces over")
		assert_almost_eq(mirror.transform.basis * Vector3(1, 2, 3), Vector3(-1, 2, 3), Vector3.ONE * 1.0e-5, "the mirror of x")
		assert_eq(_instance(mirror.multimesh, 1).origin, Vector3(1.5, 0.0, 1.0))
	var scaled := scene.find_child("scaled", true, false) as MultiMeshInstance3D
	assert_not_null(scaled, "the scaled node is a MultiMeshInstance3D")
	if scaled != null:
		var t := _instance(scaled.multimesh, 1)
		assert_almost_eq(t.basis.get_scale(), Vector3(2.0, 1.0, 0.5), Vector3.ONE * 1.0e-4, "the scale of the instance")
		assert_almost_eq(t.basis.get_euler().y, QUARTER, 1.0e-4, "a turn of normalized 16-bit integers")
	scene.free()


func test_the_editor_import_makes_the_multimesh() -> void:
	var packed := load(FILE) as PackedScene
	assert_not_null(packed, "the editor imported the test file")
	if packed == null:
		return
	var scene := packed.instantiate()
	var row := scene.find_child("row", true, false) as MultiMeshInstance3D
	assert_not_null(row, "the imported node with instances is a MultiMeshInstance3D")
	if row != null:
		assert_eq(row.multimesh.instance_count, 16)
		assert_eq(_instance(row.multimesh, 15).origin, Vector3(3.75, 0.0, 0.0), "the import keeps the transforms")
	scene.free()


func test_attributes_that_are_not_correct_give_no_instances() -> void:
	var state := GLTFState.new()
	var no_accessor := GltfGpuInstancing.instance_transforms(state, {"TRANSLATION": 3})
	assert_eq(no_accessor.size(), 0, "an accessor that is not there")
	var extension := GltfGpuInstancing.new()
	var node := GLTFNode.new()
	assert_eq(extension._parse_node_extensions(state, node, {}), OK, "a node with no extension")
	assert_null(node.get_additional_data(GltfGpuInstancing.DATA))
	assert_eq(extension._parse_node_extensions(state, node, {"EXT_mesh_gpu_instancing": {}}), ERR_INVALID_DATA)
	assert_push_error("has no attributes")
