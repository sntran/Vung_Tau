extends GutTest
## Tests for the subtitle split (plan 0003, R13).


func _assert_rules(parts: Array[Dictionary], prefix: int, max_lines := 2) -> void:
	for part in parts:
		var lines: PackedStringArray = part.lines
		assert_true(lines.size() <= max_lines, "two lines at most: %s" % lines)
		for i in lines.size():
			var length := lines[i].length() + (prefix if i == 0 else 0)
			assert_true(length <= SubtitleText.MAX_CHARS, "38 characters at most: \"%s\" (%d)" % [lines[i], length])


func test_a_short_line_is_one_part() -> void:
	var parts := SubtitleText.parts("Vô đây con, ngồi đi!", 8)
	assert_eq(parts.size(), 1)
	assert_eq(parts[0].lines, PackedStringArray(["Vô đây con, ngồi đi!"]))


func test_two_lines_are_balanced() -> void:
	var lines := SubtitleText.wrap_lines("Trời, con nói tiếng Việt giỏi quá! Qua Cô Sáu ăn", 0, 38)
	assert_eq(lines.size(), 2)
	assert_true(absi(lines[0].length() - lines[1].length()) < 12, "balanced: %s" % lines)


func test_a_long_line_splits_at_the_sentences() -> void:
	var text := "Trời, con nói tiếng Việt giỏi quá! Qua Cô Sáu ăn tô phở đi con, kẻo hết."
	var parts := SubtitleText.parts(text, 7)
	assert_eq(parts.size(), 2)
	assert_true(" ".join(parts[0].lines).ends_with("quá!"), "the first part ends at the sentence: %s" % parts[0].lines)
	_assert_rules(parts, 7)


func test_a_long_sentence_splits_at_the_phrases_then_the_words() -> void:
	var text := "Một hai ba bốn năm sáu bảy tám chín mười, một hai ba bốn năm sáu bảy tám chín mười một hai ba bốn năm sáu bảy tám chín mười"
	var parts := SubtitleText.parts(text, 9)
	assert_true(parts.size() >= 2)
	_assert_rules(parts, 9)
	var joined := " ".join(parts.map(func(part: Dictionary) -> String: return " ".join(part.lines)))
	assert_eq(joined, text, "no word is lost")


func test_each_real_line_follows_the_rules() -> void:
	for line_id: String in Content.dialogue.lines:
		var line := Content.line(line_id)
		if not line.has("speaker"):
			continue
		var prefix: int = Content.speaker(line.speaker).name.length() + 2
		_assert_rules(SubtitleText.parts(line.vi, prefix), prefix)
		_assert_rules(SubtitleText.parts(line.en, prefix), prefix)
		var both := SubtitleText.parts_both(line.vi, line.en, prefix)
		for part in both:
			assert_eq(part.lines.size(), 2, "both: a Vietnamese line and an English line")
			assert_true(part.lines[0].length() + prefix <= SubtitleText.MAX_CHARS, "both: %s" % part.lines)
			assert_true(part.lines[1].length() <= SubtitleText.MAX_CHARS, "both: %s" % part.lines)


func test_a_narrow_screen_has_shorter_lines() -> void:
	var parts := SubtitleText.parts("Con đi chơi vui không? Có gì cứ nhắn cô nghen.", 8, 2, 22)
	for part in parts:
		for i in part.lines.size():
			assert_true(part.lines[i].length() + (8 if i == 0 else 0) <= 22, "%s" % part.lines)


func test_the_time_of_each_part_is_in_proportion_to_its_length() -> void:
	var parts: Array[Dictionary] = [{"lines": PackedStringArray(["a"]), "weight": 10},
			{"lines": PackedStringArray(["b"]), "weight": 30}]
	var times := SubtitleText.durations(parts, 4.0)
	assert_almost_eq(times[0], 1.0, 0.001)
	assert_almost_eq(times[1], 3.0, 0.001)


func test_tone_of_a_syllable() -> void:
	assert_eq(ListenApp.tone_of("Dạ,"), "nặng")
	assert_eq(ListenApp.tone_of("chưa"), "ngang")
	assert_eq(ListenApp.tone_of("rồi"), "huyền")
	assert_eq(ListenApp.tone_of("sáng"), "sắc")
	assert_eq(ListenApp.tone_of("hả?"), "hỏi")
	assert_eq(ListenApp.tone_of("Sữa"), "ngã")
