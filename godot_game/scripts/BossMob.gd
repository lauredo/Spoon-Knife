class_name BossMob
extends MobBase

## The day-3 boss (MVP climax). Big, tanky melee hunter that ENRAGES below 40% HP (surges in speed,
## hits harder and faster) and periodically summons shadow creatures to swarm the player. Defeating
## it triggers the victory screen. Procedural placeholder art (dark horned brute + glowing eyes).

var _enraged: bool = false
var _summon_timer: float = 8.0   # first wave of adds a few seconds after it appears

func _init() -> void:
	mob_name = "Boss"
	max_health = 850.0
	move_speed = 115.0
	attack_damage = 38.0
	attack_cooldown = 1.0
	attack_range = 50.0
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

func _physics_process(delta: float) -> void:
	if not is_dead:
		_check_enrage()
		_tick_summon(delta)
	super._physics_process(delta)

## Below 40% HP the boss enrages ONCE: a permanent surge in speed, damage and attack rate.
func _check_enrage() -> void:
	if _enraged or health > max_health * 0.4:
		return
	_enraged = true
	move_speed *= 1.3
	attack_damage *= 1.35
	attack_cooldown *= 0.7
	body_color = Color(0.6, 0.07, 0.12)

## Periodically calls down shadow adds to swarm the player — sooner and in pairs once enraged. A
## concurrent cap keeps the screen from drowning in shadows.
func _tick_summon(delta: float) -> void:
	_summon_timer -= delta
	if _summon_timer > 0.0:
		return
	_summon_timer = 6.0 if _enraged else 10.0
	var cap: int = 6 if _enraged else 4
	if _count_shadows() >= cap:
		return
	_summon_shadows(2 if _enraged else 1)

func _summon_shadows(count: int) -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in count:
		var ang := randf() * TAU
		var dist := randf_range(120.0, 220.0)
		var m := ShadowMob.new()
		m.summoned = true  # boss adds persist regardless of the player's sanity / time of day
		m.position = global_position + Vector2(cos(ang), sin(ang)) * dist
		parent.add_child(m)

func _count_shadows() -> int:
	var parent := get_parent()
	if parent == null:
		return 0
	var n := 0
	for c in parent.get_children():
		if c is ShadowMob and not c.is_dead:
			n += 1
	return n

func _draw_mob(color: Color) -> void:
	var flash := hit_flash > 0.3
	# Hulking dark body (brighter red once enraged via body_color).
	draw_circle(Vector2.ZERO, body_radius, color if not flash else Color.WHITE)
	draw_circle(Vector2(0, -3), body_radius * 0.8, color.lightened(0.15) if not flash else Color(1, 1, 1, 0.8))
	# Horns.
	draw_line(Vector2(-16, -24), Vector2(-26, -44), Color(0.08, 0.08, 0.1), 6.0)
	draw_line(Vector2(16, -24), Vector2(26, -44), Color(0.08, 0.08, 0.1), 6.0)
	# Glowing eyes — hotter when enraged.
	var eye := Color(1.0, 0.55, 0.1) if _enraged else Color(1.0, 0.35, 0.1)
	draw_circle(Vector2(-11, -6), 5.0, eye)
	draw_circle(Vector2(11, -6), 5.0, eye)
	draw_circle(Vector2(-11, -6), 2.0, Color(1, 1, 0.6))
	draw_circle(Vector2(11, -6), 2.0, Color(1, 1, 0.6))
