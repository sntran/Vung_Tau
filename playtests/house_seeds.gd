extends RefCounted
# PT-31 house_seeds (plan 0004, R7). Build 50 houses with random seeds and
# parameters. No part goes through another part. No floating part. Each
# house stands on the ground. The houses stand in a row away from the hẻm,
# and the camera takes screenshots of some of them.
# phase: --seed=31

const COUNT := 50
const ROW_X := 300.0


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var root := Node3D.new()
	root.name = "HouseSeeds"
	d.main().add_child(root)
	var houses: Array[TubeHouse] = []
	var x := ROW_X
	for i in COUNT:
		var house := _random_house(rng, i)
		house.position = Vector3(x + house.width / 2.0, 0, 0)
		x += house.width + 1.5
		root.add_child(house)
		houses.append(house)
	var problems := 0
	for house in houses:
		problems += _check(d, house)
	d.expect(problems == 0, "%d houses have no problems: %d problems" % [COUNT, problems])
	# Screenshots of some houses.
	for i in [0, 7, 19, 33, 48]:
		var house := houses[i]
		var h := house.top_height()
		await d.fly_to(house.global_position + Vector3(2.5, h * 0.55, 9.0 + h * 0.5), house.global_position + Vector3(0, h * 0.45, -1.0))
		await d.wait_frames(4)
		await d.screenshot("house_%02d_%s_%s" % [i, house.kind, house.style])
	d.fly_end()


func _random_house(rng: RandomNumberGenerator, i: int) -> TubeHouse:
	var house := TubeHouse.new()
	house.name = "Seed_%d" % i
	house.seed = rng.randi()
	house.kind = ["tube", "tube", "tube", "villa", "hotel"][rng.randi() % 5]
	house.style = "old" if rng.randf() < 0.5 else "new"
	house.width = rng.randf_range(3.5, 5.0)
	house.floors = rng.randi_range(5, 8) if house.kind == "hotel" else rng.randi_range(2, 5)
	house.depth = rng.randf_range(10.0, 14.0)
	house.ground = ["gate", "shop", "wall"][rng.randi() % 3]
	house.balcony = rng.randf() < 0.6
	house.roof = ["", "flat", "metal", "tiles"][rng.randi() % 4] if house.kind == "tube" else ""
	house.front_tiles = ["none", "ground", "full"][rng.randi() % 3]
	var paint := HousePalette.wall(rng)
	house.paint = paint.color
	house.paint_age = rng.randf()
	house.left_neighbor_height = rng.randf_range(0.0, 12.0)
	house.right_neighbor_height = rng.randf_range(0.0, 12.0)
	if house.ground == "shop" or house.kind == "hotel":
		house.sign_text = "KHÁCH SẠN" if house.kind == "hotel" else "CƠM TẤM"
	return house


## Returns the number of problems of one house, and records each one.
func _check(d: PlaytestDriver, house: TubeHouse) -> int:
	var problems := 0
	var where := "%s (seed %d, %s, %s, %d floors, %s)" % [house.name, house.seed, house.kind, house.style, house.floors, house.ground]
	var boxes: Dictionary = house.part_boxes.duplicate()
	for kind: String in HouseParts.KINDS:
		var list := house.parts.boxes(kind)
		for k in list.size():
			boxes["%s_%d" % [kind, k]] = list[k]
	# The house stands on the ground.
	var body: AABB = boxes.get("body", AABB())
	if absf(body.position.y) > 0.01 and not boxes.has("step"):
		d.fail("%s: the house does not stand on the ground: %s" % [where, body])
		problems += 1
	var volume := AABB(Vector3(-house.width / 2.0 - 0.05, -0.01, -house.depth - 0.4),
			Vector3(house.width + 0.1, house.top_height() + 8.0, house.depth + 1.8))
	var names := boxes.keys()
	for i in names.size():
		var a: AABB = boxes[names[i]]
		# No floating part: each part is inside the volume of the house and not under the ground.
		if a.position.y < -0.02 or not volume.encloses(_shrink(a)):
			d.fail("%s: %s %s is outside the house" % [where, names[i], a])
			problems += 1
		# No part goes through another part. The parts that touch the body
		# and the parts of the same kind (the bars of one rail) can touch.
		for j in range(i + 1, names.size()):
			var b: AABB = boxes[names[j]]
			if _may_touch(names[i], names[j]):
				continue
			if _shrink(a).intersects(_shrink(b)):
				d.fail("%s: %s %s goes through %s %s" % [where, names[i], a, names[j], b])
				problems += 1
	return problems


## Pairs of parts that are fixed to each other or to the body.
func _may_touch(a: String, b: String) -> bool:
	var fixed := ["body", "extension", "parapet", "side_left", "side_right", "step"]
	if a in fixed or b in fixed:
		return true
	# A roof stands on its room (D-0004-08).
	if a.begins_with(b + "_") or b.begins_with(a + "_"):
		return true
	var kind_a := a.get_slice("_", 0)
	var kind_b := b.get_slice("_", 0)
	if kind_a == kind_b and kind_a in ["rail", "baluster", "pot", "ac"]:
		return true
	# A rail bar or a baluster stands on its balcony slab; a pot can stand on a balcony.
	var on_balcony := ["rail", "baluster", "pot"]
	if (kind_a == "balcony" and kind_b in on_balcony) or (kind_b == "balcony" and kind_a in on_balcony):
		return true
	# The bars in front of a window go from its sill.
	if (kind_a == "sill" and kind_b == "rail") or (kind_b == "sill" and kind_a == "rail"):
		return true
	return false


## The box 1 cm smaller at each side (a thin box keeps a size of 0).
func _shrink(box: AABB) -> AABB:
	var size := (box.size - Vector3(0.02, 0.02, 0.02)).max(Vector3.ZERO)
	return AABB(box.get_center() - size / 2.0, size)
