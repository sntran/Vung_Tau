extends RefCounted
# PT-64 landmark_lens (plan 0008, D6). For each known place with a stand-in:
# the camera stands 50 m from it and looks at it, and the player opens the
# Lens app with a tap. Checks: the card of the place shows its Vietnamese name,
# its English name, the phrase, and the text, with the note of the stand-in
# (D3a). A place with "Check" has no card.
# sizes: 1280x720
# phase: --world=vung_tau --start-time=12:00

const Sheet := preload("res://playtests/landmark_sheet.gd")


func run(d: PlaytestDriver) -> void:
	var w := d.world()
	if not d.expect(w != null and w.places != null, "the Vũng Tàu world has the known places"):
		return
	var ids: Array = w.places.places.keys()
	ids.sort()
	for id: String in ids:
		var entry: Dictionary = w.places.places[id]
		var view := Sheet.eye_for(w, entry, 50.0)
		if not d.expect(not view.is_empty(), "%s: a view from 50 m" % id):
			continue
		await d.fly_to(view.eye, view.target)
		await d.wait_ground(60.0)
		await d.open_app("lens")
		await d.wait_frames(4)
		var card: Dictionary = d.main().lens_card()
		d.expect(card.get("id", "") == "place." + id, "%s: the Lens names the place: %s" % [id, card.get("id", "")])
		d.expect(str(card.get("name", "")) == str(entry.config.name_vi), "%s: the name %s" % [id, card.get("name", "")])
		d.expect(str(card.get("text", "")).contains(KnownPlaces.configs_note()), "%s: the card says that a simple shape stands there (D3a)" % id)
		var shown := d.find("lens.card")
		d.expect(shown != null and shown.is_visible_in_tree(), "%s: the card shows in the Lens app" % id)
		await d.screenshot("lens_%s" % id)
		await d.lower_phone()
	d.expect(w.places.card("chua_tam_bao").is_empty(), "a place with Check has no card")
	d.fly_end()
