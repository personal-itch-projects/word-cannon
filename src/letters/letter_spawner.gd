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
		_spawn_word()
		_randomize_interval()

func _spawn_word() -> void:
	var cfg: Dictionary = GameManager.get_level_config()
	var difficulty: float = cfg["word_difficulty"]
	var min_len: int = cfg["min_word_length"]
	var max_len: int = cfg["max_word_length"]
	var min_gaps: int = cfg["min_gaps"]
	var max_gaps: int = cfg["max_gaps"]

	var gap_count := randi_range(min_gaps, max_gaps)
	var word_data: Dictionary = WordDictionary.pick_word_by_difficulty(difficulty, min_len, max_len)
	if word_data.is_empty():
		return

	var word: String = word_data["word"]
	# Clamp gaps so we don't remove more letters than possible
	gap_count = mini(gap_count, word.length() - WordDictionary.MIN_WORD_LENGTH)
	if gap_count < 1:
		gap_count = 1

	var partial: Dictionary = WordDictionary.create_partial_word(word, gap_count)
	if partial.is_empty():
		return

	var kept_letters: Array[String] = partial["kept_letters"] as Array[String]
	var slot_indices_arr: Array[int] = partial["slot_indices"] as Array[int]

	var x_pos := _find_free_x_position(word.length())
	if x_pos < 0:
		return

	var FallingLetterScript := preload("res://src/letters/falling_letter.gd")
	var letter_nodes: Array[Node2D] = []
	for i in kept_letters.size():
		var letter_node := Node2D.new()
		letter_node.set_script(FallingLetterScript)
		letter_node.setup(kept_letters[i], Vector2.ZERO)
		letter_node.slot_index = slot_indices_arr[i]
		letter_nodes.append(letter_node)

	var flock: Node2D = flock_manager.create_flock(letter_nodes, Vector2(x_pos, -30), word, slot_indices_arr)

	if OS.is_debug_build():
		var upper_word := word.to_upper()
		var missing: Array[String] = []
		var filled: Dictionary = {}
		for si in slot_indices_arr:
			filled[si] = true
		for ci in upper_word.length():
			if not filled.has(ci):
				missing.append(upper_word[ci])
		flock.set_debug_info(upper_word, missing)

func _find_free_x_position(word_length: int = 1) -> float:
	const MAX_ATTEMPTS := 10
	var word_extent := (word_length - 1) * 22.0 + 40.0 + 40.0  # HOME_SPACING + padding
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
