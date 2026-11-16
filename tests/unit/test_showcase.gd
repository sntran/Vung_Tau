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
