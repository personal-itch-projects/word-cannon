extends Node2D

const SPEED := 800.0
const SIZE := 15.0

# Trail settings
const TRAIL_LENGTH := 12
const TRAIL_WIDTH := 10.0
const TRAIL_UPDATE_INTERVAL := 0.016

# Bubble visual
const BUBBLE_SIZE := 24.0

var letter: String = ""
var velocity: Vector2 = Vector2(0, -SPEED)
var flock_manager: Node2D
var font: Font
var screen_width: float

var _trail: Line2D
var _trail_points: PackedVector2Array = PackedVector2Array()
var _trail_timer: float = 0.0
var _bubble_sprite: Sprite2D
var _bubble_material: ShaderMaterial

func setup(p_letter: String, p_position: Vector2, p_flock_manager: Node2D, p_velocity: Vector2 = Vector2(0, -SPEED)) -> void:
	letter = p_letter
	position = p_position
	flock_manager = p_flock_manager
	velocity = p_velocity
	font = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")

func _ready() -> void:
	screen_width = get_viewport().get_visible_rect().size.x
	_setup_trail()
	_setup_bubble()

func _setup_trail() -> void:
	_trail = Line2D.new()
	_trail.width = TRAIL_WIDTH
	_trail.default_color = Color(0.7, 0.85, 1.0, 0.4)
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.top_level = true

	# Width curve: thick near projectile, tapers to zero
	var width_curve := Curve.new()
	width_curve.add_point(Vector2(0.0, 1.0))
	width_curve.add_point(Vector2(0.3, 0.6))
	width_curve.add_point(Vector2(1.0, 0.0))
	_trail.width_curve = width_curve

	# Color gradient: fades out
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.7, 0.88, 1.0, 0.35))
	gradient.set_color(1, Color(0.7, 0.88, 1.0, 0.0))
	_trail.gradient = gradient

	add_child(_trail)

func _setup_bubble() -> void:
	# Create a texture for the shader to work on
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)

	_bubble_sprite = Sprite2D.new()
	_bubble_sprite.texture = tex
	_bubble_sprite.scale = Vector2(BUBBLE_SIZE / 64.0, BUBBLE_SIZE / 64.0)

	var shader := preload("res://src/shaders/projectile_bubble.gdshader")
	_bubble_material = ShaderMaterial.new()
	_bubble_material.shader = shader
	_bubble_sprite.material = _bubble_material

	# Insert behind the letter text (drawn via _draw)
	add_child(_bubble_sprite)
	move_child(_bubble_sprite, 0)

func _process(delta: float) -> void:
	position += velocity * delta

	# Bounce off side borders
	if position.x < 0:
		position.x = 0
		velocity.x = -velocity.x
	elif position.x > screen_width:
		position.x = screen_width
		velocity.x = -velocity.x

	# Update bubble stretch based on velocity direction
	_update_bubble_stretch()

	# Update trail
	_update_trail(delta)

	# Check collision with flocks (circle-based)
	var hit_flock: Node2D = flock_manager.check_projectile_collision(global_position, letter)
	if hit_flock:
		flock_manager.add_letter_to_flock(hit_flock, letter, global_position, velocity)
		queue_free()
		return

	# Remove if off screen top
	if position.y < -50:
		queue_free()

func _update_bubble_stretch() -> void:
	if not _bubble_material:
		return
	var speed := velocity.length()
	var stretch_amount := clampf(1.0 + speed / SPEED * 0.3, 1.0, 1.5)
	var angle := atan2(velocity.y, velocity.x)
	_bubble_material.set_shader_parameter("stretch", stretch_amount)
	_bubble_material.set_shader_parameter("stretch_angle", angle)

func _update_trail(delta: float) -> void:
	_trail_timer += delta
	if _trail_timer >= TRAIL_UPDATE_INTERVAL:
		_trail_timer = 0.0
		_trail_points.insert(0, global_position)
		if _trail_points.size() > TRAIL_LENGTH:
			_trail_points.resize(TRAIL_LENGTH)
		_trail.clear_points()
		for p in _trail_points:
			_trail.add_point(p)

func _draw() -> void:
	if font == null:
		return
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	var offset := -text_size / 2.0
	draw_string(font, Vector2(offset.x, -offset.y), letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color("#1A1A1A"))
