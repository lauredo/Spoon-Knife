class_name BoarMob
extends MobBase

var was_attacked: bool = false
var charge_speed: float = 220.0
var is_charging: bool = false
var charge_timer: float = 0.0
var tusk_wobble: float = 0.0

func _ready() -> void:
	mob_name = "Boar"
	max_health = 250.0
	move_speed = 70.0
	attack_damage = 30.0
	attack_cooldown = 2.5
	attack_range = 50.0
	detection_range = 100.0  # Passive until attacked
	flee_health_pct = 0.0
	body_color = Color(0.5, 0.32, 0.18)
	body_radius = 22.0
	drops = [
		{"item": "meat", "min": 2, "max": 4, "chance": 1.0},
		{"item": "seeds", "min": 1, "max": 3, "chance": 0.7},
	]
	super._ready()

func _on_aggro(player: Node) -> void:
	# Boar only aggros when attacked
	if was_attacked:
		state = State.CHASE
	# Otherwise stays neutral

func take_damage(amount: float, attacker: Node = null) -> void:
	was_attacked = true
	super.take_damage(amount, attacker)
	# Start charge after being hit
	if not is_charging and is_instance_valid(target) and randf() < 0.5:
		_start_charge()

func _start_charge() -> void:
	is_charging = true
	charge_timer = 0.6
	var prev_speed := move_speed
	move_speed = charge_speed
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(self) and not is_dead:
		move_speed = prev_speed
		is_charging = false

func _physics_process(delta: float) -> void:
	tusk_wobble = sin(Time.get_ticks_msec() * 0.005) * 3.0
	super._physics_process(delta)

func _draw_mob(color: Color) -> void:
	# Body
	draw_rect(Rect2(-body_radius, -body_radius * 0.7, body_radius * 2, body_radius * 1.4), color)

	# Head
	var head_color := color.darkened(0.1)
	draw_rect(Rect2(-body_radius * 0.65, -body_radius - 12, body_radius * 1.3, 18), head_color)

	# Snout
	draw_circle(Vector2(0, -body_radius - 14), 8, color.darkened(0.2))

	# Tusks (wobble when walking)
	var tusk_col := Color(0.95, 0.95, 0.85)
	draw_line(Vector2(-8, -body_radius - 14 + tusk_wobble * 0.5),
			  Vector2(-14, -body_radius - 22 + tusk_wobble), tusk_col, 4.0)
	draw_line(Vector2(8, -body_radius - 14 - tusk_wobble * 0.5),
			  Vector2(14, -body_radius - 22 - tusk_wobble), tusk_col, 4.0)

	# Eyes
	draw_circle(Vector2(-5, -body_radius - 6), 3, Color(0.15, 0.1, 0.05))
	draw_circle(Vector2(5, -body_radius - 6), 3, Color(0.15, 0.1, 0.05))

	# Legs
	var leg_col := color.darkened(0.2)
	draw_rect(Rect2(-body_radius - 4, body_radius * 0.1, 8, 14), leg_col)
	draw_rect(Rect2(body_radius - 4, body_radius * 0.1, 8, 14), leg_col)
	draw_rect(Rect2(-body_radius * 0.5 - 4, body_radius * 0.3, 8, 14), leg_col)
	draw_rect(Rect2(body_radius * 0.5 - 4, body_radius * 0.3, 8, 14), leg_col)

	# Charge effect
	if is_charging:
		draw_circle(Vector2.ZERO, body_radius + 5, Color(1.0, 0.5, 0.1, 0.3))
