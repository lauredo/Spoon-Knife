class_name WorldGenerator
extends Node

const WORLD_SIZE := 2000.0
const HALF_WORLD := WORLD_SIZE * 0.5

var resource_scene: PackedScene
var spider_scene: PackedScene
var boar_scene: PackedScene
var campfire_scene: PackedScene

var world_node: Node2D
var mobs_node: Node2D
var resources_node: Node2D
var structures_node: Node2D
var items_node: Node2D
var day_night: DayNightCycle

func setup(world: Node2D, dnc: DayNightCycle) -> void:
	world_node = world
	day_night = dnc

	resources_node = world.get_node("Resources")
	mobs_node = world.get_node("Mobs")
	structures_node = world.get_node("Structures")
	items_node = world.get_node("DroppedItems")

const BOUND := HALF_WORLD + 60.0  # play-area edge (just outside the outermost resources)
const WALL_T := 80.0

func generate() -> void:
	_generate_resources()
	_generate_mobs()
	_create_boundaries()

## Invisible walls around the play area so the player can't wander out into the empty terrain.
func _create_boundaries() -> void:
	var body := StaticBody2D.new()
	body.name = "Boundary"
	body.collision_layer = 1  # World — the player (mask 1) bumps it
	body.collision_mask = 0
	var span := BOUND * 2.0 + WALL_T * 2.0
	_add_wall(body, Vector2(0.0, -BOUND - WALL_T * 0.5), Vector2(span, WALL_T))         # top
	_add_wall(body, Vector2(0.0, BOUND + WALL_T * 0.5), Vector2(span, WALL_T))          # bottom
	_add_wall(body, Vector2(-BOUND - WALL_T * 0.5, 0.0), Vector2(WALL_T, BOUND * 2.0))  # left
	_add_wall(body, Vector2(BOUND + WALL_T * 0.5, 0.0), Vector2(WALL_T, BOUND * 2.0))   # right
	world_node.add_child(body)

func _add_wall(body: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	body.add_child(col)

func _generate_resources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Trees
	for i in 80:
		_spawn_resource(ResourceNode.ResourceType.TREE, _rand_pos(rng))

	# Rocks
	for i in 40:
		_spawn_resource(ResourceNode.ResourceType.ROCK, _rand_pos(rng))

	# Bushes
	for i in 60:
		_spawn_resource(ResourceNode.ResourceType.BUSH, _rand_pos(rng))

	# Grass
	for i in 100:
		_spawn_resource(ResourceNode.ResourceType.GRASS_TUFT, _rand_pos(rng))

func _generate_mobs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Spiders (far from spawn)
	for i in 20:
		var pos := _rand_pos_far(rng, 400.0)
		_spawn_spider(pos)

	# Boars
	for i in 10:
		var pos := _rand_pos_far(rng, 300.0)
		_spawn_boar(pos)

func _rand_pos(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(
		rng.randf_range(-HALF_WORLD, HALF_WORLD),
		rng.randf_range(-HALF_WORLD, HALF_WORLD)
	)

func _rand_pos_far(rng: RandomNumberGenerator, min_dist: float) -> Vector2:
	var pos := _rand_pos(rng)
	while pos.length() < min_dist:
		pos = _rand_pos(rng)
	return pos

func _spawn_resource(type: ResourceNode.ResourceType, pos: Vector2) -> Node:
	var node := ResourceNode.new()
	node.resource_type = type
	node.position = pos
	resources_node.add_child(node)
	return node

func _spawn_spider(pos: Vector2) -> Node:
	var mob := SpiderMob.new()
	mob.position = pos
	mobs_node.add_child(mob)
	if day_night:
		day_night.register_spider(mob)
	mob.died.connect(_on_mob_died.bind(mob))
	return mob

func _spawn_boar(pos: Vector2) -> Node:
	var mob := BoarMob.new()
	mob.position = pos
	mobs_node.add_child(mob)
	mob.died.connect(_on_mob_died.bind(mob))
	return mob

func _on_mob_died(mob: MobBase) -> void:
	# Respawn after delay
	var pos := mob.global_position
	var mob_type := "spider" if mob is SpiderMob else "boar"
	await get_tree().create_timer(randf_range(60.0, 120.0)).timeout
	if is_instance_valid(world_node):
		var new_pos := pos + Vector2(randf_range(-200, 200), randf_range(-200, 200))
		if mob_type == "spider":
			_spawn_spider(new_pos)
		else:
			_spawn_boar(new_pos)

func place_structure(structure_type: String, position: Vector2, player: Player) -> bool:
	match structure_type:
		"campfire":
			return _place_campfire(position, player)
		"chest":
			return _place_chest(position, player)
	return false

func _place_campfire(pos: Vector2, player: Player) -> bool:
	var campfire := Campfire.new()
	campfire.position = pos
	structures_node.add_child(campfire)
	return true

func _place_chest(pos: Vector2, player: Player) -> bool:
	var chest := Chest.new()
	chest.position = pos
	structures_node.add_child(chest)
	return true
