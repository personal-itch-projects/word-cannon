extends Node2D

const MOVE_SPEED := 400.0
const CANNON_HEIGHT := 70.0

# Barrel shape
const MUZZLE_HALF_W := 13.0
const MUZZLE_FLARE_W := 16.0
const MUZZLE_FLARE_H := 8.0
const BASE_HALF_W := 6.0
const TRUNNION_ARM_W := 18.0
const TRUNNION_ARM_H := 10.0
const TRUNNION_BAR_H := 3.0
const CASCABEL_RADIUS := 5.0

# Jiggle animation
const WOBBLE_BUILDUP := 10.0
const WOBBLE_DAMPEN := 3.0
const WOBBLE_FREQ := 14.0
const WOBBLE_MAX_ANGLE := 0.10
const WOBBLE_SQUASH_AMOUNT := 0.06
const RECOIL_STRENGTH := 12.0
const RECOIL_RETURN := 8.0
const SHOOT_SQUASH := 0.15
const SQUASH_RETURN := 5.0

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

# Squash-stretch state (shoot bounce)
var squash: float = 0.0

var color_cannon := Color("#1A1A1A")

@onready var flock_manager: Node2D = get_parent().get_node("FlockManager")

func _ready() -> void:
	screen_width = get_viewport().get_visible_rect().size.x
	font = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	var screen_height: float = get_viewport().get_visible_rect().size.y
	position = Vector2(screen_width / 2.0, screen_height - 50)
	_pick_next_letter()

func reset() -> void:
	position.x = screen_width / 2.0
	wobble_intensity = 0.0
	recoil_offset = 0.0
	squash = 0.0
	_pick_next_letter()
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
	position.x = clampf(position.x, 50.0, screen_width - 50.0)

	is_moving = direction != 0.0

	# Cannon angle toward cursor
	var mouse_pos := get_viewport().get_mouse_position()
	var tip := Vector2(position.x, position.y - 8.0)
	var dir_to_mouse := (mouse_pos - tip).normalized()
	cannon_angle = atan2(dir_to_mouse.x, -dir_to_mouse.y)
	cannon_angle = clampf(cannon_angle, -PI / 3.0, PI / 3.0)

	# Wobble: builds up when moving, dampens when stopped
	wobble_time += delta * WOBBLE_FREQ
	if is_moving:
		wobble_intensity = move_toward(wobble_intensity, 1.0, WOBBLE_BUILDUP * delta)
	else:
		wobble_intensity = move_toward(wobble_intensity, 0.0, WOBBLE_DAMPEN * delta)

	# Recoil: kicks back on shoot, returns smoothly
	recoil_offset = move_toward(recoil_offset, 0.0, RECOIL_RETURN * delta)

	# Squash-stretch: compresses on shoot, bounces back
	squash = move_toward(squash, 0.0, SQUASH_RETURN * delta)

	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameState.State.PLAYING:
		return
	if event.is_action_pressed("ui_accept"):
		_shoot()

func _shoot() -> void:
	recoil_offset = RECOIL_STRENGTH
	squash = SHOOT_SQUASH

	var mouse_pos := get_viewport().get_mouse_position()
	var cannon_tip := Vector2(position.x, position.y - CANNON_HEIGHT)
	var dir := (mouse_pos - cannon_tip).normalized()
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
	# Jiggle rotation from movement wobble
	var wobble_rot := sin(wobble_time) * wobble_intensity * WOBBLE_MAX_ANGLE

	# Squash-stretch scale: squash compresses Y, stretches X
	var scale_x := 1.0 + squash + sin(wobble_time) * wobble_intensity * WOBBLE_SQUASH_AMOUNT
	var scale_y := 1.0 - squash - sin(wobble_time) * wobble_intensity * WOBBLE_SQUASH_AMOUNT * 0.5

	var total_angle := cannon_angle + wobble_rot
	draw_set_transform(Vector2(0, 0), total_angle, Vector2(scale_x, scale_y))
	_draw_cannon_body()

	# Letter preview above muzzle
	if next_letter != "":
		var preview_y := -CANNON_HEIGHT - MUZZLE_FLARE_H - 10.0 + recoil_offset
		var text_size := font.get_string_size(next_letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
		draw_string(font, Vector2(-text_size.x / 2.0, preview_y), next_letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, color_cannon)

	draw_set_transform(Vector2.ZERO)

func _draw_cannon_body() -> void:
	var r := recoil_offset
	var h := CANNON_HEIGHT
	var c := color_cannon

	# Main barrel: tapered from wide muzzle (top) to narrow base (bottom)
	var barrel := PackedVector2Array([
		Vector2(-MUZZLE_HALF_W, -h + r),
		Vector2(MUZZLE_HALF_W, -h + r),
		Vector2(BASE_HALF_W, r),
		Vector2(-BASE_HALF_W, r),
	])
	draw_colored_polygon(barrel, c)

	# Muzzle flare: wider cap at the top
	var flare := PackedVector2Array([
		Vector2(-MUZZLE_FLARE_W, -h + r),
		Vector2(MUZZLE_FLARE_W, -h + r),
		Vector2(MUZZLE_HALF_W, -h + MUZZLE_FLARE_H + r),
		Vector2(-MUZZLE_HALF_W, -h + MUZZLE_FLARE_H + r),
	])
	draw_colored_polygon(flare, c)

	# Trunnions: two horizontal bars with rectangular arms at each end
	# Upper trunnion at ~45% height
	var ty1 := -h * 0.45 + r
	# Lower trunnion at ~35% height
	var ty2 := -h * 0.30 + r

	# Width of barrel at trunnion positions
	var bw1 := lerpf(BASE_HALF_W, MUZZLE_HALF_W, 0.45)
	var bw2 := lerpf(BASE_HALF_W, MUZZLE_HALF_W, 0.30)

	# Horizontal bars (full width)
	var bar_w1 := bw1 + TRUNNION_ARM_W
	var bar_w2 := bw2 + TRUNNION_ARM_W
	draw_rect(Rect2(-bar_w1, ty1 - TRUNNION_BAR_H / 2.0, bar_w1 * 2.0, TRUNNION_BAR_H), c)
	draw_rect(Rect2(-bar_w2, ty2 - TRUNNION_BAR_H / 2.0, bar_w2 * 2.0, TRUNNION_BAR_H), c)

	# Vertical arms at each end (left and right, upper and lower)
	# Upper trunnion arms
	draw_rect(Rect2(-bar_w1, ty1 - TRUNNION_ARM_H / 2.0, TRUNNION_ARM_W, TRUNNION_ARM_H), c)
	draw_rect(Rect2(bar_w1 - TRUNNION_ARM_W, ty1 - TRUNNION_ARM_H / 2.0, TRUNNION_ARM_W, TRUNNION_ARM_H), c)
	# Lower trunnion arms
	draw_rect(Rect2(-bar_w2, ty2 - TRUNNION_ARM_H / 2.0, TRUNNION_ARM_W, TRUNNION_ARM_H), c)
	draw_rect(Rect2(bar_w2 - TRUNNION_ARM_W, ty2 - TRUNNION_ARM_H / 2.0, TRUNNION_ARM_W, TRUNNION_ARM_H), c)

	# Cascabel (ball at bottom)
	draw_circle(Vector2(0, r + CASCABEL_RADIUS + 2), CASCABEL_RADIUS, c)
