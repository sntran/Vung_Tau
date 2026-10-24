extends RefCounted
# PT-12 fp_collision. Push into each house wall, each cart, each palm tree, and
# the beach wall for 3 s. After each push, the capsule must not intersect a
# collision shape. The player must stay on the floor. Look at a wall from
# 0.3 m. The screenshot must not show the inside of the wall.
# Runs 1 to 3: the house walls of the hẻm and the bánh mì cart (06:00). Run 4:
# the beach wall, the palm trees, and the water. Runs 5 and 6: the carts of
# 15:00 (nước mía, hột vịt lộn) and of 18:30 (hủ tiếu gõ). Runs 7 and 8: the
# other walls. Each run has few pushes, so that it is shorter than 180 s at
# 2400×1080 on a slow computer.
# phase: --start-time=06:00
# phase: --start-time=06:00 --fresh-save
# phase: --start-time=06:00 --fresh-save
# phase: --start-time=06:00 --fresh-save
# phase: --start-time=15:00 --fresh-save
# phase: --start-time=18:30 --fresh-save
# phase: --start-time=12:00 --fresh-save
# phase: --start-time=12:00 --fresh-save

const CARTS := {1: ["banhmi"], 5: ["mia", "hvl"], 6: ["go"]}
## The house walls of the main row (not the open shops) in runs 1 to 3.
const WALL_RUNS := {1: [0, 1], 2: [1, 3], 3: [3, 99]}


func run(d: PlaytestDriver) -> void:
	await d.skip_intro()
	var hem: Node = d.main().hem
	var half: float = hem.hem_width / 2.0
	for spot_id: String in CARTS.get(d.phase, []):
		var cart: Node3D = hem.carts[spot_id]
		var from := Vector3(cart.global_position.x, 0, 0.6)
		await _push(d, "cart " + spot_id, from, cart.global_position + Vector3(0, 1.0, 0))
	if d.phase == 4:
		await _beach(d)
	if WALL_RUNS.has(d.phase):
		# The house walls of the main row (not the open shops).
		var walls := Content.layout.lots.filter(func(lot: Dictionary) -> bool:
			return not (lot.has("spot") and lot.ground == "shop"))
		var part: Array = WALL_RUNS[d.phase]
		for lot: Dictionary in walls.slice(part[0], part[1]):
			var x: float = hem.lot_x[lot.id]
			await _push(d, "wall of " + lot.id, Vector3(x + 0.8, 0, 0), Vector3(x + 0.8, 1.6, -half))
	if d.phase == 7:
		# The opposite row and the end wall.
		var opposite_x: float = hem.start_x + 6.0
		await _push(d, "opposite wall", Vector3(opposite_x, 0, 0), Vector3(opposite_x, 1.6, half))
		await _push(d, "end wall", Vector3(hem.start_x + 1.5, 0, 0), Vector3(hem.start_x - 1.0, 1.6, 0))
	if d.phase != 8:
		return
	# A closed shutter and the back wall of an open shop room.
	var pho_x: float = hem.lot_x["pho_co_sau"]
	await _push(d, "closed shutter", Vector3(pho_x - 1.0, 0, 0), Vector3(pho_x - 1.0, 1.6, -half))
	var banhkhot_x: float = hem.lot_x["banhkhot"]
	await _push(d, "back of open room", Vector3(banhkhot_x - 0.6, 0, 0), Vector3(banhkhot_x - 0.6, 1.6, -half - 6.0))
	# Look at a wall from 0.3 m: the camera does not go into the wall.
	var s := d.state()
	var to_wall := d.view_distance_to_solid()
	d.expect(to_wall >= Player.RADIUS - 0.05, "the eyes stay out of the wall: %.3f m" % to_wall)
	await d.screenshot("wall_close")


## The beach wall, then the palm trees on the sand, then the water.
func _beach(d: PlaytestDriver) -> void:
	var hem: Node = d.main().hem
	var s := d.state()
	var road_x: float = hem.end_x + 4.5
	await d.stick_to(Vector3(road_x, 0, 0))
	var wall_x: float = hem.end_x + hem.beach.road_width
	await _push(d, "beach wall", Vector3(road_x, 0, 4.0), Vector3(wall_x + 1.0, 1.0, 4.0))
	await d.stick_to(Vector3(wall_x + 0.5, 0, 0))
	await d.stick_to(Vector3(wall_x + 3.5, Beach.SAND_Y, 0))
	for palm: Vector3 in [Vector3(wall_x + 1.7, Beach.SAND_Y, -3.2), Vector3(wall_x + 2.3, Beach.SAND_Y, 3.6)]:
		await _push(d, "palm", Vector3(wall_x + 4.0, Beach.SAND_Y, palm.z), palm + Vector3(0, 1.6, 0))
	# The edge of the water.
	await _push(d, "water edge", Vector3(wall_x + 11.0, Beach.SAND_Y, 0.0),
			Vector3(wall_x + 40.0, Beach.SAND_Y + 1.6, 0.0))
	s = d.state()
	d.expect(s.player.x < wall_x + hem.beach.sand_width, "the player cannot walk into the sea")


## Walks to "from" with the joystick, looks at "target", and pushes with the joystick for 3 s.
func _push(d: PlaytestDriver, what: String, from: Vector3, target: Vector3) -> void:
	await d.stick_to(from)
	await d.look_at_point(target, 3.0)
	await d.hold_stick(Vector2(0, -1), 3.0)
	await d.wait_idle()
	var s := d.state()
	var overlaps := d.player_overlaps()
	d.expect(overlaps.is_empty(), "%s: the capsule goes into %s" % [what, overlaps])
	d.expect(s.on_floor, "%s: the player is on the floor" % what)
	d.expect(d.view_distance_to_solid() >= Player.RADIUS - 0.05, "%s: the eyes are too near the wall" % what)
	await d.screenshot("push_" + what.replace(" ", "_"))
