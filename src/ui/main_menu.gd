extends Control

var font: Font
var font_bold: Font
var en_rect: Rect2
var ru_rect: Rect2
var hover_en: bool = false
var hover_ru: bool = false
var screen_size: Vector2
var play_bubble: BubbleButton
var settings_bubble: BubbleButton

func _ready() -> void:
	font = preload("res://assets/fonts/Nunito/Nunito-Regular.ttf")
	font_bold = preload("res://assets/fonts/Nunito/Nunito-Bold.ttf")
	screen_size = get_viewport().get_visible_rect().size
	var center_x: float = screen_size.x / 2.0
	var center_y: float = screen_size.y / 2.0
	en_rect = Rect2(screen_size.x - 110, 15, 45, 30)
	ru_rect = Rect2(screen_size.x - 60, 15, 45, 30)

	play_bubble = BubbleButton.create(self, Vector2(center_x, center_y - 5), GameManager.tr_text("PLAY"), GameManager.start_game)
	settings_bubble = BubbleButton.create(self, Vector2(center_x, center_y + 65), GameManager.tr_text("SETTINGS"), GameManager.open_settings)

	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if visible and play_bubble and settings_bubble:
		play_bubble.reset_state()
		settings_bubble.reset_state()

func _process(_delta: float) -> void:
	if not visible:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var was_hover_en := hover_en
	var was_hover_ru := hover_ru
	hover_en = en_rect.has_point(mouse_pos)
	hover_ru = ru_rect.has_point(mouse_pos)
	if hover_en != was_hover_en or hover_ru != was_hover_ru:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target := event.position as Vector2
		if en_rect.has_point(target):
			_set_language("en")
			get_viewport().set_input_as_handled()
			return
		elif ru_rect.has_point(target):
			_set_language("ru")
			get_viewport().set_input_as_handled()
			return

func _set_language(lang: String) -> void:
	GameManager.language = lang
	WordDictionary.load_dictionary(lang)
	play_bubble.rebuild(GameManager.tr_text("PLAY"))
	settings_bubble.rebuild(GameManager.tr_text("SETTINGS"))
	queue_redraw()

func _draw() -> void:
	# Language toggle (top-right)
	_draw_lang_button(en_rect, "EN", GameManager.language == "en", hover_en)
	_draw_lang_button(ru_rect, "RU", GameManager.language == "ru", hover_ru)

	# Title
	var title_text := GameManager.tr_text("WORD PLUNDER")
	var title_size := font_bold.get_string_size(title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 52)
	draw_string(font_bold, Vector2(screen_size.x / 2.0 - title_size.x / 2.0, screen_size.y / 2.0 - 100), title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 52, Color("#1A1A1A"))

	# High score
	if GameManager.high_score > 0:
		var hs_text := GameManager.tr_text("HIGH SCORE") + ": " + str(GameManager.high_score)
		var hs_size := font.get_string_size(hs_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
		draw_string(font, Vector2(screen_size.x / 2.0 - hs_size.x / 2.0, screen_size.y / 2.0 - 60), hs_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color("#666666"))

func _draw_lang_button(rect: Rect2, text: String, active: bool, hovered: bool) -> void:
	var bg_color := Color("#1A1A1A") if active else Color.WHITE
	var text_color := Color.WHITE if active else Color("#1A1A1A")
	var border_color := Color("#CC3333") if hovered and not active else Color("#1A1A1A")
	draw_rect(rect, bg_color)
	draw_rect(rect, border_color, false, 2.0)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	var text_pos := Vector2(rect.position.x + rect.size.x / 2.0 - text_size.x / 2.0, rect.position.y + rect.size.y / 2.0 + text_size.y / 4.0)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, text_color)
