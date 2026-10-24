class_name MessagesApp
extends ScrollContainer
## The Messages app (plan 0003, R24, R25): the thread with cô Nga of the
## host family. The newest message is at the bottom.

var phone: Phone
var _column: VBoxContainer


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column = PhoneUi.column(10)
	add_child(_column)


## state.messages: [{id, text, day, minutes}], state.sender: {name, color}.
func refresh(state: Dictionary) -> void:
	PhoneUi.clear(_column)
	var sender: Dictionary = state.get("sender", {})
	var name_label := PhoneUi.label(sender.get("name", ""), "GroupTitle")
	name_label.add_theme_color_override("font_color", Color(sender.get("color", "#8A5A34")))
	_column.add_child(name_label)
	var messages: Array = state.get("messages", [])
	if messages.is_empty():
		_column.add_child(PhoneUi.label(Content.ui_text("messages_empty"), "Hint"))
		return
	for i in messages.size():
		var message: Dictionary = messages[i]
		var bubble := PhoneUi.card()
		bubble.name = "Message_%d" % i
		bubble.set_meta("test_id", "message.%s" % message.id)
		var box := PhoneUi.column(2)
		bubble.add_child(box)
		box.add_child(PhoneUi.label("%s · %s" % [Content.format(Content.ui_text("clock_day"), {"day": message.day}),
				GameClock.format_time(int(message.minutes))], "Hint"))
		box.add_child(PhoneUi.label(message.text))
		_column.add_child(bubble)
	# Show the newest message.
	(func() -> void: scroll_vertical = int(get_v_scroll_bar().max_value)).call_deferred()
