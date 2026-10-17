extends Node2D

@onready var world: Node2D = $World
@onready var world_darkness: CanvasModulate = $WorldDarkness
@onready var hud_layer: HUD = $HUDLayer
@onready var crafting_menu: CraftingMenu = $CraftingMenu
@onready var backpack_menu: BackpackMenu = $BackpackMenu
@onready var chest_menu: ChestMenu = $ChestMenu
@onready var trade_menu: TradeMenu = $TradeMenu
@onready var map_menu: MapMenu = $MapMenu
@onready var quest_menu: QuestMenu = $QuestMenu
@onready var background: ColorRect = $Background

var player: Player
var camera: Camera2D
var day_night: DayNightCycle
var world_gen: WorldGenerator
var weather_sys: WeatherSystem

func _ready() -> void:
	# GameManager is an autoload, so its state survives a scene reload / coming back from the
	# title screen. Clear it here so every fresh load of this scene (Iniciar, R-restart, or
	# "Voltar para a tela inicial" -> Iniciar) starts a clean run.
	GameManager.reset_game_state()
	Engine.time_scale = 1.0  # reset (it persists across scene reloads)
	Audio.stop_all()  # silence any night ambience left running from a previous run
	_setup_background()
	_setup_day_night()
	_spawn_player()
	_setup_camera()
	_generate_world()
	_setup_hud()
	_connect_signals()
	if GameManager.pending_load is Dictionary:
		SaveSystem.apply(self, GameManager.pending_load)
		GameManager.pending_load = null

# World px per source px for the tiled ground texture. The terrain texture is a large
# (~980x348) varied, seamless tile (see tools/slice_terrain.gd); at 0.85 one dirt diamond
# (~140x87 px source) is ~119x74 world px and the tile blankets most of the screen, so the
# little remaining repetition is hard to notice.
const TERRAIN_SCALE := 0.85
const WORLD_SIZE := 20000.0  # visual ground span; must exceed WorldGenerator.WORLD_SIZE (18000) + walls

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
	day_night.setup(world_darkness)

func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.position = WorldGenerator.SPAWN_POS  # the green edge — your base side of the map
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
	# Loading a save? Inject the seed BEFORE generating — the world rebuilds identically and
	# SaveSystem.apply then lays the deltas on top (end of _ready).
	if GameManager.pending_load is Dictionary:
		world_gen.world_seed = int(GameManager.pending_load.get("seed", 0))
	world_gen.generate()

	# Sanity-driven terror creatures (the horror hook): spawn near the player while sanity is low.
	var shadow_spawner := ShadowSpawner.new()
	shadow_spawner.name = "ShadowSpawner"
	world.add_child(shadow_spawner)

	# Big-world tick gating: far mobs/resources stop processing (see StreamingSystem).
	var streaming := StreamingSystem.new()
	streaming.name = "StreamingSystem"
	add_child(streaming)
	streaming.setup(world)

	# Moon-driven tide: moves the water line, reveals the Orla at spring lows, drowns stragglers.
	var tide := TideSystem.new()
	tide.name = "TideSystem"
	add_child(tide)
	tide.setup(day_night, world_gen)

func _setup_hud() -> void:
	hud_layer.setup(player, day_night)
	crafting_menu.setup(player)
	backpack_menu.setup(player)
	chest_menu.setup(player)
	map_menu.setup(player, world_gen)
	GameManager.register_hud(hud_layer)
	GameManager.register_menus(crafting_menu, backpack_menu, chest_menu, trade_menu, map_menu, quest_menu)
	# S4: the quest chain + lair-boss hooks (their unique relics are the real reward).
	var quests := QuestSystem.new()
	quests.name = "QuestSystem"
	add_child(quests)
	GameManager.quest_system = quests
	if world_gen.alfa_boss:
		world_gen.alfa_boss.died.connect(func(_m): quests.on_boss_killed("alfa"))
	if world_gen.jacare_boss:
		world_gen.jacare_boss.died.connect(func(_m): quests.on_boss_killed("jacare"))
	weather_sys = WeatherSystem.new()
	weather_sys.name = "WeatherSystem"
	add_child(weather_sys)
	weather_sys.setup()

func _connect_signals() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_won.connect(_on_victory)
	GameManager.register_world(world)
	day_night.phase_changed.connect(_on_phase_changed)
	# Auto-save at each new day (endless survival must survive closing the game).
	GameManager.new_day.connect(func(_d):
		SaveSystem.save_game(self)
		hud_layer.show_notification("💾 Novo dia — progresso salvo", 2.5))

var _biome_check: float = 0.0
var _last_biome: int = -1
var _camp_found: bool = false
var _found_landmarks: Dictionary = {}

