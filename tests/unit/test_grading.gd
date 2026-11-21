extends GutTest
## The grading of each hour (plan 0026, R13, data/look/grading.json).


func test_each_hour_has_all_the_values() -> void:
	var hours: Array = Grading.data().get("hours", [])
	assert_gt(hours.size(), 2, "the grading has hours")
	var last := -1.0
	for entry: Dictionary in hours:
		assert_gt(float(entry.hour), last, "the hours are in order: %s" % entry.hour)
		last = float(entry.hour)
		for key in Grading.NUMBERS:
			assert_true(entry.has(key), "the hour %s has %s" % [entry.hour, key])
	assert_eq(float(hours[0].hour), 0.0, "the first hour is 0")
	assert_eq(float(hours[hours.size() - 1].hour), 24.0, "the last hour is 24")


func test_values_between_two_hours_are_a_mix() -> void:
	var hours: Array = Grading.data().hours
	var a: Dictionary = hours[1]
	var b: Dictionary = hours[2]
	var middle := (float(a.hour) + float(b.hour)) * 0.5
	var grade := Grading.at(middle * 60.0)
	for key in Grading.NUMBERS:
		assert_almost_eq(float(grade[key]), (float(a[key]) + float(b[key])) * 0.5, 0.0001, key)


func test_the_part_of_a_renderer_adds_its_values() -> void:
	var renderers: Dictionary = Grading.data().get("renderers", {})
	for renderer: String in renderers:
		for minutes: int in [6 * 60, 12 * 60, 17 * 60 + 10, 21 * 60]:
			var plain := Grading.at(minutes)
			var grade := Grading.at(minutes, renderer)
			var part: Dictionary = renderers[renderer]
			var of_hours := Grading._mix(part.get("hours", []), minutes / 60.0)
			for key in Grading.NUMBERS:
				var extra := float(part.get(key, 0.0)) + float(of_hours.get(key, 0.0))
				assert_almost_eq(float(grade[key]), float(plain[key]) + extra, 0.0001, "%s, %d: %s" % [renderer, minutes, key])


func test_the_hours_of_a_renderer_are_0_out_of_them() -> void:
	var hours := [{"hour": 16.0, "saturation": 0.0}, {"hour": 17.0, "saturation": -0.2}, {"hour": 18.0, "saturation": 0.0}]
	assert_almost_eq(float(Grading._mix(hours, 12.0).saturation), 0.0, 0.0001, "before the hours")
	assert_almost_eq(float(Grading._mix(hours, 16.5).saturation), -0.1, 0.0001, "between two hours")
	assert_almost_eq(float(Grading._mix(hours, 17.0).saturation), -0.2, 0.0001, "at an hour")
	assert_almost_eq(float(Grading._mix(hours, 20.0).saturation), 0.0, 0.0001, "after the hours")
	assert_almost_eq(float(Grading._mix(hours, 17.0).exposure), 0.0, 0.0001, "a value that the hours do not give")
	assert_true(Grading._mix([], 17.0).is_empty(), "no hours")


func test_the_shade_of_the_golden_hour_takes_the_blue_of_the_sky() -> void:
	# The presets with no SDFGI (Low, Medium, the Mobile renderer) had an orange
	# frame at 17:10: the ambient light of the twilight is warm (plan 0026, phase 4).
	var golden := Grading.at(17 * 60 + 10, "mobile")
	var noon := Grading.at(12 * 60, "mobile")
	assert_gt(float(golden.ambient_mix), 0.3, "at 17:10 the ambient light takes the blue of the sky")
	assert_almost_eq(float(noon.ambient_mix), 0.0, 0.0001, "at noon the ambient light does not change")
	var blue: Color = golden.ambient_color
	assert_gt(blue.b, blue.r, "the ambient color of the golden hour is blue")
	# The Mobile renderer has no SDFGI: the golden hour has less saturation there,
	# and noon has the values of all renderers.
	assert_lt(float(golden.saturation), float(Grading.at(17 * 60 + 10).saturation), "at 17:10 the Mobile renderer has less saturation")
	assert_almost_eq(float(noon.saturation), float(Grading.at(12 * 60).saturation), 0.0001, "at noon the Mobile renderer has the saturation of the hour")
