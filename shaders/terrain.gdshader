// The ground of the Vũng Tàu world (plan 0005, R12): sand on beaches, grass
// on hills, rock on slopes above 35 degrees, and concrete in towns. The
// surface mask comes from tools/geo/build.py: R is sand, A is the distance to
// the coastline (G, the town of OpenStreetMap, and B, its wood, are not used
// here: the cover mask has the land cover). The rock mask is bare rock: the Hòn Bà
// rock path, the rocks in the sea, and the small islands (R8h). In the dry
// season, the grass is partly dry (R12a).
// The cover mask is the land cover of ESA WorldCover and the canopy height
// maps (report 0005, D-0005-09, correction 0): R tree cover, G bushes, B
// grass, A bare ground. Far from the camera, the tree cover (the rule of
// VungTau.is_forest()) shows a canopy of tree crowns, so that the hills are not
// bare grass (D-0005-01). Near the camera, the near chunks have the real
// trees. The bushes and the ground under the trees have a pattern of bushes
// (the scrub of plan 0020 stands there near the camera). The grass shows the
// grass texture, and the bare ground shows soil. The dry season is olive and
// yellow-brown, not ochre. The town ground seen from far is a pattern of roofs
// and trees, until plan 0009 builds the houses. The sand below the last high
// water is wet: darker, shiny, with small pools.
shader_type spatial;
render_mode cull_back;

