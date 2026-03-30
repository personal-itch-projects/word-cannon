extends Node2D

const SPEED := 800.0
const SIZE := 15.0

# Trail: spawn soft circle particles at random offsets with random TTL
const TRAIL_SPAWN_INTERVAL := 0.04
const TRAIL_PARTICLES_PER_SPAWN := 2
const TRAIL_PARTICLE_MIN_SIZE := 16.0
const TRAIL_PARTICLE_MAX_SIZE := 28.0
const TRAIL_MIN_TTL := 0.4
const TRAIL_MAX_TTL := 0.8
const TRAIL_SPREAD := 8.0

# Bubble visual
const BUBBLE_SIZE := 24.0

var letter: String = ""
var velocity: Vector2 = Vector2(0, -SPEED)
var flock_manager: Node2D
var font: Font
var screen_width: float
var launched := false
var target_flock: Node2D = null

var _trail_timer: float = 0.0
var _trail_container: Node2D
var _trail_tex: ImageTexture
var _bubble_sprite: Sprite2D
var _bubble_material: ShaderMaterial

func setup(p_letter: String, p_position: Vector2, p_flock_manager: Node2D, p_velocity: Vector2 = Vector2(0, -SPEED)) -> void:
	letter = p_letter
	position = p_position
	flock_manager = p_flock_manager
	velocity = p_velocity
	font = preload("res://assets/fonts/Nunito/Nunito-Regular.ttf")
	launched = true

func setup_preview(p_letter: String) -> void:
	letter = p_letter
	font = preload("res://assets/fonts/Nunito/Nunito-Regular.ttf")

func launch(p_flock_manager: Node2D, p_velocity: Vector2) -> void:
	flock_manager = p_flock_manager
	velocity = p_velocity
	launched = true

func _ready() -> void:
	screen_width = get_viewport().get_visible_rect().size.x
	_setup_trail()
	_setup_bubble()

func _setup_trail() -> void:
	_trail_container = Node2D.new()
	_trail_container.top_level = true
	add_child(_trail_container)

	# Pre-bake a soft radial gradient circle texture (shared by all particles)
	var tex_size := 32
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var center := float(tex_size) / 2.0
	for y in tex_size:
		for x in tex_size:
			var dist := Vector2(x - center + 0.5, y - center + 0.5).length() / center
			var alpha := clampf(1.0 - dist * dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.75, 0.88, 1.0, alpha * 0.5))
	_trail_tex = ImageTexture.create_from_image(img)

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
	if not launched:
		return
	position += velocity * delta

	# Bounce off play area borders
	var bounds := GameManager.get_play_bounds()
	if position.x < bounds.x:
		position.x = bounds.x
		velocity.x = -velocity.x
	elif position.x > bounds.y:
		position.x = bounds.y
		velocity.x = -velocity.x

	# Spawn trail particles
	_trail_timer += delta
	if _trail_timer >= TRAIL_SPAWN_INTERVAL:
		_trail_timer = 0.0
		for _i in TRAIL_PARTICLES_PER_SPAWN:
			_spawn_trail_particle()

	# Check collision with flocks
	var hit_flock: Node2D = flock_manager.check_projectile_collision(global_position, letter, target_flock)
	if hit_flock:
		flock_manager.add_letter_to_flock(hit_flock, letter, global_position, velocity)
		SfxManager.play_random(SfxManager.sfx_bubble_merge)
		queue_free()
		return

	# Remove if outside viewport
	var screen_height: float = get_viewport().get_visible_rect().size.y
	if position.y < -50 or position.y > screen_height + 50 or position.x < -50 or position.x > screen_width + 50:
		queue_free()

func _spawn_trail_particle() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _trail_tex
	var particle_size := randf_range(TRAIL_PARTICLE_MIN_SIZE, TRAIL_PARTICLE_MAX_SIZE)
	var s := particle_size / 32.0
	sprite.scale = Vector2(s, s)
	sprite.global_position = global_position + Vector2(
		randf_range(-TRAIL_SPREAD, TRAIL_SPREAD),
		randf_range(-TRAIL_SPREAD, TRAIL_SPREAD),
	)
	_trail_container.add_child(sprite)

	var ttl := randf_range(TRAIL_MIN_TTL, TRAIL_MAX_TTL)
	var tween := sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2.ZERO, ttl).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "modulate:a", 0.0, ttl).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(sprite.queue_free)

func _draw() -> void:
	if font == null:
		return
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	var offset := -text_size / 2.0
	draw_string(font, Vector2(offset.x, -offset.y), letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color("#1A1A1A"))
