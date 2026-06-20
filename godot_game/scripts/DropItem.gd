class_name DropItem
extends RigidBody2D

var item_id: String = ""
var amount: int = 1
var bob_phase: float = 0.0
var attract_timer: float = 0.0
var magnetize_to: Node = null

func _ready() -> void:
	collision_layer = 16
	collision_mask = 1

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	col.shape = shape
	add_child(col)

	gravity_scale = 0.0
	linear_damp = 2.0

	# Random initial velocity (scatter effect)
	linear_velocity = Vector2(randf_range(-60, 60), randf_range(-60, 60))
	bob_phase = randf() * TAU

func setup(_item_id: String, _amount: int = 1) -> void:
	item_id = _item_id
	amount = _amount

func _process(delta: float) -> void:
	bob_phase += delta * 3.0
	attract_timer -= delta

	if is_instance_valid(magnetize_to) and attract_timer <= 0:
		var dir := (magnetize_to.global_position - global_position)
		if dir.length() < 40.0:
			pickup(magnetize_to)
		else:
			linear_velocity = dir.normalized() * 180.0

	queue_redraw()

func pickup(player: Player) -> void:
	var added := player.inventory.add_item(item_id, amount)
	if added > 0:
		queue_free()

func attract(player: Node) -> void:
	magnetize_to = player
	attract_timer = 0.5  # Small delay before magnetizing

func _draw() -> void:
	var item_data = ItemDatabase.get_item(item_id)
	var color := Color(0.8, 0.8, 0.8)
	var display_name := item_id
	if item_data:
		color = item_data.color
		display_name = item_data.display_name

	var bob_y := sin(bob_phase) * 3.0

	# Shadow
	draw_ellipse_arc(Vector2(0, 10), Vector2(8, 3), 0, TAU, Color(0, 0, 0, 0.25), 0, true)

	# Item circle
	draw_circle(Vector2(0, bob_y), 10, color)
	draw_arc(Vector2(0, bob_y), 10, 0, TAU, 20, color.lightened(0.4), 2.0)

	# Shine
	draw_circle(Vector2(-3, bob_y - 3), 3, Color(1, 1, 1, 0.4))

	# Amount label
	if amount > 1:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(8, bob_y + 4), str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.9))

func draw_ellipse_arc(center: Vector2, radius: Vector2, start_angle: float, end_angle: float, color: Color, width: float = 1.0, filled: bool = false) -> void:
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
