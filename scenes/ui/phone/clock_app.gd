class_name ClockApp
extends ScrollContainer
## The Clock app (plan 0003, R27): the time, the part of the day in
## Vietnamese, the day number with the solar and the lunar date (plan 0004,
## D13), and the "Rest" choices. "Sleep until morning"
## is a choice only at the homestay.

var phone: Phone
var _column: VBoxContainer


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column = PhoneUi.column(10)
	add_child(_column)


## state.minutes, state.day, state.at_home.
func refresh(state: Dictionary) -> void:
	PhoneUi.clear(_column)
	var minutes: int = state.get("minutes", 0)
	var part := GameClock.part_of_day(minutes, Content.ui.parts_of_day)
	var params := {"time": GameClock.format_time(minutes), "part": part.vi, "part_en": part.en,
			"wake": GameClock.format_time(GameClock.WAKE_MINUTES), "day": state.get("day", 1)}
	var title := PhoneUi.title(Content.format(Content.ui_text("clock_title"), params))
	title.name = "ClockTitle"
	title.set_meta("test_id", "clock.title")
	_column.add_child(title)
	# The solar date and the lunar date (plan 0004, D13).
	var day := PhoneUi.label("%s · %s" % [Content.format(Content.ui_text("clock_day"), params),
			GameCalendar.text(int(state.get("day", 1)))], "Vietnamese")
	day.set_meta("test_id", "clock.day")
	_column.add_child(day)
	_column.add_child(PhoneUi.label(Content.format(Content.ui_text("clock_hint"), params), "Hint"))
	_column.add_child(PhoneUi.label(Content.ui_text("clock_rest"), "GroupTitle"))
	var at_home: bool = state.get("at_home", false)
	for choice: Dictionary in GameClock.clock_choices(Content.ui.clock_choices, minutes):
		if choice.get("sleep", false) and not at_home:
			_column.add_child(PhoneUi.label(Content.ui_text("clock_sleep_away"), "Hint"))
			continue
		var choice_button := PhoneUi.button("clock.%s" % choice.id, Content.format(choice.label, params),
				Content.format(choice.get("sub", ""), params),
				"PrimaryButton" if choice.get("style", "") == "primary" else "Button")
		choice_button.pressed.connect(func() -> void: phone.request.emit("rest", {"choice": choice}))
		_column.add_child(choice_button)
