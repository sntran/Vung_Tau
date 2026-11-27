extends GutTest
## Plan 0031, R2 and R3 (step 1): the web pack leaves out the near level of
## each building of World, data/geo/raw, and the files of the build that the
## game does not read; the JSON of the build is there as gzip copies, and the
## game reads them as the JSON on a computer.

const PRESETS := "res://export_presets.cfg"
const WEB := "res://data/web/web.json"


func _web_filters() -> Dictionary:
	var config := ConfigFile.new()
	assert_eq(config.load(PRESETS), OK, "export_presets.cfg reads")
	for section in config.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options") and config.get_value(section, "name", "") == "Web":
			return {"include": str(config.get_value(section, "include_filter", "")).split(", "),
					"exclude": str(config.get_value(section, "exclude_filter", "")).split(", ")}
	return {}


func _matches(path: String, patterns: PackedStringArray) -> bool:
	for pattern in patterns:
		if path.match(pattern):
			return true
	return false


func _web() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(WEB))


## Each building of World is in data/web/web.json: a model with a place and a
## near file, a model of the blueprint "building", or a tube house of plan 0009.
func test_each_building_is_in_the_list() -> void:
	var buildings: Array = _web().buildings
	var places: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/places/bai_truoc.json"))
	for place: Dictionary in places.places:
		var model_id := str(place.get("model", place.get("id", "")))
		if FileAccess.file_exists(WorldModel.ROOT + model_id + ".glb.import"):
			assert_has(buildings, model_id, "the building with a place %s" % model_id)
	for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(WorldModel.ORDERS)).models:
		var id := str(entry.id)
		var blueprint: Variant = entry.order.get("blueprint", "")
		if (blueprint is String and blueprint == "building") or id.begins_with("nha_ong"):
			assert_has(buildings, id, "the building %s" % id)


## R2: the preset Web leaves out the near level of each building and the raw
## data, and it has the JSON of the build only as gzip copies.
func test_the_web_preset_leaves_out_the_files_of_step_1() -> void:
	var filters := _web_filters()
	assert_false(filters.is_empty(), "export_presets.cfg has the preset Web")
	for id: String in _web().buildings:
		assert_true(_matches("assets/world/%s.glb" % id, filters.exclude), "the near level of %s is out of the web pack" % id)
		# D14: the mid level is in the main pack, or in the pack "models".
		var mid := "assets/world/%s.mid.glb" % id
		assert_true(not _matches(mid, filters.exclude) or WebPacks.entries().models.files.has("res://" + mid),
				"the mid level of %s stays in the web build" % id)
	assert_true(_matches("data/geo/raw/osm.json", filters.exclude), "data/geo/raw is out of the web pack")
	assert_true(_matches("data/geo/build/roads.json", filters.exclude), "the JSON of the build is out")
	assert_true(_matches("data/geo/build/roads.json.gz", filters.include), "its gzip copy is in")
	assert_true(_matches("data/geo/build/town/0_0.json.gz", filters.include), "the gzip copies of the town are in")
	assert_false(_matches("data/geo/build/roads.json.gz", filters.exclude), "the gzip copy is not out")


## R3: a gzip copy (made by Python, as tools/web/prepare.py makes it) reads
## as its JSON; a file that is there reads as it is.
func test_the_game_reads_a_gzip_copy() -> void:
	var text := GeoData.read_text("res://tests/data/web/sample.json")
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "the copy reads as JSON: %s" % text)
	assert_eq(str(parsed.roads[0].name), "Quang Trung")
	assert_true(GeoData.has_file("res://tests/data/web/sample.json"), "has_file() finds the copy")
	assert_false(GeoData.has_file("res://tests/data/web/none.json"))
	assert_eq(GeoData.read_text(WEB), FileAccess.get_file_as_string(WEB), "a JSON file reads as it is")


## D5 (step 2): each file of a pack of data/web/packs.json is a resource of
## the project, and the preset Web leaves it out of the main pack.
func test_the_files_of_the_packs_are_out_of_the_main_pack() -> void:
	var filters := _web_filters()
	var packs: Dictionary = WebPacks.entries()
	assert_true(packs.has("people"), "data/web/packs.json has the pack people")
	for pack_id: String in packs:
		var files: Array = packs[pack_id].files
		assert_gt(files.size(), 0, "the pack %s has files" % pack_id)
		for file: String in files:
			assert_true(ResourceLoader.exists(file), "the file %s of the pack %s is in the project" % [file, pack_id])
			assert_true(_matches(file.trim_prefix("res://"), filters.exclude), "the file %s is out of the main pack" % file)


