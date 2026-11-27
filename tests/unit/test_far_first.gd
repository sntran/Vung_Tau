extends GutTest
## Plan 0031, D14 and R14: the far levels first. While the pack "models" is not
## there, a model of World has only its far level, and it shows from 0 m (no
## hole); when the pack comes, each model and each cell of a row gets its mid
## level. On a computer WebPacks.simulate() keeps the files of a pack out.

## A thing of World with a near, a mid, and a far level, in the pack "models".
const THING := "ghe_danh_ca"


func before_each() -> void:
	WebPacks.simulate(["models"])


func after_each() -> void:
	WebPacks.simulate([])


func test_the_pack_models_has_the_mid_and_near_levels_of_the_things() -> void:
	var files: Array = WebPacks.entries().models.files
	assert_has(files, WorldModel.ROOT + THING + ".mid.glb")
	assert_does_not_have(files, WorldModel.ROOT + THING + ".far.glb", "the far level stays in the start pack")
	assert_does_not_have(files, WorldModel.ROOT + Parked.MODEL + ".mid.glb", "the scooter that the player rides stays whole")
	assert_does_not_have(files, WorldModel.ROOT + "walker_1.mid.glb", "the people have a pack of their own")


func test_a_model_has_only_its_far_level_while_the_pack_is_not_there() -> void:
	assert_eq(WorldModel.levels_of(THING), ["far"] as Array[String])
	WebPacks.release("models")
	assert_true(WorldModel.levels_of(THING).has("mid"), "the mid level when the pack is there")


func test_a_model_shows_its_far_level_from_0_m_and_then_its_mid_level() -> void:
	var model := WorldModel.make(THING)
	add_child_autofree(model)
	var far: Node3D = model.level("far")
	assert_not_null(far)
	assert_null(model.level("mid"))
	var g := far.find_children("*", "GeometryInstance3D", true, false)[0] as GeometryInstance3D
	assert_eq(g.visibility_range_begin, 0.0, "the far level shows from 0 m: no hole")
	WebPacks.release("models")
	# The files load in other threads first: upgrade() is false while they load.
	var frames := 0
	while not model.upgrade() and frames < 600:
		await wait_frames(1)
		frames += 1
	assert_false(model.missing_levels(), "the model gets its better levels")
	assert_not_null(model.level("mid"))
	assert_gt((far.find_children("*", "GeometryInstance3D", true, false)[0] as GeometryInstance3D).visibility_range_begin, 0.0,
			"the far level shows only past the mid level")


func test_a_row_shows_a_level_from_0_m_and_then_its_mid_level() -> void:
	var row := WorldRow.new()
	add_child_autofree(row)
	row.add(THING, Transform3D.IDENTITY)
	row.build()
	assert_eq(row.cells.size(), 1)
	assert_true(_shows_at(row, 0.5), "the cell shows a level at 0.5 m: no hole")
	assert_false(row.needs_upgrade(), "no better level yet")
	WebPacks.release("models")
	assert_true(row.needs_upgrade(), "the cell waits for its better levels")
	# D18: the files of the model load first (in other threads), then the cell changes.
	var frames := 0
	while row.needs_upgrade() and frames < 600:
		if not row.upgrade_next():
			await wait_frames(1)
		frames += 1
	assert_true(_shows_at(row, 0.5))
	# A model with no near level shows its mid level from 0 m ("mid_whole").
	assert_gt(row.cells[0].mid.size() + row.cells[0].mid_whole.size(), 0, "the cell has its mid level")
	assert_eq(row.cells[0].far_whole.size(), 0, "the far level does not show from 0 m any more")


## True when a node of the row shows at the distance (its visibility range).
static func _shows_at(row: WorldRow, distance: float) -> bool:
	for node in row.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if g.visible and g.visibility_range_begin <= distance and (g.visibility_range_end == 0.0 or g.visibility_range_end > distance):
			return true
	return false
