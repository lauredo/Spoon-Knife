class_name BossMob
extends MobBase

## The day-3 boss (MVP climax). Big, tanky melee hunter. Defeating it triggers the victory
## screen. Procedural placeholder art (dark horned brute + glowing eyes), no asset needed yet.

func _init() -> void:
	mob_name = "Boss"
	max_health = 350.0
	move_speed = 95.0
	attack_damage = 20.0
	attack_cooldown = 1.4
	attack_range = 48.0
	detection_range = 2000.0  # always hunts the player
	body_color = Color(0.35, 0.05, 0.12)
	body_radius = 34.0
	drops = [{"item": "monster_meat", "min": 2, "max": 4, "chance": 1.0}]
	xp_value = 100

func _ready() -> void:
	super._ready()
	if GameManager.player and is_instance_valid(GameManager.player):
		target = GameManager.player
		state = State.CHASE

func _draw_mob(color: Color) -> void:
	var flash := hit_flash > 0.3
	# Hulking dark body.
	draw_circle(Vector2.ZERO, body_radius, Color(0.16, 0.03, 0.07) if not flash else Color.WHITE)
	draw_circle(Vector2(0, -3), body_radius * 0.8, Color(0.3, 0.06, 0.14) if not flash else Color(1, 1, 1, 0.8))
	# Horns.
	draw_line(Vector2(-16, -24), Vector2(-26, -44), Color(0.08, 0.08, 0.1), 6.0)
	draw_line(Vector2(16, -24), Vector2(26, -44), Color(0.08, 0.08, 0.1), 6.0)
	# Glowing eyes.
	var eye := Color(1.0, 0.35, 0.1)
	draw_circle(Vector2(-11, -6), 5.0, eye)
	draw_circle(Vector2(11, -6), 5.0, eye)
	draw_circle(Vector2(-11, -6), 2.0, Color(1, 1, 0.6))
	draw_circle(Vector2(11, -6), 2.0, Color(1, 1, 0.6))
