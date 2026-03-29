extends Node

signal state_changed(new_state: GameState.State)
signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal level_changed(new_level: int)
signal goal_progress_changed
signal stage_completed(stage: int)

const MAX_LIVES := 3
const LEVELS := [
	# Stage 1 — Form N words (any)
	{ "goal_type": "words", "goal_target": 10, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 1.2, "spawn_max": 2.5, "missing_letters": 0 },
	{ "goal_type": "words", "goal_target": 20, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 1.1, "spawn_max": 2.4, "missing_letters": 0 },
	{ "goal_type": "words", "goal_target": 30, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 1.0, "spawn_max": 2.3, "missing_letters": 0 },
	{ "goal_type": "words", "goal_target": 50, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.95, "spawn_max": 2.2, "missing_letters": 0 },
	{ "goal_type": "words", "goal_target": 70, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.9, "spawn_max": 2.1, "missing_letters": 0 },
	# Stage 2 — Earn N points (per-level)
	{ "goal_type": "score", "goal_target": 150, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.85, "spawn_max": 2.0, "missing_letters": 0 },
	{ "goal_type": "score", "goal_target": 300, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.8, "spawn_max": 1.9, "missing_letters": 0 },
	{ "goal_type": "score", "goal_target": 500, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.75, "spawn_max": 1.8, "missing_letters": 0 },
	{ "goal_type": "score", "goal_target": 750, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.7, "spawn_max": 1.6, "missing_letters": 0 },
	{ "goal_type": "score", "goal_target": 1000, "goal_word_length": 0, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.65, "spawn_max": 1.5, "missing_letters": 0 },
	# Stage 3 — Form N words of length L
	{ "goal_type": "words_of_length", "goal_target": 3, "goal_word_length": 5, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.6, "spawn_max": 1.4, "missing_letters": 0 },
	{ "goal_type": "words_of_length", "goal_target": 5, "goal_word_length": 5, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.55, "spawn_max": 1.3, "missing_letters": 0 },
	{ "goal_type": "words_of_length", "goal_target": 3, "goal_word_length": 6, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.5, "spawn_max": 1.2, "missing_letters": 0 },
	{ "goal_type": "words_of_length", "goal_target": 5, "goal_word_length": 6, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.45, "spawn_max": 1.1, "missing_letters": 0 },
	{ "goal_type": "words_of_length", "goal_target": 3, "goal_word_length": 7, "letter_count": -1, "fall_speed": 20.0, "spawn_min": 0.4, "spawn_max": 1.0, "missing_letters": 0 },
]

var current_state: GameState.State = GameState.State.MAIN_MENU
var score: int = 0
var lives: int = 3
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
}

func tr_text(key: String) -> String:
	if _translations.has(key):
		return _translations[key].get(language, key)
	return key

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

func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		change_state(GameState.State.DEFEAT)

func reset_game() -> void:
	score = 0
	lives = MAX_LIVES
	current_level = 0
	level_timer = 0.0
	_reset_level_counters()
	score_changed.emit(score)
	lives_changed.emit(lives)
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
