extends Node2D

var spawn_timer: float = 0.0
var next_interval: float = 1.0
var spawning: bool = false
var screen_width: float

@onready var flock_manager: Node2D = get_parent().get_node("FlockManager")

func _ready() -> void:
	screen_width = get_viewport().get_visible_rect().size.x
	_randomize_interval()

func start_spawning() -> void:
	spawning = true
	spawn_timer = 0.0
	_randomize_interval()

func stop_spawning() -> void:
	spawning = false

func _process(delta: float) -> void:
	if not spawning:
		return
	spawn_timer += delta
	if spawn_timer >= next_interval:
		spawn_timer = 0.0
		_spawn_letter()
		_randomize_interval()

func _spawn_letter() -> void:
	var cfg: Dictionary = GameManager.get_level_config()
	var roll := randi() % 100
	var t1: int = cfg.get("theme_1_pct", 0)
	var t2: int = cfg.get("theme_2_pct", 0)
	var t3: int = cfg.get("theme_3_pct", 0)

	if roll < t1:
		if _spawn_word_flock(1):
			return
	elif roll < t1 + t2:
		if _spawn_word_flock(2):
			return
	elif roll < t1 + t2 + t3:
		if _spawn_word_flock(3):
			return
	# Fallback: random single letter
	_spawn_single_letter()

func _spawn_word_flock(gaps: int) -> bool:
	if GameManager.themed_levels_enabled:
		return _spawn_theme_word(gaps)
	return _spawn_random_word(gaps)

func _spawn_theme_word(gaps: int) -> bool:
	var min_len := gaps + WordDictionary.MIN_WORD_LENGTH
	var word := GameManager.pick_theme_word(min_len)
	if word.is_empty():
		return false
	var kept_letters := WordDictionary.pick_theme_partial_word(word, gaps)
	if kept_letters.is_empty():
		return false
	return _create_word_flock(kept_letters, word)

func _spawn_random_word(gaps: int) -> bool:
	var kept_letters := WordDictionary.pick_partial_word(gaps)
	if kept_letters.is_empty():
		return false
	return _create_word_flock(kept_letters)

func _create_word_flock(kept_letters: Array[String], target_word: String = "") -> bool:
	var x_pos := _find_free_x_position(kept_letters.size())
	if x_pos < 0:
		return false
	var FallingLetterScript := preload("res://src/letters/falling_letter.gd")
	var letter_nodes: Array[Node2D] = []
	for letter_char in kept_letters:
		var letter_node := Node2D.new()
		letter_node.set_script(FallingLetterScript)
		letter_node.setup(letter_char, Vector2.ZERO)
		letter_nodes.append(letter_node)
	var flock: Node2D = flock_manager.create_flock(letter_nodes, Vector2(x_pos, -30))
	if OS.is_debug_build() and not target_word.is_empty():
		var upper_word := target_word.to_upper()
		var missing: Array[String] = []
		var kept_upper: Array[String] = []
		for k in kept_letters:
			kept_upper.append(k.to_upper())
		for c_idx in upper_word.length():
			var ch: String = upper_word[c_idx]
			var found := kept_upper.find(ch)
			if found >= 0:
				kept_upper.remove_at(found)
			else:
				missing.append(ch)
		flock.set_debug_info(upper_word, missing)
	return true

func _spawn_single_letter() -> void:
	var x_pos := _find_free_x_position()
	if x_pos < 0:
		return
	var FallingLetterScript := preload("res://src/letters/falling_letter.gd")
	var letter_node := Node2D.new()
	letter_node.set_script(FallingLetterScript)
	var allowed: String = GameManager.get_allowed_letters()
	var rand_letter := WordDictionary.pick_weighted_letter(allowed)
	letter_node.setup(rand_letter, Vector2.ZERO)
	flock_manager.create_flock([letter_node] as Array[Node2D], Vector2(x_pos, -30))

func _find_free_x_position(letter_count: int = 1) -> float:
	const MAX_ATTEMPTS := 10
	const BUBBLE_DIAMETER := 104.0  # (FLOAT_RADIUS + 22) * 2
	var word_extent := BUBBLE_DIAMETER
	var bounds := GameManager.get_play_bounds()
	var left_bound := bounds.x + 40.0
	var right_bound := bounds.y - 40.0 - word_extent
	if right_bound < left_bound:
		return -1.0
	for _attempt in MAX_ATTEMPTS:
		var x := randf_range(left_bound, right_bound)
		if _is_x_range_clear(x, word_extent):
			return x
	return -1.0

func _is_x_range_clear(x: float, extent: float) -> bool:
	const MIN_SPACING := 60.0
	for flock in flock_manager.flocks:
		var rect: Rect2 = flock.get_bounding_rect()
		if x + extent > rect.position.x - MIN_SPACING and x < rect.end.x + MIN_SPACING:
			return false
	return true

func _randomize_interval() -> void:
	var cfg: Dictionary = GameManager.get_level_config()
	var min_no_overlap: float = 44.0 / cfg["fall_speed"]
	next_interval = maxf(randf_range(cfg["spawn_min"], cfg["spawn_max"]), min_no_overlap)
