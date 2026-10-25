// The trees of the Vũng Tàu world (plan 0005, R12a). The vertex color is the
// color of the part. The alpha of the vertex color is 1 for the leaves and 0
// for the wood. The season changes the leaves: their color, their amount, the
// flowers, and the share of bare trees.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 leaf_color : source_color = vec3(0.3, 0.47, 0.2);
uniform vec3 dry_leaf_color : source_color = vec3(0.55, 0.45, 0.25);
uniform vec3 flower_color : source_color = vec3(0.84, 0.15, 0.12);
// 0 is green, 1 is the driest.
uniform float dryness = 0.0;
// The part of the leaves that shows (1 is all).
uniform float leaves = 1.0;
// The part of the leaves that are flowers.
uniform float flowers = 0.0;
// The part of the trees that have no leaves.
uniform float bare_share = 0.0;

varying float leaf;
varying float tree_random;
varying vec3 world_position;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	leaf = COLOR.a;
	tree_random = hash(vec3(float(INSTANCE_ID), 3.7, 1.3));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The vertex colors are sRGB colors.
	vec3 color = pow(COLOR.rgb, vec3(2.2));
	if (leaf > 0.5) {
		if (tree_random < bare_share) {
			discard;
		}
		// Leaves in clumps of about 30 cm.
		vec3 cell = floor(world_position * 3.0);
		if (hash(cell) > leaves) {
			discard;
		}
		color *= mix(leaf_color, dry_leaf_color, clamp(dryness * (0.6 + 0.8 * tree_random), 0.0, 1.0));
		if (hash(cell + vec3(7.0, 3.0, 1.0)) < flowers) {
			color = flower_color;
		}
	}
	ALBEDO = color;
	ROUGHNESS = 0.85;
}
