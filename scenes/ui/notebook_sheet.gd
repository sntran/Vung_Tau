class_name NotebookSheet
extends PanelContainer
## The notebook (sổ tay). It shows all cards in groups. A card that the
## player does not know yet shows only its hint.

signal closed

var scroll: ScrollContainer
var _title: Label
var _count: Label
var _list: VBoxContainer
var _close: Button


func _ready() -> void:
	theme_type_variation = "SheetPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	_title = Label.new()
	_title.theme_type_variation = "Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_title)
	_close = Button.new()
	_close.name = "Close"
	_close.set_meta("test_id", "notebook.close")
	_close.custom_minimum_size = Vector2(140, UiTheme.BUTTON_MIN_HEIGHT)
	_close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_close.pressed.connect(closed.emit)
	header.add_child(_close)
	_count = Label.new()
	_count.theme_type_variation = "Hint"
	_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_count)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)


## Fills the sheet with the cards. "known" is the list of card IDs that the player knows.
## "columns" is the number of card columns (more in landscape).
func show_cards(known: Array, columns := 1) -> void:
	_title.text = Content.ui_text("notebook_title")
	_close.text = Content.ui_text("close")
	_count.text = Content.format(Content.ui_text("notebook_count"),
			{"found": known.size(), "total": Content.card_list().size()})
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for group: String in Content.card_groups():
		var title := Label.new()
		title.theme_type_variation = "GroupTitle"
		title.text = group
		_list.add_child(title)
		var grid := GridContainer.new()
		grid.columns = columns
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		_list.add_child(grid)
		for card: Dictionary in Content.card_list():
			if card.group != group:
				continue
			grid.add_child(_card(card, known.has(card.id)))
	scroll.scroll_vertical = 0


func _card(card: Dictionary, known: bool) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Card" if known else "LockedCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("test_id", "card.%s" % card.id)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title := Label.new()
	title.add_theme_font_override("font", UiTheme.FONT_BOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	if known:
		title.text = card.title
		var vi := Label.new()
		vi.theme_type_variation = "Vietnamese"
		vi.text = card.vi
		vi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(vi)
		var body := Label.new()
		body.text = card.body
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(body)
	else:
		title.text = Content.ui_text("notebook_locked")
		var hint := Label.new()
		hint.theme_type_variation = "Hint"
		hint.text = Content.format(Content.ui_text("notebook_hint"), {"hint": card.hint})
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(hint)
	return panel
