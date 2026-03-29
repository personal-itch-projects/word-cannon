extends Node2D

const PUSH_DRAG := 2.5

# Boid parameters
const SEPARATION_RADIUS := 26.0
const SEPARATION_STRENGTH := 120.0
const COHESION_STRENGTH := 40.0
const BOUNDARY_STRENGTH := 200.0
const DRIFT_STRENGTH := 15.0
const MAX_SPEED := 60.0
const DAMPING := 0.97
const COLLISION_DIAMETER := 24.0  # 2 * falling_letter.COLLISION_RADIUS

# Bubble sizing
const BASE_BUBBLE_RADIUS := 20.0
const RADIUS_PER_LETTER := 8.0
const METABALL_RADIUS := 16.0
const BUBBLE_PADDING := 20.0

# Dent effect
const DENT_DECAY := 3.0
const DENT_INITIAL_STRENGTH := 18.0
const DENT_RADIUS := 30.0

var letters: Array[Node2D] = []
var velocity: Vector2 = Vector2.ZERO
var scorable: bool = false
var best_word: Dictionary = {}  # {word, frequency} or {}
var push_velocity: Vector2 = Vector2.ZERO
var _letter_float_data: Array = []
var _dent_pos: Vector2 = Vector2.ZERO
var _dent_strength: float = 0.0
var _popping: bool = false

var font: Font
var _bubble_sprite: Sprite2D
var _bubble_material: ShaderMaterial

func _ready() -> void:
	velocity = Vector2(0, GameManager.get_level_config()["fall_speed"])
	font = preload("res://assets/fonts/DM_Sans/DMSans-Regular.ttf")
	_setup_bubble_visual()

func _setup_bubble_visual() -> void:
	# Sprite2D with analytical metaball shader - computes the field per-pixel
	# from letter positions passed as uniforms.
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)

	_bubble_sprite = Sprite2D.new()
	_bubble_sprite.name = "BubbleSprite"
	_bubble_sprite.texture = tex

	var shader := preload("res://src/shaders/metaball_bubble.gdshader")
	_bubble_material = ShaderMaterial.new()
	_bubble_material.shader = shader
	_bubble_material.set_shader_parameter("is_scorable", false)
	_bubble_material.set_shader_parameter("ball_radius", METABALL_RADIUS)
	_bubble_sprite.material = _bubble_material

	add_child(_bubble_sprite)
	move_child(_bubble_sprite, 0)

func add_letter(letter_node: Node2D, entry_velocity: Vector2 = Vector2.ZERO) -> void:
	letters.append(letter_node)
	add_child(letter_node)
	letter_node.set_process(false)
	_init_letter_float(letter_node, entry_velocity)
	_update_possible_words()

func _init_letter_float(letter_node: Node2D, entry_velocity: Vector2 = Vector2.ZERO) -> void:
	var vel: Vector2
	if entry_velocity.length_squared() > 0.01:
		vel = entry_velocity.normalized() * clampf(entry_velocity.length() * 0.3, 10.0, MAX_SPEED)
	else:
		var angle := randf() * TAU
		vel = Vector2(cos(angle), sin(angle)) * randf_range(10.0, 30.0)
	var data := {
		"velocity": vel,
		"drift_angle": randf() * TAU,
		"drift_speed": randf_range(0.3, 0.8),
	}
	_letter_float_data.append(data)

func _update_possible_words() -> void:
	var letter_chars: Array[String] = []
	for l in letters:
		letter_chars.append(l.letter)
	if letters.size() < WordDictionary.MIN_WORD_LENGTH:
		best_word = {}
		scorable = false
		_update_scorable_visual()
		return
	best_word = WordDictionary.find_longest_word(letter_chars)
	scorable = not best_word.is_empty()
	_update_scorable_visual()

func _update_scorable_visual() -> void:
	if _bubble_material:
		_bubble_material.set_shader_parameter("is_scorable", scorable)
	queue_redraw()

func apply_push(proj_velocity: Vector2) -> void:
	push_velocity += proj_velocity * 0.25

