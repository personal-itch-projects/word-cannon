extends Control

var font: Font
var back_rect: Rect2
var move_left_rect: Rect2
var move_right_rect: Rect2
var language_rect: Rect2
var datasource_rect: Rect2
var hover_back: bool = false
var hover_move_left: bool = false
var hover_move_right: bool = false
var hover_language: bool = false
var hover_datasource: bool = false
var screen_size: Vector2
var waiting_for_key: String = ""

func _ready() -> void:
	font = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	screen_size = get_viewport().get_visible_rect().size
	var center_x: float = screen_size.x / 2.0
	var center_y: float = screen_size.y / 2.0
	move_left_rect = Rect2(center_x - 120, center_y - 80, 240, 50)
	move_right_rect = Rect2(center_x - 120, center_y - 10, 240, 50)
	language_rect = Rect2(center_x - 120, center_y + 60, 240, 50)
	datasource_rect = Rect2(center_x - 120, center_y + 130, 240, 50)
	back_rect = Rect2(center_x - 100, center_y + 200, 200, 50)

func _process(_delta: float) -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var was_back := hover_back
	var was_move_left := hover_move_left
	var was_move_right := hover_move_right
	var was_language := hover_language
	var was_datasource := hover_datasource
	hover_back = back_rect.has_point(mouse_pos) and visible
	hover_move_left = move_left_rect.has_point(mouse_pos) and visible
	hover_move_right = move_right_rect.has_point(mouse_pos) and visible
	hover_language = language_rect.has_point(mouse_pos) and visible
	hover_datasource = datasource_rect.has_point(mouse_pos) and visible
	if hover_back != was_back or hover_move_left != was_move_left or hover_move_right != was_move_right or hover_language != was_language or hover_datasource != was_datasource:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Key capture mode for rebinding
	if waiting_for_key != "" and event is InputEventKey and event.pressed:
		GameManager.bindings[waiting_for_key] = event.physical_keycode
		waiting_for_key = ""
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if move_left_rect.has_point(event.position):
			waiting_for_key = "move_left"
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif move_right_rect.has_point(event.position):
			waiting_for_key = "move_right"
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif language_rect.has_point(event.position):
			waiting_for_key = ""
			if GameManager.language == "en":
				GameManager.language = "ru"
			else:
				GameManager.language = "en"
			WordDictionary.load_dictionary(GameManager.language)
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif datasource_rect.has_point(event.position):
			waiting_for_key = ""
			if GameManager.datasource == "lemma":
				GameManager.datasource = "kaikki"
			else:
				GameManager.datasource = "lemma"
			WordDictionary.load_dictionary(GameManager.language)
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif back_rect.has_point(event.position):
			waiting_for_key = ""
			GameManager.go_to_menu()
			get_viewport().set_input_as_handled()

func _draw() -> void:
	# Title
	var title := GameManager.tr_text("SETTINGS")
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 42)
	draw_string(font, Vector2(screen_size.x / 2.0 - title_size.x / 2.0, screen_size.y / 2.0 - 110), title, HORIZONTAL_ALIGNMENT_CENTER, -1, 42, Color("#1A1A1A"))

	# Move Left rebind
	var left_text: String
	if waiting_for_key == "move_left":
		left_text = GameManager.tr_text("Press key...")
	else:
		left_text = GameManager.tr_text("Move Left:") + " " + OS.get_keycode_string(GameManager.bindings["move_left"])
	_draw_button(move_left_rect, left_text, hover_move_left, waiting_for_key == "move_left")

	# Move Right rebind
	var right_text: String
	if waiting_for_key == "move_right":
		right_text = GameManager.tr_text("Press key...")
	else:
		right_text = GameManager.tr_text("Move Right:") + " " + OS.get_keycode_string(GameManager.bindings["move_right"])
	_draw_button(move_right_rect, right_text, hover_move_right, waiting_for_key == "move_right")

	# Language toggle
	var lang_key := "Language: Russian" if GameManager.language == "ru" else "Language: English"
	_draw_button(language_rect, GameManager.tr_text(lang_key), hover_language)

	# Datasource toggle
	var ds_key := "Dict: Wiktionary" if GameManager.datasource == "kaikki" else "Dict: Lemma"
	_draw_button(datasource_rect, GameManager.tr_text(ds_key), hover_datasource)

	# Back button
	_draw_button(back_rect, GameManager.tr_text("BACK"), hover_back)

func _draw_button(rect: Rect2, text: String, hovered: bool, active: bool = false) -> void:
	var bg_color := Color("#FFF3CC") if active else Color.WHITE
	var border_color := Color("#CC3333") if hovered or active else Color("#1A1A1A")
	draw_rect(rect, bg_color)
	draw_rect(rect, border_color, false, 2.0)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24)
	var text_pos := Vector2(rect.position.x + rect.size.x / 2.0 - text_size.x / 2.0, rect.position.y + rect.size.y / 2.0 + text_size.y / 4.0)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color("#1A1A1A"))
