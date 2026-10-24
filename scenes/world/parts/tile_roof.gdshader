// Pitched roof of terracotta tiles (plan 0004, R7, R10c), with age and moss.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

instance uniform vec4 roof_color : source_color = vec4(0.83, 0.61, 0.51, 1.0);
instance uniform float age = 0.3;
instance uniform float seed = 0.0;

uniform vec3 moss_color : source_color = vec3(0.3, 0.33, 0.2);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	// Rows of tiles 0.3 m apart up the slope, and curved tiles 0.2 m wide.
	vec2 p = vec2(local_pos.x, local_pos.y * 1.4 + local_pos.z);
	float row = floor(p.y / 0.3);
	float in_row = fract(p.y / 0.3);
	float curve = 0.8 + 0.2 * cos(fract(p.x / 0.2) * 6.2831);
	vec3 color = roof_color.rgb * curve * (0.85 + 0.25 * hash(vec2(floor(p.x / 0.2), row) + seed));
	color *= 0.7 + 0.3 * smoothstep(0.0, 0.25, in_row);
	float moss = smoothstep(0.65 - age * 0.25, 0.9, noise(p * 1.3 + seed * 7.0)) * age;
	color = mix(color, moss_color, moss * 0.7);
	ALBEDO = color * (1.0 - age * 0.15);
	ROUGHNESS = 0.85;
}
