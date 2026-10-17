class_name Player
extends CharacterBody2D

signal interaction_target_changed(target: Node)

const SPEED := 220.0
const SAIL_SPEED := 320.0  # the raft is a SPEED upgrade (GDD): the sea becomes the fast road
const SWIM_SPEED := 140.0  # swimming (Jacaré scale relic): slower than walking — raft still wins
const DODGE_SPEED := 500.0
const DODGE_DURATION := 0.25
const DODGE_COOLDOWN := 1.2
const ATTACK_COOLDOWN := 0.5
const INTERACT_RADIUS := 80.0
const ATTACK_RADIUS := 65.0
const CHOP_RADIUS := 26.0   # resource harvest reach — short, so you must be close + facing the node
const CHOP_OFFSET := 30.0
const BASE_DAMAGE := 20
const GRID := 40.0  # world grid that dug plots and placed structures snap to, so everything lines up

var stats: PlayerStats
var inventory: Inventory
var facing := Vector2.DOWN
var is_attacking := false
var is_dodging := false
var is_moving := false  # driven by input, not velocity (post-slide velocity is unreliable)
var attack_timer := 0.0
var dodge_timer := 0.0
var dodge_cooldown := 0.0
var step_timer := 0.0

var nearby_interactables: Array = []
var current_target: Node = null
var near_light: bool = false
var has_torch_equipped: bool = false

var walk_cycle: float = 0.0
var hit_flash: float = 0.0

# Sailing: owning a raft turns water from a death zone into a road (see _update_sailing).
var is_sailing: bool = false
var is_swimming: bool = false  # Escama do Jacaré (boss relic): water without the raft, slower
var raft_visual: Node2D = null
var _wg_cache: WorldGenerator = null

# Structure-placement ghost (shown while a structure item is equipped; see _update_placement/_draw).
var _place_show: bool = false
var _place_target: Vector2 = Vector2.ZERO
var _place_valid: bool = false

var sprite: AnimatedSprite2D = null
var axe_sprite: Sprite2D = null      # held tool/weapon overlay in the raccoon's paw
var torch_light: PointLight2D = null # glow around the raccoon while a light source is equipped
var axe_swing: float = 0.0           # 1->0 chop arc while attacking
var _axe_item_id: String = ""        # cached id so we only reload the texture on change

func _ready() -> void:
	stats = PlayerStats.new()
	add_child(stats)
	inventory = Inventory.new()
	add_child(inventory)

	# Collision for player body
	var col := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 14.0
	shape.height = 20.0
	col.shape = shape
	add_child(col)

	# Detection area for interactables: resources (8), dropped items (16) and structures (32).
	# Dropped loot is picked up by pressing INTERACT (E) while near it — never auto-collected.
	var interact_area := Area2D.new()
	interact_area.name = "InteractArea"
	var interact_col := CollisionShape2D.new()
	var interact_shape := CircleShape2D.new()
	interact_shape.radius = INTERACT_RADIUS
	interact_col.shape = interact_shape
	interact_area.add_child(interact_col)
	interact_area.collision_layer = 0
	interact_area.collision_mask = 8 | 16 | 32  # resources + dropped items + structures
	add_child(interact_area)
	interact_area.body_entered.connect(_on_interactable_entered)
	interact_area.body_exited.connect(_on_interactable_exited)

	collision_layer = 2
	collision_mask = 1 | 4 | 32

	GameManager.register_player(self)
	stats.died.connect(_on_died)
	inventory.item_equipped.connect(_on_item_equipped)
	_build_raft_visual()  # BEFORE the sprite: both draw behind-parent, tree order keeps the raccoon on top
	_setup_sprite()

	# Held-tool overlay (axe/pickaxe/etc.) drawn in the raccoon's paw; positioned each frame.
	axe_sprite = Sprite2D.new()
	axe_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	axe_sprite.visible = false
	add_child(axe_sprite)

	# Torch glow: lights the area around the raccoon when a torch/light source is equipped.
	torch_light = PointLight2D.new()
	torch_light.texture = Assets.light_texture()
	torch_light.texture_scale = 175.0 / 128.0
	torch_light.color = Color(1.0, 0.82, 0.5)
	torch_light.energy = 1.0
	torch_light.enabled = false
	add_child(torch_light)

	# Start with an axe equipped so the player can chop trees from the get-go (still craftable).
	inventory.add_item("axe", 1)
	inventory.equip_slot(0)

