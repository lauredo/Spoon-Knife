class_name InventorySlot
extends Panel

## A Panel that supports drag-and-drop of an item TYPE between the hotbar and the backpack.
## The owning UI (HUD / BackpackMenu) sets `inv`, `zone`, `slot_index` and `item_id` and draws
## the icon/label as children. Dropping emits inventory_changed, which both UIs listen to.
##
## The dragged icon is drawn on our OWN high CanvasLayer (not Godot's set_drag_preview, whose
## preview rendered BEHIND the backpack's CanvasLayer). The drag DATA still flows normally, so
## dropping works regardless of the preview.

var inv: Inventory = null
var zone: String = "hotbar"   # "hotbar" or "backpack"
var slot_index: int = -1      # hotbar slot index (when zone == "hotbar")
var item_id: String = ""      # the item type currently shown here ("" = empty)

static var _preview: CanvasLayer = null
static var _preview_icon: TextureRect = null
# Set true by whichever slot consumes a drop; the source slot reads it on DRAG_END to decide
# whether the drag instead ended over the open world (→ drop the stack on the ground).
static var _drop_consumed: bool = false
var _dragging: bool = false

func _ready() -> void:
	set_process(false)  # only the slot being dragged processes (to follow the mouse)

func _get_drag_data(_pos: Vector2):
	if item_id == "" or inv == null:
		return null
	_drop_consumed = false
	_spawn_preview()
	_dragging = true
	set_process(true)
	return {"item_id": item_id, "from_zone": zone}

func _can_drop_data(_pos: Vector2, data) -> bool:
	return inv != null and data is Dictionary and data.has("item_id")

func _drop_data(_pos: Vector2, data) -> void:
	_drop_consumed = true  # a slot took it — the source slot must NOT also drop it on the ground
	var id: String = data["item_id"]
	if zone == "hotbar":
		inv.move_to_hotbar_slot(id, slot_index)
	else:
		inv.move_to_backpack(id)

func _process(_delta: float) -> void:
	if _dragging and _preview_icon and is_instance_valid(_preview_icon):
		_preview_icon.position = get_viewport().get_mouse_position() - Vector2(22, 22)

func _notification(what: int) -> void:
	# DRAG_END is broadcast to all controls — clean up the shared preview when any drag ends.
	if what == NOTIFICATION_DRAG_END:
		# Only the slot that started the drag acts; if no slot consumed the drop, the player let go
		# over the world → toss the stack out onto the ground.
		if _dragging and not _drop_consumed:
			_try_drop_to_ground()
		_dragging = false
		set_process(false)
		_kill_preview()

## Released over the open world (no slot took the drop and no UI is under the cursor) → drop the
## whole stack on the ground next to the player.
func _try_drop_to_ground() -> void:
	if item_id == "" or inv == null:
		return
	if get_viewport().gui_get_hovered_control() != null:
		return  # released over a UI control, not the world → treat as a cancel
	var p = GameManager.player
	if p == null or not is_instance_valid(p):
		return
	# Capture the id NOW: remove_item() below emits inventory_changed, which the HUD handles by
	# rewriting this very slot's `item_id` to the (now empty) hotbar entry. Reading item_id after
	# that would drop an empty id → a blank, uncollectable blob on the ground.
	var id := item_id
	var amount: int = inv.get_count(id)
	if amount <= 0:
		return
	if inv.remove_item(id, amount):
		GameManager.spawn_drop(p.global_position, id, amount)

func _exit_tree() -> void:
	if _dragging:
		_kill_preview()

func _spawn_preview() -> void:
	_kill_preview()
	var icon := Assets.item_icon(item_id)
	if icon == null:
		return
	_preview = CanvasLayer.new()
	_preview.layer = 128  # above every UI layer so the dragged icon is never hidden
	get_tree().root.add_child(_preview)
	_preview_icon = TextureRect.new()
	_preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_icon.texture = icon
	_preview_icon.size = Vector2(44, 44)
	# The preview follows the cursor, so it sits directly under the mouse. Without this it would
	# intercept the drag hit-test (TextureRect defaults to MOUSE_FILTER_PASS) and every drop target
	# showed the "forbidden" cursor. IGNORE makes the drop fall through to the real slot below.
	_preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_icon.modulate = Color(1, 1, 1, 0.9)
	_preview_icon.position = get_viewport().get_mouse_position() - Vector2(22, 22)
	_preview.add_child(_preview_icon)

func _kill_preview() -> void:
	if _preview and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null
	_preview_icon = null
