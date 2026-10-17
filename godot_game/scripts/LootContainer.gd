class_name LootContainer
extends StaticBody2D

## A scavengeable city container (GDD S2a): street trash bins, fridges, cabinets and store shelves.
## E searches it ONCE — loot goes straight to the inventory (overflow spills as drops) — and then
## it's empty FOREVER. That depletion is the engine of exploration pressure: eat through the near
## blocks and you're pushed deeper into the city (see GDD "progressão geográfica").

enum Kind { TRASH_BIN, FRIDGE, CABINET, SHELF }

var kind: int = Kind.TRASH_BIN
var district: int = 0  # WorldGenerator.District — industrial containers carry materials, not food
var searched: bool = false
var save_id: int = -1  # stable id (deterministic gen order) — SaveSystem persists `searched` by it

## Weighted loot tables: {item, w(eight), min, max}. Deeper districts get richer via kind mix
## (shelves only exist in commercial) and the industrial override below.
const TABLE_TRASH := [
	{"item": "old_pizza", "w": 35.0, "min": 1, "max": 2},
	{"item": "donut", "w": 15.0, "min": 1, "max": 1},
	{"item": "cloth", "w": 25.0, "min": 1, "max": 2},
	{"item": "scrap", "w": 20.0, "min": 1, "max": 2},
	{"item": "shiny_thing", "w": 5.0, "min": 1, "max": 1},
]
const TABLE_FRIDGE := [
	{"item": "canned_food", "w": 30.0, "min": 1, "max": 2},
	{"item": "old_pizza", "w": 35.0, "min": 1, "max": 2},
	{"item": "donut", "w": 25.0, "min": 1, "max": 2},
	{"item": "salve", "w": 5.0, "min": 1, "max": 1},
	{"item": "shiny_thing", "w": 5.0, "min": 1, "max": 1},
]
const TABLE_CABINET := [
	{"item": "cloth", "w": 35.0, "min": 1, "max": 2},
	{"item": "scrap", "w": 25.0, "min": 1, "max": 2},
	{"item": "bandage", "w": 15.0, "min": 1, "max": 1},
	{"item": "rope", "w": 15.0, "min": 1, "max": 1},
	{"item": "flint", "w": 10.0, "min": 1, "max": 2},
]
const TABLE_SHELF := [
	{"item": "canned_food", "w": 40.0, "min": 1, "max": 3},
	{"item": "donut", "w": 25.0, "min": 1, "max": 2},
	{"item": "salve", "w": 10.0, "min": 1, "max": 1},
	{"item": "cloth", "w": 10.0, "min": 1, "max": 2},
	{"item": "shiny_thing", "w": 15.0, "min": 1, "max": 1},
]
const TABLE_INDUSTRIAL := [
	{"item": "scrap", "w": 45.0, "min": 2, "max": 3},
	{"item": "flint", "w": 20.0, "min": 1, "max": 2},
	{"item": "cloth", "w": 15.0, "min": 1, "max": 2},
	{"item": "charcoal", "w": 10.0, "min": 1, "max": 2},
	{"item": "shiny_thing", "w": 10.0, "min": 1, "max": 1},
]
# The drowned waterfront: the city's best haul — you paid in tide risk to be here.
const TABLE_WATERFRONT := [
	{"item": "shiny_thing", "w": 30.0, "min": 1, "max": 2},
	{"item": "canned_food", "w": 25.0, "min": 2, "max": 3},
	{"item": "salve", "w": 20.0, "min": 1, "max": 2},
	{"item": "silk", "w": 15.0, "min": 2, "max": 3},
	{"item": "flint", "w": 10.0, "min": 2, "max": 3},
]

func _ready() -> void:
	collision_layer = 32  # structures: player InteractArea detects, body blocks like furniture
	collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 13.0
	col.shape = shape
	add_child(col)

func get_structure_type() -> String:
	return "loot_container"

func interact(player: Player) -> void:
	if searched:
		_notify("Vazio...")
		return
	searched = true
	var loot := _roll_loot()
	var summary := PackedStringArray()
	for id in loot:
		var amount: int = loot[id]
		var added: int = player.inventory.add_item(str(id), amount)
		if added < amount:
			GameManager.spawn_drop(global_position, str(id), amount - added)  # full stack -> spills
		var data = ItemDatabase.get_item(str(id))
		summary.append("%d× %s" % [amount, data.display_name if data else str(id)])
	Audio.play_sfx("dig", 0.15)  # rummage
	_notify("Achou: " + ", ".join(summary))
	_alert_humans()  # rummaging is LOUD — the owners come to look (stealth v0)
	_night_fear(player)
	GameManager.on_container_looted()  # perk milestone (S6)
	queue_redraw()

## The price of the burglary window: rummaging in the dark is TERRIFYING. Each container
## searched at night bleeds sanity (halved near light), so a long looting spree walks you into
## the shadow threshold — the horror system itself is the cost, no new mechanic needed.
const NIGHT_FEAR := 8.0
const NIGHT_FEAR_LIT := 4.0

func _night_fear(player: Player) -> void:
	if player.stats == null or player.stats.is_day:
		return
	player.stats.drain_sanity(NIGHT_FEAR_LIT if player.stats.in_light else NIGHT_FEAR)
	if not GameManager.night_loot_warned:
		GameManager.night_loot_warned = true
		if GameManager.hud and GameManager.hud.has_method("show_notification"):
			GameManager.hud.show_notification("😨 Vasculhar no escuro arrepia a espinha — sua sanidade paga o preço", 4.5)

