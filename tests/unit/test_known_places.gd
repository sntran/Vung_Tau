extends GutTest
## PT-59 landmark_data (plan 0008, R1): each place of data/geo/landmarks.json
## has its fields, a source for each size, and a status. A place with "Check"
## has no model and no stand-in. The stairs have steps of 15 cm to 18 cm and a
## landing at each turn (R6).


func _records() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/geo/build/landmarks.json"))
	var result := {}
	for record: Dictionary in parsed.get("landmarks", []):
		result[record.id] = record
	return result


func test_each_place_has_its_fields_and_sources() -> void:
	var entries := KnownPlaces.configs()
	assert_gt(entries.size(), 6, "the places of plan 0008")
	var problems := KnownPlaces.check(entries, _records())
	assert_eq(problems, [] as Array[String], "the place records: %s" % [problems])
	for id in ["chua_kito_vua", "hai_dang", "bach_dinh", "duc_me_bai_dau", "mieu_hon_ba", "cau_da"]:
		assert_true(entries.has(id), "%s is a place" % id)
		assert_ne(str(entries[id].place.status), "Check", "%s has sizes with sources" % id)
	for id in ["chua_tam_bao", "nha_tho_vung_tau", "tuong_tran_hung_dao"]:
		assert_eq(str(entries[id].place.status), "Check", "%s waits for the sources of its sizes (Q1, Q2)" % id)


func test_the_check_finds_the_problems() -> void:
	var records := {"a": {"found": true, "position": [0.0, 0.0]}, "b": {"found": true, "position": [0.0, 0.0]}}
	var entries := {
		"a": {"place": {"status": "Check", "name_en": "A", "kind": "statue", "model": {"blueprint": "statue"}}},
		"b": {"place": {"status": "Source", "name_en": "B", "kind": "tower", "sizes": {"height": {"value": 18.0, "source": ""}},
				"lens": {"phrase_vi": "x", "phrase_en": "x", "text": "x"}}},
	}
	var problems := KnownPlaces.check(entries, records)
	assert_true(problems.any(func(p: String) -> bool: return p.contains("Check has a model")), "%s" % [problems])
	assert_true(problems.any(func(p: String) -> bool: return p.contains("Check has a stand-in")), "%s" % [problems])
	assert_true(problems.any(func(p: String) -> bool: return p.contains("height has no source")), "%s" % [problems])


func test_the_statue_has_the_sizes_of_the_sources() -> void:
	var place: Dictionary = KnownPlaces.configs().chua_kito_vua.place
	assert_eq(float(place.sizes.figure_height.value), 32.0)
	assert_eq(float(place.sizes.arm_span.value), 18.4)
	assert_eq(int(place.sizes.steps_from_road.value), 811)
	var record: Dictionary = _records().chua_kito_vua
	assert_true(record.has("base_height"), "the build made the ground level under the plaza (R2)")


func test_the_stairs_have_steps_of_15_to_18_cm_and_landings() -> void:
	# A line up 6 m in 20 m, a turn of 90°, then up 3 m in 10 m.
	var line := PackedVector3Array([Vector3(0, 0, 0), Vector3(20, 6, 0), Vector3(20, 9, 10)])
	var profile := KnownPlaces.stair_profile(line)
	var treads: Array = profile.treads
	assert_gt(int(profile.steps), 40)
	var heights: Array[float] = []
	for t: Dictionary in treads:
		heights.append(float(t.height))
	var rises: Array[float] = []
	for i in range(1, heights.size()):
		var r := absf(heights[i] - heights[i - 1])
		if r > 0.001:
			rises.append(r)
	for r in rises:
		assert_between(r, KnownPlaces.STEP_MIN - 0.001, KnownPlaces.STEP_MAX + 0.001, "a step is 15 cm to 18 cm")
	assert_almost_eq(heights[-1], 9.0, 0.01, "the stairs end at the top")
	# The landing at the turn: one tread covers LANDING_M round the corner at x = 20.
	var half := KnownPlaces.LANDING_M / 2.0
	var landing := treads.filter(func(t: Dictionary) -> bool:
		return t.from.z < 0.01 and t.from.x <= 20.0 - half + 0.01 and absf(t.to.x - 20.0) < 0.01 and t.to.z >= half - 0.01)
	assert_false(landing.is_empty(), "a landing at the turn")


