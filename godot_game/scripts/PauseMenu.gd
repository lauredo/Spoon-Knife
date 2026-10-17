extends CanvasLayer

## In-game pause overlay, toggled with Esc. Pauses the whole scene tree (mobs, day/night,
## survival ticks all freeze) and offers: continue, settings, back to the title screen, quit.
## Runs with PROCESS_MODE_ALWAYS so its buttons and Esc still work while the tree is paused.

const BTN_W := 300.0

var is_open: bool = false
var content: Control   # dim + panel; toggled as a unit to show/hide the overlay
var panel: Panel
var settings_menu: SettingsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20  # above HUD (10) and the inventory/chest menus (11/12)
	_build_ui()
	content.visible = false

func _build_ui() -> void:
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(dim)

	var pw := 380.0
	var ph := 360.0
	panel = Panel.new()
	panel.add_theme_stylebox_override("panel", MenuUI.panel_style())
	panel.size = Vector2(pw, ph)
	panel.position = Vector2(640 - pw * 0.5, 360 - ph * 0.5)
	content.add_child(panel)

	var col := VBoxContainer.new()
	col.position = Vector2(20, 24)
	col.size = Vector2(pw - 40, ph - 48)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	col.add_child(MenuUI.make_title("Pausado", 32))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	col.add_child(gap)

	var resume_btn := MenuUI.make_button("Continuar", BTN_W)
	resume_btn.pressed.connect(resume)
	col.add_child(resume_btn)

	var cfg_btn := MenuUI.make_button("Configurações", BTN_W)
	cfg_btn.pressed.connect(_on_settings)
	col.add_child(cfg_btn)

	var menu_btn := MenuUI.make_button("Voltar para a tela inicial", BTN_W)
	menu_btn.pressed.connect(_on_main_menu)
	col.add_child(menu_btn)

	var quit_btn := MenuUI.make_button("Fechar o jogo", BTN_W)
	quit_btn.pressed.connect(_on_quit)
	col.add_child(quit_btn)

	settings_menu = SettingsMenu.new()
	content.add_child(settings_menu)
	settings_menu.closed.connect(_on_settings_closed)
	settings_menu.visible = false

## Esc: if the settings sub-panel is open, back out of it first; otherwise toggle the pause menu.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_open and settings_menu.visible:
		settings_menu.close()
		get_viewport().set_input_as_handled()
		return
	toggle()
	get_viewport().set_input_as_handled()

func toggle() -> void:
	if is_open:
		resume()
	else:
		pause()

func pause() -> void:
	if is_open:
		return
	is_open = true
	settings_menu.visible = false
	panel.visible = true
	content.visible = true
	get_tree().paused = true

func resume() -> void:
	if not is_open:
		return
	is_open = false
	content.visible = false
	get_tree().paused = false

func _on_settings() -> void:
	panel.visible = false
	settings_menu.open()

func _on_settings_closed() -> void:
	panel.visible = true

func _on_main_menu() -> void:
	SaveSystem.save_game(get_tree().current_scene)  # leaving keeps the run alive
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_quit() -> void:
	SaveSystem.save_game(get_tree().current_scene)
	get_tree().quit()
