class_name MenuUI
extends RefCounted

## Shared look-and-feel for the menu screens (main menu, pause, settings) so the three
## don't each reinvent button/panel styling. Pure static helpers — never instantiated.

const TITLE_COLOR := Color(0.92, 0.82, 0.5)
const TEXT_COLOR := Color(0.9, 0.9, 0.85)

static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.07, 0.06, 0.97)
	s.border_color = Color(0.45, 0.35, 0.2)
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	return s

static func _btn_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

## A themed menu button. min_w sets a uniform minimum width so a column of buttons lines up
## even when their labels differ in length.
static func make_button(text: String, min_w: float = 240.0) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_w, 48)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.85))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.7, 0.5))
	var hover := _btn_box(Color(0.22, 0.18, 0.12, 0.98), Color(0.7, 0.55, 0.3))
	btn.add_theme_stylebox_override("normal", _btn_box(Color(0.14, 0.12, 0.10, 0.95), Color(0.45, 0.35, 0.2)))
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", _btn_box(Color(0.10, 0.08, 0.06, 1.0), Color(0.5, 0.4, 0.22)))
	btn.add_theme_stylebox_override("focus", hover)
	btn.pressed.connect(func() -> void: Audio.play_sfx("click"))
	return btn

static func make_title(text: String, size: int, color: Color = TITLE_COLOR) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
