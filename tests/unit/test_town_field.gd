extends GutTest
## Plan 0009, phase 2 (R6): the boxes of the town. Report 0009, D-0009-13: a
## building in the area of the showcase keeps its box when no model, no
## stand-in, and no part that a player walks on covers it.


func _square(x: float, z: float, size: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, z), Vector2(x + size, z), Vector2(x + size, z + size), Vector2(x, z + size)])


func _kept_part(ring: PackedVector2Array) -> Array:
	var box := Rect2(ring[0], Vector2.ZERO)
	var middle := Vector2.ZERO
	for p in ring:
		box = box.expand(p)
		middle += p / ring.size()
	return [ring, box, middle]


func _middle(ring: PackedVector2Array) -> Vector2:
	var middle := Vector2.ZERO
	for p in ring:
		middle += p / ring.size()
	return middle


func test_a_building_with_no_model_and_no_stand_in_has_a_box() -> void:
	var building := _square(0, 0, 10)
	var model := _kept_part(_square(40, 0, 20))
	var nothing_walks := func(_p: Vector2) -> bool: return false
	assert_false(TownField.is_left_out(building, _middle(building), [model], nothing_walks),
			"a building of the area of the showcase that nothing draws keeps its box")
	assert_false(TownField.is_left_out(building, _middle(building), []), "with no kept part and no walk")


func test_a_model_or_a_stand_in_on_the_building_leaves_its_box_out() -> void:
	var building := _square(0, 0, 10)
	assert_true(TownField.is_left_out(building, _middle(building), [_kept_part(_square(-1, -1, 12))]),
			"a stand-in that covers the whole outline")
	assert_true(TownField.is_left_out(building, _middle(building), [_kept_part(_square(3, 3, 4))]),
			"a model that stands in the outline (its middle is in it)")
	# A model that covers 20 % of the outline at its side, with its middle out of it.
	assert_false(TownField.is_left_out(building, _middle(building), [_kept_part(_square(8, 0, 10))]),
			"a part that covers 20 % of the outline")
	assert_true(TownField.is_left_out(building, _middle(building), [_kept_part(_square(6, 0, 10))]),
			"a part that covers 40 % of the outline")


func test_a_walk_on_the_outline_leaves_its_box_out() -> void:
	var building := _square(0, 0, 10)
	var paving_west := func(p: Vector2) -> bool: return p.x < 5.0
	assert_true(TownField.is_left_out(building, _middle(building), [], paving_west), "paving on half of the outline")
	var paving_edge := func(p: Vector2) -> bool: return p.x < 2.0
	assert_false(TownField.is_left_out(building, _middle(building), [], paving_edge), "paving on 20 % of the outline")
