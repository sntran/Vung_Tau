class_name UiTheme
extends RefCounted
## The UI theme: colors, fonts, and the button styles.
## The colors are the same as in the 2D prototype.

const NIGHT := Color("#10211E")
const INK := Color("#1D2725")
const PAPER := Color("#E6EEE7")
const PAPER_2 := Color("#D2E0D5")
const LINE := Color("#9CB4A5")
const SIGN := Color("#C4362C")
const GOLD := Color("#F2C33C")
const JADE := Color("#2C7A6E")
const MUTED := Color("#4E615C")
const BAR_TEXT := Color("#EAF2EC")
const BAR_MUTED := Color("#A9C4BA")
const BAR_BUTTON := Color("#1C3732")
const BAR_BORDER := Color("#3B5A53")

const FONT_REGULAR := preload("res://assets/fonts/BeVietnamPro-Regular.ttf")
const FONT_BOLD := preload("res://assets/fonts/BeVietnamPro-Bold.ttf")
const FONT_SEMIBOLD := preload("res://assets/fonts/BeVietnamPro-SemiBold.ttf")
const FONT_ITALIC := preload("res://assets/fonts/BeVietnamPro-Italic.ttf")

const FONT_SIZE := 27
const FONT_SIZE_SMALL := 22
const FONT_SIZE_TITLE := 32
## Each button is at least 88 px high at the 720 px base width (R28).
const BUTTON_MIN_HEIGHT := 88
const TOP_BAR_HEIGHT := 112


static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT_REGULAR
	theme.default_font_size = FONT_SIZE

	theme.set_color("font_color", "Label", INK)
	theme.set_color("default_color", "RichTextLabel", INK)
	theme.set_font("normal_font", "RichTextLabel", FONT_REGULAR)
	theme.set_font("italics_font", "RichTextLabel", FONT_ITALIC)
	theme.set_font("bold_font", "RichTextLabel", FONT_BOLD)
	theme.set_font_size("normal_font_size", "RichTextLabel", FONT_SIZE)
	theme.set_font_size("italics_font_size", "RichTextLabel", FONT_SIZE)
	theme.set_font_size("bold_font_size", "RichTextLabel", FONT_SIZE)

	_button(theme, "Button", PAPER_2, LINE, INK)
	_button(theme, "PrimaryButton", JADE, JADE.darkened(0.2), Color.WHITE)
	_button(theme, "QuietButton", Color(PAPER_2, 0.0), LINE, MUTED)
	_button(theme, "BarButton", BAR_BUTTON, BAR_BORDER, BAR_TEXT)
	_button(theme, "WalkButton", Color(NIGHT, 0.6), Color(1, 1, 1, 0.8), Color.WHITE, 44)

	theme.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	theme.set_type_variation("TalkPanel", "PanelContainer")
	var talk := _flat(PAPER, 0)
	talk.border_color = SIGN
	talk.border_width_top = 6
	talk.shadow_color = Color(0, 0, 0, 0.25)
	talk.shadow_size = 8
	theme.set_stylebox("panel", "TalkPanel", talk)
	theme.set_type_variation("TopBar", "PanelContainer")
	theme.set_stylebox("panel", "TopBar", _flat(NIGHT, 0))
	theme.set_type_variation("SheetPanel", "PanelContainer")
	var sheet := _flat(PAPER, 0)
	sheet.border_color = SIGN
	sheet.border_width_bottom = 6
	theme.set_stylebox("panel", "SheetPanel", sheet)
	theme.set_type_variation("Card", "PanelContainer")
	var card := _flat(PAPER_2, 14)
	card.set_content_margin_all(18)
	theme.set_stylebox("panel", "Card", card)
	theme.set_type_variation("LockedCard", "PanelContainer")
	var locked := _flat(Color(PAPER_2, 0.35), 14)
	locked.border_color = LINE
	locked.set_border_width_all(3)
	locked.set_content_margin_all(18)
	theme.set_stylebox("panel", "LockedCard", locked)
	theme.set_type_variation("Toast", "PanelContainer")
	var toast := _flat(GOLD, 14)
	toast.set_content_margin_all(16)
	toast.shadow_color = Color(0, 0, 0, 0.3)
	toast.shadow_size = 10
	theme.set_stylebox("panel", "Toast", toast)

	theme.set_type_variation("BarLabel", "Label")
	theme.set_color("font_color", "BarLabel", BAR_TEXT)
	theme.set_type_variation("BarSmall", "Label")
	theme.set_color("font_color", "BarSmall", BAR_MUTED)
	theme.set_font_size("font_size", "BarSmall", FONT_SIZE_SMALL)
	theme.set_type_variation("Hint", "Label")
	theme.set_color("font_color", "Hint", MUTED)
	theme.set_font_size("font_size", "Hint", FONT_SIZE_SMALL)
	theme.set_font("font", "Hint", FONT_ITALIC)
	theme.set_type_variation("Title", "Label")
	theme.set_font("font", "Title", FONT_BOLD)
	theme.set_font_size("font_size", "Title", FONT_SIZE_TITLE)
	theme.set_type_variation("GroupTitle", "Label")
	theme.set_font("font", "GroupTitle", FONT_BOLD)
	theme.set_color("font_color", "GroupTitle", SIGN)
	theme.set_type_variation("Vietnamese", "Label")
	theme.set_font("font", "Vietnamese", FONT_SEMIBOLD)
	theme.set_color("font_color", "Vietnamese", JADE.darkened(0.25))
	theme.set_type_variation("English", "Label")
	theme.set_color("font_color", "English", MUTED)
	theme.set_font_size("font_size", "English", FONT_SIZE_SMALL)
	theme.set_type_variation("Speaker", "Label")
	theme.set_font("font", "Speaker", FONT_BOLD)
	theme.set_color("font_color", "Speaker", Color.WHITE)
	theme.set_font_size("font_size", "Speaker", FONT_SIZE_SMALL)
	theme.set_type_variation("ButtonSub", "Label")
	theme.set_font_size("font_size", "ButtonSub", FONT_SIZE_SMALL)
	theme.set_color("font_color", "ButtonSub", MUTED)

	var grabber := _flat(LINE, 6)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	theme.set_stylebox("scroll", "VScrollBar", _flat(Color(LINE, 0.25), 6))
	return theme


static func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(0)
	box.anti_aliasing = true
	return box


static func _button(theme: Theme, type: String, bg: Color, border: Color, font: Color,
		radius := 14) -> void:
	if type != "Button":
		theme.set_type_variation(type, "Button")
	var normal := _flat(bg, radius)
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.15) if bg.a > 0.0 else Color(LINE, 0.3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.06) if bg.a > 0.0 else Color(LINE, 0.15)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.border_color = GOLD
	focus.set_border_width_all(3)
	theme.set_stylebox("normal", type, normal)
	theme.set_stylebox("hover", type, hover)
	theme.set_stylebox("pressed", type, pressed)
	theme.set_stylebox("hover_pressed", type, pressed)
	theme.set_stylebox("disabled", type, normal)
	theme.set_stylebox("focus", type, focus)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		theme.set_color(state, type, font)
	theme.set_font("font", type, FONT_SEMIBOLD)
