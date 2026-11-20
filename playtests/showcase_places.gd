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
# Report 0026, D-0026-11: a scan of each edge of a part that a player walks on
# (the sidewalks, the median, the walk of Hạ Long): every 0.5 m, a ray down on
# the top of the part and a ray down just out of it. A step of more than
# 0.25 m (the step of the player) with no way round it fails: a run of such
# steps longer than 5 m along an edge (a player who meets a shorter one goes
# round it in 2.5 m or less; the ledge of D-0026-11 was about 300 m long). A
# wall is not a step (the outside is more than 1 m higher: the face of a
# building), and nor is a thing on the part (more than 0.3 m over the edge:
# the closed end of the walk, the foot of a lamp). D-0026-16: the base line of
# each low wall along the beach is smooth (the top of its pieces is one line):
# its grade is at most MAX_WALL_GRADE, and the grade changes by at most
# MAX_WALL_BEND from one segment to the next. D-0026-19: at least
# MIN_WALK_POLES blue poles stand within 3 m of the low wall. D-0026-22: for
# each model of World with a street, the ground from the curb of its street to
# its front (at the middle and at the two corners of the front) goes up or
# down by at most MAX_FORECOURT_RISE (the Grand Hotel stood on a bank 2.2 m over
# the sidewalk, and the scan of the edges passed it: its foot was a short run).
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
## The edge scan (D-0026-11): the spacing of the rays, the distances in and out
## of the edge, the highest step, and the height over the top that is a wall.
const EDGE_EVERY := 0.5
const EDGE_IN := 0.15
const EDGE_OUT := 0.3
const MAX_STEP := 0.25
const WALL_OVER := 1.0
const ON_PART := 0.3
const MAX_LEDGE_RUN := 5.0
const MAX_WALL_GRADE := 0.12
const MAX_WALL_BEND := 0.06
## D-0026-19: the blue poles by the low wall of the beach (about every 40 m of 500 m).
const MIN_WALK_POLES := 8
## D-0026-22: the ground from the curb to the front of a model, and the spacing of the samples.
const MAX_FORECOURT_RISE := 0.5
const FORECOURT_EVERY := 0.5
## The ray from the front stops at the curb: within the half width of the street and this.
const FORECOURT_CURB_M := 0.5
const FORECOURT_MAX_M := 80.0
const FORECOURT_INSET := 3.0
## Report 0026, D-0026-31: the cast green posts with five globes of the walk of
## Hạ Long (the kind globe_cast): at least one for each WALK_LAMP_EVERY m of the
## walk, each within WALK_LAMP_NEAR m of the way along the middle of the walk.
const WALK_LAMP_EVERY := 60.0
const WALK_LAMP_NEAR := 3.0
## Report 0026, D-0026-35: no tree within this of the middle of the walk of the sea (m).
const WALK_TREE_M := 2.0
## The distance of the screenshot of a model in front of it, and the most (m).
const VIEW_M := 25.0
const VIEW_MAX_M := 80.0
## The eye of a screenshot stays this far out of the box of each model (m).
const VIEW_CLEAR_M := 1.0


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.showcase != null, "the Vũng Tàu world has the showcase"):
		return
	if not await d.wait_showcase():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACES))
	if not d.expect(parsed is Dictionary, "%s can be read" % PLACES):
		return
	var data: Dictionary = {}
	var waiting: Array[String] = []
	for place: Dictionary in parsed.places:
		data[str(place.id)] = place
		# A model with the status Check has its place, but no order: it waits.
		if WorldModel.order(str(place.id)).is_empty():
			waiting.append(str(place.id))
	var models: Array[Dictionary] = w.showcase.models
	d.step("the places that wait for their models (Check): %s" % ", ".join(waiting))
	d.expect(models.size() == data.size() - waiting.size(), "each place with an order has its model: %d of %d" % [
			models.size(), data.size() - waiting.size()])
	d.step("the parts of the showcase (m, or a count): %s" % [w.showcase.lengths])
	_check_models(d, w)
	_check_hill_side(d, w)
	_scan_edges(d, w)
	_check_wall_lines(d, w)
	_check_walk_trees(d, w)
	_check_walk_lamps(d, w)
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
		# Three meters inside the sides: the grid of 2 m mixes a hill beside a
		# forecourt into the cells next to it (Hải Âu, D-0026-13).
		var inner := [t * Vector3(box.position.x + FORECOURT_INSET, 0, 0), t * Vector3(box.end.x - FORECOURT_INSET, 0, 0)]
		_check_forecourt(d, w, entry.id, place, facing, [middle] + inner)
	for i in models.size():
		for j in range(i + 1, models.size()):
			var common := 0.0
			for part: PackedVector2Array in Geometry2D.intersect_polygons(_body(models[i]), _body(models[j])):
				common += absf(_area(part))
			d.expect(common <= MAX_COMMON_M2, "%s and %s do not overlap: %.1f m² in common" % [
					models[i].id, models[j].id, common])
	# A screenshot of each model from its street, 25 m in front of it, or
	# farther where that point is in the box of another model (report 0026,
	# D-0026-34: the eye of the view of Cao ốc Sen Biển was in the hall with the
	# orange roof, and the frame was one flat color).
	for entry: Dictionary in models:
		var t: Transform3D = entry.model.transform
		var middle := t * Vector3(float(data[entry.id].get("front_middle_x", 0.0)), 0, 0)
		var out := t.basis * Vector3.BACK
		var away := VIEW_M
		while away < VIEW_MAX_M and _in_a_box(models, data, middle + out * away):
			away += 1.0
		var eye := middle + out * away
		if away > VIEW_M:
			d.step("the view of %s is %.0f m in front of it: nearer, the eye is in the box of another model" % [entry.id, away])
		eye.y = w.ground_height(eye.x, eye.z) + Player.EYE_HEIGHT
		await d.fly_to(eye, middle + Vector3(0, 6.0, 0))
		await d.wait_ground(60.0)
		await d.wait_frames(6)
		await d.screenshot(str(entry.id))
		d.expect_not_flat("the view of %s from its street" % entry.id)
	d.fly_end()


