extends RefCounted
# PT-03 spots_by_time. For each start time 05:50, 11:00, 15:00, 18:30, and
# 21:40: tap each spot that is present. Check that the dialogue line ID is
# the correct one for that spot and time. Check that a cart that is not
# present cannot be tapped and is not shown as near. Screenshot each spot.
# At each start time, also check the shutters (R19) and the boats (R17).
# phase: --start-time=05:50
# phase: --start-time=11:00 --fresh-save
# phase: --start-time=15:00 --fresh-save
# phase: --start-time=18:30 --fresh-save
# phase: --start-time=21:40 --fresh-save

## The expected line for each spot at each start time. "" means that the cart is not there.
const EXPECTED := {
	1: {"home": "spot.home.look", "pho": "spot.pho.open", "banhmi": "spot.banhmi.look",
		"coc": "spot.coc.look", "bac": "spot.bac.closed", "mia": "", "go": "",
		"banhkhot": "spot.banhkhot.closed", "hvl": "", "beach": "spot.beach.dawn"},
	2: {"home": "spot.home.look", "pho": "spot.pho.sold_out", "banhmi": "",
		"coc": "spot.coc.look", "bac": "spot.bac.closed", "mia": "spot.mia.look", "go": "",
		"banhkhot": "spot.banhkhot.look", "hvl": "", "beach": "spot.beach.day"},
	3: {"home": "spot.home.look", "pho": "spot.pho.closed_after", "banhmi": "",
		"coc": "spot.coc.look", "bac": "spot.bac.closed", "mia": "spot.mia.look", "go": "",
		"banhkhot": "spot.banhkhot.look", "hvl": "spot.hvl.look", "beach": "spot.beach.day"},
	4: {"home": "spot.home.look", "pho": "spot.pho.closed_after", "banhmi": "",
		"coc": "spot.coc.look", "bac": "spot.bac.closed", "mia": "", "go": "spot.go.look",
		"banhkhot": "spot.banhkhot.look", "hvl": "spot.hvl.look", "beach": "spot.beach.evening"},
	5: {"home": "spot.home.look", "pho": "spot.pho.closed_after", "banhmi": "",
		"coc": "spot.coc.look", "bac": "spot.bac.closed", "mia": "", "go": "spot.go.look",
		"banhkhot": "spot.banhkhot.closed", "hvl": "spot.hvl.look", "beach": "spot.beach.night"},
}
## The shutter positions and the boats at each start time (R17, R19).
const START_VIEW := {
	1: {"shutters": {"pho": "open", "bac": "closed", "banhkhot": "closed"}, "boats_in": true},
	2: {"shutters": {"pho": "half", "bac": "closed", "banhkhot": "open"}, "boats_in": false},
	3: {"shutters": {"pho": "closed", "bac": "closed", "banhkhot": "open"}, "boats_in": false},
	4: {"shutters": {"pho": "closed", "bac": "closed", "banhkhot": "open"}, "boats_in": false},
	5: {"shutters": {"pho": "closed", "bac": "closed", "banhkhot": "closed"}, "boats_in": false},
}
## The spots in the order along the hẻm.
const ORDER := ["home", "pho", "banhmi", "coc", "bac", "mia", "go", "banhkhot", "hvl", "beach"]


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	await d.tap_id("choice.step_outside")
	await d.tap_id("choice.good_morning")
	await d.tap_id("choice.okay")
	await d.wait_idle()
	await d.screenshot("start")
	var view: Dictionary = START_VIEW[d.phase]
	var s0 := d.state()
	d.expect(s0.shutters == view.shutters, "at %s the shutters are %s, not %s" % [s0.time_text, s0.shutters, view.shutters])
	d.expect(s0.boats_in == view.boats_in and s0.exercisers == view.boats_in,
			"at %s the boats on the sand and the people: %s, not %s" % [s0.time_text, s0.boats_in, view.boats_in])
	var expected: Dictionary = EXPECTED[d.phase]
	var hem: Node = d.main().hem
	for spot_id: String in ORDER:
		var line: String = expected[spot_id]
		var stand: Vector3 = hem.stand_points[spot_id]
		if line == "":
			await _check_absent(d, spot_id, stand)
			continue
		if not await d.bring_into_view("spot." + spot_id):
			continue
		if not await d.tap_id("spot." + spot_id):
			continue
		await d.wait_idle()
		var s := d.state()
		d.expect(s.line == line, "%s at %s: the line is %s, it must be %s" % [spot_id, s.time_text, s.line, line])
		await d.screenshot(spot_id)
		await _back_to_hem(d)


## A cart that is not there cannot be tapped and is not shown as near.
func _check_absent(d: PlaytestDriver, spot_id: String, stand: Vector3) -> void:
	var error: String = await d.try_tap_id("spot." + spot_id)
	d.expect(error != "", "the cart %s is not there, but a tap on it is possible" % spot_id)
	# Walk to the place of the cart with floor taps.
	await d.walk_toward(stand.x, stand.z)
	var s := d.state()
	d.expect(s.near_spot != spot_id, "the cart %s is not there, but the panel shows it as near" % spot_id)
	d.expect(s.line != "" and not s.line.begins_with("spot.%s." % spot_id), "the panel shows a line of the cart %s" % spot_id)
	await d.screenshot("no_" + spot_id)


func _back_to_hem(d: PlaytestDriver) -> void:
	var choices: Array = d.state().choices
	for id: String in ["choice.okay", "choice.go_out"]:
		if choices.has(id):
			await d.tap_id(id)
			await d.wait_frames(3)
			return
	d.fail("no choice goes back to the hẻm: %s" % [choices])
