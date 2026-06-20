class_name Campfire
extends StaticBody2D

var fire_phase: float = 0.0
var is_lit: bool = true
var fuel_timer: float = 300.0  # 5 minutes of fuel
var light_radius: float = 300.0
var nearby_players: Array = []

var base_sprite: Sprite2D = null
var flame: AnimatedSprite2D = null

signal fire_extinguished

func _ready() -> void:
	collision_layer = 32
	collision_mask = 0

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	col.shape = shape
	add_child(col)

	# Light area for player sanity/darkness detection
	var light_area := Area2D.new()
	light_area.name = "LightArea"
	var light_col := CollisionShape2D.new()
	var light_shape := CircleShape2D.new()
	light_shape.radius = light_radius
	light_col.shape = light_shape
	light_area.add_child(light_col)
	light_area.collision_layer = 0
	light_area.collision_mask = 2  # player layer
	add_child(light_area)
	light_area.body_entered.connect(_on_player_entered_light)
	light_area.body_exited.connect(_on_player_exited_light)

	_setup_sprites()

func _setup_sprites() -> void:
	var base := Assets.sprite("structures", "campfire_base")
	if base:
		base_sprite = Sprite2D.new()
		base_sprite.texture = base
		base_sprite.show_behind_parent = true
		var s := 60.0 / float(base.get_height())
		base_sprite.scale = Vector2(s, s)
		add_child(base_sprite)
	var sf := Assets.sprite_frames("campfire", [{"anim": "burn", "count": 3, "fps": 10, "loop": true}])
	if sf:
		flame = AnimatedSprite2D.new()
		flame.sprite_frames = sf
		flame.animation = "burn"
		var ft := sf.get_frame_texture("burn", 0)
		var fs := 46.0 / float(ft.get_height())
		flame.scale = Vector2(fs, fs)
		# Anchor flame base just above the logs at the origin.
		flame.position = Vector2(0, 2.0 - ft.get_height() * fs * 0.5)
		add_child(flame)
		flame.play("burn")

func get_structure_type() -> String:
	return "campfire"

func _process(delta: float) -> void:
	fire_phase += delta * 8.0
	if is_lit:
		fuel_timer -= delta
		if fuel_timer <= 0.0:
			_extinguish()
	if flame:
		flame.visible = is_lit
	queue_redraw()

func _on_player_entered_light(body: Node) -> void:
	if body is Player:
		nearby_players.append(body)
		body.set_near_light(true)

func _on_player_exited_light(body: Node) -> void:
	if body is Player:
		nearby_players.erase(body)
		body.set_near_light(false)

func interact(player: Player) -> void:
	# Allow adding fuel
	if player.inventory.has_item("wood"):
		player.inventory.remove_item("wood", 1)
		fuel_timer += 180.0
		if not is_lit:
			is_lit = true

func _extinguish() -> void:
	is_lit = false
	for p in nearby_players:
		if is_instance_valid(p):
			p.set_near_light(false)
	nearby_players.clear()
	fire_extinguished.emit()

func _draw() -> void:
	# Stone ring — procedural only when no base sprite (fallback)
	if base_sprite == null:
		for i in 8:
			var angle := float(i) / 8.0 * TAU
			var stone_pos := Vector2(cos(angle) * 20, sin(angle) * 20)
			draw_circle(stone_pos, 5, Color(0.5, 0.5, 0.5))

	if is_lit:
		# Glowing ground (light overlay, kept in all cases)
		draw_circle(Vector2.ZERO, 18, Color(0.9, 0.4, 0.05, 0.5))

		if base_sprite == null:
			# Logs
			draw_line(Vector2(-12, 8), Vector2(12, -4), Color(0.45, 0.28, 0.12), 5.0)
			draw_line(Vector2(-12, -4), Vector2(12, 8), Color(0.45, 0.28, 0.12), 5.0)

		if flame == null:
			# Procedural fire + sparks (fallback when no animated flame)
			var flicker := sin(fire_phase) * 0.3 + 0.7
			var flicker2 := sin(fire_phase * 1.3 + 1.0) * 0.25 + 0.75
			draw_circle(Vector2(0, -5), 18 * flicker, Color(0.95, 0.35, 0.05, 0.7))
			draw_circle(Vector2(sin(fire_phase * 0.7) * 3.0, -12), 13 * flicker2, Color(1.0, 0.65, 0.1, 0.85))
			draw_circle(Vector2(sin(fire_phase * 1.1) * 2.0, -18), 8 * flicker, Color(1.0, 0.9, 0.4, 0.9))
			draw_circle(Vector2(0, -20), 4, Color(1.0, 1.0, 0.85))
			for i in 3:
				var spark_phase := fire_phase + float(i) * 2.1
				var spark_x := sin(spark_phase * 0.8) * 10.0
				var spark_y := -25.0 - fmod(spark_phase * 8.0, 20.0)
				draw_circle(Vector2(spark_x, spark_y), 1.5, Color(1.0, 0.8, 0.2, max(0.0, 1.0 - fmod(spark_phase, 2.0) * 0.5)))

		# Fuel indicator (always)
		var fuel_pct: float = clamp(fuel_timer / 300.0, 0.0, 1.0)
		draw_rect(Rect2(-20, 28, 40, 4), Color(0.2, 0.1, 0.05))
		draw_rect(Rect2(-20, 28, 40 * fuel_pct, 4), Color.RED.lerp(Color(1.0, 0.65, 0.1), fuel_pct))
	else:
		# Embers / ash (overlay; logs/stones come from base sprite if present)
		draw_circle(Vector2(0, -2), 12, Color(0.3, 0.25, 0.22))
		for i in 4:
			var angle := float(i) / 4.0 * TAU
			draw_circle(Vector2(cos(angle) * 7, sin(angle) * 5), 2.5, Color(0.5, 0.22, 0.05, 0.6))
		# "Relight" hint
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-30, 44), "[E] Add wood", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.7, 0.5, 0.8))
