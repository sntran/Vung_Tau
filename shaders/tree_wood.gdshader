// The wood of the trees (plan 0020): the trunk, the branches, and the palm
// fronds. The vertex color: G is how much the wind moves the point, A is the
// shade under the crown. The UV goes around (x) and along (y, 1 for each 1.5 m).
shader_type spatial;

#include "res://shaders/tree_common.gdshaderinc"

// 0 for bark, more for the rings of a palm trunk.
uniform float rings = 0.0;
// 0: the near form; 1: the middle form; -1: the shadow of a near tree (it never fades).
uniform int form = 0;

varying vec4 wood_data;
varying vec3 tree_origin;

void vertex() {
	tree_origin = MODEL_MATRIX[3].xyz;
	wood_data = COLOR;
	float phase = tree_hash(tree_origin) * 6.28;
	vec3 move = tree_wind(COLOR.g, phase, 0.0, vec3(0.0), 0.0, TIME);
	VERTEX += tree_to_local(mat3(MODEL_MATRIX), move);
}

void fragment() {
	if (form >= 0 && tree_hidden(form, tree_origin, FRAGCOORD.xy)) {
		discard;
	}
	// Bark: long stripes along the trunk; a palm trunk has rings.
	float stripes = tree_hash(vec3(floor(UV.x * 14.0), floor(UV.y * 6.0), 1.0));
	float ring = smoothstep(0.35, 0.5, abs(fract(UV.y * 3.0) - 0.5)) * rings;
	float shade = wood_data.a * mix(0.82, 1.08, stripes) * (1.0 - 0.35 * ring);
	vec3 color = wood_color;
	if (wood_data.b > 0.25) {
		// Leaf-colored parts on the wood surface (none at present).
		color = leaf_color;
	}
	ALBEDO = color * shade;
	ROUGHNESS = 0.9;
}
