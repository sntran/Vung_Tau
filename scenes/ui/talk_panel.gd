class_name TalkPanel
extends PanelContainer
## The talk panel: the speaker name in a colored label, the text, the
## Vietnamese phrases with their English meaning, the choices as large
## buttons, and an optional hint.
##
## The main scene sets the position and the width of the panel. The panel
## tells the height that it needs with needed_height().

signal choice_pressed(index: int)

const MARGIN := 24

var line_id := ""
var choice_ids: Array[String] = []
var scroll: ScrollContainer
var content: VBoxContainer
var _speaker_box: PanelContainer
var _speaker_label: Label
var _text: RichTextLabel
var _phrases: VBoxContainer
var _choices: VBoxContainer
var _hint: Label


func _ready() -> void:
	theme_type_variation = "TalkPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	margin.add_theme_constant_override("margin_top", MARGIN - 4)
	add_child(margin)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	_speaker_box = PanelContainer.new()
	_speaker_box.name = "Speaker"
	_speaker_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_speaker_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_speaker_box)
	_speaker_label = Label.new()
	_speaker_label.theme_type_variation = "Speaker"
	_speaker_box.add_child(_speaker_label)

	_text = RichTextLabel.new()
	_text.name = "Text"
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_text)

	_phrases = VBoxContainer.new()
	_phrases.name = "Phrases"
	_phrases.add_theme_constant_override("separation", 8)
	content.add_child(_phrases)

	_choices = VBoxContainer.new()
	_choices.name = "Choices"
	_choices.add_theme_constant_override("separation", 12)
	content.add_child(_choices)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.theme_type_variation = "Hint"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_hint)


## Shows a line. "view" has: line_id, speaker (name), speaker_color, text
## (BBCode), phrases (list of {vi, en}), hint, and choices (list of
## {id, label, sub, style}).
func show_line(view: Dictionary) -> void:
	line_id = view.get("line_id", "")
	var speaker_name: String = view.get("speaker", "")
	_speaker_box.visible = speaker_name != ""
	if speaker_name != "":
		_speaker_label.text = speaker_name.to_upper()
		var style := StyleBoxFlat.new()
		style.bg_color = view.get("speaker_color", UiTheme.JADE)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		_speaker_box.add_theme_stylebox_override("panel", style)
	_text.text = view.get("text", "")

	for child in _phrases.get_children():
		child.queue_free()
	for phrase: Dictionary in view.get("phrases", []):
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		var vi := Label.new()
		vi.theme_type_variation = "Vietnamese"
		vi.text = phrase.vi
		vi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(vi)
		var en := Label.new()
		en.theme_type_variation = "English"
		en.text = phrase.en
		en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(en)
		_phrases.add_child(box)
	_phrases.visible = not view.get("phrases", []).is_empty()

	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	choice_ids = []
	var choices: Array = view.get("choices", [])
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var button := TextButton.new()
		button.name = "Choice_%s" % choice.id
		button.set_meta("test_id", "choice.%s" % choice.id)
		match choice.get("style", ""):
			"primary":
				button.set_style("PrimaryButton")
			"quiet":
				button.set_style("QuietButton")
			_:
				button.set_style("Button")
		button.set_texts(choice.label, choice.get("sub", ""))
		button.pressed.connect(choice_pressed.emit.bind(i))
		_choices.add_child(button)
		choice_ids.append("choice.%s" % choice.id)
	var hint: String = view.get("hint", "")
	_hint.text = hint
	_hint.visible = hint != ""
	scroll.scroll_vertical = 0


## Returns the height that the panel needs to show all content without a scroll bar.
func needed_height() -> float:
	return content.get_combined_minimum_size().y + MARGIN * 2.0 + 6.0
