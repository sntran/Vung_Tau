// The sea of the Vũng Tàu world (plan 0005, D8): waves, the reflection of the
// sky, and foam near the coast. The shallow color uses the distance to the
// coastline in the alpha channel of the surface mask. The foam is where the
// water is thin: the depth texture gives the ground behind the water, so the
// foam follows the water line at each tide (the coastline of the data is near
// the high tide, and at high tide the water covers the low beach).
// Report 0005, D-0005-07: over a wide shallow floor, the thin water made a
// white sheet. The foam is now a narrow band at the water line: the distance
// to the line is the depth of the water over the slope of the floor. It is
// strong on the open coast and on the rocks, and weak in the calm bay of
// Bãi Trước, with no hard edges.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D surface_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(1.0);
uniform float coast_range = 64.0;
// The sea is only near the coast: no water over low ground inland (plan 0005, R13).
uniform float inland_limit = 24.0;
uniform sampler2D wave_normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D wave_normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 deep_color : source_color = vec3(0.04, 0.22, 0.32);
uniform vec3 shallow_color : source_color = vec3(0.16, 0.48, 0.5);
uniform vec3 foam_color : source_color = vec3(0.92, 0.95, 0.95);
// The width of the foam band at the water line (m) on the open coast.
uniform float foam_band = 4.0;
// The foam is never where the water is deeper than this (m).
uniform float foam_depth = 1.2;
// The calm bay of Bãi Trước: little foam there.
uniform vec2 calm_center = vec2(0.0);
uniform float calm_radius = 0.0;
uniform float calm_foam = 0.12;
uniform sampler2D rock_mask : filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	vec3 na = texture(wave_normal_a, p * 0.045 + TIME * vec2(0.012, 0.007)).rgb;
	vec3 nb = texture(wave_normal_b, p * 0.11 - TIME * vec2(0.009, 0.016)).rgb;
	NORMAL_MAP = normalize(na + nb - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
	vec2 uv = (p - mask_origin) / mask_size;
	bool inside = uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
	// The alpha is (distance + range) / (2 * range). At sea, the distance is negative.
	// Five samples make the 8 m mask smooth, so that the foam has no squares.
	vec2 texel = 1.0 / vec2(textureSize(surface_mask, 0));
	float alpha = texture(surface_mask, uv).a * 0.4
			+ (texture(surface_mask, uv + vec2(texel.x, 0.0)).a + texture(surface_mask, uv - vec2(texel.x, 0.0)).a
			+ texture(surface_mask, uv + vec2(0.0, texel.y)).a + texture(surface_mask, uv - vec2(0.0, texel.y)).a) * 0.15;
	float signed_distance = (alpha * 2.0 - 1.0) * coast_range;
	if (inside && signed_distance > inland_limit) {
		discard;
	}
	float distance_to_coast = inside ? max(0.0, -signed_distance) : coast_range;
	float shallow = 1.0 - smoothstep(0.0, coast_range * 0.6, distance_to_coast);
	vec3 color = mix(deep_color, shallow_color, shallow);
	// The thickness of the water along the view, from the depth of the ground behind it.
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, raw_depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
#endif
	vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 behind_view = behind.xyz / behind.w;
	float thickness = max(0.0, -behind_view.z + VERTEX.z);
	// The floor behind the water in world space: its depth under the surface and its slope.
	vec3 ground = (INV_VIEW_MATRIX * vec4(behind_view, 1.0)).xyz;
	float depth = max(0.0, world_position.y - ground.y);
	vec3 ground_normal = normalize(cross(dFdx(ground), dFdy(ground)));
	float slope = length(ground_normal.xz) / max(abs(ground_normal.y), 0.05);
	float to_line = depth / max(slope, 0.01);
	float noise = texture(foam_noise, p * 0.08 + vec2(TIME * 0.02, 0.0)).r;
	float calm = calm_radius > 0.0 ? 1.0 - smoothstep(calm_radius * 0.7, calm_radius, distance(p, calm_center)) : 0.0;
	float on_rock = inside ? smoothstep(0.25, 0.5, texture(rock_mask, uv).r) : 0.0;
	float strength = max(mix(1.0, calm_foam, calm), on_rock);
	float band = foam_band * mix(0.5, 1.0, strength);
	float wave = 0.5 + 0.5 * sin(to_line * 2.0 - TIME * 1.4);
	float edge = (1.0 - smoothstep(0.0, band, to_line + (noise - 0.5) * band * 0.8))
			* (1.0 - smoothstep(foam_depth * 0.5, foam_depth, depth));
	color = mix(color, shallow_color * 1.15, 1.0 - smoothstep(0.0, 3.0, thickness));
	float foam = edge * strength * smoothstep(0.35, 0.75, noise * 0.7 + wave * 0.5);
	color = mix(color, foam_color, foam * 0.85);
	ALBEDO = color;
	ROUGHNESS = mix(0.06, 0.6, foam);
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
