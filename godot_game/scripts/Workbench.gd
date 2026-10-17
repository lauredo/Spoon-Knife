class_name Workbench
extends StaticBody2D

## A crafting station. Just like the campfire gates cooking, standing near a workbench unlocks the
## "armor" recipes (they declare requires_structure = "workbench", checked by
## GameManager.get_nearby_structures). No interaction needed — its presence nearby is enough.

func _ready() -> void:
	collision_layer = 32  # structures: player bumps it; the nearby-structure scan picks it up
	collision_mask = 0

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(42, 26)
	col.shape = shape
	col.position = Vector2(0, 2)
	add_child(col)

func get_structure_type() -> String:
	return "workbench"

func _draw() -> void:
	# Procedural carpenter's bench: a thick wooden top on four legs, a plank and a saw blade.
	var wood := Color(0.5, 0.34, 0.17)
	var wood_dark := Color(0.34, 0.22, 0.11)
	var metal := Color(0.72, 0.74, 0.8)
	# Legs
	draw_rect(Rect2(-20, 0, 4, 14), wood_dark)
	draw_rect(Rect2(16, 0, 4, 14), wood_dark)
	draw_rect(Rect2(-15, 2, 4, 12), wood_dark)
	draw_rect(Rect2(11, 2, 4, 12), wood_dark)
	# Bench top
	draw_rect(Rect2(-24, -8, 48, 10), wood)
	draw_rect(Rect2(-24, -8, 48, 10), wood_dark, false, 1.5)
	# Plank resting on top
	draw_rect(Rect2(-17, -13, 28, 5), wood.lightened(0.12))
	draw_rect(Rect2(-17, -13, 28, 5), wood_dark, false, 1.0)
	# Saw blade leaning against it
	draw_line(Vector2(6, -10), Vector2(22, -20), metal, 2.0)
	draw_line(Vector2(6, -10), Vector2(9, -12), wood_dark, 3.0)
