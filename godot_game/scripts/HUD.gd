class_name HUD
extends CanvasLayer

## Display names for the internal phase keys ("Day"/"Dusk"/... are compared as strings in Main.gd).
const PHASE_NAMES := {"Day": "Dia", "Dusk": "Entardecer", "Night": "Noite", "Dawn": "Amanhecer"}

var player: Player
var day_night: DayNightCycle

var health_bar: ProgressBar
var hunger_bar: ProgressBar
var sanity_bar: ProgressBar
var energy_bar: ProgressBar
var temp_bar: ProgressBar
var _exhaust_warned: bool = false

# Condition chips (Sangrando/Enjoado/Congelando) — icons beside the stats panel, not a 6th bar.
var _cond_box: VBoxContainer
var _prev_conds: Array = []
const COND_TEACH := {
	"🩸 Sangrando": "🩸 Você está sangrando — uma bandagem estanca",
	"🤢 Enjoado": "🤢 Comida estragada — a pomada resolve; energia e fome sofrem",
	"🥶 Congelando": "🥶 Você está congelando — procure fogo ou um teto!",
}
var day_label: Label
var phase_label: Label
var clock: DayNightClock
var hotbar_panel: Panel
var hotbar_slots: Array = []
# Notifications stack (up to NOTIF_MAX at once) — a single label made simultaneous events
# (dawn: phase + weather + autosave + quest) overwrite each other.
var notification_box: VBoxContainer
var _notifs: Array = []  # [{label: Label, timer: float}]
const NOTIF_MAX := 4

# Sanity legibility (one-shot teaching messages)
var _sanity_taught: bool = false   # first drop below the horror threshold
var _dark_warned: bool = false     # re-arms each day; fires when night-dark drain starts

var insanity_overlay: ColorRect
var insanity_phase: float = 0.0

var quest_label: Label
var perks_label: Label
var armor_panel: Panel
var armor_name_label: Label
var armor_dur_bar: ProgressBar
var armor_swatch: ColorRect
var armor_icon: TextureRect

