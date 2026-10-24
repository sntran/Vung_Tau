class_name PhoneUi
extends RefCounted
## Small helpers that make the controls of the phone apps.

const FONT_SIZE := 22
const TITLE_SIZE := 26
const SCREEN := Color("#F4F1E8")
const SCREEN_2 := Color("#E6E1D2")
const DEVICE := Color("#14191A")


static func label(text: String, variation := "", font_size := FONT_SIZE) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if variation != "":
		result.theme_type_variation = variation
	if variation not in ["English", "Hint", "BarSmall"]:
		result.add_theme_font_size_override("font_size", font_size)
	return result


static func title(text: String) -> Label:
	var result := label(text, "Title", TITLE_SIZE)
	return result


## A button with a test ID. "sub" is a smaller second text.
static func button(test_id: String, text: String, sub := "", style := "Button") -> TextButton:
	var result := TextButton.new()
	result.set_meta("test_id", test_id)
	result.name = test_id.replace(".", "_")
	result.focus_mode = Control.FOCUS_NONE
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.set_style(style)
	result.set_texts(text, sub)
	result.main_label.add_theme_font_size_override("font_size", FONT_SIZE)
	return result


static func card(variation := "Card") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = variation
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


static func column(separation := 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	return box


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