func apply_dent(local_pos: Vector2) -> void:
	_dent_pos = local_pos
	_dent_strength = DENT_INITIAL_STRENGTH

func apply_impact(impact_pos_local: Vector2, proj_velocity: Vector2) -> void:
	var impact_strength := proj_velocity.length() * 0.2
	for i in letters.size():
		var diff: Vector2 = letters[i].position - impact_pos_local
		var dist := diff.length()
		if dist < 1.0:
			diff = Vector2(randf() - 0.5, randf() - 0.5).normalized()
			dist = 1.0
		var falloff := clampf(1.0 - dist / _get_bubble_radius(), 0.0, 1.0)
		_letter_float_data[i]["velocity"] += diff.normalized() * impact_strength * falloff

func _get_best_word() -> Dictionary:
	return best_word

func pop() -> void:
	if _popping:
		return
	_popping = true
	velocity = Vector2.ZERO
	push_velocity = Vector2.ZERO

	# Scatter letters outward
	for i in letters.size():
		var dir: Vector2 = letters[i].position.normalized()
		if dir.length_squared() < 0.01:
			dir = Vector2(randf() - 0.5, randf() - 0.5).normalized()
		_letter_float_data[i]["velocity"] = dir * randf_range(150.0, 300.0)

	# Tween: scale up bubble + fade everything out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_bubble_sprite, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN).set_delay(0.1)
	tween.chain().tween_callback(func():
		remove_all()
		queue_free()
	)

func pop_word(word: String) -> void:
	if _popping:
		return
	_popping = true
	velocity = Vector2.ZERO
	push_velocity = Vector2.ZERO

	var upper_word := word.to_upper()

	# Match letter nodes to word characters (greedy multiset match)
	var matched_indices: Array[int] = []
	var used: Array[bool] = []
	used.resize(letters.size())
	used.fill(false)
	for ci in upper_word.length():
		var ch := upper_word[ci]
		for li in letters.size():
			if not used[li] and letters[li].letter.to_upper() == ch:
				matched_indices.append(li)
				used[li] = true
				break

	# Compute word-layout target positions centered at origin
	var char_width := 18.0
	var total_width := upper_word.length() * char_width
	var start_x := -total_width / 2.0 + char_width / 2.0
	var target_positions: Array[Vector2] = []
	for ci in upper_word.length():
		target_positions.append(Vector2(start_x + ci * char_width, 0.0))

	# Tween matched letters to word positions
	var tween := create_tween()
	tween.set_parallel(true)

	# Fade bubble out quickly
	tween.tween_property(_bubble_sprite, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_OUT)

	# Move matched letters to word positions
	for mi in matched_indices.size():
		var li: int = matched_indices[mi]
		_letter_float_data[li]["velocity"] = Vector2.ZERO
		tween.tween_property(letters[li], "position", target_positions[mi], 0.3)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Scatter unmatched letters outward + fade them
	for li in letters.size():
		if not used[li]:
			var dir: Vector2 = letters[li].position.normalized()
			if dir.length_squared() < 0.01:
				dir = Vector2(randf() - 0.5, randf() - 0.5).normalized()
			_letter_float_data[li]["velocity"] = dir * randf_range(150.0, 300.0)
			tween.tween_property(letters[li], "modulate:a", 0.0, 0.3)

	# Fade whole flock starting immediately in parallel, completes at 1.3s
	tween.tween_property(self, "modulate:a", 0.0, 1.3).set_ease(Tween.EASE_IN).set_delay(0.3)

	tween.chain().tween_callback(func():
		remove_all()
		queue_free()
	)

