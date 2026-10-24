class_name Subtitles
extends PanelContainer
## The subtitle box at the bottom of the screen (plan 0003, R12 to R14).
##
## It shows a spoken line in parts (SubtitleText), with the speaker name in
## the speaker color, while the audio plays and 0.6 s more. It also shows
## sound captions such as "[lóc cóc]". It does not stop taps on the world.

## The text changed: the main scene places the box again in the same frame.
signal text_changed

## The subtitle stays this long after the audio.
const HOLD_SECONDS := 0.6
## The text height at the 720 px base height (R13: 31 px or more).
const FONT_SIZE := 32
const CAPTION_SECONDS := 1.6

## The current subtitle: {speaker, lines, line_id} or an empty dictionary.
var current: Dictionary = {}
## The most characters in a line: 38 (R13), or fewer when the screen is narrow.
var max_chars := SubtitleText.MAX_CHARS
var _label: RichTextLabel
var _parts: Array[Dictionary] = []
var _times: PackedFloat32Array = []
var _index := -1
var _left := 0.0
var _caption_left := 0.0
var _speaker := ""
var _color := Color.WHITE
var _line_id := ""
var _size_scale := 1.0
var _style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0, 0, 0, 0.75)
	_style.set_corner_radius_all(10)
	_style.content_margin_left = 18
	_style.content_margin_right = 18
	_style.content_margin_top = 8
	_style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", _style)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("default_color", Color.WHITE)
	_label.add_theme_constant_override("outline_size", 0)
	add_child(_label)
	set_text_size(1.0)
	visible = false


## Sets the text size (R13: a setting makes it larger) and the box opacity.
func apply_settings(size_scale: float, box_opacity: float) -> void:
	set_text_size(size_scale)
	_style.bg_color = Color(0, 0, 0, box_opacity)


func set_text_size(size_scale: float) -> void:
	_size_scale = size_scale
	var font_size := int(round(FONT_SIZE * size_scale))
	for key: String in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		_label.add_theme_font_size_override(key, font_size)


## The text height in base pixels.
func text_height() -> float:
	return FONT_SIZE * _size_scale


## The mean width of a character of the subtitle text, in base pixels.
func char_width() -> float:
	var font := _label.get_theme_font("normal_font")
	var sample := "Ủa, con dậy rồi hả? Ăn sáng chưa con? Not yet."
	return font.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(FONT_SIZE * _size_scale))).x / sample.length()


## The width of the box for the text that shows now, from the font sizes.
func box_width() -> float:
	var font := _label.get_theme_font("bold_font")
	var font_size := int(round(FONT_SIZE * _size_scale))
	var widest := 0.0
	var lines: PackedStringArray = current.get("lines", PackedStringArray())
	for i in lines.size():
		var text: String = lines[i]
		if i == 0 and current.get("speaker", "") != "":
			text = "%s: %s" % [current.speaker, text]
		widest = maxf(widest, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return ceilf(widest) + padding() + 2.0


## The width of the box around the text, without the text.
func padding() -> float:
	return _style.content_margin_left + _style.content_margin_right


## Shows a spoken line. "mode" is "vi", "en", "both", or "off". "seconds" is
## the length of the audio.
func show_line(line_id: String, speaker: String, color: Color, vi: String, en: String, mode: String,
		seconds: float) -> void:
	_caption_left = 0.0
	if mode == "off":
		clear()
		return
	var prefix := speaker.length() + 2
	match mode:
		"en":
			_parts = SubtitleText.parts(en, prefix, SubtitleText.MAX_LINES, max_chars)
		"both":
			_parts = SubtitleText.parts_both(vi, en, prefix, max_chars)
		_:
			_parts = SubtitleText.parts(vi, prefix, SubtitleText.MAX_LINES, max_chars)
	_times = SubtitleText.durations(_parts, seconds)
	_times[_times.size() - 1] += HOLD_SECONDS
	_speaker = speaker
	_color = color
	_line_id = line_id
	_index = -1
	_next_part()


## Shows a sound caption, for example "[lóc cóc]", when no line shows.
func show_caption(text: String) -> void:
	if text == "" or (_index >= 0 and _left > 0.0):
		return
	_caption_left = CAPTION_SECONDS
	current = {"speaker": "", "lines": PackedStringArray([text]), "line_id": "", "caption": true}
	_label.text = "[i]%s[/i]" % _escape(text)
	visible = true
	text_changed.emit()


func clear() -> void:
	_parts = []
	_index = -1
	_left = 0.0
	_caption_left = 0.0
	current = {}
	visible = false


func _next_part() -> void:
	_index += 1
	if _index >= _parts.size():
		clear()
		return
	_left = _times[_index]
	var lines: PackedStringArray = _parts[_index].lines
	current = {"speaker": _speaker, "lines": lines, "line_id": _line_id, "caption": false}
	var name_text := "[color=#%s][b]%s:[/b][/color] " % [_lighter(_color).to_html(false), _escape(_speaker)]
	var shown := PackedStringArray()
	for i in lines.size():
		shown.append((name_text if i == 0 else "") + _escape(lines[i]))
	_label.text = "\n".join(shown)
	visible = true
	text_changed.emit()


func _process(delta: float) -> void:
	if _index >= 0:
		_left -= delta
		if _left <= 0.0:
			_next_part()
	elif _caption_left > 0.0:
		_caption_left -= delta
		if _caption_left <= 0.0:
			clear()


## True while a spoken line shows.
func is_showing_line() -> bool:
	return _index >= 0


## A speaker color that is easy to read on the dark box.
static func _lighter(color: Color) -> Color:
	return color if color.get_luminance() > 0.45 else color.lightened(0.45)


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
