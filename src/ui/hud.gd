extends Control

const CELL_SIZE := 30.0
const CELL_GAP := 4.0
const ARSENAL_FONT_SIZE := 18

var font: Font
var font_bold: Font
var screen_size: Vector2

@onready var platform: Node2D = get_node("/root/Main/GameLayer/Platform")

func _ready() -> void:
	font = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	font_bold = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	screen_size = get_viewport().get_visible_rect().size
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.level_changed.connect(_on_level_changed)
	# Initial update
	_on_score_changed(GameManager.score)
	_on_lives_changed(GameManager.lives)

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

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
	draw_string(font_bold, Vector2(screen_size.x - 200, 40), lives_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#1A1A1A"))

	# Arsenal
	if platform and not platform.arsenal.is_empty():
		_draw_arsenal()

func _draw_arsenal() -> void:
	var count: int = platform.arsenal.size()
	var total_w: float = count * CELL_SIZE + (count - 1) * CELL_GAP
	var start_x: float = screen_size.x / 2.0 - total_w / 2.0
	var y: float = screen_size.y - CELL_SIZE - 8.0

	for i in count:
		var x: float = start_x + i * (CELL_SIZE + CELL_GAP)
		var rect := Rect2(x, y, CELL_SIZE, CELL_SIZE)
		var bg := Color.WHITE if i > 0 else Color("#FFF3CC")
		var border := Color("#CC3333") if i == 0 else Color("#1A1A1A")
		draw_rect(rect, bg)
		draw_rect(rect, border, false, 2.0)
		var letter: String = platform.arsenal[i]
		var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, ARSENAL_FONT_SIZE)
		var tx: float = x + CELL_SIZE / 2.0 - text_size.x / 2.0
		var ty: float = y + CELL_SIZE / 2.0 + text_size.y / 4.0
		draw_string(font, Vector2(tx, ty), letter, HORIZONTAL_ALIGNMENT_CENTER, -1, ARSENAL_FONT_SIZE, Color("#1A1A1A"))
