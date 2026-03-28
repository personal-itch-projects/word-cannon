extends Control

const PLATFORM_WIDTH := 100.0
const PLATFORM_HEIGHT := 16.0
const CANNON_WIDTH := 8.0
const CANNON_HEIGHT := 30.0
const PROJECTILE_SPEED := 500.0

var font: Font
var font_bold: Font
var play_rect: Rect2
var settings_rect: Rect2
var en_rect: Rect2
var ru_rect: Rect2
var hover_play: bool = false
var hover_settings: bool = false
var hover_en: bool = false
var hover_ru: bool = false
var screen_size: Vector2
var cannon_x: float
var cannon_y: float
var cannon_angle: float = 0.0
var next_letter: String = ""
var projectiles: Array[Dictionary] = []
var pending_action: Callable
var pending_timer: float = -1.0

func _ready() -> void:
	font = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	font_bold = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	screen_size = get_viewport().get_visible_rect().size
	var center_x: float = screen_size.x / 2.0
	var center_y: float = screen_size.y / 2.0
	play_rect = Rect2(center_x - 100, center_y - 30, 200, 50)
	settings_rect = Rect2(center_x - 100, center_y + 40, 200, 50)
	en_rect = Rect2(screen_size.x - 110, 15, 45, 30)
	ru_rect = Rect2(screen_size.x - 60, 15, 45, 30)
	cannon_x = screen_size.x / 2.0
	cannon_y = screen_size.y - 50
	_pick_next_letter()

func _pick_next_letter() -> void:
	var alphabet := WordDictionary.get_alphabet()
	next_letter = alphabet[randi() % alphabet.length()]

func _process(delta: float) -> void:
	if not visible:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var was_hover_play := hover_play
	var was_hover_settings := hover_settings
	var was_hover_en := hover_en
	var was_hover_ru := hover_ru
	hover_play = play_rect.has_point(mouse_pos)
	hover_settings = settings_rect.has_point(mouse_pos)
	hover_en = en_rect.has_point(mouse_pos)
	hover_ru = ru_rect.has_point(mouse_pos)

	# Move cannon toward cursor x
	cannon_x = clampf(mouse_pos.x, PLATFORM_WIDTH / 2.0, screen_size.x - PLATFORM_WIDTH / 2.0)

	# Update cannon angle
	var cannon_tip := Vector2(cannon_x, cannon_y - PLATFORM_HEIGHT / 2.0)
	var dir_to_mouse := (mouse_pos - cannon_tip).normalized()
	cannon_angle = atan2(dir_to_mouse.x, -dir_to_mouse.y)
	cannon_angle = clampf(cannon_angle, -PI / 3.0, PI / 3.0)

	# Update projectiles
	var to_remove: Array[int] = []
	for i in projectiles.size():
		projectiles[i]["pos"] += projectiles[i]["vel"] * delta
		var p: Vector2 = projectiles[i]["pos"]
		# Check button collisions
		if play_rect.has_point(p) or settings_rect.has_point(p):
			to_remove.append(i)
			continue
		# Remove if off screen
		if p.y < -50 or p.x < -50 or p.x > screen_size.x + 50:
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		projectiles.remove_at(to_remove[i])

	# Pending button action timer
	if pending_timer >= 0:
		pending_timer -= delta
		if pending_timer <= 0:
			pending_timer = -1.0
			if pending_action.is_valid():
				pending_action.call()

	if hover_play != was_hover_play or hover_settings != was_hover_settings or hover_en != was_hover_en or hover_ru != was_hover_ru or not projectiles.is_empty():
		queue_redraw()
	else:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target := event.position as Vector2
		var action: Callable = Callable()
		if en_rect.has_point(target):
			_set_language("en")
			get_viewport().set_input_as_handled()
			return
		elif ru_rect.has_point(target):
			_set_language("ru")
			get_viewport().set_input_as_handled()
			return
		elif play_rect.has_point(target):
			target = play_rect.get_center()
			action = GameManager.start_game
			get_viewport().set_input_as_handled()
		elif settings_rect.has_point(target):
			target = settings_rect.get_center()
			action = GameManager.open_settings
			get_viewport().set_input_as_handled()
		_shoot_toward(target, action)

