class_name DayNightCycle
extends Node

signal phase_changed(phase: String, day_number: int)
signal time_updated(time_of_day: float)

enum Phase { DAWN, DAY, DUSK, NIGHT }

const CYCLE_DURATION := 480.0  # 8 minutes total
const DAY_START := 0.0
const DUSK_START := 0.65     # 65% = start of dusk
const NIGHT_START := 0.75    # 75% = night begins
const DAWN_START := 0.92     # 92% = dawn

var time_of_day: float = 0.1  # 0..1 range
var current_phase: Phase = Phase.DAY
var day_number: int = 1
var overlay_node: ColorRect = null
var spider_nodes: Array = []

func _ready() -> void:
	pass

func setup(overlay: ColorRect) -> void:
	overlay_node = overlay

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

	_update_overlay()
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
	# Tell spiders about night mode
	for spider in spider_nodes:
		if is_instance_valid(spider) and spider.has_method("set_night_mode"):
			spider.set_night_mode(is_night)

func _update_overlay() -> void:
	if not overlay_node:
		return

	var darkness := _get_darkness_level()
	var overlay_color := Color(0.0, 0.02, 0.08, darkness)

	# Add sanity distortion tint at very low sanity
	if GameManager.player and GameManager.player.stats.is_low_sanity():
		var sanity_pct := GameManager.player.stats.get_sanity_pct()
		overlay_color = overlay_color.lerp(Color(0.15, 0.0, 0.15, darkness + 0.1), 1.0 - sanity_pct * 3.0)

	overlay_node.color = overlay_color

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

func is_night() -> bool:
	return current_phase == Phase.NIGHT

func get_time_string() -> String:
	var hours := int(time_of_day * 24.0)
	var mins := int(fmod(time_of_day * 24.0 * 60.0, 60.0))
	return "%02d:%02d" % [hours, mins]

func get_phase_name() -> String:
	return _phase_name()

func register_spider(spider: Node) -> void:
	if not spider in spider_nodes:
		spider_nodes.append(spider)
