class_name BackpackMenu
extends CanvasLayer

## Full inventory view. The hotbar (HUD) only shows 6 equippable slots, but the player can
## hold any number of item types in `inventory.items`. This panel lists ALL of them so nothing
## stays invisible/unreachable; clicking a slot brings that item onto the hotbar and selects it.
##
## Slots are laid out with absolute positions (no Container) to mirror the HUD hotbar exactly —
## TextureRect icons inside a Button/GridContainer rendered at full texture size, overflowing.

var player: Player
var is_open: bool = false

var panel: Panel
var slots_holder: Control
var empty_label: Label

const PANEL_W := 380
const MIN_H := 140
const HOLDER_Y := 50    # below the title/separator
const SLOT := 60
const GAP := 6
const COLS := 5

func _ready() -> void:
	_build_ui()
	hide_menu()

func _build_ui() -> void:
	panel = Panel.new()
	panel.size = Vector2(PANEL_W, MIN_H)
	panel.position = Vector2(640 - PANEL_W * 0.5, 360 - MIN_H * 0.5)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.45, 0.35, 0.2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var title := Label.new()
	title.text = "Backpack"
	title.position = Vector2(12, 10)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	panel.add_child(title)

	var hint := Label.new()
	hint.text = "click to equip"
	hint.position = Vector2(120, 17)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	panel.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.size = Vector2(28, 28)
	close_btn.position = Vector2(PANEL_W - 36, 8)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(hide_menu)
	panel.add_child(close_btn)

	var sep := ColorRect.new()
	sep.color = Color(0.35, 0.28, 0.18)
	sep.size = Vector2(PANEL_W - 12, 2)
	sep.position = Vector2(6, 40)
	panel.add_child(sep)

	slots_holder = Control.new()
	slots_holder.position = Vector2(12, HOLDER_Y)
	slots_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(slots_holder)

	empty_label = Label.new()
	empty_label.text = "Empty"
	empty_label.size = Vector2(PANEL_W, 20)
	empty_label.position = Vector2(0, MIN_H * 0.5 - 10)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(empty_label)

func setup(p: Player) -> void:
	player = p
	if player and player.inventory:
		player.inventory.inventory_changed.connect(_on_inventory_changed)

func _on_inventory_changed() -> void:
	if is_open:
		_refresh()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_inventory"):
		if is_open:
			hide_menu()
		else:
			show_menu()

func show_menu() -> void:
	is_open = true
	panel.visible = true
	_refresh()

func hide_menu() -> void:
	is_open = false
	panel.visible = false

func _refresh() -> void:
	for child in slots_holder.get_children():
		child.queue_free()
	if not player:
		return

	var ids := player.inventory.items.keys()
	ids.sort()
	empty_label.visible = ids.is_empty()

	for i in ids.size():
		var col: int = i % COLS
		var row: int = i / COLS
		var item_id: String = ids[i]
		var slot := _make_slot(item_id)
		slot.position = Vector2(col * (SLOT + GAP), row * (SLOT + GAP))
		slots_holder.add_child(slot)

	# Grow the panel to fit the rows, keeping it centred.
	var rows: int = maxi(1, int(ceil(float(ids.size()) / float(COLS))))
	var content_h: int = HOLDER_Y + rows * (SLOT + GAP) + 8
	panel.size.y = maxi(MIN_H, content_h)
	panel.position = Vector2(640 - PANEL_W * 0.5, 360 - panel.size.y * 0.5)
	empty_label.position.y = panel.size.y * 0.5 - 10

func _make_slot(item_id: String) -> Control:
	var item_data = ItemDatabase.get_item(item_id)
	var slot := Panel.new()
	slot.size = Vector2(SLOT, SLOT)
	slot.clip_contents = true  # never let an oversized icon spill past the slot frame
	slot.tooltip_text = item_data.display_name if item_data else item_id

	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0.12, 0.12, 0.12, 0.9)
	slot_style.border_width_left = 2
	slot_style.border_width_right = 2
	slot_style.border_width_top = 2
	slot_style.border_width_bottom = 2
	var equipped := player.inventory.get_equipped_item() == item_id
	slot_style.border_color = Color(1.0, 0.85, 0.2) if equipped else Color(0.35, 0.35, 0.35)
	slot_style.corner_radius_top_left = 4
	slot_style.corner_radius_top_right = 4
	slot_style.corner_radius_bottom_left = 4
	slot_style.corner_radius_bottom_right = 4
	slot.add_theme_stylebox_override("panel", slot_style)

	# Item icon (fallback to a colour swatch when no sprite exists). Size it via anchors so the
	# icon's own (4x-rasterised) texture size can't override the slot dimensions.
	var icon := Assets.item_icon(item_id)
	if icon:
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = icon
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tr)
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 6
		tr.offset_top = 4
		tr.offset_right = -6
		tr.offset_bottom = -12  # leave room for the count label
	else:
		var swatch := ColorRect.new()
		swatch.color = item_data.color if item_data else Color(0.5, 0.5, 0.5)
		swatch.size = Vector2(34, 34)
		swatch.position = Vector2(13, 8)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(swatch)

	# Stack count.
	var count := player.inventory.get_count(item_id)
	var cnt := Label.new()
	cnt.text = str(count)
	cnt.position = Vector2(SLOT - 24, SLOT - 20)
	cnt.add_theme_font_size_override("font_size", 11)
	cnt.add_theme_color_override("font_color", Color.WHITE)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cnt)

	slot.gui_input.connect(_on_slot_gui_input.bind(item_id))
	return slot

func _on_slot_gui_input(event: InputEvent, item_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if player:
			player.inventory.equip_item(item_id)
			_refresh()
