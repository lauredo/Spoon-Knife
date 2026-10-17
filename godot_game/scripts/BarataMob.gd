class_name BarataMob
extends MobBase

const LEG_COUNT := 6

var leg_phase: float = 0.0
var night_bonus: bool = false

func _ready() -> void:
	mob_name = "Barata"
	max_health = 100.0
	move_speed = 100.0
	attack_damage = 10.0
	attack_cooldown = 1.2
	attack_range = 45.0
	detection_range = 180.0
	body_color = Color(0.38, 0.2, 0.08)
	body_radius = 16.0
	drops = [
		{"item": "silk", "min": 1, "max": 2, "chance": 0.8},
		{"item": "spider_gland", "min": 1, "max": 1, "chance": 0.5},
		{"item": "monster_meat", "min": 1, "max": 1, "chance": 1.0},
	]
	super._ready()

func _physics_process(delta: float) -> void:
	leg_phase += delta * (move_speed / 80.0)
	super._physics_process(delta)

func set_night_mode(is_night: bool) -> void:
	night_bonus = is_night
	if is_night:
		move_speed = 130.0
		detection_range = 250.0
		attack_damage = 14.0
	else:
		move_speed = 100.0
		detection_range = 180.0
		attack_damage = 10.0

func _sprite_name() -> String:
	return "barata"

func _base_modulate() -> Color:
	return Color(1.25, 1.05, 0.9) if night_bonus else Color.WHITE

func _on_aggro(player: Node) -> void:
	state = State.CHASE

func _draw_mob(color: Color) -> void:
	# Giant cockroach: 3 legs per side, flat oval shell, long antennae.
	var leg_color := Color(0.24, 0.12, 0.05)
	if night_bonus:
		leg_color = Color(0.45, 0.2, 0.08)

	for side in [-1.0, 1.0]:
		for i in 3:
			var spread := (float(i) - 1.0) * 0.55            # front / mid / hind leg
			var angle: float = side * (PI * 0.5 + spread * 0.6)
			var bend := sin(leg_phase + float(i) * 1.7 + (0.0 if side < 0 else PI)) * 0.3
			var knee_pos := Vector2(cos(angle + bend), sin(angle + bend) * 0.6) * (body_radius + 8.0)
			knee_pos.y += spread * 10.0
			var end_pos := Vector2(cos(angle), sin(angle) * 0.6) * (body_radius + 18.0)
			end_pos.y += spread * 14.0
			draw_line(Vector2.ZERO, knee_pos, leg_color, 2.5)
			draw_line(knee_pos, end_pos, leg_color, 2.0)

	# Flat oval shell (abdomen) + pronotum + small head poking out the front.
	draw_set_transform(Vector2(0, 3), 0.0, Vector2(0.85, 1.25))
	draw_circle(Vector2.ZERO, body_radius * 0.9, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0, -body_radius * 0.55), body_radius * 0.55, color.lightened(0.08))
	draw_circle(Vector2(0, -body_radius * 0.95), body_radius * 0.32, color.darkened(0.15))
	# Wing split line down the back
	draw_line(Vector2(0, -body_radius * 0.2), Vector2(0, body_radius * 1.05), color.darkened(0.25), 1.5)

	# Eyes
	var eye_color := Color(0.9, 0.8, 0.1) if night_bonus else Color(0.85, 0.1, 0.1)
	draw_circle(Vector2(-4, -body_radius * 0.95), 2.2, eye_color)
	draw_circle(Vector2(4, -body_radius * 0.95), 2.2, eye_color)

	# Long antennae sweeping back
	var ant_sway := sin(leg_phase * 1.3) * 3.0
	var ant_color := color.darkened(0.3)
	var head_y := -body_radius * 0.95
	draw_line(Vector2(-3, head_y - 3), Vector2(-12, head_y - 16), ant_color, 1.5)
	draw_line(Vector2(-12, head_y - 16), Vector2(-20 + ant_sway, head_y - 26), ant_color, 1.2)
	draw_line(Vector2(3, head_y - 3), Vector2(12, head_y - 16), ant_color, 1.5)
	draw_line(Vector2(12, head_y - 16), Vector2(20 + ant_sway, head_y - 26), ant_color, 1.2)
