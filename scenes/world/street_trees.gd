class_name StreetTrees
extends RefCounted
## The street trees and the park trees of data/geo/build/trees.json (plan 0005,
## R12a). They go into the TreeField as the source TreeField.STATIC, with the far form
## in fixed tiles (plan 0020, R10). Each tree gets a random turn and size (D5).

## type -> number of trees.
var counts: Dictionary = {}


## The turn of a tree that leans (plan 0026, R9): "tilt" degrees from the
## vertical, to the direction "toward" (degrees from +Z to +X).
static func lean(tilt: float, toward: float) -> Basis:
	var direction := Vector3(sin(deg_to_rad(toward)), 0.0, cos(deg_to_rad(toward)))
	return Basis(Vector3.UP.cross(direction).normalized(), deg_to_rad(tilt))


## Reads the trees into the field. Returns false when the file is not there.
func setup(path: String, field: TreeField) -> bool:
	if not GeoData.has_file(path):
		return false
	var parsed: Variant = JSON.parse_string(GeoData.read_text(path))
	if not parsed is Dictionary:
		return false
	var types: Dictionary = parsed.get("types", {})
	for type: String in types:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(type)
		var transforms: Array[Transform3D] = []
		for p: Array in types[type]:
			var size := rng.randf_range(0.85, 1.15)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size)
			if p.size() >= 5:
				basis = lean(float(p[3]), float(p[4])) * basis
			transforms.append(Transform3D(basis, Vector3(p[0], p[1] - 0.05, p[2])))
		counts[type] = transforms.size()
		field.add_trees(TreeField.STATIC, type, transforms, true)
	field.commit_far_tiles()
	return true
