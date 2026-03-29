extends RefCounted

## Animated theme reveal sequence. Disabled by default.
## Set `GameManager.theme_intro_enabled = true` to activate.

const FIRE_INTERVAL := 0.2
const PRE_FIRE_DELAY := 0.5
const POST_FIRE_WAIT := 1.5
const POP_HOLD := 1.0
const POP_FADE := 2.0
const POST_POP_WAIT := 3.5
const ROW1_Y_PCT := 0.38
const ROW2_Y_PCT := 0.45
const ROW_GAP := 40.0

var _running: bool = false
var _flocks: Array = []  # [{flock, word, missing_letters}]
var _tree: SceneTree
var _flock_manager: Node2D
var _platform: Node2D
var _hud: Control
var _letter_spawner: Node2D
var _game_layer: Node2D

func setup(tree: SceneTree, game_layer: Node2D, flock_manager: Node2D, platform: Node2D, hud: Control, letter_spawner: Node2D) -> void:
	_tree = tree
	_game_layer = game_layer
	_flock_manager = flock_manager
	_platform = platform
	_hud = hud
	_letter_spawner = letter_spawner

func cancel() -> void:
	_running = false
	_flocks.clear()
	_platform.intro_mode = false
	_flock_manager.input_blocked = false

func run() -> void:
	if not GameManager.theme_intro_enabled:
		_start_gameplay()
		return

	var screen_size: Vector2 = _platform.get_viewport().get_visible_rect().size
	var bounds := GameManager.get_play_bounds()

	# Build word lists
	var row1_words: Array[String] = [
		GameManager.tr_text("CURRENT").to_upper(),
		GameManager.tr_text("THEME").to_upper(),
	]
	var theme_name: String = GameManager.current_theme_name
	var row2_words: Array[String] = []
	for part in theme_name.split(" "):
		var p := part.strip_edges()
		if p != "&" and p != "и" and not p.is_empty():
			row2_words.append(p.to_upper())

	if row2_words.is_empty():
		_start_gameplay()
		return

	_running = true
	_platform.intro_mode = true
	_flock_manager.input_blocked = true

	# Position rows
	var row1_y := screen_size.y * ROW1_Y_PCT
	var row2_y := screen_size.y * ROW2_Y_PCT
	var row1_positions := _calc_row_positions(row1_words, row1_y, bounds)
	var row2_positions := _calc_row_positions(row2_words, row2_y, bounds)

	# Create intro flocks
	_flocks.clear()
	for i in row1_words.size():
		_flocks.append(_create_flock(row1_words[i], row1_positions[i]))
	for i in row2_words.size():
		_flocks.append(_create_flock(row2_words[i], row2_positions[i]))

	# Build shot queue: row 2 first (bottom, left-to-right), then row 1 (top)
	var shot_queue: Array = []
	var row2_start := row1_words.size()
	for i in range(row2_start, _flocks.size()):
		for letter in _flocks[i].missing_letters:
			shot_queue.append({flock = _flocks[i].flock, letter = letter})
	for i in range(0, row2_start):
		for letter in _flocks[i].missing_letters:
			shot_queue.append({flock = _flocks[i].flock, letter = letter})

	# Set cannon arsenal
	var arsenal_letters: Array[String] = []
	for shot in shot_queue:
		arsenal_letters.append(shot.letter)
	_platform.set_arsenal(arsenal_letters)

	# Brief pause before firing
	await _tree.create_timer(PRE_FIRE_DELAY).timeout
	if not _running:
		return

	# Auto-fire sequence
	for shot in shot_queue:
		if not _running:
			return
		var launch_pos: Vector2 = _platform.get_muzzle_position()
		var target_pos: Vector2 = shot.flock.global_position
		var vel := _calc_bounce_velocity(launch_pos, target_pos, bounds)
		_platform.auto_shoot(vel, shot.flock)
		await _tree.create_timer(FIRE_INTERVAL).timeout
		if not _running:
			return

	# Wait for last projectiles to reach targets
	await _tree.create_timer(POST_FIRE_WAIT).timeout
	if not _running:
		return

	# Pop all intro flocks simultaneously
	for data in _flocks:
		if is_instance_valid(data.flock):
			var idx: int = _flock_manager.flocks.find(data.flock)
			if idx >= 0:
				_flock_manager.flocks.remove_at(idx)
			data.flock.pop_word(data.word, POP_HOLD, POP_FADE)

	# Wait for pop animation
	await _tree.create_timer(POST_POP_WAIT).timeout
	if not _running:
		return

	_start_gameplay()

