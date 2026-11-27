class_name StartProfile
extends RefCounted
## Plan 0031, D17 and R17: the profile of the start. Each part of the start
## marks its end; a part is the time from the mark before. The first mark
## counts from the start of the engine. On a computer the argument
## --start-profile prints the parts when the scooter or the player can move;
## on the web the page gets them (window.vungTau.profile, tools/web/check.js).

static var _parts: Array = []
static var _last_usec := -1
## What the renderer did until a point of the start: [point, {name: value}].
static var _render: Array = []


## The end of a part of the start.
static func mark(part: String) -> void:
	var now := Time.get_ticks_usec()
	var from := _last_usec if _last_usec >= 0 else 0
	_parts.append([part, (now - from) / 1000.0])
	_last_usec = now


## What the renderer did until now: the pipelines it compiled (by cause),
## the objects and the draw calls of the last frame, and the memory of the
## pictures and the meshes.
static func note_render(point: String) -> void:
	var info := {}
	for item: Array in [
			["pipelines of the 2D", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS],
			["pipelines of new meshes", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH],
			["pipelines of new surfaces", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE],
			["pipelines at the draw", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW],
			["pipelines of specializations", RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION],
			["objects in the frame", RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME],
			["draw calls in the frame", RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME],
			["MB of pictures", RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED],
			["MB of meshes and buffers", RenderingServer.RENDERING_INFO_BUFFER_MEM_USED]]:
		var value := RenderingServer.get_rendering_info(item[1])
		info[item[0]] = snappedf(value / 1048576.0, 0.1) if String(item[0]).begins_with("MB") else value
	_render.append([point, info])


## The notes of the renderer as lines of text.
static func render_text() -> String:
	var lines: Array[String] = []
	for note: Array in _render:
		lines.append("%s: %s" % [note[0], JSON.stringify(note[1])])
	return "\n".join(lines)


## The parts: [name, ms], in order.
static func parts() -> Array:
	return _parts.duplicate(true)


## The sum of the parts (ms).
static func total_ms() -> float:
	var sum := 0.0
	for part: Array in _parts:
		sum += float(part[1])
	return sum


## The parts as lines of text.
static func text() -> String:
	var lines: Array[String] = []
	for part: Array in _parts:
		lines.append("%8.0f ms  %s" % [float(part[1]), part[0]])
	lines.append("%8.0f ms  in all" % total_ms())
	return "\n".join(lines)


## The parts as JSON for the page.
static func json() -> String:
	return JSON.stringify(_parts)


static func clear() -> void:
	_parts.clear()
	_render.clear()
	_last_usec = -1
