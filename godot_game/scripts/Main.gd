extends Node2D

@onready var world: Node2D = $World
@onready var darkness_overlay: ColorRect = $DarknessLayer/DarknessOverlay
@onready var hud_layer: HUD = $HUDLayer
@onready var crafting_menu: CraftingMenu = $CraftingMenu
@onready var backpack_menu: BackpackMenu = $BackpackMenu
@onready var background: ColorRect = $Background

var player: Player
var camera: Camera2D
var day_night: DayNightCycle
var world_gen: WorldGenerator

func _ready() -> void:
	Engine.time_scale = 1.0  # reset (it persists across scene reloads)
	_setup_background()
	_setup_day_night()
	_spawn_player()
	_setup_camera()
	_generate_world()
	_setup_hud()
	_connect_signals()

# World px per source px for the tiled ground texture. The terrain texture is a large
# (~980x348) varied, seamless tile (see tools/slice_terrain.gd); at 0.85 one dirt diamond
# (~140x87 px source) is ~119x74 world px and the tile blankets most of the screen, so the
# little remaining repetition is hard to notice.
const TERRAIN_SCALE := 0.85
const WORLD_SIZE := 8000.0

func _setup_background() -> void:
	background.size = Vector2(WORLD_SIZE, WORLD_SIZE)
	background.position = Vector2(-WORLD_SIZE * 0.5, -WORLD_SIZE * 0.5)
	var tex := Assets.sprite("terrain", "ground")
	if tex:
		# Tiled dirt sprite sheet (see tools/slice_terrain.gd). Base fill stays a matching
		# dirt brown so nothing green shows through at the very edges of the world.
		background.color = Color(0.30, 0.22, 0.13)
		var ground := Sprite2D.new()
		ground.name = "GroundTexture"
		ground.texture = tex
		ground.centered = false
		ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground.region_enabled = true
		ground.scale = Vector2(TERRAIN_SCALE, TERRAIN_SCALE)
		# region (texture space) * scale = rendered size; size it to blanket the world.
		var span := WORLD_SIZE / TERRAIN_SCALE
		ground.region_rect = Rect2(0, 0, span, span)
		ground.position = Vector2(-WORLD_SIZE * 0.5, -WORLD_SIZE * 0.5)
		ground.z_index = -9  # above the base fill, below every Y-sorted world entity
		add_child(ground)
	else:
		# Fallback: old flat green + scattered procedural patches.
		background.color = Color(0.12, 0.18, 0.1)
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
	# No z_index: the player is Y-sorted with the world so it goes behind/in front
	# of trees, rocks and mobs based on its position.
	world.add_child(player)
	GameManager.register_player(player)

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera2D"
	# Follow the player IN THE PHYSICS STEP. The player moves in _physics_process; with the
	# default idle callback the smoothing ran out of sync with the body and the whole screen
	# jittered while walking (very visible now that the ground has texture).
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
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

	# Sanity-driven terror creatures (the horror hook): spawn near the player while sanity is low.
	var shadow_spawner := ShadowSpawner.new()
	shadow_spawner.name = "ShadowSpawner"
	world.add_child(shadow_spawner)

func _setup_hud() -> void:
	hud_layer.setup(player, day_night)
	crafting_menu.setup(player)
	backpack_menu.setup(player)
	GameManager.register_hud(hud_layer)

func _connect_signals() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_won.connect(_on_victory)
	GameManager.register_world(world)
	day_night.phase_changed.connect(_on_phase_changed)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
	if Input.is_action_just_pressed("restart") and (GameManager.is_game_over or GameManager.is_won):
		get_tree().reload_current_scene()
	if Input.is_action_just_pressed("time_faster"):
		_set_time_scale(Engine.time_scale * 2.0)
	if Input.is_action_just_pressed("time_slower"):
		_set_time_scale(Engine.time_scale / 2.0)

## Fast-forward for testing the day/night loop. '=' speeds up, '-' slows down (1x..8x).
func _set_time_scale(s: float) -> void:
	Engine.time_scale = clampf(s, 1.0, 8.0)
	if hud_layer:
		hud_layer.show_notification("Velocidade x%.0f" % Engine.time_scale)

func _on_game_over() -> void:
	Engine.time_scale = 1.0
	hud_layer.show_game_over()
	player.set_physics_process(false)

func _on_victory() -> void:
	Engine.time_scale = 1.0
	hud_layer.show_victory()
	player.set_physics_process(false)

var _boss_spawned: bool = false

func _on_phase_changed(phase: String, day: int) -> void:
	hud_layer.show_notification("Day %d - %s" % [day, phase], 3.0)
	# MVP climax: a boss appears on the 3rd night. Defeat it to win.
	if phase == "Night" and day >= 3 and not _boss_spawned:
		_boss_spawned = true
		_spawn_boss()

func _spawn_boss() -> void:
	var boss := BossMob.new()
	var ang := randf() * TAU
	boss.position = player.global_position + Vector2(cos(ang), sin(ang)) * 260.0
	world.get_node("Mobs").add_child(boss)
	boss.died.connect(func(_m): GameManager.trigger_victory())
	hud_layer.show_notification("⚠ Um chefe surgiu na noite!", 4.0)
