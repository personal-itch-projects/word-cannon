class_name BubbleButton
extends Node2D

const SEPARATION_RADIUS := 16.0
const SEPARATION_STRENGTH := 100.0
const SPRING_STRENGTH := 30.0
const DRIFT_STRENGTH := 22.0
const MAX_SPEED := 28.0
const DAMPING := 0.97
const COLLISION_DIAMETER := 14.0

const BASE_BUBBLE_RADIUS := 14.0
const RADIUS_PER_LETTER := 7.0
const METABALL_RADIUS := 14.0
const BUBBLE_PADDING := 16.0

const HOVER_SPREAD_SPEED := 3.0

var letters: Array[Node2D] = []
var _letter_float_data: Array = []
var _home_positions: Array[Vector2] = []
var _popping: bool = false
var _hovered: bool = false
var _hover_amount: float = 0.0
var _hover_center: Vector2 = Vector2.ZERO
var _text: String = ""
var _callback: Callable
var _pop_on_click: bool = true

var _bubble_sprite: Sprite2D
var _bubble_material: ShaderMaterial

func _ready() -> void:
	_setup_bubble_visual()

static func create(parent: Node, pos: Vector2, text: String, callback: Callable, pop_on_click: bool = true) -> BubbleButton:
	var button := BubbleButton.new()
	parent.add_child(button)
	button.position = pos
	button.init(text, callback, pop_on_click)
	return button

func init(text: String, callback: Callable, pop_on_click: bool = true) -> void:
	_text = text
	_callback = callback
	_pop_on_click = pop_on_click
	_build_letters(text)

func _setup_bubble_visual() -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)

	_bubble_sprite = Sprite2D.new()
	_bubble_sprite.name = "BubbleSprite"
	_bubble_sprite.texture = tex

	var shader := preload("res://src/shaders/metaball_bubble.gdshader")
	_bubble_material = ShaderMaterial.new()
	_bubble_material.shader = shader
	_bubble_material.set_shader_parameter("ball_radius", METABALL_RADIUS)

	# Gradient texture: bright rim -> fill -> deep interior (richer for enveloping look)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.15, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.88, 0.95, 1.0, 0.70),
		Color(0.80, 0.92, 1.0, 0.55),
		Color(0.72, 0.87, 1.0, 0.42),
		Color(0.68, 0.84, 1.0, 0.35),
	])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	_bubble_material.set_shader_parameter("gradient_tex", grad_tex)
	_bubble_material.set_shader_parameter("caustic_strength", 0.4)
	_bubble_material.set_shader_parameter("caustic_scale", 0.04)
	_bubble_material.set_shader_parameter("caustic_speed", 0.3)

	_bubble_sprite.material = _bubble_material

	_bubble_sprite.z_index = 1
	_bubble_sprite.z_as_relative = false
	add_child(_bubble_sprite)

func _build_letters(text: String) -> void:
	# Remove existing letters
	for l in letters:
		l.queue_free()
	letters.clear()
	_letter_float_data.clear()
	_home_positions.clear()

	var upper := text.to_upper()
	var char_width := 18.0
	var total_width := upper.length() * char_width
	var start_x := -total_width / 2.0 + char_width / 2.0

	var FallingLetterScript := preload("res://src/letters/falling_letter.gd")
	for i in upper.length():
		var home := Vector2(start_x + i * char_width, 0.0)
		_home_positions.append(home)

		var letter_node := Node2D.new()
		letter_node.set_script(FallingLetterScript)
		letter_node.letter = upper[i]
		letter_node.velocity = Vector2.ZERO
		letter_node.position = home
		letter_node.set_process(false)
		add_child(letter_node)
		letters.append(letter_node)

		var angle := randf() * TAU
		_letter_float_data.append({
			"velocity": Vector2(cos(angle), sin(angle)) * randf_range(5.0, 15.0),
			"drift_angle": randf() * TAU,
			"drift_speed": randf_range(1.5, 3.0),
		})
	move_child(_bubble_sprite, -1)

func rebuild(text: String) -> void:
	_text = text
	_build_letters(text)

