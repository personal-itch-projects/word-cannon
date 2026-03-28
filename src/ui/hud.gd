extends Control

var font: Font
var font_bold: Font

func _ready() -> void:
	font = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	font_bold = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.level_changed.connect(_on_level_changed)
	# Initial update
	_on_score_changed(GameManager.score)
	_on_lives_changed(GameManager.lives)

func _on_score_changed(_score: int) -> void:
	queue_redraw()

func _on_lives_changed(_lives: int) -> void:
	queue_redraw()

func _on_level_changed(_level: int) -> void:
	queue_redraw()

func _draw() -> void:
	# Score
	draw_string(font_bold, Vector2(20, 40), GameManager.tr_text("SCORE") + ": " + str(GameManager.score), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#1A1A1A"))

	# Level
	draw_string(font_bold, Vector2(20, 70), GameManager.tr_text("LEVEL") + ": " + str(GameManager.current_level + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#1A1A1A"))

	# Lives
	var lives_text := ""
	for i in GameManager.MAX_LIVES:
		if i < GameManager.lives:
			lives_text += "♥ "
		else:
			lives_text += "♡ "
	var screen_width: float = get_viewport().get_visible_rect().size.x
	draw_string(font_bold, Vector2(screen_width - 200, 40), lives_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#1A1A1A"))
