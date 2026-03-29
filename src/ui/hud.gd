extends Control

const ARSENAL_FONT_SIZE := 16
const ARSENAL_DISPLAY_COUNT := 5
const ARSENAL_BUBBLE_SIZE := 28.0
const ARSENAL_GAP := 8.0

var font: Font
var font_bold: Font
var screen_size: Vector2
var _arsenal_sprites: Array[Sprite2D] = []
var _arsenal_positions: Array[Vector2] = []
var theme_intro_done: bool = false

@onready var platform: Node2D = get_node("/root/Main/GameLayer/Platform")

func _ready() -> void:
	font = preload("res://assets/fonts/Nunito/Nunito-Regular.ttf")
	font_bold = preload("res://assets/fonts/Nunito/Nunito-Bold.ttf")
	screen_size = get_viewport().get_visible_rect().size
	_setup_arsenal_bubbles()
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.goal_progress_changed.connect(_on_goal_progress_changed)
	GameManager.theme_changed.connect(_on_theme_changed)
	_on_score_changed(GameManager.score)

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _on_score_changed(_score: int) -> void:
	queue_redraw()

func _on_level_changed(_level: int) -> void:
	queue_redraw()

func _on_goal_progress_changed() -> void:
	queue_redraw()

func _on_theme_changed(_name: String) -> void:
	theme_intro_done = false
	queue_redraw()

func _draw() -> void:
	# Score
	draw_string(font_bold, Vector2(20, 40), GameManager.tr_text("SCORE") + ": " + str(GameManager.score), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#1A1A1A"))

	# Level
	draw_string(font_bold, Vector2(20, 70), GameManager.tr_text("LEVEL") + ": " + str(GameManager.current_level + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#1A1A1A"))

	# Goal progress (center)
	var goal_text := _get_goal_text()
	var goal_size := font_bold.get_string_size(goal_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	draw_string(font_bold, Vector2(screen_size.x / 2.0 - goal_size.x / 2.0, 40), goal_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color("#1A1A1A"))

	# Elapsed time (small, below goal)
	var elapsed: int = int(GameManager.level_timer)
	var minutes: int = elapsed / 60
	var seconds: int = elapsed % 60
	var timer_text := "%d:%02d" % [minutes, seconds]
	var timer_size := font.get_string_size(timer_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	draw_string(font, Vector2(screen_size.x / 2.0 - timer_size.x / 2.0, 62), timer_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color("#666666"))

	# Theme display (centered, below timer)
	if theme_intro_done and not GameManager.current_theme_name.is_empty():
		var theme_label := GameManager.tr_text("Theme:")
		var label_size := font.get_string_size(theme_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
		draw_string(font, Vector2(screen_size.x / 2.0 - label_size.x / 2.0, 90), theme_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color("#888888"))
		var theme_name: String = GameManager.current_theme_name
		var name_size := font_bold.get_string_size(theme_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 24)
		draw_string(font_bold, Vector2(screen_size.x / 2.0 - name_size.x / 2.0, 118), theme_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color("#1A1A1A"))

	# Arsenal bubbles (update visibility and draw letters)
	_update_arsenal_bubbles()
	_draw_arsenal_letters()

func _get_goal_text() -> String:
	var cfg: Dictionary = GameManager.get_level_config()
	match cfg["goal_type"]:
		"words":
			return GameManager.tr_text("Words:") + " " + str(GameManager.level_words) + "/" + str(cfg["goal_target"])
		"score":
			return GameManager.tr_text("Score:") + " " + str(GameManager.level_score) + "/" + str(cfg["goal_target"])
		"words_of_length":
			return str(cfg["goal_word_length"]) + GameManager.tr_text("-letter words:") + " " + str(GameManager.level_words_of_length) + "/" + str(cfg["goal_target"])
	return ""

func _setup_arsenal_bubbles() -> void:
	var shader := preload("res://src/shaders/metaball_bubble.gdshader")
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.15, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.85, 0.93, 1.0, 0.55),
		Color(0.78, 0.90, 1.0, 0.45),
		Color(0.70, 0.85, 1.0, 0.30),
		Color(0.65, 0.82, 1.0, 0.25),
	])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient

	var total_w := ARSENAL_DISPLAY_COUNT * ARSENAL_BUBBLE_SIZE + (ARSENAL_DISPLAY_COUNT - 1) * ARSENAL_GAP
	var start_x := screen_size.x - total_w - 20.0
	var y := screen_size.y - ARSENAL_BUBBLE_SIZE / 2.0 - 16.0

	for i in ARSENAL_DISPLAY_COUNT:
		var pos := Vector2(start_x + i * (ARSENAL_BUBBLE_SIZE + ARSENAL_GAP) + ARSENAL_BUBBLE_SIZE / 2.0, y)
		_arsenal_positions.append(pos)

		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.scale = Vector2(ARSENAL_BUBBLE_SIZE, ARSENAL_BUBBLE_SIZE)
		sprite.position = pos

		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("ball_count", 1)
		mat.set_shader_parameter("ball_positions", [Vector2.ZERO])
		mat.set_shader_parameter("ball_radius", ARSENAL_BUBBLE_SIZE * 0.45)
		mat.set_shader_parameter("rect_size", Vector2(ARSENAL_BUBBLE_SIZE, ARSENAL_BUBBLE_SIZE))
		mat.set_shader_parameter("gradient_tex", grad_tex)
		mat.set_shader_parameter("caustic_strength", 0.4)
		mat.set_shader_parameter("caustic_scale", 0.05)
		mat.set_shader_parameter("caustic_speed", 0.3)
		sprite.material = mat

		sprite.z_index = 1
		sprite.z_as_relative = false
		add_child(sprite)
		_arsenal_sprites.append(sprite)

func _update_arsenal_bubbles() -> void:
	if not platform:
		return
	for i in ARSENAL_DISPLAY_COUNT:
		if i < platform.arsenal.size():
			_arsenal_sprites[i].visible = true
		else:
			_arsenal_sprites[i].visible = false

func _draw_arsenal_letters() -> void:
	if not platform:
		return
	var count := mini(platform.arsenal.size(), ARSENAL_DISPLAY_COUNT)
	for i in count:
		var letter: String = platform.arsenal[i]
		var pos := _arsenal_positions[i]
		var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, ARSENAL_FONT_SIZE)
		draw_string(font, Vector2(pos.x - text_size.x / 2.0, pos.y + text_size.y / 4.0), letter, HORIZONTAL_ALIGNMENT_CENTER, -1, ARSENAL_FONT_SIZE, Color("#1A1A1A"))
