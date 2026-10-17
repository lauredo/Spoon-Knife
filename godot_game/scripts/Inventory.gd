class_name Inventory
extends Node

signal inventory_changed
signal item_equipped(item_id: String)
signal durability_changed(item_id: String, current: int, maximum: int)
signal armor_changed(item_id: String)

const HOTBAR_SIZE := 6

var items: Dictionary = {}
var equipped_slot: int = 0
var hotbar: Array = []
var item_durabilities: Dictionary = {}
var equipped_armor: String = ""  # worn armor (separate from the held hotbar item); "" = none

func _ready() -> void:
	hotbar.resize(HOTBAR_SIZE)
	for i in HOTBAR_SIZE:
		hotbar[i] = ""

func add_item(item_id: String, amount: int = 1) -> int:
	var item_data = ItemDatabase.get_item(item_id)
	if not item_data:
		return 0
	var remaining: int = amount
	var current: int = items.get(item_id, 0)
	var can_add: int = mini(remaining, item_data.max_stack - current)
	if can_add > 0:
		items[item_id] = current + can_add
		remaining -= can_add
		_try_add_to_hotbar(item_id)
	inventory_changed.emit()
	return amount - remaining

func remove_item(item_id: String, amount: int = 1) -> bool:
	var current: int = items.get(item_id, 0)
	if current < amount:
		return false
	current -= amount
	if current <= 0:
		items.erase(item_id)
		_remove_from_hotbar(item_id)
	else:
		items[item_id] = current
	inventory_changed.emit()
	return true

func has_item(item_id: String, amount: int = 1) -> bool:
	return items.get(item_id, 0) >= amount

func get_count(item_id: String) -> int:
	return items.get(item_id, 0)

func get_equipped_item() -> String:
	if equipped_slot >= 0 and equipped_slot < HOTBAR_SIZE:
		return hotbar[equipped_slot]
	return ""

func equip_slot(slot: int) -> void:
	if slot >= 0 and slot < HOTBAR_SIZE:
		equipped_slot = slot
		item_equipped.emit(get_equipped_item())

func cycle_hotbar() -> void:
	equipped_slot = (equipped_slot + 1) % HOTBAR_SIZE
	item_equipped.emit(get_equipped_item())

## Bring an item the player already owns onto the hotbar (if it isn't there yet) and select
## it — lets the backpack equip materials that didn't auto-fit in the 6 hotbar slots. Prefers
## an empty slot, otherwise overwrites the currently-equipped one.
func equip_item(item_id: String) -> void:
	if not has_item(item_id):
		return
	var slot: int = hotbar.find(item_id)
	if slot == -1:
		slot = hotbar.find("")
		if slot == -1:
			slot = equipped_slot
		hotbar[slot] = item_id
	equipped_slot = slot
	item_equipped.emit(get_equipped_item())
	inventory_changed.emit()

## Drag-drop: put an owned item type into a specific hotbar slot, swapping with whatever is
## there. If it came from the backpack, the displaced type simply returns to the backpack.
func move_to_hotbar_slot(item_id: String, slot: int) -> void:
	if slot < 0 or slot >= HOTBAR_SIZE or not has_item(item_id):
		return
	var from: int = hotbar.find(item_id)  # current hotbar slot, or -1 if in the backpack
	if from == slot:
		equipped_slot = slot
		item_equipped.emit(get_equipped_item())
		return
	var displaced: String = hotbar[slot]
	hotbar[slot] = item_id
	if from != -1:
		hotbar[from] = displaced  # swap within the hotbar
	equipped_slot = slot
	item_equipped.emit(get_equipped_item())
	inventory_changed.emit()

## Drag-drop: take an item type off the hotbar — it stays owned and shows up in the backpack.
func move_to_backpack(item_id: String) -> void:
	var s: int = hotbar.find(item_id)
	if s == -1:
		return
	hotbar[s] = ""
	if equipped_slot == s:
		equipped_slot = 0
	item_equipped.emit(get_equipped_item())
	inventory_changed.emit()

