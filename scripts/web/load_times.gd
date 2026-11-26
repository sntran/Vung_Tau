class_name LoadTimes
extends RefCounted
## Plan 0031, D11 and R11: the times of the start of the web build. The page
## (tools/web/page.js) marks the times of its parts in window.vungTau.marks
## (performance.now(), in ms): the end of the download of the pack and of the
## WebAssembly, the compile of the WebAssembly, and (from the game) the start
## of the engine, the first frame, and the moment when the player can move.
## After that moment the game shows one line with the times at the top for
## SHOW_S, and the Settings app shows the same line.

## The time of the line at the top of the screen.
const SHOW_S := 20.0


## The line: the megabytes over the network before the first frame, the
## seconds to the first frame and until the player can move, the frames each
## second, and the memory of the page when the browser gives it. "" with no times.
static func line(times: Dictionary, fps: int) -> String:
	if not times.has("firstFrameS") or not times.has("canMoveS"):
		return ""
	var text := Content.format(Content.ui_text("load_times_line"), {
		"mb": "%.1f" % float(times.get("bytesMB", 0.0)),
		"first": "%.1f" % float(times.firstFrameS),
		"move": "%.1f" % float(times.canMoveS),
		"fps": fps,
	})
	if times.get("pageMB") != null:
		text += Content.format(Content.ui_text("load_times_page"), {"page": int(times.pageMB)})
	return text


## True when the build shows the line: on the web, a build of a branch always
## (and a build with no branch, a local export), the build of main with ?times.
static func shows(web: bool, branch: String, times_arg: bool) -> bool:
	if not web:
		return false
	return branch != "main" or times_arg


## The parts of the start in seconds, from the marks of the page (ms):
## downloadS (the pack and the WebAssembly over the network), compileS (the
## compile of the WebAssembly, also while the download goes on), engineS
## (from the end of both to the first script of the game), worldS (the build
## of the world to the first frame), and moveS (the first frame to "can move").
static func parts(marks: Dictionary) -> Dictionary:
	var result := {}
	var download := float(marks.get("downloadEnd", -1.0))
	var compile_end := float(marks.get("compileEnd", -1.0))
	var engine := float(marks.get("engine", -1.0))
	var first := float(marks.get("firstFrame", -1.0))
	var move := float(marks.get("canMove", -1.0))
	if download >= 0.0:
		result.downloadS = download / 1000.0
	if compile_end >= 0.0 and marks.has("compileStart"):
		result.compileS = (compile_end - float(marks.compileStart)) / 1000.0
	if engine >= 0.0:
		result.engineS = (engine - maxf(download, compile_end)) / 1000.0
	if first >= 0.0 and engine >= 0.0:
		result.worldS = (first - engine) / 1000.0
	if move >= 0.0 and first >= 0.0:
		result.moveS = (move - first) / 1000.0
	return result