func _setup_sprite() -> void:
	# Isometric raccoon: SE/SW/NE provided; NW is NE mirrored. Attack only SE/SW.
	var sf := Assets.sprite_frames("player", [
		{"anim": "idle_se", "count": 3, "fps": 4.0, "loop": true},
		{"anim": "idle_sw", "count": 1, "fps": 4.0, "loop": true},
		{"anim": "idle_ne", "count": 1, "fps": 4.0, "loop": true},
		{"anim": "walk_se", "count": 6, "fps": 10.0, "loop": true},
		{"anim": "walk_sw", "count": 6, "fps": 10.0, "loop": true},
		{"anim": "walk_ne", "count": 6, "fps": 10.0, "loop": true},
		{"anim": "attack_se", "count": 4, "fps": 18.0, "loop": false},
		{"anim": "attack_sw", "count": 4, "fps": 18.0, "loop": false},
	])
	if sf == null:
		return
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = sf
	sprite.animation = "idle_se"
	sprite.show_behind_parent = true  # keep equipped item / attack arc on top
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixel art
	var tex := sf.get_frame_texture("idle_se", 0)
	var s := 60.0 / float(tex.get_height())
	sprite.scale = Vector2(s, s)
	sprite.position.y = 16.0 - tex.get_height() * s * 0.5  # bottom (feet) near the body base
	add_child(sprite)
	sprite.play("idle_se")

func _update_sprite() -> void:
	if sprite == null:
		return
	# Back view (NE) only when up is the dominant direction; otherwise the front view (SE).
	# Left/right is a horizontal flip of the same art, so going left never shows the back.
	var going_up := facing.y < 0.0 and absf(facing.y) > absf(facing.x)
	var base := "ne" if going_up else "se"
	var anim := ""
	if is_attacking:
		anim = "attack_se"  # attack art is front-only; flip handles left
	else:
		anim = ("walk_" if is_moving else "idle_") + base
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = facing.x < 0.0
	# Tie the leg cadence to ground speed so the feet don't slide — most visible on the fast dodge.
	if is_moving and not is_attacking:
		sprite.speed_scale = clampf(velocity.length() / SPEED, 1.0, 2.8)
	else:
		sprite.speed_scale = 1.0
	if hit_flash > 0.5:
		sprite.modulate = Color(1.8, 1.8, 1.8)
	elif is_dodging:
		sprite.modulate = Color(0.85, 0.92, 1.0, 0.7)
	else:
		sprite.modulate = Color.WHITE

## Place the held tool/weapon in the paw: visible only for TOOL/WEAPON, mirrored with the
## raccoon's facing, behind the body on the back view, and swinging during an attack.
func _update_axe() -> void:
	if axe_sprite == null:
		return
	var equipped_id := inventory.get_equipped_item()
	var item_data = ItemDatabase.get_item(equipped_id) if equipped_id != "" else null
	var show_tool: bool = item_data != null and (item_data.type == ItemDatabase.ItemType.TOOL or item_data.type == ItemDatabase.ItemType.WEAPON)
	axe_sprite.visible = show_tool
	if not show_tool:
		return

	if _axe_item_id != equipped_id:
		_axe_item_id = equipped_id
		var icon := Assets.item_icon(equipped_id)
		axe_sprite.texture = icon
		if icon:
			var hs := 30.0 / float(icon.get_height())
			axe_sprite.scale = Vector2(hs, hs)

	# Mirror the raccoon's facing (same rule as _update_sprite).
	var going_up := facing.y < 0.0 and absf(facing.y) > absf(facing.x)
	var side := -1.0 if facing.x < 0.0 else 1.0
	axe_sprite.flip_h = facing.x < 0.0
	if going_up:
		axe_sprite.position = Vector2(side * 12.0, -12.0)
		axe_sprite.z_index = -1  # tucked behind the raccoon's back
	else:
		axe_sprite.position = Vector2(side * 15.0, -2.0)
		axe_sprite.z_index = 1   # in front of the body

	# Held diagonally; a chop arc adds on top while attacking (axe_swing 1->0).
	var swing := sin(axe_swing * PI) * 1.4
	axe_sprite.rotation = side * (0.45 + swing)

