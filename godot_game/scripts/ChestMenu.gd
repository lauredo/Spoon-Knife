class_name ChestMenu
extends CanvasLayer

## Two-panel storage UI for a placed Chest: the player's inventory on the LEFT, the chest's
## contents on the RIGHT. Left-click moves an entire stack across; right-click moves a single
## item. Opened/closed by Chest.interact() (E); also auto-closes when the player walks away.
##
## Slots are plain Panels with an icon + count drawn as children, laid out at absolute positions
## (mirroring BackpackMenu). No drag-and-drop here — click-to-transfer keeps both sides simple.

var player: Player
var chest: Chest
var is_open: bool = false

var root: Panel
var inv_holder: Control
var chest_holder: Control
var inv_empty: Label
var chest_empty: Label
var chest_title: Label

# Design resolution is 1280x720 (see Main.tscn); centre is (640, 360).
const W := 664
const H := 396
const COL_W := 300
const COL_GAP := 24
const GRID_Y := 70          # below the column header
const SLOT := 60
const GAP := 8
const COLS := 4
const AUTO_CLOSE_DIST := 130.0

func _ready() -> void:
	_build_ui()
	close()

func setup(p: Player) -> void:
	player = p
	if player and player.inventory:
		player.inventory.inventory_changed.connect(_on_inv_changed)

func _on_inv_changed() -> void:
	if is_open:
		_refresh()

func _process(_delta: float) -> void:
	if not is_open:
		return
	# Close if the chest is gone or the player has wandered off.
	if player == null or chest == null or not is_instance_valid(chest):
		close()
		return
	if player.global_position.distance_to(chest.global_position) > AUTO_CLOSE_DIST:
		close()

func open(c: Chest, p: Player) -> void:
	chest = c
	if p:
		player = p
	is_open = true
	root.visible = true
	_refresh()

func close() -> void:
	is_open = false
	root.visible = false
	chest = null

func _build_ui() -> void:
	root = Panel.new()
	root.size = Vector2(W, H)
	root.position = Vector2(640 - W * 0.5, 360 - H * 0.5)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.96)
	style.set_border_width_all(2)
	style.border_color = Color(0.45, 0.35, 0.2)
	style.set_corner_radius_all(8)
	root.add_theme_stylebox_override("panel", style)
	add_child(root)

	var title := Label.new()
	title.text = "Baú"
	title.position = Vector2(14, 10)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	root.add_child(title)

	var hint := Label.new()
	hint.text = "clique: mover tudo  |  botão direito: mover 1  |  E / afastar: fechar"
	hint.position = Vector2(64, 17)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	root.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.size = Vector2(28, 28)
	close_btn.position = Vector2(W - 36, 8)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	root.add_child(close_btn)

	var sep := ColorRect.new()
	sep.color = Color(0.35, 0.28, 0.18)
	sep.size = Vector2(W - 20, 2)
	sep.position = Vector2(10, 40)
	root.add_child(sep)

	# LEFT column: player inventory.
	var inv_x := 14
	var inv_label := Label.new()
	inv_label.text = "Inventário"
	inv_label.position = Vector2(inv_x, 46)
	inv_label.add_theme_font_size_override("font_size", 14)
	inv_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.75))
	root.add_child(inv_label)

	inv_holder = Control.new()
	inv_holder.position = Vector2(inv_x, GRID_Y)
	root.add_child(inv_holder)

	inv_empty = _make_empty_label(inv_x)
	root.add_child(inv_empty)

	# RIGHT column: chest contents.
	var chest_x := inv_x + COL_W + COL_GAP
	chest_title = Label.new()
	chest_title.text = "Baú (0/%d)" % Chest.CAPACITY
	chest_title.position = Vector2(chest_x, 46)
	chest_title.add_theme_font_size_override("font_size", 14)
	chest_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.75))
	root.add_child(chest_title)

	# Subtle divider between the two columns.
	var col_sep := ColorRect.new()
	col_sep.color = Color(0.3, 0.24, 0.16)
	col_sep.size = Vector2(2, H - 80)
	col_sep.position = Vector2(inv_x + COL_W + COL_GAP * 0.5 - 1, 64)
	root.add_child(col_sep)

	chest_holder = Control.new()
	chest_holder.position = Vector2(chest_x, GRID_Y)
	root.add_child(chest_holder)

	chest_empty = _make_empty_label(chest_x)
	root.add_child(chest_empty)

