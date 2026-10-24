extends RefCounted
# PT-22 subtitle_rules (plan 0003, R13). Play every spoken line in the
# subtitle box. For each part of each subtitle: two lines or fewer, 38
# characters or fewer in each line (with the speaker name), text height at
# least 31 px at the base height, fully on the screen, not under the phone or
# the joystick zone. Check each subtitle language setting. The phone is up
# for the first half of the lines. The parts play 4 times faster than the
# audio. The scenario has 2 runs (2 settings in each run), so that each run is
# shorter than 180 s at 2400×1080 under lavapipe.
# sizes: 1280x720 2400x1080
# phase: --start-time=06:00
# phase: --start-time=06:00

const SPEED := 4.0
const MODES := {1: ["vi", "en"], 2: ["both", "off"]}


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	var m: Node = d.main()
	var subtitles: Subtitles = m.subtitles
	var lines: Array[String] = []
	for line_id: String in Content.dialogue.lines:
		if Content.is_speech(line_id):
			lines.append(line_id)
	for mode: String in MODES[d.phase]:
		# The setting changes in the Settings app.
		await d.open_app("settings")
		while d.state().settings.subtitles != mode:
			await d.tap_phone_id("settings.subtitles")
		var parts := 0
		var problems := {}
		for i in lines.size():
			if i == 0:
				await d.raise_phone()
			elif i == lines.size() / 2:
				await d.lower_phone()
			var line := Content.line(lines[i])
			var speaker := Content.speaker(line.speaker)
			subtitles.show_line(lines[i], speaker.name, Color(speaker.color), line.vi, line.en,
					GameState.settings.subtitles, Content.clip_duration(lines[i]) / SPEED)
			await d.wait_frames(2)
			if mode == "off":
				if subtitles.visible:
					problems["a subtitle shows with the setting off"] = true
				continue
			var last: Variant = null
			while subtitles.is_showing_line():
				var current: Dictionary = subtitles.current
				if current.lines != last:
					last = current.lines
					parts += 1
					await d.wait_frames(1)
					for problem in _check(d, subtitles, speaker.name):
						problems["%s: %s" % [lines[i], problem]] = true
				await d.wait_frames(1)
			if i == 0:
				await d.screenshot("subtitle_%s" % mode)
		for problem: String in problems:
			d.fail("subtitles %s: %s" % [mode, problem])
		d.step("subtitles %s: %d lines, %d parts" % [mode, lines.size(), parts])


## The rules of R13 for the part that shows now.
func _check(d: PlaytestDriver, subtitles: Subtitles, speaker: String) -> Array[String]:
	var result: Array[String] = []
	var s := d.state()
	var part: PackedStringArray = subtitles.current.lines
	if part.size() > 2:
		result.append("%d lines: %s" % [part.size(), part])
	for i in part.size():
		var text := ("%s: %s" % [speaker, part[i]]) if i == 0 else part[i]
		if text.length() > SubtitleText.MAX_CHARS:
			result.append("a line has %d characters: \"%s\"" % [text.length(), text])
	if subtitles.text_height() < 31.0:
		result.append("the text is %.0f px high" % subtitles.text_height())
	var rect: Rect2 = subtitles.get_global_rect()
	if not PlaytestLayout.inside(Rect2(Vector2.ZERO, s.view_size), rect):
		result.append("the box is not fully on the screen: %s" % rect)
	if s.phone_up and rect.intersects(s.phone_rect):
		result.append("the box is under the phone")
	if rect.intersects(s.phone_button_rect):
		result.append("the box is under the phone button")
	if rect.intersects(s.stick_zone):
		result.append("the box is in the joystick zone")
	return result