const HOTBAR_SIZE := 6

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# ── Stats Panel (top-left) ──────────────────────────────────
	var stats_panel := Panel.new()
	stats_panel.size = Vector2(200, 180)
	stats_panel.position = Vector2(10, 10)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.05, 0.75)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	stats_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(stats_panel)

	health_bar = _make_bar(stats_panel, "Vida", "heart", Color(0.85, 0.15, 0.15), Color(0.2, 0.05, 0.05), 10, 10)
	hunger_bar = _make_bar(stats_panel, "Fome", "hunger", Color(0.9, 0.65, 0.15), Color(0.2, 0.15, 0.0), 10, 45)
	sanity_bar = _make_bar(stats_panel, "Sanidade", "sanity", Color(0.3, 0.5, 0.95), Color(0.05, 0.05, 0.2), 10, 80)
	energy_bar = _make_bar(stats_panel, "Energia", "energy", Color(0.55, 0.82, 0.25), Color(0.1, 0.14, 0.03), 10, 115)
	temp_bar = _make_bar(stats_panel, "Calor", "temp", Color(0.9, 0.55, 0.25), Color(0.16, 0.08, 0.02), 10, 150)

	_cond_box = VBoxContainer.new()
	_cond_box.position = Vector2(218, 10)
	_cond_box.add_theme_constant_override("separation", 4)
	add_child(_cond_box)

	# ── Armor slot (left, under stats) ─────────────────────────
	armor_panel = Panel.new()
	armor_panel.size = Vector2(200, 52)
	armor_panel.position = Vector2(10, 198)
	armor_panel.add_theme_stylebox_override("panel", panel_style)
	armor_panel.tooltip_text = "Clique para tirar a armadura"
	add_child(armor_panel)
	armor_panel.gui_input.connect(_on_armor_panel_input)

	# ── Perks (S6): star counter; hover lists unlocked perks + the locked milestones ──
	perks_label = Label.new()
	perks_label.position = Vector2(14, 256)
	perks_label.add_theme_font_size_override("font_size", 12)
	perks_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	perks_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	perks_label.add_theme_constant_override("outline_size", 3)
	perks_label.mouse_filter = Control.MOUSE_FILTER_STOP  # tooltip needs hover
	add_child(perks_label)
	GameManager.perk_unlocked.connect(_on_perk_unlocked)
	_update_perks_label()

	var armor_title := Label.new()
	armor_title.text = "Armadura"
	armor_title.position = Vector2(10, 4)
	armor_title.add_theme_font_size_override("font_size", 11)
	armor_title.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	armor_panel.add_child(armor_title)

	armor_swatch = ColorRect.new()
	armor_swatch.size = Vector2(20, 20)
	armor_swatch.position = Vector2(11, 24)
	armor_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	armor_panel.add_child(armor_swatch)

	armor_icon = TextureRect.new()
	armor_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	armor_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	armor_icon.position = Vector2(8, 22)
	armor_icon.size = Vector2(24, 24)
	armor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	armor_panel.add_child(armor_icon)

	armor_name_label = Label.new()
	armor_name_label.position = Vector2(40, 21)
	armor_name_label.add_theme_font_size_override("font_size", 12)
	armor_name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	armor_panel.add_child(armor_name_label)

	armor_dur_bar = ProgressBar.new()
	armor_dur_bar.position = Vector2(40, 39)
	armor_dur_bar.size = Vector2(150, 6)
	armor_dur_bar.min_value = 0.0
	armor_dur_bar.max_value = 1.0
	armor_dur_bar.value = 1.0
	armor_dur_bar.show_percentage = false
	armor_dur_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	armor_panel.add_child(armor_dur_bar)

	# ── Day/Time clock (top-center) ────────────────────────────
	var time_panel := Panel.new()
	time_panel.size = Vector2(208, 74)
	time_panel.position = Vector2(536, 8)
	time_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(time_panel)

	clock = DayNightClock.new()
	clock.position = Vector2(8, 6)
	clock.size = Vector2(60, 60)
	time_panel.add_child(clock)

	day_label = Label.new()
	day_label.position = Vector2(80, 14)
	day_label.size = Vector2(120, 24)
	day_label.add_theme_font_size_override("font_size", 16)
	day_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	time_panel.add_child(day_label)

	phase_label = Label.new()
	phase_label.position = Vector2(80, 40)
	phase_label.size = Vector2(120, 20)
	phase_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	time_panel.add_child(phase_label)

	# ── Hotbar (bottom-center) ──────────────────────────────────
	hotbar_panel = Panel.new()
	hotbar_panel.size = Vector2(HOTBAR_SIZE * 52 + 8, 60)
	hotbar_panel.position = Vector2(640 - (HOTBAR_SIZE * 52 + 8) * 0.5, 660)
	hotbar_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(hotbar_panel)

	for i in HOTBAR_SIZE:
		var slot := InventorySlot.new()
		slot.zone = "hotbar"
		slot.slot_index = i
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.12, 0.12, 0.12, 0.9)
		slot_style.border_width_left = 2
		slot_style.border_width_right = 2
		slot_style.border_width_top = 2
		slot_style.border_width_bottom = 2
		slot_style.border_color = Color(0.35, 0.35, 0.35)
		slot_style.corner_radius_top_left = 4
		slot_style.corner_radius_top_right = 4
		slot_style.corner_radius_bottom_left = 4
		slot_style.corner_radius_bottom_right = 4
		slot.add_theme_stylebox_override("panel", slot_style)
		slot.size = Vector2(48, 48)
		slot.position = Vector2(4 + i * 52, 6)
		hotbar_panel.add_child(slot)
		hotbar_slots.append(slot)
		slot.gui_input.connect(_on_hotbar_slot_input.bind(i))

		var num_label := Label.new()
		num_label.name = "SlotNumber"  # identified by name so _update_slot never clears it
		num_label.text = str(i + 1)
		num_label.position = Vector2(2, 0)
		num_label.add_theme_font_size_override("font_size", 9)
		num_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		slot.add_child(num_label)

	# ── Quest tracker (top-right) ──────────────────────────────
	quest_label = Label.new()
	quest_label.position = Vector2(820, 14)
	quest_label.size = Vector2(450, 40)
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quest_label.add_theme_font_size_override("font_size", 12)
	quest_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	add_child(quest_label)

	# ── Notifications (center, bottom-anchored stack; newest at the bottom) ─────
	notification_box = VBoxContainer.new()
	notification_box.position = Vector2(340, 498)
	notification_box.size = Vector2(600, 112)
	notification_box.alignment = BoxContainer.ALIGNMENT_END
	notification_box.add_theme_constant_override("separation", 2)
	add_child(notification_box)

	# ── Insanity Overlay ──────────────────────────────────────
	insanity_overlay = ColorRect.new()
	insanity_overlay.size = Vector2(1280, 720)
	insanity_overlay.color = Color(0.15, 0.0, 0.2, 0.0)
	insanity_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(insanity_overlay)

	# Controls hint (bottom-left)
	var hint_label := Label.new()
	hint_label.position = Vector2(10, 600)
	hint_label.text = "WASD: Mover  |  Clique esq.: Atacar  |  E: Interagir/Pegar  |  T: Criação  |  I: Mochila  |  M: Mapa  |  Espaço: Esquiva  |  F: Trocar item  |  =/-: Tempo  |  F1: Debug"
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.8))
	add_child(hint_label)