func _process(delta: float) -> void:
	# Announce the district as the player crosses into it ("Centro Comercial", ...) — cheap polling.
	_biome_check -= delta
	if _biome_check <= 0.0 and world_gen and player:
		_biome_check = 0.5
		var b := world_gen.district_at(player.global_position)
		if b != _last_biome:
			_last_biome = b
			hud_layer.show_notification(world_gen.district_display_name(b), 2.5)
			if b == WorldGenerator.District.ISLAND:
				GameManager.on_island_reached()  # perk milestone (S6)
		# First time stumbling on the raccoon colony — the discovery moment.
		if not _camp_found and player.global_position.distance_to(world_gen.colony_pos) < 450.0:
			_camp_found = true
			hud_layer.show_notification("Você encontrou a colônia de guaxinins! Fale com o corvo [E]", 4.0)
		# Discovering points of interest.
		for i in world_gen.landmarks.size():
			if not _found_landmarks.has(i) and player.global_position.distance_to(world_gen.landmarks[i]["pos"]) < 360.0:
				_found_landmarks[i] = true
				hud_layer.show_notification("Você descobriu: %s" % world_gen.landmarks[i]["label"], 3.5)
	# Esc is handled by PauseMenu now (opens/closes the pause overlay) — no longer a hard quit.
	if Input.is_action_just_pressed("restart") and (GameManager.is_game_over or GameManager.is_won):
		get_tree().reload_current_scene()
	if Input.is_action_just_pressed("time_faster"):
		_set_time_scale(Engine.time_scale * 2.0)
	if Input.is_action_just_pressed("time_slower"):
		_set_time_scale(Engine.time_scale / 2.0)
	# Debug: B summons a test boss on demand (killing it does NOT trigger victory, so the fight
	# can be rehearsed repeatedly in one run). Same family as the =/- time-scale test keys.
	if Input.is_action_just_pressed("debug_spawn_boss") and not GameManager.is_game_over and not GameManager.is_won:
		_spawn_boss(true)

## Fast-forward for testing the day/night loop. '=' speeds up, '-' slows down (1x..32x).
func _set_time_scale(s: float) -> void:
	Engine.time_scale = clampf(s, 1.0, 32.0)
	if hud_layer:
		hud_layer.show_notification("Velocidade x%.0f" % Engine.time_scale)

func _on_game_over() -> void:
	Engine.time_scale = 1.0
	Audio.stop_all()
	SaveSystem.delete_save()  # the run IS the score — death ends it (Don't Starve rules)
	hud_layer.show_game_over()
	player.set_physics_process(false)

func _on_victory() -> void:
	Engine.time_scale = 1.0
	Audio.stop_all()
	hud_layer.show_victory()
	player.set_physics_process(false)

func _on_phase_changed(phase: String, day: int) -> void:
	Audio.set_night(phase == "Night")  # eerie drone only at night
	if phase == "Night":
		_begin_night(day)
	else:
		GameManager.blood_moon = false  # any daylight phase ends the blood moon
		match phase:
			"Dusk":
				if day_night.is_full_moon():
					hud_layer.show_notification("O céu avermelha... uma Lua de Sangue se aproxima", 4.0)
				else:
					hud_layer.show_notification("Entardecer — a noite se aproxima", 3.0)
			"Dawn":
				hud_layer.show_notification("Amanhecer", 2.5)

## The city falls across the first three nights (all lights → half grid → total blackout), then
## night 4+ is the permanent dark. No scheduled boss — bosses live in PLACES now (GDD S4).
func _begin_night(day: int) -> void:
	# Blood Moon on EVERY full moon (days 2, 10, 18...), scaling each cycle (see ShadowSpawner).
	# It used to fire once on day 2 and never again — a flat difficulty curve in an endless game.
	if day_night.is_full_moon():
		GameManager.blood_moon = true
		hud_layer.show_notification("🌙 LUA DE SANGUE — as sombras vêm por você", 4.5)
	match day:
		1:
			hud_layer.show_notification("Noite 1 — os postes ainda seguram a escuridão", 4.0)
		3:
			hud_layer.show_notification("APAGÃO TOTAL — a rede da cidade morreu esta noite", 4.5)
		_:
			pass  # night 4+: the dark is just how the world is now

func _spawn_boss(debug: bool = false) -> void:
	var boss := BossMob.new()
	var ang := randf() * TAU
	boss.position = player.global_position + Vector2(cos(ang), sin(ang)) * 260.0
	world.get_node("Mobs").add_child(boss)
	Audio.play_sfx("boss_roar", 0.0, 3.0)  # a little louder — it's the climax
	if debug:
		hud_layer.show_notification("[DEBUG] Chefe invocado — matá-lo não dá vitória", 3.0)
		return
	boss.died.connect(func(_m): GameManager.trigger_victory())
	hud_layer.show_notification("⚠ Um chefe surgiu na noite!", 4.0)
