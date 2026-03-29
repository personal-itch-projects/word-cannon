extends Node

signal state_changed(new_state: GameState.State)
signal score_changed(new_score: int)
signal level_changed(new_level: int)
signal goal_progress_changed
signal stage_completed(stage: int)
signal theme_changed(theme_name: String)

const BOTTOM_PENALTY := 10
const PLAY_AREA_WIDTH := 800.0
const MIN_WINDOW_SIZE := Vector2i(960, 540)
const LEVELS := [
	# Stage 1 — Form N words  (theme_1/2/3_pct = chance of theme flock with 1/2/3 missing letters)
	{ "goal_type": "words", "goal_target": 10, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 1.2, "spawn_max": 2.5, "theme_1_pct": 60, "theme_2_pct": 10, "theme_3_pct": 0 },
	{ "goal_type": "words", "goal_target": 20, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 1.1, "spawn_max": 2.4, "theme_1_pct": 55, "theme_2_pct": 15, "theme_3_pct": 0 },
	{ "goal_type": "words", "goal_target": 30, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 1.0, "spawn_max": 2.3, "theme_1_pct": 45, "theme_2_pct": 20, "theme_3_pct": 5 },
	{ "goal_type": "words", "goal_target": 50, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.95, "spawn_max": 2.2, "theme_1_pct": 40, "theme_2_pct": 25, "theme_3_pct": 5 },
	{ "goal_type": "words", "goal_target": 70, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.9, "spawn_max": 2.1, "theme_1_pct": 35, "theme_2_pct": 25, "theme_3_pct": 10 },
	# Stage 2 — Earn N points
	{ "goal_type": "score", "goal_target": 150, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.85, "spawn_max": 2.0, "theme_1_pct": 30, "theme_2_pct": 30, "theme_3_pct": 10 },
	{ "goal_type": "score", "goal_target": 300, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.8, "spawn_max": 1.9, "theme_1_pct": 25, "theme_2_pct": 30, "theme_3_pct": 15 },
	{ "goal_type": "score", "goal_target": 500, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.75, "spawn_max": 1.8, "theme_1_pct": 20, "theme_2_pct": 30, "theme_3_pct": 20 },
	{ "goal_type": "score", "goal_target": 750, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.7, "spawn_max": 1.6, "theme_1_pct": 15, "theme_2_pct": 30, "theme_3_pct": 25 },
	{ "goal_type": "score", "goal_target": 1000, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.65, "spawn_max": 1.5, "theme_1_pct": 10, "theme_2_pct": 30, "theme_3_pct": 30 },
	# Stage 3 — Form N words of length L
	{ "goal_type": "words_of_length", "goal_target": 3, "goal_word_length": 5, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.6, "spawn_max": 1.4, "theme_1_pct": 10, "theme_2_pct": 25, "theme_3_pct": 35 },
	{ "goal_type": "words_of_length", "goal_target": 5, "goal_word_length": 5, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.55, "spawn_max": 1.3, "theme_1_pct": 5, "theme_2_pct": 25, "theme_3_pct": 40 },
	{ "goal_type": "words_of_length", "goal_target": 3, "goal_word_length": 6, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.5, "spawn_max": 1.2, "theme_1_pct": 5, "theme_2_pct": 20, "theme_3_pct": 45 },
	{ "goal_type": "words_of_length", "goal_target": 5, "goal_word_length": 6, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.45, "spawn_max": 1.1, "theme_1_pct": 0, "theme_2_pct": 20, "theme_3_pct": 50 },
	{ "goal_type": "words_of_length", "goal_target": 3, "goal_word_length": 7, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.4, "spawn_max": 1.0, "theme_1_pct": 0, "theme_2_pct": 15, "theme_3_pct": 55 },
]

var current_state: GameState.State = GameState.State.MAIN_MENU
var score: int = 0
var current_level: int = 0
var level_timer: float = 0.0
var bindings: Dictionary = {
	"move_left": KEY_A,
	"move_right": KEY_D,
}
var language: String = "en"

var previous_state: GameState.State = GameState.State.MAIN_MENU
var is_resuming: bool = false

# Per-level goal tracking
var level_words: int = 0
var level_score: int = 0
var level_words_of_length: int = 0

# Theme system
var current_theme_name: String = ""
var _theme_words: Array = []          # words available in current theme
var _used_theme_words: Dictionary = {} # word -> true (used this session)
var _all_themes: Array = []           # loaded from JSON

var _translations: Dictionary = {
	"WORD CANNON": {"en": "WORD CANNON", "ru": "ТАРАТОР"},
	"PLAY": {"en": "PLAY", "ru": "ИГРАТЬ"},
	"SETTINGS": {"en": "SETTINGS", "ru": "НАСТРОЙКИ"},
	"BACK": {"en": "BACK", "ru": "НАЗАД"},
	"Move Left:": {"en": "Move Left:", "ru": "Влево:"},
	"Move Right:": {"en": "Move Right:", "ru": "Вправо:"},
	"Press key...": {"en": "Press key...", "ru": "Нажмите..."},
	"Language: English": {"en": "Language: English", "ru": "Язык: English"},
	"Language: Russian": {"en": "Language: Russian", "ru": "Язык: Русский"},
	"SCORE": {"en": "SCORE", "ru": "СЧЁТ"},
	"LEVEL": {"en": "LEVEL", "ru": "УРОВЕНЬ"},
	"GAME OVER": {"en": "GAME OVER", "ru": "КОНЕЦ ИГРЫ"},
	"Score:": {"en": "Score:", "ru": "Счёт:"},
	"RESTART": {"en": "RESTART", "ru": "ЗАНОВО"},
	"MENU": {"en": "MENU", "ru": "МЕНЮ"},
	"PAUSED": {"en": "PAUSED", "ru": "ПАУЗА"},
	"CONTINUE": {"en": "CONTINUE", "ru": "ПРОДОЛЖИТЬ"},
	"STAGE COMPLETE!": {"en": "STAGE COMPLETE!", "ru": "ЭТАП ПРОЙДЕН!"},
	"YOU WIN!": {"en": "YOU WIN!", "ru": "ПОБЕДА!"},
	"Words:": {"en": "Words:", "ru": "Слова:"},
	"-letter words:": {"en": "-letter words:", "ru": "-букв. слова:"},
	"Theme:": {"en": "Theme:", "ru": "Тема:"},
	"CURRENT": {"en": "CURRENT", "ru": "ТЕКУЩАЯ"},
	"THEME": {"en": "THEME", "ru": "ТЕМА"},
}

