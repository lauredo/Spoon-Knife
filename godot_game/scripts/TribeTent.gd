class_name TribeTent
extends StaticBody2D

## A colony hide tent — decor with a physical footprint so the raccoon camp feels solid.

func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	col.shape = shape
	col.position = Vector2(0, 2)
	add_child(col)

func get_structure_type() -> String:
	return "tent"

func _draw() -> void:
	var hide := Color(0.62, 0.45, 0.26)
	var hide_dark := Color(0.45, 0.32, 0.18)
	draw_polygon(PackedVector2Array([Vector2(-26, 12), Vector2(0, -30), Vector2(26, 12)]),
		PackedColorArray([hide]))
	draw_polyline(PackedVector2Array([Vector2(-26, 12), Vector2(0, -30), Vector2(26, 12), Vector2(-26, 12)]),
		hide_dark, 2.0)
	# Dark doorway
	draw_polygon(PackedVector2Array([Vector2(-8, 12), Vector2(0, -6), Vector2(8, 12)]),
		PackedColorArray([Color(0.2, 0.14, 0.08)]))
	# Crossed pole tips
	draw_line(Vector2(0, -30), Vector2(-5, -38), hide_dark, 2.0)
	draw_line(Vector2(0, -30), Vector2(5, -38), hide_dark, 2.0)
