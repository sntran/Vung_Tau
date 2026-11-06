extends GutTest
## Tests for the models of World (plan 0023, R5 to R7): the import settings,
## the materials of the roles, the joints, and the axes of each model of
## data/world/orders.json.


func _models() -> Array[String]:
	return WorldModel.ids()


func test_each_order_has_its_files() -> void:
	assert_gt(_models().size(), 0, "orders.json has models")
	for model_id in _models():
		for level in WorldModel.levels_of(model_id):
			var path: String = WorldModel.ROOT + model_id + WorldModel.SUFFIX[level]
			assert_true(ResourceLoader.exists(path), "%s: the %s level is in assets/world/" % [model_id, level])
		assert_true(FileAccess.file_exists(WorldModel.ROOT + model_id + ".parts.json"), "%s: the parts list" % model_id)
		assert_true(FileAccess.file_exists(WorldModel.ROOT + model_id + ".receipt.json"), "%s: the receipt" % model_id)


## R5: no LODs and no shadow meshes of Godot, and the node names stay.
func test_the_import_keeps_the_levels_and_the_names_of_world() -> void:
	for model_id in _models():
		for level in WorldModel.levels_of(model_id):
			var path: String = WorldModel.ROOT + model_id + WorldModel.SUFFIX[level] + ".import"
			var config := ConfigFile.new()
			assert_eq(config.load(path), OK, "%s exists" % path)
			assert_eq(config.get_value("params", "meshes/generate_lods", true), false, "%s: no LODs" % path)
			assert_eq(config.get_value("params", "meshes/create_shadow_meshes", true), false, "%s: no shadow meshes" % path)
			assert_eq(config.get_value("params", "nodes/use_name_suffixes", true), false,
					"%s: no name suffixes (a joint \"front_wheel\" stays a node)" % path)


## R6 and R7: each model loads with the materials of the game, stands on
## y = 0, has the height of its receipt, and a vehicle has its front to +Z.
func test_each_model_loads_with_the_axes_of_gltf() -> void:
	for model_id in _models():
		var model := WorldModel.make(model_id)
		assert_not_null(model, "%s loads" % model_id)
		if model == null:
			continue
		var receipt := model.receipt()
		var size: Array = receipt.get("size", [0.0, 0.0, 0.0])
		for level in WorldModel.levels_of(model_id):
			var box := model.level_aabb(level)
			assert_almost_eq(box.position.y, 0.0, 0.01, "%s %s: the lowest point is at y = 0" % [model_id, level])
			if level == WorldModel.levels_of(model_id)[0]:
				# The receipt has the size of the near level. The mid level of a
				# person is 1 cm to 2 cm shorter at the soles (plan 0023, builder
				# notes): a model with no near level in the game has 2 %.
				var part := 0.01 if level == "near" else 0.02
				assert_almost_eq(box.size.y, float(size[2]), float(size[2]) * part,
						"%s %s: the height is the height of the receipt (%s)" % [model_id, level, size])
		if receipt.get("kind", "") == "vehicle":
			var steer := model.joints_with_role("steer")
			assert_false(steer.is_empty(), "%s: the vehicle steers" % model_id)
			if not steer.is_empty():
				assert_gt(model.joint(steer[0]).position.z, 0.0, "%s: the front (the steering) is to +Z" % model_id)
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var m := node as MeshInstance3D
			for i in m.mesh.get_surface_count():
				assert_not_null(m.get_surface_override_material(i), "%s: %s has a material of the game" % [model_id, m.name])
		model.free()


func test_the_levels_have_the_ranges_of_the_preset() -> void:
	WorldModel.set_ranges("low")
	var model := WorldModel.make("scooter_tay_ga_1")
	var near := model.level("near").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mid := model.level("mid").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var far := model.level("far").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_eq(near.visibility_range_end, 15.0, "Low: the near level to 15 m (R8)")
	assert_eq(mid.visibility_range_begin, 15.0)
	assert_eq(mid.visibility_range_end, 40.0, "Low: the mid level to 40 m")
	assert_eq(far.visibility_range_begin, 40.0)
	model.free()


func test_the_paint_is_the_color_of_the_model() -> void:
	var red := Color("#B0302A")
	var model := WorldModel.make("scooter_tay_ga_1", red)
	var found := false
	for node in model.level("near").find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var material := m.get_surface_override_material(i) as StandardMaterial3D
			if material.resource_name == "paint":
				found = true
				assert_eq(material.albedo_color, red, "the paint of %s" % m.name)
	assert_true(found, "the scooter has paint")
	model.free()


func test_a_role_with_no_material_stops_the_load() -> void:
	var library := WorldMaterials.shared()
	var roles: Dictionary = library.data.roles
	var paint: String = roles.paint
	roles.erase("paint")
	library._cache.clear()
	var model := WorldModel.make("scooter_tay_ga_1")
	assert_null(model, "no model with a role that has no material")
	assert_push_error("the role \"paint\" of the model \"scooter_tay_ga_1\"")
	roles.paint = paint
	library._cache.clear()


func test_set_pose_turns_the_joints_in_their_limits() -> void:
	var model := WorldModel.make("scooter_tay_ga_1")
	var stand := model.joint("stand")
	assert_not_null(stand, "the scooter has a stand")
	var rest := stand.transform
	model.set_pose({"stand": 200.0, "fork": -20.0})
	var turn := rest.basis.inverse() * stand.transform.basis
	assert_almost_eq(rad_to_deg(turn.get_rotation_quaternion().get_angle()), 92.0, 0.01, "the stand stops at its limit of 92°")
	var fork_rest: Transform3D = model.joints.fork.rest.near
	var fork_turn := fork_rest.basis.inverse() * model.joint("fork").transform.basis
	assert_almost_eq(rad_to_deg(fork_turn.get_rotation_quaternion().get_angle()), 20.0, 0.01, "the steering turns 20°")
	var mid_fork: Node3D = model.joints.fork.nodes.get("mid")
	if mid_fork != null:
		assert_ne(mid_fork.transform, model.joints.fork.rest.mid, "the pose is on the mid level too")
	assert_eq(stand.position, rest.origin, "a hinge does not move its node")
	model.free()


