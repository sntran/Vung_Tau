class_name TreeKit
extends RefCounted
## The tree types of the Vũng Tàu world (plan 0005, R12a): simple shapes made
## by code. Each type has one mesh and one material (shaders/tree.gdshader).
## The leaves have the vertex alpha 1, so the season can change them.

const TYPES: Array[String] = ["hill", "shade", "tall_shade", "flame", "frangipani", "casuarina", "coconut", "fan_palm"]
const WOOD := Color("#5E4632", 0.0)
const PALM_WOOD := Color("#8A7A62", 0.0)
## The leaf color of each type. The vertex color of the leaves is near white.
const LEAF_COLORS := {
	"hill": Color("#466B32"), "shade": Color("#3F6B2E"), "tall_shade": Color("#3B6630"),
	"flame": Color("#5E8E3A"), "frangipani": Color("#5C8436"), "casuarina": Color("#4A5E3C"),
	"coconut": Color("#6A8F3C"), "fan_palm": Color("#4F7A36"),
}
const FLOWER_COLORS := {"flame": Color("#D7261E"), "frangipani": Color("#F4EFD9")}

static var _meshes: Dictionary = {}


static func _leaf(shade := 1.0) -> Color:
	return Color(shade, shade, shade, 1.0)


## The mesh of a tree type. The base of the trunk is at the origin.
static func mesh(type: String) -> Mesh:
	if _meshes.has(type):
		return _meshes[type]
	var b := MeshBatch.new()
	match type:
		"hill":
			b.cylinder("m", 0.15, 2.4, Vector3(0, 1.2, 0), WOOD, 6, Basis(), false)
			b.box("m", Vector3(3.0, 2.4, 3.0), Vector3(0, 3.4, 0), _leaf(0.95), Basis(Vector3.UP, PI / 4.0))
			b.box("m", Vector3(2.2, 1.6, 2.2), Vector3(0.3, 4.4, -0.2), _leaf(1.0))
		"shade":
			# A large shade tree of the main roads (for example sao, dầu, or me tây).
			b.cylinder("m", 0.28, 4.0, Vector3(0, 2.0, 0), WOOD, 8, Basis(), false)
			b.cylinder("m", 0.12, 2.4, Vector3(0.7, 4.4, 0), WOOD, 5, Basis(Vector3.BACK, -0.6), false)
			b.cylinder("m", 0.12, 2.4, Vector3(-0.6, 4.5, 0.3), WOOD, 5, Basis(Vector3.BACK, 0.6), false)
			b.box("m", Vector3(5.5, 2.6, 5.0), Vector3(0, 6.0, 0), _leaf(0.95), Basis(Vector3.UP, 0.4))
			b.box("m", Vector3(3.8, 2.0, 3.8), Vector3(1.2, 7.2, 0.6), _leaf(1.0), Basis(Vector3.UP, 1.1))
			b.box("m", Vector3(3.4, 1.8, 3.6), Vector3(-1.3, 6.8, -0.8), _leaf(0.9))
		"tall_shade":
			# The tall trees between the Bãi Trước road and the sea.
			b.cylinder("m", 0.38, 9.0, Vector3(0, 4.5, 0), WOOD, 8, Basis(), false)
			b.box("m", Vector3(6.5, 3.2, 6.0), Vector3(0, 10.5, 0), _leaf(0.95), Basis(Vector3.UP, 0.3))
			b.box("m", Vector3(4.5, 2.4, 4.5), Vector3(0.8, 12.4, -0.4), _leaf(1.0), Basis(Vector3.UP, 1.0))
		"flame":
			# Phượng vĩ: a short trunk and a wide, flat crown like an umbrella.
			b.cylinder("m", 0.3, 2.6, Vector3(0, 1.3, 0), WOOD, 8, Basis(), false)
			for i in 4:
				var angle := TAU * i / 4.0 + 0.4
				var out := Vector3(cos(angle), 0, sin(angle))
				b.cylinder("m", 0.12, 2.6, Vector3(0, 3.1, 0) + out * 0.9, WOOD, 5,
						Basis(out.cross(Vector3.UP).normalized(), 0.8), false)
			b.box("m", Vector3(7.5, 1.4, 7.0), Vector3(0, 4.6, 0), _leaf(0.95), Basis(Vector3.UP, 0.5))
			b.box("m", Vector3(5.0, 1.0, 5.0), Vector3(0, 5.4, 0), _leaf(1.0), Basis(Vector3.UP, 1.2))
		"frangipani":
			# Hoa sứ: a short tree with thick branches and leaves at the ends.
			b.cylinder("m", 0.18, 1.6, Vector3(0, 0.8, 0), WOOD, 6, Basis(), false)
			for i in 5:
				var angle := TAU * i / 5.0
				var out := Vector3(cos(angle), 0, sin(angle))
				b.cylinder("m", 0.09, 1.6, Vector3(0, 2.1, 0) + out * 0.5, WOOD, 5,
						Basis(out.cross(Vector3.UP).normalized(), 0.6), false)
				b.box("m", Vector3(1.1, 0.7, 1.1), Vector3(0, 2.9, 0) + out * 1.0, _leaf(0.95), Basis(Vector3.UP, angle))
		"casuarina":
			# Phi lao: a tall, thin tree with a narrow, uneven crown.
			b.cylinder("m", 0.18, 12.0, Vector3(0, 6.0, 0), WOOD, 6, Basis(), false)
			var sizes := [2.6, 2.4, 2.0, 1.6, 1.2, 0.7]
			for i in sizes.size():
				var s: float = sizes[i]
				b.box("m", Vector3(s, 1.6, s), Vector3(0.15 * (i % 2), 4.5 + i * 1.5, 0.1 * (i % 3)), _leaf(0.9 + 0.02 * i),
						Basis(Vector3.UP, i * 0.7))
		"coconut":
			# A curved trunk and long fronds that hang down.
			var top := Vector3.ZERO
			for i in 5:
				var next := Vector3(0.25 * i * i / 4.0, (i + 1) * 1.8, 0)
				var segment := next - top
				var axis := Vector3.UP.cross(segment.normalized())
				var basis := Basis() if axis.length() < 0.001 else Basis(axis.normalized(), Vector3.UP.angle_to(segment))
				b.cylinder("m", 0.17 - i * 0.01, segment.length() + 0.05, (top + next) / 2.0, PALM_WOOD, 6, basis, false)
				top = next
			for i in 9:
				var angle := TAU * i / 9.0
				var out := Vector3(cos(angle), 0, sin(angle))
				var frond := Basis(out.cross(Vector3.UP).normalized(), -0.35) * Basis(Vector3.UP, -angle)
				b.box("m", Vector3(3.2, 0.06, 0.5), top + out * 1.5 + Vector3(0, -0.4, 0), _leaf(0.95), frond)
			b.box("m", Vector3(0.5, 0.4, 0.5), top + Vector3(0, -0.3, 0), Color("#6B5A2E", 0.0))
		"fan_palm":
			# A straight trunk and round fan leaves.
			b.cylinder("m", 0.22, 5.0, Vector3(0, 2.5, 0), PALM_WOOD, 6, Basis(), false)
			for i in 10:
				var angle := TAU * i / 10.0
				var out := Vector3(cos(angle), 0, sin(angle))
				var tilt := Basis(out.cross(Vector3.UP).normalized(), 1.0 + 0.25 * (i % 3))
				b.cylinder("m", 0.9, 0.05, Vector3(0, 5.3 + 0.2 * (i % 2), 0) + out * 0.9, _leaf(0.9 + 0.03 * (i % 3)), 7, tilt)
	var holder := Node3D.new()
	var made: Dictionary = b.commit(holder, {})
	var instance: MeshInstance3D = made["m"]
	var built := instance.mesh
	holder.free()
	_meshes[type] = built
	return built


## A new material for a tree type.
static func material(type: String) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load("res://shaders/tree.gdshader")
	result.set_shader_parameter("leaf_color", LEAF_COLORS.get(type, Color("#466B32")))
	result.set_shader_parameter("flower_color", FLOWER_COLORS.get(type, Color.WHITE))
	return result


## Sets the season values of a material (plan 0005, R12a). "season" comes from Season.of_day().
static func apply_season(type: String, target: ShaderMaterial, season: Dictionary) -> void:
	var dryness: float = season.dryness
	var leaves := 1.0
	var flowers := 0.0
	var bare := 0.0
	var tint := dryness * 0.25
	match type:
		"hill":
			tint = dryness * 0.8
			bare = season.bare_share
			leaves = 1.0 - dryness * 0.25
		"flame":
			leaves = season.flame_leaves
			flowers = season.flame_flowers * 0.7
		"frangipani":
			leaves = 1.0 - dryness * 0.45
			flowers = 0.3
		"casuarina", "coconut", "fan_palm":
			tint = dryness * 0.12
	target.set_shader_parameter("dryness", tint)
	target.set_shader_parameter("leaves", leaves)
	target.set_shader_parameter("flowers", flowers)
	target.set_shader_parameter("bare_share", bare)
