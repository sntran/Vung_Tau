class_name Grading
extends RefCounted
## The beauty pass of the Vũng Tàu world (plan 0026, R13): the exposure, the
## color adjustment, the warmth of the sun, the sky, the ambient light, the
## bloom, and the haze for each hour, from data/look/grading.json. The values
## between two hours are a mix of the two. The part of the renderer adds its
## values. The ambient light is for the presets with no SDFGI (Low, Medium, and
## the Mobile renderer): SDFGI does not use it.

const PATH := "res://data/look/grading.json"
const NUMBERS: Array[String] = ["exposure", "saturation", "contrast", "sun_warmth", "sky_mix", "ambient_mix", "glow", "haze",
		"sea_mix"]

## The gloss of shaders/water.gdshader before the grading.
const SEA_ROUGHNESS := 0.06
const SEA_SPECULAR := 0.6

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
	var result := _mix(hours, hour)
	# The part of the renderer: values for all hours, and values for some hours
	# (its own "hours", 0 out of them).
	var extra: Dictionary = data().get("renderers", {}).get(renderer, {})
	var extra_hours: Dictionary = _mix(extra.get("hours", []), hour)
	for key in NUMBERS:
		result[key] = float(result[key]) + float(extra.get(key, 0.0)) + float(extra_hours.get(key, 0.0))
	for key: String in ["sun_color", "sky_top", "sky_horizon", "ambient_color", "haze_color", "sea_deep", "sea_shallow"]:
		result[key] = Color(str(data().get(key, "#FFFFFF")))
	# The gloss of the sea (report 0026, D-0026-06), with the part sea_mix of the hour.
	result["sea_roughness"] = float(data().get("sea_roughness", SEA_ROUGHNESS))
	result["sea_specular"] = float(data().get("sea_specular", SEA_SPECULAR))
	return result


## The values of a table of hours at an hour: a mix of the two hours around it.
## A value that an hour does not give is 0. Empty with no hours.
static func _mix(hours: Array, hour: float) -> Dictionary:
	if hours.is_empty():
		return {}
	var before: Dictionary = hours[0]
	var after: Dictionary = hours[hours.size() - 1]
	if hour <= float(before.hour):
		after = before
	elif hour >= float(after.hour):
		before = after
	else:
		for i in hours.size() - 1:
			if float(hours[i].hour) <= hour and hour <= float(hours[i + 1].hour):
				before = hours[i]
				after = hours[i + 1]
				break
	var span := float(after.hour) - float(before.hour)
	var t := (hour - float(before.hour)) / span if span > 0.0 else 0.0
	var result := {}
	for key in NUMBERS:
		result[key] = lerpf(float(before.get(key, 0.0)), float(after.get(key, 0.0)), t)
	return result
