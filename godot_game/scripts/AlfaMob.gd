class_name AlfaMob
extends BossMob

## Boss 1 — o Cachorro Alfa (missão "A Matilha"). Rules the west end of the village road from his
## den. A flesh-and-blood brawler: fast, enrages, calls his PACK (stray dogs) instead of shadows,
## and has NO dread aura. Unique drop: Colar do Alfa — dogs stop aggroing you (you smell like the
## leader). A VERB, not a stat (GDD).

func _init() -> void:
	mob_name = "Cachorro Alfa"
	max_health = 600.0
	move_speed = 150.0
	attack_damage = 28.0
	attack_cooldown = 1.1
	attack_range = 48.0
	detection_range = 480.0
	body_color = Color(0.45, 0.36, 0.28)
	body_radius = 26.0
	drops = [
		{"item": "alfa_collar", "min": 1, "max": 1, "chance": 1.0},
		{"item": "meat", "min": 2, "max": 3, "chance": 1.0},
	]
	hunts_immediately = false

func _tick_dread_aura(_delta: float) -> void:
	pass  # no sanity aura — this fight is muscle, not dread

## The Alfa calls his PACK, not shadows.
func _summon_shadows(count: int) -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in count:
		var ang := randf() * TAU
		var w := WolfMob.new()
		w.home_pos = global_position
		w.position = global_position + Vector2(cos(ang), sin(ang)) * randf_range(100.0, 180.0)
		parent.add_child(w)

## Cap counts his nearby dogs instead of shadows.
func _count_shadows() -> int:
	var parent := get_parent()
	if parent == null:
		return 0
	var n := 0
	for c in parent.get_children():
		if c is WolfMob and not c.is_dead and c.global_position.distance_to(global_position) < 700.0:
			n += 1
	return n

func _draw_mob(color: Color) -> void:
	var c := Color.WHITE if hit_flash > 0.3 else color
	# Hulking street dog: long low body, dark mane, big head, one torn ear.
	draw_rect(Rect2(-body_radius, -body_radius * 0.5, body_radius * 2.0, body_radius), c)
	draw_rect(Rect2(-body_radius, -body_radius * 0.7, body_radius * 1.2, body_radius * 0.5), c.darkened(0.25))
	draw_circle(Vector2(body_radius * 0.85, -body_radius * 0.35), 13.0, c.darkened(0.05))
	draw_rect(Rect2(body_radius * 0.85, -body_radius * 0.4, 18, 8), c.darkened(0.2))
	draw_line(Vector2(body_radius * 0.6, -body_radius * 0.85), Vector2(body_radius * 0.5, -body_radius * 1.3), c, 4.0)
	draw_line(Vector2(body_radius * 1.05, -body_radius * 0.85), Vector2(body_radius * 1.15, -body_radius * 1.1), c, 4.0)
	var eye := Color(1.0, 0.3, 0.15) if _enraged else Color(0.9, 0.5, 0.2)
	draw_circle(Vector2(body_radius * 0.95, -body_radius * 0.45), 2.6, eye)
	draw_rect(Rect2(-body_radius + 3, body_radius * 0.4, 6, 16), c.darkened(0.25))
	draw_rect(Rect2(body_radius - 10, body_radius * 0.4, 6, 16), c.darkened(0.25))
	draw_line(Vector2(-body_radius, -body_radius * 0.2), Vector2(-body_radius - 16, -body_radius * 0.7), c, 5.0)