func _try_add_to_hotbar(item_id: String) -> void:
	if item_id in hotbar:
		return
	for i in HOTBAR_SIZE:
		if hotbar[i] == "":
			hotbar[i] = item_id
			return

func _remove_from_hotbar(item_id: String) -> void:
	for i in HOTBAR_SIZE:
		if hotbar[i] == item_id:
			hotbar[i] = ""
			if equipped_slot == i:
				equipped_slot = 0

## Wear a piece of armor: moves one from the inventory into the dedicated armor slot (preserving
## its current durability), returning any previously-worn armor to the inventory. Returns false
## if the item isn't owned armor.
func equip_armor(item_id: String) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null or item_data.type != ItemDatabase.ItemType.ARMOR:
		return false
	if not has_item(item_id):
		return false
	if item_id == equipped_armor:
		# Same piece: durability is tracked PER ID (max_stack 1), so "swapping" would silently
		# destroy one copy and hand the wear of the old one to the new (confirmed bug). No-op.
		return false
	if equipped_armor != "":
		unequip_armor()  # take the current one off first (back to inventory)
	var dur: int = get_durability(item_id)
	remove_item(item_id, 1)
	equipped_armor = item_id
	if item_data.durability > 0:
		item_durabilities[item_id] = dur if dur > 0 else item_data.durability
	armor_changed.emit(equipped_armor)
	return true

## Take off the worn armor — it returns to the inventory, keeping its remaining durability.
func unequip_armor() -> void:
	if equipped_armor == "":
		return
	var id: String = equipped_armor
	equipped_armor = ""
	if add_item(id, 1) == 0:
		# Stack had no room (another copy in the bag): drop it at the player's feet instead of
		# letting it silently vanish.
		if GameManager.player and is_instance_valid(GameManager.player):
			GameManager.spawn_drop(GameManager.player.global_position, id, 1)
	armor_changed.emit("")

## Wear down the worn armor by `amount` (called when it absorbs a hit). Breaks — and unequips —
## when it hits zero.
func use_armor_durability(amount: int = 1) -> void:
	if equipped_armor == "":
		return
	var item_data = ItemDatabase.get_item(equipped_armor)
	if item_data == null or item_data.durability < 0:
		return
	var current: int = item_durabilities.get(equipped_armor, item_data.durability)
	current -= amount
	if current <= 0:
		var broken: String = equipped_armor
		item_durabilities.erase(broken)
		equipped_armor = ""
		durability_changed.emit(broken, 0, item_data.durability)
		armor_changed.emit("")
	else:
		item_durabilities[equipped_armor] = current
		durability_changed.emit(equipped_armor, current, item_data.durability)

func set_item_durability(item_id: String, durability: int) -> void:
	var item_data = ItemDatabase.get_item(item_id)
	if not item_data or item_data.durability < 0:
		return
	item_durabilities[item_id] = durability
	durability_changed.emit(item_id, durability, item_data.durability)

func use_durability(item_id: String, amount: int = 1) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if not item_data or item_data.durability < 0:
		return true
	var current: int = item_durabilities.get(item_id, item_data.durability)
	current -= amount
	if current <= 0:
		remove_item(item_id, 1)
		item_durabilities.erase(item_id)
		return false
	item_durabilities[item_id] = current
	durability_changed.emit(item_id, current, item_data.durability)
	return true

func get_durability(item_id: String) -> int:
	var item_data = ItemDatabase.get_item(item_id)
	if not item_data:
		return -1
	return item_durabilities.get(item_id, item_data.durability)

func apply_crafting_result(new_inventory: Dictionary) -> void:
	items = new_inventory
	_rebuild_hotbar()
	inventory_changed.emit()

func _rebuild_hotbar() -> void:
	for i in HOTBAR_SIZE:
		if hotbar[i] != "" and not has_item(hotbar[i]):
			hotbar[i] = ""
