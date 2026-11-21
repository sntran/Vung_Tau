extends RefCounted
# PT-60 landmark_views (plan 0008, D4, R8). From the eyes of
# data/geo/place_views.json (the beach of Bãi Trước, the south part of Bãi Sau,
# the Hải Đăng road, and the sea in front of Bãi Trước), the game casts the
# rays to the top of the statue and of the lighthouse against its own ground.
# Checks: the part of each place that the eye sees is the part of the DEM
# calculation of the tools (data/geo/build/place_views.json), ±0.1; D4: from
# the beach of Bãi Trước the statue is hidden and the lighthouse is mostly
# hidden, and from the south of Bãi Sau the statue shows. A screenshot of each
# view at 12:00 and at 18:00. No view changes to make a place visible. The two
# checks of D4 that a place is hidden count the tree tops of the canopy map too:
# the ground is the bare earth (plan 0009, R5b), and the trees of the slopes
# hide the places; the check "above the ridge" is on the ground.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=12:00
# phase: --world=vung_tau --start-time=18:00

const VIEWS := "res://data/geo/build/place_views.json"
const AGREE := 0.1


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.places != null, "the Vũng Tàu world has the known places"):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VIEWS))
	if not d.expect(parsed is Dictionary and not parsed.results.is_empty(), "the tools made %s" % VIEWS):
		return
	var results := {}
	# D4 is what the eye sees: the ground and the trees on it (plan 0009, R5b:
	# the ground is the bare earth now, so the trees are not in it).
	var with_trees := {}
	for r: Dictionary in parsed.results:
		var e: Array = parsed.eyes[r.eye]
		var t: Array = r.target
		var eye := Vector3(e[0], e[1], e[2])
		var base := Vector3(t[0], t[1], t[2])
		var game := w.places.seen_part(eye, base, float(r.top_m), int(parsed.samples), float(parsed.step_m))
		results["%s/%s" % [r.eye, r.place]] = game
		with_trees["%s/%s" % [r.eye, r.place]] = w.places.seen_part(eye, base, float(r.top_m), int(parsed.samples),
				float(parsed.step_m), true)
		d.step("%s to %s: the DEM gives %.1f, the game %.1f; with the trees of the canopy map %.1f" % [
				r.eye, r.place, float(r.seen), game, with_trees["%s/%s" % [r.eye, r.place]]])
		d.expect(absf(game - float(r.seen)) <= AGREE + 0.001, "%s to %s: the game (%.1f) and the DEM (%.1f) agree (R8)" % [
				r.eye, r.place, game, float(r.seen)])
		await d.fly_to(eye, base + Vector3(0, float(r.top_m) * 0.5, 0))
		await d.wait_ground(90.0)
		await d.wait_frames(6)
		await d.screenshot("%s_%s_%s" % [r.eye, r.place, "1200" if d.phase == 1 else "1800"])
	d.expect(with_trees.get("bai_truoc_beach/chua_kito_vua", 1.0) == 0.0, "D4: from Bãi Trước the statue is hidden")
	d.expect(with_trees.get("bai_truoc_beach/hai_dang", 1.0) <= 0.3, "D4: from Bãi Trước the lighthouse is mostly hidden: %.1f" % [
			with_trees.get("bai_truoc_beach/hai_dang", 1.0)])
	# "Above the ridge": the ridge is the ground (the trees round the top hide the
	# lower part of the statue: with them the part is lower).
	d.expect(results.get("bai_sau_south/chua_kito_vua", 0.0) >= 0.5, "D4: from the south of Bãi Sau the statue shows above the ridge: %.1f (%.1f with the trees)" % [
			results.get("bai_sau_south/chua_kito_vua", 0.0), with_trees.get("bai_sau_south/chua_kito_vua", 0.0)])
	d.fly_end()
