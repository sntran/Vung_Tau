@tool
class_name GltfGpuInstancing
extends GLTFDocumentExtension
## Imports the glTF extension EXT_mesh_gpu_instancing.
##
## A glTF node with this extension shows its mesh once at each instance.
## Godot 4.7 does not read the extension: without this class, the node
## shows its mesh one time only. This class makes a MultiMeshInstance3D
## for such a node, with one transform for each instance.
##
## The attributes of the extension: TRANSLATION (VEC3, float), ROTATION
## (VEC4: float, or normalized 8-bit or 16-bit integers) and SCALE (VEC3,
## float). An attribute that is not there has its default value.
## The node keeps its own transform. World puts a mirror (a scale of -1)
## on the node, not on each instance, so the renderer turns the faces of
## the node over.
##
## The editor plugin (plugin.gd) registers this class for the import.
## Code that loads a glTF file at run time registers it with
## GLTFDocument.register_gltf_document_extension().

const NAME := "EXT_mesh_gpu_instancing"

# The key of the attributes in the additional data of a GLTFNode.
const DATA := &"EXT_mesh_gpu_instancing"

# glTF component types.
const BYTE := 5120
const SHORT := 5122
const FLOAT := 5126


func _get_supported_extensions() -> PackedStringArray:
	return PackedStringArray([NAME])


# The accessors are not read yet when the nodes are parsed. Keep the
# indices of the attributes. _generate_scene_node() reads them.
func _parse_node_extensions(_state: GLTFState, gltf_node: GLTFNode, extensions: Dictionary) -> Error:
	if not extensions.has(NAME):
		return OK
	var attributes: Dictionary = extensions[NAME].get("attributes", {})
	if attributes.is_empty():
		push_error("%s: the node \"%s\" has no attributes." % [NAME, gltf_node.original_name])
		return ERR_INVALID_DATA
	gltf_node.set_additional_data(DATA, attributes)
	return OK


func _generate_scene_node(state: GLTFState, gltf_node: GLTFNode, _scene_parent: Node) -> Node3D:
	var attributes = gltf_node.get_additional_data(DATA)
	if attributes == null or gltf_node.mesh < 0:
		return null
	var transforms := instance_transforms(state, attributes)
	if transforms.is_empty():
		push_error("%s: the instances of the node \"%s\" are not correct." % [NAME, gltf_node.original_name])
		return null
	var gltf_mesh: GLTFMesh = state.meshes[gltf_node.mesh]
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = gltf_mesh.mesh.get_mesh()
	multimesh.instance_count = transforms.size()
	# The buffer, not set_instance_transform(): the headless renderer of
	# an import or an export in CI does not keep the instance transforms.
	multimesh.buffer = buffer_of(transforms)
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	return node


## The buffer of a MultiMesh (TRANSFORM_3D) with these transforms: for
## each instance, 12 floats, a row of the basis and the origin at a time.
static func buffer_of(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(12 * transforms.size())
	for i in transforms.size():
		var t := transforms[i]
		for row in 3:
			buffer[12 * i + 4 * row] = t.basis.x[row]
			buffer[12 * i + 4 * row + 1] = t.basis.y[row]
			buffer[12 * i + 4 * row + 2] = t.basis.z[row]
			buffer[12 * i + 4 * row + 3] = t.origin[row]
	return buffer


## The transform of each instance, from the attributes of the extension
## (a Dictionary of an attribute name to the index of its accessor).
## Gives an empty array when the attributes are not correct.
static func instance_transforms(state: GLTFState, attributes: Dictionary) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var moves := _attribute(state, attributes, "TRANSLATION", 3)
	var turns := _attribute(state, attributes, "ROTATION", 4)
	var sizes := _attribute(state, attributes, "SCALE", 3)
	var count := -1
	for values: Variant in [moves, turns, sizes]:
		if values == null:
			return result
		var n: int = values[1]
		if n < 0:
			continue
		if count >= 0 and n != count:
			return result
		count = n
	if count <= 0:
		return result
	for i in count:
		var move := Vector3.ZERO
		var turn := Quaternion.IDENTITY
		var size := Vector3.ONE
		if moves[1] >= 0:
			move = Vector3(moves[0][3 * i], moves[0][3 * i + 1], moves[0][3 * i + 2])
		if turns[1] >= 0:
			var t: PackedFloat32Array = turns[0]
			turn = Quaternion(t[4 * i], t[4 * i + 1], t[4 * i + 2], t[4 * i + 3]).normalized()
		if sizes[1] >= 0:
			size = Vector3(sizes[0][3 * i], sizes[0][3 * i + 1], sizes[0][3 * i + 2])
		result.append(Transform3D(Basis(turn).scaled_local(size), move))
	return result


# The values of an attribute: [values, count]. The count is -1 for an
# attribute that is not there. Gives null for an accessor that is not
# correct.
static func _attribute(state: GLTFState, attributes: Dictionary, name: String, width: int) -> Variant:
	if not attributes.has(name):
		return [PackedFloat32Array(), -1]
	var index := int(attributes[name])
	if index < 0 or index >= state.accessors.size():
		return null
	var accessor: GLTFAccessor = state.accessors[index]
	if accessor.sparse_count > 0 or accessor.buffer_view < 0:
		return null
	var component := accessor.component_type
	var size := {FLOAT: 4, SHORT: 2, BYTE: 1}.get(component, 0) as int
	if size == 0 or (component != FLOAT and name != "ROTATION"):
		return null
	var view: GLTFBufferView = state.buffer_views[accessor.buffer_view]
	var bytes := view.load_buffer_view_data(state)
	var stride := view.byte_stride if view.byte_stride > 0 else size * width
	var count := accessor.count
	if accessor.byte_offset + (count - 1) * stride + size * width > bytes.size():
		return null
	var values := PackedFloat32Array()
	values.resize(count * width)
	for i in count:
		for k in width:
			var at := accessor.byte_offset + i * stride + k * size
			match component:
				FLOAT:
					values[i * width + k] = bytes.decode_float(at)
				SHORT:
					values[i * width + k] = maxf(bytes.decode_s16(at) / 32767.0, -1.0)
				BYTE:
					values[i * width + k] = maxf(bytes.decode_s8(at) / 127.0, -1.0)
	return [values, count]
