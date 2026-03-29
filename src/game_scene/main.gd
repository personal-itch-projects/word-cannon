extends Node2D

@onready var game_layer: Node2D = $GameLayer
@onready var background: ColorRect = $Background
var _border_left: Sprite2D
var _border_right: Sprite2D
@onready var menu_letter_spawner: Node2D = $GameLayer/MenuLetterSpawner
@onready var letter_spawner: Node2D = $GameLayer/LetterSpawner
@onready var flock_manager: Node2D = $GameLayer/FlockManager
@onready var platform: Node2D = $GameLayer/Platform
@onready var hud: Control = $UILayer/HUD
@onready var main_menu: Control = $UILayer/MainMenu
@onready var settings_menu: Control = $UILayer/SettingsMenu
@onready var defeat_screen: Control = $UILayer/DefeatScreen
@onready var pause_menu: Control = $UILayer/PauseMenu
@onready var stage_complete_screen: Control = $UILayer/StageCompleteScreen

var _intro_running: bool = false
var _intro_flocks: Array = []  # [{flock, word, missing_letters}]

func _ready() -> void:
	_resize_background()
	get_viewport().size_changed.connect(_resize_background)
	_setup_borders()
	GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.current_state)

func _setup_borders() -> void:
	var shader := preload("res://src/shaders/border_line.gdshader")
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)

	_border_left = Sprite2D.new()
	_border_left.texture = tex
	var mat_l := ShaderMaterial.new()
	mat_l.shader = shader
	_border_left.material = mat_l
	game_layer.add_child(_border_left)

	_border_right = Sprite2D.new()
	_border_right.texture = tex
	var mat_r := ShaderMaterial.new()
	mat_r.shader = shader
	_border_right.material = mat_r
	game_layer.add_child(_border_right)

	_update_borders()

func _update_borders() -> void:
	var bounds := GameManager.get_play_bounds()
	var screen_h: float = get_viewport().get_visible_rect().size.y
	var border_w := 16.0
	_border_left.scale = Vector2(border_w, screen_h)
	_border_left.position = Vector2(bounds.x, screen_h / 2.0)
	_border_right.scale = Vector2(border_w, screen_h)
	_border_right.position = Vector2(bounds.y, screen_h / 2.0)

func _resize_background() -> void:
	background.size = get_viewport().get_visible_rect().size
	if _border_left:
		_update_borders()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if GameManager.current_state == GameState.State.PLAYING:
			GameManager.pause_game()
			get_viewport().set_input_as_handled()

func _on_state_changed(new_state: GameState.State) -> void:
	# Hide everything first
	main_menu.visible = false
	settings_menu.visible = false
	defeat_screen.visible = false
	pause_menu.visible = false
	stage_complete_screen.visible = false
	hud.visible = false
	platform.visible = false
	letter_spawner.set_process(false)
	menu_letter_spawner.visible = false
	menu_letter_spawner.set_process(false)

	match new_state:
		GameState.State.MAIN_MENU:
			main_menu.visible = true
			menu_letter_spawner.visible = true
			menu_letter_spawner.set_process(true)
			_clear_gameplay()
		GameState.State.PLAYING:
			hud.visible = true
			platform.visible = true
			letter_spawner.set_process(true)
			if GameManager.is_resuming:
				menu_letter_spawner.clear_letters()
			else:
				_clear_gameplay()
				menu_letter_spawner.clear_letters()
				_run_theme_intro()
		GameState.State.SETTINGS:
			settings_menu.visible = true
		GameState.State.DEFEAT:
			defeat_screen.visible = true
			hud.visible = true
			_clear_gameplay()
		GameState.State.PAUSED:
			pause_menu.visible = true
			hud.visible = true
		GameState.State.STAGE_COMPLETE:
			stage_complete_screen.visible = true
			hud.visible = true
			letter_spawner.set_process(false)

func _clear_gameplay() -> void:
	_intro_running = false
	_intro_flocks.clear()
	platform.intro_mode = false
	flock_manager.input_blocked = false
	flock_manager.clear_all()
	letter_spawner.stop_spawning()
	platform.reset()

# ── Theme Intro ──────────────────────────────────────────────────────────────

