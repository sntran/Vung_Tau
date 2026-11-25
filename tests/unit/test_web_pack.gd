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
		assert_false(_matches("assets/world/%s.mid.glb" % id, filters.exclude), "the mid level of %s stays" % id)
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
