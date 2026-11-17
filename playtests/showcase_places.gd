extends RefCounted
# PT-71 showcase_places (plan 0026, D3, R7). Each model of World of
# data/world/places/bai_truoc.json stands on the ground (its base within
# 0.1 m of the ground at its front and at the corners of its front), on its
# lot (its front at the point of the data), with its front to its street (the
# nearest point of the street of the place is in front of it), and no two
# models overlap. The test also
# counts the parts of the showcase (data/showcase/bai_truoc.json), checks that
# the basket boats of the sea are models of World (R8), and takes a
# screenshot of each model from its street. Report 0026, D-0026-03: on the side
# of the hill of Hạ Long, each footprint of public data near the road has a
# stand-in with its storeys from a photo, or is in the list of the footprints
# that wait for one (Check); no stand-in has a guessed number of storeys.
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
## The side of the hill of Hạ Long (D-0026-03): the footprints this near the road,
## between these z (from Cao ốc Sen Biển to Hải Âu).
const HILL_SIDE_M := 70.0
const HILL_SIDE_Z := Vector2(330.0, 520.0)


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
	_check_models(d, w)
	_check_hill_side(d, w)
	for kind: String in ["median", "sidewalk", "path_border", "wall", "sea_wall", "stand_ins", "lawn_m2", "paving_m2",
			"planter", "beach_wall", "median_trees", "lamps", "path_lamps"]:
		d.expect(float(w.showcase.lengths.get(kind, 0.0)) > 0.0, "the showcase has the part %s" % kind)
	# R8: the basket boats of the sea are the thúng chai of World.
	d.expect(w.sea_objects != null and w.sea_objects.world_baskets == w.sea_objects.baskets.size(),
			"each basket boat of the sea is a model of World: %d of %d" % [
				w.sea_objects.world_baskets if w.sea_objects else 0, w.sea_objects.baskets.size() if w.sea_objects else 0])
	# R8 and Q10: the moored fishing boats are the ghe of World, with the eyes on the bow.
	d.expect(w.sea_objects != null and w.sea_objects.world_boats == w.sea_objects.boats.size() and w.sea_objects.boats.size() > 0,
			"each fishing boat of the bay is the ghe of World: %d of %d" % [
				w.sea_objects.world_boats if w.sea_objects else 0, w.sea_objects.boats.size() if w.sea_objects else 0])
	await _boat_view(d, w)
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
		# A thing on the walk with no street of its own (a raised lawn: "along" in
		# the data) has no front to a street.
		if not place.has("street"):
			d.step("%s is along %s: no street to look to" % [entry.id, place.get("along", "?")])
			d.expect(place.has("along"), "%s names its street, or the walk that it is along" % entry.id)
			continue
		var facing := Vector2((t.basis * Vector3.BACK).x, (t.basis * Vector3.BACK).z).normalized()
		var road := _nearest_road(w, Vector3(middle.x, 0, middle.z), str(place.street))
		d.expect(road != Vector2.INF, "%s has its street %s in the roads" % [entry.id, place.street])
		if road == Vector2.INF:
			continue
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


