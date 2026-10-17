class_name SettingsMenu
extends Control

## Reusable settings panel. Instantiated by BOTH the main menu and the in-game pause menu.
## It's a dumb panel: it shows the current Settings values, writes changes straight back to
## the Settings autoload (which persists), and emits `closed` when the player hits "Voltar".
## The parent decides what "closed" means (reshow its own buttons) and owns Esc handling.

signal closed

const PANEL_W := 440.0
const PANEL_H := 400.0

var panel: Panel
var fullscreen_check: CheckButton
var volume_slider: HSlider
var volume_value: Label
var brightness_slider: HSlider
var brightness_value: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow clicks so nothing behind reacts
	add_child(dim)

	panel = Panel.new()
	panel.add_theme_stylebox_override("panel", MenuUI.panel_style())
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.position = Vector2(640 - PANEL_W * 0.5, 360 - PANEL_H * 0.5)
	add_child(panel)

	var col := VBoxContainer.new()
	col.position = Vector2(24, 20)
	col.size = Vector2(PANEL_W - 48, PANEL_H - 40)
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)

	col.add_child(MenuUI.make_title("Configurações", 28))

	var sep := ColorRect.new()
	sep.color = Color(0.35, 0.28, 0.18)
	sep.custom_minimum_size = Vector2(0, 2)
	col.add_child(sep)

	# ── Tela cheia ──────────────────────────────────────────────
	var fs_row := HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 12)
	col.add_child(fs_row)
	var fs_label := Label.new()
	fs_label.text = "Tela cheia"
	fs_label.add_theme_font_size_override("font_size", 16)
	fs_label.add_theme_color_override("font_color", MenuUI.TEXT_COLOR)
	fs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_row.add_child(fs_label)
	fullscreen_check = CheckButton.new()
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	fs_row.add_child(fullscreen_check)

	# ── Volume geral ────────────────────────────────────────────
	var vol_label := Label.new()
	vol_label.text = "Volume geral"
	vol_label.add_theme_font_size_override("font_size", 16)
	vol_label.add_theme_color_override("font_color", MenuUI.TEXT_COLOR)
	col.add_child(vol_label)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 10)
	col.add_child(vol_row)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.custom_minimum_size = Vector2(300, 0)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_slider.value_changed.connect(_on_volume_changed)
	vol_row.add_child(volume_slider)
	volume_value = Label.new()
	volume_value.custom_minimum_size = Vector2(48, 0)
	volume_value.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	vol_row.add_child(volume_value)

	# ── Brilho noturno (acessibilidade — 0% mantém o visual desenhado) ──
	var br_label := Label.new()
	br_label.text = "Brilho noturno extra"
	br_label.add_theme_font_size_override("font_size", 16)
	br_label.add_theme_color_override("font_color", MenuUI.TEXT_COLOR)
	col.add_child(br_label)

	var br_row := HBoxContainer.new()
	br_row.add_theme_constant_override("separation", 10)
	col.add_child(br_row)
	brightness_slider = HSlider.new()
	brightness_slider.min_value = 0.0
	brightness_slider.max_value = 1.0
	brightness_slider.step = 0.01
	brightness_slider.custom_minimum_size = Vector2(300, 0)
	brightness_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brightness_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brightness_slider.value_changed.connect(_on_brightness_changed)
	br_row.add_child(brightness_slider)
	brightness_value = Label.new()
	brightness_value.custom_minimum_size = Vector2(48, 0)
	brightness_value.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	br_row.add_child(brightness_value)

	# Push the back button to the bottom.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var back_btn := MenuUI.make_button("Voltar", 160.0)
	back_btn.pressed.connect(close)
	col.add_child(back_btn)

func open() -> void:
	visible = true
	_refresh_from_settings()

func close() -> void:
	visible = false
	closed.emit()

## Mirror the persisted settings into the controls. Block signals so assigning the values
## doesn't fire toggled/value_changed (which would re-apply and re-save needlessly).
func _refresh_from_settings() -> void:
	fullscreen_check.set_block_signals(true)
	volume_slider.set_block_signals(true)
	brightness_slider.set_block_signals(true)
	fullscreen_check.button_pressed = Settings.fullscreen
	volume_slider.value = Settings.master_volume
	brightness_slider.value = Settings.night_brightness
	fullscreen_check.set_block_signals(false)
	volume_slider.set_block_signals(false)
	brightness_slider.set_block_signals(false)
	_update_volume_label(Settings.master_volume)
	_update_brightness_label(Settings.night_brightness)

func _on_fullscreen_toggled(v: bool) -> void:
	Settings.set_fullscreen(v)

func _on_volume_changed(v: float) -> void:
	Settings.set_master_volume(v)
	_update_volume_label(v)

func _update_volume_label(v: float) -> void:
	volume_value.text = "%d%%" % roundi(v * 100.0)

func _on_brightness_changed(v: float) -> void:
	Settings.set_night_brightness(v)
	_update_brightness_label(v)

func _update_brightness_label(v: float) -> void:
	brightness_value.text = "%d%%" % roundi(v * 100.0)
