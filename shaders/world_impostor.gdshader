// The impostor of a model of World in a row (plan 0023, D5, R8): a card that
// turns to the camera, with the picture of the nearest direction of the 8
// directions of tools/world/impostors.py. COLOR is the paint color of each
// model (a MultiMesh color): the picture has white where the paint shows, and
// the paint mask is the alpha of the normal picture.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

uniform sampler2D impostor : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform sampler2D impostor_normal : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float views = 8.0;
// The size of a cell of the picture, in meters.
uniform float cell_size = 2.0;

varying vec2 cell_a;
varying vec2 cell_b;
varying float view_blend;
varying mat3 model_basis;
varying vec3 paint;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 x_axis = MODEL_MATRIX[0].xyz;
	float scale = length(x_axis);
	model_basis = mat3(normalize(x_axis), normalize(MODEL_MATRIX[1].xyz), normalize(MODEL_MATRIX[2].xyz));
	vec3 to_camera = CAMERA_POSITION_WORLD - origin;
	// The card turns around the vertical axis only: the model stands on the ground.
	vec3 flat_dir = vec3(to_camera.x, 0.0, to_camera.z);
	vec3 forward = length(flat_dir) > 0.001 ? normalize(flat_dir) : vec3(0.0, 0.0, 1.0);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
	vec2 corner = vec2(UV.x - 0.5, 1.0 - UV.y);
	VERTEX = origin + (right * corner.x + vec3(0.0, 1.0, 0.0) * corner.y) * cell_size * scale;
	NORMAL = forward;
	vec3 local = transpose(model_basis) * to_camera;
	float azimuth = atan(local.x, local.z);
	float at = mod(azimuth / (6.2831853 / views) + views, views);
	float a = floor(at);
	view_blend = at - a;
	cell_a = vec2(a, 0.0);
	cell_b = vec2(mod(a + 1.0, views), 0.0);
	paint = COLOR.rgb;
}

void fragment() {
	// The nearest view: the columns are centered on their directions.
	bool use_b = view_blend > 0.5;
	vec2 cell = use_b ? cell_b : cell_a;
	vec2 uv = (cell + UV) / vec2(views, 1.0);
	vec4 color = texture(impostor, uv);
	if (color.a < 0.5) {
		discard;
	}
	vec4 n = texture(impostor_normal, uv);
	ALBEDO = mix(color.rgb, color.rgb * paint, n.a);
	vec3 normal = n.xyz * 2.0 - 1.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(model_basis * normal, 0.0)).xyz);
	ROUGHNESS = 0.6;
	SPECULAR = 0.4;
}
