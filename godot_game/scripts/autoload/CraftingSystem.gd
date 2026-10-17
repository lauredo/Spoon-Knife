extends Node

class Recipe:
	var id: String
	var result_item: String
	var result_amount: int
	var ingredients: Dictionary
	var requires_structure: String
	var category: String

	func _init(_id: String, _result: String, _amount: int, _ingredients: Dictionary, _structure: String = "", _category: String = "survival") -> void:
		id = _id
		result_item = _result
		result_amount = _amount
		ingredients = _ingredients
		requires_structure = _structure
		category = _category

var recipes: Array = []

func _ready() -> void:
	_register_recipes()

func _register_recipes() -> void:
	# === BASIC (no structure needed) ===
	_add("axe", "axe", 1, {"twig": 2, "flint": 1}, "", "tools")
	_add("pickaxe", "pickaxe", 1, {"twig": 2, "flint": 2}, "", "tools")
	_add("shovel", "shovel", 1, {"twig": 2, "stone": 2}, "", "tools")
	# The island gate: a big mid-game project mixing forest (wood/rope) and city (cloth) loot.
	_add("raft", "raft", 1, {"wood": 10, "rope": 4, "cloth": 3}, "workbench", "tools")
	_add("torch", "torch", 1, {"twig": 2, "grass": 2}, "", "light")
	_add("rope", "rope", 1, {"grass": 3}, "", "refine")
	_add("bandage", "bandage", 1, {"grass": 3, "twig": 1}, "", "healing")
	_add("bandage_cloth", "bandage", 1, {"cloth": 2}, "", "healing")  # city route to the same bandage
	_add("salve", "salve", 1, {"spider_gland": 1, "grass": 2, "twig": 1}, "", "healing")
	_add("shiv", "shiv", 1, {"scrap": 2, "twig": 1, "rope": 1}, "", "weapons")
	_add("campfire", "campfire", 1, {"wood": 2, "grass": 2, "twig": 2}, "", "structures")
	_add("spear", "spear", 1, {"twig": 2, "flint": 1, "rope": 1}, "", "weapons")

	# === REQUIRE CAMPFIRE ===
	_add("cooked_berries", "cooked_berries", 1, {"berries": 1}, "campfire", "food")
	_add("cooked_meat", "cooked_meat", 1, {"meat": 1}, "campfire", "food")
	_add("charcoal", "charcoal", 1, {"wood": 1}, "campfire", "refine")

	# === ADVANCED ===
	# Top melee tier stays EARNED: the old ham_bat gated it behind a hunt (meat); the city
	# version gates it behind looting (cloth for the taped grip). Wood alone would make the
	# strongest weapon also the cheapest on day 1.
	_add("taco", "taco", 1, {"wood": 3, "cloth": 2, "rope": 1}, "", "weapons")
	_add("chest", "chest", 1, {"wood": 6, "rope": 2}, "", "structures")
	# Energy recovery away from the den (S5) — cloth keeps it a city-loot project.
	_add("bed", "bed", 1, {"cloth": 4, "grass": 4}, "", "structures")

	# === BUILDING (stone finally has a use) ===
	_add("workbench", "workbench", 1, {"wood": 4, "stone": 4}, "", "structures")
	_add("wall", "wall", 1, {"stone": 3}, "", "structures")

	# === ARMOR (needs a workbench nearby) ===
	_add("wood_armor", "wood_armor", 1, {"wood": 6, "rope": 2}, "workbench", "armor")
	_add("silk_armor", "silk_armor", 1, {"silk": 4, "rope": 2}, "workbench", "armor")
	_add("stone_armor", "stone_armor", 1, {"stone": 6, "rope": 2}, "workbench", "armor")

func _add(id: String, result: String, amount: int, ingredients: Dictionary, structure: String = "", category: String = "survival") -> void:
	recipes.append(Recipe.new(id, result, amount, ingredients, structure, category))

func get_available_recipes(inventory: Dictionary, near_structures: Array) -> Array:
	var available: Array = []
	for recipe in recipes:
		if can_craft(recipe, inventory, near_structures):
			available.append(recipe)
	return available

func get_all_recipes() -> Array:
	return recipes

func can_craft(recipe: Recipe, inventory: Dictionary, near_structures: Array) -> bool:
	if recipe.requires_structure != "" and not recipe.requires_structure in near_structures:
		return false
	for item_id in recipe.ingredients:
		var required: int = recipe.ingredients[item_id]
		var have: int = inventory.get(item_id, 0)
		if have < required:
			return false
	return true

func apply_craft(recipe: Recipe, inventory: Dictionary) -> Dictionary:
	var result := inventory.duplicate()
	for item_id in recipe.ingredients:
		result[item_id] = result.get(item_id, 0) - recipe.ingredients[item_id]
		if result[item_id] <= 0:
			result.erase(item_id)
	result[recipe.result_item] = result.get(recipe.result_item, 0) + recipe.result_amount
	var item_data = ItemDatabase.get_item(recipe.result_item)
	if item_data and result[recipe.result_item] > item_data.max_stack:
		result[recipe.result_item] = item_data.max_stack
	return result
