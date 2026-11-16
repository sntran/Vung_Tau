extends RefCounted
# PT-63 landmark_sheet (plan 0008, R3, R9). For each known place with a
# stand-in, three screenshots at 12:00: from 200 m, from 50 m, and from 10 m,
# from a point where a visitor stands (a path, a road, the stairs, or the
# plaza). Checks: the place is in the frame, and the ground, the rocks, and the
# trees do not hide it (report 0008, D-0008-05: half of it shows at 50 m and
# 10 m, and its top at 200 m); the far form has 300
# triangles or less for the statue and the lighthouse (R9); the near form ends
# at 450 m and the far form shows to 4.5 km (R9: from 3 km). The architect
# looks at the screenshots.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=12:00
# phase: --world=vung_tau --start-time=12:00

const DISTANCES := [200.0, 50.0, 10.0]
const PER_RUN := 3
const FAR_TRIANGLES := 300


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.places != null, "the Vũng Tàu world has the known places"):
		return
	var ids: Array = w.places.places.keys()
	ids.sort()
	if d.phase == 1:
		d.expect(ids.size() >= 6, "the places with a stand-in: %s" % [ids])
		_check_far(d, w)
	for id: String in ids.slice((d.phase - 1) * PER_RUN, d.phase * PER_RUN):
		var entry: Dictionary = w.places.places[id]
		for distance: float in DISTANCES:
			# The ground and its trees round the place, before the choice of the eye.
			w.prepare_at(entry.center, distance + float(entry.get("radius", 0.0)) + 60.0)
			await d.wait_ground(90.0)
			var view := eye_for(w, entry, distance)
			if not d.expect(not view.is_empty(), "%s: a view from %.0f m" % [id, distance]):
				continue
			d.step("%s at %.0f m: the eye at %s sees %.0f %% of the place" % [id, distance, view.eye, float(view.seen) * 100.0])
			# From far, the ground in front can hide the lower part: the top row must show.
			var least := 0.33 if distance >= 150.0 else 0.5
			d.expect(float(view.seen) >= least, "%s at %.0f m: the eye sees %.0f %% of the place, %.0f %% or more (D-0008-05)" % [
					id, distance, float(view.seen) * 100.0, least * 100.0])
			await d.fly_to(view.eye, view.target)
			await d.wait_ground(90.0)
			await d.wait_frames(6)
			await d.screenshot("%s_%dm" % [id, int(distance)])
			var camera := d.viewport().get_camera_3d()
			var on_screen: bool = not camera.is_position_behind(view.target) \
					and d.viewport().get_visible_rect().has_point(camera.unproject_position(view.target))
			d.expect(on_screen, "%s at %.0f m: the place is in the frame" % [id, distance])
	d.fly_end()


## R9: the far form of the statue and the lighthouse, and the ranges.
static func _check_far(d: PlaytestDriver, w: VungTau) -> void:
	for id: String in ["chua_kito_vua", "hai_dang"]:
		var entry: Dictionary = w.places.places.get(id, {})
		if not d.expect(entry.has("far"), "%s has a far form" % id):
			continue
		var far: MeshInstance3D = entry.far
		var triangles := 0
		for s in far.mesh.get_surface_count():
			triangles += far.mesh.surface_get_array_len(s) / 3
		d.step("%s: the far form has %d triangles" % [id, triangles])
		d.expect(triangles <= FAR_TRIANGLES, "%s: the far form has %d triangles, %d or less (R9)" % [id, triangles, FAR_TRIANGLES])
		d.expect(far.visibility_range_end >= 3000.0, "%s: the far form shows from 3 km (to %.0f m)" % [id, far.visibility_range_end])


## Report 0008, D-0008-05: the eye stands where a visitor stands, on a path,
## a road, the stairs, or the plaza, at eye height, at about the distance
## from the edge of the place. Of these points, the eye is the one that sees
## the most of the place: the ground, the bodies (rocks, walls), and the
## crowns of the trees must not hide it. "seen" is the part of 9 points of
## the place (3 heights, 3 points across) that the eye sees.
static func eye_for(w: VungTau, entry: Dictionary, distance: float) -> Dictionary:
	if str(entry.place.get("kind", "")) == "jetty" and distance <= 60.0 and not w.places.jetty.is_empty():
		return _jetty_eye(w, distance)
	var center: Vector3 = entry.center
	var radius := float(entry.get("radius", 0.0))
	var height := float(entry.top) - float(entry.base)
	var target := center + Vector3(0, height * 0.5, 0)
	var candidates: Array[Vector3] = []
	for road: Dictionary in w.data.roads:
		for q: Array in road.points:
			var r := Vector2(q[0] - center.x, q[2] - center.z).length() - radius
			if r >= distance * 0.6 and r <= distance * 1.6:
				candidates.append(Vector3(q[0], 0.0, q[2]))
	# The rock path to Hòn Bà (plan 0005): visitors walk on it at low tide.
	for i in w.ridge_points.size() - 1:
		var a := w.ridge_points[i]
		var b := w.ridge_points[i + 1]
		for k in ceili(a.distance_to(b) / 5.0):
			var q := a.lerp(b, k * 5.0 / a.distance_to(b))
			var r := Vector2(q.x - center.x, q.y - center.z).length() - radius
			if r >= distance * 0.6 and r <= distance * 1.6:
				candidates.append(Vector3(q.x, 0.0, q.y))
	# The dry ground round the place, where a visitor can also stand (the rocks
	# round the islet of Hòn Bà at low tide).
	for k in 32:
		var a := TAU * k / 32.0
		var q := center + Vector3(cos(a), 0.0, sin(a)) * (distance + radius)
		if w.ground_height(q.x, q.z) > w.sea_level + 0.1:
			candidates.append(q)
	if entry.has("plaza") and distance <= 20.0:
		for k in 16:
			var a := TAU * k / 16.0
			candidates.append(center + Vector3(cos(a), 0.0, sin(a)) * (float(entry.plaza) - 2.0))
	if candidates.size() > 80:
		var step := ceili(candidates.size() / 80.0)
		var fewer: Array[Vector3] = []
		for i in range(0, candidates.size(), step):
			fewer.append(candidates[i])
		candidates = fewer
	var crowns := _crowns(w, center, distance * 1.7 + radius + 20.0)
	var best := {}
	var best_score := -1.0
	for c in candidates:
		var eye := Vector3(c.x, w.ground_height(c.x, c.z) + Player.EYE_HEIGHT, c.z)
		var f := floor_y(w, c)
		if f > -INF:
			eye.y = f + Player.EYE_HEIGHT
		var seen := _seen_part(w, entry, eye, crowns)
		# The best view, and of two views that see the same, the one nearer to the distance.
		var off := absf(Vector2(c.x - center.x, c.z - center.z).length() - radius - distance) / distance
		var score := seen - off * 0.05
		if score > best_score:
			best_score = score
			best = {"eye": eye, "target": target, "seen": seen}
	return best


