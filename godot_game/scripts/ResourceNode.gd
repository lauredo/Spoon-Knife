class_name ResourceNode
extends StaticBody2D

enum ResourceType { TREE, ROCK, BUSH, GRASS_TUFT }

signal depleted(node: ResourceNode)

@export var resource_type: ResourceType = ResourceType.TREE

var max_health: float = 100.0
var health: float = 100.0
var required_tool: String = ""  # "" = any, "axe", "pickaxe"
var drops: Array = []
var regrow_time: float = 120.0
var is_depleted: bool = false
var regrow_timer: float = 0.0
var shake_amount: float = 0.0
var bob_phase: float = 0.0

var sprite: Sprite2D = null
var _collision: CollisionShape2D = null  # disabled while depleted so you can walk over the stump
var _sprite_base_pos: Vector2 = Vector2.ZERO
var _display_h: float = 0.0

# Hit-feedback shader: lerps the sprite toward `flash_color` by `flash` (0..1) while keeping
# its original alpha, so we can pop a solid-colour silhouette. Shared across all nodes.
const _HIT_SHADER_CODE: String = "shader_type canvas_item;\nuniform float flash : hint_range(0.0, 1.0) = 0.0;\nuniform vec4 flash_color : source_color = vec4(1.0);\nvoid fragment() {\n\tvec4 base = COLOR;\n\tvec4 tex = texture(TEXTURE, UV);\n\tvec3 rgb = mix(tex.rgb, flash_color.rgb, flash);\n\tCOLOR = vec4(rgb * base.rgb, tex.a * base.a);\n}\n"
static var _hit_shader: Shader = null

func _ready() -> void:
	_setup_type()
	# Layer 8 = Resources (used by the player's interact area). Trees and rocks ALSO
	# sit on layer 1 (World) so the player and mobs physically collide with them;
	# bushes and grass stay non-blocking (interaction only, walk-through).
	collision_layer = 8
	if resource_type == ResourceType.TREE or resource_type == ResourceType.ROCK:
		collision_layer |= 1
	collision_mask = 0

	_collision = CollisionShape2D.new()
	_collision.shape = _make_collision_shape()
	_collision.position = _get_collision_offset()
	add_child(_collision)

	_setup_sprite()

func _setup_sprite() -> void:
	var tex := Assets.sprite("resources", _type_name())
	if tex == null:
		return
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.show_behind_parent = true  # keep health bar / overlays drawn on top
	var s := _sprite_target_height() / float(tex.get_height())
	sprite.scale = Vector2(s, s)
	_display_h = tex.get_height() * s
	# Anchor the base slightly below origin, matching the procedural footprint.
	_sprite_base_pos = Vector2(0, 8.0 - _display_h * 0.5)
	sprite.position = _sprite_base_pos
	# Shader material so we can flash the sprite white on hit (flash=0 = passthrough).
	var flash_mat := ShaderMaterial.new()
	flash_mat.shader = _get_hit_shader()
	flash_mat.set_shader_parameter("flash", 0.0)
	sprite.material = flash_mat
	add_child(sprite)

func _type_name() -> String:
	match resource_type:
		ResourceType.TREE: return "tree"
		ResourceType.ROCK: return "rock"
		ResourceType.BUSH: return "bush"
		ResourceType.GRASS_TUFT: return "grass_tuft"
	return "tree"

func _sprite_target_height() -> float:
	match resource_type:
		ResourceType.TREE: return 120.0
		ResourceType.ROCK: return 50.0
		ResourceType.BUSH: return 54.0
		ResourceType.GRASS_TUFT: return 36.0
	return 60.0

