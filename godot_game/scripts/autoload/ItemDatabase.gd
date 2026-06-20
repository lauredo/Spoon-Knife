extends Node

enum ItemType { RESOURCE, TOOL, FOOD, STRUCTURE, WEAPON, ARMOR }

class ItemData:
	var id: String
	var display_name: String
	var type: int
	var max_stack: int
	var color: Color
	var durability: int
	var damage: int
	var hunger_restore: float
	var health_restore: float
	var sanity_restore: float
	var is_light_source: bool
	var light_radius: float

	func _init(_id: String, _name: String, _type: int, _stack: int = 50, _color: Color = Color.WHITE) -> void:
		id = _id
		display_name = _name
		type = _type
		max_stack = _stack
		color = _color
		durability = -1
		damage = 0
		hunger_restore = 0.0
		health_restore = 0.0
		sanity_restore = 0.0
		is_light_source = false
		light_radius = 0.0

var items: Dictionary = {}

func _ready() -> void:
	_register_all_items()

func _register_all_items() -> void:
	# === RESOURCES ===
	_reg("wood", "Wood", ItemType.RESOURCE, 20, Color(0.55, 0.27, 0.07))
	_reg("stone", "Stone", ItemType.RESOURCE, 20, Color(0.55, 0.55, 0.55))
	_reg("flint", "Flint", ItemType.RESOURCE, 20, Color(0.4, 0.4, 0.55))
	_reg("grass", "Grass", ItemType.RESOURCE, 40, Color(0.47, 0.78, 0.28))
	_reg("twig", "Twig", ItemType.RESOURCE, 40, Color(0.65, 0.45, 0.2))
	_reg("silk", "Silk", ItemType.RESOURCE, 20, Color(0.95, 0.95, 1.0))
	_reg("spider_gland", "Spider Gland", ItemType.RESOURCE, 20, Color(0.55, 0.85, 0.45))
	_reg("rope", "Rope", ItemType.RESOURCE, 20, Color(0.82, 0.68, 0.38))
	_reg("seeds", "Seeds", ItemType.RESOURCE, 40, Color(0.8, 0.7, 0.4))
	_reg("charcoal", "Charcoal", ItemType.RESOURCE, 20, Color(0.25, 0.25, 0.25))

	# === FOOD ===
	var berries = _reg("berries", "Berries", ItemType.FOOD, 40, Color(0.85, 0.15, 0.35))
	berries.hunger_restore = 9.375
	berries.health_restore = 1.0
	berries.sanity_restore = -10.0

	var meat = _reg("meat", "Meat", ItemType.FOOD, 20, Color(0.85, 0.35, 0.25))
	meat.hunger_restore = 12.5

	var monster_meat = _reg("monster_meat", "Monster Meat", ItemType.FOOD, 20, Color(0.7, 0.2, 0.2))
	monster_meat.hunger_restore = 18.75
	monster_meat.health_restore = -3.0
	monster_meat.sanity_restore = -20.0

	var cooked_berries = _reg("cooked_berries", "Roasted Berries", ItemType.FOOD, 40, Color(0.9, 0.3, 0.15))
	cooked_berries.hunger_restore = 12.5
	cooked_berries.health_restore = 1.0
	cooked_berries.sanity_restore = 5.0

	var cooked_meat = _reg("cooked_meat", "Cooked Meat", ItemType.FOOD, 20, Color(0.9, 0.5, 0.2))
	cooked_meat.hunger_restore = 25.0
	cooked_meat.health_restore = 3.0
	cooked_meat.sanity_restore = 5.0

	# === TOOLS ===
	var axe = _reg("axe", "Axe", ItemType.TOOL, 1, Color(0.72, 0.72, 0.82))
	axe.durability = 100
	axe.damage = 27

	var pickaxe = _reg("pickaxe", "Pickaxe", ItemType.TOOL, 1, Color(0.6, 0.6, 0.75))
	pickaxe.durability = 100
	pickaxe.damage = 15

	var torch = _reg("torch", "Torch", ItemType.TOOL, 1, Color(1.0, 0.75, 0.25))
	torch.durability = 225
	torch.is_light_source = true
	torch.light_radius = 200.0

	# === WEAPONS ===
	var spear = _reg("spear", "Spear", ItemType.WEAPON, 1, Color(0.85, 0.65, 0.25))
	spear.durability = 150
	spear.damage = 34

	var ham_bat = _reg("ham_bat", "Ham Bat", ItemType.WEAPON, 1, Color(0.9, 0.5, 0.4))
	ham_bat.durability = 100
	ham_bat.damage = 59

	# === STRUCTURES ===
	var campfire = _reg("campfire", "Campfire", ItemType.STRUCTURE, 1, Color(1.0, 0.55, 0.1))
	campfire.is_light_source = true
	campfire.light_radius = 350.0

	_reg("chest", "Chest", ItemType.STRUCTURE, 1, Color(0.6, 0.4, 0.2))

func _reg(id: String, name: String, type: int, stack: int = 50, color: Color = Color.WHITE) -> ItemData:
	var item = ItemData.new(id, name, type, stack, color)
	items[id] = item
	return item

func get_item(id: String) -> ItemData:
	return items.get(id, null)

func has_item(id: String) -> bool:
	return items.has(id)
