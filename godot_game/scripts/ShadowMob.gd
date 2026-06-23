class_name ShadowMob
extends MobBase

## Terror creature (the horror hook). Spawns near the player when sanity is LOW (see ShadowSpawner),
## relentlessly hunts, and VANISHES the moment sanity recovers. No art yet — a procedural shadow
## blob with glowing eyes (placeholder until the 2.5D painted pass).

## Set by the boss for adds it calls down: these persist until killed instead of vanishing when
## sanity recovers / day breaks (a regular shadow only haunts you while sanity is low at night).
var summoned: bool = false

func _init() -> void:
	mob_name = "Shadow"
	max_health = 30.0
	move_speed = 115.0
	attack_damage = 8.0
	attack_cooldown = 1.1
	attack_range = 34.0
	detection_range = 2000.0  # never loses the player (drawn to your low sanity)
	body_color = Color(0.05, 0.02, 0.08)
	body_radius = 14.0
	drops = []
	xp_value = 0

func _ready() -> void:
	super._ready()
	# Hunt immediately on appearing.
	if GameManager.player and is_instance_valid(GameManager.player):
		target = GameManager.player
		state = State.CHASE

func _base_modulate() -> Color:
	return Color(0.12, 0.06, 0.18, 0.9)

func _physics_process(delta: float) -> void:
	# Only exist at night while the player's sanity is low — fade out at dawn or once they recover.
	# Boss-summoned shadows ignore this and stay until killed.
	var p = GameManager.player
	if not summoned and not is_dead and p and is_instance_valid(p) and p.stats and (p.stats.is_day or not p.stats.is_low_sanity()):
		_vanish()
		return
	super._physics_process(delta)

func take_damage(amount: float, attacker: Node = null) -> void:
	# Striking a shadow is the ONLY way to claw sanity back (daylight no longer restores it).
	if not is_dead and attacker is Player:
		var pl := attacker as Player
		if pl.stats:
			pl.stats.restore_sanity(PlayerStats.SANITY_PER_SHADOW_HIT)
	super.take_damage(amount, attacker)

func _vanish() -> void:
	if is_dead:
		return
	is_dead = true
	state = State.DEAD
	velocity = Vector2.ZERO
	queue_free()

func _draw_mob(color: Color) -> void:
	var c := color
	if hit_flash > 0.3:
		c = Color.WHITE
	# Wispy shadow body.
	draw_circle(Vector2.ZERO, body_radius, Color(0.04, 0.02, 0.07, 0.92))
	draw_circle(Vector2(0, -2), body_radius * 0.7, Color(0.14, 0.06, 0.2, 0.7))
	# Glowing eyes.
	var eye := Color(0.95, 0.85, 0.2) if hit_flash <= 0.3 else Color.WHITE
	draw_circle(Vector2(-5, -4), 2.3, eye)
	draw_circle(Vector2(5, -4), 2.3, eye)
