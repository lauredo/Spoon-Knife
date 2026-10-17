class_name QuestMenu
extends CanvasLayer

## The mission board's panel (toggled by QuestBoard.interact). Shows the CURRENT quest of the
## authored chain: accept it, deliver fetch goods, or watch boss progress (those complete on the
## kill, wherever you are). Auto-closes when you walk away — same rule as the chest/trade UIs.

const PANEL_W := 430
const PANEL_H := 260

var is_open: bool = false
var board: Node2D = null

var panel: Panel
var title_l: Label
var desc_l: Label
var action_btn: Button
var _refresh_t: float = 0.0

func _ready() -> void:
	_build_ui()
	panel.visible = false

func _build_ui() -> void:
	panel = Panel.new()
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.position = Vector2(640 - PANEL_W * 0.5, 360 - PANEL_H * 0.5)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.95)
	style.border_color = Color(0.45, 0.35, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var header := Label.new()
	header.text = "Missões da Colônia"
	header.position = Vector2(12, 10)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	panel.add_child(header)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.size = Vector2(28, 28)
	close_btn.position = Vector2(PANEL_W - 36, 8)
	close_btn.pressed.connect(close)
	panel.add_child(close_btn)

	var sep := ColorRect.new()
	sep.color = Color(0.35, 0.28, 0.18)
	sep.size = Vector2(PANEL_W - 12, 2)
	sep.position = Vector2(6, 40)
	panel.add_child(sep)

	title_l = Label.new()
	title_l.position = Vector2(14, 52)
	title_l.size = Vector2(PANEL_W - 28, 24)
	title_l.add_theme_font_size_override("font_size", 15)
	title_l.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	panel.add_child(title_l)

	desc_l = Label.new()
	desc_l.position = Vector2(14, 80)
	desc_l.size = Vector2(PANEL_W - 28, 110)
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_l.add_theme_font_size_override("font_size", 12)
	desc_l.add_theme_color_override("font_color", Color(0.78, 0.78, 0.72))
	panel.add_child(desc_l)

	action_btn = Button.new()
	action_btn.custom_minimum_size = Vector2(180, 38)
	action_btn.position = Vector2(PANEL_W * 0.5 - 90, PANEL_H - 52)
	action_btn.pressed.connect(_on_action)
	panel.add_child(action_btn)

func open(b: Node2D) -> void:
	board = b
	is_open = true
	panel.visible = true
	_refresh()

func close() -> void:
	is_open = false
	panel.visible = false

func _process(delta: float) -> void:
	if not is_open:
		return
	var p = GameManager.player
	if p and is_instance_valid(board) and p.global_position.distance_to(board.global_position) > 140.0:
		close()
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.4
		_refresh()

func _refresh() -> void:
	var qs = GameManager.quest_system
	if qs == null:
		return
	if qs.is_all_done():
		title_l.text = "Todas as missões concluídas!"
		desc_l.text = "A colônia agradece, pequeno herói. (Novas missões chegarão com o tempo.)"
		action_btn.visible = false
		return
	var q: Dictionary = qs.current_quest()
	title_l.text = str(q["title"])
	desc_l.text = str(q["desc"])
	action_btn.visible = true
	if qs.stage == QuestSystem.Stage.AVAILABLE:
		action_btn.text = "Aceitar"
		action_btn.disabled = false
	elif str(q.get("type", "")) == "fetch":
		var have := 0
		var p = GameManager.player
		if p:
			have = p.inventory.get_count(str(q["item"]))
		var need: int = int(q["amount"])
		action_btn.text = "Entregar (%d/%d)" % [mini(have, need), need]
		action_btn.disabled = have < need
	else:
		action_btn.text = "Em andamento..."
		action_btn.disabled = true

func _on_action() -> void:
	var qs = GameManager.quest_system
	if qs == null:
		return
	if qs.stage == QuestSystem.Stage.AVAILABLE:
		qs.accept()
	else:
		qs.try_deliver()
	Audio.play_sfx("click")
	_refresh()
