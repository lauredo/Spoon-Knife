class_name HumanNPC
extends MobBase

## The city's owners (GDD S2b — stealth v0). Humans patrol the LIVING districts by day. They see
## through a directional VISION CONE (drawn on the ground so stealth is readable), and line of
## sight is physical: walls, trees and fences' buildings block it — hiding works. Searching a
## container makes NOISE they come to investigate. Spotted, they chase and swat; badly hurt, they
## flee. At dusk they go home — the night belongs to the animals (and is your burglary window).

const VISION_RANGE := 260.0
const VISION_HALF_ANGLE := 0.873   # ~50° each side (100° cone)
const HEAR_RANGE := 70.0           # this close they notice you no matter where they face
const LOSE_SIGHT_TIME := 2.5
const INVESTIGATE_LINGER := 2.0
const NOISE_RANGE := 420.0         # how far a container search carries

var home_pos: Vector2 = Vector2.ZERO
var shirt_col: Color = Color(0.35, 0.5, 0.7)
var _facing: Vector2 = Vector2.DOWN
var _sleeping: bool = false
var _lost_timer: float = 0.0

func _init() -> void:
	mob_name = "Humano"
	max_health = 150.0
	move_speed = 165.0     # slower than a sprinting raccoon — getting caught means getting cornered
	attack_damage = 22.0
	attack_cooldown = 1.4
	attack_range = 42.0
	detection_range = 300.0  # Area2D = candidate radius only; the CONE decides
	body_radius = 13.0
	flee_health_pct = 0.0    # flee handled in take_damage (threshold below)
	drops = [
		{"item": "shiny_thing", "min": 1, "max": 1, "chance": 0.3},
		{"item": "cloth", "min": 1, "max": 2, "chance": 0.4},
	]

func _ready() -> void:
	super._ready()
	if home_pos == Vector2.ZERO:
		home_pos = global_position

## Proximity never aggros a human — only the vision cone / noise do.
func _on_aggro(_p: Node) -> void:
	pass

func take_damage(amount: float, attacker: Node = null) -> void:
	super.take_damage(amount, attacker)
	if is_dead:
		return
	if health < max_health * 0.35:
		state = State.FLEE
		state_timer = 4.0
	elif attacker is Player:
		target = attacker
		state = State.CHASE
		_lost_timer = 0.0

## A noise (container search) pulls idle humans to investigate the spot.
func hear_noise(pos: Vector2) -> void:
	if is_dead or _sleeping or state == State.CHASE or state == State.ATTACK or state == State.FLEE:
		return
	last_known_target_pos = pos
	target = null
	state = State.ALERT
	_facing = (pos - global_position).normalized()

func _physics_process(delta: float) -> void:
	var day := _is_daytime()
	if _sleeping == day:
		_set_sleeping(not day)
	if _sleeping:
		return
	if velocity.length() > 5.0:
		_facing = velocity.normalized()
	super._physics_process(delta)

func _is_daytime() -> bool:
	var p = GameManager.player
	return p != null and is_instance_valid(p) and p.stats != null and p.stats.is_day

## "Going home": frozen, invisible and intangible until dawn. Wakes back at its home spot.
func _set_sleeping(v: bool) -> void:
	_sleeping = v
	visible = not v
	collision_layer = 0 if v else 4
	if v:
		velocity = Vector2.ZERO
		state = State.IDLE
		global_position = home_pos

