extends CanvasLayer

## Developer overlay (F1). Inspect the whole world: free zoom, reveal the fog map, show ALL entities
## (bypass streaming), God mode (invincible + no hunger/sanity/drown → walk anywhere, even the
## islands), and quick teleports. Pure tooling — never gates real gameplay.

var is_open: bool = false
var _panel: Panel
var _zoom_label: Label
var _show_all: bool = false

func _ready() -> void:
	layer = 21  # above the pause menu
	_build_ui()
	_panel.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_menu"):
		is_open = not is_open
		_panel.visible = is_open
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.size = Vector2(240, 372)
	_panel.position = Vector2(1280 - 252, 12)
	_panel.add_theme_stylebox_override("panel", MenuUI.panel_style())
	add_child(_panel)

	var col := VBoxContainer.new()
	col.position = Vector2(12, 10)
	col.size = Vector2(216, 352)
	col.add_theme_constant_override("separation", 7)
	_panel.add_child(col)

	col.add_child(MenuUI.make_title("DEBUG  (F1)", 18))

	_zoom_label = Label.new()
	_zoom_label.add_theme_color_override("font_color", MenuUI.TEXT_COLOR)
	_zoom_label.add_theme_font_size_override("font_size", 12)
	col.add_child(_zoom_label)
	var zoom := HSlider.new()
	zoom.min_value = 0.03
	zoom.max_value = 2.0
	zoom.step = 0.01
	zoom.value = 1.2
	zoom.custom_minimum_size = Vector2(0, 18)
	zoom.value_changed.connect(_on_zoom)
	col.add_child(zoom)
	_on_zoom(1.2)

	_btn(col, "Revelar mapa (névoa)", _reveal_map)
	_toggle(col, "Mostrar tudo (sem streaming)", _on_show_all)
	_toggle(col, "Modo Deus (invencível)", _on_god)

	var sep := ColorRect.new()
	sep.color = Color(0.35, 0.28, 0.18)
	sep.custom_minimum_size = Vector2(0, 2)
	col.add_child(sep)
	var tp := Label.new()
	tp.text = "Teleporte:"
	tp.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	tp.add_theme_font_size_override("font_size", 11)
	col.add_child(tp)
	_btn(col, "→ Toca (mata)", func(): _teleport(WorldGenerator.SPAWN_POS))
	_btn(col, "→ Marina", func(): _teleport(_wg_spot(WorldGenerator.District.MARINA)))
	_btn(col, "→ Ilha de Itacuruçá", func(): _teleport(WorldGenerator.ISLANDS[0]["c"]))

	_btn(col, "Voltar ao normal", _restore)

func _btn(col: VBoxContainer, text: String, cb: Callable) -> void:
	var b := MenuUI.make_button(text, 210.0)
	b.custom_minimum_size = Vector2(210, 30)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(cb)
	col.add_child(b)

func _toggle(col: VBoxContainer, text: String, cb: Callable) -> void:
	var row := HBoxContainer.new()
	col.add_child(row)
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", MenuUI.TEXT_COLOR)
	row.add_child(l)
	var c := CheckButton.new()
	c.toggled.connect(cb)
	row.add_child(c)

# ── Actions ─────────────────────────────────────────────────────────────────

func _on_zoom(v: float) -> void:
	_zoom_label.text = "Zoom: %.2fx" % v
	var cam := _camera()
	if cam:
		cam.zoom = Vector2(v, v)

func _reveal_map() -> void:
	if GameManager.map_menu and GameManager.map_menu.has_method("reveal_all"):
		GameManager.map_menu.reveal_all()
		_notify("Mapa revelado")

func _on_show_all(on: bool) -> void:
	_show_all = on
	var s = get_tree().current_scene.get_node_or_null("StreamingSystem")
	if s and s.has_method("set_enabled"):
		s.set_enabled(not on)  # off = show everything
	_notify("Streaming " + ("desligado" if on else "ligado"))

func _on_god(on: bool) -> void:
	GameManager.debug_god = on
	if GameManager.player and GameManager.player.stats:
		GameManager.player.stats.invincible = on
	_notify("Modo Deus " + ("ligado" if on else "desligado"))

func _teleport(pos: Vector2) -> void:
	if GameManager.player:
		GameManager.player.global_position = pos

func _restore() -> void:
	var cam := _camera()
	if cam:
		cam.zoom = Vector2(1.2, 1.2)
	var s = get_tree().current_scene.get_node_or_null("StreamingSystem")
	if s and s.has_method("set_enabled"):
		s.set_enabled(true)
	_notify("Restaurado")

func _camera() -> Camera2D:
	if GameManager.player == null:
		return null
	return GameManager.player.get_node_or_null("Camera2D")

func _wg_spot(_zone: int) -> Vector2:
	# On the road at the marina — that's the town strip, not the forest behind it.
	var wg = get_tree().current_scene.get_node_or_null("World/WorldGenerator")
	if wg and wg.has_method("road_y"):
		return Vector2(WorldGenerator.MARINA_X, wg.road_y(WorldGenerator.MARINA_X))
	return Vector2(WorldGenerator.MARINA_X, 2400.0)

func _notify(msg: String) -> void:
	if GameManager.hud and GameManager.hud.has_method("show_notification"):
		GameManager.hud.show_notification("[DEBUG] " + msg, 2.0)
