class_name StreetLight
extends StaticBody2D

## City street lamp — the safe-light corridors of the living districts (GDD S3). Shines through
## dusk/night and counts as LIGHT for sanity (same pool mechanic as a campfire). The grid dies with
## the city: night 1 every lamp works, night 2 the doomed half fails (alongside the Blood Moon),
## night 3+ blackout forever. Learning which streets still have power IS the map knowledge.

const LIGHT_RADIUS := 260.0

var doomed: bool = false   # this one fails on night 2
var _light: PointLight2D
var _area: Area2D
var _on: bool = false
var _poll: float = 0.0

func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	col.shape = shape
	add_child(col)

	_light = PointLight2D.new()
	_light.texture = Assets.light_texture()
	_light.texture_scale = LIGHT_RADIUS / 128.0
	_light.color = Color(1.0, 0.87, 0.6)
	_light.energy = 1.05
	_light.position = Vector2(0, -34)
	_light.enabled = false
	add_child(_light)

	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2  # player
	var acol := CollisionShape2D.new()
	var ashape := CircleShape2D.new()
	ashape.radius = LIGHT_RADIUS * 0.9
	acol.shape = ashape
	_area.add_child(acol)
	add_child(_area)
	_area.body_entered.connect(_on_body_in)
	_area.body_exited.connect(_on_body_out)

func get_structure_type() -> String:
	return "street_light"

## The blackout schedule (GDD): day 1 all on, day 2 the doomed half dies, day 3+ nothing.
func works_tonight() -> bool:
	var d: int = GameManager.current_day
	if d <= 1:
		return true
	if d == 2:
		return not doomed
	return false

func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.4
	var want := _is_dark() and works_tonight()
	if want != _on:
		_set_on(want)

func _is_dark() -> bool:
	var p = GameManager.player
	return p != null and is_instance_valid(p) and p.stats != null and not p.stats.is_day

func _set_on(v: bool) -> void:
	_on = v
	_light.enabled = v
	# Anyone already standing in the pool gets the light state change immediately.
	for b in _area.get_overlapping_bodies():
		if b is Player:
			b.set_near_light(v)
	queue_redraw()

func _on_body_in(b: Node) -> void:
	if b is Player and _on:
		b.set_near_light(true)

func _on_body_out(b: Node) -> void:
	if b is Player and _on:
		b.set_near_light(false)

func _draw() -> void:
	var pole := Color(0.3, 0.32, 0.35)
	draw_rect(Rect2(-2.5, -36, 5, 40), pole)
	draw_rect(Rect2(-7, -44, 14, 6), pole.darkened(0.15))
	var bulb := Color(1.0, 0.9, 0.6) if _on else Color(0.38, 0.38, 0.4)
	draw_rect(Rect2(-5, -41, 10, 5), bulb)
	if _on:
		draw_circle(Vector2(0, -38), 7.0, Color(1.0, 0.9, 0.6, 0.25))
