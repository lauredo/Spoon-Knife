class_name TideSystem
extends Node

## Applies the moon-driven tide (math in DayNightCycle) to the organic coast: slides the sea slab,
## and DROWNS whoever wanders past the waterline. The islands are the real gate — you can't reach
## them without a raft, and the water in between kills you. Low spring tides expose more beach.

const DROWN_DPS := 12.0
const UPDATE_EVERY := 0.25

var day_night: DayNightCycle
var world_gen: WorldGenerator
var _t: float = 0.0
var _low_announced: bool = false
var _warned: bool = false
var _raft_notified: bool = false
var _prev_tide: float = 0.0

func setup(dnc: DayNightCycle, wg: WorldGenerator) -> void:
	day_night = dnc
	world_gen = wg
	_prev_tide = day_night.tide_level()
	_apply()

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = UPDATE_EVERY
	_apply()

func _apply() -> void:
	if day_night == null or world_gen == null:
		return
	var tide := day_night.tide_level()          # -1 (low) .. +1 (high)
	world_gen.tide_offset = tide * WorldGenerator.TIDE_RANGE
	if world_gen.sea_poly:
		world_gen.sea_poly.position.y = -world_gen.tide_offset  # high tide slides the sea inland

	# A big spring low exposes the beach — worth announcing (plan your island run).
	var low := tide < -0.7
	if low != _low_announced:
		_low_announced = low
		if low:
			_notify("🌊 Maré baixa de sizígia — a praia se abre")

	var p = GameManager.player
	if p != null and is_instance_valid(p) and p.stats != null and not GameManager.is_game_over:
		var in_water: bool = world_gen.is_water(p.global_position)
		var rising := tide > _prev_tide + 0.001
		var has_raft: bool = p.inventory != null and p.inventory.has_item("raft")
		var can_cross: bool = has_raft or (p.inventory != null and p.inventory.has_item("jacare_scale"))
		if in_water and can_cross:
			if has_raft and not _raft_notified:  # the first launch is a moment
				_raft_notified = true
				_notify("🛶 Você lançou a balsa ao mar!")
			_warned = false
		elif in_water and not GameManager.debug_god:
			p.stats.take_damage(DROWN_DPS * UPDATE_EVERY)  # the sea bypasses armor on purpose
			_warned = false
		elif rising and _in_tide_zone(p.global_position):
			# Anywhere the spring tide can reach — not just the BEACH district; the old check let
			# players near the waterline (or in the surf zone) flood with zero warning.
			if not _warned:
				_warned = true
				_notify("⚠ A maré está subindo — afaste-se da água!")
		else:
			_warned = false
	_prev_tide = tide

## Dry land the spring high tide can still swallow (islands excluded — they never flood).
func _in_tide_zone(pos: Vector2) -> bool:
	if world_gen._on_island(pos) >= 0:
		return false
	var inland := world_gen.coastline_y(pos.x) - pos.y
	return inland > 0.0 and inland < WorldGenerator.TIDE_RANGE + 80.0

func _notify(msg: String) -> void:
	if GameManager.hud and GameManager.hud.has_method("show_notification"):
		GameManager.hud.show_notification(msg, 3.5)
