class_name Address
extends RefCounted
## The forms of address (plan 0007, R6 to R11). The rules are in
## data/address.json. tools/voices/address.py has the same rules for the
## voices build: tests/unit/address_cases.json checks both.
##
## For a person and the traveler ({gender, age}), the rules give four words:
## "you" (what the person calls the traveler), "me" (what the person calls
## themself), "them" (what the traveler calls the person), and "self" (what
## the traveler calls themself). The functions are static and use no nodes.

const FIELDS := ["you", "me", "them", "self"]
const MAX_DEPTH := 8
## The Vietnamese letters and their ASCII letters, for the clip keys (R11).
const VIETNAMESE := "àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ"
const ASCII := "aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD"


## The words for the person and the traveler: {you, me, them, self}. An
## unknown person gets the words of the first general rule that agrees.
static func words(data: Dictionary, person_id: String, traveler: Dictionary) -> Dictionary:
	var person: Dictionary = data.get("people", {}).get(person_id, {})
	var rule := rule_for(data, person_id, traveler)
	var result := {}
	for field: String in FIELDS:
		result[field] = word(data, str(rule.get(field, "")), person, traveler)
	return result


## The first rule that agrees with the person and the traveler, or {}.
static func rule_for(data: Dictionary, person_id: String, traveler: Dictionary) -> Dictionary:
	var person: Dictionary = data.get("people", {}).get(person_id, {})
	var person_age := int(person.get("age", 0))
	var traveler_age := int(traveler.get("age", 30))
	var difference := person_age - traveler_age
	for rule: Dictionary in data.get("rules", []):
		if rule.has("person") and str(rule.person) != person_id:
			continue
		if rule.has("role") and str(rule.role) != str(person.get("role", "")):
			continue
		if rule.has("min") and difference < int(rule.min):
			continue
		if rule.has("max") and difference > int(rule.max):
			continue
		if rule.has("min_person_age") and person_age < int(rule.min_person_age):
			continue
		if rule.has("max_person_age") and person_age > int(rule.max_person_age):
			continue
		if rule.has("min_traveler_age") and traveler_age < int(rule.min_traveler_age):
			continue
		if rule.has("max_traveler_age") and traveler_age > int(rule.max_traveler_age):
			continue
		return rule
	return {}


## A value of a rule: a word, or a class of "classes" that gives the word by
## the gender or the region of the person or of the traveler. A person can
## replace a class with a word of their own.
static func word(data: Dictionary, value: String, person: Dictionary, traveler: Dictionary) -> String:
	var classes: Dictionary = data.get("classes", {})
	var result := value
	for i in MAX_DEPTH:
		if not classes.has(result):
			return result
		if person.has(result):
			result = str(person[result])
			continue
		var word_class: Dictionary = classes[result]
		match str(word_class.get("by", "")):
			"person_gender":
				result = str(word_class.get(str(person.get("gender", "male")), ""))
			"person_region":
				result = str(word_class.get(str(person.get("region", "south")), ""))
			"traveler_gender":
				result = str(word_class.get(str(traveler.get("gender", "male")), ""))
			"person":
				result = str(person.get(str(word_class.get("field", "")), ""))
			_:
				return ""
	return result


## The text with the fields of R9 replaced: {you}, {me}, {them}, {self}, and
## the capital letter forms {You}, {Me}, {Them}, {Self}.
static func fill(text: String, resolved: Dictionary) -> String:
	var result := text
	for field: String in FIELDS:
		var value := str(resolved.get(field, ""))
		result = result.replace("{%s}" % field, value)
		result = result.replace("{%s}" % field.capitalize(), capital(value))
	return result


## The English text with {dear}: "dear" for the words of data.dear, else
## empty, with the comma or the space before it (R9).
static func fill_english(data: Dictionary, text: String, resolved: Dictionary) -> String:
	var dear: Dictionary = data.get("dear", {})
	if str(resolved.get("you", "")) in dear.get("words", []):
		return text.replace("{dear}", str(dear.get("text", "dear")))
	return text.replace(", {dear}", "").replace(" {dear}", "").replace("{dear}", "")


