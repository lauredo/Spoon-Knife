class_name BossMob
extends MobBase

## The day-3 boss (MVP climax). Big, tanky melee hunter that ENRAGES below 40% HP (surges in speed,
## hits harder and faster) and periodically summons shadow creatures to swarm the player. Defeating
## it triggers the victory screen. Procedural placeholder art (dark horned brute + glowing eyes).
##
## It BULLDOZES anything in its path — trees/rocks are felled (drops spill out), walls and
## structures are smashed (a chest spills its contents) — so it never snags on obstacles and a
## wall ring can't cheese it. It also radiates a DREAD AURA that bleeds the player's sanity while
## they're close, stronger once enraged.

const SMASH_DAMAGE := 999.0      # one blow fells any tree/rock in the way
const SMASH_COOLDOWN := 0.35     # seconds between smashes — chews through a wall line, not instantly
const AURA_RADIUS := 340.0
const AURA_DRAIN_PER_MIN := 24.0
const AURA_DRAIN_ENRAGED_PER_MIN := 40.0

var _enraged: bool = false
var _summon_timer: float = 8.0   # first wave of adds a few seconds after it appears
var _smash_timer: float = 0.0

## Lair bosses (AlfaMob/JacareMob) wait at HOME and aggro by proximity like any mob; only the
## debug/summoned boss charges the player the moment it spawns.
var hunts_immediately: bool = true

func _init() -> void:
	mob_name = "Chefe"
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
	if hunts_immediately and GameManager.player and is_instance_valid(GameManager.player):
		target = GameManager.player
		state = State.CHASE

func _physics_process(delta: float) -> void:
	if not is_dead:
		_check_enrage()
		_tick_summon(delta)
	super._physics_process(delta)
	if not is_dead:
		_smash_obstacles(delta)
		_tick_dread_aura(delta)

## Bulldoze whatever the boss walked into this frame (checked after move_and_slide). One obstacle
## per SMASH_COOLDOWN so a wall line slows it down for a beat instead of evaporating.
func _smash_obstacles(delta: float) -> void:
	_smash_timer -= delta
	if _smash_timer > 0.0:
		return
	for i in get_slide_collision_count():
		if _smash(get_slide_collision(i).get_collider()):
			_smash_timer = SMASH_COOLDOWN
			return

## Try to destroy one obstacle. Returns false for bodies it can't smash (the world Boundary, other
## mobs), so the caller keeps scanning the frame's collisions.
func _smash(body) -> bool:
	var rn := body as ResourceNode
	if rn != null:
		if rn.is_depleted:
			return false
		rn.smash(SMASH_DAMAGE)  # fells it — drops spill out like a normal harvest
		_smash_feedback(rn.global_position)
		return true
	if body is Wall:
		_smash_feedback(body.global_position)
		body.queue_free()
		return true
	if body is Node2D and body.has_method("get_structure_type"):
		var chest := body as Chest
		if chest != null:
			# Spill the stash so stored loot isn't silently erased with the chest.
			for id in chest.contents:
				GameManager.spawn_drop(chest.global_position, id, chest.contents[id])
			var menu = GameManager.chest_menu
			if menu != null and menu.is_open and menu.chest == chest:
				menu.close()
		_smash_feedback(body.global_position)
		body.queue_free()
		return true
	return false

## Crunch sound + a burst of debris where something got flattened.
func _smash_feedback(pos: Vector2) -> void:
	Audio.play_sfx("hit", 0.15, 2.0)
	var parent := get_parent()
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, 380.0)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.35, 0.3, 0.24, 1.0))
	ramp.set_color(1, Color(0.35, 0.3, 0.24, 0.0))
	p.color_ramp = ramp
	p.z_index = 5
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.emitting = true

## Standing near the boss frays the mind: continuous sanity drain inside AURA_RADIUS (stronger
## once enraged). Counterweights the sanity the player claws back from hitting its shadow adds.
func _tick_dread_aura(delta: float) -> void:
	var p = GameManager.player
	if p == null or not is_instance_valid(p):
		return
	if global_position.distance_to(p.global_position) > AURA_RADIUS:
		return
	var per_min: float = AURA_DRAIN_ENRAGED_PER_MIN if _enraged else AURA_DRAIN_PER_MIN
	p.stats.drain_sanity(per_min / 60.0 * delta)

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
