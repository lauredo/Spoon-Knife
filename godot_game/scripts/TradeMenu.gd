class_name TradeMenu
extends CanvasLayer

## Barter panel for the colony's crow trader (toggled by CrowTrader.interact). Fixed offers, click-to-trade,
## no dialogue: hand over the glade's surplus for goods from far biomes or rarities. Auto-closes
## when the player walks away from the stall (same rule as the chest UI).

const PANEL_W := 400
const PANEL_H := 430

## Each offer: cost -> reward (item_id -> amount). "monster_meat" finally has a sink — the crow
## eats anything. "rep" (optional) gates the offer behind a reputation tier (S6): 1 = Conhecido,
## 2 = Amigo da Colônia — trust unlocks the good stock.
const OFFERS := [
	{"cost": {"carrot": 3}, "reward": {"silk": 2}},
	{"cost": {"meat": 2}, "reward": {"salve": 1}},
	{"cost": {"berries": 4}, "reward": {"stone": 2}},
	{"cost": {"monster_meat": 2}, "reward": {"meat": 1}},
	{"cost": {"shiny_thing": 1}, "reward": {"salve": 1}},  # the trader can't resist shiny things
	{"cost": {"scrap": 4}, "reward": {"bandage": 2}, "rep": 1},
	{"cost": {"wood": 8}, "reward": {"cloth": 2}, "rep": 1},   # forest surplus -> city cloth
	{"cost": {"shiny_thing": 2}, "reward": {"silk": 3}, "rep": 2},
	{"cost": {"monster_meat": 4}, "reward": {"canned_food": 1}, "rep": 2},
]

var player: Player
var trader: Node2D
var is_open: bool = false

var panel: Panel
var rows_box: VBoxContainer
var rep_label: Label

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

	var title := Label.new()
	title.text = "Trocas do Corvo"
	title.position = Vector2(12, 10)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	panel.add_child(title)

	rep_label = Label.new()
	rep_label.position = Vector2(190, 16)
	rep_label.add_theme_font_size_override("font_size", 11)
	rep_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.6))
	panel.add_child(rep_label)

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

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 50)
	scroll.size = Vector2(PANEL_W - 20, PANEL_H - 60)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)
	rows_box = VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 8)
	scroll.add_child(rows_box)

func open(p: Player, t: Node2D) -> void:
	player = p
	trader = t
	is_open = true
	panel.visible = true
	_refresh()

func close() -> void:
	is_open = false
	panel.visible = false

func _process(_delta: float) -> void:
	if is_open and player and is_instance_valid(trader):
		if player.global_position.distance_to(trader.global_position) > 140.0:
			close()

func _refresh() -> void:
	for c in rows_box.get_children():
		c.queue_free()
	if not player:
		return
	rep_label.text = "Reputação: %s (%d)" % [GameManager.rep_tier_name(), int(GameManager.reputation)]
	var tier := GameManager.rep_tier()
	for offer in OFFERS:
		if int(offer.get("rep", 0)) <= tier:
			_add_offer_row(offer)
		else:
			_add_locked_row(offer)

## A gated offer shows as a locked teaser — the player SEES what trust would buy.
func _add_locked_row(offer: Dictionary) -> void:
	var lbl := Label.new()
	var tier_name := "Conhecido" if int(offer.get("rep", 0)) == 1 else "Amigo da Colônia"
	lbl.text = "🔒 %s   — requer %s" % [_amounts_text(offer["reward"]), tier_name]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.48, 0.42))
	rows_box.add_child(lbl)

func _add_offer_row(offer: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(PANEL_W - 24, 46)
	rows_box.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var reward_label := Label.new()
	reward_label.text = _amounts_text(offer["reward"])
	reward_label.add_theme_font_size_override("font_size", 13)
	reward_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	info.add_child(reward_label)

	var cost_text := "Paga: "
	for id in offer["cost"]:
		var need: int = offer["cost"][id]
		var have: int = player.inventory.get_count(str(id))
		cost_text += "%s %d/%d  " % [_item_name(str(id)), have, need]
	var cost_label := Label.new()
	cost_label.text = cost_text
	cost_label.add_theme_font_size_override("font_size", 10)
	cost_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	info.add_child(cost_label)

	var btn := Button.new()
	btn.text = "Trocar"
	btn.custom_minimum_size = Vector2(64, 36)
	btn.disabled = not _can_trade(offer)
	btn.pressed.connect(_do_trade.bind(offer))
	row.add_child(btn)

	var sep := ColorRect.new()
	sep.color = Color(0.2, 0.18, 0.15, 0.5)
	sep.custom_minimum_size = Vector2(0, 1)
	rows_box.add_child(sep)

func _item_name(id: String) -> String:
	var data = ItemDatabase.get_item(id)
	return data.display_name if data else id

func _amounts_text(d: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in d:
		parts.append("%d× %s" % [int(d[id]), _item_name(str(id))])
	return "Recebe: " + ", ".join(parts)

func _can_trade(offer: Dictionary) -> bool:
	for id in offer["cost"]:
		if player.inventory.get_count(str(id)) < int(offer["cost"][id]):
			return false
	# The reward must also fit its stack, or items would silently vanish on add.
	for id in offer["reward"]:
		var data = ItemDatabase.get_item(str(id))
		if data and player.inventory.get_count(str(id)) + int(offer["reward"][id]) > data.max_stack:
			return false
	return true

func _do_trade(offer: Dictionary) -> void:
	if not player or not _can_trade(offer):
		return
	for id in offer["cost"]:
		player.inventory.remove_item(str(id), int(offer["cost"][id]))
	for id in offer["reward"]:
		player.inventory.add_item(str(id), int(offer["reward"][id]))
	Audio.play_sfx("pickup")
	GameManager.add_reputation(GameManager.REP_TRADE)  # every barter builds a little trust (S6)
	_refresh()
