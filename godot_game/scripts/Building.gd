class_name Building
extends StaticBody2D

## A city building: four walls with a door gap, and a roof that FADES OUT while the player is
## inside (see MUNDO.md → "Interiores"). The interior is part of the same world — no scene swap, no
## teleport, so stats/day-night/weather/mobs never know you "entered".
##
## The roof is a Polygon2D on a high absolute z_index so it draws over the Y-sorted world (and over
## the player) until you step in. Walls sit on the World layer, so the player AND mobs collide with
## them — and since mobs walk in straight lines (no pathfinding), they can't find the door: a
## building is a REFUGE, by design.

const T := 16.0        # wall thickness
const DOOR_W := 80.0   # door gap
const FADE_SPEED := 5.0

const FENCE_MARGIN := 46.0

var size: Vector2 = Vector2(360, 300)
var door_side: int = 2  # 0=N, 1=E, 2=S, 3=W
var wall_col: Color = Color(0.55, 0.52, 0.48)
var floor_col: Color = Color(0.26, 0.24, 0.23)
var roof_col: Color = Color(0.38, 0.35, 0.33)
var has_fence: bool = false  # fenced yard (residential); decorative — a raccoon hops it

var _roof: Polygon2D
var _inside: bool = false

func _ready() -> void:
	collision_layer = 1  # World — player and mobs bump the walls
	collision_mask = 0
	# Floor + walls must NEVER win the Y-sort against the player: this node is big, and Y-sorting
	# uses the node ORIGIN, so standing in the building's upper half made the floor draw OVER the
	# raccoon (it vanished). Pin the shell below every entity; the roof child keeps its own
	# absolute z=100 so it still covers you from above while opaque.
	z_index = -5
	z_as_relative = false
	_build_walls()
	if has_fence:
		_build_fence_collision()
	_build_roof()
	_build_trigger()
	set_process(false)  # only ticks while the roof is fading

func get_structure_type() -> String:
	return "building"

# ── Walls ───────────────────────────────────────────────────────────────────

func _build_walls() -> void:
	var w := size.x
	var h := size.y
	_wall_or_door(0, Vector2(0, -h * 0.5 + T * 0.5), Vector2(w, T), true)
	_wall_or_door(2, Vector2(0, h * 0.5 - T * 0.5), Vector2(w, T), true)
	_wall_or_door(3, Vector2(-w * 0.5 + T * 0.5, 0), Vector2(T, h), false)
	_wall_or_door(1, Vector2(w * 0.5 - T * 0.5, 0), Vector2(T, h), false)

## Adds a solid wall, or two segments with a gap when this side holds the door.
func _wall_or_door(side: int, center: Vector2, wsize: Vector2, horizontal: bool) -> void:
	if door_side != side:
		_add_wall(center, wsize)
		return
	if horizontal:
		var seg := (wsize.x - DOOR_W) * 0.5
		_add_wall(center + Vector2(-(DOOR_W + seg) * 0.5, 0), Vector2(seg, wsize.y))
		_add_wall(center + Vector2((DOOR_W + seg) * 0.5, 0), Vector2(seg, wsize.y))
	else:
		var seg := (wsize.y - DOOR_W) * 0.5
		_add_wall(center + Vector2(0, -(DOOR_W + seg) * 0.5), Vector2(wsize.x, seg))
		_add_wall(center + Vector2(0, (DOOR_W + seg) * 0.5), Vector2(wsize.x, seg))

## Solid yard fence, matching the drawn rails and leaving the door side open as the gate. The
## collision is deliberately THICKER than the 4px rail is drawn: the player moves 220px/s (500 while
## dodging ≈ 8px per physics frame), and move_and_slide has no continuous detection — a hairline
## collider would be tunnelled straight through.
func _build_fence_collision() -> void:
	const FT := 14.0
	var w := size.x * 0.5 + FENCE_MARGIN
	var h := size.y * 0.5 + FENCE_MARGIN
	if door_side != 0:
		_add_wall(Vector2(0.0, -h), Vector2(w * 2.0, FT))
	if door_side != 2:
		_add_wall(Vector2(0.0, h), Vector2(w * 2.0, FT))
	if door_side != 3:
		_add_wall(Vector2(-w, 0.0), Vector2(FT, h * 2.0))
	if door_side != 1:
		_add_wall(Vector2(w, 0.0), Vector2(FT, h * 2.0))

func _add_wall(center: Vector2, wsize: Vector2) -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = wsize
	col.shape = shape
	col.position = center
	add_child(col)

# ── Roof + entry trigger ────────────────────────────────────────────────────

func _build_roof() -> void:
	var w := size.x
	var h := size.y
	_roof = Polygon2D.new()
	_roof.name = "Roof"
	_roof.polygon = PackedVector2Array([
		Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
		Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5)])
	_roof.color = roof_col
	# Absolute z so it covers the Y-sorted world (including the player) while opaque.
	_roof.z_index = 100
	_roof.z_as_relative = false
	add_child(_roof)
	_add_door_marker()

