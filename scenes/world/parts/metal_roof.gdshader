// Corrugated metal roof (tôn, plan 0004, R7, R10c). The ridges run down the
// slope. Rust shows in streaks along the ridges.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

instance uniform vec4 roof_color : source_color = vec4(0.58, 0.72, 0.72, 1.0);
// 0: new metal. 1: much rust.
instance uniform float rust = 0.3;
instance uniform float seed = 0.0;
// The direction of the ridges in the local space: 0 along x, 1 along z.
instance uniform float ridges_along_z = 1.0;

uniform vec3 rust_color : source_color = vec3(0.45, 0.25, 0.17);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

uniform sampler2D noise_smooth : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_detail : filter_linear_mipmap, repeat_enable;

// Detailed noise from 0 to 1, from a texture (fast without a graphics card).
float noise(vec2 p) {
	return texture(noise_detail, p * 0.08).r;
}

void fragment() {
	// across: the position across the ridges. down: along the ridges.
	float across = ridges_along_z > 0.5 ? local_pos.x : local_pos.z;
	float down = ridges_along_z > 0.5 ? local_pos.z : local_pos.x;
	float wave = cos(across * 6.2831 / 0.076);
	vec3 color = roof_color.rgb * (0.86 + 0.14 * wave);
	// Each sheet is about 1 m wide, with a small change of tone. Some sheets
	// are newer or were painted again, so their color is stronger: the photo
	// colors of R10c are the means of many sheets (D-0004-09).
	float sheet = hash(vec2(floor(across / 1.0), seed));
	color *= 0.92 + 0.16 * sheet;
	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	color = max(mix(vec3(lum), color, 1.4 + 0.9 * hash(vec2(floor(across / 1.0) + 7.0, seed))), vec3(0.0));
	float streak = noise(vec2(across * 26.0 + seed * 9.0, down * 1.5));
	float rust_mask = smoothstep(0.75 - rust * 0.45, 0.95 - rust * 0.3, streak) * step(0.2, wave);
	color = mix(color, rust_color * (0.8 + 0.4 * noise(local_pos.xz * 4.0)), rust_mask * (0.4 + 0.6 * rust));
	ALBEDO = color;
	// Painted sheets are almost matte. A shiny metal reflected the pale sky
	// and made the colors grey from above (D-0004-03).
	METALLIC = 0.1 * (1.0 - rust_mask);
	ROUGHNESS = mix(0.65, 0.9, rust_mask);
	SPECULAR = 0.3;
}
