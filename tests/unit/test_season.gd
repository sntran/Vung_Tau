extends GutTest
## Tests for the seasons of the plants and the roadworks hours (plan 0005, R11a, R12a).


func test_dry_and_rainy_months() -> void:
	for month in [11, 12, 1, 2, 3, 4]:
		assert_eq(Season.name_of(month), "dry", "month %d is in the dry season" % month)
	for month in [5, 6, 7, 8, 9, 10]:
		assert_eq(Season.name_of(month), "rainy", "month %d is in the rainy season" % month)


func test_hills_are_dry_in_the_dry_season_and_green_in_the_rainy_season() -> void:
	assert_gt(Season.dryness(12, 8), 0.4, "day 1 (8 December) has dry hills")
	assert_gt(Season.dryness(3, 15), 0.9, "March is the driest")
	assert_eq(Season.dryness(8, 15), 0.0, "August is green")
	assert_gt(Season.bare_share(2, 15), 0.2, "some hill trees are bare in February")
	assert_eq(Season.bare_share(8, 15), 0.0, "no hill tree is bare in August")


func test_flame_trees_flower_in_may_and_june() -> void:
	assert_gt(Season.flame_flowers(6, 3), 0.9, "full flowers on 3 June")
	assert_gt(Season.flame_flowers(5, 20), 0.8)
	assert_eq(Season.flame_flowers(12, 8), 0.0, "no flowers on day 1")
	assert_lt(Season.flame_leaves(2, 15), 0.5, "few leaves late in the dry season")


func test_values_change_smoothly() -> void:
	var last := Season.dryness(1, 1)
	for day_of_year in range(1, 366):
		var date := Lunar.date_from_jd(Lunar.jd_from_date(1, 1, 2027) + day_of_year)
		var value := Season.dryness(date.month, date.day)
		assert_true(absf(value - last) < 0.05, "no jump on %d/%d" % [date.day, date.month])
		last = value


func test_roadworks_hours() -> void:
	var works := Roadworks.new()
	var path := "user://test_roadworks.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"roadworks": [{
		"road": "Hải Đăng", "from": "bottom", "length_m": 40.0, "width_m": 9.0, "road_width_m": 6.0, "widen_m": 3.0,
		"planned_end": "2027", "contractor": "Công ty thử", "sign": "CÔNG TRÌNH THỬ",
		"work_hours": {"start": "07:00", "lunch": "11:00", "after_lunch": "13:00", "end": "17:00"},
		"points": [[0, 1, 0], [0, 2, -20], [0, 3, -40]]}]}))
	file.close()
	add_child_autofree(works)
	assert_true(works.setup(path))
	assert_false(works.is_working(6 * 60 + 59), "no work before 07:00")
	assert_true(works.is_working(7 * 60), "work at 07:00")
	assert_false(works.is_working(12 * 60), "the lunch break")
	assert_true(works.is_working(13 * 60 + 30), "work after lunch")
	assert_false(works.is_working(17 * 60), "no work at 17:00")
	works.update_time(9 * 60)
	assert_true(works.workers.visible and works.machine.playing, "the workers and the machine at 09:00")
	works.update_time(12 * 60)
	assert_false(works.workers.visible or works.machine.playing, "no workers and no machine at lunch")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