## The floor at a point: the stairs or the plaza of a place, or -INF.
static func floor_y(w: VungTau, p: Vector3) -> float:
	return w.places.floor_at(p.x, p.z)


## The crowns of the trees and the boulders near a point: [center, radius] for each.
static func _crowns(w: VungTau, point: Vector3, radius: float) -> Array:
	var sizes := {}
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/trees/manifest.json"))
	if manifest is Dictionary:
		var types: Dictionary = manifest.get("types", manifest)
		for type: String in types:
			var v: Array = (types[type] as Dictionary).get("variants", [])
			if not v.is_empty():
				sizes[type] = Vector2(float(v[0].get("height", 8.0)), float(v[0].get("radius", 3.0)))
	var result := []
	if w.trees == null:
		return result
	for entry: Array in w.trees.all_trees_near(point, radius):
		var size: Vector2 = sizes.get(entry[1], Vector2(8.0, 3.0))
		var base: Vector3 = entry[0]
		result.append([base + Vector3(0, size.x * 0.6, 0), size.y * 0.5])
	# The granite boulders (plan 0005) have no collision: each is a sphere of its scale.
	for node in w.find_children("Boulders_*_near", "MultiMeshInstance3D", true, false):
		var multi := (node as MultiMeshInstance3D).multimesh
		var origin := (node as Node3D).global_transform
		for k in multi.instance_count:
			var t := origin * multi.get_instance_transform(k)
			if Vector2(t.origin.x - point.x, t.origin.z - point.z).length() <= radius:
				result.append([t.origin, t.basis.x.length() * 0.9])
	return result


static func _seen_part(w: VungTau, entry: Dictionary, eye: Vector3, crowns: Array) -> float:
	var center: Vector3 = entry.center
	var radius := float(entry.get("radius", 0.0))
	var height := float(entry.top) - float(entry.base)
	var flat := Vector3(center.x - eye.x, 0.0, center.z - eye.z).normalized()
	var side := Vector3(-flat.z, 0.0, flat.x)
	var space := w.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if entry.has("body"):
		exclude.append((entry.body as CollisionObject3D).get_rid())
	var seen := 0
	for k in 3:
		for j in 3:
			var p := center + Vector3(0, float(entry.base) - center.y + height * (0.2 + 0.3 * k), 0) \
					+ side * radius * 0.6 * (j - 1)
			if not w.places.seen(eye, p, 2.0):
				continue
			var query := PhysicsRayQueryParameters3D.create(eye, p)
			query.exclude = exclude
			if not space.intersect_ray(query).is_empty():
				continue
			var blocked := false
			for crown: Array in crowns:
				var at: Vector3 = Geometry3D.get_closest_point_to_segment(crown[0], eye, p)
				if at.distance_to(crown[0]) < float(crown[1]):
					blocked = true
					break
			if not blocked:
				seen += 1
	return seen / 9.0


## A close view of the jetty: a visitor on the deck, 5 m from the land end,
## looks along the deck at the point "distance" ahead.
static func _jetty_eye(w: VungTau, distance: float) -> Dictionary:
	var line: PackedVector3Array = w.places.jetty.line
	var deck := float(w.places.jetty.deck)
	var start := PlaytestDriver.route_point(line, 5.0)
	var ahead := PlaytestDriver.route_point(line, 5.0 + distance)
	var eye := Vector3(start.x, maxf(start.y, w.ground_height(start.x, start.z)) + Player.EYE_HEIGHT, start.z)
	var target := Vector3(ahead.x, deck + 0.5, ahead.z)
	return {"eye": eye, "target": target, "seen": 1.0 if w.places.seen(eye, target, 1.0) else 0.0}
