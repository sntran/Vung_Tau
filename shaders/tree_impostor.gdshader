// The far form of the trees (plan 0020, D3): an impostor. The picture shows
// each variant (a row) from VIEWS directions (the columns). The card turns
// to the camera, and the shader shows the column of the direction of the
// camera around the tree. INSTANCE_CUSTOM: x is the row, y the size of a
// cell in meters. The far form casts no shadow (R7).
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

#include "res://shaders/tree_common.gdshaderinc"

uniform sampler2D impostor : hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform sampler2D impostor_normal : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float views = 8.0;
uniform float rows = 3.0;

varying vec3 tree_origin;
varying vec2 cell_a;
varying vec2 cell_b;
varying float view_blend;
varying mat3 tree_basis;

void vertex() {
	tree_origin = MODEL_MATRIX[3].xyz;
	vec3 x_axis = MODEL_MATRIX[0].xyz;
	float scale = length(x_axis);
	tree_basis = mat3(normalize(x_axis), normalize(MODEL_MATRIX[1].xyz), normalize(MODEL_MATRIX[2].xyz));
	float size = INSTANCE_CUSTOM.y * scale;
	vec3 to_camera = CAMERA_POSITION_WORLD - tree_origin;
	vec3 forward = normalize(to_camera);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
	vec3 up = cross(forward, right);
	// The corner of the card from the UV: x -0.5 to 0.5, y 0 to 1 (the base at the bottom).
	vec2 corner = vec2(UV.x - 0.5, 1.0 - UV.y);
	VERTEX = tree_origin + (right * corner.x + up * corner.y) * size;
	NORMAL = forward;
	// The direction of the camera around the tree, in the frame of the tree.
	vec3 local = transpose(tree_basis) * to_camera;
	float azimuth = atan(local.x, local.z);
	float at = mod(azimuth / (6.2831853 / views) + views, views);
	float a = floor(at);
	view_blend = at - a;
	float b = mod(a + 1.0, views);
	float row = INSTANCE_CUSTOM.x;
	cell_a = vec2(a, row);
	cell_b = vec2(b, row);
}

void fragment() {
	if (tree_hidden(2, tree_origin, FRAGCOORD.xy)) {
		discard;
	}
	// The two nearest views: the cover is the mix of both, and the data comes
	// from the nearer view where it has cover.
	vec2 uv_a = (cell_a + UV) / vec2(views, rows);
	vec2 uv_b = (cell_b + UV) / vec2(views, rows);
	vec4 data_a = texture(impostor, uv_a);
	vec4 data_b = texture(impostor, uv_b);
	// The cover gets less in the small mipmaps; this keeps it (alpha to the mip level).
	vec2 size = vec2(textureSize(impostor, 0));
	vec2 dx = dFdx(uv_a * size);
	vec2 dy = dFdy(uv_a * size);
	float lod = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	float keep = 1.0 + lod * 0.35;
	data_a.a *= keep;
	data_b.a *= keep;
	if (mix(data_a.a, data_b.a, view_blend) < 0.5) {
		discard;
	}
	bool use_b = data_b.a >= 0.5 && (view_blend > 0.5 || data_a.a < 0.5);
	vec4 data = use_b ? data_b : data_a;
	vec2 uv = use_b ? uv_b : uv_a;
	bool bare;
	float tree_random = tree_hash(tree_origin + 7.0);
	vec3 color = tree_leaf_albedo(data.g, data.b, data.r, tree_random, bare);
	if (bare) {
		discard;
	}
	vec3 n = texture(impostor_normal, uv).xyz * 2.0 - 1.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(tree_basis * n, 0.0)).xyz);
	ALBEDO = color;
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
	BACKLIGHT = data.b > 0.25 ? color * 0.6 : vec3(0.0);
}
