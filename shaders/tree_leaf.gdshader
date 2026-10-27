// The leaves of the near form of the trees (plan 0020): real leaf geometry.
// The vertex color holds the data of each leaf (tree_common.gdshaderinc).
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/tree_common.gdshaderinc"

varying vec4 leaf_data;
varying vec3 tree_origin;

void vertex() {
	tree_origin = MODEL_MATRIX[3].xyz;
	leaf_data = COLOR;
	float phase = tree_hash(tree_origin) * 6.28;
	vec3 normal_world = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vec3 move = tree_wind(COLOR.g, phase, COLOR.r, normal_world, 1.0, TIME);
	VERTEX += tree_to_local(mat3(MODEL_MATRIX), move);
}

void fragment() {
	if (tree_hidden(0, tree_origin, FRAGCOORD.xy)) {
		discard;
	}
	bool bare;
	vec3 color = tree_leaf_albedo(leaf_data.r, leaf_data.b, leaf_data.a, tree_hash(tree_origin + 7.0), bare);
	if (bare) {
		discard;
	}
	ALBEDO = color;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	// Thin leaves: light comes through them when the sun is behind (R4).
	BACKLIGHT = color * 0.6;
}