func tr_text(key: String) -> String:
	if _translations.has(key):
		return _translations[key].get(language, key)
	return key

func _ready() -> void:
	get_window().min_size = MIN_WINDOW_SIZE

func load_themes() -> void:
	var path := "res://assets/data/themes.%s.json" % language
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open themes: " + path)
		_all_themes = []
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("Failed to parse themes JSON: " + json.get_error_message())
		_all_themes = []
		return
	var data: Dictionary = json.data
	_all_themes = data.get("themes", [])

func _pick_random_theme() -> void:
	if _all_themes.is_empty():
		load_themes()
	if _all_themes.is_empty():
		current_theme_name = ""
		_theme_words = []
		return
	var theme: Dictionary = _all_themes[randi() % _all_themes.size()]
	current_theme_name = theme["name"]
	_theme_words = theme["words"].duplicate()
	_used_theme_words.clear()
	theme_changed.emit(current_theme_name)

func pick_theme_word(min_length: int) -> String:
	## Pick an unused theme word with length >= min_length. Returns "" if exhausted.
	var candidates: Array = []
	for word in _theme_words:
		if word.length() >= min_length and not _used_theme_words.has(word):
			# Verify word exists in dictionary
			if WordDictionary.word_table.has(word):
				candidates.append(word)
	if candidates.is_empty():
		return ""
	var chosen: String = candidates[randi() % candidates.size()]
	_used_theme_words[chosen] = true
	return chosen

func get_play_bounds() -> Vector2:
	var screen_w: float = get_viewport().get_visible_rect().size.x
	if screen_w <= PLAY_AREA_WIDTH:
		return Vector2(0.0, screen_w)
	var margin := (screen_w - PLAY_AREA_WIDTH) / 2.0
	return Vector2(margin, screen_w - margin)

func _process(delta: float) -> void:
	if current_state != GameState.State.PLAYING:
		return
	level_timer += delta

func get_level_config() -> Dictionary:
	return LEVELS[current_level]

func get_allowed_letters() -> String:
	var cfg: Dictionary = get_level_config()
	var alphabet := WordDictionary.get_alphabet()
	var count: int = cfg["letter_count"]
	if count < 0 or count >= alphabet.length():
		return alphabet
	return alphabet.substr(0, count)

func get_current_stage() -> int:
	return current_level / 5 + 1

func change_state(new_state: GameState.State) -> void:
	previous_state = current_state
	current_state = new_state
	if new_state == GameState.State.PAUSED:
		get_tree().paused = true
	elif new_state != GameState.State.SETTINGS:
		get_tree().paused = false
	state_changed.emit(new_state)

func add_score(amount: int) -> void:
	score += amount
	level_score += amount
	score_changed.emit(score)
	goal_progress_changed.emit()
	_check_level_goal()

func on_word_formed(word_length: int) -> void:
	level_words += 1
	var cfg: Dictionary = get_level_config()
	if cfg["goal_type"] == "words_of_length" and word_length == cfg["goal_word_length"]:
		level_words_of_length += 1
	goal_progress_changed.emit()
	_check_level_goal()

func _check_level_goal() -> void:
	var cfg: Dictionary = get_level_config()
	var met := false
	match cfg["goal_type"]:
		"words":
			met = level_words >= cfg["goal_target"]
		"score":
			met = level_score >= cfg["goal_target"]
		"words_of_length":
			met = level_words_of_length >= cfg["goal_target"]
	if met:
		_advance_level()

func _advance_level() -> void:
	var was_stage := get_current_stage()
	if current_level >= LEVELS.size() - 1:
		# Final level complete — show win
		change_state(GameState.State.STAGE_COMPLETE)
		stage_completed.emit(was_stage)
		return
	current_level += 1
	_reset_level_counters()
	level_changed.emit(current_level)
	if current_level % 5 == 0:
		change_state(GameState.State.STAGE_COMPLETE)
		stage_completed.emit(was_stage)

func _reset_level_counters() -> void:
	level_words = 0
	level_score = 0
	level_words_of_length = 0

func continue_after_stage() -> void:
	is_resuming = true
	change_state(GameState.State.PLAYING)
	is_resuming = false

func penalize_bottom() -> void:
	score = maxi(score - BOTTOM_PENALTY, 0)
	score_changed.emit(score)

func reset_game() -> void:
	score = 0
	current_level = 0
	level_timer = 0.0
	_reset_level_counters()
	_pick_random_theme()
	score_changed.emit(score)
	level_changed.emit(current_level)

func start_game() -> void:
	reset_game()
	change_state(GameState.State.PLAYING)

func restart_game() -> void:
	start_game()

func go_to_menu() -> void:
	change_state(GameState.State.MAIN_MENU)

func open_settings() -> void:
	change_state(GameState.State.SETTINGS)

func pause_game() -> void:
	change_state(GameState.State.PAUSED)

func resume_game() -> void:
	is_resuming = true
	change_state(GameState.State.PLAYING)
	is_resuming = false
