// The ground of the Vũng Tàu world (plan 0005, R12): sand on beaches, grass
// on hills, rock on slopes above 35 degrees, and concrete in towns. The
// surface mask comes from tools/geo/build.py: R is sand, G is town, B is wood,
// A is the distance to the coastline. The rock mask is bare rock: the Hòn Bà
// rock path, the rocks in the sea, and the small islands (R8h). In the dry
// season, the grass is partly dry (R12a).
shader_type spatial;
render_mode cull_back;

uniform sampler2D surface_mask : filter_linear, repeat_disable;
uniform sampler2D rock_mask : filter_linear, repeat_disable;
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
// 0 is green, 1 is the driest (the season, R12a).
uniform float dryness = 0.0;
// The rocks of the Hòn Bà path below this height hold water at low tide (tide pools).
uniform float pool_level = -100.0;
uniform vec3 dry_grass_color : source_color = vec3(0.6, 0.48, 0.3);
uniform vec3 dry_orange_color : source_color = vec3(0.72, 0.47, 0.24);
uniform vec3 shell_color : source_color = vec3(0.85, 0.82, 0.76);
uniform vec3 pool_color : source_color = vec3(0.1, 0.22, 0.24);

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
// The rocks of Vũng Tàu are light granite.
uniform vec3 rock_color : source_color = vec3(0.6, 0.56, 0.5);

float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Value noise from 0 to 1.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 mask = texture(surface_mask, (world_position.xz - mask_origin) / mask_size);
	vec2 uv = world_position.xz * tiling;
	vec3 grass = texture(grass_texture, uv).rgb;
	float grass_detail = luminance(grass) * 2.2;
	vec3 color = grass_color * grass_detail;
	// In the dry season, the grass is dry in patches: brown and orange (R12a).
	float patches = value_noise(world_position.xz * 0.02) * 0.7 + value_noise(world_position.xz * 0.15) * 0.3;
	float dry = dryness * smoothstep(0.3, 0.6, patches + dryness * 0.25);
	vec3 dry_color = mix(dry_grass_color, dry_orange_color, value_noise(world_position.xz * 0.05)) * grass_detail;
	color = mix(color, dry_color, dry);
	float bare_rock = texture(rock_mask, (world_position.xz - mask_origin) / mask_size).r;
	vec3 wood = wood_color * luminance(texture(wood_texture, uv * 0.7).rgb) * 2.2;
	// Under the trees, the dry season shows less: half of the dry patches.
	wood = mix(wood, dry_color * 0.75, dry * 0.5);
	color = mix(color, wood, mask.b * 0.85);
	// On a hill with wood, the wood is stronger than the town (the roads up the hill).
	color = mix(color, texture(town_texture, uv).rgb, mask.g * (1.0 - mask.b * 0.75));
	color = mix(color, texture(sand_texture, uv).rgb * 1.15, mask.r);
	float rock = smoothstep(rock_normal_y + 0.04, rock_normal_y - 0.04, normalize(world_normal).y);
	vec3 rock_detail = rock_color * luminance(texture(rock_texture, uv * 0.5).rgb) * 2.4;
	color = mix(color, rock_detail, max(rock, bare_rock));
	float roughness = 0.92;
	if (bare_rock > 0.5 && world_position.y < 0.5) {
		// The Hòn Bà rock path: pebbles and oyster shells on the rocks (R8h).
		float speck = hash2(floor(world_position.xz * 20.0));
		color = speck < 0.015 ? shell_color : (speck < 0.05 ? rock_detail * 0.7 : color);
		// A thin, wet dark tone at the low edges.
		float wet = smoothstep(sea_level + 0.5, sea_level + 0.05, world_position.y);
		color *= mix(1.0, 0.6, wet);
		roughness = mix(roughness, 0.4, wet);
		// Tide pools: the low rocks hold water when the sea is lower.
		if (world_position.y < pool_level && world_position.y > sea_level + 0.02) {
			color = mix(color, pool_color, 0.85);
			roughness = 0.05;
		}
	}
	// The ground under the water is darker and wet.
	float under = smoothstep(sea_level + 0.2, sea_level - 0.6, world_position.y);
	color = mix(color, color * vec3(0.55, 0.65, 0.7), under);
	ALBEDO = color;
	ROUGHNESS = mix(roughness, 0.6, under);
}