uniform sampler2D surface_mask : filter_linear, repeat_disable;
uniform sampler2D cover_mask : filter_linear, repeat_disable;
// The canopy heights (canopy.png): the trees of the town seen from far.
uniform sampler2D canopy_heights : filter_linear, repeat_disable;
uniform vec2 canopy_origin = vec2(0.0);
uniform vec2 canopy_size = vec2(1.0);
// The height (m) of a texture value of 1.
uniform float canopy_unit = 51.0;
uniform float tree_min = 3.0;
// 0 shows grass in place of the tree cover (the reference of the canopy check of PT-33).
uniform float tree_cover = 1.0;
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
uniform vec3 dry_grass_color : source_color = vec3(0.45, 0.44, 0.24);
uniform vec3 dry_orange_color : source_color = vec3(0.52, 0.43, 0.26);
// The bushes of the hill slopes (D-0005-09): dark green and olive, and some yellow-brown in the dry season.
uniform vec3 bush_dark : source_color = vec3(0.11, 0.19, 0.07);
uniform vec3 bush_olive : source_color = vec3(0.22, 0.29, 0.11);
uniform vec3 bush_dry : source_color = vec3(0.36, 0.33, 0.17);
// The town seen from far: roof colors of data/world/palette.json (VungTau sets them), and trees.
uniform vec3 roof_colors[8] : source_color;
uniform float roof_near = 120.0;
uniform float roof_far = 220.0;
// Far away, the roofs take their mean color (report 0026, D-0026-15: lots of pink
// and teal roofs made patches on the slope of Núi Nhỏ from the beach).
uniform vec2 roof_even_range = vec2(250.0, 600.0);
uniform float roof_far_even = 0.8;
// The air between the eye and the far land (report 0026, D-0026-15): from
// far_haze_range.x to .y m, far_haze of the color of the land goes to
// far_haze_color (the far forest of the photo of S1 is a pale blue green). The
// far clumps of the hill trees (shaders/canopy.gdshader) take the same values.
uniform vec3 far_haze_color : source_color = vec3(0.23, 0.38, 0.38);
uniform vec2 far_haze_range = vec2(150.0, 650.0);
// The haze fades out from far_haze_fade.x to .y m: there the fog of the world
// covers the land, and the haze took the contrast of the crowns of Núi Lớn
// from Núi Nhỏ (3 km, PT-33).
uniform vec2 far_haze_fade = vec2(1500.0, 2500.0);
uniform float far_haze = 0.58;
// The light of the haze: 1 in the day, less in the twilight (VungTau sets it).
uniform float far_haze_light = 1.0;
// The highest sea level of the last 12 hours: the sand below it is wet.
uniform float last_high = -100.0;
uniform vec3 shell_color : source_color = vec3(0.85, 0.82, 0.76);
uniform vec3 pool_color : source_color = vec3(0.1, 0.22, 0.24);
// The bare ground of the cover map: the red-brown soil and the granite grit of the hills.
uniform vec3 bare_color : source_color = vec3(0.42, 0.33, 0.24);
// The canopy starts at canopy_near meters from the camera, and it is full at canopy_far.
uniform float canopy_near = 200.0;
uniform float canopy_far = 400.0;
// As dark as the far clumps of HillCanopy: on Low, the ground shows the far forest with fewer clumps (D-0005-10).
uniform vec3 canopy_dark : source_color = vec3(0.08, 0.15, 0.06);
uniform vec3 canopy_light : source_color = vec3(0.15, 0.24, 0.09);
uniform vec3 canopy_dry : source_color = vec3(0.4, 0.33, 0.17);
// Report 0026, D-0026-23: the crowns of the forest are cells on a grid of
// crown_spacing m (jittered), each with a radius from crown_radius.x to .y m
// (crowns of 5 m to 12 m, as in the photo of S1).
uniform float crown_spacing = 7.0;
uniform vec2 crown_radius = vec2(2.5, 6.0);

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// The scanned textures give the detail. The tropical plants are greener than
// the textures, so the grass, the wood, and the rock take their color here.
uniform vec3 grass_color : source_color = vec3(0.22, 0.3, 0.11);
uniform vec3 wood_color : source_color = vec3(0.2, 0.32, 0.13);
// The rocks of Vũng Tàu are dark grey and brown granite (report 0005, section
// 8: the light color of before looked like sand at the cape). Not black: Hòn
// Bà was almost black before (D-0005-05).
uniform vec3 rock_color : source_color = vec3(0.34, 0.31, 0.28);
// The ground of the showcase of Bãi Trước (plan 0026, R3, R4): a fine mask of
// the lawns (R) and the paving (G) of OpenStreetMap, and the beds of soil
// that a photo shows (B; report 0026, D-0026-30) (data/geo/build/showcase_ground.png).
uniform sampler2D detail_mask : filter_linear, repeat_disable;
uniform vec2 detail_origin = vec2(0.0);
uniform vec2 detail_size = vec2(1.0);
uniform float detail_on = 0.0;
// A park lawn: watered, so it is green in the dry season too.
uniform vec3 lawn_color : source_color = vec3(0.2, 0.31, 0.1);
// A bed of brown soil with a few low plants (the photo from a drone of 2021).
uniform vec3 bed_color : source_color = vec3(0.3, 0.22, 0.15);
uniform vec3 paving_color : source_color = vec3(0.66, 0.64, 0.6);
uniform vec3 paving_color_b : source_color = vec3(0.56, 0.55, 0.53);
// The side of a tile (m).
uniform float paving_tile = 0.4;
// The texture of the paving (plan 0026, R12: the set walk_slabs), its side (m), and its tint.
uniform sampler2D paving_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool paving_textured = false;
uniform float paving_size = 1.8;
uniform vec3 paving_tint : source_color = vec3(1.0);
// A gain over the tint: the slabs of the photos are paler than the texture.
uniform float paving_gain = 1.0;

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

// The crowns of the forest (report 0026, D-0026-23): the nearest crown of p
// (crowns on a jittered grid of spacing m, radius from radius.x to .y m):
// dome (1 at its top, 0 at its edge and in a gap), id (a random value of the
// crown), and offset (from the middle of the crown to p, as a part of its radius).
void crown_cells(vec2 p, float spacing, vec2 radius, out float dome, out float id, out vec2 offset) {
	vec2 g = floor(p / spacing);
	float best = 10.0;
	id = 0.0;
	offset = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = g + vec2(float(i), float(j));
			vec2 center = (c + 0.15 + 0.7 * vec2(hash2(c), hash2(c + vec2(17.3, 5.9)))) * spacing;
			float r = mix(radius.x, radius.y, hash2(c + vec2(3.7, 11.1)));
			vec2 o = (p - center) / r;
			float d = length(o);
			if (d < best) {
				best = d;
				id = hash2(c + vec2(9.1, 2.3));
				offset = o;
			}
		}
	}
	dome = clamp(1.0 - best * best, 0.0, 1.0);
}