## The faces of a box face out: Godot draws only the front of a face, so a box
## with its faces in the other order shows its inside (the deck of the jetty).
func test_a_box_has_its_faces_to_the_outside() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	KnownPlaces._add_box(st, {"center": Vector3(1, 2, 3), "size": Vector3(4, 1, 2), "turn": 0.7, "tilt": 0.1})
	st.generate_normals()
	var arrays := st.commit_to_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_eq(vertices.size(), 36)
	for i in range(0, vertices.size(), 3):
		var middle := (vertices[i] + vertices[i + 1] + vertices[i + 2]) / 3.0
		var face := (vertices[i + 2] - vertices[i]).cross(vertices[i + 1] - vertices[i])
		assert_gt(face.dot(middle - Vector3(1, 2, 3)), 0.0, "triangle %d faces out" % (i / 3))
		assert_gt(normals[i].dot(middle - Vector3(1, 2, 3)), 0.0, "the normal of triangle %d points out" % (i / 3))


## A short flight between two turns has steps of 15 cm to 18 cm too (PT-61
## found a step of 14 cm on the way 788327915).
func test_a_short_flight_has_steps_in_the_range() -> void:
	var line := PackedVector3Array([Vector3(0, 0, 0), Vector3(4, 0.25, 0), Vector3(4, 0.25, 4), Vector3(14, 3.3, 4)])
	var profile := KnownPlaces.stair_profile(line)
	var walk: PackedVector3Array = profile.walk
	for i in range(1, walk.size()):
		var r := absf(walk[i].y - walk[i - 1].y)
		if r > 0.001:
			assert_between(r, KnownPlaces.STEP_MIN - 0.001, KnownPlaces.STEP_MAX + 0.001, "the step %d is 15 cm to 18 cm" % i)
	assert_almost_eq(walk[walk.size() - 1].y, 3.3, 0.01, "the stairs end at the top")


## floor_at() gives the height of the nearest part of the stairs, not of the
## steps farther up within the width of the stairs.
func test_the_floor_of_stairs_is_the_nearest_step() -> void:
	var places := KnownPlaces.new()
	var walk := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0.6, 0), Vector3(2, 1.2, 0)])
	places.stairs.append({"way": 1, "place": "a", "points": walk, "steps": 0, "width": 2.0})
	assert_almost_eq(places.floor_at(0.5, 0.5), 0.3, 0.001, "the floor in the middle of the first part")
	assert_almost_eq(places.floor_at(1.0, 0.0), 0.6, 0.001, "the floor at a joint")
	assert_eq(places.floor_at(0.5, 3.0), -INF, "no floor out of the width")
	places.free()


## The ramp on the noses of the steps is never steeper than the player can walk
## (40°): a tread is 28 cm or more in a straight line, also at a bend (PT-61
## found a part of 44°).
func test_the_walk_line_of_stairs_is_not_too_steep() -> void:
	var line := PackedVector3Array()
	for i in 40:
		# A line that bends 25° at each point (no landing), up 0.8 m in each meter.
		var a := deg_to_rad(25.0) * float(i)
		var p := Vector3.ZERO if line.is_empty() else line[line.size() - 1]
		line.append(p + Vector3(cos(a) * 0.5, 0.4, sin(a) * 0.5) if i > 0 else p)
	var walk: PackedVector3Array = KnownPlaces.stair_profile(line).walk
	for i in range(1, walk.size()):
		var flat := Vector2(walk[i].x - walk[i - 1].x, walk[i].z - walk[i - 1].z).length()
		var rise := absf(walk[i].y - walk[i - 1].y)
		if rise > 0.001:
			assert_lt(rad_to_deg(atan2(rise, flat)), 40.0, "the part %d of the walk line" % i)


## The faces of a prism face out, and its top faces up (the plaza, the base,
## and the dome of the statue showed their inside), for a polygon in each order.
func test_a_prism_has_its_faces_to_the_outside() -> void:
	for points: PackedVector2Array in [KnownPlaces.ring_points(Vector2(3, 4), 2.0, 8),
			PackedVector2Array([Vector2(0, 0), Vector2(0, 2), Vector2(3, 2), Vector2(3, 0)])]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		KnownPlaces._prism(st, points, 1.0, 3.0)
		var arrays := st.commit_to_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var middle := Vector3.ZERO
		for p in points:
			middle += Vector3(p.x, 2.0, p.y) / points.size()
		for i in range(0, vertices.size(), 3):
			var center := (vertices[i] + vertices[i + 1] + vertices[i + 2]) / 3.0
			var face := (vertices[i + 2] - vertices[i]).cross(vertices[i + 1] - vertices[i])
			assert_gt(face.dot(center - middle), 0.0, "triangle %d faces out" % (i / 3))