func _physics_process(delta: float) -> void:
	if is_sleeping:
		_tick_sleep()
		return
	_handle_timers(delta)
	_update_sailing()
	_handle_input(delta)
	_handle_movement(delta)
	_check_light()
	_tick_torch(delta)
	_update_sprite()
	_update_axe()
	_update_placement()
	queue_redraw()

# ── Sleep (S5) — time runs 4x while asleep; the night is LIVED, not skipped ─────────────────

var is_sleeping := false
var _zzz_label: Label = null

func start_sleeping(bed: Node) -> void:
	if is_sleeping:
		return
	is_sleeping = true
	stats.is_sleeping = true
	global_position = bed.global_position + Vector2(0.0, -2.0)
	velocity = Vector2.ZERO
	Engine.time_scale = 4.0
	GameManager.on_slept()  # perk milestone (S6)
	if _zzz_label == null:
		_zzz_label = Label.new()
		_zzz_label.text = "💤"
		_zzz_label.position = Vector2(6, -46)
		_zzz_label.add_theme_font_size_override("font_size", 16)
		add_child(_zzz_label)
	_zzz_label.visible = true
	if GameManager.hud and GameManager.hud.has_method("show_notification"):
		GameManager.hud.show_notification("💤 Dormindo... (qualquer tecla acorda)", 3.0)

func wake_up() -> void:
	if not is_sleeping:
		return
	is_sleeping = false
	stats.is_sleeping = false
	Engine.time_scale = 1.0
	if _zzz_label:
		_zzz_label.visible = false

func _tick_sleep() -> void:
	velocity = Vector2.ZERO
	if stats.energy >= PlayerStats.MAX_ENERGY:
		wake_up()
		if GameManager.hud and GameManager.hud.has_method("show_notification"):
			GameManager.hud.show_notification("😊 Você acordou descansado", 2.5)
	elif stats.is_cold() or stats.is_bleeding():
		wake_up()  # discomfort interrupts the nap — no sleeping through hypothermia
	elif _wake_input():
		wake_up()

func _wake_input() -> bool:
	for act in ["attack", "dodge", "interact", "move_left", "move_right", "move_up", "move_down"]:
		if Input.is_action_just_pressed(act):
			return true
	return false

# ── Indoors (Building roof trigger; refcounted like the light sources) ──────────────────────

var _indoor_refs := 0

func set_indoors(inside: bool) -> void:
	_indoor_refs = maxi(0, _indoor_refs + (1 if inside else -1))
	stats.indoors = _indoor_refs > 0

