class_name Chest
extends StaticBody2D

## A placed storage structure. For now it just exists in the world (a real storage UI is a later
## feature); this fixes the bug where crafting a chest consumed it but nothing appeared.

func _ready() -> void:
	collision_layer = 32  # structures (player collides; interact_area detects)
	collision_mask = 0

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	col.shape = shape
	col.position = Vector2(0, 2)
	add_child(col)

	var tex := Assets.item_icon("chest")  # reuse the chest icon as a placeholder world sprite
	if tex:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.show_behind_parent = true
		var s := 40.0 / float(tex.get_height())
		spr.scale = Vector2(s, s)
		add_child(spr)

func get_structure_type() -> String:
	return "chest"

func interact(_player: Player) -> void:
	# Storage UI is a future feature; the chest just exists for now.
	if GameManager.hud and GameManager.hud.has_method("show_notification"):
		GameManager.hud.show_notification("Chest (storage coming soon)")

func _draw() -> void:
	# Procedural wooden chest (fallback / when no icon texture).
	if get_child_count() <= 1:  # only the collision shape -> no sprite, draw one
		var body := Color(0.5, 0.32, 0.14)
		var lid := Color(0.6, 0.4, 0.18)
		var iron := Color(0.32, 0.28, 0.26)
		draw_rect(Rect2(-16, -4, 32, 16), body)
		draw_rect(Rect2(-16, -12, 32, 9), lid)
		draw_rect(Rect2(-16, -4, 32, 2), iron)
		draw_rect(Rect2(-3, -8, 6, 7), iron)
		draw_rect(Rect2(-16, -12, 32, 24), Color(0.2, 0.12, 0.05), false, 1.5)