func _setup_type() -> void:
	match resource_type:
		ResourceType.TREE:
			max_health = 100.0
			required_tool = "axe"
			drops = [
				{"item": "wood", "min": 2, "max": 4},
				{"item": "twig", "min": 1, "max": 2},
				{"item": "seeds", "min": 0, "max": 2},
			]
			regrow_time = 180.0
		ResourceType.ROCK:
			max_health = 150.0
			required_tool = "pickaxe"
			drops = [
				{"item": "stone", "min": 2, "max": 4},
				{"item": "flint", "min": 1, "max": 2},
			]
			regrow_time = 300.0
		ResourceType.BUSH:
			max_health = 40.0
			required_tool = ""
			drops = [
				{"item": "berries", "min": 1, "max": 3},
				{"item": "twig", "min": 1, "max": 1},
			]
			regrow_time = 60.0
		ResourceType.GRASS_TUFT:
			max_health = 20.0
			required_tool = ""
			drops = [
				{"item": "grass", "min": 2, "max": 4},
				{"item": "seeds", "min": 0, "max": 1},
			]
			regrow_time = 45.0
	health = max_health

func _get_collision_radius() -> float:
	match resource_type:
		ResourceType.ROCK: return 17.0
		ResourceType.BUSH: return 14.0
		ResourceType.GRASS_TUFT: return 10.0
	return 16.0

# Tree uses a slim vertical capsule that matches the trunk in tree.svg, so the player
# can walk behind the canopy and only the trunk blocks. Others use a circle.
func _make_collision_shape() -> Shape2D:
	if resource_type == ResourceType.TREE:
		var cap := CapsuleShape2D.new()
		cap.radius = 6.5
		cap.height = 43.0   # trunk runs from y~-38 (top) to y~+5 (base) in node space
		return cap
	var circle := CircleShape2D.new()
	circle.radius = _get_collision_radius()
	return circle

# Offsets the collision shape so its base sits at the base of the trunk/rock.
func _get_collision_offset() -> Vector2:
	match resource_type:
		ResourceType.TREE: return Vector2(0, -16.5)  # capsule base lands at the trunk base (~y+5)
		ResourceType.ROCK: return Vector2(0, -2)
	return Vector2.ZERO

func _process(delta: float) -> void:
	shake_amount = max(0.0, shake_amount - delta * 9.0)
	bob_phase += delta * 1.2
	if sprite and not is_depleted:
		# Trees stay planted — their hit feedback is a flash + silhouette (_flash_silhouette).
		# Rocks/bushes still do a small position jitter on hit that decays back to 0.
		if resource_type != ResourceType.TREE and shake_amount > 0.0:
			sprite.position = _sprite_base_pos + Vector2(
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount * 0.5, shake_amount * 0.5))
		else:
			sprite.position = _sprite_base_pos
	if is_depleted:
		regrow_timer -= delta
		if regrow_timer <= 0.0:
			_regrow()
	queue_redraw()

func interact(player: Player) -> void:
	if is_depleted:
		return

	var equipped_id := player.inventory.get_equipped_item()
	var item_data = ItemDatabase.get_item(equipped_id) if equipped_id != "" else null

	# Check tool requirement
	if required_tool != "":
		if not item_data or item_data.id != required_tool:
			# Can still hit with any tool or bare hands, just does less damage
			_take_hit(10.0, player)
			return

	var damage := 34.0
	if item_data and item_data.damage > 0:
		damage = float(item_data.damage)
	_take_hit(damage, player)
	if item_data and item_data.durability > 0:
		player.inventory.use_durability(equipped_id, 1)

## Harvest from a tool/weapon swing (the attack button). Trees/rocks/bushes are chopped this
## way now; the tool check & damage live in interact(), so this just forwards to it.
func chop(player: Player) -> void:
	interact(player)

func _take_hit(damage: float, player: Player) -> void:
	health -= damage
	shake_amount = 8.0
	if resource_type == ResourceType.TREE:
		_spawn_hit_effect()
		_flash_silhouette()
	queue_redraw()
	if health <= 0.0:
		_harvest(player)

