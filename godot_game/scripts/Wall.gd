class_name Wall
extends StaticBody2D

## A solid stone barrier for base defence. It sits on the "World" collision layer, so BOTH the
## player and every mob (baratas, shadows, the boss) collide with it — a ring of walls actually
## keeps things out. Cheap to build from stone, which otherwise had no use.

const SIZE := Vector2(40, 40)

func _ready() -> void:
	collision_layer = 1  # World — player (mask 1) and mobs (mask 1) both collide => real barrier
	collision_mask = 0

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	col.shape = shape
	add_child(col)

func _draw() -> void:
	var stone := Color(0.5, 0.5, 0.53)
	var stone_dark := Color(0.32, 0.32, 0.35)
	var stone_light := Color(0.63, 0.63, 0.67)
	var r := Rect2(-SIZE.x * 0.5, -SIZE.y * 0.5, SIZE.x, SIZE.y)
	draw_rect(r, stone)
	# Brick courses (offset every other row).
	for row in 3:
		var y := -SIZE.y * 0.5 + 4.0 + row * 12.0
		draw_line(Vector2(-SIZE.x * 0.5, y), Vector2(SIZE.x * 0.5, y), stone_dark, 1.5)
		var off := 0.0 if row % 2 == 0 else 10.0
		draw_line(Vector2(-SIZE.x * 0.5 + off + 12, y), Vector2(-SIZE.x * 0.5 + off + 12, y + 12.0), stone_dark, 1.5)
		draw_line(Vector2(-SIZE.x * 0.5 + off + 28, y), Vector2(-SIZE.x * 0.5 + off + 28, y + 12.0), stone_dark, 1.5)
	draw_rect(r, stone_dark, false, 2.0)
	draw_line(Vector2(-SIZE.x * 0.5, -SIZE.y * 0.5 + 1.0), Vector2(SIZE.x * 0.5, -SIZE.y * 0.5 + 1.0), stone_light, 1.5)
