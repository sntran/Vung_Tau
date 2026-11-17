// The far form of the hill trees (report 0005, D-0005-01): round crown clumps
// (HillCanopy). Each clump has its own green. In the dry season, some clumps
// have brown, red, or yellow leaves, and some are bare (grey brown), as on
// Núi Lớn in the photos. Nearer than near_hide, the near chunks have the real
// trees, so the clumps get smaller and go away.
shader_type spatial;
render_mode cull_disabled;

uniform float near_hide = 280.0;
// Low shows fewer clumps, each one larger, and larger again far away, so that
// they cover the hills as the clumps of the other presets do (report 0005, D-0005-10).
uniform float clump_scale = 1.0;
uniform float clump_scale_far = 1.0;
uniform vec2 scale_range = vec2(400.0, 1600.0);
uniform float height_scale_max = 100.0;
// The cap of the height holds near (S1, 500 m) and fades out far away: from
// Núi Nhỏ, the low clumps on Núi Lớn (3 km) left the ground between them
// (PT-33: 54 % of the slopes with a crown color).
uniform vec2 height_cap_range = vec2(900.0, 1600.0);
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
// Far away, the clumps take the mean of their colors (report 0026, D-0026-05):
// one clump is many trees there, and the dark and the light clumps side by side
// made the slopes of Núi Lớn and Núi Nhỏ look like patches of camouflage. From
// far_range.x to far_range.y m, far_even of the difference to the mean goes.
uniform vec2 far_range = vec2(250.0, 900.0);
uniform float far_even = 0.75;
// The air between the eye and the far hill (report 0026, D-0026-15): the same
// values as the far ground (shaders/terrain.gdshader).
uniform vec3 far_haze_color : source_color = vec3(0.23, 0.38, 0.38);
uniform vec2 far_haze_range = vec2(150.0, 650.0);
// As the ground (shaders/terrain.gdshader): the haze fades out far away.
uniform vec2 far_haze_fade = vec2(1500.0, 2500.0);
uniform float far_haze = 0.58;
uniform float far_haze_light = 1.0;

varying vec3 clump_color;
varying float haze_part;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	// MODEL_MATRIX has the transform of the clump in the MultiMesh.
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float distance_xz = distance(origin.xz, CAMERA_POSITION_WORLD.xz);
	float near = smoothstep(near_hide, near_hide + fade_m, distance_xz);
	// Report 0026, D-0026-15: a far clump grows wider than it grows high, so that
	// the clumps cover the hill as one canopy and do not stand on it as houses.
	float grow = mix(clump_scale, clump_scale_far, smoothstep(scale_range.x, scale_range.y, distance_xz));
	VERTEX.xz *= near * grow;
	VERTEX.y *= near * min(grow, mix(height_scale_max, grow, smoothstep(height_cap_range.x, height_cap_range.y, distance_xz)));
	float a = hash(origin.xz);
	float b = hash(origin.xz + vec2(17.0, 5.0));
	vec3 color = mix(leaf_dark, leaf_light, a);
	if (b < bare_share * 0.6) {
		color = bare_color;
	} else if (b < dryness * 0.45) {
		float kind = hash(origin.xz + vec2(3.0, 11.0));
		color = kind < 0.4 ? dry_brown : (kind < 0.7 ? dry_red : dry_yellow);
	}
	// The mean of the colors of the clumps of the season.
	// The same mean as the far canopy of the ground (shaders/terrain.gdshader), so
	// that the far clumps do not stand out on it.
	vec3 mean = mix(mix(leaf_dark, leaf_light, 0.5), (dry_brown + dry_red + dry_yellow) / 3.0 * 0.85, dryness * 0.4);
	color = mix(color, mean, far_even * smoothstep(far_range.x, far_range.y, distance_xz));
	// The vertex color is the shade low on the crowns; far away, less of it (toward a
	// mean shade of 0.8).
	float shade = mix(COLOR.r, 0.8, 0.5 * far_even * smoothstep(far_range.x, far_range.y, distance_xz));
	haze_part = far_haze * smoothstep(far_haze_range.x, far_haze_range.y, distance_xz)
			* (1.0 - smoothstep(far_haze_fade.x, far_haze_fade.y, distance_xz));
	clump_color = color * shade * (1.0 - haze_part);
}

void fragment() {
	ALBEDO = clump_color;
	// The haze of the far land (shaders/terrain.gdshader): an emission.
	EMISSION = far_haze_color * haze_part * far_haze_light;
	ROUGHNESS = 0.9;
	// Leaves have almost no shine: with the default specular, a low sun made
	// the clumps pale tan on the Mobile renderer.
	SPECULAR = 0.1;
}
