extends Control

var font: Font
var screen_size: Vector2
var continue_bubble: BubbleButton
var restart_bubble: BubbleButton
var settings_bubble: BubbleButton
var menu_bubble: BubbleButton

func _ready() -> void:
	font = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	screen_size = get_viewport().get_visible_rect().size
	var center_x: float = screen_size.x / 2.0
	var center_y: float = screen_size.y / 2.0

	continue_bubble = BubbleButton.create(self, Vector2(center_x, center_y - 5), GameManager.tr_text("CONTINUE"), GameManager.resume_game)
	restart_bubble = BubbleButton.create(self, Vector2(center_x, center_y + 65), GameManager.tr_text("RESTART"), GameManager.restart_game)
	settings_bubble = BubbleButton.create(self, Vector2(center_x, center_y + 135), GameManager.tr_text("SETTINGS"), GameManager.open_settings)
	menu_bubble = BubbleButton.create(self, Vector2(center_x, center_y + 205), GameManager.tr_text("MENU"), GameManager.go_to_menu)

	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if visible:
		for bubble in [continue_bubble, restart_bubble, settings_bubble, menu_bubble]:
			if bubble:
				bubble.reset_state()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		GameManager.resume_game()
		get_viewport().set_input_as_handled()
		return

func _draw() -> void:
	# Overlay
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0, 0, 0, 0.6))

	# Title
	var title := GameManager.tr_text("PAUSED")
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 52)
	draw_string(font, Vector2(screen_size.x / 2.0 - title_size.x / 2.0, screen_size.y / 2.0 - 60), title, HORIZONTAL_ALIGNMENT_CENTER, -1, 52, Color.WHITE)
