extends RefCounted
# PT-71 showcase_places (plan 0026, D3, R7). Each model of World of
# data/world/places/bai_truoc.json stands on the ground (its base within
# 0.1 m of the ground at its front and at the corners of its front), on its
# lot (its front at the point of the data), with its front to its street (the
# nearest point of the street of the place is in front of it), and no two
# models overlap. The test also
# counts the parts of the showcase (data/showcase/bai_truoc.json), checks that
# the basket boats of the sea are models of World (R8), and takes a
# screenshot of each model from its street.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=10:00 --quality=low

const PLACES := "res://data/world/places/bai_truoc.json"
## The base of a model and the ground under its front.
const MAX_BASE_GAP := 0.1
## The corners of the front that the test measures are this far inside the sides.
const CORNER_INSET := 2.0
## The front of a model and the point of the data.
const MAX_FRONT_GAP := 0.5
## The front looks to the nearest road: the cosine of the angle.
const MIN_FACING := 0.9
## Two footprints can touch: a common area of this much or less is no overlap.
const MAX_COMMON_M2 := 0.5


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.showcase != null, "the Vũng Tàu world has the showcase"):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACES))
	if not d.expect(parsed is Dictionary, "%s can be read" % PLACES):
		return
	var data: Dictionary = {}
	for place: Dictionary in parsed.places:
		data[str(place.id)] = place
	var models: Array[Dictionary] = w.showcase.models
	d.expect(models.size() == data.size(), "each place has its model: %d of %d" % [models.size(), data.size()])
	d.step("the parts of the showcase (m, or a count): %s" % [w.showcase.lengths])
	for kind: String in ["median", "sidewalk", "path_border", "wall", "sea_wall", "stand_ins", "lawn_m2", "paving_m2",
			"planter", "beach_wall", "median_trees", "lamps", "path_lamps"]:
		d.expect(float(w.showcase.lengths.get(kind, 0.0)) > 0.0, "the showcase has the part %s" % kind)
	# R8: the basket boats of the sea are the thúng chai of World.
	d.expect(w.sea_objects != null and w.sea_objects.world_baskets == w.sea_objects.baskets.size(),
			"each basket boat of the sea is a model of World: %d of %d" % [
				w.sea_objects.world_baskets if w.sea_objects else 0, w.sea_objects.baskets.size() if w.sea_objects else 0])
	for entry: Dictionary in models:
		var model: WorldModel = entry.model
		var place: Dictionary = data.get(entry.id, {})
		var box: AABB = entry.box
		var t := model.transform
		# The front of the model: its middle and its two corners (z = 0 in the model).
		var middle := t * Vector3(float(place.get("front_middle_x", 0.0)), 0, 0)
		# The corners one cell of the grid (2 m) inside the sides: two neighbors
		# can have two levels, and the ground between two cells mixes their heights.
		var corners := [t * Vector3(box.position.x + CORNER_INSET, 0, 0), t * Vector3(box.end.x - CORNER_INSET, 0, 0)]
		var gaps := []
		for p: Vector3 in [middle] + corners:
			gaps.append(absf(w.ground_height(p.x, p.z) - t.origin.y))
		var worst: float = gaps.max()
		d.expect(worst <= MAX_BASE_GAP, "%s stands on the ground: the base is %.2f m from the ground at its front (at most %.2f)" % [
				entry.id, worst, MAX_BASE_GAP])
		var front := Vector2(float(place.front[0]), float(place.front[1]))
		var off := Vector2(middle.x, middle.z).distance_to(front)
		d.expect(off <= MAX_FRONT_GAP, "%s is on its lot: its front is %.2f m from the point of the data" % [entry.id, off])
		var facing := Vector2((t.basis * Vector3.BACK).x, (t.basis * Vector3.BACK).z).normalized()
		var road := _nearest_road(w, Vector3(middle.x, 0, middle.z), str(place.get("street", "")))
		var to_road := (road - Vector2(middle.x, middle.z)).normalized()
		d.expect(facing.dot(to_road) >= MIN_FACING, "%s looks to its street: cos %.2f (at least %.2f)" % [
				entry.id, facing.dot(to_road), MIN_FACING])
	for i in models.size():
		for j in range(i + 1, models.size()):
			var common := 0.0
			for part: PackedVector2Array in Geometry2D.intersect_polygons(_body(models[i]), _body(models[j])):
				common += absf(_area(part))
			d.expect(common <= MAX_COMMON_M2, "%s and %s do not overlap: %.1f m² in common" % [
					models[i].id, models[j].id, common])
	# A screenshot of each model from its street, 25 m in front of it.
	for entry: Dictionary in models:
		var t: Transform3D = entry.model.transform
		var middle := t * Vector3(float(data[entry.id].get("front_middle_x", 0.0)), 0, 0)
		var out := t.basis * Vector3.BACK
		var eye := middle + out * 25.0
		eye.y = w.ground_height(eye.x, eye.z) + Player.EYE_HEIGHT
		await d.fly_to(eye, middle + Vector3(0, 6.0, 0))
		await d.wait_ground(60.0)
		await d.wait_frames(6)
		await d.screenshot(str(entry.id))
	d.fly_end()


## The point of the nearest car road (not a footway) to the point, as (x, z):
## of the street with the name, when the place gives its street.
static func _nearest_road(w: VungTau, p: Vector3, street := "") -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for road: Dictionary in w.data.roads:
		if str(road.type) in ["footway", "pedestrian", "path", "steps", "service", "track"]:
			continue
		if street != "" and str(road.name) != street:
			continue
		var points: Array = road.points
		for i in points.size() - 1:
			var a := Vector3(points[i][0], 0, points[i][2])
			var b := Vector3(points[i + 1][0], 0, points[i + 1][2])
			var q := Geometry3D.get_closest_point_to_segment(Vector3(p.x, 0, p.z), a, b)
			var dist := Vector2(q.x - p.x, q.z - p.z).length()
			if dist < best_d:
				best_d = dist
				best = Vector2(q.x, q.z)
	return best


## The footprint of the body of a model: the part behind its front (z <= 0).
static func _body(entry: Dictionary) -> PackedVector2Array:
	var box: AABB = entry.box
	var t: Transform3D = entry.model.transform
	var result := PackedVector2Array()
	for c: Vector3 in [Vector3(box.position.x, 0, box.position.z), Vector3(box.end.x, 0, box.position.z),
			Vector3(box.end.x, 0, 0), Vector3(box.position.x, 0, 0)]:
		var p := t * c
		result.append(Vector2(p.x, p.z))
	return result


static func _area(ring: PackedVector2Array) -> float:
	var result := 0.0
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		result += a.x * b.y - b.x * a.y
	return result / 2.0
