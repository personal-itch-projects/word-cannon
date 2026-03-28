extends Node2D

const SPEED := 500.0
const SIZE := 30.0

var letter: String = ""
var velocity: Vector2 = Vector2(0, -SPEED)
var flock_manager: Node2D
var font: Font
var screen_width: float

func setup(p_letter: String, p_position: Vector2, p_flock_manager: Node2D, p_velocity: Vector2 = Vector2(0, -SPEED)) -> void:
	letter = p_letter
	position = p_position
	flock_manager = p_flock_manager
	velocity = p_velocity
	font = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	screen_width = get_viewport().get_visible_rect().size.x

func _process(delta: float) -> void:
	position += velocity * delta

	# Bounce off side borders
	if position.x < 0:
		position.x = 0
		velocity.x = -velocity.x
	elif position.x > screen_width:
		position.x = screen_width
		velocity.x = -velocity.x

	# Check collision with flocks
	var proj_rect := Rect2(position - Vector2(SIZE / 2, SIZE / 2), Vector2(SIZE, SIZE))
	var hit_flock: Node2D = flock_manager.check_projectile_collision(proj_rect, letter)
	if hit_flock:
		flock_manager.add_letter_to_flock(hit_flock, letter, global_position)
		queue_free()
		return

	# Remove if off screen top
	if position.y < -50:
		queue_free()

func _draw() -> void:
	if font == null:
		return
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
	var offset := -text_size / 2.0
	draw_string(font, Vector2(offset.x, -offset.y), letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 32, Color("#1A1A1A"))
