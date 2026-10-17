class_name DayNightCycle
extends Node

signal phase_changed(phase: String, day_number: int)
signal time_updated(time_of_day: float)

enum Phase { DAWN, DAY, DUSK, NIGHT }

const CYCLE_DURATION := 300.0  # 5 minutes total
const DAY_START := 0.0
const DUSK_START := 0.65     # 65% = start of dusk
const NIGHT_START := 0.75    # 75% = night begins
const DAWN_START := 0.92     # 92% = dawn

var time_of_day: float = 0.1  # 0..1 range
var current_phase: Phase = Phase.DAY
var day_number: int = 1
var modulate_node: CanvasModulate = null
var barata_nodes: Array = []

func _ready() -> void:
	pass

func setup(modulate: CanvasModulate) -> void:
	modulate_node = modulate

func _process(delta: float) -> void:
	time_of_day += delta / CYCLE_DURATION
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day_number += 1
		GameManager.advance_day()

	var new_phase := _calculate_phase()
	if new_phase != current_phase:
		current_phase = new_phase
		phase_changed.emit(_phase_name(), day_number)
		_on_phase_change(new_phase)

	_update_darkness()
	time_updated.emit(time_of_day)

func _calculate_phase() -> Phase:
	if time_of_day < DUSK_START:
		return Phase.DAY
	elif time_of_day < NIGHT_START:
		return Phase.DUSK
	elif time_of_day < DAWN_START:
		return Phase.NIGHT
	else:
		return Phase.DAWN

func _phase_name() -> String:
	match current_phase:
		Phase.DAY: return "Day"
		Phase.DUSK: return "Dusk"
		Phase.NIGHT: return "Night"
		Phase.DAWN: return "Dawn"
	return "Day"

func _on_phase_change(phase: Phase) -> void:
	var is_night := phase == Phase.NIGHT
	if GameManager.player:
		GameManager.player.stats.set_is_day(phase == Phase.DAY or phase == Phase.DAWN)
	# Tell the roaches about night mode
	for barata in barata_nodes:
		if is_instance_valid(barata) and barata.has_method("set_night_mode"):
			barata.set_night_mode(is_night)

func _update_darkness() -> void:
	if not modulate_node:
		return

	# Multiply the whole world toward a dark blue at night; campfire/torch PointLight2Ds add
	# brightness back around them. (CanvasModulate darkens the world canvas, not the HUD layer.)
	var d: float = _get_darkness_level() / 0.88   # 0 (day) .. 1 (deep night)
	# Accessibility slider: shave up to 50% off the darkness (0 keeps the designed look).
	d *= 1.0 - 0.5 * Settings.night_brightness
	# Deep night is near-black with a faint cold tint, so only campfire/torch pools are readable.
	# A Blood Moon night bleeds the darkness red instead of blue.
	var night_col := Color(0.12, 0.01, 0.02) if GameManager.blood_moon else Color(0.02, 0.03, 0.07)
	var col: Color = Color.WHITE.lerp(night_col, d)

	# Sanity distortion: tint the world toward a sickly purple as sanity drops.
	if GameManager.player and GameManager.player.stats.is_low_sanity():
		var k: float = GameManager.player.stats.get_insanity_intensity()
		col = col.lerp(Color(0.30, 0.12, 0.32), k * 0.5)

	modulate_node.color = col

func _get_darkness_level() -> float:
	if time_of_day < DUSK_START:
		return 0.0
	elif time_of_day < NIGHT_START:
		# Fade in during dusk
		var t := (time_of_day - DUSK_START) / (NIGHT_START - DUSK_START)
		return t * 0.88
	elif time_of_day < DAWN_START:
		return 0.88
	else:
		# Fade out during dawn
		var t := (time_of_day - DAWN_START) / (1.0 - DAWN_START)
		return (1.0 - t) * 0.88

# ── Moon & tide (S3) — the long clock. The moon phase sets the tide AMPLITUDE: full/new moon =
# spring tides (extreme lows open the flooded waterfront ON FOOT), quarters = neap (it stays shut).
# Day 2 is deliberately the FULL moon, so the Blood Moon night rides a spring tide.
const LUNAR_PERIOD_DAYS := 8.0
const TIDES_PER_DAY := 2.0

## 0 = new moon, 0.5 = full, wrapping every LUNAR_PERIOD_DAYS.
func moon_phase() -> float:
	return fposmod((float(day_number) - 2.0) / LUNAR_PERIOD_DAYS + 0.5, 1.0)

## Tide swing strength: 1 at full/new (spring), 0 at the quarters (neap).
func moon_amplitude() -> float:
	return absf(cos(TAU * moon_phase()))

## Full moon tonight? (days 2, 10, 18... — phase steps 1/8 per day, so only exact days hit 0.5)
func is_full_moon() -> bool:
	return absf(moon_phase() - 0.5) < 0.07

## -1 (lowest) .. +1 (highest): TIDES_PER_DAY sine cycles per day, scaled by the moon.
func tide_level() -> float:
	return sin(time_of_day * TAU * TIDES_PER_DAY) * moon_amplitude()

func is_night() -> bool:
	return current_phase == Phase.NIGHT

func get_time_string() -> String:
	var hours := int(time_of_day * 24.0)
	var mins := int(fmod(time_of_day * 24.0 * 60.0, 60.0))
	return "%02d:%02d" % [hours, mins]

func get_phase_name() -> String:
	return _phase_name()

func register_barata(barata: Node) -> void:
	if not barata in barata_nodes:
		barata_nodes.append(barata)
