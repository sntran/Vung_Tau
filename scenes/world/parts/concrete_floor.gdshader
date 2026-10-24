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

// The distance to the nearest edge of a Voronoi cell: thin lines are cracks.
float cracks(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.0));
			float d = length(g + o - f);
			if (d < first) {
				second = first;
				first = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return second - first;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 color = base_color * (0.9 + 0.2 * noise(p * 1.5)) * (0.95 + 0.1 * noise(p * 12.0));
	// Patches of newer concrete: rectangles across the hẻm.
	float slab = floor(p.x / 2.6);
	float patch = step(0.72, hash(vec2(slab, 3.0))) * step(abs(fract(p.x / 2.6) - 0.5), 0.3);
	color = mix(color, patch_color * (0.95 + 0.1 * noise(p * 6.0)), patch);
	// Cracks, with only a few long lines visible.
	float crack = 1.0 - smoothstep(0.0, 0.025, cracks(p * 0.7));
	crack *= step(0.45, noise(p * 0.8 + 5.0));
	color *= 1.0 - crack * 0.45;
	// Dirt and damp along the edges of the hẻm.
	float edge = smoothstep(half_width - 0.6, half_width, abs(world_pos.z));
	color *= 1.0 - edge * 0.25 * (0.6 + 0.4 * noise(p * 3.0));
	ALBEDO = color;
	ROUGHNESS = 0.95;
}
