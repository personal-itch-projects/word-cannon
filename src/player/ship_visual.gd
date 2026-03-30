extends Node2D

## Renders a 3D pirate ship + cannon in a SubViewport and displays it as a Sprite2D.
## The cannon rotates based on the parent platform's cannon_angle.
## The ship flips with a 0.1s tween when changing direction.

const VIEWPORT_SIZE := Vector2i(256, 256)
const SHIP_TURN_DURATION := 0.1

var _viewport: SubViewport
var _sprite: Sprite2D
var _camera: Camera3D
var _ship_node: Node3D
var _cannon_pivot: Node3D  # Pivot at barrel base for correct rotation
var _ship_root: Node3D  # Root 3D node that holds ship + cannon
var _current_facing: float = PI  # Y rotation of ship (PI = right-facing, 0 = left-facing)
var _last_cannon_angle: float = 0.0
var _turn_tween: Tween

func _ready() -> void:
	_setup_viewport()

func _setup_viewport() -> void:
	# Create SubViewport for 3D rendering
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_viewport.msaa_3d = SubViewport.MSAA_2X
	add_child(_viewport)

	# Create 3D scene root
	_ship_root = Node3D.new()
	_ship_root.name = "ShipRoot"
	_ship_root.rotation.y = PI
	_viewport.add_child(_ship_root)

	# Add lighting
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	environment.ambient_light_energy = 0.8
	env.environment = environment
	_viewport.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = false
	_viewport.add_child(sun)

	# Load ship model
	var ship_scene := load("res://assets/models/ship-pirate-small.glb") as PackedScene
	_ship_node = ship_scene.instantiate()
	_ship_node.name = "Ship"
	_ship_root.add_child(_ship_node)

	# Load cannon barrel from weapon-cannon (remove the base, keep barrel)
	var cannon_scene := load("res://assets/models/weapon-cannon.glb") as PackedScene
	var cannon_inst := cannon_scene.instantiate()
	var base_mesh := cannon_inst.find_child("weapon-cannon", true, false)
	var barrel: MeshInstance3D
	if base_mesh:
		barrel = base_mesh.find_child("barrel", true, false)
		if barrel:
			base_mesh.remove_child(barrel)
	cannon_inst.queue_free()

	# Apply tower defense colormap texture to barrel
	if barrel:
		var td_colormap := load("res://assets/models/Textures/colormap-td.png")
		for si in barrel.mesh.get_surface_count():
			var mat := barrel.mesh.surface_get_material(si) as StandardMaterial3D
			if mat:
				var new_mat := mat.duplicate() as StandardMaterial3D
				new_mat.albedo_texture = td_colormap
				barrel.set_surface_override_material(si, new_mat)

	# Pivot node at the barrel base so rotation swings the barrel correctly
	_cannon_pivot = Node3D.new()
	_cannon_pivot.name = "CannonPivot"
	_cannon_pivot.position = Vector3(0, 1.0, 0.0)
	_cannon_pivot.scale = Vector3(7.5, 7.5, 7.5)
	_ship_root.add_child(_cannon_pivot)

	if barrel:
		# Barrel's original position was (0, 0.383, 0) — offset it so pivot is at its base
		barrel.position = Vector3(0, 0, 0)
		_cannon_pivot.add_child(barrel)

	# Pitch the cannon upward
	_cannon_pivot.rotation.x = -1.0

	# Scale down ship to fit viewport including mast/sail
	_ship_root.scale = Vector3(0.25, 0.25, 0.25)

	# Camera: side view - looking at the ship from the side (profile)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 3.0
	_camera.position = Vector3(5.0, 1.2, 0.0)
	_camera.rotation_degrees = Vector3(0, 90, 0)
	_viewport.add_child(_camera)

	# Sprite2D to display the viewport texture
	_sprite = Sprite2D.new()
	_sprite.texture = _viewport.get_texture()
	# Scale and position so ship appears correctly at platform position
	_sprite.scale = Vector2(0.7, 0.7)
	_sprite.position = Vector2(0, -10)
	add_child(_sprite)

func set_cannon_angle(angle: float) -> void:
	if _cannon_pivot and not is_equal_approx(angle, _last_cannon_angle):
		_last_cannon_angle = angle
		# From side view, cannon sweeps left/right via Z-axis rotation on the pivot
		var compensated := angle if _current_facing > PI * 0.5 else -angle
		_cannon_pivot.rotation.z = compensated
		_request_update()

func set_ship_direction(direction: float) -> void:
	## direction: -1.0 (left), 0.0 (no change), 1.0 (right)
	if direction == 0.0:
		return
	var target_y: float
	if direction > 0.0:
		target_y = PI   # Facing right
	else:
		target_y = 0.0  # Facing left

	if is_equal_approx(target_y, _current_facing):
		return

	_current_facing = target_y

	if _turn_tween:
		_turn_tween.kill()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_turn_tween = create_tween()
	_turn_tween.tween_property(_ship_root, "rotation:y", target_y, SHIP_TURN_DURATION)
	_turn_tween.tween_callback(func(): _viewport.render_target_update_mode = SubViewport.UPDATE_ONCE)

func _request_update() -> void:
	if _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
