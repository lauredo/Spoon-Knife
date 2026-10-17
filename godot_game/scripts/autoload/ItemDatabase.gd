extends Node

enum ItemType { RESOURCE, TOOL, FOOD, STRUCTURE, WEAPON, ARMOR, MEDICINE }

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
	var armor: float  # fraction of incoming damage blocked (0..1); ARMOR items only

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
		armor = 0.0

var items: Dictionary = {}

func _ready() -> void:
	_register_all_items()

func _register_all_items() -> void:
	# === RESOURCES ===
	# NOTE (S6 rename): ids are FROZEN (SaveSystem persists them raw — renaming an id orphans
	# items in old saves); only display_name carries the theme.
	_reg("wood", "Madeira", ItemType.RESOURCE, 20, Color(0.55, 0.27, 0.07))
	_reg("stone", "Pedra", ItemType.RESOURCE, 20, Color(0.55, 0.55, 0.55))
	_reg("flint", "Sílex", ItemType.RESOURCE, 20, Color(0.4, 0.4, 0.55))
	_reg("grass", "Grama", ItemType.RESOURCE, 40, Color(0.47, 0.78, 0.28))
	_reg("twig", "Galho", ItemType.RESOURCE, 40, Color(0.65, 0.45, 0.2))
	_reg("silk", "Carapaça", ItemType.RESOURCE, 20, Color(0.95, 0.95, 1.0))
	_reg("spider_gland", "Gosma de Barata", ItemType.RESOURCE, 20, Color(0.55, 0.85, 0.45))
	_reg("rope", "Corda", ItemType.RESOURCE, 20, Color(0.82, 0.68, 0.38))
	_reg("seeds", "Sementes", ItemType.RESOURCE, 40, Color(0.8, 0.7, 0.4))
	_reg("charcoal", "Carvão", ItemType.RESOURCE, 20, Color(0.25, 0.25, 0.25))
	_reg("scrap", "Sucata", ItemType.RESOURCE, 20, Color(0.65, 0.42, 0.3))
	_reg("cloth", "Pano", ItemType.RESOURCE, 20, Color(0.85, 0.8, 0.7))
	_reg("shiny_thing", "Coisa Brilhante", ItemType.RESOURCE, 10, Color(1.0, 0.95, 0.55))

	# === FOOD ===
	var berries = _reg("berries", "Frutinhas", ItemType.FOOD, 40, Color(0.85, 0.15, 0.35))
	berries.hunger_restore = 9.375
	berries.health_restore = 1.0
	berries.sanity_restore = -10.0

	var meat = _reg("meat", "Carne", ItemType.FOOD, 20, Color(0.85, 0.35, 0.25))
	meat.hunger_restore = 12.5

	var monster_meat = _reg("monster_meat", "Carne Estranha", ItemType.FOOD, 20, Color(0.7, 0.2, 0.2))
	monster_meat.hunger_restore = 18.75
	monster_meat.health_restore = -3.0
	monster_meat.sanity_restore = -20.0

	var cooked_berries = _reg("cooked_berries", "Frutinhas Assadas", ItemType.FOOD, 40, Color(0.9, 0.3, 0.15))
	cooked_berries.hunger_restore = 12.5
	cooked_berries.health_restore = 1.0
	cooked_berries.sanity_restore = 5.0

	var cooked_meat = _reg("cooked_meat", "Carne Assada", ItemType.FOOD, 20, Color(0.9, 0.5, 0.2))
	cooked_meat.hunger_restore = 25.0
	cooked_meat.health_restore = 3.0
	cooked_meat.sanity_restore = 5.0

	# Grown on the farm plot from seeds — renewable hunger food (no sanity penalty, no downside).
	var carrot = _reg("carrot", "Cenoura", ItemType.FOOD, 20, Color(0.95, 0.55, 0.15))
	carrot.hunger_restore = 12.0
	carrot.health_restore = 1.0

	# === CITY LOOT (scavenged from containers — see LootContainer) ===
	var old_pizza = _reg("old_pizza", "Pizza Velha", ItemType.FOOD, 10, Color(0.82, 0.55, 0.25))
	old_pizza.hunger_restore = 20.0
	old_pizza.sanity_restore = -5.0   # filling, but you know where it's been

	var donut = _reg("donut", "Rosquinha", ItemType.FOOD, 10, Color(0.93, 0.55, 0.68))
	donut.hunger_restore = 14.0
	donut.sanity_restore = 6.0        # sugar joy

	var canned = _reg("canned_food", "Enlatado", ItemType.FOOD, 10, Color(0.6, 0.66, 0.72))
	canned.hunger_restore = 32.0
	canned.health_restore = 2.0       # shelf-stable, the best basic food

	# === MEDICINE ===
	var bandage = _reg("bandage", "Bandagem", ItemType.MEDICINE, 20, Color(0.95, 0.95, 0.9))
	bandage.health_restore = 40.0

	# Premium heal made from roach goo (rarer than bandage mats) — gives the goo a use.
	var salve = _reg("salve", "Pomada", ItemType.MEDICINE, 20, Color(0.6, 0.85, 0.5))
	salve.health_restore = 60.0

	# === TOOLS ===
	var axe = _reg("axe", "Machado", ItemType.TOOL, 1, Color(0.72, 0.72, 0.82))
	axe.durability = 100
	axe.damage = 27

	var pickaxe = _reg("pickaxe", "Picareta", ItemType.TOOL, 1, Color(0.6, 0.6, 0.75))
	pickaxe.durability = 100
	pickaxe.damage = 15

	# Tilling tool: swing it on bare ground to make a farm plot (see Player._try_till). Weak weapon.
	var shovel = _reg("shovel", "Pá", ItemType.TOOL, 1, Color(0.7, 0.72, 0.8))
	shovel.durability = 120
	shovel.damage = 12

	# The raft — the late-game key (GDD): owning it turns the sea from a wall into a ROAD (and a
	# faster one than land; see Player sailing). No durability on purpose: a raft that dies
	# mid-crossing is a death sentence, not a decision.
	_reg("raft", "Balsa", ItemType.TOOL, 1, Color(0.55, 0.4, 0.2))

	# === BOSS RELICS (S4) — unique drops that unlock VERBS, not stats (GDD) ===
	_reg("alfa_collar", "Colar do Alfa", ItemType.RESOURCE, 1, Color(0.75, 0.2, 0.2))     # dogs ignore you
	_reg("jacare_scale", "Escama do Jacaré", ItemType.RESOURCE, 1, Color(0.25, 0.5, 0.3)) # you can SWIM

	var torch = _reg("torch", "Tocha", ItemType.TOOL, 1, Color(1.0, 0.75, 0.25))
	torch.durability = 225
	torch.is_light_source = true
	torch.light_radius = 200.0

	# === WEAPONS ===
	var spear = _reg("spear", "Lança", ItemType.WEAPON, 1, Color(0.85, 0.65, 0.25))
	spear.durability = 150
	spear.damage = 34

	# Top melee tier (replaced the old Don't Starve "Ham Bat" — same stats, honest city theme).
	var taco = _reg("taco", "Taco de Beisebol", ItemType.WEAPON, 1, Color(0.85, 0.68, 0.42))
	taco.durability = 100
	taco.damage = 59

	# City-loot weapon: cheap mid-tier blade from scavenged scrap.
	var shiv = _reg("shiv", "Faca de Sucata", ItemType.WEAPON, 1, Color(0.7, 0.68, 0.62))
	shiv.durability = 120
	shiv.damage = 40

	# === ARMOR === (blocks a fraction of incoming damage; wears down as it absorbs hits)
	var wood_armor = _reg("wood_armor", "Armadura de Madeira", ItemType.ARMOR, 1, Color(0.55, 0.36, 0.16))
	wood_armor.durability = 150
	wood_armor.armor = 0.25

	var silk_armor = _reg("silk_armor", "Armadura de Carapaça", ItemType.ARMOR, 1, Color(0.9, 0.9, 0.97))
	silk_armor.durability = 200
	silk_armor.armor = 0.40

	var stone_armor = _reg("stone_armor", "Armadura de Pedra", ItemType.ARMOR, 1, Color(0.5, 0.5, 0.52))
	stone_armor.durability = 320
	stone_armor.armor = 0.55

	# === STRUCTURES ===
	# Structures are inventory items now (crafted, then placed on the grid), so they STACK — you
	# carry several and set them down one per click. Walls stack high for base building.
	var campfire = _reg("campfire", "Fogueira", ItemType.STRUCTURE, 10, Color(1.0, 0.55, 0.1))
	campfire.is_light_source = true
	campfire.light_radius = 350.0

	_reg("chest", "Baú", ItemType.STRUCTURE, 10, Color(0.6, 0.4, 0.2))
	_reg("bed", "Cama de Panos", ItemType.STRUCTURE, 5, Color(0.72, 0.6, 0.45))
	_reg("workbench", "Bancada de Trabalho", ItemType.STRUCTURE, 5, Color(0.5, 0.35, 0.18))
	_reg("wall", "Muralha de Pedra", ItemType.STRUCTURE, 30, Color(0.5, 0.5, 0.52))