## The word with a capital first letter: "con" to "Con".
static func capital(value: String) -> String:
	if value == "":
		return value
	return value.substr(0, 1).to_upper() + value.substr(1)


## The display name of a person for the traveler (R8): the traveler's word
## for the person and the given name ("Cô Sáu", "Chị Sáu"), or the name that
## the neighbors use when the word is in "keep_name" ("Cô Út").
static func display_name(data: Dictionary, person_id: String, traveler: Dictionary) -> String:
	var person: Dictionary = data.get("people", {}).get(person_id, {})
	if person.is_empty():
		return ""
	var them := str(words(data, person_id, traveler).them)
	if them == "" or them in data.get("display_name", {}).get("keep_name", []):
		return str(person.get("name", ""))
	return "%s %s" % [capital(them), str(person.get("given", ""))]


## The fields of R9 in the texts, in the order of FIELDS (the capital forms count too).
static func fields_in(texts: Array) -> Array[String]:
	var result: Array[String] = []
	for field: String in FIELDS:
		for text: Variant in texts:
			var value := str(text)
			if value.contains("{%s}" % field) or value.contains("{%s}" % field.capitalize()):
				result.append(field)
				break
	return result


## The fields that the voice of a line (or a reply) depends on: the fields
## in its Vietnamese texts and in the conditions of its variants.
static func line_fields(line: Dictionary) -> Array[String]:
	var texts: Array = [line.get("vi", ""), line.get("say", "")]
	var when_fields := {}
	for variant: Variant in line.get("variants", []):
		if typeof(variant) != TYPE_DICTIONARY:
			continue
		texts.append(variant.get("vi", ""))
		texts.append(variant.get("say", ""))
		for field: Variant in variant.get("when", {}):
			when_fields[str(field)] = true
	var result := fields_in(texts)
	for field: String in FIELDS:
		if when_fields.has(field) and not result.has(field):
			result.append(field)
	var ordered: Array[String] = []
	for field: String in FIELDS:
		if result.has(field):
			ordered.append(field)
	return ordered


## The key of a variant (R11): the resolved words of the fields, in ASCII,
## joined with "-". For example "con", or "con-co". Empty with no field.
static func key(resolved: Dictionary, fields: Array[String]) -> String:
	var parts := PackedStringArray()
	for field: String in fields:
		parts.append(ascii(str(resolved.get(field, ""))))
	return "-".join(parts)


static func ascii(text: String) -> String:
	var result := ""
	for i in text.length():
		var letter := text[i]
		var at := VIETNAMESE.find(letter)
		result += ASCII[at] if at >= 0 else letter
	return result


## The texts of a line for the words: "vi", "say", and "en" of the first
## variant whose "when" agrees, else of the line, with the fields filled.
static func resolve_line(data: Dictionary, line: Dictionary, resolved: Dictionary) -> Dictionary:
	var result := line.duplicate()
	result.erase("variants")
	for variant: Variant in line.get("variants", []):
		if typeof(variant) != TYPE_DICTIONARY:
			continue
		var agrees := true
		for field: Variant in variant.get("when", {}):
			if str(resolved.get(str(field), "")) != str(variant.when[field]):
				agrees = false
				break
		if agrees:
			for text_key: String in ["vi", "say", "en"]:
				if variant.has(text_key):
					result[text_key] = variant[text_key]
			if variant.has("vi") and not variant.has("say"):
				result.erase("say")
			break
	for text_key: String in ["vi", "say", "text"]:
		if result.has(text_key):
			result[text_key] = fill(str(result[text_key]), resolved)
	if result.has("en"):
		result.en = fill_english(data, str(result.en), resolved)
	return result


## All the different words that the rules can give for the person, for each
## gender and each age of the traveler (R11). The list is in a fixed order.
static func all_words(data: Dictionary, person_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	var limits: Dictionary = data.get("traveler", {})
	for gender: String in ["male", "female"]:
		for age in range(int(limits.get("min_age", 18)), int(limits.get("max_age", 80)) + 1):
			var resolved := words(data, person_id, {"gender": gender, "age": age})
			var id := "/".join(PackedStringArray([resolved.you, resolved.me, resolved.them, resolved.self]))
			if not seen.has(id):
				seen[id] = true
				result.append(resolved)
	return result
