class_name TextButton
extends Button
## A button with a main text and an optional smaller second text below it.
## The texts wrap to the button width. The button grows to show all lines,
## and it is never lower than 88 px at the 720 px base width.

var main_label: Label
## A font for the main text. When it is null, the font of the style is used.
var main_font: Font
var sub_label: Label
var _box: VBoxContainer
var _margin := Vector2(20, 10)


func _init() -> void:
	custom_minimum_size.y = UiTheme.BUTTON_MIN_HEIGHT
	clip_text = false
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The text box follows the button size through its anchors.
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.add_theme_constant_override("separation", 2)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_box)
	main_label = Label.new()
	main_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(main_label)
	sub_label = Label.new()
	sub_label.theme_type_variation = "ButtonSub"
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_label.visible = false
	_box.add_child(sub_label)
	resized.connect(_fit)


## Sets the texts. "align" is the horizontal alignment of both texts.
func set_texts(main_text: String, sub_text := "",
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	main_label.text = main_text
	main_label.horizontal_alignment = align
	sub_label.text = sub_text
	sub_label.horizontal_alignment = align
	sub_label.visible = sub_text != ""
	_fit.call_deferred()


## Sets the style variation. It sets the button colors and the text colors.
func set_style(variation: String) -> void:
	theme_type_variation = variation
	_apply_text_style()


## The theme is known only when the button is in the tree.
func _apply_text_style() -> void:
	if not is_inside_tree():
		return
	var variation := theme_type_variation if theme_type_variation != &"" else &"Button"
	var color := get_theme_color("font_color", variation)
	main_label.add_theme_color_override("font_color", color)
	main_label.add_theme_font_override("font", main_font if main_font else get_theme_font("font", variation))
	if variation == &"PrimaryButton":
		sub_label.add_theme_color_override("font_color", Color(color, 0.85))
	elif variation == &"BarButton":
		sub_label.add_theme_color_override("font_color", UiTheme.BAR_MUTED)


func _fit() -> void:
	# Before the container gives the button its width, the text cannot wrap correctly.
	if not is_inside_tree() or size.x < 1.0:
		return
	var style := get_theme_stylebox("normal")
	if style:
		_margin = Vector2(style.content_margin_left, style.content_margin_top)
	var inner_width := maxf(size.x - _margin.x * 2.0, 10.0)
	# Calculate the text height from the font. The label sizes change one frame late.
	var needed := _text_height(main_label, inner_width)
	if sub_label.visible:
		needed += _box.get_theme_constant("separation") + _text_height(sub_label, inner_width)
	needed += _margin.y * 2.0
	custom_minimum_size.y = maxf(UiTheme.BUTTON_MIN_HEIGHT, ceilf(needed))
	_box.offset_left = _margin.x
	_box.offset_right = -_margin.x
	_box.offset_top = _margin.y
	_box.offset_bottom = -_margin.y


func _text_height(label: Label, width: float) -> float:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var text_size := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, width,
			font_size, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
	return text_size.y + label.get_theme_constant("line_spacing") * maxf(0.0, text_size.y / font.get_height(font_size) - 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_apply_text_style()
		_fit.call_deferred()
