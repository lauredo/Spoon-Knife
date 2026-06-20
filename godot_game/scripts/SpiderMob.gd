class_name SpiderMob
extends MobBase

const LEG_COUNT := 8

var leg_phase: float = 0.0
var night_bonus: bool = false

func _ready() -> void:
	mob_name = "Spider"
	max_health = 100.0
	move_speed = 100.0
	attack_damage = 10.0
	attack_cooldown = 1.2
	attack_range = 45.0
	detection_range = 180.0
	body_color = Color(0.25, 0.1, 0.35)
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
	return "spider"

func _base_modulate() -> Color:
	return Color(1.25, 1.0, 1.4) if night_bonus else Color.WHITE

func _on_aggro(player: Node) -> void:
	state = State.CHASE

func _draw_mob(color: Color) -> void:
	# Draw 8 legs
	var leg_colors := Color(0.18, 0.07, 0.28)
	if night_bonus:
		leg_colors = Color(0.5, 0.1, 0.6)

	for i in LEG_COUNT:
		var angle := (float(i) / LEG_COUNT) * TAU
		var leg_bend := sin(leg_phase + angle * 2.0) * 0.35
		var leg_end_dist := body_radius + 20.0
		var knee_dist := body_radius + 10.0
		var knee_pos := Vector2(cos(angle + leg_bend), sin(angle + leg_bend)) * knee_dist
		var end_pos := Vector2(cos(angle), sin(angle)) * leg_end_dist
		draw_line(Vector2.ZERO, knee_pos, leg_colors, 2.5)
		draw_line(knee_pos, end_pos, leg_colors, 2.0)

	# Body segments (abdomen + cephalothorax)
	draw_circle(Vector2(0, 5), body_radius * 0.85, color)
	draw_circle(Vector2(0, -body_radius * 0.5), body_radius * 0.6, color.lightened(0.1))

	# Eyes
	var eye_color := Color(0.9, 0.8, 0.1) if night_bonus else Color(0.85, 0.1, 0.1)
	draw_circle(Vector2(-5, -body_radius * 0.5 - 2), 3.5, eye_color)
	draw_circle(Vector2(5, -body_radius * 0.5 - 2), 3.5, eye_color)
	draw_circle(Vector2(-9, -body_radius * 0.5 + 2), 2.0, eye_color)
	draw_circle(Vector2(9, -body_radius * 0.5 + 2), 2.0, eye_color)

	# Fangs
	var fang_color := Color(0.6, 0.8, 0.4)
	draw_line(Vector2(-4, -body_radius * 0.5 - 8), Vector2(-6, -body_radius * 0.5 - 14), fang_color, 2.5)
	draw_line(Vector2(4, -body_radius * 0.5 - 8), Vector2(6, -body_radius * 0.5 - 14), fang_color, 2.5)
