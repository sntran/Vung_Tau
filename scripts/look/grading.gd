class_name Grading
extends RefCounted
## The beauty pass of the Vũng Tàu world (plan 0026, R13): the exposure, the
## color adjustment, the warmth of the sun, the sky, the bloom, and the haze for
## each hour, from data/look/grading.json. The values between two hours are a
## mix of the two. The part of the renderer adds its values.

const PATH := "res://data/look/grading.json"
const NUMBERS: Array[String] = ["exposure", "saturation", "contrast", "sun_warmth", "sky_mix", "glow", "haze"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"hours": []}
	return _data


## The values at the clock time (minutes after midnight) for the renderer
## ("mobile", "forward_plus", or "gl_compatibility"). Empty with no data.
static func at(minutes: float, renderer := "") -> Dictionary:
	var hours: Array = data().get("hours", [])
	if hours.is_empty():
		return {}
	var hour := fposmod(minutes / 60.0, 24.0)
	var before: Dictionary = hours[0]
	var after: Dictionary = hours[hours.size() - 1]
	for i in hours.size() - 1:
		if float(hours[i].hour) <= hour and hour <= float(hours[i + 1].hour):
			before = hours[i]
			after = hours[i + 1]
			break
	var span := float(after.hour) - float(before.hour)
	var t := (hour - float(before.hour)) / span if span > 0.0 else 0.0
	var result := {}
	var extra: Dictionary = data().get("renderers", {}).get(renderer, {})
	for key in NUMBERS:
		result[key] = lerpf(float(before.get(key, 0.0)), float(after.get(key, 0.0)), t) + float(extra.get(key, 0.0))
	for key: String in ["sun_color", "sky_top", "sky_horizon", "haze_color"]:
		result[key] = Color(str(data().get(key, "#FFFFFF")))
	return result
