class_name RatMob
extends MobBase

## The first INTERIOR threat (GDD: buildings must not be free hideouts). A small, fast, weak vermin
## that nests inside city buildings and defends its patch. Tethered to its nest, so it stays indoors
## — and since walls block it (straight-line AI), a fight in a room is close and nasty.

var home_pos: Vector2 = Vector2.ZERO

func _init() -> void:
	mob_name = "Rato"
	max_health = 25.0
	move_speed = 150.0
	attack_damage = 6.0
	attack_cooldown = 0.9
	attack_range = 26.0
	detection_range = 170.0
	body_color = Color(0.42, 0.4, 0.42)
	body_radius = 8.0
	drops = [
		{"item": "meat", "min": 0, "max": 1, "chance": 0.4},
		{"item": "cloth", "min": 0, "max": 1, "chance": 0.25},
	]

func _ready() -> void:
	super._ready()
	if home_pos == Vector2.ZERO:
		home_pos = global_position

func _perform_attack() -> void:
	super._perform_attack()
	recover_timer = 0.4  # tiny nip-and-retreat beat

func _set_wander_target() -> void:
	wander_target = home_pos + Vector2(randf_range(-80, 80), randf_range(-80, 80))

func _draw_mob(color: Color) -> void:
	var c := Color.WHITE if hit_flash > 0.3 else color
	# Low body + head + snout
	draw_circle(Vector2(0, 0), body_radius, c)
	draw_circle(Vector2(body_radius * 0.9, -2), 5.0, c.lightened(0.06))
	draw_circle(Vector2(body_radius * 1.5, -1), 2.4, Color(0.75, 0.6, 0.6))
	# Ears + red eyes
	draw_circle(Vector2(body_radius * 0.5, -6), 2.6, c.darkened(0.1))
	draw_circle(Vector2(body_radius * 1.1, -6), 2.6, c.darkened(0.1))
	draw_circle(Vector2(body_radius * 0.95, -3), 1.1, Color(0.9, 0.25, 0.2))
	# Naked tail
	draw_line(Vector2(-body_radius, 1), Vector2(-body_radius - 11, -3), Color(0.72, 0.58, 0.58), 2.0)
