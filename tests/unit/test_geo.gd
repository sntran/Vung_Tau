extends GutTest
## Tests for the geodata code of the game (plan 0005, R17). The tests of the
## pipeline (road widths, blocks, the homestay hẻm) are in tools/geo/tests/.


func test_projection_known_points() -> void:
	# The expected values come from pyproj (EPSG:4326 to EPSG:32648).
	var p := GeoProjection.new()
	var cases := [
		[107.0728, 10.3466, 726971.3326, 1144471.8244],
		[107.05, 10.30, 724506.7961, 1139300.2084],
		[107.13, 10.42, 733182.9702, 1152633.9530],
		[108.5, 20.0, 866294.0087, 2215311.1044],
	]
	for c: Array in cases:
		var utm := p.to_utm(c[0], c[1])
		assert_almost_eq(utm[0], c[2], 0.01, "easting of %s" % [c])
		assert_almost_eq(utm[1], c[3], 0.01, "northing of %s" % [c])


func test_projection_round_trip_below_one_centimeter() -> void:
	var p := GeoProjection.new(726970.0, 1144470.0)
	for c: Array in [[107.05, 10.30], [107.13, 10.42], [107.0776, 10.3343]]:
		var game := p.to_game(c[0], c[1])
		var back := p.game_to_lonlat(game.x, game.y)
		var again := p.to_game(back[0], back[1])
		assert_lt(game.distance_to(again), 0.01)
		assert_almost_eq(back[0], float(c[0]), 1e-7)
		assert_almost_eq(back[1], float(c[1]), 1e-7)


func test_projection_axes() -> void:
	var p := GeoProjection.new(726970.0, 1144470.0)
	var here := p.to_game(107.0728, 10.3466)
	var north := p.to_game(107.0728, 10.3566)
	var east := p.to_game(107.0828, 10.3466)
	assert_lt(north.y, here.y, "north is game -Z")
	assert_gt(east.x, here.x, "east is game +X")


func test_png16_decode() -> void:
	var result := Png16.decode(FileAccess.get_file_as_bytes("res://tests/data/height16.png"))
	assert_false(result.has("error"), str(result.get("error", "")))
	assert_eq(result.width, 4)
	assert_eq(result.height, 3)
	assert_eq(Array(result.values), [0, 1, 2, 65535, 256, 257, 1000, 4000, 30000, 30001, 30002, 30003])


func test_png16_rejects_other_files() -> void:
	assert_true(Png16.decode(PackedByteArray([1, 2, 3])).has("error"))
	assert_true(Png16.decode(FileAccess.get_file_as_bytes("res://icon.svg")).has("error"))


func test_height_sampling_on_a_small_grid() -> void:
	var heights := PackedFloat32Array([0.0, 2.0, 4.0, 10.0, 12.0, 14.0, 20.0, 22.0, 24.0])
	assert_almost_eq(GeoData._bilinear(heights, 3, 3, 0.0, 0.0), 0.0, 0.0001)
	assert_almost_eq(GeoData._bilinear(heights, 3, 3, 1.0, 1.0), 12.0, 0.0001)
	assert_almost_eq(GeoData._bilinear(heights, 3, 3, 0.5, 0.0), 1.0, 0.0001)
	assert_almost_eq(GeoData._bilinear(heights, 3, 3, 1.5, 1.5), 18.0, 0.0001)
	assert_almost_eq(GeoData._bilinear(heights, 3, 3, 5.0, 1.0), 14.0, 0.0001, "out of the grid: the edge")


func test_sun_position() -> void:
	var day := GameCalendar.day_of_year(2)
	assert_eq(day, GameCalendar.day_of_year(1) % 365 + 1, "the day of the year follows the calendar")
	var noon := SunPosition.at(10.35, 107.08, 80, 11.0 * 60.0 + 53.0)
	assert_almost_eq(float(noon.elevation), 79.6, 1.5, "near the equinox, the sun is high at noon")
	var morning := SunPosition.at(10.35, 107.08, 80, 6.0 * 60.0)
	assert_lt(float(morning.elevation), 5.0)
	assert_gt(float(morning.elevation), -5.0)
	assert_almost_eq(float(morning.azimuth), 90.0, 5.0, "the sun comes up in the east")
	var evening := SunPosition.at(10.35, 107.08, 80, 18.0 * 60.0)
	assert_almost_eq(float(evening.azimuth), 270.0, 5.0, "the sun goes down in the west")
	var night := SunPosition.at(10.35, 107.08, 80, 21.0 * 60.0)
	assert_lt(float(night.elevation), -30.0)
	var east := SunPosition.direction(0.0, 90.0)
	assert_almost_eq(east.x, 1.0, 0.0001)
	var north := SunPosition.direction(0.0, 0.0)
	assert_almost_eq(north.z, -1.0, 0.0001)


func test_terrain_arrays() -> void:
	var heights := PackedFloat32Array()
	heights.resize(5 * 5)
	for i in heights.size():
		heights[i] = float(i % 5)
	var arrays := TerrainBuilder.arrays(heights, 5, 5, 0, 0, 3, 2, 2.0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# 3 x 3 vertices and a skirt of 3 vertices on each of the 4 edges.
	assert_eq(vertices.size(), 9 + 12)
	assert_eq(vertices[8], Vector3(8.0, 4.0, 8.0), "the last vertex is 8 m from the first")
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	assert_eq(indices.size(), (2 * 2 * 2 + 4 * 2 * 2) * 3)


func test_boulder_meshes() -> void:
	# Report 0005, D-0005-03 and D-0005-05: the near form has 80 triangles, the far form 20.
	for form in 2:
		var mesh := BoulderBuilder.mesh(form)
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		assert_eq(vertices.size(), [80, 20][form] * 3)
		var lowest := INF
		for i in range(0, vertices.size(), 3):
			var a := vertices[i]
			var b := vertices[i + 1]
			var c := vertices[i + 2]
			# The faces point out, and Godot draws the clockwise order as the front.
			assert_gt(normals[i].dot(a + b + c), 0.0, "face %d points out" % (i / 3))
			assert_lt((b - a).cross(c - a).dot(normals[i]), 0.0, "face %d is clockwise from the front" % (i / 3))
			lowest = minf(lowest, minf(a.y, minf(b.y, c.y)))
		assert_almost_eq(lowest, -BoulderBuilder.BASE, 0.001, "the base of the boulder is flat")