func test_parts_come_from_the_parts_list() -> void:
	var model := WorldModel.make("scooter_tay_ga_1")
	var names := model.parts().map(func(p: Dictionary) -> String: return p.name)
	assert_true(names.has("tire_80_90_14"), "the parts of the scooter: %s" % [names])
	model.free()


## Plan 0009, R7a: the 12 roles of a house are at most 6 materials.
func test_a_house_merges_its_roles_into_six_materials() -> void:
	var library := WorldMaterials.shared()
	var roles := ["plaster", "brick_ong", "tile_granite", "tile_pattern", "metal_shutter", "iron", "aluminum",
			"roof_corrugated", "roof_clay", "concrete", "glass", "wood"]
	var materials := {}
	for role in roles:
		var material_name := library.material_name(role, "house")
		assert_ne(material_name, "", "the house role %s has a material" % role)
		assert_false(library.values(material_name, "house").is_empty(), "the material %s has values" % material_name)
		materials[material_name] = true
	assert_lte(materials.size(), 6, "the house materials: %s" % [materials.keys()])
	assert_eq(library.material_name("aluminum"), "aluminum", "outside a house, a role keeps its own material")


func test_each_role_of_the_palette_of_world_has_a_material() -> void:
	var library := WorldMaterials.shared()
	for role in ["paint", "glass", "tire", "skin", "hair", "cloth", "clothes_shirt", "color_hair", "eyes", "collision"]:
		var material_name := library.material_name(role)
		assert_ne(material_name, "", "%s has a material" % role)


## R12: the credits name the commit of the lock.
func test_the_credits_name_the_commit_of_the_lock() -> void:
	var lock: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/lock.json"))
	var commit: String = lock.world.commit
	assert_eq(commit.length(), 40, "the lock has a commit")
	assert_true(FileAccess.get_file_as_string("res://assets/CREDITS.md").contains(commit), "assets/CREDITS.md names the commit %s" % commit)
	assert_true(FileAccess.get_file_as_string("res://data/credits.json").contains(commit), "the Credits sheet names the commit %s" % commit)
	assert_true(FileAccess.get_file_as_string("res://data/credits.json").contains("AGPL-3.0"), "the Credits sheet names the license")


## R8: a row puts its models in cells of MultiMeshes, with the paint of each model.
func test_a_row_has_cells_of_multimeshes() -> void:
	var row := WorldRow.new()
	var red := Color("#B0302A")
	for i in 5:
		row.add("scooter_tay_ga_1", Transform3D(Basis(), Vector3(i * 1.0, 0, 0)), red, {"fork": 20.0})
	row.add("scooter_tay_ga_1", Transform3D(Basis(), Vector3(20.0, 0, 0)), Color.WHITE)
	row.build()
	assert_eq(row.count(), 6)
	assert_eq(row.cells.size(), 2, "two cells of %.0f m" % WorldRow.CELL)
	var cell: Dictionary = row.cells[0]
	assert_gt(cell.near.size(), 0, "the near level has MultiMeshes")
	assert_gt(cell.mid.size(), 0, "the mid level has MultiMeshes")
	assert_eq(cell.impostor.size(), 1, "one MultiMesh of impostor cards")
	var card: MultiMeshInstance3D = cell.impostor[0]
	assert_eq(card.multimesh.instance_count, 5)
	var b := card.multimesh.buffer
	assert_almost_eq(Vector3(b[12], b[13], b[14]), Vector3(red.r, red.g, red.b), Vector3.ONE * 0.001, "the paint of the first model")
	assert_eq((card.material_override if card.material_override else card.multimesh.mesh.surface_get_material(0)).shader.resource_path,
			WorldRow.SHADER)
	WorldModel.set_ranges("low")
	row.apply_ranges()
	var near: MultiMeshInstance3D = cell.near[0]
	assert_eq(near.visibility_range_end, 15.0)
	assert_eq(card.visibility_range_begin, 40.0)
	assert_eq(WorldRow.level_at(20.0), "mid")
	assert_eq(WorldRow.level_at(50.0), "impostor")
	row.free()


## R9a: a parked scooter: 10° to 30° from the curb, the stand on the ground.
func test_a_parked_scooter_stands_at_an_angle_to_the_curb() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 20:
		var angle := Parked.pick_angle(rng)
		assert_between(angle, 10.0, 30.0)
		var t := Parked.transform(Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD, angle)
		var front := t.basis.z.normalized()
		assert_almost_eq(rad_to_deg(front.angle_to(Vector3.RIGHT)), angle, 0.01, "the angle to the curb")
		assert_lt(front.z, 0.0, "the front turns to the street")
	assert_between(Parked.pick_angle(rng, Parked.PARALLEL_ANGLE), 0.0, 5.0, "parallel in a narrow hẻm (Q9)")
	var stand := Parked.stand_angle()
	assert_between(stand, 45.0, 92.0, "the stand is down: %.0f°" % stand)
	var pose := Parked.pose(rng)
	assert_gte(absf(pose.fork), Parked.MIN_STEER, "the front wheel is turned")
	assert_gt(Parked.colors().size(), 4, "the colors of the scooters")
