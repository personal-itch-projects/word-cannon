extends Control

var font: Font
var screen_size: Vector2
var restart_bubble: BubbleButton
var menu_bubble: BubbleButton

func _ready() -> void:
	font = preload("res://assets/fonts/Nunito/Nunito-Regular.ttf")
	screen_size = get_viewport().get_visible_rect().size
	var center_x: float = screen_size.x / 2.0
	var center_y: float = screen_size.y / 2.0

	restart_bubble = BubbleButton.create(self, Vector2(center_x, center_y + 35), GameManager.tr_text("RESTART"), GameManager.restart_game)
	menu_bubble = BubbleButton.create(self, Vector2(center_x, center_y + 105), GameManager.tr_text("MENU"), GameManager.go_to_menu)

	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if visible:
		restart_bubble.rebuild(GameManager.tr_text("RESTART"))
		menu_bubble.rebuild(GameManager.tr_text("MENU"))
		for bubble in [restart_bubble, menu_bubble]:
			if bubble:
				bubble.reset_state()
		queue_redraw()

func _draw() -> void:
	# Game Over title
	var title := GameManager.tr_text("GAME OVER")
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 52)
	draw_string(font, Vector2(screen_size.x / 2.0 - title_size.x / 2.0, screen_size.y / 2.0 - 60), title, HORIZONTAL_ALIGNMENT_CENTER, -1, 52, Color("#1A1A1A"))

	# Score
	var score_text := GameManager.tr_text("Score:") + " " + str(GameManager.score)
	var score_size := font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	draw_string(font, Vector2(screen_size.x / 2.0 - score_size.x / 2.0, screen_size.y / 2.0 - 20), score_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color("#666666"))
