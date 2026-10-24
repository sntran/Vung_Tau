class_name TopBar
extends PanelContainer
## The top bar: the time with the part of the day, the place, the day,
## the sound button, and the notebook button with the count of cards.

signal clock_pressed
signal sound_pressed
signal notebook_pressed

const ICON_SOUND_ON := preload("res://assets/icons/sound_on.svg")
const ICON_SOUND_OFF := preload("res://assets/icons/sound_off.svg")
const ICON_BOOK := preload("res://assets/icons/book.svg")

var clock_button: TextButton
var place_label: Label
var sub_label: Label
var sound_button: Button
var notebook_button: Button


func _ready() -> void:
	theme_type_variation = "TopBar"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	clock_button = TextButton.new()
	clock_button.name = "Clock"
	clock_button.set_meta("test_id", "topbar.clock")
	clock_button.custom_minimum_size.x = 132
	clock_button.set_style("BarButton")
	clock_button.main_label.add_theme_font_size_override("font_size", 30)
	clock_button.main_font = UiTheme.FONT_BOLD
	clock_button.pressed.connect(clock_pressed.emit)
	row.add_child(clock_button)

	var place := VBoxContainer.new()
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place.alignment = BoxContainer.ALIGNMENT_CENTER
	place.add_theme_constant_override("separation", 0)
	place.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(place)
	place_label = Label.new()
	place_label.name = "Place"
	place_label.theme_type_variation = "BarLabel"
	place_label.add_theme_font_override("font", UiTheme.FONT_BOLD)
	place_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	place_label.clip_text = true
	place.add_child(place_label)
	sub_label = Label.new()
	sub_label.name = "PlaceSub"
	sub_label.theme_type_variation = "BarSmall"
	sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub_label.clip_text = true
	place.add_child(sub_label)

	sound_button = _icon_button("Sound", "topbar.sound", ICON_SOUND_ON)
	sound_button.pressed.connect(sound_pressed.emit)
	row.add_child(sound_button)
	notebook_button = _icon_button("Notebook", "topbar.notebook", ICON_BOOK)
	notebook_button.pressed.connect(notebook_pressed.emit)
	row.add_child(notebook_button)


func _icon_button(node_name: String, test_id: String, icon: Texture2D) -> Button:
	var button := Button.new()
	button.name = node_name
	button.set_meta("test_id", test_id)
	button.theme_type_variation = "BarButton"
	button.icon = icon
	button.custom_minimum_size = Vector2(88, UiTheme.BUTTON_MIN_HEIGHT)
	button.add_theme_constant_override("h_separation", 8)
	return button


## Shows the state. "place" and "sub" are the place name and the second line.
func show_state(time_text: String, part: String, place: String, sub: String, sound_on: bool,
		found: int, total: int) -> void:
	clock_button.set_texts(time_text, part, HORIZONTAL_ALIGNMENT_CENTER)
	place_label.text = place
	sub_label.text = sub
	sound_button.icon = ICON_SOUND_ON if sound_on else ICON_SOUND_OFF
	sound_button.tooltip_text = Content.ui_text("sound_on" if sound_on else "sound_off")
	notebook_button.text = "%d/%d" % [found, total]
	notebook_button.tooltip_text = Content.ui_text("notebook_button")