func _start_gameplay() -> void:
	_running = false
	_flocks.clear()
	_platform.intro_mode = false
	_flock_manager.input_blocked = false
	_hud.theme_intro_done = true
	_platform.reset()
	_letter_spawner.start_spawning()

func _create_flock(word: String, pos: Vector2) -> Dictionary:
	var letters_to_remove := mini(2, word.length() - 1)

	var all_positions: Array = []
	for i in word.length():
		all_positions.append(i)
	all_positions.shuffle()
	var remove_set: Array = []
	for i in letters_to_remove:
		remove_set.append(all_positions[i])

	var missing_letters: Array[String] = []
	var kept_letters: Array[String] = []
	for i in word.length():
		if remove_set.has(i):
			missing_letters.append(word[i])
		else:
			kept_letters.append(word[i])

	var FallingLetterScript := preload("res://src/letters/falling_letter.gd")
	var letter_nodes: Array[Node2D] = []
	for letter_char in kept_letters:
		var letter_node := Node2D.new()
		letter_node.set_script(FallingLetterScript)
		letter_node.setup(letter_char, Vector2.ZERO)
		letter_nodes.append(letter_node)

	var flock: Node2D = _flock_manager.create_flock(letter_nodes, pos)
	flock.velocity = Vector2.ZERO
	flock.is_intro_flock = true
	flock.set_debug_info(word, missing_letters)

	return {flock = flock, word = word, missing_letters = missing_letters}

func _calc_row_positions(words: Array[String], y_pos: float, bounds: Vector2) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var center_x := (bounds.x + bounds.y) / 2.0

	if words.size() == 1:
		positions.append(Vector2(center_x, y_pos))
		return positions

	var word_widths: Array[float] = []
	var total_span := 0.0
	for word in words:
		var kept := word.length() - mini(2, word.length() - 1)
		var r := 20.0 + 8.0 * maxf(kept - 1, 0)
		var w := r * 2.0
		word_widths.append(w)
		total_span += w

	total_span += (words.size() - 1) * ROW_GAP

	var x := center_x - total_span / 2.0
	for i in words.size():
		x += word_widths[i] / 2.0
		positions.append(Vector2(x, y_pos))
		x += word_widths[i] / 2.0 + ROW_GAP

	return positions

func _calc_bounce_velocity(launch_pos: Vector2, target_pos: Vector2, bounds: Vector2) -> Vector2:
	const PROJ_SPEED := 800.0

	if abs(target_pos.x - launch_pos.x) < 40.0:
		var dir := (target_pos - launch_pos).normalized()
		return dir * PROJ_SPEED

	var left_mirror := Vector2(2.0 * bounds.x - target_pos.x, target_pos.y)
	var right_mirror := Vector2(2.0 * bounds.y - target_pos.x, target_pos.y)

	var dir_left := (left_mirror - launch_pos).normalized()
	var dir_right := (right_mirror - launch_pos).normalized()

	var angle_left: float = abs(atan2(dir_left.x, -dir_left.y))
	var angle_right: float = abs(atan2(dir_right.x, -dir_right.y))
	var ideal := PI / 4.0

	if abs(angle_left - ideal) < abs(angle_right - ideal):
		return dir_left * PROJ_SPEED
	else:
		return dir_right * PROJ_SPEED
