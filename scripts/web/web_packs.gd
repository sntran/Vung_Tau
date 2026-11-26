class_name WebPacks
extends Node
## Plan 0031, D5 (step 2): the packs of the web build that the game gets while
## it runs (data/web/packs.json). The game gets a pack when the player comes
## near its area, and the things of the pack show when it is there. On a
## computer (one whole pack) each pack is there from the start.
##
## D14: the pack "models" has the mid and near levels of the models of World.
## Until it is there, each model shows its far level from 0 m; when it comes,
## the models and the cells of the rows get their better levels, the nearest
## first, with UPGRADE_MS of work in each frame. A play test on a computer
## keeps the files of a pack out with --packs-sim=SECONDS (simulate()), and
## they come SECONDS after the first frame (release()).

const PACKS := "res://data/web/packs.json"
## The player is checked this often (s).
const CHECK_S := 1.0
## D15: the state of a pack that the page gets is checked this often (s).
const POLL_S := 0.25

## The work of the upgrades of D14 in each frame (ms).
const UPGRADE_MS := 8.0
## D16: the builds before D15 wrote each pack here (report 0031, D-0031-03).
const OLD_PACKS := "user://packs"

signal pack_ready(pack_id: String)

static var _instance: WebPacks
static var _entries: Dictionary = {}
static var _read := false
static var _loaded: Dictionary = {}
## D14: the packs that a computer keeps out (a play test, a unit test), and their files.
static var _simulated: Dictionary = {}
static var _hidden: Dictionary = {}

var _loading := ""
var _start_ms := 0
var _left := 0.0
var _player: Node3D
var _times: Dictionary = {}
## D14: the upgrades that wait, nearest first: [WorldModel] or [WorldRow, cell index].
var _upgrades: Array = []
var _sim_left := -1.0
## D16: the pack whose load and upgrades go on, and its longest frame (ms).
var _measured := ""
var _longest_ms := 0.0


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
	if _simulated.has(pack_id):
		return true
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


## D14: keeps the files of these packs out on a computer, as on the web before
## the packs come (a play test with --packs-sim, a unit test). [] ends it.
static func simulate(pack_ids: Array) -> void:
	_simulated.clear()
	_hidden.clear()
	for pack_id: String in pack_ids:
		_simulated[pack_id] = true
		_loaded.erase(pack_id)
		for file: String in entries().get(pack_id, {}).get("files", []):
			_hidden[file] = pack_id
	WorldModel.forget_levels()


## True when the file is in a pack that simulate() keeps out.
static func hides(path: String) -> bool:
	return _hidden.has(path)


## D14: the files of a pack that simulate() kept out come (as a download on the web).
static func release(pack_id: String) -> void:
	_simulated.erase(pack_id)
	for path: String in _hidden.keys():
		if _hidden[path] == pack_id:
			_hidden.erase(path)
	_loaded[pack_id] = true
	WorldModel.forget_levels()
	if _instance != null:
		_instance._on_pack(pack_id)


## The number of upgrades that wait within the distance of the point (D14, R14).
static func upgrades_within(point: Vector3, distance: float) -> int:
	if _instance == null:
		return 0
	var count := 0
	for job: Array in _instance._upgrades:
		if _job_at(job).distance_to(point) <= distance:
			count += 1
	return count


## D16: removes the packs that the builds before D15 wrote to user://. The
## browser reads all of user:// into memory at each start.
static func remove_old_packs() -> void:
	if not DirAccess.dir_exists_absolute(OLD_PACKS):
		return
	for file: String in DirAccess.get_files_at(OLD_PACKS):
		DirAccess.remove_absolute(OLD_PACKS.path_join(file))
	DirAccess.remove_absolute(OLD_PACKS)


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
	if OS.has_feature("web"):
		remove_old_packs()
	if GameState.has_arg("packs-sim"):
		_sim_left = float(GameState.arg_value("packs-sim"))
		simulate(["models"])


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _process(delta: float) -> void:
	_run_upgrades()
	_measure_frame(delta)
	# D14 on a computer: the pack "comes" some seconds after the first frame.
	if _sim_left >= 0.0 and Engine.get_frames_drawn() > 1:
		_sim_left -= delta
		if _sim_left < 0.0:
			for pack_id: String in _simulated.keys():
				release(pack_id)
	if not OS.has_feature("web"):
		return
	_left -= delta
	if _left > 0.0 or _player == null:
		return
	_left = CHECK_S
	if _loading != "":
		_left = POLL_S
		_poll()
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


