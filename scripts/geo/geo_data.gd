class_name GeoData
extends RefCounted
## The game data of plan 0003 in data/geo/build/ (made by tools/geo/build.py).
##
## It reads world.json, the roads, and the landmarks, and decodes the height
## chunks when the world asks for them. The decode is safe in a worker thread.

const ROOT := "res://data/geo/build/"
## The sea floor where the data has no chunk (far from the land).
const DEEP_SEA := -4.0

var root := ROOT
var world: Dictionary = {}
var projection: GeoProjection
var chunk_size := 256.0
var grid := 2.0
## The number of samples on one side of a chunk (129 for 256 m and 2 m).
var samples := 129
var height_offset := -20.0
var height_step := 0.01
## Vector2i(x, z) -> the chunk record of world.json.
var chunks: Dictionary = {}
var roads: Array = []
var landmarks: Array = []
var homestay: Dictionary = {}
## The overview grid for the far ground.
var overview: Dictionary = {}
var surface: Dictionary = {}
## Vector2i -> Array of [road index, first point, last point]: the road parts in each chunk.
var road_parts: Dictionary = {}

var _cache: Dictionary = {}
var _cache_order: Array[Vector2i] = []
var _mutex := Mutex.new()
const CACHE_SIZE := 64


## Returns null when the folder has no world.json (the geodata workflow did not run).
static func open(folder := ROOT) -> GeoData:
	var path := folder.path_join("world.json")
	if not FileAccess.file_exists(path):
		return null
	var data := GeoData.new()
	data.root = folder
	data.world = _read_json(path)
	data.projection = GeoProjection.from_world(data.world)
	data.chunk_size = float(data.world.get("chunk_size", 256))
	data.grid = float(data.world.get("grid", 2))
	data.samples = int(data.chunk_size / data.grid) + 1
	var height: Dictionary = data.world.get("height", {})
	data.height_offset = float(height.get("offset", -20.0))
	data.height_step = float(height.get("step", 0.01))
	for record: Dictionary in data.world.get("chunks", []):
		data.chunks[Vector2i(int(record.x), int(record.z))] = record
	data.surface = data.world.get("surface", {})
	data.roads = _read_json(folder.path_join("roads.json")).get("roads", [])
	data.landmarks = _read_json(folder.path_join("landmarks.json")).get("landmarks", [])
	data.homestay = _read_json(folder.path_join("homestay.json"))
	data._index_roads()
	var info: Dictionary = data.world.get("overview", {})
	var read := Png16.read_heights(folder.path_join("height/overview.png"), data.height_offset, data.height_step)
	if not read.has("error"):
		data.overview = {"x0": float(info.get("x0", 0.0)), "z0": float(info.get("z0", 0.0)),
				"step": float(info.get("step", 16.0)), "width": read.width, "height": read.height,
				"heights": read.heights}
	return data


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


## The chunk that has the game point.
func chunk_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / chunk_size), floori(z / chunk_size))


func has_chunk(key: Vector2i) -> bool:
	return chunks.has(key)


## The heights of a chunk (samples x samples, row by row from north to south).
## Returns an empty array for a chunk that the data does not have.
func chunk_heights(key: Vector2i) -> PackedFloat32Array:
	_mutex.lock()
	if _cache.has(key):
		var cached: PackedFloat32Array = _cache[key]
		_mutex.unlock()
		return cached
	_mutex.unlock()
	if not chunks.has(key):
		return PackedFloat32Array()
	var read := Png16.read_heights(root.path_join("height/%d_%d.png" % [key.x, key.y]), height_offset, height_step)
	if read.has("error") or read.width != samples or read.height != samples:
		push_error("GeoData: chunk %s cannot be read: %s" % [key, read.get("error", "wrong size")])
		return PackedFloat32Array()
	var heights: PackedFloat32Array = read.heights
	_mutex.lock()
	_cache[key] = heights
	_cache_order.append(key)
	while _cache_order.size() > CACHE_SIZE:
		_cache.erase(_cache_order.pop_front())
	_mutex.unlock()
	return heights


## True when the chunk is decoded, so that height_at() is exact there.
func is_decoded(key: Vector2i) -> bool:
	_mutex.lock()
	var result := _cache.has(key)
	_mutex.unlock()
	return result


## The ground height at a game point. It uses the 2 m chunk when it is decoded
## or when "decode" is true. Else it uses the overview grid.
func height_at(x: float, z: float, decode := false) -> float:
	var key := chunk_of(x, z)
	if chunks.has(key) and (decode or is_decoded(key)):
		var heights := chunk_heights(key)
		if not heights.is_empty():
			return _bilinear(heights, samples, samples, (x - key.x * chunk_size) / grid,
					(z - key.y * chunk_size) / grid)
	return overview_height(x, z)


func overview_height(x: float, z: float) -> float:
	if overview.is_empty():
		return DEEP_SEA
	var col := (x - float(overview.x0)) / float(overview.step)
	var row := (z - float(overview.z0)) / float(overview.step)
	if col < 0.0 or row < 0.0 or col > overview.width - 1 or row > overview.height - 1:
		return DEEP_SEA
	return _bilinear(overview.heights, overview.width, overview.height, col, row)


static func _bilinear(heights: PackedFloat32Array, width: int, height: int, col: float, row: float) -> float:
	var c0 := clampi(floori(col), 0, width - 2)
	var r0 := clampi(floori(row), 0, height - 2)
	var fc := clampf(col - c0, 0.0, 1.0)
	var fr := clampf(row - r0, 0.0, 1.0)
	var i := r0 * width + c0
	var top := lerpf(heights[i], heights[i + 1], fc)
	var bottom := lerpf(heights[i + width], heights[i + width + 1], fc)
	return lerpf(top, bottom, fr)


## Splits each road into parts, one for each chunk that it goes through.
func _index_roads() -> void:
	for r in roads.size():
		var points: Array = roads[r].points
		var start := 0
		var current := Vector2i(-99999, -99999)
		for i in points.size():
			var p: Array = points[i]
			var key := chunk_of(float(p[0]), float(p[2]))
			if key != current:
				if i > 0:
					_add_part(current, r, start, i)
				current = key
				start = i
		_add_part(current, r, start, points.size() - 1)


func _add_part(key: Vector2i, road: int, first: int, last: int) -> void:
	if last <= first:
		return
	if not road_parts.has(key):
		road_parts[key] = []
	road_parts[key].append([road, first, last])


## The road at a game point: the nearest road whose surface has the point, or {}.
func road_at(x: float, z: float) -> Dictionary:
	var point := Vector2(x, z)
	var best: Dictionary = {}
	var best_distance := INF
	for part: Array in road_parts.get(chunk_of(x, z), []):
		var road: Dictionary = roads[part[0]]
		var points: Array = road.points
		for i in range(part[1], part[2]):
			var a := Vector2(points[i][0], points[i][2])
			var b := Vector2(points[i + 1][0], points[i + 1][2])
			var d := point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b))
			if d <= float(road.width) / 2.0 + 0.5 and d < best_distance:
				best_distance = d
				best = road
	return best


## The found landmark with the ID, or {}.
func landmark(landmark_id: String) -> Dictionary:
	for record: Dictionary in landmarks:
		if record.id == landmark_id and record.get("found", false):
			return record
	return {}
