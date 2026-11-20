extends GutTest
## Tests for the showcase of Bãi Trước (plan 0026): the helpers of its parts.


## R9: a tree that leans tilts to its direction (degrees from +Z to +X).
func test_a_leaning_tree_tilts_to_its_direction() -> void:
	var up := StreetTrees.lean(30.0, 90.0) * Vector3.UP
	assert_almost_eq(up.x, sin(deg_to_rad(30.0)), 0.001)
	assert_almost_eq(up.y, cos(deg_to_rad(30.0)), 0.001)
	assert_almost_eq(up.z, 0.0, 0.001)
	var back := StreetTrees.lean(10.0, 0.0) * Vector3.UP
	assert_gt(back.z, 0.0, "a direction of 0 degrees is +Z")


## R9: the trees and the lamps of the median stand at a distance from the ends of each run.
func test_things_along_a_line_keep_off_its_ends() -> void:
	var line := PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0), Vector3(10, 0, 10)])
	var points := Showcase._every(line, 5.0, 2.0)
	# The line is 20 m long: at 2, 7, 12, and 17 m, none after 18 m.
	assert_eq(points.size(), 4)
	assert_almost_eq((points[1][0] as Vector3).x, 7.0, 0.001)
	assert_almost_eq((points[2][0] as Vector3).z, 2.0, 0.001)
	assert_almost_eq((points[2][1] as Vector3).z, 1.0, 0.001, "the direction of the second segment")
	assert_eq(Showcase._every(line, 0.0, 2.0).size(), 0, "no spacing, no points")


## Report 0026, D-0026-23 (audit 5): the autocorrelation length of PT-72 grows
## with the size of the patches (crowns of 4 px against caps of 16 px), and a
## fine noise of 2 px on large patches does not make it small.
func test_the_autocorrelation_length_is_the_size_of_the_patches() -> void:
	var shots: Script = load("res://playtests/showcase_shots.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lengths := {}
	for cell: int in [4, 16]:
		var image := Image.create(128, 64, false, Image.FORMAT_RGB8)
		var values := {}
		for y in 64:
			for x in 128:
				var key := Vector2i(x / cell, y / cell)
				if not values.has(key):
					values[key] = rng.randf()
				image.set_pixel(x, y, Color.from_hsv(0.3, 0.5, 0.2 + 0.6 * float(values[key])))
		lengths[cell] = shots.correlation_length(image, [0.0, 0.0, 1.0, 1.0])
		if cell == 16:
			var noisy := image.duplicate() as Image
			for y in 64:
				for x in 128:
					var c := noisy.get_pixel(x, y)
					var f := 0.75 + 0.5 * float(rng.randf() < 0.5) if (x / 2 + y / 2) % 2 == 0 else 1.0
					noisy.set_pixel(x, y, Color(c.r * f, c.g * f, c.b * f))
			lengths["noisy"] = shots.correlation_length(noisy, [0.0, 0.0, 1.0, 1.0])
	assert_lt(float(lengths[4]), 4.0, "patches of 4 px")
	assert_gt(float(lengths[16]), 1.5 * float(lengths[4]), "patches of 16 px are more than 1.5 times longer")
	assert_gt(float(lengths["noisy"]), 1.5 * float(lengths[4]), "a fine noise does not hide large patches")
