class_name ColonyRaccoon
extends MobBase

## A peaceful little raccoon of the colony that potters around its camp. Never attacks and never
## targets the player; if struck it just bolts for a moment. Drops nothing — hurting the colony
## earns nothing.

var home_pos: Vector2 = Vector2.ZERO

func _init() -> void:
	mob_name = "Guaxinim"
	max_health = 40.0
	move_speed = 55.0
	attack_damage = 0.0
	attack_range = 0.0
	detection_range = 1.0  # effectively blind — never acquires the player as a target
	body_color = Color(0.55, 0.53, 0.58)
	body_radius = 10.0
	drops = []

func _ready() -> void:
	super._ready()
	if home_pos == Vector2.ZERO:
		home_pos = global_position

## Aggro for a colony raccoon means PANIC, not fight.
func _on_aggro(_player: Node) -> void:
	state = State.FLEE
	state_timer = 3.0

func take_damage(amount: float, attacker: Node = null) -> void:
	super.take_damage(amount, attacker)
	if attacker is Player:
		GameManager.add_reputation(GameManager.REP_HURT_RACCOON)  # the colony SEES this
	if not is_dead:
		state = State.FLEE
		state_timer = 3.0

## Wander stays tethered to the camp instead of drifting across the world.
func _set_wander_target() -> void:
	wander_target = home_pos + Vector2(randf_range(-110, 110), randf_range(-110, 110))

func _draw_mob(color: Color) -> void:
	# Little raccoon: ringed tail, round body, masked face, small round ears.
	var dark := Color(0.2, 0.18, 0.22)
	# Ringed tail behind the body (alternating rings)
	draw_circle(Vector2(-9, 9), 4.0, dark)
	draw_circle(Vector2(-5, 10), 4.0, color.darkened(0.1))
	draw_circle(Vector2(-1, 11), 3.5, dark)
	# Body + head
	draw_circle(Vector2(0, 2), body_radius, color)
	draw_circle(Vector2(0, -8), body_radius * 0.75, color.lightened(0.12))
	# Small round ears
	draw_circle(Vector2(-5, -14), 2.6, color.darkened(0.15))
	draw_circle(Vector2(5, -14), 2.6, color.darkened(0.15))
	# Eye mask band + eyes
	draw_rect(Rect2(-7, -11, 14, 4), dark)
	draw_circle(Vector2(-3, -9), 1.2, Color(0.95, 0.95, 0.95))
	draw_circle(Vector2(3, -9), 1.2, Color(0.95, 0.95, 0.95))
	# Pale muzzle + nose
	draw_circle(Vector2(0, -5.5), 2.4, color.lightened(0.35))
	draw_circle(Vector2(0, -6.5), 1.0, dark)