## D-0026-22: from each point of the front, out along the facing of the model
## to the curb of its street (the first point within the half width of the
## street and FORECOURT_CURB_M), the ground goes up or down from its height at
## the curb by at most MAX_FORECOURT_RISE. At a corner of the front, the street
## can fall along a wide model (Quang Trung falls 1.45 m along the front of
## Cảng vụ): the fall of the curb from the middle to the corner is not a bank.
## A model on a slope behind another lot gives its height over the street from
## a photo ("front_above_street_m", with "front_above_street_source").
func _check_forecourt(d: PlaytestDriver, w: VungTau, id: String, place: Dictionary, facing: Vector2, fronts: Array) -> void:
	var above := float(place.get("front_above_street_m", 0.0))
	if above != 0.0:
		d.step("%s stands %.1f m over %s: %s" % [id, above, place.street, place.get("front_above_street_source", "?")])
	var curb_middle := NAN
	for k in fronts.size():
		var p: Vector3 = fronts[k]
		var samples: Array[float] = []
		var curb := NAN
		var s := 0.0
		while s <= FORECOURT_MAX_M:
			var q := Vector2(p.x, p.z) + facing * s
			var road := _nearest_road_point(w, Vector3(q.x, 0, q.y), str(place.street))
			if not road.is_empty() and (road.point as Vector2).distance_to(q) <= float(road.width) / 2.0 + FORECOURT_CURB_M:
				curb = w.ground_height(q.x, q.y)
				samples.append(curb)
				break
			# A point on another road is not ground of the forecourt (Hẻm 2 Hải
			# Đăng climbs along the east wall of Hải Âu, inside its box).
			if not _on_road(w, q, str(place.street)):
				samples.append(w.ground_height(q.x, q.y))
			s += FORECOURT_EVERY
		if is_nan(curb):
			d.expect(false, "%s: the street %s is in front of the front, within %.0f m" % [id, place.street, FORECOURT_MAX_M])
			return
		if k == 0:
			curb_middle = curb
		var allowed := MAX_FORECOURT_RISE + (absf(curb - curb_middle) if k > 0 else 0.0)
		# Out of the band from the curb to the height of the front over the street.
		var worst := 0.0
		for h in samples:
			var change := h - curb
			var out := change - clampf(change, minf(0.0, above), maxf(0.0, above))
			if absf(out) > absf(worst):
				worst = out
		d.expect(absf(worst) <= allowed, "%s: from the curb of %s to its front (%s, %.1f m), the ground changes by %+.2f m%s (at most %.2f): %.2f m at the curb, %.2f m at the front" % [
				id, place.street, ["the middle", "a corner", "a corner"][mini(k, 2)], s, worst,
				" over %.1f m" % above if above != 0.0 else "", allowed, curb, samples[0] if not samples.is_empty() else NAN])


