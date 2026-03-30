extends Node

signal state_changed(new_state: GameState.State)
signal score_changed(new_score: int)
signal level_changed(new_level: int)
signal goal_progress_changed

const BOTTOM_PENALTY := 10
const PLAY_AREA_WIDTH := 800.0
const MIN_WINDOW_SIZE := Vector2i(960, 540)

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
var level_score: int = 0

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
}

func tr_text(key: String) -> String:
	if _translations.has(key):
		return _translations[key].get(language, key)
	return key

func _ready() -> void:
	get_window().min_size = MIN_WINDOW_SIZE

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
	var level := current_level
	return {
		"score_target": 50 + 30 * level,
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

func on_word_formed(_word_length: int) -> void:
	goal_progress_changed.emit()
	_check_level_goal()

func _check_level_goal() -> void:
	var cfg: Dictionary = get_level_config()
	if level_score >= cfg["score_target"]:
		_advance_level()

func _advance_level() -> void:
	current_level += 1
	level_score = 0
	level_changed.emit(current_level)

func penalize_bottom() -> void:
	score = maxi(score - BOTTOM_PENALTY, 0)
	score_changed.emit(score)

func reset_game() -> void:
	score = 0
	current_level = 0
	level_timer = 0.0
	level_score = 0
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
