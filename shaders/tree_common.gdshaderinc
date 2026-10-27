// The shared part of the tree shaders of plan 0020 (Real trees): the wind,
// the colors of the season, and the change from one form to the next.
//
// The data of a leaf (from the vertex color, or from the card and impostor
// pictures): a random value, the kind (0 wood, 0.5 leaf, 1 dead leaf or brown
// fruit), and the shade inside the crown. TreeLibrary sets the uniforms from
// data/trees/types.json and the season of the game date.

// The wind of the game (Wind): the direction on the ground, and the strength
// (0 is calm air, 1 is a strong wind).
global uniform vec2 wind_direction;
global uniform float wind_strength;
// The point that the forms measure their distance from: the camera of the
// view (TreeField sets it each frame, so the shadow pass uses it too).
global uniform vec3 tree_view_position;
// The ends of the near, the middle, and the far form (meters, plan 0020, R5).
global uniform vec3 tree_ranges;

// The ranges of this type, as a part of tree_ranges (the bushes end sooner).
uniform float range_scale = 1.0;
uniform vec3 leaf_color : source_color = vec3(0.24, 0.42, 0.12);
uniform vec3 leaf_young : source_color = vec3(0.45, 0.6, 0.2);
uniform vec3 red_color : source_color = vec3(0.64, 0.23, 0.11);
uniform vec3 orange_color : source_color = vec3(0.72, 0.45, 0.16);
uniform vec3 dead_color : source_color = vec3(0.56, 0.45, 0.28);
uniform vec3 flower_color : source_color = vec3(0.84, 0.15, 0.12);
uniform vec3 wood_color : source_color = vec3(0.3, 0.25, 0.2);
// The parts of the leaves that are red or orange, bare (gone), young, and flowers.
uniform float red_share = 0.0;
uniform float bare_share = 0.0;
uniform float young_share = 0.12;
uniform float flower_share = 0.0;
// How far the wind moves the tips (meters at full strength).
uniform float sway = 0.35;

float tree_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// A screen noise for the dither of the fades (interleaved gradient noise).
float tree_dither(vec2 frag) {
	return fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715))));
}

float tree_fade_width(float range) {
	return clamp(range * 0.2, 3.0, 60.0);
}

// How much of each form shows at the distance d: x near, y middle, z far.
// The middle form shows where the near form goes away, and the far form
// where the middle form goes away, with the same dither (R6).
vec3 tree_forms(float d) {
	float n = tree_ranges.x * range_scale;
	float m = tree_ranges.y * range_scale;
	float f = tree_ranges.z * range_scale;
	float near = 1.0 - smoothstep(n - tree_fade_width(n), n, d);
	float far_in = smoothstep(m - tree_fade_width(m), m, d);
	float far_out = 1.0 - smoothstep(f - tree_fade_width(f) * 0.5, f, d);
	return vec3(near, 1.0 - near - far_in, far_in * far_out);
}

// True when the form must not draw this pixel. form: 0 near, 1 middle, 2 far.
bool tree_hidden(int form, vec3 origin, vec2 frag) {
	vec3 forms = tree_forms(distance(origin, tree_view_position));
	float noise = tree_dither(frag);
	float near_end = forms.x;
	if (form == 0) {
		return noise >= near_end;
	}
	float far_start = 1.0 - forms.x - forms.y;
	if (form == 1) {
		return noise < near_end || noise >= 1.0 - far_start;
	}
	return noise < 1.0 - far_start || noise >= 1.0 - far_start + forms.z;
}

// The wind: the move of a point in world space. flex is 0 at the trunk base
// and 1 at the tips. phase is different for each tree. t is TIME.
vec3 tree_wind(float flex, float phase, float leaf_random, vec3 normal_world, float leaf, float t) {
	vec3 dir = vec3(wind_direction.x, 0.0, wind_direction.y);
	float gust = 0.65 + 0.35 * sin(t * 0.45 + phase * 0.3) * sin(t * 0.17 + phase);
	float bend = wind_strength * gust * (0.8 + 0.2 * sin(t * 1.3 + phase));
	vec3 move = dir * (sway * flex * flex * bend);
	// The tips move to and fro too, more in a strong wind.
	move += dir * (sway * 0.25 * flex * (0.15 + wind_strength) * sin(t * 2.1 + phase + flex * 2.0));
	// The leaves flutter a little, also in calm air (R8).
	float flutter = (0.012 + 0.05 * wind_strength) * flex * leaf;
	move += normal_world * flutter * sin(t * (6.0 + 4.0 * leaf_random) + leaf_random * 40.0 + phase);
	return move;
}

// A world direction in the space of the model. The trees have a turn and
// one size for all axes, so the inverse is the transpose over the scale squared.
vec3 tree_to_local(mat3 model, vec3 v) {
	return transpose(model) * v / dot(model[0], model[0]);
}

// The color of a leaf. tree_random is a value of the whole tree. bare is set
// when the leaf fell (the season).
vec3 tree_leaf_albedo(float leaf_random, float kind, float shade, float tree_random, out bool bare) {
	float r = fract(leaf_random + tree_random * 0.618);
	// Some trees lose more leaves than others.
	float tree_bare = clamp(bare_share * (0.3 + 1.4 * tree_random), 0.0, 1.0);
	bare = kind > 0.25 && kind < 0.75 && r > 1.0 - tree_bare;
	vec3 color = leaf_color;
	float red = red_share * (0.4 + 1.2 * fract(tree_random * 3.7));
	if (kind > 0.75) {
		color = dead_color;
	} else if (kind < 0.25) {
		color = wood_color;
	} else if (r < red * 0.5) {
		color = red_color;
	} else if (r < red) {
		color = orange_color;
	} else if (r < red + young_share) {
		color = leaf_young;
	}
	if (kind > 0.25 && kind < 0.75 && fract(r * 7.13 + 0.3) < flower_share) {
		color = flower_color;
	}
	// A little change from leaf to leaf.
	float vary = 0.88 + 0.24 * fract(r * 13.7);
	return color * vary * shade;
}
