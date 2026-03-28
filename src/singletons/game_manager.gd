extends Node

signal state_changed(new_state: GameState.State)
signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal level_changed(new_level: int)

const MAX_LIVES := 3
const LEVELS := [
	{ "letter_count": 5, "fall_speed": 10.0, "spawn_min": 1.2, "spawn_max": 2.5, "duration": 30.0 },
	{ "letter_count": 10, "fall_speed": 15.0, "spawn_min": 0.8, "spawn_max": 2.0, "duration": 30.0 },
	{ "letter_count": 16, "fall_speed": 20.0, "spawn_min": 0.6, "spawn_max": 1.5, "duration": 30.0 },
	{ "letter_count": -1, "fall_speed": 25.0, "spawn_min": 0.4, "spawn_max": 1.0, "duration": 30.0 },
]

var current_state: GameState.State = GameState.State.MAIN_MENU
var score: int = 0
var lives: int = 3
var current_level: int = 0
var level_timer: float = 0.0
var use_arrow_keys: bool = false
var language: String = "en"

var _translations: Dictionary = {
	"LETTER FALL": {"en": "LETTER FALL", "ru": "БУКВОПАД"},
	"PLAY": {"en": "PLAY", "ru": "ИГРАТЬ"},
	"SETTINGS": {"en": "SETTINGS", "ru": "НАСТРОЙКИ"},
	"BACK": {"en": "BACK", "ru": "НАЗАД"},
	"Controls: A/D": {"en": "Controls: A/D", "ru": "Управление: A/D"},
	"Controls: Arrows": {"en": "Controls: Arrows", "ru": "Управление: Стрелки"},
	"Language: English": {"en": "Language: English", "ru": "Язык: English"},
	"Language: Russian": {"en": "Language: Russian", "ru": "Язык: Русский"},
	"SCORE": {"en": "SCORE", "ru": "СЧЁТ"},
	"LEVEL": {"en": "LEVEL", "ru": "УРОВЕНЬ"},
	"GAME OVER": {"en": "GAME OVER", "ru": "КОНЕЦ ИГРЫ"},
	"Score:": {"en": "Score:", "ru": "Счёт:"},
	"RESTART": {"en": "RESTART", "ru": "ЗАНОВО"},
	"MENU": {"en": "MENU", "ru": "МЕНЮ"},
}

func tr_text(key: String) -> String:
	if _translations.has(key):
		return _translations[key].get(language, key)
	return key

func _process(delta: float) -> void:
	if current_state != GameState.State.PLAYING:
		return
	level_timer += delta
	var cfg: Dictionary = get_level_config()
	if level_timer >= cfg["duration"]:
		level_timer = 0.0
		if current_level < LEVELS.size() - 1:
			current_level += 1
			level_changed.emit(current_level)

func get_level_config() -> Dictionary:
	return LEVELS[current_level]

func get_allowed_letters() -> String:
	var cfg: Dictionary = get_level_config()
	var alphabet := WordDictionary.get_alphabet()
	var count: int = cfg["letter_count"]
	if count < 0 or count >= alphabet.length():
		return alphabet
	return alphabet.substr(0, count)

func change_state(new_state: GameState.State) -> void:
	current_state = new_state
	state_changed.emit(new_state)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

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
