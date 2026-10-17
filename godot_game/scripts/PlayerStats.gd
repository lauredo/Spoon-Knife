class_name PlayerStats
extends Node

signal health_changed(current: float, maximum: float)
signal hunger_changed(current: float, maximum: float)
signal sanity_changed(current: float, maximum: float)
signal energy_changed(current: float, maximum: float)
signal temperature_changed(current: float, maximum: float)
signal died

const MAX_HEALTH := 150.0
const MAX_HUNGER := 150.0
const MAX_SANITY := 200.0
const MAX_ENERGY := 100.0

# --- Energia (S5, user-locked design): drains awake (passive + heavy actions), refills ONLY by
# sleeping in a bed (time runs 4x — the night is lived, not skipped). At 0 the raccoon is
# exhausted: -30% move speed + slower swings (Player reads is_exhausted). Food restores a nibble.
const ENERGY_DRAIN_RATE := 12.0     # per minute awake → ~60/day-cycle passive
const ENERGY_SLEEP_REGEN := 110.0   # per minute asleep → a full night's sleep ≈ full bar
const ENERGY_ATTACK_COST := 0.5
const ENERGY_DODGE_COST := 1.5

# --- Temperatura (S5, rides the weather): the bar DRIFTS toward a context target (day/night,
# rain, roof overhead, fire nearby, open water). Below the freeze line = Frio: health bleeds
# until you find fire or shelter. Fifth and LAST visible bar (GDD caps them at 5).
const MAX_TEMP := 100.0
const TEMP_FREEZE_PCT := 0.25
const TEMP_RATE := 25.0             # per minute toward the target
const TEMP_RATE_FIRE := 50.0        # a fire warms you back fast (QoL — recovery isn't a chore)
const TEMP_RATE_SWIM := 60.0        # open water strips heat
const COLD_HEALTH_DRAIN := 5.0      # per minute while Frio

# --- Condições (S5): discrete states, ONE system — icons, not a 6th bar. Rare events with a
# clear item answer: bandage stops bleeding, salve also clears sickness.
const BLEED_DURATION := 90.0
const BLEED_HEALTH_DRAIN := 10.0    # per minute while Sangrando
const SICK_DURATION := 120.0
const SICK_ENERGY_EXTRA := 12.0     # per minute extra energy drain while Enjoado
const SICK_HUNGER_EXTRA := 6.0      # per minute extra hunger drain while Enjoado

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
var energy: float = MAX_ENERGY
var temperature: float = 70.0
var bleeding_timer: float = 0.0
var sick_timer: float = 0.0

var in_light: bool = true
var is_day: bool = true
var invincible: bool = false
var is_sleeping: bool = false  # set by Player.start_sleeping/wake_up
var swimming: bool = false     # mirrored from Player.is_swimming each frame
var indoors: bool = false      # set by Player.set_indoors (Building roof trigger)

var _time_accumulator: float = 0.0

func _ready() -> void:
	health = MAX_HEALTH
	hunger = MAX_HUNGER
	sanity = MAX_SANITY
	energy = MAX_ENERGY

func _process(delta: float) -> void:
	_time_accumulator += delta

	if _time_accumulator >= 1.0:
		_time_accumulator -= 1.0
		_tick_per_second()

