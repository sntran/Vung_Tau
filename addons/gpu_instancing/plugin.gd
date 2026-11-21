@tool
extends EditorPlugin
## Registers GltfGpuInstancing for the import of the glTF files in the editor.

var _extension: GltfGpuInstancing


func _enter_tree() -> void:
	_extension = GltfGpuInstancing.new()
	GLTFDocument.register_gltf_document_extension(_extension)


func _exit_tree() -> void:
	GLTFDocument.unregister_gltf_document_extension(_extension)
	_extension = null
