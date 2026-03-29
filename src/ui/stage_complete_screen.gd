extends Control

var font: Font
var continue_rect: Rect2
var restart_rect: Rect2
var menu_rect: Rect2
var hover_continue: bool = false
var hover_restart: bool = false
var hover_menu: bool = false
var screen_size: Vector2
var is_final_stage: bool = false

func _ready() -> void:
	font = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	screen_size = get_viewport().get_visible_rect().size
	var center_x: float = screen_size.x / 2.0
	var center_y: float = screen_size.y / 2.0
	continue_rect = Rect2(center_x - 100, center_y + 40, 200, 50)
	restart_rect = Rect2(center_x - 100, center_y + 40, 200, 50)
	menu_rect = Rect2(center_x - 100, center_y + 110, 200, 50)
	GameManager.stage_completed.connect(_on_stage_completed)

func _on_stage_completed(stage: int) -> void:
	is_final_stage = stage >= 3
	queue_redraw()

func _process(_delta: float) -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var was_c := hover_continue
	var was_r := hover_restart
	var was_m := hover_menu
	if is_final_stage:
		hover_restart = restart_rect.has_point(mouse_pos) and visible
		hover_menu = menu_rect.has_point(mouse_pos) and visible
		hover_continue = false
	else:
		hover_continue = continue_rect.has_point(mouse_pos) and visible
		hover_restart = false
		hover_menu = false
	if hover_continue != was_c or hover_restart != was_r or hover_menu != was_m:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_final_stage:
			if restart_rect.has_point(event.position):
				GameManager.restart_game()
				get_viewport().set_input_as_handled()
			elif menu_rect.has_point(event.position):
				GameManager.go_to_menu()
				get_viewport().set_input_as_handled()
		else:
			if continue_rect.has_point(event.position):
				GameManager.continue_after_stage()
				get_viewport().set_input_as_handled()

func _draw() -> void:
	# Overlay
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0, 0, 0, 0.6))

	# Title
	var title: String
	if is_final_stage:
		title = GameManager.tr_text("YOU WIN!")
	else:
		title = GameManager.tr_text("STAGE COMPLETE!")
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 52)
	draw_string(font, Vector2(screen_size.x / 2.0 - title_size.x / 2.0, screen_size.y / 2.0 - 60), title, HORIZONTAL_ALIGNMENT_CENTER, -1, 52, Color.WHITE)

	# Score
	var score_text := GameManager.tr_text("Score:") + " " + str(GameManager.score)
	var score_size := font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
	draw_string(font, Vector2(screen_size.x / 2.0 - score_size.x / 2.0, screen_size.y / 2.0), score_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 32, Color.WHITE)

	# Buttons
	if is_final_stage:
		_draw_button(restart_rect, GameManager.tr_text("RESTART"), hover_restart)
		_draw_button(menu_rect, GameManager.tr_text("MENU"), hover_menu)
	else:
		_draw_button(continue_rect, GameManager.tr_text("CONTINUE"), hover_continue)

func _draw_button(rect: Rect2, text: String, hovered: bool) -> void:
	var bg_color := Color.WHITE
	var border_color := Color("#1A1A1A") if not hovered else Color("#CC3333")
	draw_rect(rect, bg_color)
	draw_rect(rect, border_color, false, 2.0)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24)
	var text_pos := Vector2(rect.position.x + rect.size.x / 2.0 - text_size.x / 2.0, rect.position.y + rect.size.y / 2.0 + text_size.y / 4.0)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color("#1A1A1A"))
