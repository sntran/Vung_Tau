// Polished granite or ceramic tiles on a house front or a step (plan 0004, R7,
// R11). pattern 0: plain square tiles. 1: granite with speckles. 2: tiles
// with a printed pattern.
shader_type spatial;
render_mode cull_back, diffuse_burley;

instance uniform vec4 tile_color : source_color = vec4(0.72, 0.7, 0.66, 1.0);
instance uniform vec4 second_color : source_color = vec4(0.55, 0.36, 0.29, 1.0);
instance uniform float pattern = 0.0;
instance uniform float tile_size = 0.3;
instance uniform float seed = 0.0;

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 w = abs(local_normal.y) > 0.5 ? local_pos.xz : (abs(local_normal.z) > 0.5 ? local_pos.xy : local_pos.zy);
	vec2 cell = w / tile_size;
	vec2 f = fract(cell);
	float grout = 1.0 - step(0.03, f.x) * step(0.03, f.y);
	vec3 color = tile_color.rgb * (0.94 + 0.12 * hash(floor(cell) + seed));
	if (pattern > 0.5 && pattern < 1.5) {
		color *= 0.85 + 0.3 * hash(floor(w * 120.0));
	} else if (pattern > 1.5) {
		vec2 c = f - 0.5;
		float flower = step(length(c), 0.32) * step(0.18, length(c)) + step(abs(c.x) + abs(c.y), 0.12);
		color = mix(color, second_color.rgb, clamp(flower, 0.0, 1.0));
	}
	ALBEDO = mix(color, vec3(0.6, 0.58, 0.55), grout);
	ROUGHNESS = pattern > 0.5 && pattern < 1.5 ? 0.25 : 0.4;
	SPECULAR = 0.6;
}