func _make_empty_label(x: int) -> Label:
	var l := Label.new()
	l.text = "Vazio"
	l.size = Vector2(COL_W, 20)
	l.position = Vector2(x, H * 0.5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	return l

func _refresh() -> void:
	if not player:
		return
	_populate(inv_holder, inv_empty, _sorted_entries(player.inventory.items), false)
	var chest_entries: Array = _sorted_entries(chest.contents) if chest else []
	_populate(chest_holder, chest_empty, chest_entries, true)
	if chest_title and chest:
		chest_title.text = "Baú (%d/%d)" % [chest.contents.size(), Chest.CAPACITY]

func _sorted_entries(d: Dictionary) -> Array:
	var ids: Array = d.keys()
	ids.sort()
	var out: Array = []
	for id in ids:
		out.append([id, d[id]])
	return out

func _populate(holder: Control, empty_label: Label, entries: Array, is_chest: bool) -> void:
	for child in holder.get_children():
		child.queue_free()
	empty_label.visible = entries.is_empty()
	for i in entries.size():
		var col: int = i % COLS
		var row: int = i / COLS
		var slot := _make_slot(entries[i][0], entries[i][1], is_chest)
		slot.position = Vector2(col * (SLOT + GAP), row * (SLOT + GAP))
		holder.add_child(slot)

func _make_slot(item_id: String, count: int, is_chest: bool) -> Panel:
	var item_data = ItemDatabase.get_item(item_id)
	var slot := Panel.new()
	slot.size = Vector2(SLOT, SLOT)
	slot.clip_contents = true
	var move_hint := "Esquerdo: pegar tudo · Direito: pegar 1" if is_chest else "Esquerdo: guardar tudo · Direito: guardar 1"
	slot.tooltip_text = ItemDatabase.tooltip(item_id) + "\n" + move_hint

	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0.12, 0.12, 0.12, 0.9)
	slot_style.set_border_width_all(2)
	slot_style.border_color = Color(0.35, 0.35, 0.35)
	slot_style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", slot_style)

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
		tr.offset_bottom = -12
	else:
		var swatch := ColorRect.new()
		swatch.color = item_data.color if item_data else Color(0.5, 0.5, 0.5)
		swatch.size = Vector2(34, 34)
		swatch.position = Vector2(13, 8)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(swatch)

	var cnt := Label.new()
	cnt.text = str(count)
	cnt.position = Vector2(SLOT - 24, SLOT - 20)
	cnt.add_theme_font_size_override("font_size", 11)
	cnt.add_theme_color_override("font_color", Color.WHITE)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cnt)

	slot.gui_input.connect(_on_slot_input.bind(item_id, is_chest))
	return slot

func _on_slot_input(event: InputEvent, item_id: String, is_chest: bool) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var whole: bool = event.button_index == MOUSE_BUTTON_LEFT
	if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
		if is_chest:
			_withdraw(item_id, whole)
		else:
			_deposit(item_id, whole)

func _deposit(item_id: String, whole: bool) -> void:
	if chest == null or player == null:
		return
	var have: int = player.inventory.get_count(item_id)
	if have <= 0:
		return
	var amount: int = have if whole else 1
	var moved: int = chest.deposit(item_id, amount)
	if moved > 0:
		player.inventory.remove_item(item_id, moved)
	elif chest.is_full_for(item_id):
		_notify("Baú cheio")
	_refresh()

func _withdraw(item_id: String, whole: bool) -> void:
	if chest == null or player == null:
		return
	var have: int = chest.contents.get(item_id, 0)
	if have <= 0:
		return
	var amount: int = have if whole else 1
	var added: int = player.inventory.add_item(item_id, amount)
	if added > 0:
		chest.remove_contents(item_id, added)
	_refresh()

func _notify(msg: String) -> void:
	if GameManager.hud and GameManager.hud.has_method("show_notification"):
		GameManager.hud.show_notification(msg)
