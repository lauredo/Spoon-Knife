class_name FarmPlot
extends StaticBody2D

## A tilled plot. Press E with seeds to plant; it grows over ~100s of game time (scaled by the
## fast-forward), then E again harvests carrots and it returns to empty to replant. Renewable
## food — this is what finally gives `seeds` (dropped by bushes and boars) a purpose.

enum State { EMPTY, GROWING, READY }

const GROW_TIME := 100.0   # game-seconds from planting to ripe
const CROP := "carrot"
const YIELD_MIN := 1
const YIELD_MAX := 2

var state: int = State.EMPTY
var grow_timer: float = 0.0

func _ready() -> void:
	collision_layer = 32  # structures: player bumps it; the InteractArea (E) detects it
	collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	col.shape = shape
	add_child(col)

func get_structure_type() -> String:
	return "farm_plot"

func _process(delta: float) -> void:
	if state == State.GROWING:
		grow_timer -= delta
		if grow_timer <= 0.0:
			grow_timer = 0.0
			state = State.READY
			_notify("Colheita pronta!")
		queue_redraw()

func interact(player: Player) -> void:
	match state:
		State.EMPTY:
			if player.inventory.has_item("seeds"):
				player.inventory.remove_item("seeds", 1)
				state = State.GROWING
				grow_timer = GROW_TIME
				_notify("Plantado")
				queue_redraw()
			else:
				_notify("Precisa de sementes")
		State.READY:
			var amount := randi_range(YIELD_MIN, YIELD_MAX)
			player.inventory.add_item(CROP, amount)
			state = State.EMPTY
			grow_timer = 0.0
			_notify("Colhido: %d cenoura(s)" % amount)
			queue_redraw()
		State.GROWING:
			_notify("Crescendo...")

func _notify(msg: String) -> void:
	if GameManager.hud and GameManager.hud.has_method("show_notification"):
		GameManager.hud.show_notification(msg)

func _draw() -> void:
	# Tilled soil bed with furrows.
	var soil := Color(0.34, 0.22, 0.12)
	var soil_dark := Color(0.24, 0.15, 0.08)
	draw_rect(Rect2(-20, -12, 40, 26), soil)
	draw_rect(Rect2(-20, -12, 40, 26), soil_dark, false, 1.5)
	for i in 3:
		var fy := -8.0 + i * 8.0
		draw_line(Vector2(-18, fy), Vector2(18, fy), soil_dark, 1.0)

	match state:
		State.EMPTY:
			for i in 3:
				draw_circle(Vector2(-12.0 + i * 12.0, 2.0), 1.6, soil_dark)
		State.GROWING:
			var p: float = 1.0 - clampf(grow_timer / GROW_TIME, 0.0, 1.0)
			var h := 2.0 + p * 14.0
			for i in 3:
				var x := -12.0 + i * 12.0
				draw_line(Vector2(x, 6.0), Vector2(x, 6.0 - h), Color(0.3, 0.6, 0.2), 2.0)
				if p > 0.4:
					draw_circle(Vector2(x, 6.0 - h), 2.0 + p * 2.0, Color(0.35, 0.7, 0.25))
		State.READY:
			for i in 3:
				var x := -12.0 + i * 12.0
				draw_line(Vector2(x, 6.0), Vector2(x, -10.0), Color(0.3, 0.6, 0.2), 2.0)
				draw_circle(Vector2(x, -10.0), 4.0, Color(0.3, 0.65, 0.2))
				draw_circle(Vector2(x, 4.0), 2.5, Color(0.95, 0.55, 0.15))  # carrot top poking out
			var font := ThemeDB.fallback_font
			draw_string(font, Vector2(-16, 28), "[E] Colher", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.95, 0.6, 0.9))