func _tick_per_second() -> void:
	if GameManager.debug_god:
		return  # debug: no survival drain
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
			var dark_drain := SANITY_NIGHT_DARK_DRAIN
			if GameManager.has_perk("veterano_da_noite"):
				dark_drain *= 0.75  # perk (S6): the dark is familiar now
			_change_sanity(-dark_drain / 60.0)

	# Hunger frays the nerves: being very hungry also bleeds sanity (couples the two pillars).
	if hunger <= MAX_HUNGER * HUNGER_STRESS_PCT:
		_change_sanity(-SANITY_HUNGER_DRAIN / 60.0)

	# Energia: refills asleep, drains awake (heavy actions cost extra via spend_energy).
	if is_sleeping:
		_change_energy(ENERGY_SLEEP_REGEN / 60.0)
	else:
		var e_drain := ENERGY_DRAIN_RATE
		if GameManager.has_perk("sono_leve"):
			e_drain *= 0.85  # perk (S6): rests deeper, tires slower
		_change_energy(-e_drain / 60.0)

	# Temperatura: drift toward the context target; freezing bleeds health.
	var t_target := _temp_target()
	var t_rate := TEMP_RATE
	if swimming:
		t_rate = TEMP_RATE_SWIM
	elif in_light and t_target > temperature:
		t_rate = TEMP_RATE_FIRE
	temperature = move_toward(temperature, t_target, t_rate / 60.0)
	temperature_changed.emit(temperature, MAX_TEMP)
	if is_cold():
		take_damage(COLD_HEALTH_DRAIN / 60.0)

	# Condições: rare, timed, each with a clear item answer (see eat()).
	if bleeding_timer > 0.0:
		bleeding_timer = maxf(0.0, bleeding_timer - 1.0)
		take_damage(BLEED_HEALTH_DRAIN / 60.0)
	if sick_timer > 0.0:
		sick_timer = maxf(0.0, sick_timer - 1.0)
		_change_energy(-SICK_ENERGY_EXTRA / 60.0)
		_change_hunger(-SICK_HUNGER_EXTRA / 60.0)

## Where the temperature wants to settle given the situation. Night + rain in the open dips
## below the freeze line; a roof cancels the rain; fire dominates everything but open water.
func _temp_target() -> float:
	if swimming:
		return 12.0
	var t := 70.0 if is_day else 45.0
	if indoors:
		t += 12.0
	elif GameManager.is_raining():
		t -= 28.0
	if in_light:
		t = maxf(t, 92.0)
	return clampf(t, 0.0, MAX_TEMP)

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

## Sanity bled by an external terror source (the boss's dread aura). Kept separate from
## restore_sanity so callers read as what they do.
func drain_sanity(amount: float) -> void:
	_change_sanity(-amount)

## Consume a food OR medicine item: applies its hunger/health/sanity restores. (Medicine like
## bandages only set health_restore.)
func eat(item_id: String) -> bool:
	var item = ItemDatabase.get_item(item_id)
	if not item or (item.type != ItemDatabase.ItemType.FOOD and item.type != ItemDatabase.ItemType.MEDICINE):
		return false
	_change_hunger(item.hunger_restore)
	heal(item.health_restore)
	_change_sanity(item.sanity_restore)
	if item.hunger_restore > 0.0:
		_change_energy(item.hunger_restore * 0.2)  # a meal perks you up a little
	# Condições: dressings stop the bleed; the premium salve clears the gut too; bad food gambles.
	if item.type == ItemDatabase.ItemType.MEDICINE:
		bleeding_timer = 0.0
		if item_id == "salve":
			sick_timer = 0.0
	elif item_id == "monster_meat" and randf() < 0.35:
		apply_sickness()
	elif item_id == "old_pizza" and randf() < 0.2:
		apply_sickness()
	return true

func apply_bleeding() -> void:
	bleeding_timer = BLEED_DURATION

func apply_sickness() -> void:
	sick_timer = SICK_DURATION

func is_bleeding() -> bool:
	return bleeding_timer > 0.0

func is_sick() -> bool:
	return sick_timer > 0.0

func is_cold() -> bool:
	return temperature < MAX_TEMP * TEMP_FREEZE_PCT

## Heavy actions (swing, dodge) burn extra energy — called from Player.
func spend_energy(amount: float) -> void:
	_change_energy(-amount)

func is_exhausted() -> bool:
	return energy <= 0.001

func _change_energy(amount: float) -> void:
	energy = clamp(energy + amount, 0.0, MAX_ENERGY)
	energy_changed.emit(energy, MAX_ENERGY)

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
