// The surfaces of the showcase of Bãi Trước (plan 0026, R12): a texture set of
// data/look/textures.json on the world axes (the parts are made by code). A
// face with UV2.x = 1 has UVs in meters along its line (the walk on the sea
// wall of Hạ Long): its tiles follow the line, with no jagged edge (report
// 0026, D-0026-04). The texture repeats each size_m meters. A tint multiplies the
// color. With tones, the dark and the light of the texture become two colors:
// so a set of brown and black tiles gives the grey and white tiles of the
// photo from a drone of 2021. Far from the camera, the texture fades to its
// mean color (no moire).
shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_texture : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float size_m = 2.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform bool tones = false;
uniform vec3 tone_dark : source_color = vec3(0.45, 0.45, 0.45);
uniform vec3 tone_light : source_color = vec3(0.85, 0.85, 0.84);
// The luminance (linear) of the dark and of the light parts of the texture.
uniform vec2 tone_range = vec2(0.04, 0.12);
uniform float fade_near = 40.0;
uniform float fade_far = 120.0;
uniform vec3 mean_color : source_color = vec3(0.5);

varying vec3 world_position;
varying vec3 world_normal;
varying float along;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	along = UV2.x;
}

vec4 triplanar(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy) * w.x + texture(tex, p.xz) * w.y + texture(tex, p.xy) * w.z;
}

void fragment() {
	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = world_position / size_m;
	bool on_line = along > 0.5;
	vec3 color = on_line ? texture(albedo_texture, UV / size_m).rgb : triplanar(albedo_texture, p, w).rgb;
	if (tones) {
		float l = dot(color, vec3(0.2126, 0.7152, 0.0722));
		color = mix(tone_dark, tone_light, smoothstep(tone_range.x, tone_range.y, l));
	}
	float far = smoothstep(fade_near, fade_far, distance(world_position, CAMERA_POSITION_WORLD));
	ALBEDO = mix(color, mean_color, far) * tint;
	float rough = on_line ? texture(roughness_texture, UV / size_m).r : triplanar(roughness_texture, p, w).r;
	ROUGHNESS = mix(rough, 0.85, far);
}