func _make_bar(parent: Control, label_text: String, icon_name: String, fill_color: Color, bg_color: Color, x: int, y: int) -> ProgressBar:
	# Icon when available (SVG UI), otherwise fall back to a text label.
	var icon := Assets.texture("res://assets/ui/%s.svg" % icon_name)
	if icon:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.position = Vector2(x, y - 2)
		tr.size = Vector2(22, 22)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		parent.add_child(tr)
	else:
		var lbl := Label.new()
		lbl.text = label_text
		lbl.position = Vector2(x, y)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		parent.add_child(lbl)

	var bar := ProgressBar.new()
	bar.position = Vector2(x + 55, y + 2)
	bar.size = Vector2(130, 16)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = bg_color
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = fill_color
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", bar_fill)

	parent.add_child(bar)
	return bar

func setup(p: Player, dnc: DayNightCycle) -> void:
	player = p
	day_night = dnc

	if player and player.stats:
		player.stats.health_changed.connect(_on_health_changed)
		player.stats.hunger_changed.connect(_on_hunger_changed)
		player.stats.sanity_changed.connect(_on_sanity_changed)
		player.stats.energy_changed.connect(_on_energy_changed)
		player.stats.temperature_changed.connect(_on_temperature_changed)
		player.inventory.inventory_changed.connect(_update_hotbar)
		# Selecting a slot (number keys / F cycle) only emits item_equipped, so refresh the
		# highlight on that too — otherwise the selector visually sticks to the old slot.
		player.inventory.item_equipped.connect(_update_hotbar.unbind(1))
		# Worn armor: refresh the indicator when it changes or wears down.
		player.inventory.armor_changed.connect(_update_armor.unbind(1))
		player.inventory.durability_changed.connect(_update_armor.unbind(3))

	if day_night:
		day_night.time_updated.connect(_on_time_updated)
		day_night.phase_changed.connect(_on_phase_changed)

	_update_hotbar()  # render any starting items (e.g. the axe) right away
	_update_armor()

