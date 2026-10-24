extends RefCounted
# PT-28 quality_presets (plan 0004, D3, R4). Change to each preset in the
# Settings app. Quit and start again. The preset stays. Take a screenshot of
# the same view on each preset. A preset with another renderer shows the
# restart note. Each run starts with the renderer of the preset, as the game
# does after its restart.
# sizes: 1280x720
# phase: --start-time=12:00 --fresh-save
# phase: --renderer=forward_plus --start-time=12:00
# phase: --renderer=forward_plus --start-time=12:00
# phase: --renderer=forward_plus --start-time=12:00
# phase: --start-time=12:00

## The preset at the start of each run, and the next preset that the run selects.
const RUNS := {1: ["low", "medium"], 2: ["medium", "high"], 3: ["high", "ultra"], 4: ["ultra", "low"], 5: ["low", ""]}


func run(d: PlaytestDriver) -> void:
	var now: String = RUNS[d.phase][0]
	var next: String = RUNS[d.phase][1]
	if d.phase == 1:
		await d.skip_intro()
		d.expect(GameState.settings.quality == "low", "the first start under lavapipe selects Low: %s" % GameState.settings.quality)
	d.expect(GameState.settings.quality == now, "after the restart the preset is %s, not %s" % [now, GameState.settings.quality])
	var environment: Environment = d.main().environment
	var values: Dictionary = Quality.PRESETS[now]
	var forward := RenderingServer.get_current_rendering_method() == "forward_plus"
	d.expect(environment.ssao_enabled == (forward and values.ssao), "%s: SSAO is %s" % [now, environment.ssao_enabled])
	d.expect(environment.sdfgi_enabled == (forward and values.sdfgi), "%s: SDFGI is %s" % [now, environment.sdfgi_enabled])
	d.expect(environment.volumetric_fog_enabled == (forward and values.fog), "%s: the fog is %s" % [now, environment.volumetric_fog_enabled])
	d.expect(absf(d.main().sun.directional_shadow_max_distance - float(values.shadow_distance)) < 0.01,
			"%s: the sun shadow distance is %.0f m" % [now, d.main().sun.directional_shadow_max_distance])
	d.expect(absf(d.main().get_viewport().scaling_3d_scale - float(values.scale)) < 0.01, "%s: the render scale is %.2f" % [now, d.main().get_viewport().scaling_3d_scale])
	# The same view on each preset.
	var view: Dictionary = d.hem_views()[0]
	await d.fly_to(view.eye, view.target)
	await d.wait_frames(6)
	await d.screenshot("view_%s" % now)
	d.fly_end()
	if next == "":
		return
	await d.open_app("settings")
	await d.tap_phone_id("settings.quality")
	d.expect(GameState.settings.quality == next, "the Settings app changes the preset to %s: %s" % [next, GameState.settings.quality])
	var needs_restart := Quality.renderer_for(next) != RenderingServer.get_current_rendering_method()
	var note := d.find("settings.restart") as Control
	var shown := note != null and note.is_visible_in_tree()
	d.expect(shown == needs_restart, "the restart note shows only for another renderer (%s to %s): %s" % [now, next, shown])
	await d.screenshot("settings_%s" % next)
