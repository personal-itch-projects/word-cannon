extends Node2D

@onready var game_layer: Node2D = $GameLayer
@onready var background: ColorRect = $Background
var _border_left: Sprite2D
var _border_right: Sprite2D
@onready var menu_letter_spawner: Node2D = $GameLayer/MenuLetterSpawner
@onready var letter_spawner: Node2D = $GameLayer/LetterSpawner
@onready var flock_manager: Node2D = $GameLayer/FlockManager
@onready var platform: Node2D = $GameLayer/Platform
@onready var hud: Control = $UILayer/HUD
@onready var main_menu: Control = $UILayer/MainMenu
@onready var settings_menu: Control = $UILayer/SettingsMenu
@onready var defeat_screen: Control = $UILayer/DefeatScreen
@onready var pause_menu: Control = $UILayer/PauseMenu
@onready var stage_complete_screen: Control = $UILayer/StageCompleteScreen

var _theme_intro: RefCounted

func _ready() -> void:
	_resize_background()
	get_viewport().size_changed.connect(_resize_background)
	_setup_borders()
	var ThemeIntro := preload("res://src/game_scene/theme_intro.gd")
	_theme_intro = ThemeIntro.new()
	_theme_intro.setup(get_tree(), flock_manager, platform, hud, letter_spawner)
	GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.current_state)

func _setup_borders() -> void:
	var shader := preload("res://src/shaders/border_line.gdshader")
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)

	_border_left = Sprite2D.new()
	_border_left.texture = tex
	var mat_l := ShaderMaterial.new()
	mat_l.shader = shader
	_border_left.material = mat_l
	game_layer.add_child(_border_left)

	_border_right = Sprite2D.new()
	_border_right.texture = tex
	var mat_r := ShaderMaterial.new()
	mat_r.shader = shader
	_border_right.material = mat_r
	game_layer.add_child(_border_right)

	_update_borders()

func _update_borders() -> void:
	var bounds := GameManager.get_play_bounds()
	var screen_h: float = get_viewport().get_visible_rect().size.y
	var border_w := 16.0
	_border_left.scale = Vector2(border_w, screen_h)
	_border_left.position = Vector2(bounds.x, screen_h / 2.0)
	_border_right.scale = Vector2(border_w, screen_h)
	_border_right.position = Vector2(bounds.y, screen_h / 2.0)

func _resize_background() -> void:
	background.size = get_viewport().get_visible_rect().size
	if _border_left:
		_update_borders()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if GameManager.current_state == GameState.State.PLAYING:
			GameManager.pause_game()
			get_viewport().set_input_as_handled()

func _on_state_changed(new_state: GameState.State) -> void:
	# Hide everything first
	main_menu.visible = false
	settings_menu.visible = false
	defeat_screen.visible = false
	pause_menu.visible = false
	stage_complete_screen.visible = false
	hud.visible = false
	platform.visible = false
	letter_spawner.set_process(false)
	menu_letter_spawner.visible = false
	menu_letter_spawner.set_process(false)

	match new_state:
		GameState.State.MAIN_MENU:
			main_menu.visible = true
			menu_letter_spawner.visible = true
			menu_letter_spawner.set_process(true)
			_clear_gameplay()
		GameState.State.PLAYING:
			hud.visible = true
			platform.visible = true
			letter_spawner.set_process(true)
			if GameManager.is_resuming:
				menu_letter_spawner.clear_letters()
			else:
				_clear_gameplay()
				menu_letter_spawner.clear_letters()
				_theme_intro.run()
		GameState.State.SETTINGS:
			settings_menu.visible = true
		GameState.State.DEFEAT:
			defeat_screen.visible = true
			hud.visible = true
			_clear_gameplay()
		GameState.State.PAUSED:
			pause_menu.visible = true
			hud.visible = true
			SfxManager.play(SfxManager.sfx_pause_opened)
		GameState.State.STAGE_COMPLETE:
			stage_complete_screen.visible = true
			hud.visible = true
			letter_spawner.set_process(false)

	if new_state != GameState.State.PLAYING:
		SfxManager.stop_cannon_move()

func _clear_gameplay() -> void:
	_theme_intro.cancel()
	flock_manager.clear_all()
	letter_spawner.stop_spawning()
	platform.reset()
