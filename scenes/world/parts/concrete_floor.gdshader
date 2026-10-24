// The concrete floor of the hẻm (plan 0004, R11): cracks, patches of newer
// concrete, and dirt along the edges.
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform vec3 base_color : source_color = vec3(0.6, 0.59, 0.55);
uniform vec3 patch_color : source_color = vec3(0.68, 0.67, 0.63);
uniform float half_width = 1.4;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

uniform sampler2D noise_smooth : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_detail : filter_linear_mipmap, repeat_enable;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 p = world_pos.xz;
	float soft = texture(noise_smooth, p * 0.12).r;
	float detail = texture(noise_detail, p * 0.1).r;
	vec3 color = base_color * (0.9 + 0.2 * soft) * (0.95 + 0.1 * detail);
	// Patches of newer concrete: slabs across the hẻm.
	float slab = floor(p.x / 2.6);
	float patch = step(0.72, hash(vec2(slab, 3.0))) * step(abs(fract(p.x / 2.6) - 0.5), 0.3);
	color = mix(color, patch_color * (0.95 + 0.1 * detail), patch);
	// Cracks: thin lines where the smooth noise crosses 0.5, only in some places.
	float line = abs(texture(noise_smooth, p * 0.07 + 0.3).r - 0.5);
	float crack = (1.0 - smoothstep(0.0, 0.012, line)) * step(0.55, soft);
	color *= 1.0 - crack * 0.45;
	// Dirt and damp along the edges of the hẻm.
	float edge = smoothstep(half_width - 0.6, half_width, abs(world_pos.z));
	color *= 1.0 - edge * 0.25 * (0.6 + 0.4 * detail);
	ALBEDO = color;
	ROUGHNESS = 0.95;
}
