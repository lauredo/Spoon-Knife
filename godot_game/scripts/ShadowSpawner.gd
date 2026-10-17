class_name ShadowSpawner
extends Node

## Spawns ShadowMobs near the player while sanity is LOW (the horror hook). Faster/more when
## sanity is very low. Shadows despawn themselves once sanity recovers (see ShadowMob).

const SPAWN_DIST_MIN := 280.0   # just off-screen
const SPAWN_DIST_MAX := 430.0

var _timer: float = 0.0

func _process(delta: float) -> void:
	var p = GameManager.player
	if p == null or not is_instance_valid(p) or p.stats == null:
		return
	# Shadows are a NIGHT terror: they only emerge in the dark hours, never in daylight. Normally
	# gated by LOW sanity — but a Blood Moon summons them regardless of how sane you are.
	var bm: bool = GameManager.blood_moon
	if GameManager.is_game_over or p.stats.is_day or (not bm and not p.stats.is_low_sanity()):
		_timer = 0.0
		return

	_timer -= delta
	if _timer > 0.0:
		return

	var very: bool = p.stats.is_very_low_sanity()
	# Blood moons ESCALATE with each lunar cycle survived (wave 0 on day 2, +1 every 8 days):
	# more shadows, faster — the endless game's difficulty curve rides the moon.
	var wave: int = maxi(0, (GameManager.current_day - 2) / 8) if bm else 0
	var cap: int = mini(7 + wave * 2, 15) if bm else (5 if very else 3)
	_timer = maxf(0.6, 1.2 - 0.15 * wave) if bm else (2.0 if very else 4.0)
	if _count_shadows() >= cap:
		return
	_spawn_shadow(p)

func _count_shadows() -> int:
	var mobs := _mobs_node()
	if mobs == null:
		return 0
	var n := 0
	for c in mobs.get_children():
		if c is ShadowMob and not c.is_dead:
			n += 1
	return n

func _spawn_shadow(p: Node) -> void:
	var mobs := _mobs_node()
	if mobs == null:
		return
	var ang := randf() * TAU
	var dist := randf_range(SPAWN_DIST_MIN, SPAWN_DIST_MAX)
	var m := ShadowMob.new()
	m.position = p.global_position + Vector2(cos(ang), sin(ang)) * dist
	mobs.add_child(m)

func _mobs_node() -> Node:
	if GameManager.world == null:
		return null
	return GameManager.world.get_node_or_null("Mobs")
