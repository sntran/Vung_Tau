extends RefCounted
# PT-86 far_first (plan 0031, D14, R14). The web build gets the mid and near
# levels of the models of World in the pack "models" after the first frame.
# On a computer --packs-sim keeps that pack out until 30 s after the first
# frame. While it is out, each model of World and each cell of a row near the
# start of Bãi Trước shows a level at its distance (no hole); after the pack
# is there, each model and each cell within 40 m shows its mid level (or its
# near level), and no upgrade waits there. Screenshots: the street with the far
# levels, and the same view with the better levels.
# sizes: 1280x720
# phase: --world=vung_tau --start=bai_truoc --start-time=09:00 --quality=low --packs-sim=30

const NEAR_M := 150.0
const MID_M := 40.0


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	await d.wait_showcase()
	var player: Player = d.main().player
	var at := player.global_position
	var far_only := 0
	var holes: Array = []
	for node in d.main().get_tree().get_nodes_in_group(WorldModel.GROUP):
		var model := node as WorldModel
		var distance := model.global_position.distance_to(at)
		if distance > NEAR_M or not model.is_visible_in_tree():
			continue
		if WorldModel.order(model.id).get("levels", []).size() > 1 and model.level("mid") == null and model.level("near") == null:
			far_only += 1
		# A model shows to its far end (a lamp of the paths has a short one), or to the range of the preset.
		var r: Vector3 = model.custom_ranges.get(WorldModel.preset, WorldModel.ranges)
		var end := model.far_end if model.far_end > 0.0 else r.z
		if distance < end and not _shows(model, distance):
			holes.append("%s at %.0f m" % [model.id, distance])
	var cells := 0
	for node in d.main().get_tree().get_nodes_in_group(WorldRow.GROUP):
		var row := node as WorldRow
		if row == null:
			continue
		for entry: Dictionary in row.cells:
			var cell := entry.node as Node3D
			var distance := cell.global_position.distance_to(at)
			if distance > NEAR_M or not row.is_visible_in_tree():
				continue
			cells += 1
			var r: Vector3 = row.custom_ranges.get(WorldModel.preset, WorldModel.ranges)
			if distance < r.z and not _shows(cell, distance):
				holes.append("%s/%s at %.0f m" % [row.name, cell.name, distance])
	d.step("before the pack: %d models with only their far level, %d cells within %.0f m" % [far_only, cells, NEAR_M])
	d.expect(far_only > 0, "the pack \"models\" is out: some models have only their far level")
	d.expect(holes.is_empty(), "each model and each cell near the start shows a level (no hole): %s" % [holes.slice(0, 8)])
	await d.screenshot("far_levels")
	# The pack comes 30 s after the first frame (game time), then the upgrades, nearest first.
	await d.wait_until(func() -> bool: return not WebPacks.waiting("models") and WebPacks.upgrades_within(at, MID_M) == 0, 120.0,
			"the pack models is there and the upgrades within %.0f m are done" % MID_M)
	var no_mid: Array = []
	for node in d.main().get_tree().get_nodes_in_group(WorldModel.GROUP):
		var model := node as WorldModel
		if model.global_position.distance_to(at) > MID_M or not model.is_visible_in_tree():
			continue
		if model.missing_levels():
			no_mid.append(model.id)
	for node in d.main().get_tree().get_nodes_in_group(WorldRow.GROUP):
		var row := node as WorldRow
		if row == null:
			continue
		for index in row.cells.size():
			var cell := row.cells[index].node as Node3D
			if cell.global_position.distance_to(at) <= MID_M and row.cell_needs_upgrade(index):
				no_mid.append("%s/%s" % [row.name, cell.name])
	d.expect(no_mid.is_empty(), "after the pack each model and cell within %.0f m has its mid level: %s" % [MID_M, no_mid.slice(0, 8)])
	await d.screenshot("better_levels")


## True when a geometry of the node shows at the distance (its visibility range).
static func _shows(root: Node, distance: float) -> bool:
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var begin := g.visibility_range_begin - g.visibility_range_begin_margin
		var end := g.visibility_range_end + g.visibility_range_end_margin
		if begin <= distance and (g.visibility_range_end <= 0.0 or end >= distance):
			return true
	return false
