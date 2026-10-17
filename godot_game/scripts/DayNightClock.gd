class_name DayNightClock
extends Control

## Circular day/night dial for the HUD. The ring is split into coloured arcs (day/dusk/night/
## dawn) matching DayNightCycle's phase boundaries; a hand with a sun/moon marker sweeps it so
## the player can see where in the cycle they are and how much night is left.

var time_of_day: float = 0.0
var phase: String = "Day"
var moon_phase: float = 0.5   # 0 = new .. 0.5 = full (drawn in the inner disc)
var tide: float = 0.0
var tide_rising: bool = false

const R := 25.0
# Phase boundaries — keep in sync with DayNightCycle (DUSK_START / NIGHT_START / DAWN_START).
const DUSK := 0.65
const NIGHT := 0.75
const DAWN := 0.92

func set_time(t: float) -> void:
	time_of_day = t
	queue_redraw()

func set_moon(phase_frac: float, tide_v: float) -> void:
	moon_phase = phase_frac
	tide_rising = tide_v > tide + 0.0001
	tide = tide_v

func _draw() -> void:
	var c := Vector2(R + 3.0, R + 3.0)
	# Dark backing ring.
	draw_arc(c, R - 1.0, 0.0, TAU, 40, Color(0.05, 0.05, 0.08, 0.9), 7.0)
	# Phase arcs (0 = top, clockwise).
	_arc(c, 0.0, DUSK, Color(0.95, 0.82, 0.32))     # Day
	_arc(c, DUSK, NIGHT, Color(0.92, 0.5, 0.18))    # Dusk
	_arc(c, NIGHT, DAWN, Color(0.18, 0.2, 0.45))    # Night
	_arc(c, DAWN, 1.0, Color(0.62, 0.55, 0.82))     # Dawn
	# Inner disc.
	draw_circle(c, R - 5.0, Color(0.07, 0.07, 0.1, 0.95))
	# Moon phase (the tide clock you plan by): lit disc + sliding shadow disc = crescent.
	var mr := 6.5
	var mc := c + Vector2(0, -3.0)
	draw_circle(mc, mr, Color(0.85, 0.88, 0.95))
	var dark_amt := 1.0 - 2.0 * absf(moon_phase - 0.5)  # 0 at full, 1 at new
	if dark_amt > 0.03:
		var side := 1.0 if moon_phase < 0.5 else -1.0
		var off := (1.0 - dark_amt) * 2.4 * mr
		draw_circle(mc + Vector2(side * off, 0), mr, Color(0.07, 0.07, 0.1, 0.97))
	if GameManager.blood_moon:
		draw_circle(mc, mr, Color(0.85, 0.1, 0.1, 0.4))
	# Tide arrow under the moon: up = rising, down = ebbing.
	var ty := c + Vector2(0, 9.0)
	var tcol := Color(0.45, 0.72, 1.0)
	if tide_rising:
		draw_colored_polygon(PackedVector2Array([ty + Vector2(-4, 3), ty + Vector2(4, 3), ty + Vector2(0, -4)]), tcol)
	else:
		draw_colored_polygon(PackedVector2Array([ty + Vector2(-4, -3), ty + Vector2(4, -3), ty + Vector2(0, 4)]), tcol)
	# Hand + sun/moon marker.
	var ang := time_of_day * TAU - PI * 0.5
	var dir := Vector2(cos(ang), sin(ang))
	draw_line(c, c + dir * (R - 7.0), Color(1, 1, 1, 0.85), 2.0)
	var is_dark: bool = time_of_day >= NIGHT and time_of_day < DAWN
	var marker_col := Color(0.8, 0.85, 1.0) if is_dark else Color(1.0, 0.92, 0.4)
	draw_circle(c + dir * (R - 2.0), 4.0, marker_col)
	draw_circle(c, 2.5, Color(0.85, 0.85, 0.85))

func _arc(c: Vector2, t0: float, t1: float, col: Color) -> void:
	draw_arc(c, R - 2.5, t0 * TAU - PI * 0.5, t1 * TAU - PI * 0.5, 28, col, 4.5)
