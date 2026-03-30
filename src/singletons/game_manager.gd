extends Node

signal state_changed(new_state: GameState.State)
signal score_changed(new_score: int)
signal level_changed(new_level: int)
signal lives_changed(new_lives: int)

const INITIAL_LIVES := 3
const LEVEL_DURATION := 45.0
const PLAY_AREA_WIDTH := 800.0
const MIN_WINDOW_SIZE := Vector2i(960, 540)

var current_state: GameState.State = GameState.State.MAIN_MENU
var score: int = 0
var high_score: int = 0
var lives: int = INITIAL_LIVES
var current_level: int = 0
var level_timer: float = 0.0
var bindings: Dictionary = {
	"move_left": KEY_A,
	"move_right": KEY_D,
}
var language: String = "en"

var previous_state: GameState.State = GameState.State.MAIN_MENU
var is_resuming: bool = false
var _level_elapsed: float = 0.0

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
	"HIGH SCORE": {"en": "HIGH SCORE", "ru": "РЕКОРД"},
}

func tr_text(key: String) -> String:
	if _translations.has(key):
		return _translations[key].get(language, key)
	return key

func _ready() -> void:
	get_window().min_size = MIN_WINDOW_SIZE
	_load_high_score()

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
	_level_elapsed += delta
	if _level_elapsed >= LEVEL_DURATION:
		_level_elapsed -= LEVEL_DURATION
		_advance_level()

func get_level_config() -> Dictionary:
	var level := current_level
	return {
		"fall_speed": clampf(20.0 + level * 0.5, 20.0, 35.0),
		"spawn_min": clampf(1.5 - level * 0.05, 0.4, 1.5),
		"spawn_max": clampf(2.5 - level * 0.08, 0.8, 2.5),
		"word_difficulty": clampf(float(level) / 25.0, 0.0, 1.0),
		"min_gaps": clampi(1 + level / 8, 1, 4),
		"max_gaps": clampi(1 + level / 4, 1, 6),
		"min_word_length": clampi(3 + level / 10, 3, 5),
		"max_word_length": clampi(5 + level / 5, 5, 9),
	}

func get_allowed_letters() -> String:
	return WordDictionary.get_alphabet()

func change_state(new_state: GameState.State) -> void:
	previous_state = current_state
	current_state = new_state
	if new_state == GameState.State.DEFEAT:
		_update_high_score()
	if new_state == GameState.State.PAUSED:
		get_tree().paused = true
	elif new_state != GameState.State.SETTINGS:
		get_tree().paused = false
	state_changed.emit(new_state)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func on_word_formed(_word_length: int) -> void:
	add_life()

func add_life() -> void:
	lives += 1
	lives_changed.emit(lives)

func lose_life() -> void:
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)
	if lives <= 0:
		change_state(GameState.State.DEFEAT)

func _advance_level() -> void:
	current_level += 1
	level_changed.emit(current_level)

func penalize_bottom() -> void:
	lose_life()

func reset_game() -> void:
	score = 0
	lives = INITIAL_LIVES
	current_level = 0
	level_timer = 0.0
	_level_elapsed = 0.0
	score_changed.emit(score)
	lives_changed.emit(lives)
	level_changed.emit(current_level)

func start_game() -> void:
	reset_game()
	change_state(GameState.State.PLAYING)

func restart_game() -> void:
	_update_high_score()
	start_game()

func go_to_menu() -> void:
	_update_high_score()
	change_state(GameState.State.MAIN_MENU)

func open_settings() -> void:
	change_state(GameState.State.SETTINGS)

func pause_game() -> void:
	change_state(GameState.State.PAUSED)

func resume_game() -> void:
	is_resuming = true
	change_state(GameState.State.PLAYING)
	is_resuming = false

const SAVE_PATH := "user://high_score.dat"

func _update_high_score() -> void:
	if score > high_score:
		high_score = score
		_save_high_score()

func _save_high_score() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(high_score)

func _load_high_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			high_score = file.get_32()
