class_name Png16
extends RefCounted
## Reads the 16-bit gray PNG height files of tools/geo/build.py.
##
## Godot changes 16-bit PNG files to 8 bits when it loads them, so the game
## reads these files itself. The files use only the PNG filters "None" (0)
## and "Up" (2) (see tools/geo/geodata/pngio.py).

const SIGNATURE := [137, 80, 78, 71, 13, 10, 26, 10]


## Returns {"width", "height", "values": PackedInt32Array} or {"error": text}.
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 8:
		return {"error": "the file is too short"}
	for i in 8:
		if bytes[i] != SIGNATURE[i]:
			return {"error": "the file is not a PNG file"}
	var pos := 8
	var width := 0
	var height := 0
	var idat := PackedByteArray()
	while pos + 8 <= bytes.size():
		var length := _u32(bytes, pos)
		var kind := bytes.slice(pos + 4, pos + 8).get_string_from_ascii()
		if kind == "IHDR":
			width = _u32(bytes, pos + 8)
			height = _u32(bytes, pos + 12)
			if bytes[pos + 16] != 16 or bytes[pos + 17] != 0:
				return {"error": "the PNG file is not 16-bit gray"}
		elif kind == "IDAT":
			idat.append_array(bytes.slice(pos + 8, pos + 8 + length))
		elif kind == "IEND":
			break
		pos += 12 + length
	if width <= 0 or height <= 0:
		return {"error": "the PNG file has no header"}
	var stride := width * 2 + 1
	var raw := idat.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != stride * height:
		return {"error": "the PNG data has the wrong size"}
	var values := PackedInt32Array()
	values.resize(width * height)
	var previous := PackedByteArray()
	previous.resize(width * 2)
	var row := PackedByteArray()
	row.resize(width * 2)
	for r in height:
		var start := r * stride
		var filter := raw[start]
		if filter == 0:
			for i in width * 2:
				row[i] = raw[start + 1 + i]
		elif filter == 2:
			for i in width * 2:
				row[i] = (raw[start + 1 + i] + previous[i]) & 0xFF
		else:
			return {"error": "the PNG filter %d is not supported" % filter}
		var base := r * width
		for c in width:
			values[base + c] = (row[c * 2] << 8) | row[c * 2 + 1]
		var swap := previous
		previous = row
		row = swap
	return {"width": width, "height": height, "values": values}


## Reads a height file and returns the heights in meters: value * step + offset.
## Returns an empty array when the file cannot be read.
static func read_heights(path: String, offset: float, step: float) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "no file %s" % path}
	var result := decode(FileAccess.get_file_as_bytes(path))
	if result.has("error"):
		return result
	var values: PackedInt32Array = result.values
	var heights := PackedFloat32Array()
	heights.resize(values.size())
	for i in values.size():
		heights[i] = values[i] * step + offset
	return {"width": result.width, "height": result.height, "heights": heights}


static func _u32(bytes: PackedByteArray, pos: int) -> int:
	return (bytes[pos] << 24) | (bytes[pos + 1] << 16) | (bytes[pos + 2] << 8) | bytes[pos + 3]
