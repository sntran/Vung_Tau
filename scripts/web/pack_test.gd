class_name WebPackTest
extends Node
## Plan 0031, D5 (step 2): the test of a second pack in the web build. With the
## URL parameter packtest (the argument --packtest), the game downloads
## packtest.pck of its build while it runs, puts it in user://, loads it
## (ProjectSettings.load_resource_pack()), and makes a scene that only that
## pack has: the near level of a building, which the main pack of the web
## leaves out (step 1). It tries two ways:
## - "file": HTTPRequest writes the download to user:// (download_file);
## - "memory": HTTPRequest keeps the body, and FileAccess writes it to user://.
## It gives the result to the page in window.vungTau.packTest: {done, ways:
## {file, memory}, each {downloaded, counted, body, file_bytes, loaded, scene,
## meshes, download_ms, load_ms, error}}.

const PACK := "packtest.pck"
## The scene that only the test pack has.
const SCENE := "res://assets/world/nha_mai_ngoi_cam.glb"
const WAYS := ["file", "memory"]

var result := {"done": false, "ways": {}}
var _http: HTTPRequest
var _way := 0
var _start_ms := 0


func _ready() -> void:
	name = "WebPackTest"
	_http = HTTPRequest.new()
	_http.use_threads = false
	add_child(_http)
	_http.request_completed.connect(_on_downloaded)
	_start()


static func target(way: String) -> String:
	return "user://packtest_%s.pck" % way


func _start() -> void:
	var way: String = WAYS[_way]
	result.ways[way] = {"downloaded": false, "counted": 0, "body": 0, "file_bytes": 0, "loaded": false,
			"scene": false, "meshes": 0, "download_ms": -1, "load_ms": -1, "error": ""}
	_http.download_file = target(way) if way == "file" else ""
	var url := pack_url()
	_start_ms = Time.get_ticks_msec()
	var error := _http.request(url)
	if error != OK:
		_next("the request of %s did not start: %d" % [url, error])


## The URL of the test pack: next to the main pack of the page (b/BUILD/).
static func pack_url() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval(
			"new URL(GODOT_CONFIG.mainPack.replace(/[^/]*$/, '%s'), window.location.href).href" % PACK, true))


func _on_downloaded(status: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var way: String = WAYS[_way]
	var r: Dictionary = result.ways[way]
	r.download_ms = Time.get_ticks_msec() - _start_ms
	r.counted = _http.get_downloaded_bytes()
	r.body = body.size()
	if status != HTTPRequest.RESULT_SUCCESS or code != 200:
		_next("the download: result %d, HTTP %d" % [status, code])
		return
	r.downloaded = true
	var path := target(way)
	if way == "memory":
		var out := FileAccess.open(path, FileAccess.WRITE)
		if out == null:
			_next("user:// does not open: %d" % FileAccess.get_open_error())
			return
		out.store_buffer(body)
		out.close()
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		r.file_bytes = f.get_length() if f != null else -1
	var t0 := Time.get_ticks_msec()
	r.loaded = ProjectSettings.load_resource_pack(path, false)
	if not r.loaded:
		_next("load_resource_pack() returned false")
		return
	var scene := load(SCENE) as PackedScene
	r.load_ms = Time.get_ticks_msec() - t0
	if scene == null:
		_next("%s did not load from the pack" % SCENE)
		return
	var node := scene.instantiate()
	r.scene = node != null
	if node != null:
		r.meshes = node.find_children("*", "MeshInstance3D", true, false).size()
		node.free()
	_next("")


## The end of a way: the next way, or the end of the test. After a way that
## loads the pack, the scene is there, so the next way is not a test.
func _next(error: String) -> void:
	var way: String = WAYS[_way]
	result.ways[way].error = error
	if error != "":
		push_warning("WebPackTest (%s): %s" % [way, error])
	_way += 1
	if error != "" and _way < WAYS.size():
		_start.call_deferred()
		return
	result.done = true
	result.works = WAYS.any(func(w: String) -> bool: return result.ways.has(w) and result.ways[w].scene)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.vungTau = window.vungTau || {}; window.vungTau.packTest = %s" % JSON.stringify(result), true)
	print("WebPackTest: %s" % JSON.stringify(result))