func _process(delta: float) -> void:
	# Notification stack: each entry runs its own timer and fades in its last 0.5s
	for i in range(_notifs.size() - 1, -1, -1):
		var n = _notifs[i]
		n["timer"] -= delta
		if n["timer"] <= 0.0:
			n["label"].queue_free()
			_notifs.remove_at(i)
		elif n["timer"] <= 0.5:
			n["label"].modulate.a = n["timer"] * 2.0

	# Night-dark sanity drain warning: once per night, the moment it starts biting.
	if player and player.stats:
		if player.stats.is_day:
			_dark_warned = false
		elif not player.stats.in_light and not _dark_warned:
			_dark_warned = true
			show_notification("☠ No escuro sua mente escoa rápido — fique perto da luz!", 4.0)

	_update_conditions()

	# Insanity effect
	if player and player.stats.is_low_sanity():
		insanity_phase += delta * 2.0
		var intensity := player.stats.get_insanity_intensity()
		insanity_overlay.color.a = sin(insanity_phase) * 0.08 * intensity
	else:
		insanity_overlay.color.a = 0.0

func _on_health_changed(current: float, maximum: float) -> void:
	if health_bar:
		health_bar.value = current / maximum

func _on_hunger_changed(current: float, maximum: float) -> void:
	if hunger_bar:
		hunger_bar.value = current / maximum

func _on_sanity_changed(current: float, maximum: float) -> void:
	if sanity_bar:
		sanity_bar.value = current / maximum
	# The recovery rule (hit shadows) is invisible until taught — one-shot lesson when the
	# horror threshold is first crossed and shadows start appearing.
	if not _sanity_taught and current < maximum * PlayerStats.SANITY_LOW_PCT:
		_sanity_taught = true
		show_notification("🌀 Sua mente vacila... golpear as SOMBRAS recupera sanidade", 5.0)

func _on_energy_changed(current: float, maximum: float) -> void:
	if energy_bar:
		energy_bar.value = current / maximum
	# Exhaustion teach: fires on hitting zero, re-arms after a real recovery.
	if current <= 0.001 and not _exhaust_warned:
		_exhaust_warned = true
		show_notification("😴 Exausto — durma numa cama para recuperar (-30% de velocidade)", 4.5)
	elif current > maximum * 0.3:
		_exhaust_warned = false

func _on_temperature_changed(current: float, maximum: float) -> void:
	if temp_bar:
		temp_bar.value = current / maximum

func _on_perk_unlocked(_id: String) -> void:
	_update_perks_label()

func _update_perks_label() -> void:
	perks_label.text = "⭐ Perks: %d/%d" % [GameManager.perks.size(), GameManager.PERKS.size()]
	var lines := PackedStringArray()
	for id in GameManager.PERKS:
		var p: Dictionary = GameManager.PERKS[id]
		if GameManager.perks.has(id):
			lines.append("✓ %s — %s" % [p["nome"], p["desc"]])
		else:
			lines.append("🔒 %s — %s" % [p["nome"], p["marco"]])
	perks_label.tooltip_text = "\n".join(lines)

## Condition chips + their teach notifications: rebuilt only when the active set changes.
func _update_conditions() -> void:
	if player == null or player.stats == null:
		return
	var conds: Array = []
	if player.stats.is_bleeding():
		conds.append("🩸 Sangrando")
	if player.stats.is_sick():
		conds.append("🤢 Enjoado")
	if player.stats.is_cold():
		conds.append("🥶 Congelando")
	if conds == _prev_conds:
		return
	for c in conds:
		if not c in _prev_conds and COND_TEACH.has(c):
			show_notification(COND_TEACH[c], 4.0)
	_prev_conds = conds
	for child in _cond_box.get_children():
		child.queue_free()
	for c in conds:
		var lbl := Label.new()
		lbl.text = c
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.8))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		lbl.add_theme_constant_override("outline_size", 3)
		_cond_box.add_child(lbl)

func _on_time_updated(t: float) -> void:
	if clock:
		if day_night:
			clock.set_moon(day_night.moon_phase(), day_night.tide_level())
		clock.set_time(t)
	if day_label and day_night:
		day_label.text = "Dia %d" % day_night.day_number
	if phase_label and day_night:
		phase_label.text = _phase_display(day_night.get_phase_name())