## The point is on a road (in its half width) that is not the street.
static func _on_road(w: VungTau, q: Vector2, street: String) -> bool:
	for road: Dictionary in w.data.roads:
		if str(road.name) == street or str(road.type) in ["footway", "pedestrian", "path", "steps", "track"]:
			continue
		var points: Array = road.points
		for i in points.size() - 1:
			var a := Vector3(points[i][0], 0, points[i][2])
			var b := Vector3(points[i + 1][0], 0, points[i + 1][2])
			var c := Geometry3D.get_closest_point_to_segment(Vector3(q.x, 0, q.y), a, b)
			if Vector2(c.x - q.x, c.z - q.y).length() <= float(road.get("width", 4.0)) / 2.0:
				return true
	return false


## The nearest point of a car road of the street to a point: {"point": (x, z), "width"}, or {}.
static func _nearest_road_point(w: VungTau, p: Vector3, street: String) -> Dictionary:
	var best := {}
	var best_d := INF
	for road: Dictionary in w.data.roads:
		if str(road.type) in ["footway", "pedestrian", "path", "steps", "service", "track"] or str(road.name) != street:
			continue
		var points: Array = road.points
		for i in points.size() - 1:
			var a := Vector3(points[i][0], 0, points[i][2])
			var b := Vector3(points[i + 1][0], 0, points[i + 1][2])
			var q := Geometry3D.get_closest_point_to_segment(Vector3(p.x, 0, p.z), a, b)
			var dist := Vector2(q.x - p.x, q.z - p.z).length()
			if dist < best_d:
				best_d = dist
				best = {"point": Vector2(q.x, q.z), "width": float(road.get("width", 6.0))}
	return best


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
## D-0026-16: the base lines of the low walls are smooth (no saw-tooth).
func _check_wall_lines(d: PlaytestDriver, w: VungTau) -> void:
	var steepest := 0.0
	var bend := 0.0
	var at := Vector3.ZERO
	for line: PackedVector3Array in w.showcase.wall_lines:
		var last := INF
		for i in line.size() - 1:
			var run := Vector2(line[i + 1].x - line[i].x, line[i + 1].z - line[i].z).length()
			if run < 0.1:
				continue
			var grade := (line[i + 1].y - line[i].y) / run
			steepest = maxf(steepest, absf(grade))
			if last != INF and absf(grade - last) > bend:
				bend = absf(grade - last)
				at = line[i]
			last = grade
	d.step("the low walls: %d lines, the steepest grade %.3f, the largest change of grade %.3f at (%.0f, %.0f)" % [
			w.showcase.wall_lines.size(), steepest, bend, at.x, at.z])
	d.expect(not w.showcase.wall_lines.is_empty(), "the showcase has the low walls along the beach")
	# D-0026-19: the blue poles of the walk of the sea stand by the low wall.
	var poles := 0
	for lamp: Dictionary in w.showcase.lamps:
		if str(lamp.kind) != "blue_double":
			continue
		var foot: Vector3 = lamp.at
		var near := false
		for line: PackedVector3Array in w.showcase.wall_lines:
			for q in line:
				if Vector2(q.x - foot.x, q.z - foot.z).length() < 3.0:
					near = true
					break
			if near:
				break
		if near:
			poles += 1
	d.expect(poles >= MIN_WALK_POLES, "the walk of the sea has its blue poles by the low wall: %d (at least %d)" % [poles, MIN_WALK_POLES])
	d.expect(steepest <= MAX_WALL_GRADE and bend <= MAX_WALL_BEND, "the top of each low wall is one smooth line: the grade %.3f (at most %.2f), the change of grade %.3f (at most %.2f)" % [
			steepest, MAX_WALL_GRADE, bend, MAX_WALL_BEND])


