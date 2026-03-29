extends Node2D

const SCORE_BASE := 2
const SCORE_MULTIPLIER := 3
const MAX_FREQ := 1500000.0

var flocks: Array[Node2D] = []
var screen_height: float
var input_blocked: bool = false

func _ready() -> void:
	screen_height = get_viewport().get_visible_rect().size.y

func _process(_delta: float) -> void:
	_check_bottom()

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameState.State.PLAYING:
		return
	if input_blocked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_click_flock(event.position)

func _try_click_flock(click_pos: Vector2) -> void:
	for i in range(flocks.size() - 1, -1, -1):
		var flock: Node2D = flocks[i]
		if flock._popping or flock.letters.size() < WordDictionary.MIN_WORD_LENGTH:
			continue
		if flock.get_bounding_rect().has_point(click_pos):
			var letter_chars: Array[String] = []
			for l in flock.letters:
				letter_chars.append(l.letter)
			var exact: Dictionary = WordDictionary.find_exact_word(letter_chars)
			flocks.remove_at(i)
			if not exact.is_empty():
				var word_len: int = exact["word"].length()
				var score := _calculate_score(word_len, exact["frequency"])
				GameManager.add_score(score)
				GameManager.on_word_formed(word_len)
				flock.pop_word(exact["word"])
			else:
				flock.pop()
			get_viewport().set_input_as_handled()
			return

func is_click_on_flock(click_pos: Vector2) -> bool:
	for flock in flocks:
		if not flock._popping and flock.letters.size() >= WordDictionary.MIN_WORD_LENGTH and flock.get_bounding_rect().has_point(click_pos):
			return true
	return false

func create_flock(letter_nodes: Array[Node2D], spawn_pos: Vector2) -> Node2D:
	var flock_scene := preload("res://src/letters/flock.gd")
	var flock := Node2D.new()
	flock.set_script(flock_scene)
	flock.position = spawn_pos
	add_child(flock)
	for letter_node in letter_nodes:
		flock.add_letter(letter_node)
	flocks.append(flock)
	return flock

func check_projectile_collision(proj_pos: Vector2, proj_letter: String) -> Node2D:
	for flock in flocks:
		if flock._popping:
			continue
		# Compute metaball field at projectile position - same formula as the shader
		var local_pos: Vector2 = proj_pos - flock.global_position
		var field := 0.0
		var r: float = flock.METABALL_RADIUS
		for letter in flock.letters:
			var diff: Vector2 = local_pos - letter.position
			var dist_sq := diff.length_squared()
			field += (r * r) / (dist_sq + r * 0.5)
		if field >= 1.0:
			return flock
	return null

func add_letter_to_flock(flock: Node2D, letter_char: String, from_pos: Vector2, proj_velocity: Vector2 = Vector2.ZERO) -> void:
	var FallingLetterScript := preload("res://src/letters/falling_letter.gd")
	var new_letter := Node2D.new()
	new_letter.set_script(FallingLetterScript)
	new_letter.letter = letter_char
	new_letter.velocity = Vector2.ZERO
	# Place letter at entry point (local to flock) and give it projectile velocity
	var entry_local: Vector2 = from_pos - flock.global_position
	new_letter.position = entry_local
	flock.add_letter(new_letter, proj_velocity)
	flock.apply_push(proj_velocity)
	flock.apply_dent(entry_local)
	flock.apply_impact(entry_local, proj_velocity)
	if not flock.is_intro_flock and flock.letters.size() >= WordDictionary.MIN_WORD_LENGTH and not flock.scorable:
		# Check if adding more letters could ever form a word
		var letter_chars: Array[String] = []
		for l in flock.letters:
			letter_chars.append(l.letter)
		if not WordDictionary.can_form_word_with_additions(letter_chars):
			var flock_idx := flocks.find(flock)
			if flock_idx >= 0:
				flocks.remove_at(flock_idx)
				flock.pop()

func _check_bottom() -> void:
	if GameManager.current_state != GameState.State.PLAYING:
		return
	for i in range(flocks.size() - 1, -1, -1):
		var flock: Node2D = flocks[i]
		if flock.get_bottom_y() >= screen_height:
			GameManager.penalize_bottom()
			_remove_flock(i)

func _remove_flock(index: int) -> void:
	var flock: Node2D = flocks[index]
	flocks.remove_at(index)
	flock.remove_all()
	flock.queue_free()

func clear_all() -> void:
	for flock in flocks:
		flock.remove_all()
		flock.queue_free()
	flocks.clear()

func _calculate_score(word_length: int, frequency: int) -> int:
	var freq := maxf(float(frequency), 1.0)
	var rarity_factor: float = log(MAX_FREQ / freq) / log(10.0)
	var raw_score: float = float(word_length) * (SCORE_BASE + SCORE_MULTIPLIER * rarity_factor)
	return maxi(roundi(raw_score), 1)
