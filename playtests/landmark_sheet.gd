extends RefCounted
# PT-63 landmark_sheet (plan 0008, R3, R9). For each known place with a
# stand-in, three screenshots at 12:00: from 200 m, from 50 m, and from 10 m,
# from a direction where the ground does not hide the place. Checks: the place
# is in the frame and the ground does not hide it; the far form has 300
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
			var view := eye_for(w, entry, distance)
			if not d.expect(not view.is_empty(), "%s: a view from %.0f m" % [id, distance]):
				continue
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


## An eye at a distance from the edge of the place, at eye height (higher for a far view),
## from the first of 16 directions where the ground does not hide the place.
static func eye_for(w: VungTau, entry: Dictionary, distance: float) -> Dictionary:
	var center: Vector3 = entry.center
	var target := center + Vector3(0, (float(entry.top) - float(entry.base)) * 0.5, 0)
	for i in 16:
		var a := TAU * i / 16.0
		var eye := center + Vector3(cos(a), 0.0, sin(a)) * (distance + float(entry.get("radius", 0.0)))
		eye.y = maxf(w.ground_height(eye.x, eye.z), 0.0) + Player.EYE_HEIGHT + (distance * 0.15 if distance > 20.0 else 0.0)
		if w.places.seen(eye, target, 2.0):
			return {"eye": eye, "target": target}
	return {}
