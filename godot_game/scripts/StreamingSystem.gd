class_name StreamingSystem
extends Node

## Distance-based tick gating. The 18000px city holds ~3000 scripted nodes (resources, mobs), and
## per-frame _process/_physics_process on ALL of them is what tanked the framerate — 95% are far
## off-screen doing useless work. Every CHECK_EVERY seconds this sweeps the world and simply turns
## processing OFF beyond the wake radius (and back on when the player approaches).
##
## Consequences (accepted): far mobs freeze mid-step (they're beyond any visible range, and resume
## seamlessly); far resource regrow pauses (fits the design — the world shouldn't heal while you're
## not there). The boss NEVER sleeps.

const MOB_WAKE_R := 1500.0   # > screen half-diagonal at normal zoom, so you never see a statue
const RES_WAKE_R := 1100.0
const VIS_R := 1400.0        # hide beyond this: invisible items skip Y-sort/culling entirely
const CHECK_EVERY := 0.3

var _timer: float = 0.0
var _mobs: Node2D
var _resources: Node2D
var _structures: Node2D

func setup(world: Node2D) -> void:
	_mobs = world.get_node("Mobs")
	_resources = world.get_node("Resources")
	_structures = world.get_node("Structures")
	_sweep()  # gate immediately so even the first frames are cheap

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_EVERY
	_sweep()

func _sweep() -> void:
	var p = GameManager.player
	if p == null or not is_instance_valid(p):
		return
	var pp: Vector2 = p.global_position

	for m in _mobs.get_children():
		var mob := m as MobBase
		if mob == null or mob.is_dead:
			continue
		if mob is BossMob or mob is ShadowMob:
			# Boss never sleeps. Shadows must keep running their own vanish/daybreak logic —
			# frozen shadows stayed alive forever and silently filled the spawner cap,
			# switching the whole horror system off (confirmed bug). They're capped at 7, cheap.
			continue
		var awake := mob.global_position.distance_to(pp) < MOB_WAKE_R
		if mob.is_physics_processing() != awake:
			mob.set_physics_process(awake)
			# Never re-show a human who went home for the night (their own visibility owner) —
			# waking one used to leave a frozen intangible "ghost" standing in the street.
			mob.visible = awake and not (mob is HumanNPC and mob._sleeping)

	for r in _resources.get_children():
		var res := r as ResourceNode
		if res == null:
			continue
		var d := res.global_position.distance_to(pp)
		var awake := d < RES_WAKE_R
		if res.is_processing() != awake:
			res.set_process(awake)
		var vis := d < VIS_R
		if res.visible != vis:
			res.visible = vis

	# Structures (buildings, containers, fences, tents...) don't tick, but they're the bulk of the
	# Y-sorted canvas items — hiding the far ones is what actually buys the frame time back.
	# Collision is unaffected by visibility, so nothing changes physically.
	for s in _structures.get_children():
		var n := s as Node2D
		if n == null:
			continue
		var vis := n.global_position.distance_to(pp) < VIS_R
		if n.visible != vis:
			n.visible = vis

## DebugMenu: turn gating off (everything awake+visible) or back on.
func set_enabled(v: bool) -> void:
	set_process(v)
	if v:
		_sweep()
	else:
		wake_all()

## Debug/validation helper: force everything awake+visible (the "before" state).
func wake_all() -> void:
	for m in _mobs.get_children():
		if m is MobBase and not m.is_dead:
			m.set_physics_process(true)
			m.visible = not (m is HumanNPC and m._sleeping)
	for r in _resources.get_children():
		if r is ResourceNode:
			r.set_process(true)
			r.visible = true
	for s in _structures.get_children():
		if s is Node2D:
			s.visible = true
