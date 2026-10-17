class_name CrowTrader
extends StaticBody2D

## The colony's trader — a crow behind a little stall, obsessed with shiny things. Interact (E)
## toggles the barter panel (TradeMenu). Static on the structures layer so the player's
## InteractArea picks it up exactly like a chest.

var _bob: float = 0.0

func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	col.shape = shape
	add_child(col)

func get_structure_type() -> String:
	return "trader"

func interact(player: Player) -> void:
	var menu = GameManager.trade_menu
	if menu == null:
		return
	if menu.is_open:
		menu.close()
	else:
		menu.open(player, self)

func _process(delta: float) -> void:
	_bob += delta * 2.0
	queue_redraw()

func _draw() -> void:
	var bob := sin(_bob) * 1.5
	# Stall table
	draw_rect(Rect2(-24, 6, 48, 8), Color(0.5, 0.34, 0.17))
	draw_rect(Rect2(-22, 14, 4, 8), Color(0.34, 0.22, 0.11))
	draw_rect(Rect2(18, 14, 4, 8), Color(0.34, 0.22, 0.11))
	# Crow trader (idle bob)
	var feathers := Color(0.13, 0.13, 0.17)
	draw_circle(Vector2(0, -6 + bob * 0.4), 11, feathers)
	draw_circle(Vector2(0, -19 + bob), 7, feathers.lightened(0.08))
	# Folded wing over the body
	draw_line(Vector2(-8, -8 + bob * 0.4), Vector2(6, 2 + bob * 0.4), feathers.lightened(0.15), 3.0)
	# Tail feathers
	draw_line(Vector2(8, 0 + bob * 0.4), Vector2(16, 6 + bob * 0.4), feathers, 4.0)
	# Beak (pointed, slightly open toward the goods)
	var beak := Color(0.9, 0.65, 0.15)
	draw_polygon(PackedVector2Array([Vector2(-6, -20 + bob), Vector2(-16, -16 + bob), Vector2(-5, -16 + bob)]), PackedColorArray([beak]))
	# Bright greedy eye
	draw_circle(Vector2(-2, -21 + bob), 1.8, Color(0.95, 0.9, 0.5))
	draw_circle(Vector2(-2, -21 + bob), 0.9, Color(0.05, 0.05, 0.05))
	# Goods on the table (the shiny one gleams — it's what the crow really wants)
	draw_circle(Vector2(-12, 4), 4, Color(0.95, 0.55, 0.15))
	draw_circle(Vector2(0, 3), 4, Color(0.9, 0.9, 0.97))
	draw_circle(Vector2(12, 4), 4, Color(1.0, 0.95, 0.55))
	draw_circle(Vector2(13, 3), 1.2, Color(1.0, 1.0, 0.9))
	# Hint sign
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-26, -46), "[E] Trocar", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.9, 0.6, 0.9))
