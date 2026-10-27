// The granite boulders of the rocky coasts and of the small islands
// (BoulderBuilder, report 0005, D-0005-03 and D-0005-05): grey and brown,
// with the detail of the rock texture on the three axes. The base is darker
// (soil and shade), and the part below the mean sea level is darker again,
// with algae (as the low rocks of the ground shader).
shader_type spatial;

uniform sampler2D rock_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 grey : source_color = vec3(0.29, 0.28, 0.27);
uniform vec3 brown : source_color = vec3(0.34, 0.28, 0.23);
uniform float tiling = 0.35;

varying vec3 world_position;
varying vec3 world_normal;
varying vec2 tone;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tone = INSTANCE_CUSTOM.rg;
}

float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec3 blend = pow(abs(world_normal), vec3(4.0));
	blend /= dot(blend, vec3(1.0));
	vec3 p = world_position * tiling;
	float detail = luminance(texture(rock_texture, p.zy).rgb) * blend.x
			+ luminance(texture(rock_texture, p.xz).rgb) * blend.y
			+ luminance(texture(rock_texture, p.xy).rgb) * blend.z;
	// The rock texture is dark (a mean linear brightness of 0.07), as in the ground shader.
	vec3 color = mix(grey, brown, smoothstep(0.3, 0.8, tone.x)) * clamp(detail * 11.0, 0.45, 1.25);
	color *= mix(0.75, 1.05, tone.y);
	color *= mix(0.55, 1.0, smoothstep(0.0, 0.5, COLOR.r));
	color = mix(color, color * vec3(0.3, 0.3, 0.24), smoothstep(0.0, -0.8, world_position.y));
	ALBEDO = color;
	ROUGHNESS = 0.85;
}