## With the roof opaque you can't see the gap in the wall, so the entrance would be invisible from
## outside — you'd have to grope around the whole building. This paints a little door on the roof's
## edge at the door side. It's a CHILD of the roof, so it inherits the fade: once you're inside and
## the roof is gone, the real gap in the wall speaks for itself.
func _add_door_marker() -> void:
	var w := size.x
	var h := size.y
	var d := DOOR_W * 0.5
	var t := T + 10.0
	var frame_rect: Rect2
	match door_side:
		0: frame_rect = Rect2(-d, -h * 0.5 - 3.0, DOOR_W, t)
		2: frame_rect = Rect2(-d, h * 0.5 - t + 3.0, DOOR_W, t)
		3: frame_rect = Rect2(-w * 0.5 - 3.0, -d, t, DOOR_W)
		_: frame_rect = Rect2(w * 0.5 - t + 3.0, -d, t, DOOR_W)
	_roof.add_child(_rect_poly(frame_rect, Color(0.86, 0.72, 0.35), 1))          # bright frame
	_roof.add_child(_rect_poly(frame_rect.grow(-4.0), Color(0.35, 0.20, 0.10), 2))  # the door itself

func _rect_poly(r: Rect2, col: Color, z: int) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		r.position, r.position + Vector2(r.size.x, 0.0), r.end, r.position + Vector2(0.0, r.size.y)])
	p.color = col
	p.z_index = z  # relative to the roof, so it rides along with the fade
	return p

func _build_trigger() -> void:
	var area := Area2D.new()
	area.name = "InsideTrigger"
	area.collision_layer = 0
	area.collision_mask = 2  # player only
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size - Vector2(T * 2.0 + 8.0, T * 2.0 + 8.0)
	col.shape = shape
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(_on_entered)
	area.body_exited.connect(_on_exited)

func _on_entered(body: Node) -> void:
	if body is Player:
		_inside = true
		set_process(true)
		body.set_indoors(true)  # a roof over your head: shelter from rain (temperatura, S5)

func _on_exited(body: Node) -> void:
	if body is Player:
		_inside = false
		set_process(true)
		body.set_indoors(false)

func _process(delta: float) -> void:
	var target := 0.0 if _inside else 1.0
	_roof.modulate.a = move_toward(_roof.modulate.a, target, delta * FADE_SPEED)
	if is_equal_approx(_roof.modulate.a, target):
		set_process(false)  # idle buildings cost nothing

# ── Draw (floor + walls; the roof is its own node) ──────────────────────────

func _draw() -> void:
	var w := size.x
	var h := size.y
	if has_fence:
		_draw_fence()
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), floor_col)
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, T), wall_col)
	draw_rect(Rect2(-w * 0.5, h * 0.5 - T, w, T), wall_col)
	draw_rect(Rect2(-w * 0.5, -h * 0.5, T, h), wall_col)
	draw_rect(Rect2(w * 0.5 - T, -h * 0.5, T, h), wall_col)
	# Punch the doorway back out to floor.
	match door_side:
		0: draw_rect(Rect2(-DOOR_W * 0.5, -h * 0.5, DOOR_W, T), floor_col)
		2: draw_rect(Rect2(-DOOR_W * 0.5, h * 0.5 - T, DOOR_W, T), floor_col)
		3: draw_rect(Rect2(-w * 0.5, -DOOR_W * 0.5, T, DOOR_W), floor_col)
		1: draw_rect(Rect2(w * 0.5 - T, -DOOR_W * 0.5, T, DOOR_W), floor_col)
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), wall_col.darkened(0.35), false, 2.0)

## A little wooden yard fence. The door side is left OPEN — that gap is the gate, and it points at
## the entrance. SOLID (see _build_fence_collision): you go in through the gate, which also means a
## fenced yard is a refuge — the street dogs can't follow you over it.
func _draw_fence() -> void:
	var w := size.x * 0.5 + FENCE_MARGIN
	var h := size.y * 0.5 + FENCE_MARGIN
	var rail := Color(0.55, 0.40, 0.22)
	var post := Color(0.42, 0.29, 0.15)
	if door_side != 0:
		draw_rect(Rect2(-w, -h - 2.0, w * 2.0, 4.0), rail)
	if door_side != 2:
		draw_rect(Rect2(-w, h - 2.0, w * 2.0, 4.0), rail)
	if door_side != 3:
		draw_rect(Rect2(-w - 2.0, -h, 4.0, h * 2.0), rail)
	if door_side != 1:
		draw_rect(Rect2(w - 2.0, -h, 4.0, h * 2.0), rail)
	var x := -w
	while x <= w:
		if door_side != 0:
			draw_rect(Rect2(x - 2.5, -h - 6.0, 5.0, 13.0), post)
		if door_side != 2:
			draw_rect(Rect2(x - 2.5, h - 6.0, 5.0, 13.0), post)
		x += 46.0
	var y := -h
	while y <= h:
		if door_side != 3:
			draw_rect(Rect2(-w - 6.0, y - 2.5, 13.0, 5.0), post)
		if door_side != 1:
			draw_rect(Rect2(w - 6.0, y - 2.5, 13.0, 5.0), post)
		y += 46.0
