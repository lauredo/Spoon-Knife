class_name DropItem
extends RigidBody2D

var item_id: String = ""
var amount: int = 1
var attract_timer: float = 0.0
var magnetize_to: Node = null
var icon_sprite: Sprite2D = null

# Vertical "toss" so loot pops out and LANDS with weight instead of gliding like a bubble.
const HOP_GRAVITY := 1100.0
var _hop_h: float = 0.0      # current height above rest (px)
var _hop_v: float = 0.0      # vertical velocity (px/s, + = up)
var _rest_y: float = 0.0     # icon's resting y
var _landed: bool = true     # no hop until a sprite + initial pop is set

func _ready() -> void:
	collision_layer = 16
	collision_mask = 1

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	col.shape = shape
	add_child(col)

	gravity_scale = 0.0
	linear_damp = 5.0  # higher = the scatter settles quickly instead of drifting (no floaty glide)

	# Small ground scatter; damping settles it fast.
	linear_velocity = Vector2(randf_range(-45, 45), randf_range(-45, 45))

func setup(_item_id: String, _amount: int = 1) -> void:
	item_id = _item_id
	amount = _amount
	_setup_icon()

func _setup_icon() -> void:
	# Prefer a dedicated "on the ground" sprite (drops/<id>.png) over the flat inventory icon.
	var target_h := 26.0
	var icon := Assets.sprite("drops", item_id)
	if icon != null:
		target_h = 32.0  # ground sprites are more detailed; give them a touch more size
	else:
		icon = Assets.item_icon(item_id)
	if icon == null:
		return
	icon_sprite = Sprite2D.new()
	icon_sprite.texture = icon
	icon_sprite.show_behind_parent = true  # keep shadow + count drawn on top
	var s := target_h / float(icon.get_height())
	icon_sprite.scale = Vector2(s, s)
	# Rest the sprite on the ground (its bottom near the shadow) instead of floating.
	icon_sprite.position = Vector2(0, 12.0 - target_h * 0.5)
	add_child(icon_sprite)

	# Kick off the toss: pop up, then fall under gravity and settle with a tiny bounce.
	_rest_y = icon_sprite.position.y
	_hop_h = 0.0
	_hop_v = randf_range(150.0, 210.0)
	_landed = false

func _process(delta: float) -> void:
	# Vertical toss/land animation (purely visual; the body only moves horizontally).
	if not _landed and icon_sprite != null:
		_hop_v -= HOP_GRAVITY * delta
		_hop_h += _hop_v * delta
		if _hop_h <= 0.0:
			_hop_h = 0.0
			if _hop_v < -55.0:
				_hop_v = -_hop_v * 0.32  # one small bounce
			else:
				_hop_v = 0.0
				_landed = true
		icon_sprite.position.y = _rest_y - _hop_h

	attract_timer -= delta
	if is_instance_valid(magnetize_to) and attract_timer <= 0:
		var dir: Vector2 = (magnetize_to.global_position - global_position)
		if dir.length() < 40.0:
			pickup(magnetize_to)
		else:
			linear_velocity = dir.normalized() * 180.0

func pickup(player: Player) -> void:
	var added := player.inventory.add_item(item_id, amount)
	if added > 0:
		queue_free()

## Picked up by pressing INTERACT (E) while near it — routed through the player's interactable
## system, exactly like harvesting a grass tuft. Loot is never auto-collected; it waits on the
## ground until you grab it.
func interact(player: Player) -> void:
	pickup(player)

func attract(player: Node) -> void:
	magnetize_to = player
	attract_timer = 0.5  # Small delay before magnetizing

func _draw() -> void:
	# Shadow on the ground
	_draw_ellipse(Vector2(0, 12), Vector2(9, 3), 0, TAU, Color(0, 0, 0, 0.25), 0, true)

	# Procedural blob only when there is no icon sprite (fallback), resting on the ground.
	if icon_sprite == null:
		var item_data = ItemDatabase.get_item(item_id)
		var color := Color(0.8, 0.8, 0.8)
		if item_data:
			color = item_data.color
		draw_circle(Vector2(0, 2), 10, color)
		draw_arc(Vector2(0, 2), 10, 0, TAU, 20, color.lightened(0.4), 2.0)
		draw_circle(Vector2(-3, -1), 3, Color(1, 1, 1, 0.4))

	# Amount label
	if amount > 1:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(8, 6), str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.9))

func _draw_ellipse(center: Vector2, radius: Vector2, start_angle: float, end_angle: float, color: Color, width: float = 1.0, filled: bool = false) -> void:
	var points := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var angle := start_angle + (end_angle - start_angle) * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	if filled:
		var colors := PackedColorArray()
		colors.resize(points.size())
		colors.fill(color)
		draw_polygon(points, colors)
	else:
		draw_polyline(points, color, width)
