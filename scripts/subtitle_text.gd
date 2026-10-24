class_name SubtitleText
extends RefCounted
## Splits a spoken line into subtitle parts (plan 0003, R13).
##
## A part has two lines at most, with MAX_CHARS characters or fewer in each
## line (fewer when the screen is narrow). The speaker name and ": " are on the first line of each part, so
## they count too. A long line splits at the sentences first, then at the
## phrases (a comma, a semicolon, a colon, or a dash), then at the words.
## Each part shows for a time in proportion to its length.

const MAX_CHARS := 38
const MAX_LINES := 2
const SENTENCE_ENDS := ".!?…"
const PHRASE_ENDS := ",;:—–"

## The line length of the split that runs now: MAX_CHARS, or fewer on a
## narrow screen.
static var _limit := MAX_CHARS


## Returns the parts of the text: a list of {lines: PackedStringArray, weight: int}.
## "prefix" is the length of the speaker name and ": " on the first line.
static func parts(text: String, prefix := 0, max_lines := MAX_LINES, max_chars := MAX_CHARS) -> Array[Dictionary]:
	_limit = mini(max_chars, MAX_CHARS)
	var units: Array[String] = []
	for sentence in _split_after(text.strip_edges(), SENTENCE_ENDS):
		if wrap_lines(sentence, prefix).size() <= max_lines:
			units.append(sentence)
			continue
		for phrase in _split_after(sentence, PHRASE_ENDS):
			if wrap_lines(phrase, prefix).size() <= max_lines:
				units.append(phrase)
			else:
				units.append_array(_word_chunks(phrase, prefix, max_lines))
	var result: Array[Dictionary] = []
	var current := ""
	for unit in units:
		var joined := unit if current == "" else current + " " + unit
		if current != "" and wrap_lines(joined, prefix).size() > max_lines:
			result.append(_part(current, prefix))
			current = unit
		else:
			current = joined
	if current != "":
		result.append(_part(current, prefix))
	return result


## The parts for the "both" setting: each part has one Vietnamese line and
## one English line. The two texts split into the same number of parts.
static func parts_both(vi: String, en: String, prefix := 0, max_chars := MAX_CHARS) -> Array[Dictionary]:
	_limit = mini(max_chars, MAX_CHARS)
	var vi_words := vi.strip_edges().split(" ", false)
	var en_words := en.strip_edges().split(" ", false)
	for count in range(1, 40):
		var vi_lines := _split_words(vi_words, count, prefix)
		var en_lines := _split_words(en_words, count, 0)
		if vi_lines.is_empty() or en_lines.is_empty():
			continue
		var result: Array[Dictionary] = []
		for i in count:
			result.append({"lines": PackedStringArray([vi_lines[i], en_lines[i]]), "weight": maxi(1, vi_lines[i].length())})
		return result
	return [{"lines": PackedStringArray([vi, en]), "weight": 1}]


## Wraps the text into lines of the line length or fewer characters. The first line
## has "prefix" characters less. Two lines are balanced when they can be.
static func wrap_lines(text: String, prefix := 0, max_chars := -1) -> PackedStringArray:
	if max_chars > 0:
		_limit = mini(max_chars, MAX_CHARS)
	var words := text.strip_edges().split(" ", false)
	if words.is_empty():
		return PackedStringArray([""])
	var whole := " ".join(words)
	if whole.length() + prefix <= _limit:
		return PackedStringArray([whole])
	# Two lines: the break that makes the longer line shortest.
	var best := -1
	var best_width := INF
	for i in range(1, words.size()):
		var first := " ".join(words.slice(0, i))
		var second := " ".join(words.slice(i))
		if first.length() + prefix <= _limit and second.length() <= _limit:
			var width := maxf(first.length() + prefix, second.length())
			if width < best_width:
				best_width = width
				best = i
	if best > 0:
		return PackedStringArray([" ".join(words.slice(0, best)), " ".join(words.slice(best))])
	# More lines: fill each line.
	var lines := PackedStringArray()
	var line := ""
	var budget := _limit - prefix
	for word in words:
		var next := word if line == "" else line + " " + word
		if line != "" and next.length() > budget:
			lines.append(line)
			line = word
			budget = _limit
		else:
			line = next
	lines.append(line)
	return lines


static func _part(text: String, prefix: int) -> Dictionary:
	return {"lines": wrap_lines(text, prefix), "weight": maxi(1, text.length())}


## Splits after each character of "ends" that comes before a space.
static func _split_after(text: String, ends: String) -> PackedStringArray:
	var result := PackedStringArray()
	var start := 0
	for i in text.length():
		if ends.contains(text[i]) and (i + 1 == text.length() or text[i + 1] == " "):
			var piece := text.substr(start, i + 1 - start).strip_edges()
			if piece != "":
				result.append(piece)
			start = i + 1
	var rest := text.substr(start).strip_edges()
	if rest != "":
		result.append(rest)
	return result


## Splits a phrase that is too long into pieces of "max_lines" lines.
static func _word_chunks(text: String, prefix: int, max_lines: int) -> Array[String]:
	var result: Array[String] = []
	var current := ""
	for word in text.split(" ", false):
		var next := word if current == "" else current + " " + word
		if current != "" and wrap_lines(next, prefix).size() > max_lines:
			result.append(current)
			current = word
		else:
			current = next
	if current != "":
		result.append(current)
	return result


## Splits the words into exactly "count" lines that fit (the first line has
## "prefix" characters less). The lines are as even as possible. Returns an
## empty list when the words do not fit in "count" lines.
static func _split_words(words: PackedStringArray, count: int, prefix: int) -> PackedStringArray:
	if words.size() < count:
		return PackedStringArray()
	# The narrowest width that fits the words in "count" lines or fewer.
	var width := -1
	for w in range(1, _limit + 1):
		var lines := _fill(words, w, prefix)
		if not lines.is_empty() and lines.size() <= count:
			width = w
			break
	if width < 0:
		return PackedStringArray()
	var result := _fill(words, width, prefix)
	# Fewer lines than "count": split the line with the most words.
	while result.size() < count:
		var longest := -1
		for i in result.size():
			if result[i].contains(" ") and (longest < 0 or result[i].length() > result[longest].length()):
				longest = i
		if longest < 0:
			return PackedStringArray()
		var line_words := result[longest].split(" ")
		var half := line_words.size() / 2
		result.remove_at(longest)
		result.insert(longest, " ".join(line_words.slice(half)))
		result.insert(longest, " ".join(line_words.slice(0, half)))
	return result


## Fills lines of "width" characters or fewer (the first line: "prefix" less).
## Returns an empty list when a word is too long.
static func _fill(words: PackedStringArray, width: int, prefix: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	var budget := width - prefix
	for word in words:
		var next := word if line == "" else line + " " + word
		if next.length() <= budget:
			line = next
			continue
		if line == "":
			return PackedStringArray()
		lines.append(line)
		line = word
		budget = width
		if line.length() > budget:
			return PackedStringArray()
	lines.append(line)
	return lines


## The time of each part: the duration of the audio in proportion to the length of each part.
static func durations(part_list: Array[Dictionary], total: float) -> PackedFloat32Array:
	var sum := 0
	for part in part_list:
		sum += int(part.weight)
	var result := PackedFloat32Array()
	for part in part_list:
		result.append(total * float(part.weight) / maxf(1.0, float(sum)))
	return result