## R4: the people of the showcase and of the morning exercise come in the pack
## people, with their mid and far levels, and its area has the showcase.
func test_the_people_are_in_their_pack() -> void:
	var files: Array = WebPacks.entries().people.files
	var ids: Array = []
	for group: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(MorningExercise.PATH)).groups:
		ids.append(group.leader)
		ids.append_array(group.people)
	var people: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ShowcasePeople.PATH))
	for kind: String in ["walkers", "sitters", "swimmers"]:
		ids.append_array(people[kind].models)
	for id: String in ids:
		if not (id.begins_with("aerobics_") or id.begins_with("walker_") or id.begins_with("sitter_") or id.begins_with("swimmer_")):
			continue
		for level: String in ["mid", "far"]:
			assert_has(files, "%s%s.%s.glb" % [WorldModel.ROOT, id, level], "the %s level of %s is in the pack people" % [level, id])
	var area: Array = WebPacks.entries().people.area
	var outline: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/showcase/bai_truoc.json")).outline
	for p: Array in outline:
		assert_true(float(p[0]) >= float(area[0]) and float(p[0]) <= float(area[2]) and float(p[1]) >= float(area[1]) and float(p[1]) <= float(area[3]),
				"the point %s of the showcase is in the area of the pack people" % [p])


## On a computer (one whole pack) no pack waits.
func test_no_pack_waits_on_a_computer() -> void:
	assert_false(WebPacks.waiting("people"))
	var called := [false]
	WebPacks.when_ready("people", func() -> void: called[0] = true)
	assert_true(called[0], "when_ready() calls at once")


## D13 (R13): the pictures of the people stay compressed: each scene of the
## pack people imports its pictures as Basis Universal (docs/web/load.md).
func test_the_pictures_of_the_people_import_as_basis_universal() -> void:
	for file: String in WebPacks.entries().people.files:
		var cfg := ConfigFile.new()
		assert_eq(cfg.load(file + ".import"), OK, "%s.import reads" % file)
		assert_eq(int(cfg.get_value("params", "gltf/embedded_image_handling", -1)), 2,
				"%s imports its pictures as Basis Universal" % file)


## Plan 0031, D16 (report 0031, D-0031-03): the builds before D15 wrote each
## pack to user://packs/, and the browser reads all of user:// into memory at
## each start. The game removes that folder; the packs now stay in the cache of
## the page (D15).
func test_the_game_removes_the_packs_of_old_builds_from_user() -> void:
	DirAccess.make_dir_recursive_absolute(WebPacks.OLD_PACKS)
	var file := FileAccess.open(WebPacks.OLD_PACKS.path_join("people.pck"), FileAccess.WRITE)
	file.store_string("old pack")
	file.close()
	WebPacks.remove_old_packs()
	assert_false(DirAccess.dir_exists_absolute(WebPacks.OLD_PACKS), "user://packs/ is gone")
	WebPacks.remove_old_packs()
	assert_false(DirAccess.dir_exists_absolute(WebPacks.OLD_PACKS), "a second call does nothing")


## Plan 0031, R18 (round 4): the measure of a pack counts the frames after
## "can move" only. The first frame after it ended a frame of the start (with
## the work of the start in it): it does not count.
func test_the_measure_of_a_pack_starts_with_the_frame_after_can_move() -> void:
	var packs := WebPacks.new(null)
	packs._measured["models"] = 0.0
	WebPacks.playing = false
	packs._measure_frame(0.0)
	OS.delay_msec(150)
	WebPacks.playing = true
	packs._measure_frame(0.0)
	assert_eq(float(packs._measured["models"]), 0.0, "the last frame of the start does not count")
	OS.delay_msec(30)
	packs._measure_frame(0.0)
	assert_between(float(packs._measured["models"]), 25.0, 140.0, "the next frame counts")
	packs.free()