## D-0026-11: the steps at the edges of the parts that a player walks on.
func _scan_edges(d: PlaytestDriver, w: VungTau) -> void:
	var space: PhysicsDirectSpaceState3D = d.main().get_world_3d().direct_space_state
	var points := 0
	var by_kind: Dictionary = {}  # kind -> {points, ledges, max, first}
	var all_ledges: Array = []
	for edge: Dictionary in w.showcase.walk_edges:
		var a: Vector3 = edge.a
		var b: Vector3 = edge.b
		var out: Vector3 = edge.out
		var length := Vector2(b.x - a.x, b.z - a.z).length()
		var count := maxi(int(length / EDGE_EVERY), 1)
		var entry: Dictionary = by_kind.get(edge.kind, {"points": 0, "ledges": 0, "max": 0.0, "first": [],
				"run": 0, "longest": 0, "last": Vector3.INF, "at": Vector3.ZERO})
		for k in count:
			var p := a.lerp(b, (k + 0.5) / count)
			var top := _floor_at(space, w, p - out * EDGE_IN, p.y + 1.0)
			var outside := _floor_at(space, w, p + out * EDGE_OUT, top + WALL_OVER + 0.5)
			var step := top - outside
			points += 1
			entry.points += 1
			# A wall out of the part (the face of a building), or a thing on the
			# part (the closed end of the walk, the foot of a lamp): not a step.
			if outside - top > WALL_OVER or top - p.y > ON_PART:
				continue
			entry.max = maxf(float(entry.max), absf(step))
			if absf(step) > MAX_STEP:
				# A run: the ledge points next to each other along the edge.
				entry.run = int(entry.run) + 1 if (entry.last as Vector3).distance_to(p) <= EDGE_EVERY * 2.0 else 1
				entry.last = p
				if int(entry.run) > int(entry.longest):
					entry.longest = entry.run
					entry.at = p
				entry.ledges += 1
				all_ledges.append({"kind": edge.kind, "at": [p.x, p.y, p.z], "step": -step, "top": top, "outside": outside})
				if (entry.first as Array).size() < 3:
					(entry.first as Array).append("(%.1f, %.1f, %.1f) %+.2f m" % [p.x, p.y, p.z, -step])
		by_kind[edge.kind] = entry
	var file := FileAccess.open(d.out_dir.path_join("edges.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(all_ledges, "\t"))
		file.close()
	var ledges := 0
	var long_runs: Array[String] = []
	for kind: String in by_kind:
		var entry: Dictionary = by_kind[kind]
		ledges += int(entry.ledges)
		var longest := int(entry.longest) * EDGE_EVERY
		d.step("edge %s: %d points, the highest step %.2f m, %d steps over %.2f m %s, the longest run %.1f m" % [
				kind, entry.points, entry.max, entry.ledges, MAX_STEP, entry.first, longest])
		if longest > MAX_LEDGE_RUN:
			var at: Vector3 = entry.at
			long_runs.append("%s: %.1f m to (%.1f, %.1f, %.1f)" % [kind, longest, at.x, at.y, at.z])
	d.step("%d of %d points of the edges have a step of more than %.2f m" % [ledges, points, MAX_STEP])
	d.expect(points > 0 and long_runs.is_empty(), "no step of more than %.2f m with no way round it (a run longer than %.0f m) at an edge of a part that a player walks on: %s" % [
			MAX_STEP, MAX_LEDGE_RUN, long_runs])


## The highest floor under a point (the parts of the showcase and the ground), from the height "from" down.
static func _floor_at(space: PhysicsDirectSpaceState3D, w: VungTau, p: Vector3, from: float) -> float:
	var ground := w.ground_height(p.x, p.z)
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, from, p.z), Vector3(p.x, ground - 1.0, p.z), Layers.FLOOR)
	# In the body of a building, the hit is at the start of the ray: a wall.
	query.hit_from_inside = true
	var hit := space.intersect_ray(query)
	return maxf(ground, (hit.position as Vector3).y) if not hit.is_empty() else ground


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
	named.append(str(data.ground.get("beach_wall", {}).get("model", "the low wall of the beach")))
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