func _handle_timers(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta
	if dodge_cooldown > 0.0:
		dodge_cooldown -= delta
	if hit_flash > 0.0:
		hit_flash -= delta * 4.0
	if axe_swing > 0.0:
		axe_swing = maxf(0.0, axe_swing - delta * 5.0)  # ~0.2s chop arc
	if is_dodging:
		dodge_timer -= delta
		if dodge_timer <= 0.0:
			is_dodging = false
			stats.invincible = false

func _handle_input(delta: float) -> void:
	# A left-click that lands on UI (an open menu, or the always-visible hotbar) is moving/
	# selecting items, not attacking — so don't swing when a menu is open or the cursor is over
	# any HUD control. (The world Background is MOUSE_FILTER_IGNORE, so world clicks still attack.)
	var blocked_by_ui: bool = GameManager.is_menu_open() or get_viewport().gui_get_hovered_control() != null
	if Input.is_action_just_pressed("attack") and attack_timer <= 0.0 and not is_dodging and not blocked_by_ui:
		_perform_attack()
	if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0.0 and not is_dodging:
		_start_dodge()
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	if Input.is_action_just_pressed("next_item"):
		inventory.cycle_hotbar()
	for i in 6:
		if Input.is_action_just_pressed("slot_%d" % (i + 1)):
			inventory.equip_slot(i)

func _handle_movement(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	if is_dodging:
		velocity = facing * DODGE_SPEED
		is_moving = true
	elif input_dir.length() > 0.1:
		facing = input_dir.normalized()
		var speed := SAIL_SPEED if is_sailing else (SWIM_SPEED if is_swimming else SPEED)
		if is_sailing and GameManager.has_perk("lobo_do_mar"):
			speed *= 1.15  # perk (S6): reads the currents
		if stats.is_exhausted():
			speed *= 0.7  # exhaustion (S5): dragging your feet until you sleep
		velocity = input_dir.normalized() * speed
		walk_cycle += delta * 8.0
		is_moving = true
	else:
		# Stop firmly so a step doesn't glide on after you release the key (start is instant, so the
		# stop should be too — a slow decel here was the "ice-skating" slide).
		velocity = velocity.move_toward(Vector2.ZERO, SPEED * 16.0 * delta)
		is_moving = false

	move_and_slide()

func _start_dodge() -> void:
	is_dodging = true
	stats.invincible = true
	stats.spend_energy(PlayerStats.ENERGY_DODGE_COST)
	dodge_timer = DODGE_DURATION
	dodge_cooldown = DODGE_COOLDOWN

func _perform_attack() -> void:
	var equipped_id := inventory.get_equipped_item()
	var item_data = ItemDatabase.get_item(equipped_id) if equipped_id != "" else null

	# Holding a structure item: left-click PLACES it on the snapped grid cell instead of swinging.
	if item_data and item_data.type == ItemDatabase.ItemType.STRUCTURE:
		_try_place_structure(equipped_id)
		return

	attack_timer = ATTACK_COOLDOWN * (1.35 if stats.is_exhausted() else 1.0)  # tired = sluggish swings
	stats.spend_energy(PlayerStats.ENERGY_ATTACK_COST)
	is_attacking = true
	axe_swing = 1.0  # kick off the held-tool chop arc
	Audio.play_sfx("attack", 0.1)

	var damage := BASE_DAMAGE
	if item_data and (item_data.type == ItemDatabase.ItemType.WEAPON or item_data.type == ItemDatabase.ItemType.TOOL):
		damage = item_data.damage if item_data.damage > 0 else BASE_DAMAGE
	if GameManager.has_perk("cacador"):
		damage *= 1.1  # perk (S6): sharper strikes against everything the swing hits

	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = ATTACK_RADIUS
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + facing * 40.0)
	query.collision_mask = 4  # mobs only

	var results := space.intersect_shape(query, 8)
	var struck := false
	for res in results:
		if res.collider.has_method("take_damage"):
			res.collider.take_damage(damage, self)
			struck = true
			if item_data and item_data.durability > 0:
				inventory.use_durability(equipped_id, 1)

	# Chop / mine / gather a resource node in front: trees (axe), rocks (pickaxe), bushes. Uses a
	# much SHORTER reach than combat so you have to be close and facing it (no hitting a tree from
	# well below). Only the single closest node is harvested. Grass is interact-only.
	var chop_query := PhysicsShapeQueryParameters2D.new()
	var chop_shape := CircleShape2D.new()
	chop_shape.radius = CHOP_RADIUS
	chop_query.shape = chop_shape
	chop_query.transform = Transform2D(0.0, global_position + facing * CHOP_OFFSET)
	chop_query.collision_mask = 8  # resources layer
	var best_node: ResourceNode = null
	var best_dist := INF
	for res in space.intersect_shape(chop_query, 8):
		var node := res.collider as ResourceNode
		if node == null or node.resource_type == ResourceNode.ResourceType.GRASS_TUFT:
			continue
		var d := global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best_node = node
	if best_node != null:
		best_node.chop(self)
		struck = true

	if struck:
		Audio.play_sfx("hit", 0.12)

	# Shovel on bare ground (no mob, no resource in front) tills a new farm plot.
	if equipped_id == "shovel" and best_node == null and not struck:
		_try_till()

	await get_tree().create_timer(0.18).timeout
	is_attacking = false
	queue_redraw()

## Shovel: swing at bare ground to till a new farm plot just in front of the player (unless one is
## already there). The plot is then planted with seeds via E — see FarmPlot.interact.
func _try_till() -> void:
	var world := GameManager.world
	if world == null:
		return
	var cell := _snap_to_grid(global_position + facing * GRID)
	if not _cell_free(cell):
		return  # cell already has a plot / structure
	var wg = world.get_node_or_null("WorldGenerator")
	if wg == null:
		return
	wg.place_structure("farm_plot", cell, self)
	inventory.use_durability("shovel", 1)
	Audio.play_sfx("dig", 0.12)
	_spawn_dirt_puff(cell)

## Place the equipped structure item on the snapped grid cell in front (left-click). Consumes one.
func _try_place_structure(id: String) -> void:
	if not inventory.has_item(id):
		return
	var world := GameManager.world
	if world == null:
		return
	var cell := _snap_to_grid(global_position + facing * GRID)
	if not _cell_free(cell):
		return
	var wg = world.get_node_or_null("WorldGenerator")
	if wg == null:
		return
	if wg.place_structure(id, cell, self):
		inventory.remove_item(id, 1)
		Audio.play_sfx("hit", 0.08)  # a placement thunk

## While a structure item is equipped, cache the snapped target cell + whether it's free, for the
## ghost preview drawn in _draw.
func _update_placement() -> void:
	var id := inventory.get_equipped_item()
	var data = ItemDatabase.get_item(id) if id != "" else null
	_place_show = data != null and data.type == ItemDatabase.ItemType.STRUCTURE
	if not _place_show:
		return
	_place_target = _snap_to_grid(global_position + facing * GRID)
	_place_valid = _cell_free(_place_target)

## True when the grid cell has no structure / farm plot already sitting on it.
func _cell_free(cell: Vector2) -> bool:
	if GameManager.world == null:
		return true
	var structures := GameManager.world.get_node_or_null("Structures")
	if structures == null:
		return true
	for c in structures.get_children():
		var n := c as Node2D
		if n != null and n.global_position.distance_to(cell) < GRID * 0.5:
			return false
	return true

func _snap_to_grid(p: Vector2) -> Vector2:
	return Vector2(roundf(p.x / GRID), roundf(p.y / GRID)) * GRID

## Brief brown particle burst when the shovel turns the soil — purely cosmetic, self-frees.
func _spawn_dirt_puff(pos: Vector2) -> void:
	var world := GameManager.world
	if world == null:
		return
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.one_shot = true
	p.amount = 12
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 45.0
	p.initial_velocity_max = 105.0
	p.gravity = Vector2(0, 340.0)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	# Dark, fresh-soil clods that fade out — darker than the dry dirt ground so the burst reads
	# (a mid-brown puff was nearly invisible against the brown terrain).
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.26, 0.16, 0.08, 1.0))
	ramp.set_color(1, Color(0.26, 0.16, 0.08, 0.0))
	p.color_ramp = ramp
	p.z_index = 5
	world.add_child(p)
	p.finished.connect(p.queue_free)
	p.emitting = true

