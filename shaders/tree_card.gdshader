// The leaf cards of the middle form of the trees (plan 0020, D3, D4): a
// picture of a leaf group with alpha scissor. The picture holds the shade,
// the random value, and the kind of each leaf; the vertex color the shade of
// the card in the crown.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/tree_common.gdshaderinc"

uniform sampler2D cards : hint_default_transparent, filter_linear_mipmap, repeat_disable;
// 1: the middle form. -1: the shadow of a near tree (it never fades).
uniform int form = 1;

varying vec4 card_data;
varying vec3 tree_origin;

void vertex() {
	tree_origin = MODEL_MATRIX[3].xyz;
	card_data = COLOR;
	float phase = tree_hash(tree_origin) * 6.28;
	vec3 normal_world = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vec3 move = tree_wind(COLOR.g, phase, COLOR.r, normal_world, 1.0, TIME);
	VERTEX += tree_to_local(mat3(MODEL_MATRIX), move);
}

void fragment() {
	if (form >= 0 && tree_hidden(form, tree_origin, FRAGCOORD.xy)) {
		discard;
	}
	vec4 data = texture(cards, UV);
	// The cover gets less in the small mipmaps; this keeps it (alpha to the mip level).
	vec2 size = vec2(textureSize(cards, 0));
	vec2 dx = dFdx(UV * size);
	vec2 dy = dFdy(UV * size);
	float lod = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	if (data.a * (1.0 + lod * 0.25) < 0.5) {
		discard;
	}
	bool bare;
	vec3 color = tree_leaf_albedo(data.g, data.b, data.r * card_data.a, tree_hash(tree_origin + 7.0), bare);
	if (bare) {
		discard;
	}
	ALBEDO = color;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	BACKLIGHT = color * 0.6;
}
