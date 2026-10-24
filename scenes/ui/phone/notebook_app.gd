class_name NotebookApp
extends ScrollContainer
## The Sổ tay app (plan 0003, R26): the cards of plan 0001 and the saved
## phrases. A card that the player does not know yet shows only its hint.

var phone: Phone
var _column: VBoxContainer


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column = PhoneUi.column(10)
	add_child(_column)


## state.cards: the known card IDs, state.phrases: [{vi, en}].
func refresh(state: Dictionary) -> void:
	PhoneUi.clear(_column)
	var known: Array = state.get("cards", [])
	var count := PhoneUi.label(Content.format(Content.ui_text("notebook_count"),
			{"found": known.size(), "total": Content.card_list().size()}), "Hint")
	count.name = "Count"
	count.set_meta("test_id", "notebook.count")
	_column.add_child(count)
	_column.add_child(PhoneUi.label(Content.ui_text("notebook_phrases"), "GroupTitle"))
	var phrases: Array = state.get("phrases", [])
	if phrases.is_empty():
		_column.add_child(PhoneUi.label(Content.ui_text("notebook_no_phrases"), "Hint"))
	for i in phrases.size():
		var panel := PhoneUi.card()
		panel.set_meta("test_id", "phrase.%d" % i)
		var box := PhoneUi.column(2)
		panel.add_child(box)
		box.add_child(PhoneUi.label(phrases[i].vi, "Vietnamese"))
		box.add_child(PhoneUi.label(phrases[i].en, "English"))
		_column.add_child(panel)
	for group: String in Content.card_groups():
		_column.add_child(PhoneUi.label(group, "GroupTitle"))
		for card: Dictionary in Content.card_list():
			if card.group == group:
				_column.add_child(_card(card, known.has(card.id)))


func _card(card: Dictionary, known: bool) -> Control:
	var panel := PhoneUi.card("Card" if known else "LockedCard")
	panel.set_meta("test_id", "card.%s" % card.id)
	var box := PhoneUi.column(4)
	panel.add_child(box)
	if known:
		var title := PhoneUi.label(card.title)
		title.add_theme_font_override("font", UiTheme.FONT_BOLD)
		box.add_child(title)
		box.add_child(PhoneUi.label(card.vi, "Vietnamese"))
		box.add_child(PhoneUi.label(card.body))
	else:
		box.add_child(PhoneUi.label(Content.ui_text("notebook_locked")))
		box.add_child(PhoneUi.label(Content.format(Content.ui_text("notebook_hint"), {"hint": card.hint}), "Hint"))
	return panel