func _try_interact() -> void:
	if nearby_interactables.is_empty():
		return
	# Interact (E) only PICKS grass tufts from the ground and operates structures (chest, campfire).
	# Trees, rocks and bushes are harvested with the attack button now.
	var closest: Node = null
	var closest_dist := INF
	for obj in nearby_interactables:
		if not is_instance_valid(obj):
			continue
		# E works on grass (pluck) and bushes (pick the berries, bush survives). Trees and rocks
		# are attack-only.
		var rn := obj as ResourceNode
		if rn != null and rn.resource_type != ResourceNode.ResourceType.GRASS_TUFT and rn.resource_type != ResourceNode.ResourceType.BUSH:
			continue
		var d := global_position.distance_to(obj.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = obj
	if closest and closest.has_method("interact"):
		closest.interact(self)

func _on_interactable_entered(body: Node) -> void:
	if not body in nearby_interactables:
		nearby_interactables.append(body)

func _on_interactable_exited(body: Node) -> void:
	nearby_interactables.erase(body)

func _check_light() -> void:
	has_torch_equipped = false
	var equipped_id := inventory.get_equipped_item()
	if equipped_id != "":
		var item_data = ItemDatabase.get_item(equipped_id)
		# Only a HELD tool (the torch) lights the player. The campfire is is_light_source too, but
		# it's a STRUCTURE you carry to place — holding it shouldn't make the player glow; only the
		# campfire placed on the ground illuminates (via its own PointLight2D).
		if item_data and item_data.is_light_source and item_data.type == ItemDatabase.ItemType.TOOL:
			has_torch_equipped = true
	stats.set_in_light(near_light or has_torch_equipped)
	if torch_light:
		torch_light.enabled = has_torch_equipped

var _light_refs: int = 0

## Refcounted: each overlapping light source (campfire, street lamp) adds/removes ONE credit.
## The old bool was last-writer-wins — stepping out of a lamp while beside a lit campfire blanked
## ALL light and silently flipped the night sanity drain from 3/min to 50/min (confirmed bug).
func set_near_light(value: bool) -> void:
	_light_refs = maxi(0, _light_refs + (1 if value else -1))
	near_light = _light_refs > 0

func _world_gen() -> WorldGenerator:
	if _wg_cache == null and GameManager.world:
		_wg_cache = GameManager.world.get_node_or_null("WorldGenerator")
	return _wg_cache

## Owning a raft = sailing whenever you're on water (faster than paws; TideSystem skips drowning).
## The Jacaré's scale unlocks SWIMMING: water without the raft, slower — the raft stays the fast road.
func _update_sailing() -> void:
	var wg := _world_gen()
	var on_water: bool = wg != null and wg.is_water(global_position)
	is_sailing = on_water and inventory.has_item("raft")
	is_swimming = on_water and not is_sailing and inventory.has_item("jacare_scale")
	stats.swimming = is_swimming  # temperatura (S5): open water strips body heat
	if raft_visual:
		raft_visual.visible = is_sailing

## Lashed-plank raft drawn under the raccoon while sailing (static polygons, toggled by visibility).
func _build_raft_visual() -> void:
	raft_visual = Node2D.new()
	raft_visual.name = "RaftVisual"
	raft_visual.show_behind_parent = true
	raft_visual.visible = false
	add_child(raft_visual)
	var deck := Polygon2D.new()
	deck.polygon = PackedVector2Array([Vector2(-28, -8), Vector2(28, -8), Vector2(30, 24), Vector2(-30, 24)])
	deck.color = Color(0.52, 0.36, 0.18)
	raft_visual.add_child(deck)
	for i in 3:  # plank gaps
		var gap := Polygon2D.new()
		var gx := -14.0 + i * 14.0
		gap.polygon = PackedVector2Array([Vector2(gx, -8), Vector2(gx + 2.5, -8), Vector2(gx + 2.5, 24), Vector2(gx, 24)])
		gap.color = Color(0.36, 0.24, 0.11)
		raft_visual.add_child(gap)
	var rim := Polygon2D.new()  # bow shading strip
	rim.polygon = PackedVector2Array([Vector2(-30, 20), Vector2(30, 20), Vector2(30, 24), Vector2(-30, 24)])
	rim.color = Color(0.3, 0.2, 0.1)
	raft_visual.add_child(rim)

var _torch_burn: float = 0.0
var _torch_warned: bool = false

## The torch BURNS while it lights the dark (equipped + not daytime): ~2/s, 6/s under rain.
## It used to be eternal — a near-free pocket streetlight that nullified the blackout, the street
## lamps and half the night terror (review finding). One torch ≈ one night of darkness (225 dur).
## No burn in daylight, so carrying it around by day is never a chore — fun > realism.
func _tick_torch(delta: float) -> void:
	if not has_torch_equipped or stats == null or stats.is_day:
		return
	_torch_burn += delta * (6.0 if GameManager.is_raining() else 2.0)
	if _torch_burn < 1.0:
		return
	var n := int(_torch_burn)
	_torch_burn -= float(n)
	if not inventory.use_durability("torch", n):
		_torch_warned = false
		if GameManager.hud and GameManager.hud.has_method("show_notification"):
			GameManager.hud.show_notification("Sua tocha se apagou!", 3.0)
		return
	var dur := inventory.get_durability("torch")
	if dur > 55:
		_torch_warned = false  # fresh torch — arm the warning again
	elif not _torch_warned:
		_torch_warned = true
		if GameManager.hud and GameManager.hud.has_method("show_notification"):
			GameManager.hud.show_notification("Sua tocha está no fim...", 3.0)

func take_damage(amount: float, attacker: Node = null) -> void:
	if is_sleeping:
		wake_up()  # getting hit ends the nap — the 4x night can bite (shadows, blood moon)
	if stats.invincible:
		return  # i-frames (dodge/god): no damage, no flinch — and NO armor wear (it used to
		        # grind durability on every dodged hit, punishing exactly the skilled play)
	Audio.play_sfx("hurt", 0.08)
	# Worn armor blocks a fraction of the hit and wears down for absorbing it.
	var final_amount := amount
	var armor_id := inventory.equipped_armor
	if armor_id != "":
		var armor_data = ItemDatabase.get_item(armor_id)
		if armor_data and armor_data.armor > 0.0:
			final_amount = amount * (1.0 - armor_data.armor)
			inventory.use_armor_durability(1)
	stats.take_damage(final_amount)
	# Condições (S5): a landed bite can open a wound — vermin are filthier than the big fauna.
	if GameManager.has_perk("casca_grossa"):
		final_amount *= 0.9  # perk (S6): survivor's thick hide
	if final_amount > 0.0 and attacker is MobBase:
		var bleed_chance := 0.3 if (attacker is RatMob or attacker is BarataMob) else 0.15
		if randf() < bleed_chance:
			stats.apply_bleeding()
	hit_flash = 1.0
	queue_redraw()

func _on_died() -> void:
	GameManager.trigger_game_over()

func _on_item_equipped(item_id: String) -> void:
	queue_redraw()

## Eat a food item from the inventory: applies its restores (hunger/health/sanity) and
## consumes one. Returns false if it isn't food or the player doesn't have it.
func eat_item(item_id: String) -> bool:
	if not inventory.has_item(item_id):
		return false
	if not stats.eat(item_id):
		return false
	inventory.remove_item(item_id, 1)
	return true

func get_attack_damage() -> int:
	var equipped_id := inventory.get_equipped_item()
	var item_data = ItemDatabase.get_item(equipped_id) if equipped_id != "" else null
	if item_data and item_data.damage > 0:
		return item_data.damage
	return BASE_DAMAGE

func _draw() -> void:
	# Procedural body only when there is no sprite (fallback).
	if sprite == null:
		var base_color := Color(0.35, 0.55, 0.9)
		if hit_flash > 0.5:
			base_color = Color(1.0, 0.3, 0.3)
		elif is_dodging:
			base_color = Color(0.8, 0.9, 1.0, 0.7)

		# Legs (animated)
		var leg_offset := sin(walk_cycle) * 8.0 if velocity.length() > 20.0 else 0.0
		draw_circle(Vector2(-7, 16 + leg_offset), 5, Color(0.25, 0.35, 0.7))
		draw_circle(Vector2(7, 16 - leg_offset), 5, Color(0.25, 0.35, 0.7))

		# Body
		var body_rect := Rect2(-14, -12, 28, 28)
		draw_rect(body_rect, base_color)

		# Head
		draw_circle(Vector2(0, -20), 14, base_color)

		# Eyes showing facing direction
		var eye_offset := facing * 6.0 + Vector2(-4, -20)
		draw_circle(eye_offset, 3, Color.WHITE)
		draw_circle(eye_offset + Vector2(8, 0), 3, Color.WHITE)
		draw_circle(eye_offset + facing * 1.5, 1.5, Color(0.1, 0.1, 0.2))
		draw_circle(eye_offset + Vector2(8, 0) + facing * 1.5, 1.5, Color(0.1, 0.1, 0.2))

	# (Equipped tool/weapon is now a real Sprite2D overlay in the paw — see _update_axe.)

	# Attack arc
	if is_attacking:
		var attack_angle := atan2(facing.y, facing.x)
		draw_arc(Vector2.ZERO, ATTACK_RADIUS, attack_angle - 0.6, attack_angle + 0.6, 16, Color(1.0, 0.8, 0.2, 0.45), 8.0)

	# Direction arrow (fallback body only)
	if sprite == null:
		draw_line(Vector2.ZERO, facing * 22.0, Color(1, 1, 1, 0.3), 2.0)

	# Light radius indicator (torch)
	if has_torch_equipped:
		var item_data = ItemDatabase.get_item(inventory.get_equipped_item())
		if item_data:
			draw_arc(Vector2.ZERO, item_data.light_radius, 0, TAU, 32, Color(1.0, 0.9, 0.3, 0.08), 2.0)

	# Structure placement ghost: a grid-cell footprint at the snapped target (green=free, red=blocked).
	if _place_show:
		var g := _place_target - global_position
		var gc := Color(0.4, 0.9, 0.4) if _place_valid else Color(0.95, 0.35, 0.3)
		var rect := Rect2(g - Vector2(GRID * 0.5, GRID * 0.5), Vector2(GRID, GRID))
		draw_rect(rect, Color(gc.r, gc.g, gc.b, 0.22))
		draw_rect(rect, Color(gc.r, gc.g, gc.b, 0.85), false, 2.0)