## Report 0026, D-0026-03: the side of the hill of Hạ Long is not bare. Each
## footprint of data/geo/build/footprints.json (public data, Overture Maps) near
## the road has a stand-in with its storeys from a photo, or is listed in
## stand_ins.footprints_check of data/showcase/bai_truoc.json with its reason;
## each stand-in has its storeys from a source.
func _check_hill_side(d: PlaytestDriver, w: VungTau) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/geo/build/footprints.json"))
	if not d.expect(parsed is Dictionary, "the footprints of public data can be read (tools/geo/footprints.py)"):
		return
	var road := PackedVector3Array()
	for entry: Dictionary in w.data.roads:
		if str(entry.get("name", "")) == "Hạ Long":
			for p: Array in entry.points:
				if float(p[2]) > HILL_SIDE_Z.x - HILL_SIDE_M and float(p[2]) < HILL_SIDE_Z.y + HILL_SIDE_M:
					road.append(Vector3(float(p[0]), 0.0, float(p[2])))
	var built := {}
	for entry: Dictionary in w.showcase.stand_ins:
		d.expect(bool(entry.known), "the stand-in %s has its storeys from a source" % entry.osm)
		built[str(entry.osm)] = true
	var check_ids: Array = w.showcase.data.stand_ins.get("footprints_check", {}).get("ids", [])
	var near := 0
	var with_building := 0
	var missing: Array[String] = []
	for footprint: Dictionary in parsed.get("footprints", []):
		if "OpenStreetMap" in (footprint.get("sources", []) as Array):
			continue
		var middle := Vector2.ZERO
		var outline: Array = footprint.outline
		for p: Array in outline:
			middle += Vector2(float(p[0]), float(p[1])) / outline.size()
		if middle.y < HILL_SIDE_Z.x or middle.y > HILL_SIDE_Z.y:
			continue
		var gap := INF
		for q in road:
			gap = minf(gap, Vector2(q.x, q.z).distance_to(middle))
		if gap > HILL_SIDE_M:
			continue
		near += 1
		if built.has("footprint/" + str(footprint.id)):
			with_building += 1
		elif not str(footprint.id) in check_ids:
			missing.append(str(footprint.id))
	d.step("the side of the hill of Hạ Long: %d footprints near the road, %d with a stand-in, %d wait for their storeys (Check), %d OSM buildings with no storeys left out" % [
			near, with_building, near - with_building - missing.size(), w.showcase.stand_ins_left_out.size()])
	d.expect(missing.is_empty(), "each footprint near Hạ Long has a stand-in or waits for its storeys with a reason: %s" % ", ".join(missing))


## Report 0026, D-0026-08 and D-0026-09: each plain part of the showcase (the
## lamps, the raised lawns, the low wall of the beach, the sea wall of Hạ Long)
## names the model that I make for it with the tools of World, and the model is
## in data/world/drawings/. The game shows the model when its order is in
## data/world/orders.json, and a stand-in until then.
func _check_models(d: PlaytestDriver, w: VungTau) -> void:
	var data: Dictionary = w.showcase.data
	var named: Array[String] = []
	for kind: String in data.get("lamp_kinds", {}):
		if kind != "note":
			named.append(str(data.lamp_kinds[kind].get("model", "lamp " + kind)))
	for id: Variant in data.ground.planters.get("models", {"the raised lawns": "the raised lawns"}).values():
		named.append(str(id))
	for wall: Dictionary in data.get("walls", []):
		named.append(str(wall.get("model", "the low wall")))
	for wall: Dictionary in data.get("sea_walls", []):
		for id: String in wall.get("models", ["the sea wall"]):
			named.append(id)
	var missing: Array[String] = []
	var used: Array[String] = []
	for id in named:
		if not FileAccess.file_exists("res://data/world/drawings/%s.json" % id):
			missing.append(id)
		elif not WorldModel.order(id).is_empty():
			used.append(id)
	d.step("the plain parts and their models: %s; in the game as models of World: %s" % [", ".join(named), ", ".join(used)])
	d.expect(missing.is_empty(), "each plain part of the showcase names its model in data/world/drawings/: %s" % ", ".join(missing))


## Q10: the ghe of World in the bay, near (its mid level) and far (its far level).
func _boat_view(d: PlaytestDriver, w: VungTau) -> void:
	if w.sea_objects == null or w.sea_objects.boats.is_empty():
		return
	# The boat nearest to the sea wall of Hạ Long.
	var best: Dictionary = w.sea_objects.boats[0]
	for boat: Dictionary in w.sea_objects.boats:
		var p: Array = boat.position
		var q: Array = best.position
		if Vector2(float(p[0]), float(p[1])).distance_to(Vector2(-150.0, 380.0)) < Vector2(float(q[0]), float(q[1])).distance_to(Vector2(-150.0, 380.0)):
			best = boat
	var at := Vector3(float(best.position[0]), w.sea_level + 1.0, float(best.position[1]))
	# The eyes are on the sea side of the boat, and look back to it and to the shore.
	var out := Vector3(at.x + 150.0, 0.0, at.z - 380.0).normalized()
	for view: Array in [["boat_near", 22.0, 4.0], ["boat_far", 160.0, 12.0]]:
		var eye := at + out * float(view[1]) + Vector3(0.0, float(view[2]), 0.0)
		await d.fly_to(eye, at)
		await d.wait_ground(60.0)
		await d.wait_frames(6)
		await d.screenshot(str(view[0]))
	d.fly_end()
