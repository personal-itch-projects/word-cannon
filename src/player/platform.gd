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

const ARSENAL_SIZE := 10

var screen_width: float
var arsenal: Array[String] = []
var font: Font
var cannon_angle: float = 0.0
var _loaded_projectile: Node2D

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
	font = preload("res://assets/fonts/Nunito/Nunito-Regular.ttf")
	var screen_height: float = get_viewport().get_visible_rect().size.y
	var bounds := GameManager.get_play_bounds()
	position = Vector2((bounds.x + bounds.y) / 2.0, screen_height - 50)
	_fill_arsenal()
	_create_loaded_projectile()
	WordDictionary.language_changed.connect(_on_language_changed)

func _on_language_changed(_lang: String) -> void:
	_fill_arsenal()
	_recreate_loaded_projectile()

func reset() -> void:
	var bounds := GameManager.get_play_bounds()
	position.x = (bounds.x + bounds.y) / 2.0
	wobble_intensity = 0.0
	recoil_offset = 0.0
	squash = 0.0
	_loaded_projectile = null
	_fill_arsenal()
	for child in get_children():
		child.queue_free()
	_create_loaded_projectile()

func _process(delta: float) -> void:
	if GameManager.current_state != GameState.State.PLAYING:
		return

	# Movement
	var direction := 0.0
	if Input.is_physical_key_pressed(GameManager.bindings["move_left"]):
		direction = -1.0
	if Input.is_physical_key_pressed(GameManager.bindings["move_right"]):
		direction = 1.0
	position.x += direction * MOVE_SPEED * delta
	var bounds := GameManager.get_play_bounds()
	position.x = clampf(position.x, bounds.x + 50.0, bounds.y - 50.0)

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

	# Position loaded projectile at cannon tip
	if _loaded_projectile:
		var wobble_rot := sin(wobble_time) * wobble_intensity * WOBBLE_MAX_ANGLE
		var total_angle := cannon_angle + wobble_rot
		var local_tip := Vector2(0, -CANNON_HEIGHT - MUZZLE_FLARE_H - 10.0 + recoil_offset)
		_loaded_projectile.position = local_tip.rotated(total_angle)

	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameState.State.PLAYING:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if flock_manager.is_click_on_flock(event.position):
			return
		_shoot()

func _shoot() -> void:
	if arsenal.is_empty() or not _loaded_projectile:
		return
	recoil_offset = RECOIL_STRENGTH
	squash = SHOOT_SQUASH

	arsenal.pop_front()
	var mouse_pos := get_viewport().get_mouse_position()
	var launch_pos := _loaded_projectile.global_position
	var dir := (mouse_pos - launch_pos).normalized()
	if dir.y > -0.1:
		dir = Vector2(dir.x, -0.1).normalized()
	var vel := dir * preload("res://src/player/projectile.gd").SPEED

	# Reparent to game layer and launch
	var global_pos := _loaded_projectile.global_position
	remove_child(_loaded_projectile)
	_loaded_projectile.position = global_pos
	get_parent().add_child(_loaded_projectile)
	_loaded_projectile.launch(flock_manager, vel)
	_loaded_projectile = null

	_append_arsenal_letter()
	_create_loaded_projectile()

func _fill_arsenal() -> void:
	arsenal.clear()
	var allowed := GameManager.get_allowed_letters()
	var flock_data := _get_flock_letter_arrays()
	for i in ARSENAL_SIZE:
		if flock_data.is_empty():
			arsenal.append(WordDictionary.pick_weighted_letter(allowed))
		else:
			arsenal.append(WordDictionary.pick_slot_aware_letter(flock_data, allowed))
	queue_redraw()

func _append_arsenal_letter() -> void:
	var allowed := GameManager.get_allowed_letters()
	var flock_data := _get_flock_letter_arrays()
	if flock_data.is_empty():
		arsenal.append(WordDictionary.pick_weighted_letter(allowed))
	else:
		arsenal.append(WordDictionary.pick_slot_aware_letter(flock_data, allowed))
	queue_redraw()

func _get_flock_letter_arrays() -> Array:
	var result: Array = []
	for flock in flock_manager.flocks:
		if flock._popping:
			continue
		var flock_letters: Array[String] = []
		for l in flock.letters:
			flock_letters.append(l.letter)
		result.append(flock_letters)
	return result

func _draw() -> void:
	# Jiggle rotation from movement wobble
	var wobble_rot := sin(wobble_time) * wobble_intensity * WOBBLE_MAX_ANGLE

	# Squash-stretch scale: squash compresses Y, stretches X
	var scale_x := 1.0 + squash + sin(wobble_time) * wobble_intensity * WOBBLE_SQUASH_AMOUNT
	var scale_y := 1.0 - squash - sin(wobble_time) * wobble_intensity * WOBBLE_SQUASH_AMOUNT * 0.5

	var total_angle := cannon_angle + wobble_rot
	draw_set_transform(Vector2(0, 0), total_angle, Vector2(scale_x, scale_y))
	_draw_cannon_body()

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

func _create_loaded_projectile() -> void:
	if arsenal.is_empty():
		return
	var ProjectileScript := preload("res://src/player/projectile.gd")
	_loaded_projectile = Node2D.new()
	_loaded_projectile.set_script(ProjectileScript)
	_loaded_projectile.setup_preview(arsenal[0])
	add_child(_loaded_projectile)

func _recreate_loaded_projectile() -> void:
	if _loaded_projectile:
		_loaded_projectile.queue_free()
		_loaded_projectile = null
	_create_loaded_projectile()