func _run_theme_intro() -> void:
	var screen_size := get_viewport().get_visible_rect().size
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
		_finish_intro()
		return

	_intro_running = true
	platform.intro_mode = true
	flock_manager.input_blocked = true

	# Position rows
	var row1_y := screen_size.y * 0.38
	var row2_y := screen_size.y * 0.45
	var row1_positions := _calc_row_positions(row1_words, row1_y, bounds)
	var row2_positions := _calc_row_positions(row2_words, row2_y, bounds)

	# Create intro flocks
	_intro_flocks.clear()
	for i in row1_words.size():
		_intro_flocks.append(_create_intro_flock(row1_words[i], row1_positions[i]))
	for i in row2_words.size():
		_intro_flocks.append(_create_intro_flock(row2_words[i], row2_positions[i]))

	# Build shot queue: row 2 first (bottom, left-to-right), then row 1 (top)
	var shot_queue: Array = []
	var row2_start := row1_words.size()
	for i in range(row2_start, _intro_flocks.size()):
		for letter in _intro_flocks[i].missing_letters:
			shot_queue.append({flock = _intro_flocks[i].flock, letter = letter})
	for i in range(0, row2_start):
		for letter in _intro_flocks[i].missing_letters:
			shot_queue.append({flock = _intro_flocks[i].flock, letter = letter})

	# Set cannon arsenal
	var arsenal_letters: Array[String] = []
	for shot in shot_queue:
		arsenal_letters.append(shot.letter)
	platform.set_arsenal(arsenal_letters)

	# Brief pause before firing
	await get_tree().create_timer(0.5).timeout
	if not _intro_running:
		return

	# Auto-fire sequence
	for shot in shot_queue:
		if not _intro_running:
			return
		var launch_pos: Vector2 = platform.get_muzzle_position()
		var target_pos: Vector2 = shot.flock.global_position
		var vel := _calc_bounce_velocity(launch_pos, target_pos, bounds)
		platform.auto_shoot(vel, shot.flock)
		await get_tree().create_timer(0.2).timeout
		if not _intro_running:
			return

	# Wait for last projectiles to reach targets
	await get_tree().create_timer(1.5).timeout
	if not _intro_running:
		return

	# Pop all intro flocks simultaneously
	for data in _intro_flocks:
		if is_instance_valid(data.flock):
			var idx: int = flock_manager.flocks.find(data.flock)
			if idx >= 0:
				flock_manager.flocks.remove_at(idx)
			data.flock.pop_word(data.word, 1.0, 2.0)

	# Wait for pop animation (0.3s arrange + hold + fade)
	await get_tree().create_timer(3.5).timeout
	if not _intro_running:
		return

	_finish_intro()

func _finish_intro() -> void:
	_intro_running = false
	_intro_flocks.clear()
	platform.intro_mode = false
	flock_manager.input_blocked = false
	hud.theme_intro_done = true
	platform.reset()
	letter_spawner.start_spawning()

func _create_intro_flock(word: String, pos: Vector2) -> Dictionary:
	var letters_to_remove := mini(2, word.length() - 1)

	# Pick random positions to remove
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

	# Create letter nodes
	var FallingLetterScript := preload("res://src/letters/falling_letter.gd")
	var letter_nodes: Array[Node2D] = []
	for letter_char in kept_letters:
		var letter_node := Node2D.new()
		letter_node.set_script(FallingLetterScript)
		letter_node.setup(letter_char, Vector2.ZERO)
		letter_nodes.append(letter_node)

	# Create stationary intro flock
	var flock: Node2D = flock_manager.create_flock(letter_nodes, pos)
	flock.velocity = Vector2.ZERO
	flock.is_intro_flock = true

	return {flock = flock, word = word, missing_letters = missing_letters}

func _calc_row_positions(words: Array[String], y_pos: float, bounds: Vector2) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var center_x := (bounds.x + bounds.y) / 2.0

	if words.size() == 1:
		positions.append(Vector2(center_x, y_pos))
		return positions

	# Calculate bubble width per word (with 2 missing letters)
	var word_widths: Array[float] = []
	var total_span := 0.0
	for word in words:
		var kept := word.length() - mini(2, word.length() - 1)
		var r := 20.0 + 8.0 * maxf(kept - 1, 0)
		var w := r * 2.0
		word_widths.append(w)
		total_span += w

	var gap := 40.0
	total_span += (words.size() - 1) * gap

	var x := center_x - total_span / 2.0
	for i in words.size():
		x += word_widths[i] / 2.0
		positions.append(Vector2(x, y_pos))
		x += word_widths[i] / 2.0 + gap

	return positions

func _calc_bounce_velocity(launch_pos: Vector2, target_pos: Vector2, bounds: Vector2) -> Vector2:
	const PROJ_SPEED := 800.0

	# If target is roughly above cannon, aim directly
	if abs(target_pos.x - launch_pos.x) < 40.0:
		var dir := (target_pos - launch_pos).normalized()
		return dir * PROJ_SPEED

	# Try both wall bounces, pick the one with angle closest to 45°
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
