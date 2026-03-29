extends Node2D

const SPEED := 800.0
const SIZE := 15.0

# Trail settings
const TRAIL_SPAWN_INTERVAL := 0.03
const TRAIL_PARTICLE_LIFETIME := 0.35
const TRAIL_PARTICLE_SIZE := 10.0

# Bubble visual
const BUBBLE_SIZE := 24.0

var letter: String = ""
var velocity: Vector2 = Vector2(0, -SPEED)
var flock_manager: Node2D
var font: Font
var screen_width: float

var _trail_timer: float = 0.0
var _trail_container: Node2D
var _bubble_sprite: Sprite2D
var _bubble_material: ShaderMaterial
var _trail_shader: Shader
var _trail_grad_tex: GradientTexture1D

func setup(p_letter: String, p_position: Vector2, p_flock_manager: Node2D, p_velocity: Vector2 = Vector2(0, -SPEED)) -> void:
	letter = p_letter
	position = p_position
	flock_manager = p_flock_manager
	velocity = p_velocity
	font = preload("res://assets/fonts/Nunito/Nunito-Regular.ttf")

func _ready() -> void:
	screen_width = get_viewport().get_visible_rect().size.x
	_setup_trail()
	_setup_bubble()

func _setup_trail() -> void:
	_trail_container = Node2D.new()
	_trail_container.top_level = true
	add_child(_trail_container)

	_trail_shader = preload("res://src/shaders/metaball_bubble.gdshader")
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.15, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.85, 0.93, 1.0, 0.55),
		Color(0.78, 0.90, 1.0, 0.45),
		Color(0.70, 0.85, 1.0, 0.30),
		Color(0.65, 0.82, 1.0, 0.25),
	])
	_trail_grad_tex = GradientTexture1D.new()
	_trail_grad_tex.gradient = gradient

func _setup_bubble() -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)

	_bubble_sprite = Sprite2D.new()
	_bubble_sprite.texture = tex
	_bubble_sprite.scale = Vector2(BUBBLE_SIZE, BUBBLE_SIZE)

	var shader := preload("res://src/shaders/metaball_bubble.gdshader")
	_bubble_material = ShaderMaterial.new()
	_bubble_material.shader = shader
	_bubble_material.set_shader_parameter("ball_count", 1)
	_bubble_material.set_shader_parameter("ball_positions", [Vector2.ZERO])
	_bubble_material.set_shader_parameter("ball_radius", BUBBLE_SIZE * 0.45)
	_bubble_material.set_shader_parameter("rect_size", Vector2(BUBBLE_SIZE, BUBBLE_SIZE))

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
	_bubble_material.set_shader_parameter("gradient_tex", grad_tex)
	_bubble_material.set_shader_parameter("caustic_strength", 0.4)
	_bubble_material.set_shader_parameter("caustic_scale", 0.06)
	_bubble_material.set_shader_parameter("caustic_speed", 0.5)

	_bubble_sprite.material = _bubble_material

	_bubble_sprite.z_index = 1
	_bubble_sprite.z_as_relative = false
	add_child(_bubble_sprite)

func _process(delta: float) -> void:
	position += velocity * delta

	# Bounce off side borders
	if position.x < 0:
		position.x = 0
		velocity.x = -velocity.x
	elif position.x > screen_width:
		position.x = screen_width
		velocity.x = -velocity.x

	# Spawn trail particles
	_trail_timer += delta
	if _trail_timer >= TRAIL_SPAWN_INTERVAL:
		_trail_timer = 0.0
		_spawn_trail_particle()

	# Fade and remove trail particles
	for child in _trail_container.get_children():
		var age: float = child.get_meta("age") + delta
		child.set_meta("age", age)
		var t := age / TRAIL_PARTICLE_LIFETIME
		if t >= 1.0:
			child.queue_free()
		else:
			var s := lerpf(1.0, 0.2, t)
			child.scale = Vector2(TRAIL_PARTICLE_SIZE * s, TRAIL_PARTICLE_SIZE * s)
			child.modulate.a = 1.0 - t

	# Check collision with flocks (circle-based)
	var hit_flock: Node2D = flock_manager.check_projectile_collision(global_position, letter)
	if hit_flock:
		flock_manager.add_letter_to_flock(hit_flock, letter, global_position, velocity)
		queue_free()
		return

	# Remove if off screen top
	if position.y < -50:
		queue_free()

func _spawn_trail_particle() -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)

	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(TRAIL_PARTICLE_SIZE, TRAIL_PARTICLE_SIZE)
	sprite.global_position = global_position

	var mat := ShaderMaterial.new()
	mat.shader = _trail_shader
	mat.set_shader_parameter("ball_count", 1)
	mat.set_shader_parameter("ball_positions", [Vector2.ZERO])
	mat.set_shader_parameter("ball_radius", TRAIL_PARTICLE_SIZE * 0.45)
	mat.set_shader_parameter("rect_size", Vector2(TRAIL_PARTICLE_SIZE, TRAIL_PARTICLE_SIZE))
	mat.set_shader_parameter("gradient_tex", _trail_grad_tex)
	mat.set_shader_parameter("caustic_strength", 0.3)
	mat.set_shader_parameter("caustic_scale", 0.08)
	mat.set_shader_parameter("caustic_speed", 0.6)
	sprite.material = mat

	sprite.set_meta("age", 0.0)
	_trail_container.add_child(sprite)

func _draw() -> void:
	if font == null:
		return
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	var offset := -text_size / 2.0
	draw_string(font, Vector2(offset.x, -offset.y), letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color("#1A1A1A"))
