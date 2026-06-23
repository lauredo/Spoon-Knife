class_name Chest
extends StaticBody2D

## A placed storage structure. Holds its own item stash (item_id -> count) and opens a two-panel
## transfer UI (ChestMenu) when the player interacts with it. Each chest keeps its OWN contents.

## How many DISTINCT item types one chest can hold. Each type stacks up to its ItemDatabase
## max_stack, mirroring how the player inventory stores items.
const CAPACITY := 16

var contents: Dictionary = {}  # item_id -> count

func _ready() -> void:
	collision_layer = 32  # structures (player collides; interact_area detects)
	collision_mask = 0

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	col.shape = shape
	col.position = Vector2(0, 2)
	add_child(col)

	var tex := Assets.item_icon("chest")  # reuse the chest icon as a placeholder world sprite
	if tex:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.show_behind_parent = true
		var s := 40.0 / float(tex.get_height())
		spr.scale = Vector2(s, s)
		add_child(spr)

func get_structure_type() -> String:
	return "chest"

func interact(player: Player) -> void:
	# Toggle the storage UI: open this chest, or close it if it's already the open one.
	var menu = GameManager.chest_menu
	if menu == null:
		return
	if menu.is_open and menu.chest == self:
		menu.close()
	else:
		menu.open(self, player)

## Try to store `amount` of an item type. Returns how many were actually stored (respecting the
## per-type max_stack and the chest's distinct-type capacity); the caller removes that many.
func deposit(item_id: String, amount: int) -> int:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null or amount <= 0:
		return 0
	var current: int = contents.get(item_id, 0)
	if current == 0 and contents.size() >= CAPACITY:
		return 0  # no slot free for a brand-new type
	var space: int = maxi(item_data.max_stack - current, 0)
	var can: int = mini(amount, space)
	if can <= 0:
		return 0
	contents[item_id] = current + can
	return can

## Remove up to `amount` of a type from the chest (used after the caller has accepted them).
func remove_contents(item_id: String, amount: int) -> void:
	var current: int = contents.get(item_id, 0)
	current -= amount
	if current <= 0:
		contents.erase(item_id)
	else:
		contents[item_id] = current

## True when the chest can't accept any more of this type (stack full, or no slot for a new type).
func is_full_for(item_id: String) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return true
	var current: int = contents.get(item_id, 0)
	if current == 0:
		return contents.size() >= CAPACITY
	return current >= item_data.max_stack

func _draw() -> void:
	# Procedural wooden chest (fallback / when no icon texture).
	if get_child_count() <= 1:  # only the collision shape -> no sprite, draw one
		var body := Color(0.5, 0.32, 0.14)
		var lid := Color(0.6, 0.4, 0.18)
		var iron := Color(0.32, 0.28, 0.26)
		draw_rect(Rect2(-16, -4, 32, 16), body)
		draw_rect(Rect2(-16, -12, 32, 9), lid)
		draw_rect(Rect2(-16, -4, 32, 2), iron)
		draw_rect(Rect2(-3, -8, 6, 7), iron)
		draw_rect(Rect2(-16, -12, 32, 24), Color(0.2, 0.12, 0.05), false, 1.5)
