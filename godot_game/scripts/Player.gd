class_name Player
extends CharacterBody2D

signal interaction_target_changed(target: Node)

const SPEED := 220.0
const DODGE_SPEED := 500.0
const DODGE_DURATION := 0.25
const DODGE_COOLDOWN := 1.2
const ATTACK_COOLDOWN := 0.5
const INTERACT_RADIUS := 80.0
const ATTACK_RADIUS := 65.0
const BASE_DAMAGE := 20

var stats: PlayerStats
var inventory: Inventory
var facing := Vector2.DOWN
var is_attacking := false
var is_dodging := false
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

var sprite: AnimatedSprite2D = null

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

	# Pickup area
	var pickup_area := Area2D.new()
	pickup_area.name = "PickupArea"
	var pickup_col := CollisionShape2D.new()
	var pickup_shape := CircleShape2D.new()
	pickup_shape.radius = 40.0
	pickup_col.shape = pickup_shape
	pickup_area.add_child(pickup_col)
	pickup_area.collision_layer = 0
	pickup_area.collision_mask = 16  # dropped items layer
	add_child(pickup_area)
	pickup_area.body_entered.connect(_on_pickup_area_entered)

	# Detection area for interactables
	var interact_area := Area2D.new()
	interact_area.name = "InteractArea"
	var interact_col := CollisionShape2D.new()
	var interact_shape := CircleShape2D.new()
	interact_shape.radius = INTERACT_RADIUS
	interact_col.shape = interact_shape
	interact_area.add_child(interact_col)
	interact_area.collision_layer = 0
	interact_area.collision_mask = 8 | 32  # resources + structures
	add_child(interact_area)
	interact_area.body_entered.connect(_on_interactable_entered)
	interact_area.body_exited.connect(_on_interactable_exited)

	collision_layer = 2
	collision_mask = 1 | 4 | 32

	GameManager.register_player(self)
	stats.died.connect(_on_died)
	inventory.item_equipped.connect(_on_item_equipped)
	_setup_sprite()

func _setup_sprite() -> void:
	var sf := Assets.sprite_frames("player", [
		{"anim": "idle", "count": 1, "fps": 4.0, "loop": true},
		{"anim": "walk", "count": 2, "fps": 9.0, "loop": true},
		{"anim": "attack", "count": 1, "fps": 10.0, "loop": false},
	])
	if sf == null:
		return
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = sf
	sprite.animation = "idle"
	sprite.show_behind_parent = true  # keep equipped item / attack arc on top
	var tex := sf.get_frame_texture("idle", 0)
	var s := 56.0 / float(tex.get_height())
	sprite.scale = Vector2(s, s)
	add_child(sprite)
	sprite.play("idle")

func _update_sprite() -> void:
	if sprite == null:
		return
	if is_attacking:
		if sprite.animation != "attack":
			sprite.play("attack")
	elif velocity.length() > 10.0:
		if sprite.animation != "walk":
			sprite.play("walk")
	else:
		if sprite.animation != "idle":
			sprite.play("idle")
	if absf(facing.x) > 0.1:
		sprite.flip_h = facing.x < 0.0
	if hit_flash > 0.5:
		sprite.modulate = Color(1.8, 1.8, 1.8)
	elif is_dodging:
		sprite.modulate = Color(0.85, 0.92, 1.0, 0.7)
	else:
		sprite.modulate = Color.WHITE

func _physics_process(delta: float) -> void:
	_handle_timers(delta)
	_handle_input(delta)
	_handle_movement(delta)
	_check_light()
	_update_sprite()
	queue_redraw()

func _handle_timers(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta
	if dodge_cooldown > 0.0:
		dodge_cooldown -= delta
	if hit_flash > 0.0:
		hit_flash -= delta * 4.0
	if is_dodging:
		dodge_timer -= delta
		if dodge_timer <= 0.0:
			is_dodging = false
			stats.invincible = false

func _handle_input(delta: float) -> void:
	if Input.is_action_just_pressed("attack") and attack_timer <= 0.0 and not is_dodging:
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
	elif input_dir.length() > 0.1:
		facing = input_dir.normalized()
		velocity = input_dir.normalized() * SPEED
		walk_cycle += delta * 8.0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED * 4.0 * delta)

	move_and_slide()

func _start_dodge() -> void:
	is_dodging = true
	stats.invincible = true
	dodge_timer = DODGE_DURATION
	dodge_cooldown = DODGE_COOLDOWN

func _perform_attack() -> void:
	attack_timer = ATTACK_COOLDOWN
	is_attacking = true

	var equipped_id := inventory.get_equipped_item()
	var item_data = ItemDatabase.get_item(equipped_id) if equipped_id != "" else null
	var damage := BASE_DAMAGE
	if item_data and (item_data.type == ItemDatabase.ItemType.WEAPON or item_data.type == ItemDatabase.ItemType.TOOL):
		damage = item_data.damage if item_data.damage > 0 else BASE_DAMAGE

	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = ATTACK_RADIUS
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + facing * 40.0)
	query.collision_mask = 4  # mobs only

	var results := space.intersect_shape(query, 8)
	for res in results:
		if res.collider.has_method("take_damage"):
			res.collider.take_damage(damage, self)
			if item_data and item_data.durability > 0:
				inventory.use_durability(equipped_id, 1)

	await get_tree().create_timer(0.18).timeout
	is_attacking = false
	queue_redraw()

func _try_interact() -> void:
	if nearby_interactables.is_empty():
		return
	# Find closest interactable
	var closest: Node = null
	var closest_dist := INF
	for obj in nearby_interactables:
		if is_instance_valid(obj):
			var d := global_position.distance_to(obj.global_position)
			if d < closest_dist:
				closest_dist = d
				closest = obj
	if closest and closest.has_method("interact"):
		closest.interact(self)

func _on_pickup_area_entered(body: Node) -> void:
	if body.has_method("pickup"):
		body.pickup(self)

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
		if item_data and item_data.is_light_source:
			has_torch_equipped = true
	stats.set_in_light(near_light or has_torch_equipped)

func set_near_light(value: bool) -> void:
	near_light = value

func take_damage(amount: float, attacker: Node = null) -> void:
	stats.take_damage(amount)
	hit_flash = 1.0
	queue_redraw()

func _on_died() -> void:
	GameManager.trigger_game_over()

func _on_item_equipped(item_id: String) -> void:
	queue_redraw()

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

	# Equipped item indicator
	var equipped_id := inventory.get_equipped_item()
	if equipped_id != "":
		var hand_pos := facing * 22.0 + Vector2(14, 0).rotated(atan2(facing.y, facing.x))
		var icon := Assets.item_icon(equipped_id)
		if icon:
			var sz := Vector2(20, 20)
			draw_texture_rect(icon, Rect2(hand_pos - sz * 0.5, sz), false)
		else:
			var item_data = ItemDatabase.get_item(equipped_id)
			if item_data:
				draw_circle(hand_pos, 6, item_data.color)

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
