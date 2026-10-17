class_name DeerMob
extends MobBase

## Peaceful herd animal. Never attacks — it BOLTS the moment you get close or hit it, so hunting one
## is a chase. Drops meat. Roams as a loose herd tethered to where it spawned.

var home_pos: Vector2 = Vector2.ZERO

func _init() -> void:
	mob_name = "Veado"
	max_health = 60.0
	move_speed = 135.0            # sprints away fast
	attack_damage = 0.0
	attack_range = 0.0
	detection_range = 175.0       # spots you at medium range and flees
	body_color = Color(0.62, 0.44, 0.26)
	body_radius = 15.0
	drops = [{"item": "meat", "min": 2, "max": 3, "chance": 1.0}]

func _ready() -> void:
	super._ready()
	if home_pos == Vector2.ZERO:
		home_pos = global_position

func _on_aggro(_p: Node) -> void:
	state = State.FLEE
	state_timer = 3.5

func take_damage(amount: float, attacker: Node = null) -> void:
	super.take_damage(amount, attacker)
	if not is_dead:
		state = State.FLEE
		state_timer = 3.5

func _set_wander_target() -> void:
	wander_target = home_pos + Vector2(randf_range(-170, 170), randf_range(-170, 170))

func _draw_mob(color: Color) -> void:
	var c := Color.WHITE if hit_flash > 0.3 else color
	draw_rect(Rect2(-body_radius, -body_radius * 0.5, body_radius * 2.0, body_radius), c)
	draw_line(Vector2(body_radius * 0.7, -body_radius * 0.3), Vector2(body_radius + 7, -body_radius - 8), c, 5.0)  # neck
	draw_circle(Vector2(body_radius + 9, -body_radius - 9), 6.0, c.darkened(0.05))                                 # head
	draw_line(Vector2(body_radius + 9, -body_radius - 13), Vector2(body_radius + 4, -body_radius - 24), Color(0.5, 0.36, 0.2), 2.0)   # antler
	draw_line(Vector2(body_radius + 9, -body_radius - 13), Vector2(body_radius + 15, -body_radius - 24), Color(0.5, 0.36, 0.2), 2.0)  # antler
	var lc := c.darkened(0.2)
	draw_rect(Rect2(-body_radius + 2, body_radius * 0.4, 4, 13), lc)
	draw_rect(Rect2(body_radius - 6, body_radius * 0.4, 4, 13), lc)
	draw_circle(Vector2(-body_radius - 2, -body_radius * 0.1), 3.0, Color.WHITE)  # tail
