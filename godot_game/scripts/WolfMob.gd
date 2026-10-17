class_name WolfMob
extends MobBase

## Territorial predator of the dark forest. Aggros on SIGHT (unlike the passive boar) and is fast,
## but slower than a sprinting player, so it's escapable. Wanders tethered to its den and gives up
## the chase when you leave its turf. Drops meat (+ sometimes monster meat).

var home_pos: Vector2 = Vector2.ZERO

func _init() -> void:
	mob_name = "Cão de Rua"
	max_health = 120.0
	move_speed = 138.0
	attack_damage = 18.0
	attack_cooldown = 1.2
	attack_range = 42.0
	detection_range = 270.0
	body_color = Color(0.4, 0.4, 0.46)
	body_radius = 16.0
	drops = [
		{"item": "meat", "min": 1, "max": 2, "chance": 1.0},
		{"item": "monster_meat", "min": 0, "max": 1, "chance": 0.5},
	]

func _ready() -> void:
	super._ready()
	if home_pos == Vector2.ZERO:
		home_pos = global_position

## Wearing the Alfa's collar? You smell like the pack leader — dogs won't start a fight (boss
## relic VERB). Hitting one still makes it fight back (MobBase.take_damage aggros directly).
func _on_aggro(_p: Node) -> void:
	var pl = GameManager.player
	if pl and is_instance_valid(pl) and pl.inventory and pl.inventory.has_item("alfa_collar"):
		return
	state = State.CHASE

func _perform_attack() -> void:
	super._perform_attack()
	recover_timer = 0.7  # brief lunge recovery so it isn't an inescapable glue (see MobBase)

func _set_wander_target() -> void:
	wander_target = home_pos + Vector2(randf_range(-150, 150), randf_range(-150, 150))

func _draw_mob(color: Color) -> void:
	var c := Color.WHITE if hit_flash > 0.3 else color
	draw_rect(Rect2(-body_radius, -body_radius * 0.5, body_radius * 2.0, body_radius * 0.9), c)
	draw_circle(Vector2(body_radius * 0.8, -body_radius * 0.3), 8.0, c.darkened(0.05))                 # head
	draw_rect(Rect2(body_radius * 0.8, -body_radius * 0.35, 12, 5), c.darkened(0.15))                  # snout
	draw_line(Vector2(body_radius * 0.55, -body_radius * 0.9), Vector2(body_radius * 0.45, -body_radius * 1.4), c, 3.0)  # ear
	draw_line(Vector2(body_radius * 1.05, -body_radius * 0.9), Vector2(body_radius * 1.15, -body_radius * 1.4), c, 3.0)  # ear
	draw_circle(Vector2(body_radius * 0.95, -body_radius * 0.4), 1.9, Color(0.9, 0.2, 0.1))            # red eye
	var lc := c.darkened(0.25)
	draw_rect(Rect2(-body_radius + 2, body_radius * 0.35, 4, 13), lc)
	draw_rect(Rect2(body_radius - 8, body_radius * 0.35, 4, 13), lc)
	draw_line(Vector2(-body_radius, -body_radius * 0.1), Vector2(-body_radius - 11, -body_radius * 0.6), c, 4.0)  # tail
