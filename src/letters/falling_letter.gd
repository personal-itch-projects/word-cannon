extends Node2D

const LETTER_SIZE := 20.0
const COLLISION_RADIUS := 12.0

var velocity: Vector2 = Vector2.ZERO
var letter: String = ""
var font: Font
var font_size: int = 20

func _ready() -> void:
	font = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	if letter == "":
		var alphabet := WordDictionary.get_alphabet()
		letter = alphabet[randi() % alphabet.length()]

func setup(p_letter: String, p_position: Vector2, p_font_size: int = 20) -> void:
	letter = p_letter
	position = p_position
	font_size = p_font_size
	var fall_speed: float = GameManager.get_level_config()["fall_speed"]
	velocity = Vector2(0, fall_speed)

func _process(delta: float) -> void:
	position += velocity * delta

func _draw() -> void:
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var offset := -text_size / 2.0
	draw_string(font, Vector2(offset.x, -offset.y), letter, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color("#1A1A1A"))

func get_rect() -> Rect2:
	return Rect2(position - Vector2(LETTER_SIZE / 2, LETTER_SIZE / 2), Vector2(LETTER_SIZE, LETTER_SIZE))