func _process(delta: float) -> void:
	if _popping:
		# During pop: just scatter letters outward, no boid forces
		for i in letters.size():
			var vel: Vector2 = _letter_float_data[i]["velocity"]
			vel *= 0.96
			_letter_float_data[i]["velocity"] = vel
			letters[i].position += vel * delta
		_update_bubble_uniforms()
		return

	# Apply push with drag
	push_velocity = push_velocity.move_toward(Vector2.ZERO, PUSH_DRAG * push_velocity.length() * delta)
	position += (velocity + push_velocity) * delta

	# Decay dent
	if _dent_strength > 0.0:
		_dent_strength = move_toward(_dent_strength, 0.0, DENT_DECAY * _dent_strength * delta + delta)

	var bubble_r := _get_bubble_radius()
	var time := Time.get_ticks_msec() / 1000.0
	var count := letters.size()

	for i in count:
		var data: Dictionary = _letter_float_data[i]
		var vel: Vector2 = data["velocity"]
		var pos: Vector2 = letters[i].position

		# Separation: push away from nearby letters
		var separation := Vector2.ZERO
		for j in count:
			if j == i:
				continue
			var diff: Vector2 = pos - letters[j].position
			var dist := diff.length()
			if dist < SEPARATION_RADIUS and dist > 0.1:
				separation += diff.normalized() * (1.0 - dist / SEPARATION_RADIUS)
		vel += separation * SEPARATION_STRENGTH * delta

		# Cohesion: gentle pull toward center
		var to_center := -pos
		var center_dist := to_center.length()
		if center_dist > 1.0:
			vel += to_center.normalized() * COHESION_STRENGTH * delta

		# Soft boundary: stronger push when near or past bubble edge
		if center_dist > bubble_r * 0.6:
			var overshoot := (center_dist - bubble_r * 0.6) / (bubble_r * 0.4)
			vel += to_center.normalized() * BOUNDARY_STRENGTH * overshoot * delta

		# Gentle drift: slow-changing random perturbation
		var drift_angle: float = data["drift_angle"] + time * data["drift_speed"]
		vel += Vector2(cos(drift_angle), sin(drift_angle)) * DRIFT_STRENGTH * delta

		# Damping and speed limit
		vel *= DAMPING
		if vel.length() > MAX_SPEED:
			vel = vel.normalized() * MAX_SPEED

		data["velocity"] = vel
		letters[i].position = pos + vel * delta

	# Hard collision resolution: push overlapping letters apart
	_resolve_collisions()

	# Update metaball shader uniforms
	_update_bubble_uniforms()

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

func _draw() -> void:
	# Draw word label above the bubble
	if scorable:
		var bubble_r := _get_bubble_radius()
		var best := _get_best_word()
		if not best.is_empty():
			var label: String = str(best["word"]).to_upper()
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
			var text_x := -text_size.x / 2.0
			var text_y := -bubble_r - 6
			draw_string(font, Vector2(text_x, text_y), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.1, 0.6, 0.2))

func _update_bubble_uniforms() -> void:
	if not _bubble_material:
		return
	var r := _get_bubble_radius() + BUBBLE_PADDING
	# Scale sprite to cover the bubble area: 2x2 texture -> scale by r
	_bubble_sprite.scale = Vector2(r, r)
	var rect_size := Vector2(r * 2.0, r * 2.0)
	_bubble_material.set_shader_parameter("rect_size", rect_size)
	_bubble_material.set_shader_parameter("ball_count", letters.size())
	var positions: Array[Vector2] = []
	for l in letters:
		positions.append(l.position)
	while positions.size() < 16:
		positions.append(Vector2(-9999.0, -9999.0))
	_bubble_material.set_shader_parameter("ball_positions", positions)
	_bubble_material.set_shader_parameter("dent_pos", _dent_pos)
	_bubble_material.set_shader_parameter("dent_strength", _dent_strength)
	_bubble_material.set_shader_parameter("dent_radius", DENT_RADIUS)

func _get_bubble_radius() -> float:
	return BASE_BUBBLE_RADIUS + RADIUS_PER_LETTER * maxf(letters.size() - 1, 0)

func get_bounding_rect() -> Rect2:
	var r := _get_bubble_radius()
	return Rect2(global_position - Vector2(r, r), Vector2(r, r) * 2)

func get_bounding_rect_local() -> Rect2:
	var r := _get_bubble_radius()
	return Rect2(-Vector2(r, r), Vector2(r, r) * 2)

func get_bottom_y() -> float:
	return global_position.y + _get_bubble_radius()

func remove_all() -> void:
	for l in letters:
		l.queue_free()
	letters.clear()
	_letter_float_data.clear()