func _on_phase_changed(phase_name: String, day_num: int) -> void:
	if phase_label:
		phase_label.text = _phase_display(phase_name)
	if clock:
		clock.phase = phase_name  # raw internal key on purpose (only Main.gd compares phases)
	show_notification(_phase_display(phase_name))

## Phase names are internal logic keys (Main.gd compares them); translate only at display time.
func _phase_display(phase_name: String) -> String:
	return PHASE_NAMES.get(phase_name, phase_name)

func _update_hotbar() -> void:
	if not player:
		return
	for i in HOTBAR_SIZE:
		_update_slot(i)

## Refresh the worn-armor indicator (icon/colour, name + % block, durability bar).
func _update_armor() -> void:
	if not player or armor_name_label == null:
		return
	var id: String = player.inventory.equipped_armor
	if id == "":
		armor_name_label.text = "Nenhuma"
		armor_name_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		armor_dur_bar.visible = false
		armor_icon.visible = false
		armor_swatch.visible = false
		return
	var data = ItemDatabase.get_item(id)
	if data == null:
		return
	armor_name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	armor_name_label.text = "%s  %d%%" % [data.display_name, roundi(data.armor * 100.0)]
	var icon := Assets.item_icon(id)
	if icon:
		armor_icon.texture = icon
		armor_icon.visible = true
		armor_swatch.visible = false
	else:
		armor_swatch.color = data.color
		armor_swatch.visible = true
		armor_icon.visible = false
	if data.durability > 0:
		armor_dur_bar.visible = true
		armor_dur_bar.value = float(player.inventory.get_durability(id)) / float(data.durability)
	else:
		armor_dur_bar.visible = false

## Click the armor indicator to take the current armor off (back into the inventory).
func _on_armor_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if player and player.inventory.equipped_armor != "":
			player.inventory.unequip_armor()

func _update_slot(i: int) -> void:
	var slot: InventorySlot = hotbar_slots[i]
	slot.inv = player.inventory
	slot.item_id = player.inventory.hotbar[i] if i < player.inventory.hotbar.size() else ""
	slot.tooltip_text = ""
	# Remove old item visuals (icon + count), keeping only the persistent slot-number label.
	# (Was keyed off text length, which wrongly kept single-digit count labels → ghost numbers.)
	for child in slot.get_children():
		if child.name == "SlotNumber":
			continue
		child.queue_free()

	var item_id: String = player.inventory.hotbar[i] if i < player.inventory.hotbar.size() else ""
	var is_equipped := i == player.inventory.equipped_slot
	var slot_style: StyleBoxFlat = slot.get_theme_stylebox("panel")
	if slot_style:
		slot_style.border_color = Color(1.0, 0.85, 0.2) if is_equipped else Color(0.35, 0.35, 0.35)

	if item_id == "":
		return

	var item_data = ItemDatabase.get_item(item_id)
	if not item_data:
		return
	var action := "Esquerdo: selecionar"
	if item_data.type == ItemDatabase.ItemType.FOOD:
		action = "Esquerdo: comer"
	elif item_data.type == ItemDatabase.ItemType.MEDICINE:
		action = "Esquerdo: usar"
	elif item_data.type == ItemDatabase.ItemType.ARMOR:
		action = "Esquerdo: vestir"
	slot.tooltip_text = ItemDatabase.tooltip(item_id) + "\n" + action + " · Direito: soltar 1"

	# Item icon (fallback to color swatch when no sprite exists). Size via anchors so a large
	# (256px) icon texture can't override the rect and overflow the slot.
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
		tr.offset_top = 6
		tr.offset_right = -6
		tr.offset_bottom = -6
	else:
		var swatch := ColorRect.new()
		swatch.color = item_data.color
		swatch.size = Vector2(30, 30)
		swatch.position = Vector2(9, 10)
		slot.add_child(swatch)

	# Count label
	var count := player.inventory.get_count(item_id)
	if count > 1:
		var cnt_lbl := Label.new()
		cnt_lbl.text = str(count)
		cnt_lbl.position = Vector2(28, 32)
		cnt_lbl.add_theme_font_size_override("font_size", 10)
		cnt_lbl.add_theme_color_override("font_color", Color.WHITE)
		slot.add_child(cnt_lbl)