## Full custom state machine (cone-based stealth) — movement itself is reused from MobBase.
func _update_state(delta: float) -> void:
	move_speed = 165.0 * (1.0 + 0.2 * GameManager.heat_factor())  # heat: up to +20% speed
	var p = GameManager.player
	var sees: bool = p != null and is_instance_valid(p) and not GameManager.is_game_over and _can_see(p)
	match state:
		State.IDLE:
			if sees:
				_spot(p)
			elif state_timer <= 0.0:
				if randf() < 0.5:
					state = State.WANDER
					_set_wander_target()
				state_timer = randf_range(1.5, 4.0)
		State.WANDER:
			if sees:
				_spot(p)
			elif global_position.distance_to(wander_target) < 15.0:
				state = State.IDLE
				state_timer = randf_range(1.0, 3.0)
		State.ALERT:
			if sees:
				_spot(p)
			elif global_position.distance_to(last_known_target_pos) < 34.0:
				state = State.IDLE               # arrived at the noise: look around, give up
				state_timer = INVESTIGATE_LINGER
		State.CHASE:
			if not is_instance_valid(target):
				state = State.IDLE
				return
			if sees:
				_lost_timer = 0.0
				last_known_target_pos = target.global_position
			else:
				_lost_timer += delta
				if _lost_timer > LOSE_SIGHT_TIME:
					target = null
					state = State.ALERT          # poke at the last place it saw you
					return
			if global_position.distance_to(target.global_position) <= attack_range:
				state = State.ATTACK
		State.ATTACK:
			if not is_instance_valid(target):
				state = State.IDLE
				return
			if global_position.distance_to(target.global_position) > attack_range * 1.3:
				state = State.CHASE
			elif attack_timer <= 0.0:
				_perform_attack()
		State.FLEE:
			if state_timer <= 0.0:
				state = State.IDLE

func _spot(p: Node) -> void:
	target = p
	state = State.CHASE
	_lost_timer = 0.0
	GameManager.add_heat(GameManager.HEAT_PER_SPOT)  # every fresh sighting feeds the manhunt

## Heat sharpens the town: up to +25% vision and +20% speed at full vigilância. The drawn cone
## uses the SAME value, so the buff stays readable on the ground (fun>realism).
func _vision_range() -> float:
	return VISION_RANGE * (1.0 + 0.25 * GameManager.heat_factor())

## Cone + physical line of sight: walls/trees/rocks (World layer) block the ray.
func _can_see(p: Node) -> bool:
	var to: Vector2 = p.global_position - global_position
	var dist := to.length()
	if dist > _vision_range():
		return false
	if dist > HEAR_RANGE and absf(_facing.angle_to(to / dist)) > VISION_HALF_ANGLE:
		return false
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, p.global_position, 1)
	return space.intersect_ray(q).is_empty()

func _perform_attack() -> void:
	super._perform_attack()
	recover_timer = 0.6  # the swat has a wind-down — an escape window (see MobBase)

func _set_wander_target() -> void:
	wander_target = home_pos + Vector2(randf_range(-170, 170), randf_range(-170, 170))

func _draw_mob(_color: Color) -> void:
	# Vision cone on the ground — stealth must be READABLE (fun > realism).
	var alerted := state == State.CHASE or state == State.ATTACK
	var ccol := Color(1.0, 0.35, 0.25, 0.14) if alerted \
		else (Color(1.0, 0.85, 0.3, 0.10) if state == State.ALERT else Color(1.0, 1.0, 0.85, 0.06))
	var pts := PackedVector2Array([Vector2.ZERO])
	var base_a := _facing.angle()
	for i in 13:
		var a := base_a - VISION_HALF_ANGLE + VISION_HALF_ANGLE * 2.0 * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * _vision_range())
	draw_colored_polygon(pts, ccol)

	# The human: legs, shirt, head, hair. Tall next to a raccoon.
	var c := Color.WHITE if hit_flash > 0.3 else shirt_col
	draw_rect(Rect2(-7, -6, 5, 14), Color(0.25, 0.25, 0.3))
	draw_rect(Rect2(2, -6, 5, 14), Color(0.25, 0.25, 0.3))
	draw_rect(Rect2(-9, -26, 18, 22), c)
	draw_rect(Rect2(-9, -26, 18, 22), c.darkened(0.3), false, 1.5)
	draw_circle(Vector2(0, -33), 8.0, Color(0.9, 0.72, 0.58))
	draw_rect(Rect2(-8, -43, 16, 7), Color(0.25, 0.18, 0.12))
	# Reaction bubble: "!" chasing, "?" investigating.
	if alerted or state == State.ALERT:
		var font := ThemeDB.fallback_font
		var mark := "!" if alerted else "?"
		var mcol := Color(1.0, 0.3, 0.2) if alerted else Color(1.0, 0.85, 0.3)
		draw_string(font, Vector2(-4, -50), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, mcol)
