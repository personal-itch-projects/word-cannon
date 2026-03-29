extends Node2D

const SPEED := 800.0
const SIZE := 15.0

# Trail metaball settings
const TRAIL_PARTICLE_AMOUNT := 25
const TRAIL_PARTICLE_LIFETIME := 0.35

# Bubble visual
const BUBBLE_SIZE := 24.0

var letter: String = ""
var velocity: Vector2 = Vector2(0, -SPEED)
var flock_manager: Node2D
var font: Font
var screen_width: float

var _bubble_sprite: Sprite2D
var _bubble_material: ShaderMaterial
var _trail_viewport: SubViewport
var _trail_display: Sprite2D
var _trail_particles: CPUParticles2D
var _trail_core: Sprite2D

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
	var screen_size := get_viewport().get_visible_rect().size

	# Radial gradient texture: bright center fading to black edges
	var radial_img := Image.create(64, 64, false, Image.FORMAT_R8)
	for y in 64:
		for x in 64:
			var dx := (x - 31.5) / 31.5
			var dy := (y - 31.5) / 31.5
			var dist := sqrt(dx * dx + dy * dy)
			var val := clampf(1.0 - dist, 0.0, 1.0)
			radial_img.set_pixel(x, y, Color(val, val, val, 1.0))
	var radial_tex := ImageTexture.create_from_image(radial_img)

	# SubViewport: black background accumulates brightness with additive blend
	_trail_viewport = SubViewport.new()
	_trail_viewport.transparent_bg = false
	_trail_viewport.size = Vector2i(int(screen_size.x), int(screen_size.y))
	_trail_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_trail_viewport)

	# Additive blend material for all viewport contents
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# Core blob: follows projectile, merges with trail particles
	_trail_core = Sprite2D.new()
	_trail_core.texture = radial_tex
	_trail_core.material = add_mat
	_trail_core.scale = Vector2.ONE * 0.5
	_trail_viewport.add_child(_trail_core)

	# CPUParticles2D: emits trail particles with radial gradient
	_trail_particles = CPUParticles2D.new()
	_trail_particles.texture = radial_tex
	_trail_particles.material = add_mat
	_trail_particles.emitting = true
	_trail_particles.amount = TRAIL_PARTICLE_AMOUNT
	_trail_particles.lifetime = TRAIL_PARTICLE_LIFETIME
	_trail_particles.explosiveness = 0.0
	_trail_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	_trail_particles.direction = Vector2.ZERO
	_trail_particles.spread = 180.0
	_trail_particles.initial_velocity_min = 5.0
	_trail_particles.initial_velocity_max = 20.0
	_trail_particles.gravity = Vector2.ZERO
	_trail_particles.scale_amount_min = 0.2
	_trail_particles.scale_amount_max = 0.35
	# Fade alpha over lifetime to shrink metaballs (per article technique)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_trail_particles.color_ramp = ramp
	_trail_viewport.add_child(_trail_particles)

	# Display: renders viewport texture with metaball gradient shader
	_trail_display = Sprite2D.new()
	_trail_display.texture = _trail_viewport.get_texture()
	_trail_display.centered = false
	_trail_display.top_level = true
	_trail_display.position = Vector2.ZERO
	_trail_display.z_index = -1

	var shader := preload("res://src/shaders/metaball_trail.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	# Color gradient: maps brightness to bubble colors (transparent below threshold)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.05, 0.2, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.85, 0.93, 1.0, 0.55),
		Color(0.78, 0.90, 1.0, 0.45),
		Color(0.70, 0.85, 1.0, 0.30),
		Color(0.65, 0.82, 1.0, 0.25),
	])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.set_shader_parameter("gradient_tex", grad_tex)
	_trail_display.material = mat
	add_child(_trail_display)

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

	# Update trail core and particle emitter to follow projectile
	_trail_core.position = global_position
	_trail_particles.position = global_position

	# Check collision with flocks (circle-based)
	var hit_flock: Node2D = flock_manager.check_projectile_collision(global_position, letter)
	if hit_flock:
		flock_manager.add_letter_to_flock(hit_flock, letter, global_position, velocity)
		queue_free()
		return

	# Remove if off screen top
	if position.y < -50:
		queue_free()

func _draw() -> void:
	if font == null:
		return
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	var offset := -text_size / 2.0
	draw_string(font, Vector2(offset.x, -offset.y), letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color("#1A1A1A"))
