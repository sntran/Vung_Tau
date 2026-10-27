extends RefCounted
# PT-55 tree_wind (plan 0020, R8). Near a coconut palm and a bàng tree on the
# test ground of PT-52: two screenshots 0.5 s apart, in a strong wind and in
# calm air. Checks: the pixels of the crown change between the two
# screenshots, more in the wind than in calm air, and they change also in calm
# air (the leaves flutter a little). The pixels at the base of the trunk do
# not change.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=12:00

const Gallery := preload("res://playtests/tree_gallery.gd")
const TYPES := ["coconut", "bang"]
const DISTANCE := 11.0
## A pixel changed when one channel changed by more than this.
const CHANGE := 0.04
## The crown must have this part of changed pixels, or more (in calm air: CALM_SHARE).
const WIND_SHARE := 0.03
const CALM_SHARE := 0.002
## The base of the trunk: not more than this part of changed pixels.
const BASE_SHARE := 0.01


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null, "the Vũng Tàu world starts with --world=vung_tau"):
		return
	var library := w.trees.library
	Gallery._build_ground(w)
	var indices := {}
	for i in library.names.size():
		indices[library.names[i]] = i
	for type: String in TYPES:
		var t: Array[Transform3D] = [Transform3D(Basis(), Gallery._base(indices[type], 1))]
		var variant: Array[int] = [1]
		w.trees.add_trees(Gallery.SOURCE, type, t, false, variant)
	await d.fly_to(Gallery.ORIGIN + Vector3(0, 30.0, 60.0), Gallery.ORIGIN)
	await d.wait_ground(90.0)
	for type: String in TYPES:
		var info := library.variant_info(type, 1)
		var base := Gallery._base(indices[type], 1)
		var eye := base + Vector3(0, Player.EYE_HEIGHT, DISTANCE)
		var target := base + Vector3(0, float(info.height) * 0.45, 0)
		await d.fly_to(eye, target)
		var crown := {"center": base + Vector3(0, float(info.height) * 0.75, 0), "rx": float(info.radius) * 0.8,
				"ry": float(info.height) * 0.2}
		var trunk := {"center": base + Vector3(0, 0.5, 0), "rx": 0.35, "ry": 0.45}
		var shares := {}
		for air: String in ["wind", "calm"]:
			Wind.hold(Vector2(1.0, 0.3), 0.9 if air == "wind" else 0.0)
			await d.wait_frames(3)
			await d.screenshot("%s_%s_a" % [type, air])
			var first := d.viewport().get_texture().get_image()
			await d.wait_seconds(0.5)
			await d.screenshot("%s_%s_b" % [type, air])
			var second := d.viewport().get_texture().get_image()
			var crown_share := _changed(d, first, second, crown)
			var base_share := _changed(d, first, second, trunk)
			shares[air] = crown_share
			d.step("%s, %s: %.1f %% of the crown pixels and %.1f %% of the trunk base pixels changed in 0.5 s" % [
					type, air, crown_share * 100.0, base_share * 100.0])
			d.expect(crown_share >= (WIND_SHARE if air == "wind" else CALM_SHARE),
					"%s, %s: the crown moves (%.2f %% of its pixels changed)" % [type, air, crown_share * 100.0])
			d.expect(base_share <= BASE_SHARE, "%s, %s: the base of the trunk does not move (%.2f %% changed)" % [
					type, air, base_share * 100.0])
		d.expect(shares.wind > shares.calm, "%s: the crown moves more in the wind than in calm air" % type)
	Wind.held = false
	w.trees.remove_source(Gallery.SOURCE)
	d.fly_end()


## The part of the pixels in the screen box of the area that changed between two images.
static func _changed(d: PlaytestDriver, a: Image, b: Image, area: Dictionary) -> float:
	var box := Gallery._crown_box(d, area)
	var scale := Vector2(a.get_size()) / d.viewport().get_visible_rect().size
	var from := Vector2i((box.position * scale).floor())
	var to := Vector2i((box.end * scale).floor())
	var total := 0
	var changed := 0
	for y in range(maxi(from.y, 0), mini(to.y, a.get_height())):
		for x in range(maxi(from.x, 0), mini(to.x, a.get_width())):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			total += 1
			if maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) > CHANGE:
				changed += 1
	return changed / maxf(total, 1.0)