## D15: the page gets the pack (from its cache or the network, tools/web/page.js)
## and writes it in the file system of the engine (not user://).
func _start(pack_id: String) -> void:
	_loading = pack_id
	_start_ms = Time.get_ticks_msec()
	_measured = pack_id
	_longest_ms = 0.0
	JavaScriptBridge.eval("window.vungTau.loadPack(%s)" % JSON.stringify(pack_id), true)
	_tell_page()


## The state of the pack that the page gets; its load when it is there.
func _poll() -> void:
	var pack_id := _loading
	var parsed: Variant = JSON.parse_string(str(JavaScriptBridge.eval(
			"JSON.stringify((window.vungTau.packState || {})[%s] || {})" % JSON.stringify(pack_id), true)))
	var state: Dictionary = parsed if parsed is Dictionary else {}
	if state.get("state", "") == "error":
		push_warning("WebPacks: the page did not get the pack %s: %s" % [pack_id, state.get("error", "")])
		_loading = ""
		_left = 5.0
		_tell_page()
		return
	if state.get("state", "") != "done" or not state.has("path"):
		return
	_loading = ""
	var t0 := Time.get_ticks_msec()
	if not ProjectSettings.load_resource_pack(str(state.path), false):
		push_warning("WebPacks: the pack %s did not load from %s" % [pack_id, state.path])
		_left = 5.0
		_tell_page()
		return
	_loaded[pack_id] = true
	WorldModel.forget_levels()
	# loadMs: the load of the pack (one frame); fromCache: the bytes from the cache of the page.
	_times[pack_id] = {"downloadMs": Time.get_ticks_msec() - _start_ms, "bytes": int(state.get("size", 0)),
			"fromCache": int(state.get("fromCache", 0)), "loadMs": Time.get_ticks_msec() - t0, "readyMs": Time.get_ticks_msec()}
	_on_pack(pack_id)
	_tell_page()


## A pack is there: the things that wait for it come, and (D14) the models
## and the cells of the rows get their better levels, the nearest first.
func _on_pack(pack_id: String) -> void:
	pack_ready.emit(pack_id)
	var at := _player.global_position if _player != null else Vector3.ZERO
	for node in get_tree().get_nodes_in_group(WorldModel.GROUP):
		var model := node as WorldModel
		if model != null and model.missing_levels():
			_upgrades.append([model])
	for node in get_tree().get_nodes_in_group(WorldRow.GROUP):
		var row := node as WorldRow
		if row == null:
			continue
		for index in row.cells.size():
			if row.cell_needs_upgrade(index):
				_upgrades.append([row, index])
	_upgrades.sort_custom(func(a: Array, b: Array) -> bool: return _job_at(a).distance_to(at) < _job_at(b).distance_to(at))


## The place of an upgrade (the model, or the middle of the cell).
static func _job_at(job: Array) -> Vector3:
	if not is_instance_valid(job[0]):
		return Vector3.INF
	if job.size() == 1:
		return (job[0] as Node3D).global_position
	var row := job[0] as WorldRow
	return row.global_transform * (row.cells[int(job[1])].node as Node3D).position


## The upgrades of D14, nearest first, for UPGRADE_MS in each frame. A model
## whose files still load waits at the end of the list.
func _run_upgrades() -> void:
	if _upgrades.is_empty():
		return
	var end := Time.get_ticks_usec() + int(UPGRADE_MS * 1000.0)
	var tries := _upgrades.size()
	while not _upgrades.is_empty() and tries > 0 and Time.get_ticks_usec() < end:
		tries -= 1
		var job: Array = _upgrades.pop_front()
		if not is_instance_valid(job[0]):
			continue
		if job.size() == 1:
			if not (job[0] as WorldModel).upgrade():
				_upgrades.append(job)
		else:
			(job[0] as WorldRow).upgrade_cell(int(job[1]))


## D16: the longest frame from the request of a pack until its upgrades are
## done (longestFrameMs), and the time of the upgrades (upgradesMs).
func _measure_frame(delta: float) -> void:
	if _measured == "":
		return
	_longest_ms = maxf(_longest_ms, delta * 1000.0)
	if _loading != "" or not _upgrades.is_empty() or not _times.has(_measured):
		return
	_times[_measured].longestFrameMs = roundf(_longest_ms)
	_times[_measured].upgradesMs = Time.get_ticks_msec() - int(_times[_measured].readyMs)
	_measured = ""
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
