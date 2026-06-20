class_name MobBase
extends CharacterBody2D

signal died(mob: MobBase)

enum State { IDLE, WANDER, ALERT, CHASE, ATTACK, FLEE, DEAD }

# Override in subclasses
var mob_name: String = "Mob"
var max_health: float = 100.0
var move_speed: float = 80.0
var attack_damage: float = 10.0
var attack_cooldown: float = 1.5
var attack_range: float = 40.0
var detection_range: float = 200.0
var flee_health_pct: float = 0.0  # 0 = never flee
var body_color: Color = Color(0.6, 0.2, 0.8)
var body_radius: float = 18.0
var drops: Array = []  # [{item_id, min_amount, max_amount}]
var xp_value: int = 10

var health: float = 100.0
var state: State = State.IDLE
var target: Node = null
var last_known_target_pos: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var attack_timer: float = 0.0
var hit_flash: float = 0.0
var wander_timer: float = 0.0
var is_dead: bool = false

func _ready() -> void:
	health = max_health
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 32

	# Collision body
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = body_radius
	col.shape = shape
	add_child(col)

	# Detection area
	var detect_area := Area2D.new()
	detect_area.name = "DetectionArea"
	var detect_col := CollisionShape2D.new()
	var detect_shape := CircleShape2D.new()
	detect_shape.radius = detection_range
	detect_col.shape = detect_shape
	detect_area.add_child(detect_col)
	detect_area.collision_layer = 0
	detect_area.collision_mask = 2  # player layer
	add_child(detect_area)
	detect_area.body_entered.connect(_on_player_detected)
	detect_area.body_exited.connect(_on_player_lost)

	_set_wander_target()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_update_timers(delta)
	_update_state(delta)
	_process_movement(delta)
	queue_redraw()

func _update_timers(delta: float) -> void:
	state_timer -= delta
	attack_timer -= delta
	hit_flash = max(0.0, hit_flash - delta * 3.0)
	wander_timer -= delta

func _update_state(delta: float) -> void:
	match state:
		State.IDLE:
			if state_timer <= 0.0:
				if randf() < 0.4:
					state = State.WANDER
					_set_wander_target()
				state_timer = randf_range(1.5, 4.0)

		State.WANDER:
			if global_position.distance_to(wander_target) < 15.0:
				state = State.IDLE
				state_timer = randf_range(1.0, 3.0)

		State.ALERT, State.CHASE:
			if not is_instance_valid(target):
				state = State.IDLE
				return
			var dist := global_position.distance_to(target.global_position)
			last_known_target_pos = target.global_position
			if dist <= attack_range:
				state = State.ATTACK
			elif dist > detection_range * 1.5:
				state = State.IDLE
				target = null

		State.ATTACK:
			if not is_instance_valid(target):
				state = State.IDLE
				return
			var dist := global_position.distance_to(target.global_position)
			if dist > attack_range * 1.3:
				state = State.CHASE
			elif attack_timer <= 0.0:
				_perform_attack()
				# Flee check
				if flee_health_pct > 0 and health / max_health <= flee_health_pct:
					state = State.FLEE
					state_timer = 5.0

		State.FLEE:
			if state_timer <= 0.0:
				state = State.IDLE

func _process_movement(delta: float) -> void:
	var move_dir := Vector2.ZERO

	match state:
		State.WANDER:
			move_dir = (wander_target - global_position).normalized()
			if global_position.distance_to(wander_target) < 15.0:
				velocity = Vector2.ZERO
				return
		State.ALERT, State.CHASE:
			if is_instance_valid(target):
				move_dir = (target.global_position - global_position).normalized()
			else:
				move_dir = (last_known_target_pos - global_position).normalized()
		State.ATTACK:
			# Slight movement toward target during attack
			if is_instance_valid(target):
				var dist := global_position.distance_to(target.global_position)
				if dist > attack_range * 0.7:
					move_dir = (target.global_position - global_position).normalized()
		State.FLEE:
			if is_instance_valid(target):
				move_dir = -(target.global_position - global_position).normalized()
			else:
				move_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, move_speed * 3.0 * delta)
			move_and_slide()
			return

	velocity = move_dir * move_speed
	move_and_slide()

func _perform_attack() -> void:
	attack_timer = attack_cooldown
	if is_instance_valid(target) and target.has_method("take_damage"):
		var dist := global_position.distance_to(target.global_position)
		if dist <= attack_range:
			target.take_damage(attack_damage, self)

func _set_wander_target() -> void:
	wander_target = global_position + Vector2(randf_range(-120, 120), randf_range(-120, 120))

func _on_player_detected(body: Node) -> void:
	if body is Player and not is_dead:
		target = body
		_on_aggro(body)

func _on_player_lost(body: Node) -> void:
	if body == target:
		state_timer = 5.0  # Keep chasing for a bit

func _on_aggro(player: Node) -> void:
	# Override for different mob behaviors
	state = State.CHASE

func take_damage(amount: float, attacker: Node = null) -> void:
	if is_dead:
		return
	health -= amount
	hit_flash = 1.0
	queue_redraw()
	if attacker is Player:
		target = attacker
		if state == State.IDLE or state == State.WANDER:
			_on_aggro(attacker)
	if health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	state = State.DEAD
	velocity = Vector2.ZERO
	_spawn_drops()
	died.emit(self)
	await get_tree().create_timer(0.3).timeout
	queue_free()

func _spawn_drops() -> void:
	for drop_info in drops:
		var amount := randi_range(drop_info.get("min", 1), drop_info.get("max", 1))
		if randf() <= drop_info.get("chance", 1.0):
			GameManager.spawn_drop(global_position, drop_info["item"], amount)

func _draw() -> void:
	if is_dead:
		return
	var color := body_color
	if hit_flash > 0.3:
		color = Color.WHITE

	_draw_mob(color)

	# Health bar
	var hp_pct := health / max_health
	var bar_w := body_radius * 2.2
	draw_rect(Rect2(-bar_w * 0.5, -body_radius - 12, bar_w, 5), Color(0.2, 0.1, 0.1))
	draw_rect(Rect2(-bar_w * 0.5, -body_radius - 12, bar_w * hp_pct, 5), Color.lerp(Color.RED, Color.GREEN, hp_pct))

	# State indicator for debugging (small dot)
	if state == State.CHASE or state == State.ATTACK:
		draw_circle(Vector2(0, -body_radius - 20), 4, Color.RED)

func _draw_mob(color: Color) -> void:
	# Override in subclasses for custom appearance
	draw_circle(Vector2.ZERO, body_radius, color)
