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
var _dragging: bool = false

func _ready() -> void:
	set_process(false)  # only the slot being dragged processes (to follow the mouse)

func _get_drag_data(_pos: Vector2):
	if item_id == "" or inv == null:
		return null
	_spawn_preview()
	_dragging = true
	set_process(true)
	return {"item_id": item_id, "from_zone": zone}

func _can_drop_data(_pos: Vector2, data) -> bool:
	return inv != null and data is Dictionary and data.has("item_id")

func _drop_data(_pos: Vector2, data) -> void:
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
		_dragging = false
		set_process(false)
		_kill_preview()

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
