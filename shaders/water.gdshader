// The sea of the Vũng Tàu world (plan 0004, D8): waves, the reflection of the
// sky, and foam near the coast. The foam and the shallow color use the
// distance to the coastline in the alpha channel of the surface mask.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D surface_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(1.0);
uniform float coast_range = 64.0;
// The sea is only near the coast: no water over low ground inland (plan 0004, R13).
uniform float inland_limit = 24.0;
uniform sampler2D wave_normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D wave_normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 deep_color : source_color = vec3(0.04, 0.22, 0.32);
uniform vec3 shallow_color : source_color = vec3(0.16, 0.48, 0.5);
uniform vec3 foam_color : source_color = vec3(0.92, 0.95, 0.95);
uniform float foam_width = 7.0;

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
	float noise = texture(foam_noise, p * 0.08 + vec2(TIME * 0.02, 0.0)).r;
	float wave = 0.5 + 0.5 * sin(distance_to_coast * 0.9 - TIME * 1.4);
	float edge = 1.0 - smoothstep(0.0, foam_width, distance_to_coast + (noise - 0.5) * 4.0);
	float foam = edge * smoothstep(0.35, 0.75, noise * 0.7 + wave * 0.5);
	color = mix(color, foam_color, foam * 0.85);
	ALBEDO = color;
	ROUGHNESS = mix(0.06, 0.6, foam);
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
