extends RefCounted
# PT-25 look_review (plan 0004). Fixed views of the hẻm at 07:00, 12:00, 17:30,
# and 20:00. Take still screenshots on Forward+ (High) and on Mobile (Low). I
# compare them with docs/content/reference/houses.md.
# Forward+ with SDFGI takes about 2 s for one frame under lavapipe (D7), so
# each run takes only the screenshots.
# sizes: 1280x720
# phase: --renderer=forward_plus --quality=high --start-time=07:00 --fresh-save
# phase: --renderer=forward_plus --quality=high --start-time=12:00 --fresh-save
# phase: --renderer=forward_plus --quality=high --start-time=17:30 --fresh-save
# phase: --renderer=forward_plus --quality=high --start-time=20:00 --fresh-save
# phase: --quality=low --start-time=07:00 --fresh-save
# phase: --quality=low --start-time=12:00 --fresh-save
# phase: --quality=low --start-time=17:30 --fresh-save
# phase: --quality=low --start-time=20:00 --fresh-save

const TIMES := ["0700", "1200", "1730", "2000"]


func run(d: PlaytestDriver) -> void:
	var forward := d.phase <= 4
	var renderer := RenderingServer.get_current_rendering_method()
	d.expect(renderer == ("forward_plus" if forward else "mobile"), "the renderer is %s" % renderer)
	d.expect(GameState.settings.quality == ("high" if forward else "low"), "the preset is %s" % GameState.settings.quality)
	var environment: Environment = d.main().environment
	d.expect(environment.ssao_enabled == forward, "SSAO is on only on Forward+ (High)")
	d.expect(d.main().sun.shadow_enabled, "the sun casts shadows (R5)")
	var time: String = TIMES[(d.phase - 1) % 4]
	var tag := "high" if forward else "low"
	for view: Dictionary in d.hem_views():
		await d.fly_to(view.eye, view.target)
		# SDFGI and the shadows need some frames to settle.
		await d.wait_frames(8 if forward else 4)
		await d.screenshot("%s_%s_%s" % [view.name, time, tag])
	d.fly_end()
