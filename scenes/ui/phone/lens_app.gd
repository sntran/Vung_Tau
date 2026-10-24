class_name LensApp
extends VBoxContainer
## The Lens app (plan 0003, R23). It shows the camera view of the game with a
## frame in the center. When a place or a cart is in the frame (the focus of
## plan 0002), the app shows its card: the name, the English name, open or
## closed now, the hours, and the description.

## The camera view renders at a half of the size, so that it costs less.
const SHRINK := 2

var phone: Phone
## The camera of the player. The Lens camera follows it.
var source_camera: Camera3D
var view_container: SubViewportContainer
var camera: Camera3D
var _frame: Control
var _card: PanelContainer
var _card_box: VBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_container = SubViewportContainer.new()
	view_container.name = "CameraView"
	view_container.stretch = true
	view_container.stretch_shrink = SHRINK
	view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view_container)
	var viewport := SubViewport.new()
	viewport.name = "Viewport"
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	view_container.add_child(viewport)
	camera = Camera3D.new()
	camera.name = "LensCamera"
	camera.current = true
	viewport.add_child(camera)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.draw.connect(_draw_frame)
	_frame.resized.connect(_frame.queue_redraw)
	view_container.add_child(_frame)
	_card = PhoneUi.card()
	_card.name = "LensCard"
	_card.set_meta("test_id", "lens.card")
	_card_box = PhoneUi.column(4)
	_card.add_child(_card_box)
	add_child(_card)


func _draw_frame() -> void:
	var rect_size := _frame.size * 0.42
	var rect := Rect2((_frame.size - rect_size) / 2.0, rect_size)
	var corner := minf(rect_size.x, rect_size.y) * 0.25
	var color := Color(1, 1, 1, 0.9)
	for c in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var dx := corner if c.x == rect.position.x else -corner
		var dy := corner if c.y == rect.position.y else -corner
		_frame.draw_line(c, c + Vector2(dx, 0), color, 4.0)
		_frame.draw_line(c, c + Vector2(0, dy), color, 4.0)


func _process(_delta: float) -> void:
	if is_visible_in_tree() and source_camera:
		camera.global_transform = source_camera.global_transform
		camera.fov = source_camera.fov


## state.lens: {kind: "spot", name, en, status, text}, {kind: "person", name}, or empty.
func refresh(state: Dictionary) -> void:
	PhoneUi.clear(_card_box)
	var lens: Dictionary = state.get("lens", {})
	match lens.get("kind", ""):
		"spot":
			_card_box.add_child(PhoneUi.label(lens.name, "Title", PhoneUi.TITLE_SIZE))
			_card_box.add_child(PhoneUi.label(lens.en, "English"))
			if lens.status != "":
				var status := PhoneUi.label(lens.status, "Vietnamese")
				status.name = "Status"
				status.set_meta("test_id", "lens.status")
				_card_box.add_child(status)
			_card_box.add_child(PhoneUi.label(lens.text))
		"person":
			_card_box.add_child(PhoneUi.label(lens.name, "Title", PhoneUi.TITLE_SIZE))
		_:
			_card_box.add_child(PhoneUi.label(Content.ui_text("lens_empty"), "Hint"))
