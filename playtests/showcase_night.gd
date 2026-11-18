extends RefCounted
# PT-76 showcase_night (plan 0026, R14). The shots S3 and S5 of
# data/showcase/shots.json at 20:00, on Low (the Mobile renderer) and on High
# (Forward+): the street lamps of Quang Trung light the ground and the heads
# of the lamps glow. The fronts of the bars of Quang Trung 4 to 26 glow with
# the emissive parts of their models of World. On Low, the check of the light
# records the measure only (an open defect of phase 6, plan 0026: the Mobile
# renderer). The windows of the hotels wait
# for World (the models have no lit windows yet): the test says so.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=20:00 --quality=low
# phase: --world=vung_tau --start-time=20:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=20:00 --quality=high --renderer=forward_plus
# phase: --world=vung_tau --start-time=20:00 --quality=high --renderer=forward_plus

const SHOTS := "res://data/showcase/shots.json"
## The eye and the aim of a shot, as PT-72 takes it.
const Shots := preload("res://playtests/showcase_shots.gd")
## For each run: the preset, the shots, and if the run measures the light of a lamp.
## High takes S3, S5, and the measure in three runs: a run on Forward+ under
## lavapipe is slow (one run of S3 and the measure took more than 300 s in CI).
const RUNS := [["low", ["S3", "S5"], true], ["high", ["S3"], false], ["high", ["S5"], false], ["high", [], true]]
## The ground under a street lamp, with the lamps on, against the same view with them off.
const MIN_LIT_RATIO := 1.5


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.showcase != null, "the Vũng Tàu world has the showcase"):
		return
	if not await d.wait_showcase():
		return
	await d.wait_frames(10)
	d.expect(w.showcase.lamps_lit, "at 20:00 the lamps of the showcase are on")
	d.expect(w.showcase.lamp_lights.size() > 0, "the street lamps have lights: %d" % w.showcase.lamp_lights.size())
	var on := 0
	for light: OmniLight3D in w.showcase.lamp_lights:
		on += 1 if light.visible else 0
	d.expect(on == w.showcase.lamp_lights.size(), "each street lamp lights the ground: %d of %d" % [on, w.showcase.lamp_lights.size()])
	d.step("the windows of the hotels wait for World: the models of World have no lit windows yet")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHOTS))
	if not d.expect(data is Dictionary, "%s can be read" % SHOTS):
		return
	var camera := d.viewport().get_camera_3d()
	var fov := camera.fov
	var ui: Control = d.main().ui_root
	var run_values: Array = RUNS[d.phase - 1]
	var preset: String = run_values[0]
	for shot: Dictionary in data.shots:
		if not str(shot.id) in (run_values[1] as Array):
			continue
		var eye := Shots.eye_of(w, shot)
		await d.fly_to(eye, Shots.aim(shot, eye))
		d.expect(await d.wait_ground(120.0), "%s: the ground is ready" % shot.id)
		camera.fov = float(shot.get("fov", fov))
		ui.visible = false
		await d.wait_frames(8)
		await d.screenshot("%s_%s_2000" % [shot.id, preset])
		ui.visible = true
		camera.fov = fov
	if not bool(run_values[2]):
		d.fly_end()
		return
	# A lamp lights the ground: one view of the ground under a street lamp, with
	# the street lamps on and then off (a measure only: the lamps go on again).
	var lamp: OmniLight3D = w.showcase.lamp_lights[0]
	var under := lamp.global_position
	under.y = w.ground_height(under.x, under.z)
	# A first look at the view, so that both measures have the same ground.
	await _brightness(d, under + Vector3(4, 5, 4), under)
	for light: OmniLight3D in w.showcase.lamp_lights:
		light.visible = false
	var dark := await _brightness(d, under + Vector3(4, 5, 4), under)
	for light: OmniLight3D in w.showcase.lamp_lights:
		light.visible = true
	var lit := await _brightness(d, under + Vector3(4, 5, 4), under)
	var text := "the ground under a street lamp takes the warm light: red %.3f with the lamps, %.3f without them" % [lit, dark]
	if preset == "high":
		d.expect(lit > dark * MIN_LIT_RATIO, text)
	else:
		# The open defect of plan 0026 (phase 6): on the Mobile renderer the
		# lights of the lamps take the light of the moon away from the big
		# meshes of the showcase, so the frame gets darker. The run records it.
		d.step("Low (the Mobile renderer, an open defect of phase 6): " + text)
	d.fly_end()


## The mean red of the frame when the camera looks at a point: the warm light
## of the lamps (the light of the moon and of the sky at night is blue).
func _brightness(d: PlaytestDriver, eye: Vector3, target: Vector3) -> float:
	# Each chunk to the mid distance of the preset at once, as for a shot
	# (Shots.eye_of()). With 200 m, the world built the other chunks of the mid
	# ring one in each frame, and on High in CI (about 1.2 s for each frame) the
	# ground was not ready in 60 s (the CI of 112ed1c, run 4).
	d.world().prepare_at(eye, maxf(400.0, float(VungTau.ground_detail.mid)))
	await d.fly_to(eye, target)
	await d.wait_ground(120.0)
	await d.wait_frames(10)
	var image := d.viewport().get_texture().get_image()
	var size := image.get_size()
	var total := 0.0
	var count := 0
	for y in range(0, size.y, 8):
		for x in range(0, size.x, 8):
			total += image.get_pixel(x, y).r
			count += 1
	return total / maxf(count, 1)
