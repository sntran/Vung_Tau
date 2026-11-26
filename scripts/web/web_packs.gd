class_name WebPacks
extends Node
## Plan 0031, D5 (step 2): the packs of the web build that the game gets while
## it runs (data/web/packs.json). The game gets a pack when the player comes
## near its area, and the things of the pack show when it is there. On a
## computer (one whole pack) each pack is there from the start.

const PACKS := "res://data/web/packs.json"
## The player is checked this often (s).
const CHECK_S := 1.0
## On the web, HTTPRequest reads one part of the body in each frame, 64 KiB
## by default: a pack of 81 MB then takes about 1240 frames. With 4 MiB, about
## 20 frames.
const CHUNK_BYTES := 4 * 1024 * 1024

signal pack_ready(pack_id: String)

static var _instance: WebPacks
static var _entries: Dictionary = {}
static var _read := false
static var _loaded: Dictionary = {}

var _http: HTTPRequest
var _loading := ""
var _start_ms := 0
var _left := 0.0
var _player: Node3D
var _times: Dictionary = {}


## The entries of data/web/packs.json by id.
static func entries() -> Dictionary:
	if not _read:
		_read = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACKS)) if FileAccess.file_exists(PACKS) else null
		if parsed is Dictionary:
			for entry: Dictionary in parsed.get("packs", []):
				_entries[str(entry.id)] = entry
	return _entries


## True while the pack is not there yet: only on the web, for a pack of the
## list whose files are not in the main pack.
static func waiting(pack_id: String) -> bool:
	if not OS.has_feature("web") or _loaded.has(pack_id):
		return false
	var entry: Dictionary = entries().get(pack_id, {})
	if entry.is_empty():
		return false
	var files: Array = entry.get("files", [])
	# A build with the files in its main pack (a pack is not made).
	if not files.is_empty() and ResourceLoader.exists(str(files[0])):
		_loaded[pack_id] = true
		return false
	return true


## Calls "call" when the pack is there (at once when it is there now).
static func when_ready(pack_id: String, call: Callable) -> void:
	if not waiting(pack_id) or _instance == null:
		call.call()
		return
	var done := {"called": false}
	_instance.pack_ready.connect(func(id: String) -> void:
		if id == pack_id and not done.called:
			done.called = true
			call.call())


func _init(player: Node3D) -> void:
	name = "WebPacks"
	_player = player
	_instance = self


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = false
	_http.download_chunk_size = CHUNK_BYTES
	add_child(_http)
	_http.request_completed.connect(_on_downloaded)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


## The URL of a pack: next to the main pack of the page (b/BUILD/).
static func url_of(pack_id: String) -> String:
	return str(JavaScriptBridge.eval(
			"new URL(GODOT_CONFIG.mainPack.replace(/[^/]*$/, '%s.pck'), window.location.href).href" % pack_id, true))


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0 or _player == null:
		return
	_left = CHECK_S
	if _loading != "":
		_tell_page()
		return
	var at := _player.global_position
	for pack_id: String in entries():
		if not waiting(pack_id):
			continue
		var entry: Dictionary = entries()[pack_id]
		var area: Array = entry.get("area", [])
		var near := float(entry.get("near_m", 300.0))
		if area.size() == 4 and (at.x < float(area[0]) - near or at.x > float(area[2]) + near
				or at.z < float(area[1]) - near or at.z > float(area[3]) + near):
			continue
		_start(pack_id)
		return
	_tell_page()


func _start(pack_id: String) -> void:
	_loading = pack_id
	_start_ms = Time.get_ticks_msec()
	# The body stays in memory: on the web, HTTPRequest.download_file writes a
	# file of 0 bytes (Godot 4.7.2; docs/web/load.md, the test of D5).
	var error := _http.request(url_of(pack_id))
	if error != OK:
		push_warning("WebPacks: the request of the pack %s did not start: %d" % [pack_id, error])
		_loading = ""
	_tell_page()


func _on_downloaded(status: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var pack_id := _loading
	_loading = ""
	var path := "user://packs/%s.pck" % pack_id
	var download_ms := Time.get_ticks_msec() - _start_ms
	var stored := false
	var t0 := Time.get_ticks_msec()
	if status == HTTPRequest.RESULT_SUCCESS and code == 200:
		DirAccess.make_dir_recursive_absolute("user://packs")
		var out := FileAccess.open(path, FileAccess.WRITE)
		if out != null:
			out.store_buffer(body)
			out.close()
			stored = true
	if not stored or not ProjectSettings.load_resource_pack(path, false):
		push_warning("WebPacks: the pack %s did not load (result %d, HTTP %d)" % [pack_id, status, code])
		_left = 5.0
		_tell_page()
		return
	_loaded[pack_id] = true
	WorldModel.forget_levels()
	# storeLoadMs: the write to user:// and the load of the pack, in one frame.
	_times[pack_id] = {"downloadMs": download_ms, "bytes": body.size(),
			"storeLoadMs": Time.get_ticks_msec() - t0, "readyMs": Time.get_ticks_msec()}
	pack_ready.emit(pack_id)
	_tell_page()


## window.vungTau.packs (the time of each pack) and window.vungTau.waiting
## (the packs near the player that are not there yet), for PT-85.
func _tell_page() -> void:
	if not OS.has_feature("web"):
		return
	var waiting_near := 0
	if _player != null:
		var at := _player.global_position
		for pack_id: String in entries():
			var area: Array = entries()[pack_id].get("area", [])
			if waiting(pack_id) and area.size() == 4 and at.x >= float(area[0]) and at.x <= float(area[2]) \
					and at.z >= float(area[1]) and at.z <= float(area[3]):
				waiting_near += 1
	JavaScriptBridge.eval("window.vungTau = window.vungTau || {}; window.vungTau.packs = %s; window.vungTau.waiting = %d; window.vungTau.packLoading = '%s'" % [
			JSON.stringify(_times), waiting_near, _loading], true)