## Searching a container carries: nearby humans walk over to investigate the spot.
func _alert_humans() -> void:
	if GameManager.world == null:
		return
	var mobs = GameManager.world.get_node_or_null("Mobs")
	if mobs == null:
		return
	for m in mobs.get_children():
		if m is HumanNPC and m.global_position.distance_to(global_position) < HumanNPC.NOISE_RANGE:
			m.hear_noise(global_position)

func _roll_loot() -> Dictionary:
	var table := _table_for()
	var rolls: int = 2
	if kind == Kind.TRASH_BIN:
		rolls = randi_range(1, 2)
	elif kind == Kind.SHELF:
		rolls = randi_range(2, 3)
	if GameManager.has_perk("farejador") and randf() < 0.25:
		rolls += 1  # a trained nose finds the extra stash
	var result: Dictionary = {}
	for i in rolls:
		var total := 0.0
		for e in table:
			total += float(e["w"])
		var pick := randf() * total
		for e in table:
			pick -= float(e["w"])
			if pick <= 0.0:
				var id: String = str(e["item"])
				result[id] = int(result.get(id, 0)) + randi_range(int(e["min"]), int(e["max"]))
				break
	return result

func _table_for() -> Array:
	# The islands pay best (you crossed the sea to get here), whatever the furniture.
	if district == WorldGenerator.District.ISLAND:
		return TABLE_WATERFRONT
	match kind:
		Kind.FRIDGE: return TABLE_FRIDGE
		Kind.CABINET: return TABLE_CABINET
		Kind.SHELF: return TABLE_SHELF
	return TABLE_TRASH

func _notify(msg: String) -> void:
	if GameManager.hud and GameManager.hud.has_method("show_notification"):
		GameManager.hud.show_notification(msg)

# ── Looks (procedural placeholders; searched = darker + opened) ─────────────

func _draw() -> void:
	var dim := 0.55 if searched else 1.0
	match kind:
		Kind.TRASH_BIN: _draw_bin(dim)
		Kind.FRIDGE: _draw_fridge(dim)
		Kind.CABINET: _draw_cabinet(dim)
		Kind.SHELF: _draw_shelf(dim)

func _draw_bin(dim: float) -> void:
	var body := Color(0.25, 0.42, 0.28) * dim
	draw_rect(Rect2(-11, -20, 22, 26), body)
	draw_rect(Rect2(-11, -20, 22, 26), body.darkened(0.35), false, 1.5)
	if searched:
		draw_rect(Rect2(-6, -30, 24, 4), Color(0.2, 0.33, 0.22) * dim)  # lid tipped aside
	else:
		draw_rect(Rect2(-13, -24, 26, 5), Color(0.3, 0.5, 0.33))
	draw_line(Vector2(-5, -14), Vector2(-5, 0), body.darkened(0.25), 2.0)
	draw_line(Vector2(2, -14), Vector2(2, 0), body.darkened(0.25), 2.0)

func _draw_fridge(dim: float) -> void:
	var body := Color(0.88, 0.9, 0.92) * dim
	draw_rect(Rect2(-12, -30, 24, 40), body)
	draw_rect(Rect2(-12, -30, 24, 40), Color(0.55, 0.58, 0.62) * dim, false, 1.5)
	draw_line(Vector2(-12, -12), Vector2(12, -12), Color(0.55, 0.58, 0.62) * dim, 1.5)
	if searched:
		draw_rect(Rect2(10, -28, 8, 16), body.darkened(0.15))  # door ajar
	else:
		draw_rect(Rect2(8, -26, 2, 10), Color(0.4, 0.42, 0.45))  # handle

func _draw_cabinet(dim: float) -> void:
	var body := Color(0.52, 0.36, 0.2) * dim
	draw_rect(Rect2(-16, -22, 32, 30), body)
	draw_rect(Rect2(-16, -22, 32, 30), body.darkened(0.4), false, 1.5)
	draw_line(Vector2(0, -22), Vector2(0, 8), body.darkened(0.4), 1.5)
	if searched:
		draw_rect(Rect2(2, -20, 14, 26), Color(0.15, 0.1, 0.06) * dim)  # one door hangs open
	else:
		draw_circle(Vector2(-3, -7), 1.6, Color(0.85, 0.75, 0.5))
		draw_circle(Vector2(3, -7), 1.6, Color(0.85, 0.75, 0.5))

func _draw_shelf(dim: float) -> void:
	var frame := Color(0.45, 0.42, 0.4) * dim
	draw_rect(Rect2(-16, -30, 32, 38), Color(0.3, 0.29, 0.28) * dim)
	draw_rect(Rect2(-16, -30, 32, 38), frame, false, 1.5)
	for i in 3:
		var y := -22.0 + i * 12.0
		draw_line(Vector2(-16, y + 8.0), Vector2(16, y + 8.0), frame, 2.0)
		if not searched:  # goods on the shelves
			for g in 3:
				draw_circle(Vector2(-10.0 + g * 10.0, y + 4.0), 2.6,
					[Color(0.85, 0.4, 0.3), Color(0.4, 0.6, 0.85), Color(0.9, 0.8, 0.4)][(i + g) % 3])
