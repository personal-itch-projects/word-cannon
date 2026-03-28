extends Node2D

const SCORE_BASE := 2
const SCORE_MULTIPLIER := 3
const MAX_FREQ := 1500000.0

var flocks: Array[Node2D] = []
var screen_height: float

func _ready() -> void:
	screen_height = get_viewport().get_visible_rect().size.y

func _process(_delta: float) -> void:
	_check_bottom()

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameState.State.PLAYING:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_click_flock(event.position)

func _try_click_flock(click_pos: Vector2) -> void:
	for i in range(flocks.size() - 1, -1, -1):
		var flock: Node2D = flocks[i]
		if flock.scorable and flock.get_bounding_rect().has_point(click_pos):
			var score := _calculate_score(flock.matched_word.length(), flock.matched_frequency)
			GameManager.add_score(score)
			_remove_flock(i)
			get_viewport().set_input_as_handled()
			return

func is_click_on_scorable(click_pos: Vector2) -> bool:
	for flock in flocks:
		if flock.scorable and flock.get_bounding_rect().has_point(click_pos):
			return true
	return false

func create_flock(letter_nodes: Array[Node2D], spawn_pos: Vector2) -> Node2D:
	var flock_scene := preload("res://src/letters/flock.gd")
	var flock := Node2D.new()
	flock.set_script(flock_scene)
	flock.position = spawn_pos
	for letter_node in letter_nodes:
		letter_node.position = Vector2.ZERO
		letter_node.velocity = Vector2.ZERO
		flock.add_child(letter_node)
		flock.letters.append(letter_node)
	if flock.letters.size() > 1:
		flock._arrange_letters()
	flock._update_scorable()
	add_child(flock)
	flocks.append(flock)
	return flock

func check_projectile_collision(proj_rect: Rect2, proj_letter: String) -> Node2D:
	for flock in flocks:
		if flock.get_bounding_rect().intersects(proj_rect):
			return flock
	return null

func add_letter_to_flock(flock: Node2D, letter_char: String, from_pos: Vector2) -> void:
	var FallingLetterScript := preload("res://src/letters/falling_letter.gd")
	var new_letter := Node2D.new()
	new_letter.set_script(FallingLetterScript)
	new_letter.letter = letter_char
	new_letter.velocity = Vector2.ZERO
	var index := _find_insertion_index(flock, from_pos)
	flock.insert_letter_at(new_letter, index)
	if not flock.scorable:
		var letter_chars: Array[String] = []
		for l in flock.letters:
			letter_chars.append(l.letter)
		if not WordDictionary.can_extend_to_word(letter_chars):
			var flock_idx := flocks.find(flock)
			if flock_idx >= 0:
				_remove_flock(flock_idx)

func _find_insertion_index(flock: Node2D, proj_global_pos: Vector2) -> int:
	var proj_x := proj_global_pos.x
	for i in flock.letters.size():
		var letter_global_x: float = flock.global_position.x + flock.letters[i].position.x
		if proj_x < letter_global_x:
			return i
	return flock.letters.size()

func _check_bottom() -> void:
	if GameManager.current_state != GameState.State.PLAYING:
		return
	for i in range(flocks.size() - 1, -1, -1):
		var flock: Node2D = flocks[i]
		if flock.get_bottom_y() >= screen_height:
			GameManager.lose_life()
			if GameManager.current_state != GameState.State.PLAYING:
				return
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
