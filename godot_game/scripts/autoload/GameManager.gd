extends Node

signal game_over
signal new_day(day_number: int)

var current_day: int = 1
var is_game_over: bool = false
var player: Node = null
var world: Node = null
var hud: Node = null

func _ready() -> void:
	pass

func register_player(p: Node) -> void:
	player = p

func register_world(w: Node) -> void:
	world = w

func register_hud(h: Node) -> void:
	hud = h

func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	game_over.emit()

func advance_day() -> void:
	current_day += 1
	new_day.emit(current_day)

func get_nearby_structures(position: Vector2, radius: float) -> Array:
	var found: Array = []
	if not world:
		return found
	var structures_node = world.get_node_or_null("Structures")
	if not structures_node:
		return found
	for child in structures_node.get_children():
		if child.has_method("get_structure_type"):
			if child.global_position.distance_to(position) <= radius:
				found.append(child.get_structure_type())
	return found

func spawn_drop(position: Vector2, item_id: String, amount: int = 1) -> void:
	if not world:
		return
	var drop_scene = load("res://scenes/items/DropItem.tscn")
	if not drop_scene:
		return
	var drop = drop_scene.instantiate()
	drop.global_position = position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	drop.setup(item_id, amount)
	var items_node = world.get_node_or_null("DroppedItems")
	if items_node:
		items_node.add_child(drop)
	else:
		world.add_child(drop)
