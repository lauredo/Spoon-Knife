class_name QuestBoard
extends StaticBody2D

## The colony's mission board (S4). Interact (E) toggles the QuestMenu — the endless game's
## "what now?" answer lives here.

func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 14)
	col.shape = shape
	col.position = Vector2(0, 4)
	add_child(col)

func get_structure_type() -> String:
	return "quest_board"

func interact(_player: Player) -> void:
	var menu = GameManager.quest_menu
	if menu == null:
		return
	if menu.is_open:
		menu.close()
	else:
		menu.open(self)

func _draw() -> void:
	# Wooden notice board with pinned papers.
	var wood := Color(0.5, 0.35, 0.18)
	draw_rect(Rect2(-20, -2, 5, 16), wood.darkened(0.25))
	draw_rect(Rect2(15, -2, 5, 16), wood.darkened(0.25))
	draw_rect(Rect2(-24, -34, 48, 34), wood)
	draw_rect(Rect2(-24, -34, 48, 34), wood.darkened(0.4), false, 2.0)
	draw_rect(Rect2(-18, -29, 16, 20), Color(0.92, 0.89, 0.8))
	draw_rect(Rect2(1, -27, 14, 16), Color(0.88, 0.86, 0.76))
	draw_circle(Vector2(-10, -27), 1.5, Color(0.8, 0.25, 0.2))
	draw_circle(Vector2(8, -25), 1.5, Color(0.25, 0.4, 0.8))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-28, 26), "[E] Missões", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.9, 0.6, 0.9))
