class_name PassportApp
extends ScrollContainer
## The Passport app (plan 0007, R1 to R3, R5): the passport page of the
## traveler, and the controls of the gender, the date of birth, and the names.
## Before the photo is sent, the changes stay in the app until "Send". After
## that, each change takes effect at once. The look is a generic passport: no
## design, seal, or emblem of a real passport.

const MIN_YEAR := 1900
const PAGE_COLOR := Color("#E9E4D4")
const BAND_COLOR := Color("#2F4A5A")
const PHOTO_COLOR := Color("#B9B2A1")

var phone: Phone
var _column: VBoxContainer
## The values that the controls show: given, family, gender, birth, number, sent.
var _draft: Dictionary = {}
var _day := 1


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column = PhoneUi.column(8)
	add_child(_column)


## state.passport (GameState.passport), state.day (the game day).
func refresh(state: Dictionary) -> void:
	var passport: Dictionary = state.get("passport", {})
	_day = int(state.get("day", 1))
	# The draft follows the saved passport, except the changes before "Send".
	if _draft.is_empty() or bool(passport.get("sent", false)) or not bool(_draft.get("edited", false)):
		_draft = passport.duplicate()
	_build()


func _build() -> void:
	PhoneUi.clear(_column)
	var sender_name := str(Content.sender().get("name", ""))
	var sent := bool(_draft.get("sent", false))
	_column.add_child(page(_draft))
	var hint := PhoneUi.label(Content.format(Content.ui_text("passport_sent" if sent else "passport_hint"),
			{"name": sender_name}), "Hint")
	hint.set_meta("test_id", "passport.hint")
	_column.add_child(hint)
	# The gender.
	var genders := HBoxContainer.new()
	genders.add_theme_constant_override("separation", 8)
	for gender: String in ["male", "female"]:
		var gender_button := PhoneUi.button("passport.%s" % gender, Content.ui_text("passport_" + gender), "",
				"PrimaryButton" if _draft.get("gender", "") == gender else "Button")
		gender_button.pressed.connect(_change.bind("gender", gender))
		genders.add_child(gender_button)
	_column.add_child(genders)
	# The date of birth: day, month, and year, each with "−" and "+".
	var birth := _birth_parts()
	for part: String in ["day", "month", "year"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var minus := PhoneUi.button("passport.%s_minus" % part, "−")
		minus.size_flags_horizontal = Control.SIZE_FILL
		minus.custom_minimum_size.x = 64
		minus.pressed.connect(_step.bind(part, -1))
		row.add_child(minus)
		var value_label := PhoneUi.label(Content.format(Content.ui_text("passport_" + part), {"value": birth[part]}))
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.set_meta("test_id", "passport.%s" % part)
		row.add_child(value_label)
		var plus := PhoneUi.button("passport.%s_plus" % part, "+")
		plus.size_flags_horizontal = Control.SIZE_FILL
		plus.custom_minimum_size.x = 64
		plus.pressed.connect(_step.bind(part, 1))
		row.add_child(plus)
		_column.add_child(row)
	var date := GameCalendar.date_of(_day)
	var age := PhoneUi.label(Content.format(Content.ui_text("passport_age"), {"date": "%d/%d/%d" % [date.day, date.month,
			date.year], "age": GameState.age_on(str(_draft.get("birth", "")), _day)}))
	age.set_meta("test_id", "passport.age")
	_column.add_child(age)
	# The names (the default values can change).
	for field: String in ["given", "family"]:
		_column.add_child(PhoneUi.label(Content.ui_text("passport_given" if field == "given" else "passport_surname"), "Hint"))
		var edit := LineEdit.new()
		edit.set_meta("test_id", "passport.%s_name" % field)
		edit.name = "Passport_%s" % field
		edit.text = str(_draft.get(field, ""))
		edit.max_length = 30
		edit.add_theme_font_size_override("font_size", PhoneUi.FONT_SIZE)
		edit.text_submitted.connect(func(text: String) -> void: _change(field, text.strip_edges()))
		edit.focus_exited.connect(func() -> void: _change(field, edit.text.strip_edges()))
		_column.add_child(edit)
	if not sent:
		var send := PhoneUi.button("passport.send", Content.format(Content.ui_text("passport_send"), {"name": sender_name}),
				"", "PrimaryButton")
		send.pressed.connect(func() -> void: phone.request.emit("send_passport", {"values": _values()}))
		_column.add_child(send)


func _values() -> Dictionary:
	return {"given": _draft.get("given", ""), "family": _draft.get("family", ""), "gender": _draft.get("gender", "male"),
			"birth": _draft.get("birth", "")}


func _change(field: String, value: String) -> void:
	if field in ["given", "family"] and value == "":
		value = str(GameState.default_passport()[field])
	if str(_draft.get(field, "")) == value:
		return
	_draft[field] = value
	_draft.edited = true
	if bool(_draft.get("sent", false)):
		phone.request.emit("passport", {"values": _values()})
	_build.call_deferred()


## Changes a part of the date of birth. The age stays 18 to 80 on the game date (R3).
func _step(part: String, amount: int) -> void:
	var birth := _birth_parts()
	birth[part] = int(birth[part]) + amount
	if part == "month":
		birth.month = wrapi(int(birth.month) - 1, 0, 12) + 1
	var last := _days_in_month(int(birth.year), int(birth.month))
	if part == "day":
		birth.day = wrapi(int(birth.day) - 1, 0, last) + 1
	birth.day = mini(int(birth.day), last)
	var text := "%04d-%02d-%02d" % [birth.year, birth.month, birth.day]
	var limits: Dictionary = Content.address.get("traveler", {})
	var age := GameState.age_on(text, _day)
	if int(birth.year) < MIN_YEAR or age < int(limits.get("min_age", 18)) or age > int(limits.get("max_age", 80)):
		return
	_change("birth", text)


func _birth_parts() -> Dictionary:
	var parts := str(_draft.get("birth", "1988-06-15")).split("-")
	if parts.size() != 3:
		parts = PackedStringArray(["1988", "06", "15"])
	return {"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2])}


static func _days_in_month(year: int, month: int) -> int:
	if month == 2:
		return 29 if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0 else 28
	return 30 if month in [4, 6, 9, 11] else 31


## The passport page: a generic page with a band, a photo place, and the fields (R1).
static func page(passport: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "PassportPage"
	panel.set_meta("test_id", "passport.page")
	var style := StyleBoxFlat.new()
	style.bg_color = PAGE_COLOR
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	style.border_color = BAND_COLOR
	style.border_width_top = 16
	panel.add_theme_stylebox_override("panel", style)
	var rows := PhoneUi.column(2)
	panel.add_child(rows)
	var header := PhoneUi.label("%s · %s" % [Content.ui_text("passport_page_title"),
			str(Content.address.get("traveler", {}).get("passport", {}).get("nationality", ""))], "Hint")
	rows.add_child(header)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	rows.add_child(body)
	var photo := ColorRect.new()
	photo.color = PHOTO_COLOR
	photo.custom_minimum_size = Vector2(72, 92)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(photo)
	var fields := PhoneUi.column(0)
	body.add_child(fields)
	var months: Array = Content.ui.get("passport_months", [])
	var parts := str(passport.get("birth", "")).split("-")
	var birth := str(passport.get("birth", ""))
	if parts.size() == 3 and months.size() == 12:
		birth = "%s %s %s" % [parts[2], months[clampi(int(parts[1]) - 1, 0, 11)], parts[0]]
	var nationality := str(Content.address.get("traveler", {}).get("passport", {}).get("nationality", ""))
	for entry: Array in [["passport_surname", str(passport.get("family", "")).to_upper()],
			["passport_given", str(passport.get("given", "")).to_upper()], ["passport_nationality", nationality],
			["passport_sex", "M" if passport.get("gender", "male") == "male" else "F"],
			["passport_birth", birth], ["passport_number", str(passport.get("number", ""))]]:
		var name_label := PhoneUi.label(Content.ui_text(entry[0]), "Hint")
		fields.add_child(name_label)
		var value := PhoneUi.label(entry[1], "", 20)
		value.set_meta("test_id", "passport.page.%s" % str(entry[0]).trim_prefix("passport_"))
		fields.add_child(value)
	return panel
