class_name Inventory
extends Node

signal inventory_changed
signal item_equipped(item_id: String)
signal durability_changed(item_id: String, current: int, maximum: int)

const HOTBAR_SIZE := 6

var items: Dictionary = {}
var equipped_slot: int = 0
var hotbar: Array = []
var item_durabilities: Dictionary = {}

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
