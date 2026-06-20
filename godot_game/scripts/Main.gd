extends Node2D

@onready var world: Node2D = $World
@onready var darkness_overlay: ColorRect = $DarknessOverlay
@onready var hud_layer: HUD = $HUDLayer
@onready var crafting_menu: CraftingMenu = $CraftingMenu
@onready var background: ColorRect = $Background

var player: Player
var camera: Camera2D
var day_night: DayNightCycle
var world_gen: WorldGenerator

func _ready() -> void:
	_setup_background()
	_setup_day_night()
	_spawn_player()
	_setup_camera()
	_generate_world()
	_setup_hud()
	_connect_signals()

func _setup_background() -> void:
	background.color = Color(0.12, 0.18, 0.1)
	background.size = Vector2(8000, 8000)
	background.position = Vector2(-4000, -4000)
	# Draw grid lines via shader or just leave as flat color
	_draw_ground_detail()

func _draw_ground_detail() -> void:
	# Add some visual variety with scattered rocks/grass patches
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 200:
		var patch := ColorRect.new()
		patch.size = Vector2(rng.randf_range(20, 60), rng.randf_range(15, 40))
		patch.position = Vector2(rng.randf_range(-3000, 3000), rng.randf_range(-3000, 3000))
		patch.color = Color(
			rng.randf_range(0.1, 0.18),
			rng.randf_range(0.17, 0.26),
			rng.randf_range(0.08, 0.14)
		)
		background.add_child(patch)

func _setup_day_night() -> void:
	day_night = DayNightCycle.new()
	day_night.name = "DayNightCycle"
	add_child(day_night)
	day_night.setup(darkness_overlay)

func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.position = Vector2.ZERO
	player.z_index = 10
	world.add_child(player)
	GameManager.register_player(player)

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.zoom = Vector2(1.2, 1.2)
	player.add_child(camera)
	camera.make_current()

func _generate_world() -> void:
	world_gen = WorldGenerator.new()
	world_gen.name = "WorldGenerator"
	world.add_child(world_gen)
	world_gen.setup(world, day_night)
	world_gen.generate()

func _setup_hud() -> void:
	hud_layer.setup(player, day_night)
	crafting_menu.setup(player)
	GameManager.register_hud(hud_layer)

func _connect_signals() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.register_world(world)
	day_night.phase_changed.connect(_on_phase_changed)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
	if Input.is_action_just_pressed("restart") and GameManager.is_game_over:
		get_tree().reload_current_scene()

func _on_game_over() -> void:
	hud_layer.show_game_over()
	player.set_physics_process(false)

func _on_phase_changed(phase: String, day: int) -> void:
	hud_layer.show_notification("Day %d - %s" % [day, phase], 3.0)
