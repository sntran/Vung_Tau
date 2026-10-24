extends Node
## Runs a play-test scenario. It is active only when the command line has
## --playtest=NAME (R32). Without it, it does nothing.
##
## Before the scenario starts, it can set only the start state (R33):
## --start-time=HH:MM, --day=N, --save-path=PATH (read by GameState), --seed=N,
## --quality=NAME (a quality preset, plan 0004).
## After the start, the scenario changes the game only through input events.
##
## Other arguments: --out=DIR (the folder for the screenshots and log.json)
## and --phase=N (the run number of a scenario with more than one run).

## A scenario must finish in this time (R36).
const TIME_LIMIT_S := 180.0

var active := false
var scenario_name := ""
var driver: PlaytestDriver
var _logger: Object


func _ready() -> void:
	scenario_name = GameState.arg_value("playtest")
	if scenario_name == "":
		set_process(false)
		return
	active = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	var start_time := GameState.arg_value("start-time")
	if start_time != "":
		var minutes := GameClock.parse_time(start_time)
		if minutes < 0:
			push_error("Playtest: --start-time=%s is not a time HH:MM." % start_time)
		else:
			GameState.minutes = minutes
	var quality := GameState.arg_value("quality")
	if quality != "":
		if Quality.PRESETS.has(quality):
			GameState.settings.quality = quality
		else:
			push_error("Playtest: --quality=%s is not a preset." % quality)
	var day := GameState.arg_value("day")
	if day.is_valid_int():
		GameState.day = maxi(day.to_int(), 1)
	var seed_text := GameState.arg_value("seed")
	if seed_text.is_valid_int():
		seed(seed_text.to_int())
	var out_dir := GameState.arg_value("out")
	if out_dir == "":
		out_dir = "user://playtest/%s" % scenario_name
	DirAccess.make_dir_recursive_absolute(out_dir)
	var phase_text := GameState.arg_value("phase")
	var phase := phase_text.to_int() if phase_text.is_valid_int() else 1
	driver = PlaytestDriver.new(get_tree(), out_dir, phase)
	_add_error_logger()
	_run.call_deferred()


## Records engine and script errors as failures, when the engine has the Logger class.
func _add_error_logger() -> void:
	if not ClassDB.class_exists("Logger"):
		return
	var script := GDScript.new()
	script.source_code = """extends Logger
var driver: Object
func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		editor_notify: bool, error_type: int, script_backtrace: Array) -> void:
	var text := rationale if rationale != "" else code
	if text.contains("ALSA") or file.contains("audio_driver"):
		return
	driver.failures.append("Godot error: %s (%s:%d)" % [text, file, line])
"""
	if script.reload() != OK:
		return
	_logger = script.new()
	_logger.set("driver", driver)
	OS.call("add_logger", _logger)


func _run() -> void:
	# Wait for the main scene and some frames, so that the world is ready.
	await get_tree().process_frame
	await driver.wait_frames(5)
	if driver.main() == null:
		driver.fail("the main scene did not load (see the script errors above)")
		_finish()
		return
	var path := "res://playtests/%s.gd" % scenario_name
	if not ResourceLoader.exists(path):
		driver.fail("no scenario file %s" % path)
		_finish()
		return
	var scenario: Object = load(path).new()
	var timer := get_tree().create_timer(TIME_LIMIT_S)
	timer.timeout.connect(_on_time_limit)
	driver.step("start %s, phase %d, %s, %s" % [scenario_name, driver.phase,
			GameClock.format_time(GameState.minutes), get_window().size])
	await scenario.run(driver)
	_finish()


func _on_time_limit() -> void:
	driver.fail("the scenario takes more than %d seconds" % TIME_LIMIT_S)
	_finish()


var _finished := false


func _finish() -> void:
	if _finished:
		return
	_finished = true
	var log_path := driver.out_dir.path_join("log.json")
	var data := {"scenario": scenario_name, "size": "%dx%d" % [get_window().size.x, get_window().size.y],
			"phases": []}
	if driver.phase > 1 and FileAccess.file_exists(log_path):
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(log_path))
		if typeof(old) == TYPE_DICTIONARY:
			data = old
	var passed := driver.failures.is_empty()
	data.phases.append({"phase": driver.phase, "result": "pass" if passed else "fail",
			"failures": driver.failures, "steps": driver.steps})
	data.result = "pass"
	for item: Dictionary in data.phases:
		if item.result != "pass":
			data.result = "fail"
	var file := FileAccess.open(log_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	if passed:
		print("PLAYTEST PASS %s phase %d" % [scenario_name, driver.phase])
	else:
		print("PLAYTEST FAIL %s phase %d" % [scenario_name, driver.phase])
		for failure in driver.failures:
			print("  - " + failure)
	# A voice that plays at the quit is not freed: stop the sounds, then wait
	# for the audio server.
	get_tree().call_group("main", "stop_sounds")
	for i in 3:
		await get_tree().process_frame
	get_tree().quit(0 if passed else 1)
