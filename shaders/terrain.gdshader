// The ground of the Vũng Tàu world (plan 0005, R12): sand on beaches, grass
// on hills, rock on slopes above 35 degrees, and concrete in towns. The
// surface mask comes from tools/geo/build.py: R is sand, G is town, B is wood,
// A is the distance to the coastline.
shader_type spatial;
render_mode cull_back;

uniform sampler2D surface_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(1.0);
uniform float coast_range = 64.0;
uniform sampler2D sand_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D town_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wood_texture : source_color, filter_linear_mipmap, repeat_enable;
// One texture repeat each 1 / tiling meters.
uniform float tiling = 0.25;
// The sea level now (the tide, plan 0005, D12).
uniform float sea_level = 0.0;
// cos(35 degrees) = 0.819.
uniform float rock_normal_y = 0.819;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// The scanned textures give the detail. The tropical plants are greener than
// the textures, so the grass, the wood, and the rock take their color here.
uniform vec3 grass_color : source_color = vec3(0.36, 0.47, 0.2);
uniform vec3 wood_color : source_color = vec3(0.2, 0.32, 0.13);
uniform vec3 rock_color : source_color = vec3(0.46, 0.43, 0.39);

float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 mask = texture(surface_mask, (world_position.xz - mask_origin) / mask_size);
	vec2 uv = world_position.xz * tiling;
	vec3 grass = texture(grass_texture, uv).rgb;
	vec3 color = grass_color * luminance(grass) * 2.2;
	color = mix(color, wood_color * luminance(texture(wood_texture, uv * 0.7).rgb) * 2.2, mask.b * 0.85);
	// On a hill with wood, the wood is stronger than the town (the roads up the hill).
	color = mix(color, texture(town_texture, uv).rgb, mask.g * (1.0 - mask.b * 0.75));
	color = mix(color, texture(sand_texture, uv).rgb * 1.15, mask.r);
	float rock = smoothstep(rock_normal_y + 0.04, rock_normal_y - 0.04, normalize(world_normal).y);
	color = mix(color, rock_color * luminance(texture(rock_texture, uv * 0.5).rgb) * 2.4, rock);
	// The ground under the water is darker and wet.
	float under = smoothstep(sea_level + 0.2, sea_level - 0.6, world_position.y);
	color = mix(color, color * vec3(0.55, 0.65, 0.7), under);
	ALBEDO = color;
	ROUGHNESS = mix(0.92, 0.6, under);
}