## True if the point is in the box of a model (with VIEW_CLEAR_M round it).
func _in_a_box(models: Array[Dictionary], data: Dictionary, point: Vector3) -> bool:
	for entry: Dictionary in models:
		var box: Array = data[entry.id].get("box", [])
		if box.size() < 4:
			continue
		var local: Vector3 = entry.model.transform.affine_inverse() * point
		if local.x > float(box[0]) - VIEW_CLEAR_M and local.x < float(box[1]) + VIEW_CLEAR_M \
				and local.z > float(box[2]) - VIEW_CLEAR_M and local.z < float(box[3]) + VIEW_CLEAR_M:
			return true
	return false


## Report 0026, D-0026-35: palms of the rule of the coast roads stood on the
## tiles of the walk of Hạ Long, some in its middle (PT-74, runs 6 and 7). No
## tree stands within WALK_TREE_M of the way along the middle of the walk.
func _check_walk_trees(d: PlaytestDriver, w: VungTau) -> void:
	var found := PackedStringArray()
	var seen := {}
	for i in w.showcase.sea_walk.size():
		if w.showcase.sea_walk_on[i] == 0:
			continue
		for tree: Array in w.trees.all_trees_near(w.showcase.sea_walk[i], WALK_TREE_M):
			var key := "%s %s" % [tree[1], tree[0]]
			if not seen.has(key):
				seen[key] = true
				found.append("a %s at %s" % [tree[1], tree[0]])
	d.expect(found.is_empty(), "no tree stands on the walk of the sea: %d%s" % [
			found.size(), "" if found.is_empty() else " (" + "; ".join(found.slice(0, 8)) + ")"])


## Report 0026, D-0026-31: the walk of Hạ Long had no lamp (PT-74, runs 5 to 7);
## the photo of 2018 (Mapillary 1927330624091805) shows a green post with five
## white globes at the parapet.
func _check_walk_lamps(d: PlaytestDriver, w: VungTau) -> void:
	var length := float(w.showcase.lengths.get("sea_walk_along", 0.0))
	var near := 0
	var far := PackedStringArray()
	for lamp: Dictionary in w.showcase.lamps:
		if str(lamp.get("kind", "")) != "globe_cast":
			continue
		var at: Vector3 = lamp.at
		var best := INF
		for i in w.showcase.sea_walk.size():
			if w.showcase.sea_walk_on[i] == 1:
				var q: Vector3 = w.showcase.sea_walk[i]
				best = minf(best, Vector2(q.x - at.x, q.z - at.z).length())
		if best <= WALK_LAMP_NEAR:
			near += 1
		else:
			far.append("(%.1f, %.1f) %.1f m" % [at.x, at.z, best])
	var least := floori(length / WALK_LAMP_EVERY)
	d.expect(near >= least and far.is_empty(), "the walk of Hạ Long (%.0f m) has at least %d cast posts with five globes along it: %d%s" % [
			length, least, near, "" if far.is_empty() else "; away from the walk: " + ", ".join(far)])
