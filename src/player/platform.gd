extends Node2D

const MOVE_SPEED := 400.0
const PLATFORM_WIDTH := 100.0
const PLATFORM_HEIGHT := 16.0
const CANNON_WIDTH := 8.0
const CANNON_HEIGHT := 30.0

# Medieval cannon dimensions
const BARREL_LENGTH := 36.0
const BARREL_REAR_RADIUS := 8.0
const BARREL_FRONT_RADIUS := 6.0
const MUZZLE_RADIUS := 9.0
const CARRIAGE_WIDTH := 50.0
const CARRIAGE_HEIGHT := 14.0
const WHEEL_RADIUS := 10.0

# Animation
const WOBBLE_BUILDUP_SPEED := 8.0
const WOBBLE_DAMPEN_SPEED := 4.0
const WOBBLE_FREQUENCY := 12.0
const WOBBLE_MAX_ANGLE := 0.08
const RECOIL_STRENGTH := 10.0
const RECOIL_RETURN_SPEED := 6.0

var screen_width: float
var next_letter: String = ""
var font: Font
var cannon_angle: float = 0.0

# Wobble state
var wobble_intensity: float = 0.0
var wobble_time: float = 0.0
var is_moving: bool = false

# Recoil state
var recoil_offset: float = 0.0

# Colors
var color_barrel := Color("#3B3530")
var color_barrel_highlight := Color("#524A42")
var color_band := Color("#2A2623")
var color_carriage := Color("#5C4A3A")
var color_carriage_dark := Color("#3E3228")
var color_wheel := Color("#4A3E34")
var color_wheel_hub := Color("#2A2623")
var color_muzzle_inner := Color("#1A1A1A")
var color_text := Color("#1A1A1A")

# Shader
var shader_material: ShaderMaterial

@onready var flock_manager: Node2D = get_parent().get_node("FlockManager")

func _ready() -> void:
	screen_width = get_viewport().get_visible_rect().size.x
	font = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	var screen_height: float = get_viewport().get_visible_rect().size.y
	position = Vector2(screen_width / 2.0, screen_height - 50)
	_pick_next_letter()
	_setup_shader()

func _setup_shader() -> void:
	var shader := preload("res://src/player/cannon.gdshader")
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	material = shader_material

func reset() -> void:
	position.x = screen_width / 2.0
	wobble_intensity = 0.0
	recoil_offset = 0.0
	_pick_next_letter()
	# Remove any existing projectiles
	for child in get_children():
		child.queue_free()

func _process(delta: float) -> void:
	if GameManager.current_state != GameState.State.PLAYING:
		return

	# Movement
	var direction := 0.0
	var left_action := "ui_left" if GameManager.use_arrow_keys else "move_left"
	var right_action := "ui_right" if GameManager.use_arrow_keys else "move_right"
	if Input.is_action_pressed(left_action):
		direction = -1.0
	if Input.is_action_pressed(right_action):
		direction = 1.0
	position.x += direction * MOVE_SPEED * delta
	position.x = clampf(position.x, PLATFORM_WIDTH / 2.0, screen_width - PLATFORM_WIDTH / 2.0)

	is_moving = direction != 0.0

	# Update cannon angle toward cursor
	var mouse_pos := get_viewport().get_mouse_position()
	var cannon_tip := Vector2(position.x, position.y - PLATFORM_HEIGHT / 2.0)
	var dir_to_mouse := (mouse_pos - cannon_tip).normalized()
	cannon_angle = atan2(dir_to_mouse.x, -dir_to_mouse.y)
	cannon_angle = clampf(cannon_angle, -PI / 3.0, PI / 3.0)

	# Update wobble animation
	wobble_time += delta * WOBBLE_FREQUENCY
	if is_moving:
		wobble_intensity = move_toward(wobble_intensity, 1.0, WOBBLE_BUILDUP_SPEED * delta)
	else:
		wobble_intensity = move_toward(wobble_intensity, 0.0, WOBBLE_DAMPEN_SPEED * delta)

	# Update recoil animation
	recoil_offset = move_toward(recoil_offset, 0.0, RECOIL_RETURN_SPEED * delta)

	# Update shader uniforms
	if shader_material:
		shader_material.set_shader_parameter("wobble_amount", wobble_intensity * sin(wobble_time))
		shader_material.set_shader_parameter("recoil_amount", recoil_offset / RECOIL_STRENGTH)

	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameState.State.PLAYING:
		return
	if event.is_action_pressed("ui_accept"):
		_shoot()

func _shoot() -> void:
	# Trigger recoil
	recoil_offset = RECOIL_STRENGTH

	var mouse_pos := get_viewport().get_mouse_position()
	var cannon_tip := Vector2(position.x, position.y - PLATFORM_HEIGHT / 2.0 - CANNON_HEIGHT)
	var dir := (mouse_pos - cannon_tip).normalized()
	# Prevent shooting downward
	if dir.y > -0.1:
		dir = Vector2(dir.x, -0.1).normalized()
	var vel := dir * preload("res://src/player/projectile.gd").SPEED

	var ProjectileScript := preload("res://src/player/projectile.gd")
	var proj := Node2D.new()
	proj.set_script(ProjectileScript)
	proj.setup(next_letter, cannon_tip, flock_manager, vel)
	get_parent().add_child(proj)
	_pick_next_letter()

