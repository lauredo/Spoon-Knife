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
	_add("torch", "torch", 1, {"twig": 2, "grass": 2}, "", "light")
	_add("rope", "rope", 1, {"grass": 3}, "", "refine")
	_add("campfire", "campfire", 1, {"wood": 2, "grass": 2, "twig": 2}, "", "structures")
	_add("spear", "spear", 1, {"twig": 2, "flint": 1, "rope": 1}, "", "weapons")

	# === REQUIRE CAMPFIRE ===
	_add("cooked_berries", "cooked_berries", 1, {"berries": 1}, "campfire", "food")
	_add("cooked_meat", "cooked_meat", 1, {"meat": 1}, "campfire", "food")
	_add("charcoal", "charcoal", 1, {"wood": 1}, "campfire", "refine")

	# === ADVANCED ===
	_add("ham_bat", "ham_bat", 1, {"meat": 1, "twig": 2, "rope": 1}, "", "weapons")
	_add("chest", "chest", 1, {"wood": 6, "rope": 2}, "", "structures")

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