## Hotbar slot interaction (acts on RELEASE so press-and-drag still works):
##   left-click  -> use it if it's a consumable (food/medicine), otherwise select the slot
##   right-click -> drop one of that item on the ground
func _on_hotbar_slot_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton) or event.pressed or not player:
		return
	var id: String = player.inventory.hotbar[index] if index < player.inventory.hotbar.size() else ""
	if event.button_index == MOUSE_BUTTON_LEFT:
		if id == "":
			player.inventory.equip_slot(index)
			return
		var item_data = ItemDatabase.get_item(id)
		if item_data and (item_data.type == ItemDatabase.ItemType.FOOD or item_data.type == ItemDatabase.ItemType.MEDICINE):
			player.eat_item(id)
		elif item_data and item_data.type == ItemDatabase.ItemType.ARMOR:
			player.inventory.equip_armor(id)
		else:
			player.inventory.equip_slot(index)
	elif event.button_index == MOUSE_BUTTON_RIGHT and id != "":
		_drop_one(id)

## Drop one of an item type on the ground next to the player.
func _drop_one(item_id: String) -> void:
	if not player or not player.inventory.has_item(item_id):
		return
	if player.inventory.remove_item(item_id, 1):
		GameManager.spawn_drop(player.global_position, item_id, 1)

## Quest tracker line (fed by QuestSystem's 0.5s poll).
func set_quest_text(t: String) -> void:
	if quest_label:
		quest_label.text = t

func show_notification(text: String, duration: float = 2.5) -> void:
	# Same text already on screen → refresh it instead of stacking a duplicate.
	for n in _notifs:
		if n["label"].text == text:
			n["timer"] = duration
			n["label"].modulate.a = 1.0
			return
	if _notifs.size() >= NOTIF_MAX:
		var oldest = _notifs.pop_front()
		oldest["label"].queue_free()
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	notification_box.add_child(lbl)
	_notifs.append({"label": lbl, "timer": duration})

func show_game_over() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.size = Vector2(1280, 720)
	add_child(overlay)

	var go_label := Label.new()
	go_label.text = "VOCÊ MORREU"
	go_label.position = Vector2(490, 280)
	go_label.add_theme_font_size_override("font_size", 48)
	go_label.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	add_child(go_label)

	# Endless survival: the score IS how long you lasted.
	var days_label := Label.new()
	days_label.text = "Sobreviveu %d dia%s" % [GameManager.current_day, "" if GameManager.current_day == 1 else "s"]
	days_label.position = Vector2(553, 334)
	days_label.add_theme_font_size_override("font_size", 20)
	days_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	add_child(days_label)

	var sub_label := Label.new()
	sub_label.text = "Pressione R para recomeçar"
	sub_label.position = Vector2(535, 372)
	sub_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.7))
	add_child(sub_label)

	var tween := create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.7), 1.5)

func show_victory() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.size = Vector2(1280, 720)
	add_child(overlay)

	var title := Label.new()
	title.text = "VOCÊ SOBREVIVEU!"
	title.position = Vector2(440, 270)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.45, 0.92, 0.45))
	add_child(title)

	var sub_label := Label.new()
	sub_label.text = "Você venceu — pressione R para jogar de novo"
	sub_label.position = Vector2(420, 350)
	sub_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	add_child(sub_label)

	var tween := create_tween()
	tween.tween_property(overlay, "color", Color(0, 0.06, 0, 0.6), 1.5)