## A few leaves shake loose from the canopy and drift down when the tree is chopped
## (individual leaf sprites from trees.png HIT EFFECTS, see tools/slice_trees.gd).
func _spawn_hit_effect() -> void:
	var leaves: Array[Texture2D] = []
	for i in 8:
		var t := Assets.sprite("effects", "leaf_%d" % i)
		if t:
			leaves.append(t)
	if leaves.is_empty():
		return
	for k in randi_range(2, 4):
		var leaf := Sprite2D.new()
		leaf.texture = leaves[randi() % leaves.size()]
		leaf.z_index = 5
		# start somewhere in the canopy
		var start := Vector2(randf_range(-_display_h * 0.22, _display_h * 0.22), -_display_h * 0.6)
		leaf.position = start
		leaf.scale = Vector2(0.5, 0.5)
		leaf.rotation = randf() * TAU
		add_child(leaf)
		var dur := randf_range(0.8, 1.3)
		var dest := start + Vector2(randf_range(-18.0, 18.0), _display_h * 0.55 + randf_range(0.0, 20.0))
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(leaf, "position", dest, dur).set_trans(Tween.TRANS_SINE)
		tw.tween_property(leaf, "rotation", leaf.rotation + randf_range(-2.5, 2.5), dur)
		tw.tween_property(leaf, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
		tw.set_parallel(false)
		tw.tween_callback(leaf.queue_free)

## Hit feedback (TREE): a quick white flash on the tree plus a solid-white silhouette that
## pops out of it and fades — replaces the old canopy-shake (see [[sprite-pipeline]]).
func _flash_silhouette() -> void:
	if sprite == null:
		return
	# 1) Flash the tree itself white, then ease it back over a beat.
	var mat := sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("flash", 1.0)
		var ft := create_tween()
		ft.tween_property(mat, "shader_parameter/flash", 0.0, 0.12).set_ease(Tween.EASE_OUT)
	# 2) Solid-white silhouette ghost that grows slightly and fades out — "saindo" da árvore.
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.scale = sprite.scale
	ghost.position = _sprite_base_pos
	ghost.z_index = 6
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.85)
	var gmat := ShaderMaterial.new()
	gmat.shader = _get_hit_shader()
	gmat.set_shader_parameter("flash", 1.0)  # full silhouette
	ghost.material = gmat
	add_child(ghost)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "scale", sprite.scale * 1.18, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.18).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_callback(ghost.queue_free)

static func _get_hit_shader() -> Shader:
	if _hit_shader == null:
		_hit_shader = Shader.new()
		_hit_shader.code = _HIT_SHADER_CODE
	return _hit_shader

func _harvest(player: Player) -> void:
	for drop_info in drops:
		var amount: int = randi_range(drop_info.get("min", 1), drop_info.get("max", 1))
		if amount > 0:
			GameManager.spawn_drop(global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)),
								   drop_info["item"], amount)
	_deplete()

func _deplete() -> void:
	is_depleted = true
	regrow_timer = regrow_time
	if sprite:
		sprite.visible = false
	# Drop the hitbox so the leftover stump/rubble can be walked over.
	if _collision:
		_collision.set_deferred("disabled", true)
	depleted.emit(self)
	queue_redraw()

func _regrow() -> void:
	is_depleted = false
	health = max_health
	if sprite:
		sprite.visible = true
	if _collision:
		_collision.set_deferred("disabled", false)
	queue_redraw()

func _draw() -> void:
	if is_depleted:
		_draw_depleted()
		return

	# Procedural body only when no sprite texture is present (fallback).
	if sprite == null:
		var shake_offset := Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount * 0.5, shake_amount * 0.5))
		var bob := sin(bob_phase) * 2.0
		match resource_type:
			ResourceType.TREE:
				_draw_tree(shake_offset, bob)
			ResourceType.ROCK:
				_draw_rock(shake_offset)
			ResourceType.BUSH:
				_draw_bush(shake_offset, bob)
			ResourceType.GRASS_TUFT:
				_draw_grass(shake_offset, bob)

	# Health bar when damaged
	if health < max_health:
		var pct := health / max_health
		var bw := 30.0
		draw_rect(Rect2(-bw * 0.5, -_get_draw_height() - 8, bw, 4), Color(0.2, 0.1, 0.05))
		draw_rect(Rect2(-bw * 0.5, -_get_draw_height() - 8, bw * pct, 4), Color.RED.lerp(Color.GREEN, pct))

