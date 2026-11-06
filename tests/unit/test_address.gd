extends GutTest
## The forms of address (plan 0007, R7 to R11): the cases of address_cases.json.

const CASES_PATH := "res://tests/unit/address_cases.json"
const DATA_PATH := "res://data/address.json"

var _cases: Dictionary
var _data: Dictionary


func before_all() -> void:
	_cases = JSON.parse_string(FileAccess.get_file_as_string(CASES_PATH))
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


func test_each_row_and_role_rule() -> void:
	for case: Dictionary in _cases.words:
		var traveler := {"gender": case.gender, "age": int(case.age)}
		var words := Address.words(_data, case.person, traveler)
		var label := "%s, %s %d (%s)" % [case.person, case.gender, int(case.age), case.row]
		for field: String in Address.FIELDS:
			assert_eq(words[field], case[field], "%s: %s" % [label, field])
		assert_eq(Address.display_name(_data, case.person, traveler), case.name, "%s: display name" % label)


func test_fields_and_capital_letters() -> void:
	for case: Dictionary in _cases.fill:
		assert_eq(Address.fill(case.text, case.words), case.result)


func test_dear() -> void:
	for case: Dictionary in _cases.english:
		assert_eq(Address.fill_english(_data, case.text, case.words), case.result)


func test_variant_keys() -> void:
	for case: Dictionary in _cases.keys:
		var fields: Array[String] = []
		fields.assign(case.fields)
		var ordered: Array[String] = []
		for field: String in Address.FIELDS:
			if fields.has(field):
				ordered.append(field)
		assert_eq(Address.key(case.words, ordered), case.result)


func test_the_default_traveler_keeps_the_words_of_plan_0003() -> void:
	# R4: a man of 30 before the passport. The lines of plan 0003 had these words.
	var traveler: Dictionary = _data.traveler.default
	assert_eq(Address.words(_data, "batu", traveler).you, "con")
	assert_eq(Address.words(_data, "cosau", traveler).you, "con")
	assert_eq(Address.words(_data, "bacha", traveler).you, "cháu")
	assert_eq(Address.words(_data, "cout", traveler).you, "anh")
	assert_eq(Address.words(_data, "nga", traveler).you, "con")


func test_each_person_has_words_for_each_traveler() -> void:
	for person_id: String in _data.people:
		for gender: String in ["male", "female"]:
			for age in range(int(_data.traveler.min_age), int(_data.traveler.max_age) + 1):
				var words := Address.words(_data, person_id, {"gender": gender, "age": age})
				for field: String in Address.FIELDS:
					assert_ne(str(words[field]), "", "%s, %s %d: %s" % [person_id, gender, age, field])


func test_variants_of_a_line() -> void:
	var line := {"vi": "Dạ, {self} cảm ơn {them}.", "en": "Thank you.",
			"variants": [{"when": {"them": "em"}, "vi": "Cảm ơn {them}."}]}
	assert_eq(Address.line_fields(line), ["them", "self"] as Array[String])
	var young := Address.resolve_line(_data, line, {"you": "anh", "me": "em", "them": "em", "self": "anh"})
	assert_eq(young.vi, "Cảm ơn em.")
	var old := Address.resolve_line(_data, line, {"you": "con", "me": "cô", "them": "cô", "self": "con"})
	assert_eq(old.vi, "Dạ, con cảm ơn cô.")
	assert_false(old.has("variants"))
