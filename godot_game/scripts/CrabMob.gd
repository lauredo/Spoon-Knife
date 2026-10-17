class_name CrabMob
extends MobBase

## The island threat: a giant armored crab. The islands hold the best loot in the game and used
## to be completely safe once you owned the raft — a free shopping trip. Crabs make landfall an
## expedition: territorial (aggro on sight, tethered to their patch like WolfMob), slow but hard
## to bring down (the shell soaks 40% of every hit), and they pinch HARD. Looting AROUND them is
## the intended play — they give up when you leave their turf. Also the islands' chitin source:
## they drop Carapaça, so silk_armor has a second farm besides the baratas.

const SHELL_SOAK := 0.4  # fraction of incoming damage absorbed by the shell

var home_pos: Vector2 = Vector2.ZERO

func _init() -> void:
	mob_name = "Caranguejo Gigante"
	max_health = 140.0
	move_speed = 88.0
	attack_damage = 24.0
	attack_cooldown = 1.4
	attack_range = 46.0
	detection_range = 230.0
	body_color = Color(0.82, 0.34, 0.2)
	body_radius = 17.0
	drops = [
		{"item": "meat", "min": 1, "max": 2, "chance": 1.0},
		{"item": "silk", "min": 1, "max": 2, "chance": 0.7},
	]

func _ready() -> void:
	super._ready()
	if home_pos == Vector2.ZERO:
		home_pos = global_position

func _on_aggro(_p: Node) -> void:
	state = State.CHASE

func take_damage(amount: float, attacker: Node = null) -> void:
	super.take_damage(amount * (1.0 - SHELL_SOAK), attacker)

func _perform_attack() -> void:
	super._perform_attack()
	recover_timer = 0.8  # the claw resets — the escape window against a slow tank

func _set_wander_target() -> void:
	wander_target = home_pos + Vector2(randf_range(-130, 130), randf_range(-130, 130))

func _draw_mob(color: Color) -> void:
	var c := Color.WHITE if hit_flash > 0.3 else color
	# Legs (3 per side, angled down)
	var lc := c.darkened(0.3)
	for side in [-1.0, 1.0]:
		for i in 3:
			var bx: float = side * body_radius * 0.8
			var by: float = -4.0 + float(i) * 6.0
			draw_line(Vector2(bx, by), Vector2(bx + side * 12.0, by + 9.0), lc, 2.5)
	# Wide shell (flattened oval) + lighter dome
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.35, 1.0))
	draw_circle(Vector2.ZERO, body_radius, c)
	draw_circle(Vector2(0, -2), body_radius * 0.62, c.lightened(0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Big claws up front
	draw_circle(Vector2(-body_radius * 1.25, -body_radius * 0.75), 7.0, c.darkened(0.1))
	draw_circle(Vector2(body_radius * 1.25, -body_radius * 0.75), 7.0, c.darkened(0.1))
	draw_line(Vector2(-body_radius * 1.25, -body_radius * 1.1), Vector2(-body_radius * 1.05, -body_radius * 1.35), c.darkened(0.25), 3.0)
	draw_line(Vector2(body_radius * 1.25, -body_radius * 1.1), Vector2(body_radius * 1.05, -body_radius * 1.35), c.darkened(0.25), 3.0)
	# Eye stalks
	draw_line(Vector2(-4, -body_radius * 0.9), Vector2(-4, -body_radius * 1.35), lc, 2.0)
	draw_line(Vector2(4, -body_radius * 0.9), Vector2(4, -body_radius * 1.35), lc, 2.0)
	draw_circle(Vector2(-4, -body_radius * 1.4), 2.2, Color(0.15, 0.1, 0.08))
	draw_circle(Vector2(4, -body_radius * 1.4), 2.2, Color(0.15, 0.1, 0.08))