func reset_state() -> void:
	_popping = false
	modulate.a = 1.0
	if _bubble_sprite:
		_bubble_sprite.modulate.a = 1.0
	for i in letters.size():
		letters[i].modulate.a = 1.0
		letters[i].position = _home_positions[i]
		_letter_float_data[i]["velocity"] = Vector2.ZERO

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_hovered = false
		return
	if _popping:
		for i in letters.size():
			var vel: Vector2 = _letter_float_data[i]["velocity"]
			vel *= 0.96
			_letter_float_data[i]["velocity"] = vel
			letters[i].position += vel * delta
		_update_bubble_uniforms()
		return

	# Hover detection (rectangular to match bubble shape)
	var mouse_pos := get_viewport().get_mouse_position()
	var local_mouse := mouse_pos - global_position
	var char_width := 18.0
	var half_w: float = letters.size() * char_width / 2.0 + METABALL_RADIUS
	var half_h: float = METABALL_RADIUS + 10.0
	_hovered = absf(local_mouse.x) < half_w and absf(local_mouse.y) < half_h

	# Hover green tint: spread from cursor
	if _hovered:
		_hover_center = local_mouse
		_hover_amount = move_toward(_hover_amount, 1.0, HOVER_SPREAD_SPEED * delta)
	else:
		_hover_amount = move_toward(_hover_amount, 0.0, HOVER_SPREAD_SPEED * delta * 1.5)

	var time := Time.get_ticks_msec() / 1000.0
	var count := letters.size()

	for i in count:
		var data: Dictionary = _letter_float_data[i]
		var vel: Vector2 = data["velocity"]
		var pos: Vector2 = letters[i].position

		# Spring toward home position
		var to_home: Vector2 = _home_positions[i] - pos
		vel += to_home * SPRING_STRENGTH * delta

		# Separation
		var separation := Vector2.ZERO
		for j in count:
			if j == i:
				continue
			var diff: Vector2 = pos - letters[j].position
			var dist := diff.length()
			if dist < SEPARATION_RADIUS and dist > 0.1:
				separation += diff.normalized() * (1.0 - dist / SEPARATION_RADIUS)
		vel += separation * SEPARATION_STRENGTH * delta

		# Gentle drift (mostly horizontal to keep letters on the line)
		var drift_angle: float = data["drift_angle"] + time * data["drift_speed"]
		var drift_vec := Vector2(cos(drift_angle), sin(drift_angle) * 0.4)
		vel += drift_vec * DRIFT_STRENGTH * delta

		# Damping and speed limit
		vel *= DAMPING
		if vel.length() > MAX_SPEED:
			vel = vel.normalized() * MAX_SPEED

		data["velocity"] = vel
		letters[i].position = pos + vel * delta

	_resolve_collisions()
	_update_bubble_uniforms()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _popping:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hovered:
			if _pop_on_click:
				_pop_and_trigger()
			else:
				if _callback.is_valid():
					_callback.call()
			get_viewport().set_input_as_handled()

func _pop_and_trigger() -> void:
	if _popping:
		return
	_popping = true

	# Scatter letters in random directions
	for i in letters.size():
		var angle := randf() * TAU
		var dir := Vector2(cos(angle), sin(angle))
		_letter_float_data[i]["velocity"] = dir * randf_range(150.0, 300.0)

	# Fade bubble + whole node
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_bubble_sprite, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN).set_delay(0.1)

	# Fire callback after the scatter is visible
	get_tree().create_timer(0.5).timeout.connect(func():
		if _callback.is_valid():
			_callback.call()
	)

func _resolve_collisions() -> void:
	var count := letters.size()
	for _pass in 3:
		for i in count:
			for j in range(i + 1, count):
				var diff: Vector2 = letters[i].position - letters[j].position
				var dist := diff.length()
				if dist < COLLISION_DIAMETER and dist > 0.01:
					var overlap := COLLISION_DIAMETER - dist
					var push := diff.normalized() * overlap * 0.5
					letters[i].position += push
					letters[j].position -= push
				elif dist <= 0.01:
					var nudge := Vector2(randf() - 0.5, randf() - 0.5).normalized() * COLLISION_DIAMETER * 0.5
					letters[i].position += nudge
					letters[j].position -= nudge

func _update_bubble_uniforms() -> void:
	if not _bubble_material:
		return
	# Compute rectangular extents: wide for horizontal letter spread, short vertically
	var char_width := 18.0
	var half_w: float = letters.size() * char_width / 2.0 + METABALL_RADIUS + BUBBLE_PADDING
	var half_h: float = METABALL_RADIUS + BUBBLE_PADDING + 10.0
	_bubble_sprite.scale = Vector2(half_w, half_h)
	var rect_size := Vector2(half_w * 2.0, half_h * 2.0)
	_bubble_material.set_shader_parameter("rect_size", rect_size)
	_bubble_material.set_shader_parameter("ball_count", letters.size())
	var positions: Array[Vector2] = []
	for l in letters:
		positions.append(l.position)
	while positions.size() < 16:
		positions.append(Vector2(-9999.0, -9999.0))
	_bubble_material.set_shader_parameter("ball_positions", positions)
	_bubble_material.set_shader_parameter("hover_center", _hover_center)
	_bubble_material.set_shader_parameter("hover_amount", _hover_amount)
	_bubble_material.set_shader_parameter("dent_pos", Vector2.ZERO)
	_bubble_material.set_shader_parameter("dent_strength", 0.0)
	_bubble_material.set_shader_parameter("dent_radius", 30.0)

func _get_bubble_radius() -> float:
	return BASE_BUBBLE_RADIUS + RADIUS_PER_LETTER * maxf(letters.size() - 1, 0)
