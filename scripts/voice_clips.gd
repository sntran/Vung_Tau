class_name VoiceClips
extends RefCounted
## The voice clips of the dialogue (plan 0003, R4 to R6). This is the same
## list and the same hash as tools/voices/build.py.
##
## A clip is a spoken line of a person (ID = the line ID), a phrase of the
## phrasebook in the neutral phone voice ("reply.LINE.REPLY"), or the "say
## again" phrase for a person ("say_again.SPEAKER"). A line with a form of
## address (plan 0007, R11) has one clip for each variant that the rules can
## make for its speaker: "ID@KEY", where KEY is the resolved words (Address.key()).

const FOLDER := "res://assets/voices/"


static func path(clip_id: String) -> String:
	return FOLDER + clip_id + ".ogg"


## The clip ID of a variant: "ID@KEY", or the ID when the key is empty.
static func variant_id(clip_id: String, variant_key: String) -> String:
	return clip_id if variant_key == "" else "%s@%s" % [clip_id, variant_key]


static func reply_id(line_id: String, reply_id_value: String) -> String:
	return "reply.%s.%s" % [line_id, reply_id_value]


static func say_again_id(speaker_id: String) -> String:
	return "say_again." + speaker_id


static func model_version(voices: Dictionary) -> String:
	return "%s %s" % [voices.get("model", ""), voices.get("package", "")]


## The hash of a clip: the text that the voice reads, the voice, and the model version.
static func clip_hash(text: String, voice: String, model: String) -> String:
	return ("%s\n%s\n%s" % [text, voice, model]).sha256_text()


## The text that the voice reads: the style tag, then "say" or "vi".
static func spoken_text(line: Dictionary) -> String:
	var text: String = line.get("say", line.get("vi", ""))
	var style: String = line.get("voice_style", "")
	return "%s %s" % [style, text] if style != "" else text


## Returns all clips: a list of {id, text, voice, hash}. "address" is
## data/address.json: a line with a form of address has a clip for each of
## its variants.
static func expected(dialogue: Dictionary, voices: Dictionary, address: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var model := model_version(voices)
	var speaker_voices: Dictionary = voices.get("speakers", {})
	var phone: String = voices.get("phone", "")
	var lines: Dictionary = dialogue.get("lines", {})
	for line_id: String in lines:
		var line: Variant = lines[line_id]
		if typeof(line) != TYPE_DICTIONARY or not line.has("speaker"):
			continue
		var voice: String = speaker_voices.get(line.speaker, "")
		_add_variants(result, line_id, line, line.speaker, address, voice, model, true)
		for reply: Variant in line.get("replies", []):
			if typeof(reply) == TYPE_DICTIONARY and not reply.get("english", false) and reply.has("vi"):
				_add_variants(result, reply_id(line_id, reply.get("id", "")), reply, line.speaker, address, phone, model, false)
	var say_again: Dictionary = dialogue.get("say_again", {})
	for speaker_id: String in dialogue.get("speakers", {}):
		_add_variants(result, say_again_id(speaker_id), say_again, speaker_id, address, phone, model, false)
	return result


## The clips of the variants of a line, a reply, or the "say again" phrase
## for the person "speaker_id", in the order of Address.all_words().
static func _add_variants(result: Array[Dictionary], clip_id: String, item: Dictionary, speaker_id: String,
		address: Dictionary, voice: String, model: String, styled: bool) -> void:
	var fields := Address.line_fields(item)
	if fields.is_empty():
		result.append(_clip(clip_id, spoken_text(item) if styled else str(item.get("vi", "")), voice, model))
		return
	var seen := {}
	for words: Dictionary in Address.all_words(address, speaker_id):
		var variant_key := Address.key(words, fields)
		if seen.has(variant_key):
			continue
		seen[variant_key] = true
		var resolved := Address.resolve_line(address, item, words)
		var text := spoken_text(resolved) if styled else str(resolved.get("vi", ""))
		result.append(_clip(variant_id(clip_id, variant_key), text, voice, model))


static func _clip(clip_id: String, text: String, voice: String, model: String) -> Dictionary:
	return {"id": clip_id, "text": text, "voice": voice, "hash": clip_hash(text, voice, model)}
