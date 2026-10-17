class_name MapMenu
extends CanvasLayer

## World map overlay (toggled with M). Fog-of-war: only cells the player has walked near are
## revealed, tinted by their biome colour. Markers: campfires (fire dot), the raccoon colony (gold
## tent + label) and the player. Exploration state lives on this node, so a fresh run starts
## with a blank map. Tracking runs even while the map is closed (cheap 0.25s poll).

const CELL := 300.0        # world px per fog cell (60x60 grid over the 18000px world)
const REVEAL_R := 400.0    # world px revealed around the player
const MAP_SIZE := 560.0    # on-screen size of the map square

var player: Player
var world_gen: WorldGenerator
var is_open: bool = false

var _explored: Dictionary = {}  # Vector2i cell -> true
var _poll: float = 0.0
var _dim: ColorRect
var _canvas: MapCanvas

## Thin drawing surface: forwards _draw to the menu so all map logic stays in one place.
class MapCanvas extends Control:
	var menu
	func _draw() -> void:
		if menu:
			menu._draw_map(self)

func _ready() -> void:
	layer = 13
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_canvas = MapCanvas.new()
	_canvas.menu = self
	_canvas.position = Vector2(640 - MAP_SIZE * 0.5, 360 - MAP_SIZE * 0.5)
	_canvas.size = Vector2(MAP_SIZE, MAP_SIZE)
	add_child(_canvas)
	_set_shown(false)

func setup(p: Player, wg: WorldGenerator) -> void:
	player = p
	world_gen = wg

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_map"):
		toggle()
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.25
		_reveal_around_player()
	if is_open:
		_canvas.queue_redraw()

func toggle() -> void:
	is_open = not is_open
	_set_shown(is_open)

func close() -> void:
	is_open = false
	_set_shown(false)

func _set_shown(v: bool) -> void:
	_dim.visible = v
	_canvas.visible = v

# ── Fog grid ────────────────────────────────────────────────────────────────

func _cell_of(p: Vector2) -> Vector2i:
	var half := WorldGenerator.HALF_WORLD
	var n := int(WorldGenerator.WORLD_SIZE / CELL)
	return Vector2i(
		clampi(int((p.x + half) / CELL), 0, n - 1),
		clampi(int((p.y + half) / CELL), 0, n - 1))

func _cell_center(cell: Vector2i) -> Vector2:
	var half := WorldGenerator.HALF_WORLD
	return Vector2(cell.x * CELL + CELL * 0.5 - half, cell.y * CELL + CELL * 0.5 - half)

func _to_map(p: Vector2) -> Vector2:
	var s := MAP_SIZE / WorldGenerator.WORLD_SIZE
	return (p + Vector2(WorldGenerator.HALF_WORLD, WorldGenerator.HALF_WORLD)) * s

## DebugMenu: reveal every fog cell at once.
func reveal_all() -> void:
	var n := int(WorldGenerator.WORLD_SIZE / CELL)
	for y in n:
		for x in n:
			_explored[Vector2i(x, y)] = true
	if is_open:
		_canvas.queue_redraw()

func _reveal_around_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	var p := player.global_position
	var reach := int(ceil(REVEAL_R / CELL))
	var center := _cell_of(p)
	var n := int(WorldGenerator.WORLD_SIZE / CELL)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := center + Vector2i(dx, dy)
			if cell.x < 0 or cell.y < 0 or cell.x >= n or cell.y >= n:
				continue
			if not _explored.has(cell) and _cell_center(cell).distance_to(p) <= REVEAL_R:
				_explored[cell] = true

# ── Drawing ─────────────────────────────────────────────────────────────────

