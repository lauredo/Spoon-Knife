class_name PlayerStats
extends Node

signal health_changed(current: float, maximum: float)
signal hunger_changed(current: float, maximum: float)
signal sanity_changed(current: float, maximum: float)
signal died

const MAX_HEALTH := 150.0
const MAX_HUNGER := 150.0
const MAX_SANITY := 200.0

# --- Tuning (Phase 3). Day cycle is 5 min. Hunger is a hard clock (full -> "worrying" within a
# single day if you never eat). Sanity NEVER recovers passively any more: by day it holds steady,
# at night it always bleeds (slow near fire/torch, fast in the dark), and the ONLY way back up is
# striking shadow creatures (see ShadowMob.take_damage -> restore_sanity).
const HUNGER_DRAIN_RATE := 18.0         # per minute — ~40% left by the end of day 1 if you don't eat
const HUNGER_STARVE_DAMAGE := 5.0       # health per minute at 0 hunger
const SANITY_NIGHT_LIGHT_DRAIN := 3.0   # per minute at night NEAR light (fire/torch) — slowed, not stopped
const SANITY_NIGHT_DARK_DRAIN := 50.0   # per minute at night IN THE DARK — the core horror pressure
const SANITY_HUNGER_DRAIN := 6.0        # per minute extra sanity loss while very hungry
const SANITY_PER_SHADOW_HIT := 10.0     # sanity clawed back per hit landed on a shadow creature
const HUNGER_STRESS_PCT := 0.30         # hunger below this fraction starts fraying sanity

const SANITY_LOW_PCT := 0.5             # shadows + visual distortion begin (was 0.3)
const SANITY_VERY_LOW_PCT := 0.25       # heavier horror: more/faster shadows (was 0.15)

var health: float = MAX_HEALTH
var hunger: float = MAX_HUNGER
var sanity: float = MAX_SANITY

var in_light: bool = true
var is_day: bool = true
var invincible: bool = false

var _time_accumulator: float = 0.0

func _ready() -> void:
	health = MAX_HEALTH
	hunger = MAX_HUNGER
	sanity = MAX_SANITY

func _process(delta: float) -> void:
	_time_accumulator += delta

	if _time_accumulator >= 1.0:
		_time_accumulator -= 1.0
		_tick_per_second()

func _tick_per_second() -> void:
	# Hunger drains constantly
	_change_hunger(-HUNGER_DRAIN_RATE / 60.0)

	# Starvation damage
	if hunger <= 0.0:
		take_damage(HUNGER_STARVE_DAMAGE / 60.0)

	# Sanity: no passive recovery any more. By day it holds steady; at night it always drains —
	# slowly near fire/torch light, fast out in the dark. The only way back up is striking shadow
	# creatures (ShadowMob.take_damage -> restore_sanity), which only emerge once sanity is low.
	if not is_day:
		if in_light:
			_change_sanity(-SANITY_NIGHT_LIGHT_DRAIN / 60.0)
		else:
			_change_sanity(-SANITY_NIGHT_DARK_DRAIN / 60.0)

	# Hunger frays the nerves: being very hungry also bleeds sanity (couples the two pillars).
	if hunger <= MAX_HUNGER * HUNGER_STRESS_PCT:
		_change_sanity(-SANITY_HUNGER_DRAIN / 60.0)

func take_damage(amount: float) -> void:
	if invincible:
		return
	health = max(0.0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	health = min(MAX_HEALTH, health + amount)
	health_changed.emit(health, MAX_HEALTH)

## Sanity gained by striking shadow creatures — the only recovery path now that daylight no longer
## restores it. Called from ShadowMob.take_damage.
func restore_sanity(amount: float) -> void:
	_change_sanity(amount)

## Consume a food OR medicine item: applies its hunger/health/sanity restores. (Medicine like
## bandages only set health_restore.)
func eat(item_id: String) -> bool:
	var item = ItemDatabase.get_item(item_id)
	if not item or (item.type != ItemDatabase.ItemType.FOOD and item.type != ItemDatabase.ItemType.MEDICINE):
		return false
	_change_hunger(item.hunger_restore)
	heal(item.health_restore)
	_change_sanity(item.sanity_restore)
	return true

func _change_hunger(amount: float) -> void:
	hunger = clamp(hunger + amount, 0.0, MAX_HUNGER)
	hunger_changed.emit(hunger, MAX_HUNGER)

func _change_sanity(amount: float) -> void:
	sanity = clamp(sanity + amount, 0.0, MAX_SANITY)
	sanity_changed.emit(sanity, MAX_SANITY)

func set_in_light(value: bool) -> void:
	in_light = value

func set_is_day(value: bool) -> void:
	is_day = value

func get_health_pct() -> float:
	return health / MAX_HEALTH

func get_hunger_pct() -> float:
	return hunger / MAX_HUNGER

func get_sanity_pct() -> float:
	return sanity / MAX_SANITY

func is_low_sanity() -> bool:
	return get_sanity_pct() < SANITY_LOW_PCT

func is_very_low_sanity() -> bool:
	return get_sanity_pct() < SANITY_VERY_LOW_PCT

## 0.0 at the low-sanity threshold → 1.0 at empty. Drives the horror screen effects so they
## scale with the threshold instead of a hardcoded literal.
func get_insanity_intensity() -> float:
	return clampf((SANITY_LOW_PCT - get_sanity_pct()) / SANITY_LOW_PCT, 0.0, 1.0)
