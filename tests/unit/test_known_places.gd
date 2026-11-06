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
	# The landing at the turn: a tread of LANDING_M at x = 20.
	var landing := treads.filter(func(t: Dictionary) -> bool:
		return Vector2(t.to.x - t.from.x, t.to.z - t.from.z).length() >= KnownPlaces.LANDING_M * 0.49 \
				and absf(t.from.x - 20.0) < 1.0)
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