func _reg(id: String, name: String, type: int, stack: int = 50, color: Color = Color.WHITE) -> ItemData:
	var item = ItemData.new(id, name, type, stack, color)
	items[id] = item
	return item

func get_item(id: String) -> ItemData:
	return items.get(id, null)

## Rich pt-BR tooltip: display name + the item's mechanical effects (UX pack — slots used to
## show only the name, leaving food/weapon/armor stats invisible).
func tooltip(id: String) -> String:
	var it: ItemData = get_item(id)
	if it == null:
		return id
	var fx: Array[String] = []
	if it.hunger_restore != 0.0:
		fx.append("Fome %+d" % int(it.hunger_restore))
	if it.health_restore != 0.0:
		fx.append("Vida %+d" % int(it.health_restore))
	if it.sanity_restore != 0.0:
		fx.append("Sanidade %+d" % int(it.sanity_restore))
	if it.damage > 0:
		fx.append("Dano %d" % it.damage)
	if it.armor > 0.0:
		fx.append("Bloqueia %d%% do dano" % int(round(it.armor * 100.0)))
	if it.durability > 0:
		fx.append("Durabilidade %d" % it.durability)
	if it.is_light_source:
		fx.append("Fonte de luz")
	if fx.is_empty():
		return it.display_name
	return it.display_name + "\n" + " · ".join(fx)

func has_item(id: String) -> bool:
	return items.has(id)
