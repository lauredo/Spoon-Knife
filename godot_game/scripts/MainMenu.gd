extends Control

## Title screen — the game's front door (set as the project's main scene). "Iniciar" loads the
## gameplay scene, "Configurações" opens the shared settings panel, "Sair" quits to desktop.

var settings_menu: SettingsMenu
var button_box: VBoxContainer

func _ready() -> void:
	Engine.time_scale = 1.0  # it persists across scenes; the fast-forward test keys may have left it high
	Audio.stop_all()  # no gameplay ambience should bleed into the title screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	col.add_child(MenuUI.make_title("GUAXINIM", 64))
	col.add_child(MenuUI.make_title("Noites de Muriqui — sobreviva na vila abandonada", 20, Color(0.7, 0.72, 0.78)))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 36)
	col.add_child(gap)

	button_box = VBoxContainer.new()
	button_box.alignment = BoxContainer.ALIGNMENT_CENTER
	button_box.add_theme_constant_override("separation", 12)
	col.add_child(button_box)

	# A living run? "Continuar" leads the menu (endless survival must resume where it stopped).
	if SaveSystem.has_save():
		var cont_btn := MenuUI.make_button("Continuar")
		cont_btn.pressed.connect(_on_continue)
		button_box.add_child(cont_btn)

	var start_btn := MenuUI.make_button("Iniciar")
	start_btn.pressed.connect(_on_start)
	button_box.add_child(start_btn)

	var cfg_btn := MenuUI.make_button("Configurações")
	cfg_btn.pressed.connect(_on_settings)
	button_box.add_child(cfg_btn)

	var quit_btn := MenuUI.make_button("Sair")
	quit_btn.pressed.connect(_on_quit)
	button_box.add_child(quit_btn)

	settings_menu = SettingsMenu.new()
	add_child(settings_menu)
	settings_menu.closed.connect(_on_settings_closed)
	settings_menu.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and settings_menu.visible:
		settings_menu.close()
		get_viewport().set_input_as_handled()

func _on_continue() -> void:
	GameManager.pending_load = SaveSystem.load_data()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_start() -> void:
	# A fresh start abandons any existing run (its save is overwritten territory).
	SaveSystem.delete_save()
	GameManager.pending_load = null
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_settings() -> void:
	button_box.visible = false
	settings_menu.open()

func _on_settings_closed() -> void:
	button_box.visible = true

func _on_quit() -> void:
	get_tree().quit()
