extends Node

const BUS := "Master"

var sfx_bubble_pop: AudioStream = preload("res://assets/sfx/bubble-pop-1.wav")
var sfx_bubble_pop_word: AudioStream = preload("res://assets/sfx/bubble-pop-with-existing-word-1.wav")
var sfx_cannon_move: AudioStream = preload("res://assets/sfx/cannon-move-1.wav")
var sfx_arsenal_activated: AudioStream = preload("res://assets/sfx/magic-arsenal-bubble-activated-1.wav")
var sfx_menu_click: AudioStream = preload("res://assets/sfx/menu-button-clicked-1.wav")
var sfx_pause_opened: AudioStream = preload("res://assets/sfx/pause-menu-opened-1.wav")

var _cannon_move_player: AudioStreamPlayer

func _ready() -> void:
	# Cannon move is a looping sound that plays while moving
	_cannon_move_player = AudioStreamPlayer.new()
	_cannon_move_player.stream = sfx_cannon_move
	_cannon_move_player.bus = BUS
	add_child(_cannon_move_player)

func play(stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func start_cannon_move() -> void:
	if not _cannon_move_player.playing:
		_cannon_move_player.play()

func stop_cannon_move() -> void:
	if _cannon_move_player.playing:
		_cannon_move_player.stop()
