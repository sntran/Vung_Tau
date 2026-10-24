class_name CreditsApp
extends ScrollContainer
## The credits page of the phone: the notices of the map data, the height
## data, and the assets (plan 0005, acceptance criterion 4). The Settings app
## opens it. The text is in data/credits.json.

const PATH := "res://data/credits.json"

var phone: Phone
var _column: VBoxContainer


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column = PhoneUi.column(12)
	add_child(_column)


func refresh(_state: Dictionary) -> void:
	PhoneUi.clear(_column)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary:
		data = {"sections": []}
	for section: Dictionary in data.get("sections", []):
		_column.add_child(PhoneUi.label(section.title, "GroupTitle"))
		var text := PhoneUi.label(section.text)
		text.set_meta("test_id", "credits.text")
		_column.add_child(text)
