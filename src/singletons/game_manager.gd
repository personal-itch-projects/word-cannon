extends Node

signal state_changed(new_state: GameState.State)
signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal level_changed(new_level: int)

const MAX_LIVES := 3
const LEVELS := [
	{ "allowed_letters": "ABCDE", "fall_speed": 60.0, "spawn_min": 1.2, "spawn_max": 2.5, "duration": 30.0 },
	{ "allowed_letters": "ABCDEFGHIJ", "fall_speed": 80.0, "spawn_min": 0.8, "spawn_max": 2.0, "duration": 30.0 },
	{ "allowed_letters": "ABCDEFGHIJKLMNOP", "fall_speed": 100.0, "spawn_min": 0.6, "spawn_max": 1.5, "duration": 30.0 },
	{ "allowed_letters": "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "fall_speed": 120.0, "spawn_min": 0.4, "spawn_max": 1.0, "duration": 30.0 },
]

var current_state: GameState.State = GameState.State.MAIN_MENU
var score: int = 0
var lives: int = 3
var current_level: int = 0
var level_timer: float = 0.0
var use_arrow_keys: bool = false

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
