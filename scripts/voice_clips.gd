class_name VoiceClips
extends RefCounted
## The voice clips of the dialogue (plan 0003, R4 to R6). This is the same
## list and the same hash as tools/voices/build.py.
##
## A clip is a spoken line of a person (ID = the line ID), a phrase of the
## phrasebook in the neutral phone voice ("reply.LINE.REPLY"), or the "say
## again" phrase for a person ("say_again.SPEAKER").

const FOLDER := "res://assets/voices/"


static func path(clip_id: String) -> String:
	return FOLDER + clip_id + ".ogg"


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


## The "say again" phrase with the form of address of the speaker (R20).
static func say_again_text(dialogue: Dictionary, speaker_id: String) -> String:
	var speaker: Dictionary = dialogue.get("speakers", {}).get(speaker_id, {})
	return str(dialogue.get("say_again", {}).get("vi", "")).replace("{address}", speaker.get("address", ""))


## Returns all clips: a list of {id, text, voice, hash}.
static func expected(dialogue: Dictionary, voices: Dictionary) -> Array[Dictionary]:
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
		result.append(_clip(line_id, spoken_text(line), voice, model))
		for reply: Variant in line.get("replies", []):
			if typeof(reply) == TYPE_DICTIONARY and not reply.get("english", false) and reply.has("vi"):
				result.append(_clip(reply_id(line_id, reply.get("id", "")), reply.vi, phone, model))
	for speaker_id: String in dialogue.get("speakers", {}):
		result.append(_clip(say_again_id(speaker_id), say_again_text(dialogue, speaker_id), phone, model))
	return result


static func _clip(clip_id: String, text: String, voice: String, model: String) -> Dictionary:
	return {"id": clip_id, "text": text, "voice": voice, "hash": clip_hash(text, voice, model)}
