class_name Quality
extends RefCounted
## The quality presets (plan 0004, D3, R4): Low, Medium, High, and Ultra.
##
## A preset sets the distance of the sun shadow, the screen-space effects,
## the volumetric fog, and the render scale. All presets use Forward+ on a
## computer, so a change of preset does not start the game again (D-0004-07).
## Android and iOS always use the Mobile renderer, and the web build always
## uses the Compatibility renderer.

const NAMES: Array[String] = ["low", "medium", "high", "ultra"]
const PRESETS := {
	"low": {"renderer": "forward_plus", "shadow_distance": 25.0, "ssao": false, "ssil": false, "sdfgi": false,
			"fog": false, "scale": 0.75},
	"medium": {"renderer": "forward_plus", "shadow_distance": 50.0, "ssao": true, "ssil": false, "sdfgi": false,
			"fog": false, "scale": 1.0},
	"high": {"renderer": "forward_plus", "shadow_distance": 80.0, "ssao": true, "ssil": true, "sdfgi": true,
			"fog": false, "scale": 1.0},
	"ultra": {"renderer": "forward_plus", "shadow_distance": 120.0, "ssao": true, "ssil": true, "sdfgi": true,
			"fog": true, "scale": 1.0},
}

## The preset for the first start: Low on phones, in the web build, and on a
## computer without a graphics card (a software renderer). Medium with a
## graphics chip in the processor, and High with a separate graphics card.
static func default_preset() -> String:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return "low"
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
			return "high"
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
			return "medium"
	return "low"


## Returns a known preset name. An unknown or empty name gives the preset of
## the first start.
static func valid(preset: String) -> String:
	return preset if PRESETS.has(preset) else default_preset()


## The renderer that the preset uses on this platform.
static func renderer_for(preset: String) -> String:
	if OS.has_feature("web"):
		return "gl_compatibility"
	if OS.has_feature("mobile"):
		return "mobile"
	return str(PRESETS[valid(preset)].renderer)


static func current_renderer() -> String:
	return RenderingServer.get_current_rendering_method()


## Sets the values of the preset. The screen-space effects and the fog are
## only in the Forward+ renderer, so they stay off with the other renderers.
static func apply(preset: String, environment: Environment, sun: DirectionalLight3D, viewport: Viewport) -> void:
	var values: Dictionary = PRESETS[valid(preset)]
	var forward := current_renderer() == "forward_plus"
	environment.ssao_enabled = forward and bool(values.ssao)
	environment.ssil_enabled = forward and bool(values.ssil)
	environment.sdfgi_enabled = forward and bool(values.sdfgi)
	environment.volumetric_fog_enabled = forward and bool(values.fog)
	# A narrow hẻm gets little sky light. Without these values, SDFGI and SSAO
	# made the street almost black at noon in the look review (PT-25). The
	# SDFGI energy changes with the time (DayLight.gi_energy()).
	environment.sdfgi_bounce_feedback = 0.6
	# The AgX tone mapping makes bright colors a little paler. SDFGI also adds
	# the blue light of the sky to all surfaces, and to the sunlit roofs too.
	# A small saturation adjustment gives the colors back, as a phone camera
	# does (report 0004, D-0004-10).
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.35 if environment.sdfgi_enabled else 1.15
	environment.ssao_intensity = 1.2
	environment.ssil_intensity = 1.4
	environment.volumetric_fog_density = 0.004
	sun.directional_shadow_max_distance = float(values.shadow_distance)
	# Low: one shadow split and hard shadows, the cost of a phone. The other
	# presets: more splits and soft shadows.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if preset == "low" \
			else (DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if preset == "medium" else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	RenderingServer.directional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_HARD if preset == "low" else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	viewport.scaling_3d_scale = float(values.scale)
	# The distances of the tree forms (plan 0020, R5, R13).
	TreeLibrary.set_ranges(valid(preset))
	# The detail levels of the ground of the Vũng Tàu world (report 0005, D-0005-10).
	VungTau.set_ground_detail(valid(preset))


## True when the sun casts shadows. Plan 0001 (note N18) turned them off,
## because the Compatibility renderer under llvmpipe made up-facing surfaces
## too bright with the sun shadow on. Plan 0004 (R5) turns them on for all
## presets. The web build keeps them off while it shows that defect (see
## AGENTS.md).
static func sun_shadow() -> bool:
	return current_renderer() != "gl_compatibility"
