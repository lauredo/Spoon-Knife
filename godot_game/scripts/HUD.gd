class_name HUD
extends CanvasLayer

var player: Player
var day_night: DayNightCycle

var health_bar: ProgressBar
var hunger_bar: ProgressBar
var sanity_bar: ProgressBar
var day_label: Label
var phase_label: Label
var hotbar_panel: Panel
var hotbar_slots: Array = []
var notification_label: Label
var notification_timer: float = 0.0

var insanity_overlay: ColorRect
var insanity_phase: float = 0.0

const HOTBAR_SIZE := 6

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# ── Stats Panel (top-left) ──────────────────────────────────
	var stats_panel := Panel.new()
	stats_panel.size = Vector2(200, 110)
	stats_panel.position = Vector2(10, 10)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.05, 0.75)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	stats_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(stats_panel)

	health_bar = _make_bar(stats_panel, "Health", Color(0.85, 0.15, 0.15), Color(0.2, 0.05, 0.05), 10, 10)
	hunger_bar = _make_bar(stats_panel, "Hunger", Color(0.9, 0.65, 0.15), Color(0.2, 0.15, 0.0), 10, 45)
	sanity_bar = _make_bar(stats_panel, "Sanity", Color(0.3, 0.5, 0.95), Color(0.05, 0.05, 0.2), 10, 80)

	# ── Day/Time (top-center) ──────────────────────────────────
	var time_panel := Panel.new()
	time_panel.size = Vector2(160, 50)
	time_panel.position = Vector2(560, 10)
	time_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(time_panel)

	day_label = Label.new()
	day_label.position = Vector2(8, 6)
	day_label.size = Vector2(144, 20)
	day_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	time_panel.add_child(day_label)

	phase_label = Label.new()
	phase_label.position = Vector2(8, 26)
	phase_label.size = Vector2(144, 20)
	phase_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	time_panel.add_child(phase_label)

	# ── Hotbar (bottom-center) ──────────────────────────────────
	hotbar_panel = Panel.new()
	hotbar_panel.size = Vector2(HOTBAR_SIZE * 52 + 8, 60)
	hotbar_panel.position = Vector2(640 - (HOTBAR_SIZE * 52 + 8) * 0.5, 660)
	hotbar_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(hotbar_panel)

	for i in HOTBAR_SIZE:
		var slot := Panel.new()
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

		var num_label := Label.new()
		num_label.text = str(i + 1)
		num_label.position = Vector2(2, 0)
		num_label.add_theme_font_size_override("font_size", 9)
		num_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		slot.add_child(num_label)

	# ── Notification (center) ──────────────────────────────────
	notification_label = Label.new()
	notification_label.position = Vector2(440, 580)
	notification_label.size = Vector2(400, 30)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	notification_label.modulate.a = 0.0
	add_child(notification_label)

	# ── Insanity Overlay ──────────────────────────────────────
	insanity_overlay = ColorRect.new()
	insanity_overlay.size = Vector2(1280, 720)
	insanity_overlay.color = Color(0.15, 0.0, 0.2, 0.0)
	insanity_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(insanity_overlay)

	# Controls hint (bottom-left)
	var hint_label := Label.new()
	hint_label.position = Vector2(10, 600)
	hint_label.text = "WASD: Move  |  LClick: Attack  |  E: Interact  |  T: Craft  |  Space: Dodge  |  F: Cycle item"
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.8))
	add_child(hint_label)

func _make_bar(parent: Control, label_text: String, fill_color: Color, bg_color: Color, x: int, y: int) -> ProgressBar:
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
		player.inventory.inventory_changed.connect(_update_hotbar)

	if day_night:
		day_night.time_updated.connect(_on_time_updated)
		day_night.phase_changed.connect(_on_phase_changed)

func _process(delta: float) -> void:
	# Notification fade
	if notification_timer > 0.0:
		notification_timer -= delta
		if notification_timer <= 0.5:
			notification_label.modulate.a = notification_timer * 2.0
	else:
		notification_label.modulate.a = 0.0

	# Insanity effect
	if player and player.stats.is_low_sanity():
		insanity_phase += delta * 2.0
		var intensity := 1.0 - player.stats.get_sanity_pct() / 0.3
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

func _on_time_updated(t: float) -> void:
	if day_label and day_night:
		day_label.text = "Day %d  %s" % [day_night.day_number, day_night.get_time_string()]

func _on_phase_changed(phase_name: String, day_num: int) -> void:
	if phase_label:
		phase_label.text = phase_name
	show_notification(phase_name)

func _update_hotbar() -> void:
	if not player:
		return
	for i in HOTBAR_SIZE:
		_update_slot(i)

func _update_slot(i: int) -> void:
	var slot: Panel = hotbar_slots[i]
	# Remove old item visuals (keep the number label)
	for child in slot.get_children():
		if child is Label and child.text.length() <= 1:
			continue  # keep number label
		if child is ColorRect or (child is Label and child.text.length() > 1):
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

	# Color swatch
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

func show_notification(text: String, duration: float = 2.5) -> void:
	notification_label.text = text
	notification_label.modulate.a = 1.0
	notification_timer = duration

func show_game_over() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.size = Vector2(1280, 720)
	add_child(overlay)

	var go_label := Label.new()
	go_label.text = "YOU DIED"
	go_label.position = Vector2(540, 280)
	go_label.add_theme_font_size_override("font_size", 48)
	go_label.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	add_child(go_label)

	var sub_label := Label.new()
	sub_label.text = "Press R to restart"
	sub_label.position = Vector2(560, 360)
	sub_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.7))
	add_child(sub_label)

	var tween := create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.7), 1.5)
