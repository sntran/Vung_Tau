// The far form of the hill trees (report 0005, D-0005-01): round crown clumps
// (HillCanopy). Each clump has its own green. In the dry season, some clumps
// have brown, red, or yellow leaves, and some are bare (grey brown), as on
// Núi Lớn in the photos. Nearer than near_hide, the near chunks have the real
// trees, so the clumps get smaller and go away.
shader_type spatial;
render_mode cull_disabled;

uniform float near_hide = 280.0;
uniform float fade_m = 60.0;
// 0 is green, 1 is the driest.
uniform float dryness = 0.0;
// The part of the trees that have no leaves.
uniform float bare_share = 0.0;
// Darker than before: the land was too pale from far (report 0005, D-0005-09).
uniform vec3 leaf_dark : source_color = vec3(0.09, 0.17, 0.06);
uniform vec3 leaf_light : source_color = vec3(0.16, 0.26, 0.09);
uniform vec3 dry_brown : source_color = vec3(0.38, 0.34, 0.18);
uniform vec3 dry_red : source_color = vec3(0.45, 0.25, 0.14);
uniform vec3 dry_yellow : source_color = vec3(0.45, 0.42, 0.2);
uniform vec3 bare_color : source_color = vec3(0.38, 0.35, 0.3);

varying vec3 clump_color;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	// MODEL_MATRIX has the transform of the clump in the MultiMesh.
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float near = smoothstep(near_hide, near_hide + fade_m, distance(origin.xz, CAMERA_POSITION_WORLD.xz));
	VERTEX *= near;
	float a = hash(origin.xz);
	float b = hash(origin.xz + vec2(17.0, 5.0));
	vec3 color = mix(leaf_dark, leaf_light, a);
	if (b < bare_share * 0.6) {
		color = bare_color;
	} else if (b < dryness * 0.45) {
		float kind = hash(origin.xz + vec2(3.0, 11.0));
		color = kind < 0.4 ? dry_brown : (kind < 0.7 ? dry_red : dry_yellow);
	}
	// The vertex color is the shade low on the crowns.
	clump_color = color * COLOR.r;
}

void fragment() {
	ALBEDO = clump_color;
	ROUGHNESS = 0.9;
}
