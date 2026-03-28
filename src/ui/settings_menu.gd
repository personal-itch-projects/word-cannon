extends Control

var font: Font
var back_rect: Rect2
var controls_rect: Rect2
var hover_back: bool = false
var hover_controls: bool = false
var screen_size: Vector2

func _ready() -> void:
	font = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	screen_size = get_viewport().get_visible_rect().size
	var center_x: float = screen_size.x / 2.0
	var center_y: float = screen_size.y / 2.0
	controls_rect = Rect2(center_x - 120, center_y - 10, 240, 50)
	back_rect = Rect2(center_x - 100, center_y + 60, 200, 50)

func _process(_delta: float) -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var was_back := hover_back
	var was_controls := hover_controls
	hover_back = back_rect.has_point(mouse_pos) and visible
	hover_controls = controls_rect.has_point(mouse_pos) and visible
	if hover_back != was_back or hover_controls != was_controls:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if controls_rect.has_point(event.position):
			GameManager.use_arrow_keys = not GameManager.use_arrow_keys
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif back_rect.has_point(event.position):
			GameManager.go_to_menu()
			get_viewport().set_input_as_handled()

func _draw() -> void:
	# Title
	var title := "SETTINGS"
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 42)
	draw_string(font, Vector2(screen_size.x / 2.0 - title_size.x / 2.0, screen_size.y / 2.0 - 40), title, HORIZONTAL_ALIGNMENT_CENTER, -1, 42, Color("#1A1A1A"))

	# Controls toggle
	var controls_label := "Controls: Arrows" if GameManager.use_arrow_keys else "Controls: A/D"
	_draw_button(controls_rect, controls_label, hover_controls)

	# Back button
	_draw_button(back_rect, "BACK", hover_back)

func _draw_button(rect: Rect2, text: String, hovered: bool) -> void:
	var bg_color := Color.WHITE
	var border_color := Color("#1A1A1A") if not hovered else Color("#CC3333")
	draw_rect(rect, bg_color)
	draw_rect(rect, border_color, false, 2.0)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24)
	var text_pos := Vector2(rect.position.x + rect.size.x / 2.0 - text_size.x / 2.0, rect.position.y + rect.size.y / 2.0 + text_size.y / 4.0)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color("#1A1A1A"))