func _get_draw_height() -> float:
	match resource_type:
		ResourceType.TREE: return 60.0
		ResourceType.ROCK: return 30.0
		ResourceType.BUSH: return 28.0
		ResourceType.GRASS_TUFT: return 20.0
	return 30.0

func _draw_tree(offset: Vector2, bob: float) -> void:
	# Trunk
	draw_rect(Rect2(-8 + offset.x * 0.3, -10, 16, 30), Color(0.45, 0.28, 0.12))
	# Canopy layers
	draw_circle(Vector2(offset.x * 0.8, -35 + bob), 32, Color(0.22, 0.55, 0.18))
	draw_circle(Vector2(offset.x, -48 + bob), 24, Color(0.28, 0.65, 0.22))
	draw_circle(Vector2(offset.x * 0.5, -58 + bob * 1.3), 16, Color(0.35, 0.72, 0.28))
	# Pinecone hint
	draw_circle(Vector2(offset.x * 0.5, -60 + bob * 1.3), 4, Color(0.55, 0.35, 0.12))

func _draw_rock(offset: Vector2) -> void:
	var pts := PackedVector2Array([
		Vector2(-22 + offset.x, 5),
		Vector2(-18 + offset.x * 0.7, -18),
		Vector2(0, -28 + offset.y * 0.5),
		Vector2(18, -20),
		Vector2(24, 2),
		Vector2(0, 8),
	])
	draw_polygon(pts, PackedColorArray([Color(0.52, 0.52, 0.52)]))
	draw_polyline(pts, Color(0.38, 0.38, 0.38), 1.5)
	# Flint hint
	draw_polygon(PackedVector2Array([
		Vector2(5, -15), Vector2(12, -22), Vector2(16, -14)
	]), PackedColorArray([Color(0.4, 0.4, 0.55)]))

func _draw_bush(offset: Vector2, bob: float) -> void:
	# Branches
	draw_circle(Vector2(-12 + offset.x * 0.7, -8 + bob * 0.8), 16, Color(0.28, 0.45, 0.15))
	draw_circle(Vector2(12 + offset.x * 0.5, -6 + bob * 0.6), 14, Color(0.32, 0.5, 0.18))
	draw_circle(Vector2(0 + offset.x, -18 + bob), 18, Color(0.35, 0.55, 0.2))
	# Berries
	for i in 5:
		var bx := cos(i * TAU / 5.0) * 10.0
		var by := sin(i * TAU / 5.0) * 8.0 - 12.0
		draw_circle(Vector2(bx + offset.x * 0.3, by + bob * 0.4), 3.5, Color(0.85, 0.15, 0.35))

func _draw_grass(offset: Vector2, bob: float) -> void:
	var grass_col := Color(0.42, 0.72, 0.25)
	for i in 6:
		var angle := (float(i) / 6.0) * TAU - PI * 0.5
		var len := randf_range(12, 20)
		var tip_offset := Vector2(cos(angle) * 4.0 + offset.x * 0.5, -len + sin(bob + float(i)) * 3.0)
		draw_line(Vector2(cos(angle) * 5.0, 0), tip_offset, grass_col, 2.0)

func _draw_depleted() -> void:
	match resource_type:
		ResourceType.TREE:
			# Stump
			draw_rect(Rect2(-8, -4, 16, 12), Color(0.45, 0.28, 0.12))
			draw_circle(Vector2(0, -4), 8, Color(0.52, 0.35, 0.15))
		ResourceType.ROCK:
			# Rubble
			for i in 4:
				var angle := float(i) * TAU / 4.0
				draw_circle(Vector2(cos(angle) * 12, sin(angle) * 8), 5, Color(0.45, 0.45, 0.45))
		ResourceType.BUSH, ResourceType.GRASS_TUFT:
			# Bare twigs
			draw_line(Vector2(-8, 0), Vector2(-4, -10), Color(0.5, 0.35, 0.2), 2.0)
			draw_line(Vector2(0, 0), Vector2(2, -12), Color(0.5, 0.35, 0.2), 2.0)
			draw_line(Vector2(8, 0), Vector2(5, -8), Color(0.5, 0.35, 0.2), 2.0)