func _draw_map(c: Control) -> void:
	var s := MAP_SIZE / WorldGenerator.WORLD_SIZE
	var font := ThemeDB.fallback_font
	# Frame + title
	c.draw_rect(Rect2(-10, -34, MAP_SIZE + 20, MAP_SIZE + 54), Color(0.08, 0.07, 0.06, 0.96))
	c.draw_rect(Rect2(-10, -34, MAP_SIZE + 20, MAP_SIZE + 54), Color(0.45, 0.35, 0.2), false, 2.0)
	c.draw_string(font, Vector2(0, -14), "Mapa  —  [M] fecha", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.85, 0.55))
	# Unexplored void
	c.draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), Color(0.02, 0.02, 0.03))
	# Explored cells, tinted by biome
	for cell in _explored:
		var mp := Vector2(cell.x * CELL, cell.y * CELL) * s
		var col := _district_color(world_gen.district_at(_cell_center(cell))) if world_gen else Color(0.3, 0.3, 0.3)
		c.draw_rect(Rect2(mp, Vector2(CELL * s + 0.6, CELL * s + 0.6)), col)
	# Campfire markers (only in explored territory; the colony's eternal fire is covered by the tent)
	var structures = GameManager.world.get_node_or_null("Structures") if GameManager.world else null
	if structures:
		for st in structures.get_children():
			if st is Campfire:
				if world_gen and st.global_position.distance_to(world_gen.colony_pos) < 60.0:
					continue
				if _explored.has(_cell_of(st.global_position)):
					var m := _to_map(st.global_position)
					c.draw_circle(m, 5.0, Color(1.0, 0.55, 0.1))
					c.draw_circle(m, 2.5, Color(1.0, 0.9, 0.4))
	# Landmark markers (POIs) — a small cyan diamond + label, once discovered.
	if world_gen:
		for lm in world_gen.landmarks:
			var lpos: Vector2 = lm["pos"]
			if not _explored.has(_cell_of(lpos)):
				continue
			var m := _to_map(lpos)
			c.draw_colored_polygon(
				PackedVector2Array([m + Vector2(0, -6), m + Vector2(5, 0), m + Vector2(0, 6), m + Vector2(-5, 0)]),
				Color(0.5, 0.85, 0.95))
			c.draw_string(font, m + Vector2(-16, -8), lm["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.75, 0.9, 0.95))

	# Raccoon colony marker
	if world_gen and _explored.has(_cell_of(world_gen.colony_pos)):
		var t := _to_map(world_gen.colony_pos)
		c.draw_polygon(
			PackedVector2Array([t + Vector2(-8, 6), t + Vector2(0, -8), t + Vector2(8, 6)]),
			PackedColorArray([Color(0.95, 0.8, 0.3)]))
		c.draw_string(font, t + Vector2(-20, 20), "Colônia", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.85, 0.55))
	# Player marker
	if player and is_instance_valid(player):
		var pm := _to_map(player.global_position)
		c.draw_circle(pm, 4.0, Color.WHITE)
		c.draw_arc(pm, 7.5, 0, TAU, 16, Color(1, 1, 1, 0.6), 1.5)

	_draw_legend(c, font)

## Legend box (bottom-right corner of the map) naming every marker kind.
func _draw_legend(c: Control, font: Font) -> void:
	var box := Rect2(Vector2(MAP_SIZE - 148, MAP_SIZE - 90), Vector2(142, 84))
	c.draw_rect(box, Color(0.05, 0.05, 0.06, 0.88))
	c.draw_rect(box, Color(0.45, 0.35, 0.2, 0.7), false, 1.0)
	var x := box.position.x + 13.0
	var y := box.position.y + 16.0
	var text_col := Color(0.85, 0.85, 0.82)
	# You
	c.draw_circle(Vector2(x, y), 3.5, Color.WHITE)
	c.draw_string(font, Vector2(x + 12, y + 4), "Você", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_col)
	y += 18.0
	# Campfire
	c.draw_circle(Vector2(x, y), 4.5, Color(1.0, 0.55, 0.1))
	c.draw_circle(Vector2(x, y), 2.2, Color(1.0, 0.9, 0.4))
	c.draw_string(font, Vector2(x + 12, y + 4), "Fogueira", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_col)
	y += 18.0
	# Colony
	c.draw_polygon(
		PackedVector2Array([Vector2(x - 5, y + 4), Vector2(x, y - 5), Vector2(x + 5, y + 4)]),
		PackedColorArray([Color(0.95, 0.8, 0.3)]))
	c.draw_string(font, Vector2(x + 12, y + 4), "Colônia", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_col)
	y += 18.0
	# Landmark / POI
	c.draw_colored_polygon(
		PackedVector2Array([Vector2(x, y - 5), Vector2(x + 4.5, y), Vector2(x, y + 5), Vector2(x - 4.5, y)]),
		Color(0.5, 0.85, 0.95))
	c.draw_string(font, Vector2(x + 12, y + 4), "Ponto de interesse", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_col)

func _district_color(d: int) -> Color:
	match d:
		WorldGenerator.District.FOREST: return Color(0.15, 0.32, 0.15)
		WorldGenerator.District.VILLAGE: return Color(0.45, 0.40, 0.36)
		WorldGenerator.District.MARINA: return Color(0.55, 0.55, 0.58)
		WorldGenerator.District.BEACH: return Color(0.6, 0.55, 0.38)
		WorldGenerator.District.SEA: return Color(0.09, 0.22, 0.34)
		WorldGenerator.District.ISLAND: return Color(0.2, 0.4, 0.22)
	return Color(0.2, 0.2, 0.2)
