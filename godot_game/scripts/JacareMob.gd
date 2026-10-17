class_name JacareMob
extends BossMob

## Boss 2 — o Jacaré (missão "O Senhor da Caverna"). Something old and wrong living by the cave on
## Ilha de Itacuruçá — you need the raft just to MEET it. Slow, huge, bulldozes, keeps the DREAD
## aura, summons nothing: the fight is the animal itself. Unique drop: Escama do Jacaré — you learn
## to SWIM (water stops drowning you; the raft stays the fast option). A VERB, not a stat (GDD).

func _init() -> void:
	mob_name = "Jacaré"
	max_health = 950.0
	move_speed = 105.0
	attack_damage = 42.0
	attack_cooldown = 1.5
	attack_range = 55.0
	detection_range = 450.0
	body_color = Color(0.2, 0.42, 0.22)
	body_radius = 30.0
	drops = [
		{"item": "jacare_scale", "min": 1, "max": 1, "chance": 1.0},
		{"item": "meat", "min": 3, "max": 5, "chance": 1.0},
	]
	hunts_immediately = false

func _tick_summon(_delta: float) -> void:
	pass  # no adds

func _draw_mob(color: Color) -> void:
	var c := Color.WHITE if hit_flash > 0.3 else color
	# Long armored body + toothy snout + back ridges + dragging tail.
	draw_rect(Rect2(-body_radius * 1.4, -body_radius * 0.5, body_radius * 2.2, body_radius), c)
	draw_rect(Rect2(body_radius * 0.8, -body_radius * 0.35, body_radius * 1.1, body_radius * 0.7), c.darkened(0.1))
	for i in 4:
		draw_circle(Vector2(body_radius * (0.9 + i * 0.25), body_radius * 0.35), 2.0, Color(0.95, 0.95, 0.85))
	for i in 5:
		var rx := -body_radius * 1.2 + i * body_radius * 0.45
		draw_line(Vector2(rx, -body_radius * 0.5), Vector2(rx + 4.0, -body_radius * 0.85), c.darkened(0.3), 3.0)
	draw_line(Vector2(-body_radius * 1.4, 0), Vector2(-body_radius * 2.2, body_radius * 0.35), c, 8.0)
	var eye := Color(1.0, 0.4, 0.15) if _enraged else Color(1.0, 0.85, 0.2)
	draw_circle(Vector2(body_radius * 0.75, -body_radius * 0.55), 3.0, eye)
