// Plaster on brick (plan 0004, R8, R9). Houses in Vũng Tàu are red hollow
// clay brick (gạch ống) under plaster and paint. The values of each house are
// instance uniforms, so many houses share this material.
//
// The patterns use the vertex positions in the local space of the house:
// x is along the front, y is up, z is the depth. A side wall uses z and y.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// The paint. When stripe_color.a is more than 0, the wall has two-color stripes.
instance uniform vec4 paint_color : source_color = vec4(0.91, 0.89, 0.86, 1.0);
instance uniform vec4 stripe_color : source_color = vec4(0.0);
// 0 is a new house with clean paint. 1 is an old house: faded and stained.
instance uniform float paint_age = 0.3;
instance uniform float seed = 0.0;
// 0: painted plaster. 1: bare grey plaster. 2: bare brick.
instance uniform float bare = 0.0;
// x: the top of the wall, y: the floor height, z: the half width of the
// windows, w: the center of the windows (along the wall).
instance uniform vec4 wall_info = vec4(9.6, 3.2, 1.1, 0.0);
// The half width of the wall (the distance from the center to an edge).
instance uniform float half_width = 2.25;

uniform vec3 bare_color : source_color = vec3(0.639, 0.655, 0.6);
uniform vec3 brick_color : source_color = vec3(0.659, 0.333, 0.227);
uniform vec3 mortar_color : source_color = vec3(0.725, 0.694, 0.635);
// The height of the sill above the floor line of each floor.
uniform float sill_height = 0.9;

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

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

// Red hollow clay bricks with thick, uneven mortar. "holes" from 0 to 1 shows
// the holes of the bricks (at broken ends and at edges).
vec3 brick(vec2 w, float holes) {
	float row = floor(w.y / 0.1);
	float offset = mod(row, 2.0) * 0.1;
	float column = floor((w.x + offset) / 0.2);
	vec2 cell = vec2(fract((w.x + offset) / 0.2), fract(w.y / 0.1));
	float joint = 0.07 + noise(w * 9.0) * 0.06;
	float mortar = 1.0 - step(joint, cell.x) * step(cell.x, 1.0 - joint * 0.5)
			* step(joint * 1.6, cell.y) * step(cell.y, 1.0 - joint);
	vec3 one = brick_color * (0.82 + 0.3 * hash(vec2(row, column) + seed));
	// Four holes along each brick.
	vec2 hole_cell = vec2(fract(cell.x * 4.0), cell.y);
	float hole = step(0.25, hole_cell.x) * step(hole_cell.x, 0.75) * step(0.3, hole_cell.y) * step(hole_cell.y, 0.7);
	one = mix(one, one * 0.25, hole * holes);
	return mix(one, mortar_color * (0.9 + 0.2 * noise(w * 3.0)), mortar);
}

void fragment() {
	bool side = abs(local_normal.z) < 0.5;
	vec2 w = side ? vec2(local_pos.z, local_pos.y) : vec2(local_pos.x, local_pos.y);
	vec2 s = w + vec2(seed * 17.3, seed * 5.7);
	float edge_distance = side ? 10.0 : half_width - abs(local_pos.x);

	vec3 paint = paint_color.rgb;
	if (stripe_color.a > 0.0) {
		paint = mix(paint, stripe_color.rgb, step(0.5, fract(w.y / 0.9)));
	}
	if (bare > 0.5) {
		paint = bare_color;
	}
	// Small changes in tone.
	paint *= 1.0 + (fbm(s * 0.7) - 0.5) * 0.1;
	// Age: the paint fades and gets stains.
	float lum = dot(paint, vec3(0.299, 0.587, 0.114));
	paint = mix(paint, mix(vec3(lum), vec3(1.0), 0.2), paint_age * 0.35);
	float blot = smoothstep(0.6, 0.82, fbm(s * 0.45 + 3.1)) * paint_age;
	paint *= 1.0 - blot * 0.22;

	// Rain streaks from the parapet and below each sill.
	float streak = smoothstep(0.42, 0.78, noise(vec2(s.x * 7.0, s.y * 0.35)));
	float from_top = clamp(1.0 - (wall_info.x - w.y) / 2.2, 0.0, 1.0);
	float floor_height = max(wall_info.y, 0.5);
	float sill_y = ceil((w.y - sill_height) / floor_height) * floor_height + sill_height;
	float below = sill_y - w.y;
	float under_sill = 0.0;
	if (!side && sill_y < wall_info.x - 0.5 && sill_y > floor_height
			&& abs(w.x - wall_info.w) < wall_info.z + 0.1 && below > 0.0) {
		under_sill = clamp(1.0 - below / 1.6, 0.0, 1.0);
	}
	float rain = max(from_top, under_sill) * streak * (0.35 + paint_age);
	paint *= 1.0 - rain * 0.32;

	// Damp and dirt at the base.
	float base = 1.0 - smoothstep(0.15, 0.7 + fbm(s * 1.7) * 0.5, w.y);
	paint = mix(paint, paint * vec3(0.55, 0.56, 0.5), base * (0.35 + 0.5 * paint_age));

	// Patches where the plaster fell off, mostly low on the wall and at edges.
	float low = 1.0 - smoothstep(0.4, 2.4, w.y);
	float edge = 1.0 - smoothstep(0.0, 0.7, edge_distance);
	float threshold = 0.86 - paint_age * 0.12 - low * 0.1 - edge * 0.12;
	if (bare > 0.5) {
		threshold -= 0.03;
	}
	float mask = fbm(s * 0.95 + 11.0);
	float patch = smoothstep(threshold, threshold + 0.015, mask);
	float rim = smoothstep(threshold - 0.02, threshold, mask) * (1.0 - patch);
	float bricks_here = bare > 1.5 ? 1.0 : patch;
	// The holes show at the broken ends (the border of a patch) and at the edges.
	float holes = clamp(1.0 - smoothstep(threshold + 0.015, threshold + 0.05, mask) + edge, 0.0, 1.0);
	vec3 color = mix(paint, brick(w, holes), bricks_here);
	color = mix(color, color * 1.08, rim);
	ALBEDO = color;
	ROUGHNESS = 0.92;
	SPECULAR = 0.3;
}
