extends GutTest
## Tests for the quality presets (plan 0004, R4).


func test_presets_have_the_values_of_the_plan() -> void:
	assert_eq(Quality.NAMES, ["low", "medium", "high", "ultra"] as Array[String])
	var shadows := Quality.NAMES.map(func(n: String) -> float: return Quality.PRESETS[n].shadow_distance)
	assert_eq(shadows, [25.0, 50.0, 80.0, 120.0])
	assert_eq(Quality.PRESETS.low.renderer, "mobile")
	for preset: String in ["medium", "high", "ultra"]:
		assert_eq(Quality.PRESETS[preset].renderer, "forward_plus")
		assert_true(Quality.PRESETS[preset].ssao)
	assert_false(Quality.PRESETS.medium.ssil)
	assert_true(Quality.PRESETS.high.sdfgi)
	assert_false(Quality.PRESETS.high.fog)
	assert_true(Quality.PRESETS.ultra.fog)
	assert_almost_eq(Quality.PRESETS.low.scale, 0.75, 0.001)


func test_unknown_preset_takes_the_default() -> void:
	assert_eq(Quality.valid("ultra"), "ultra")
	assert_eq(Quality.valid(""), Quality.default_preset())
	assert_true(Quality.NAMES.has(Quality.default_preset()))


func test_restart_arguments_replace_the_renderer() -> void:
	var args := Quality.restart_args("low")
	assert_eq(args.count(Quality.RENDERER_ARG), 1)
	var at := args.find(Quality.RENDERER_ARG)
	assert_eq(args[at + 1], "mobile")


func test_apply_sets_the_shadow_and_the_scale() -> void:
	var environment := Environment.new()
	var sun := DirectionalLight3D.new()
	var viewport := SubViewport.new()
	add_child_autofree(viewport)
	Quality.apply("ultra", environment, sun, viewport)
	assert_almost_eq(sun.directional_shadow_max_distance, 120.0, 0.001)
	assert_almost_eq(viewport.scaling_3d_scale, 1.0, 0.001)
	Quality.apply("low", environment, sun, viewport)
	assert_almost_eq(sun.directional_shadow_max_distance, 25.0, 0.001)
	assert_almost_eq(viewport.scaling_3d_scale, 0.75, 0.001)
	assert_false(environment.ssao_enabled)
	sun.free()