func _pick_next_letter() -> void:
	var allowed := GameManager.get_allowed_letters()
	next_letter = allowed[randi() % allowed.length()]
	queue_redraw()

func _draw() -> void:
	# Calculate wobble rotation offset
	var wobble_rot := sin(wobble_time) * wobble_intensity * WOBBLE_MAX_ANGLE

	# -- Carriage / Base --
	_draw_carriage(wobble_rot)

	# -- Cannon barrel (rotated toward cursor + wobble + recoil) --
	var barrel_origin := Vector2(0, -CARRIAGE_HEIGHT * 0.6)
	var total_angle := cannon_angle + wobble_rot
	draw_set_transform(barrel_origin, total_angle)
	_draw_barrel()

	# Next letter preview above muzzle
	if next_letter != "":
		var preview_y := -BARREL_LENGTH - MUZZLE_RADIUS - 14.0 + recoil_offset
		var text_size := font.get_string_size(next_letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
		draw_string(font, Vector2(-text_size.x / 2.0, preview_y), next_letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, color_text)

	draw_set_transform(Vector2.ZERO)

func _draw_carriage(wobble_rot: float) -> void:
	# Main carriage body (trapezoid shape)
	var cw := CARRIAGE_WIDTH / 2.0
	var ch := CARRIAGE_HEIGHT
	var narrow := cw * 0.7
	var carriage_points := PackedVector2Array([
		Vector2(-cw, 0),
		Vector2(cw, 0),
		Vector2(narrow, -ch),
		Vector2(-narrow, -ch),
	])
	# Apply wobble skew to carriage
	var skewed_points := PackedVector2Array()
	for p in carriage_points:
		var height_factor := -p.y / ch
		skewed_points.append(Vector2(p.x + sin(wobble_time) * wobble_intensity * 3.0 * height_factor, p.y))
	draw_colored_polygon(skewed_points, color_carriage)

	# Carriage top edge highlight
	draw_line(
		Vector2(-narrow + sin(wobble_time) * wobble_intensity * 3.0, -ch),
		Vector2(narrow + sin(wobble_time) * wobble_intensity * 3.0, -ch),
		color_carriage_dark, 2.0
	)

	# Wheels
	var wheel_y := 2.0
	_draw_wheel(Vector2(-cw + WHEEL_RADIUS * 0.5, wheel_y))
	_draw_wheel(Vector2(cw - WHEEL_RADIUS * 0.5, wheel_y))

func _draw_wheel(center: Vector2) -> void:
	# Outer wheel
	draw_circle(center, WHEEL_RADIUS, color_wheel)
	# Hub
	draw_circle(center, WHEEL_RADIUS * 0.35, color_wheel_hub)
	# Spokes
	for i in range(4):
		var angle := i * PI / 4.0 + wobble_time * 0.1
		var spoke_end := center + Vector2(cos(angle), sin(angle)) * WHEEL_RADIUS * 0.8
		draw_line(center, spoke_end, color_wheel_hub, 1.5)

func _draw_barrel() -> void:
	# Recoil pushes barrel backward (positive Y in local space = toward base)
	var recoil_y := recoil_offset

	# Main barrel body (tapered polygon)
	var rear_r := BARREL_REAR_RADIUS
	var front_r := BARREL_FRONT_RADIUS
	var length := BARREL_LENGTH
	var barrel_body := PackedVector2Array([
		Vector2(-rear_r, recoil_y),
		Vector2(rear_r, recoil_y),
		Vector2(front_r, -length + recoil_y),
		Vector2(-front_r, -length + recoil_y),
	])
	draw_colored_polygon(barrel_body, color_barrel)

	# Barrel highlight (left side light reflection)
	var highlight_body := PackedVector2Array([
		Vector2(-rear_r + 1.5, recoil_y + 2),
		Vector2(-rear_r * 0.3, recoil_y + 2),
		Vector2(-front_r * 0.3, -length + recoil_y + 2),
		Vector2(-front_r + 1.5, -length + recoil_y + 2),
	])
	draw_colored_polygon(highlight_body, color_barrel_highlight)

	# Reinforcing bands
	for i in range(3):
		var t := (i + 1.0) / 4.0
		var band_y := -length * t + recoil_y
		var band_r := lerpf(front_r, rear_r, 1.0 - t) + 2.0
		draw_line(Vector2(-band_r, band_y), Vector2(band_r, band_y), color_band, 2.5)

	# Muzzle flare at the end
	var muzzle_y := -length + recoil_y
	draw_circle(Vector2(0, muzzle_y), MUZZLE_RADIUS, color_barrel)
	# Dark muzzle opening
	draw_circle(Vector2(0, muzzle_y), MUZZLE_RADIUS * 0.55, color_muzzle_inner)

	# Rear bulge (breech)
	draw_circle(Vector2(0, recoil_y), rear_r + 1.5, color_barrel)
	# Fuse hole on top of breech
	draw_circle(Vector2(0, recoil_y + 2), 2.0, color_band)
