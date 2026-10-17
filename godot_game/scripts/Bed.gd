class_name Bed
extends StaticBody2D

## A rag bed — the energy-recovery spot (S5). One free at the den; more are craftable (cloth +
## grass). E → sleep: time runs 4x but the night is LIVED, not skipped — damage or any key wakes
## you (see Player.start_sleeping). Static on the structures layer like the chest/trader.

func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(46, 26)
	col.shape = shape
	add_child(col)

func get_structure_type() -> String:
	return "bed"

func interact(player: Player) -> void:
	player.start_sleeping(self)

func _draw() -> void:
	# Patchwork rag mattress + a lighter pillow, scrappy raccoon-den style.
	var cloth := Color(0.62, 0.5, 0.38)
	draw_rect(Rect2(-23, -13, 46, 26), cloth)
	draw_rect(Rect2(-23, -13, 46, 26), cloth.darkened(0.35), false, 2.0)
	draw_rect(Rect2(-19, -9, 14, 10), Color(0.82, 0.76, 0.64))          # pillow
	draw_rect(Rect2(2, -2, 12, 9), cloth.darkened(0.15))                # patch
	draw_line(Vector2(-2, 6), Vector2(6, 6), cloth.darkened(0.4), 1.5)  # stitch
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-24, -20), "[E] Dormir", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.9, 0.6, 0.85))
