extends Node

const BUS := "Master"

var sfx_bubble_pop: Array[AudioStream] = [
	preload("res://assets/sfx/bubble_pop_1.wav"),
	preload("res://assets/sfx/bubble_pop_2.wav"),
	preload("res://assets/sfx/bubble_pop_3.wav"),
	preload("res://assets/sfx/bubble_pop_4.wav"),
]
var sfx_bubble_pop_word: Array[AudioStream] = [
	preload("res://assets/sfx/word_pop_1.wav"),
	preload("res://assets/sfx/word_pop_2.wav"),
	preload("res://assets/sfx/word_pop_3.wav"),
	preload("res://assets/sfx/word_pop_4.wav"),
	preload("res://assets/sfx/word_pop_5.wav"),
]
var sfx_cannon_move: Array[AudioStream] = [
	preload("res://assets/sfx/cannon_move_1.wav"),
	preload("res://assets/sfx/cannon_move_2.wav"),
	preload("res://assets/sfx/cannon_move_3.wav"),
	preload("res://assets/sfx/cannon_move_4.wav"),
]
var sfx_bubble_fire: Array[AudioStream] = [
	preload("res://assets/sfx/bubble_fire_1.wav"),
	preload("res://assets/sfx/bubble_fire_2.wav"),
	preload("res://assets/sfx/bubble_fire_3.wav"),
	preload("res://assets/sfx/bubble_fire_4.wav"),
]
var sfx_menu_click: AudioStream = preload("res://assets/sfx/menu-button-clicked-1.wav")
var sfx_pause_opened: AudioStream = preload("res://assets/sfx/pause-menu-opened-1.wav")

const CANNON_MOVE_FADE_SPEED := 3.0  # linear volume units per second

var _cannon_move_player: AudioStreamPlayer
var _cannon_moving := false
var _cannon_move_vol := 0.0  # linear 0.0–1.0

func _ready() -> void:
	_cannon_move_player = AudioStreamPlayer.new()
	_cannon_move_player.bus = BUS
	_cannon_move_player.volume_db = -80.0
	add_child(_cannon_move_player)

func _process(delta: float) -> void:
	var target := 1.0 if _cannon_moving else 0.0
	_cannon_move_vol = move_toward(_cannon_move_vol, target, CANNON_MOVE_FADE_SPEED * delta)
	_cannon_move_player.volume_db = linear_to_db(maxf(_cannon_move_vol, 0.0001))

func play(stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_random(streams: Array[AudioStream]) -> void:
	play(streams[randi() % streams.size()])

func start_cannon_move() -> void:
	if not _cannon_moving:
		_cannon_move_player.stream = sfx_cannon_move[randi() % sfx_cannon_move.size()]
		_cannon_move_player.play(0.0)
	_cannon_moving = true

func stop_cannon_move() -> void:
	_cannon_moving = false
