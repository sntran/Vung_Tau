class_name ListenApp
extends ScrollContainer
## The Listen app (plan 0003, R19 to R22). It writes down the lines that the
## player hears while it is on, and it has the phrasebook of the talk.

const TONE_MARKS := {
	"huyền": "àằầèềìòồờùừỳÀẰẦÈỀÌÒỒỜÙỪỲ",
	"sắc": "áắấéếíóốớúứýÁẮẤÉẾÍÓỐỚÚỨÝ",
	"hỏi": "ảẳẩẻểỉỏổởủửỷẢẲẨẺỂỈỎỔỞỦỬỶ",
	"ngã": "ãẵẫẽễĩõỗỡũữỹÃẴẪẼỄĨÕỖỠŨỮỸ",
	"nặng": "ạặậẹệịọộợụựỵẠẶẬẸỆỊỌỘỢỤỰỴ",
}

var phone: Phone
var _column: VBoxContainer


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column = PhoneUi.column(10)
	add_child(_column)


## state.listen_on, state.transcript ([{speaker, vi, en}]), state.talk
## ({say_again, replies, saying} or empty).
func refresh(state: Dictionary) -> void:
	PhoneUi.clear(_column)
	var listen_on: bool = state.get("listen_on", false)
	var toggle := PhoneUi.button("listen.toggle", Content.ui_text("listen_on" if listen_on else "listen_off"),
			"", "PrimaryButton" if listen_on else "Button")
	toggle.pressed.connect(func() -> void: phone.request.emit("listen", {"on": not listen_on}))
	_column.add_child(toggle)
	var talk: Dictionary = state.get("talk", {})
	if talk.has("saying"):
		_saying(talk.saying)
	elif not talk.is_empty():
		_phrasebook(talk)
	var transcript: Array = state.get("transcript", [])
	if transcript.is_empty():
		var hint := PhoneUi.label(Content.ui_text("listen_empty_on" if listen_on else "listen_empty"), "Hint")
		hint.set_meta("test_id", "listen.hint")
		_column.add_child(hint)
		return
	_column.add_child(PhoneUi.label(Content.ui_text("listen_save_hint"), "Hint"))
	# The newest line is at the top.
	for i in range(transcript.size() - 1, -1, -1):
		var entry: Dictionary = transcript[i]
		var item := PhoneUi.button("listen.entry.%d" % i, "%s: %s" % [entry.speaker, entry.vi], entry.en, "Button")
		item.pressed.connect(func() -> void: phone.request.emit("save_phrase", {"index": i}))
		_column.add_child(item)


func _phrasebook(talk: Dictionary) -> void:
	_column.add_child(PhoneUi.label(Content.ui_text("phrasebook_title"), "GroupTitle"))
	# "Say again" is always first, so it stays in the same place when the
	# replies come in at the end of a line (D-0003-02).
	if talk.has("say_again"):
		_phrase({"id": "say_again", "vi": talk.say_again.vi, "en": talk.say_again.en})
	var replies: Array = talk.get("replies", [])
	for reply: Dictionary in replies:
		_phrase(reply)


func _phrase(reply: Dictionary) -> void:
	var panel := PhoneUi.card()
	panel.set_meta("test_id", "reply.%s" % reply.id)
	var box := PhoneUi.column(6)
	panel.add_child(box)
	var reply_id: String = reply.id
	if reply.get("english", false):
		box.add_child(PhoneUi.label("“%s”" % reply.en))
		var say := PhoneUi.button("reply.%s.english" % reply_id, Content.ui_text("reply_english"), "", "PrimaryButton")
		say.pressed.connect(func() -> void: phone.request.emit("reply", {"id": reply_id, "mode": "english"}))
		box.add_child(say)
	else:
		box.add_child(PhoneUi.label(reply.vi, "Vietnamese"))
		box.add_child(PhoneUi.label(reply.en, "English"))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var play := PhoneUi.button("reply.%s.play" % reply_id, Content.ui_text("reply_play"), "", "PrimaryButton")
		play.pressed.connect(func() -> void: phone.request.emit("reply", {"id": reply_id, "mode": "play"}))
		row.add_child(play)
		var said := PhoneUi.button("reply.%s.say" % reply_id, Content.ui_text("reply_say"), "", "Button")
		said.pressed.connect(func() -> void: phone.request.emit("reply", {"id": reply_id, "mode": "said"}))
		row.add_child(said)
	_column.add_child(panel)


## "I'll say it": the phrase large, with the tone of each syllable.
func _saying(saying: Dictionary) -> void:
	_column.add_child(PhoneUi.label(Content.ui_text("said_title"), "Hint"))
	var big := PhoneUi.label(saying.vi, "Vietnamese", 40)
	big.name = "SayingPhrase"
	big.set_meta("test_id", "said.phrase")
	_column.add_child(big)
	var names: Dictionary = Content.ui_dict("tones")
	var parts := PackedStringArray()
	for syllable in saying.vi.split(" ", false):
		var tone := tone_of(syllable)
		parts.append("%s (%s, %s)" % [syllable.strip_edges().trim_suffix(",").trim_suffix(".").trim_suffix("?"),
				tone, names.get(tone, "")])
	_column.add_child(PhoneUi.label(" · ".join(parts), "English"))
	_column.add_child(PhoneUi.label(saying.en, "English"))
	var done := PhoneUi.button("said.done", Content.ui_text("said_done"), "", "PrimaryButton")
	done.pressed.connect(func() -> void: phone.request.emit("said_done", {}))
	_column.add_child(done)


## The tone of a Vietnamese syllable: ngang, huyền, sắc, hỏi, ngã, or nặng.
static func tone_of(syllable: String) -> String:
	for tone: String in TONE_MARKS:
		for i in syllable.length():
			if TONE_MARKS[tone].contains(syllable[i]):
				return tone
	return "ngang"