void fragment() {
	vec4 mask = texture(surface_mask, (world_position.xz - mask_origin) / mask_size);
	vec2 uv = world_position.xz * tiling;
	vec3 grass = texture(grass_texture, uv).rgb;
	float grass_detail = luminance(grass) * 2.2;
	vec3 color = grass_color * grass_detail;
	// In the dry season, the grass is dry in patches: brown and orange (R12a).
	float patches = value_noise(world_position.xz * 0.02) * 0.7 + value_noise(world_position.xz * 0.15) * 0.3;
	float dry = dryness * 0.75 * smoothstep(0.35, 0.65, patches + dryness * 0.2);
	vec3 dry_color = mix(dry_grass_color, dry_orange_color, value_noise(world_position.xz * 0.05)) * grass_detail;
	color = mix(color, dry_color, dry);
	// The rock mask: 1 for boulders, about 0.55 for the low rocks with pebbles
	// and shells (the Hòn Bà band and the flat rocks along the sea wall).
	float rock_value = texture(rock_mask, (world_position.xz - mask_origin) / mask_size).r;
	float bare_rock = smoothstep(0.25, 0.45, rock_value);
	float pebbles = bare_rock * (1.0 - smoothstep(0.7, 0.85, rock_value));
	vec4 cover = texture(cover_mask, (world_position.xz - mask_origin) / mask_size);
	cover.r *= tree_cover;
	vec3 wood = wood_color * luminance(texture(wood_texture, uv * 0.7).rgb) * 2.2;
	// Under the trees, the dry season shows less: half of the dry patches.
	wood = mix(wood, dry_color * 0.75, dry * 0.5);
	color = mix(color, wood, cover.r * 0.85);
	// The bare ground: soil with the detail of the grass texture.
	color = mix(color, bare_color * clamp(grass_detail, 0.6, 1.3), cover.a);
	// From far, the grass and the soil lose the light of the blade tips and show
	// the shade between them: darker (D-0005-09, the land was grey from the hills).
	float camera_distance = distance(world_position, CAMERA_POSITION_WORLD);
	color *= mix(1.0, 0.8, smoothstep(150.0, 600.0, camera_distance));
	// The town is the land with no cover channel (the built-up class of
	// WorldCover), not the town areas of OpenStreetMap: they also have the
	// forest of the hills and the grass field on the top of Núi Lớn, and they
	// do not have the radar station there.
	float wild = clamp(cover.r + cover.g, 0.0, 1.0);
	float town_ground = 1.0 - smoothstep(0.3, 0.7, cover.r + cover.g + cover.b + cover.a);
	color = mix(color, texture(town_texture, uv).rgb, town_ground);
	// The ground with bushes: the bushes of the cover map, and the ground under the trees.
	float hill_ground = smoothstep(0.25, 0.45, wild);
	// The town seen from far: blocks of roofs, with streets and trees between them.
	vec2 lot = world_position.xz / vec2(9.0, 11.0);
	vec2 cell = floor(lot);
	vec2 in_lot = fract(lot);
	vec3 roof = roof_colors[int(floor(hash2(cell) * 7.99))];
	// The shade between the houses makes the roofs darker from far.
	roof *= in_lot.x < 0.5 ? 0.46 : 0.6;
	float street = step(0.86, max(in_lot.x, in_lot.y));
	// The streets are asphalt and the shade of the houses: darker than the concrete.
	vec3 lot_color = mix(roof, texture(town_texture, uv).rgb * 0.55, street);
	// The trees of the town where the canopy map has them (report 0005, D-0005-09).
	// From far, a pixel covers many cells of the canopy map: five samples over
	// the pixel give the part of it with trees.
	vec2 canopy_uv = (world_position.xz - canopy_origin) / canopy_size;
	vec2 spread = fwidth(world_position.xz) * 0.35 / canopy_size;
	float town_tree = 0.0;
	for (int k = 0; k < 5; k++) {
		vec2 offset = k == 0 ? vec2(0.0) : vec2(k < 3 ? (k == 1 ? 1.0 : -1.0) : 0.0, k >= 3 ? (k == 3 ? 1.0 : -1.0) : 0.0);
		town_tree += step(tree_min, texture(canopy_heights, canopy_uv + offset * spread).r * canopy_unit) * 0.2;
	}
	vec3 town_crowns = mix(canopy_dark, canopy_light, value_noise(world_position.xz * 0.4));
	vec3 roof_mean = vec3(0.0);
	for (int k = 0; k < 8; k++) {
		roof_mean += roof_colors[k] * 0.53 / 8.0;
	}
	lot_color = mix(lot_color, roof_mean, roof_far_even * smoothstep(roof_even_range.x, roof_even_range.y, camera_distance));
	lot_color = mix(lot_color, town_crowns, town_tree);
	float town = town_ground * (1.0 - hill_ground);
	color = mix(color, lot_color, town * smoothstep(roof_near, roof_far, camera_distance));
	// The bushes of the hill slopes: blobs of about 2 to 3 m over most of the
	// ground. Near the camera, the scrub of plan 0020 stands there, so the
	// pattern is weaker (the shade under the bushes).
	float blobs = value_noise(world_position.xz * 0.38) * 0.65 + value_noise(world_position.xz * 1.3) * 0.35;
	float bush = smoothstep(0.38, 0.5, blobs);
	vec3 bush_color = mix(bush_dark, bush_olive, value_noise(world_position.xz * 0.11 + 5.0));
	bush_color = mix(bush_color, bush_dry, smoothstep(0.6, 0.68, value_noise(world_position.xz * 0.21 + 3.0)) * dryness * 0.8);
	bush_color *= mix(0.75, 1.1, smoothstep(0.5, 0.8, blobs));
	float bush_strength = mix(0.8, 1.0, smoothstep(30.0, 90.0, camera_distance));
	color = mix(color, bush_color, bush * hill_ground * bush_strength * (1.0 - mask.r));
	color = mix(color, texture(sand_texture, uv).rgb * 1.15, mask.r);
	float rock = smoothstep(rock_normal_y + 0.04, rock_normal_y - 0.04, normalize(world_normal).y);
	// Where the cover map has trees or bushes, they grow on the steep ground too:
	// the granite shows only where the map has no cover.
	rock *= 1.0 - smoothstep(0.3, 0.6, wild);
	// The rock texture is dark (a mean linear brightness of 0.07), so the
	// detail takes about 80 % of the rock color.
	vec3 rock_detail = rock_color * clamp(luminance(texture(rock_texture, uv * 0.5).rgb) * 11.0, 0.45, 1.25);
	// The canopy: round crowns of 5 m to 12 m with dark shade between them
	// (report 0026, D-0026-23: the photo of S1 shows one canopy of small crowns;
	// a smooth noise of 8 m, made even far away, gave large dark patches on a
	// lighter slope). In the dry season, some crowns are brown and red.
	float forest = smoothstep(0.4, 0.6, cover.r) * (1.0 - smoothstep(0.2, 0.3, mask.r));
	float far = smoothstep(canopy_near, canopy_far, distance(world_position, CAMERA_POSITION_WORLD));
	float crowns;
	float crown_id;
	vec2 crown_offset;
	crown_cells(world_position.xz, crown_spacing, crown_radius, crowns, crown_id, crown_offset);
	vec3 canopy = mix(canopy_dark, canopy_light, 0.35 + 0.5 * crown_id);
	float dry_share = dryness * 0.4;
	float crown_dry = step(1.0 - dry_share, fract(crown_id * 7.13));
	canopy = mix(canopy, canopy_dry * (0.55 + 0.2 * crown_id), crown_dry);
	// The leaves of a crown: clusters of about 1 m with dark holes between them.
	float leaves = value_noise(world_position.xz / 1.1) * 0.65 + value_noise(world_position.xz / 2.5 + vec2(3.1, 7.7)) * 0.35;
	float canopy_rough = mix(0.3, 1.0, smoothstep(0.0, 0.5, crowns)) * (0.65 + 0.6 * leaves);
	// Where a pixel is larger than about a third of a crown, the crowns change
	// to their mean (no moire): about 3 km away on Low. The clusters of the
	// leaves change to their mean where a pixel is larger than a cluster.
	float pixel_m = max(length(fwidth(world_position.xz)), 0.05);
	float blur = smoothstep(crown_spacing * 0.3, crown_spacing * 0.6, pixel_m);
	float leaf_blur = smoothstep(0.6, 1.4, pixel_m);
	canopy_rough = mix(canopy_rough, mix(0.3, 1.0, smoothstep(0.0, 0.5, crowns)) * 0.95, leaf_blur);
	vec3 canopy_mean = mix(mix(canopy_dark, canopy_light, 0.6), canopy_dry * 0.65, dry_share);
	canopy = mix(canopy, canopy_mean, blur);
	canopy_rough = mix(canopy_rough, 0.8, blur);
	canopy *= canopy_rough * 0.85;
	// Each crown is a dome for the light of the sun: one side lit and one in
	// its own shade, as the crowns of the photo of S1.
	float crown_light = forest * far * (1.0 - blur) * step(0.0001, crowns);
	vec3 dome_normal = normalize(normalize(world_normal) * 0.8 + vec3(crown_offset.x, 0.0, crown_offset.y) * 1.1);
	vec3 shaded_normal = normalize(mix(normalize(world_normal), dome_normal, crown_light));
	// The haze over the far forest takes the shade of the crowns too
	// (shaders/canopy.gdshader, haze_contrast): it gave most of the color.
	float forest_haze = mix(1.0, canopy_rough / 0.85, forest * far * 0.7);
	color = mix(color, canopy, forest * far);
	// Bare rock below the mean sea level is under the water for half of the
	// time: it is darker, with algae and shells (the flat rocks along the sea
	// wall, Q6, and the low rocks of the Hòn Bà path).
	vec3 low_rock = mix(rock_detail, rock_detail * vec3(0.3, 0.3, 0.24), smoothstep(0.0, -0.8, world_position.y));
	// Boulders: lit tops and dark gaps of about 3 m, so that a rocky coast does
	// not look like sand (D-0005-03).
	float blocks = value_noise(world_position.xz * 0.35) * 0.7 + value_noise(world_position.xz * 1.1) * 0.3;
	vec3 boulders = low_rock * mix(0.32, 1.1, smoothstep(0.38, 0.62, blocks));
	low_rock = mix(low_rock, boulders, bare_rock - pebbles);
	color = mix(color, low_rock, max(rock, bare_rock));
	// The lawns and the paving of the showcase (plan 0026, R3, R4). They cover
	// the town ground, the cover map, and the town seen from far.
	vec2 detail_uv = (world_position.xz - detail_origin) / detail_size;
	vec4 detail = vec4(0.0);
	if (detail_on > 0.5 && detail_uv.x >= 0.0 && detail_uv.y >= 0.0 && detail_uv.x <= 1.0 && detail_uv.y <= 1.0) {
		detail = texture(detail_mask, detail_uv);
	}
	float far_shade = mix(1.0, 0.8, smoothstep(150.0, 600.0, camera_distance));
	vec3 lawn = lawn_color * grass_detail * far_shade;
	lawn = mix(lawn, dry_color * far_shade, dry * 0.25);
	color = mix(color, lawn, detail.r);
	// The bed: soil in clods of about 0.3 m, with low plants in a third of it.
	float clods = value_noise(world_position.xz * 3.3) * 0.6 + value_noise(world_position.xz * 9.0) * 0.4;
	float plants = smoothstep(0.55, 0.75, value_noise(world_position.xz * 1.7 + vec2(13.0, 7.0)));
	vec3 bed = bed_color * mix(0.8, 1.15, clods);
	bed = mix(bed, lawn_color * grass_detail * 0.85, plants * 0.6) * far_shade;
	color = mix(color, bed, detail.b);
	// Square tiles in two tones with dark joints. From far, the pattern fades
	// to its mean color (no moire).
	vec2 tile_uv = world_position.xz / paving_tile;
	vec2 in_tile = fract(tile_uv);
	float near_pattern = 1.0 - smoothstep(15.0, 45.0, camera_distance);
	float checker = mod(floor(tile_uv.x) + floor(tile_uv.y), 2.0);
	float joint = step(0.93, max(in_tile.x, in_tile.y));
	vec3 paving_mean = (paving_color + paving_color_b) * 0.5;
	vec3 paving = mix(paving_color, paving_color_b, checker) * (0.94 + 0.12 * value_noise(world_position.xz * 3.0));
	paving = mix(paving, paving * 0.72, joint);
	if (paving_textured) {
		vec3 slab = texture(paving_texture, world_position.xz / paving_size).rgb * paving_tint * paving_gain;
		paving = mix(slab, paving_mean, smoothstep(40.0, 120.0, camera_distance));
	}
	paving = mix(paving_mean, paving, paving_textured ? 1.0 : near_pattern) * far_shade;
	color = mix(color, paving, detail.g);
	float roughness = 0.92;
	if (pebbles > 0.5 && world_position.y < 0.5) {
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
	// The ground below the last high water is wet: darker and shiny. The
	// higher parts were out of the water for longer, so they are drier. Small
	// pools stay in the low places of the sand (D-0005-09).
	float span = max(last_high - sea_level, 0.05);
	float wet = pow(clamp((last_high - world_position.y) / span, 0.0, 1.0), 0.6) * step(sea_level, world_position.y);
	wet *= 1.0 - max(rock, bare_rock) * 0.5;
	color *= mix(1.0, 0.55, wet);
	roughness = mix(roughness, 0.38, wet);
	// Report 0026, D-0026-30: the puddles have soft edges and a little of the
	// color of the water; with hard edges, the color of the sky (1.6 times the
	// pool color), and a gloss of 0.05, the wet sand had white and dark patches.
	float puddle = value_noise(world_position.xz * 0.5 + 11.0) * 0.7 + value_noise(world_position.xz * 1.7) * 0.3;
	float in_puddle = smoothstep(0.74, 0.84, puddle) * smoothstep(0.5, 0.7, wet) * step(0.5, mask.r);
	color = mix(color, pool_color, 0.3 * in_puddle);
	roughness = mix(roughness, 0.2, in_puddle);
	// The ground under the water is darker and wet.
	float under = smoothstep(sea_level + 0.2, sea_level - 0.6, world_position.y);
	color = mix(color, color * vec3(0.55, 0.65, 0.7), under);
	// The haze is light that the air scatters, not a lit surface: an emission
	// with the light of the hour, so that the warm sun of the golden hour does
	// not make it olive.
	float haze_part = far_haze * smoothstep(far_haze_range.x, far_haze_range.y, camera_distance)
			* (1.0 - smoothstep(far_haze_fade.x, far_haze_fade.y, camera_distance)) * (1.0 - under);
	ALBEDO = color * (1.0 - haze_part);
	EMISSION = far_haze_color * haze_part * far_haze_light * forest_haze;
	ROUGHNESS = mix(roughness, 0.6, under);
	// The domes of the crowns of the far forest (report 0026, D-0026-23).
	NORMAL = normalize((VIEW_MATRIX * vec4(shaded_normal, 0.0)).xyz);
}
