class_name Landmark
extends StaticBody2D

## A hand-placed point of interest — the payoff of exploring. Each kind reads as a distinct PLACE
## and is paired (by WorldGenerator) with a reward: the abandoned camp has a loot chest, the ancient
## tree anchors a wood grove, the cave a rock cluster. The cemetery is pure dread — standing in it
## at night bleeds sanity. Discovered landmarks get a map marker.

enum Kind { ABANDONED_CAMP, ANCIENT_TREE, CAVE, CEMETERY }

const CEMETERY_DRAIN := 5.0       # sanity/min at night within CEMETERY_RADIUS
const CEMETERY_RADIUS := 220.0

var kind: int = Kind.ABANDONED_CAMP
var _t: float = 0.0

func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 24.0 if kind == Kind.ANCIENT_TREE else 16.0
	col.shape = shape
	add_child(col)
	set_process(kind == Kind.CEMETERY)  # only the graveyard needs a tick

func get_structure_type() -> String:
	return "landmark"

func label() -> String:
	match kind:
		Kind.ABANDONED_CAMP: return "Acampamento Abandonado"
		Kind.ANCIENT_TREE: return "Árvore Anciã"
		Kind.CAVE: return "Caverna"
		Kind.CEMETERY: return "Cemitério"
	return "Lugar"

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	var p = GameManager.player
	if p and is_instance_valid(p) and p.stats and not p.stats.is_day:
		if global_position.distance_to(p.global_position) < CEMETERY_RADIUS:
			p.stats.drain_sanity(CEMETERY_DRAIN / 60.0 * delta)

func _draw() -> void:
	match kind:
		Kind.ABANDONED_CAMP: _draw_camp()
		Kind.ANCIENT_TREE: _draw_ancient_tree()
		Kind.CAVE: _draw_cave()
		Kind.CEMETERY: _draw_cemetery()

func _draw_camp() -> void:
	# Cold ash ring + charred logs, a fallen bone or two — someone was here.
	for i in 8:
		var a := float(i) / 8.0 * TAU
		draw_circle(Vector2(cos(a) * 18, sin(a) * 14), 3.0, Color(0.4, 0.4, 0.42))
	draw_line(Vector2(-10, 4), Vector2(10, -3), Color(0.18, 0.15, 0.13), 5.0)
	draw_line(Vector2(-10, -3), Vector2(10, 4), Color(0.2, 0.17, 0.14), 5.0)
	draw_circle(Vector2(0, 0), 6.0, Color(0.28, 0.24, 0.2))
	var bone := Color(0.85, 0.82, 0.72)
	draw_line(Vector2(20, 14), Vector2(30, 18), bone, 3.0)
	draw_circle(Vector2(20, 14), 2.2, bone)
	draw_circle(Vector2(30, 18), 2.2, bone)

func _draw_ancient_tree() -> void:
	# A huge gnarled tree — a landmark you can see from afar.
	draw_rect(Rect2(-14, -20, 28, 54), Color(0.36, 0.24, 0.12))
	draw_rect(Rect2(-14, -20, 28, 54), Color(0.26, 0.17, 0.08), false, 2.0)
	draw_circle(Vector2(0, -60 + sin(_t) * 2.0), 52, Color(0.14, 0.42, 0.16))
	draw_circle(Vector2(-26, -44 + sin(_t * 1.1) * 2.0), 32, Color(0.16, 0.46, 0.18))
	draw_circle(Vector2(28, -48 + sin(_t * 0.9) * 2.0), 34, Color(0.18, 0.5, 0.2))
	draw_circle(Vector2(0, -78 + sin(_t * 1.3) * 2.0), 26, Color(0.2, 0.54, 0.22))

func _draw_cave() -> void:
	# A rocky mound with a black mouth.
	draw_polygon(PackedVector2Array([
		Vector2(-40, 18), Vector2(-30, -18), Vector2(0, -32), Vector2(30, -16), Vector2(40, 18)]),
		PackedColorArray([Color(0.42, 0.42, 0.46)]))
	draw_polyline(PackedVector2Array([
		Vector2(-40, 18), Vector2(-30, -18), Vector2(0, -32), Vector2(30, -16), Vector2(40, 18)]),
		Color(0.3, 0.3, 0.34), 2.0)
	draw_polygon(PackedVector2Array([
		Vector2(-15, 18), Vector2(-12, -6), Vector2(0, -14), Vector2(12, -6), Vector2(15, 18)]),
		PackedColorArray([Color(0.03, 0.02, 0.05)]))

func _draw_cemetery() -> void:
	# A cluster of leaning gravestones + a skull. Creepier at night (the tick drains sanity).
	var stone := Color(0.5, 0.5, 0.54)
	_grave(Vector2(-22, 6), 0.15, stone)
	_grave(Vector2(2, 0), -0.1, stone)
	_grave(Vector2(24, 8), 0.2, stone.darkened(0.08))
	var bone := Color(0.86, 0.83, 0.74)
	draw_circle(Vector2(-6, 18), 5.0, bone)
	draw_circle(Vector2(-8, 17), 1.2, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(-4, 17), 1.2, Color(0.1, 0.1, 0.1))

func _grave(pos: Vector2, tilt: float, col: Color) -> void:
	draw_set_transform(pos, tilt, Vector2.ONE)
	draw_rect(Rect2(-9, -22, 18, 26), col)
	draw_rect(Rect2(-3, -30, 6, 10), col)   # cross vertical
	draw_rect(Rect2(-8, -27, 16, 5), col)   # cross arms
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
