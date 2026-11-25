class_name WebPackTest
extends Node
## Plan 0031, D5 (step 2): the test of a second pack in the web build. With the
## URL parameter packtest (the argument --packtest), the game downloads
## packtest.pck of its build while it runs (HTTPRequest, to user://), loads it
## (ProjectSettings.load_resource_pack()), and makes a scene that only that
## pack has: the near level of a building, which the main pack of the web
## leaves out (step 1). It gives the result to the page in
## window.vungTau.packTest: {done, downloaded, loaded, scene, meshes, bytes,
## download_ms, load_ms, error}.

const PACK := "packtest.pck"
const TARGET := "user://packtest.pck"
## The scene that only the test pack has.
const SCENE := "res://assets/world/nha_mai_ngoi_cam.glb"

var result := {"done": false, "downloaded": false, "loaded": false, "scene": false, "meshes": 0,
		"bytes": 0, "download_ms": -1, "load_ms": -1, "error": ""}
var _http: HTTPRequest
var _start_ms := 0


func _ready() -> void:
	name = "WebPackTest"
	_http = HTTPRequest.new()
	_http.download_file = TARGET
	_http.use_threads = false
	add_child(_http)
	_http.request_completed.connect(_on_downloaded)
	var url := pack_url()
	_start_ms = Time.get_ticks_msec()
	var error := _http.request(url)
	if error != OK:
		_finish("the request of %s did not start: %d" % [url, error])


## The URL of the test pack: next to the main pack of the page (b/BUILD/).
static func pack_url() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval(
			"new URL(GODOT_CONFIG.mainPack.replace(/[^/]*$/, '%s'), window.location.href).href" % PACK, true))


func _on_downloaded(status: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	result.download_ms = Time.get_ticks_msec() - _start_ms
	if status != HTTPRequest.RESULT_SUCCESS or code != 200:
		_finish("the download: result %d, HTTP %d" % [status, code])
		return
	result.downloaded = true
	result.bytes = FileAccess.open(TARGET, FileAccess.READ).get_length() if FileAccess.file_exists(TARGET) else 0
	var t0 := Time.get_ticks_msec()
	result.loaded = ProjectSettings.load_resource_pack(TARGET, false)
	if not result.loaded:
		_finish("load_resource_pack() returned false")
		return
	var scene := load(SCENE) as PackedScene
	result.load_ms = Time.get_ticks_msec() - t0
	if scene == null:
		_finish("%s did not load from the pack" % SCENE)
		return
	var node := scene.instantiate()
	result.scene = node != null
	if node != null:
		result.meshes = node.find_children("*", "MeshInstance3D", true, false).size()
		node.free()
	_finish("")


func _finish(error: String) -> void:
	result.done = true
	result.error = error
	if error != "":
		push_warning("WebPackTest: " + error)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.vungTau = window.vungTau || {}; window.vungTau.packTest = %s" % JSON.stringify(result), true)
	print("WebPackTest: %s" % JSON.stringify(result))