func _set_language(lang: String) -> void:
	GameManager.language = lang
	WordDictionary.load_dictionary(lang)
	_pick_next_letter()
	queue_redraw()

func _shoot_toward(target: Vector2, action: Callable) -> void:
	var cannon_tip := Vector2(cannon_x, cannon_y - PLATFORM_HEIGHT / 2.0 - CANNON_HEIGHT)
	var dir := (target - cannon_tip).normalized()
	if dir.y > -0.1:
		dir = Vector2(dir.x, -0.1).normalized()
	var vel := dir * PROJECTILE_SPEED
	projectiles.append({"pos": cannon_tip, "vel": vel, "letter": next_letter})
	_pick_next_letter()
	if action.is_valid():
		pending_action = action
		pending_timer = 0.15

func _draw() -> void:
	# Language toggle (top-right)
	_draw_lang_button(en_rect, "EN", GameManager.language == "en", hover_en)
	_draw_lang_button(ru_rect, "RU", GameManager.language == "ru", hover_ru)

	# Title
	var title_text := GameManager.tr_text("WORD CANNON")
	var title_size := font_bold.get_string_size(title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 52)
	draw_string(font_bold, Vector2(screen_size.x / 2.0 - title_size.x / 2.0, screen_size.y / 2.0 - 100), title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 52, Color("#1A1A1A"))

	# Play button
	_draw_button(play_rect, GameManager.tr_text("PLAY"), hover_play)

	# Settings button
	_draw_button(settings_rect, GameManager.tr_text("SETTINGS"), hover_settings)

	# Cannon platform
	var platform_rect := Rect2(cannon_x - PLATFORM_WIDTH / 2.0, cannon_y - PLATFORM_HEIGHT / 2.0, PLATFORM_WIDTH, PLATFORM_HEIGHT)
	draw_rect(platform_rect, Color("#1A1A1A"))

	# Cannon barrel (rotated)
	draw_set_transform(Vector2(cannon_x, cannon_y - PLATFORM_HEIGHT / 2.0), cannon_angle)
	var cannon_rect := Rect2(-CANNON_WIDTH / 2.0, -CANNON_HEIGHT, CANNON_WIDTH, CANNON_HEIGHT)
	draw_rect(cannon_rect, Color("#1A1A1A"))
	if next_letter != "":
		var text_size := font.get_string_size(next_letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
		draw_string(font, Vector2(-text_size.x / 2.0, -CANNON_HEIGHT - 8), next_letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color("#1A1A1A"))
	draw_set_transform(Vector2.ZERO)

	# Projectiles
	for p in projectiles:
		var text_size := font.get_string_size(p["letter"], HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
		var offset := -text_size / 2.0
		draw_string(font, p["pos"] + Vector2(offset.x, -offset.y), p["letter"], HORIZONTAL_ALIGNMENT_CENTER, -1, 32, Color("#1A1A1A"))

func _draw_button(rect: Rect2, text: String, hovered: bool) -> void:
	var bg_color := Color.WHITE
	var border_color := Color("#1A1A1A") if not hovered else Color("#CC3333")
	draw_rect(rect, bg_color)
	draw_rect(rect, border_color, false, 2.0)
	var text_size := font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24)
	var text_pos := Vector2(rect.position.x + rect.size.x / 2.0 - text_size.x / 2.0, rect.position.y + rect.size.y / 2.0 + text_size.y / 4.0)
	draw_string(font_bold, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color("#1A1A1A"))

func _draw_lang_button(rect: Rect2, text: String, active: bool, hovered: bool) -> void:
	var bg_color := Color("#1A1A1A") if active else Color.WHITE
	var text_color := Color.WHITE if active else Color("#1A1A1A")
	var border_color := Color("#CC3333") if hovered and not active else Color("#1A1A1A")
	draw_rect(rect, bg_color)
	draw_rect(rect, border_color, false, 2.0)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	var text_pos := Vector2(rect.position.x + rect.size.x / 2.0 - text_size.x / 2.0, rect.position.y + rect.size.y / 2.0 + text_size.y / 4.0)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, text_color)
