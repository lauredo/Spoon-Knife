extends Node

signal game_over
signal game_won
signal new_day(day_number: int)

var current_day: int = 1
var is_game_over: bool = false
var is_won: bool = false

# Weather (set each dawn by WeatherSystem) + the day-2 Blood Moon flag (set by Main at nightfall).
const WEATHER_CLEAR := 0
const WEATHER_FOG := 1
const WEATHER_RAIN := 2
var weather: int = WEATHER_CLEAR
var blood_moon: bool = false
var debug_god: bool = false  # DebugMenu: invincible + no hunger/sanity/drown

# ── Vigilância (heat) ──────────────────────────────────────────────────────
# Being SPOTTED by humans builds a global wanted level that cools off over time. High heat makes
# humans faster and sharper-eyed (HumanNPC reads heat_factor), so chained daytime burglaries get
# progressively riskier — lay low (or loot at night) to cool down.
const HEAT_MAX := 100.0
const HEAT_PER_SPOT := 15.0
const HEAT_DECAY_PER_MIN := 12.0   # spotted 4x = tier 2; full cool-down in ~8 min (1.6 days)
var heat: float = 0.0
var _heat_tier: int = 0
var night_loot_warned: bool = false  # one-shot teach for the night-looting sanity price

# ── Progressão (S6): perks por marcos — NUNCA grind de skill (lock do GDD) ─────────────────
# Milestones are concrete and varied (survive, hunt, gather, loot, sleep, explore), so playing
# your own way still progresses. Perks are per-run (permadeath) and persist in the save.
signal perk_unlocked(id: String)

const PERKS := {
	"casca_grossa": {"nome": "Casca Grossa", "desc": "-10% de dano recebido", "marco": "Sobreviva 3 dias"},
	"veterano_da_noite": {"nome": "Veterano da Noite", "desc": "-25% de dreno de sanidade no escuro", "marco": "Sobreviva 7 dias"},
	"cacador": {"nome": "Caçador", "desc": "+10% de dano de ataque", "marco": "Derrote 10 criaturas"},
	"bracos_de_lenhador": {"nome": "Braços de Lenhador", "desc": "+20% de dano em árvores e rochas", "marco": "Colete 50 recursos"},
	"farejador": {"nome": "Farejador", "desc": "25% de chance de item extra ao saquear", "marco": "Saqueie 20 contêineres"},
	"sono_leve": {"nome": "Sono Leve", "desc": "-15% de dreno de energia", "marco": "Durma 3 vezes"},
	"lobo_do_mar": {"nome": "Lobo do Mar", "desc": "+15% de velocidade na balsa", "marco": "Chegue a uma ilha"},
}
var perks: Dictionary = {}   # id -> true
var kills: int = 0
var harvests: int = 0
var loots: int = 0
var sleeps: int = 0
var island_reached: bool = false

# ── Reputação com a colônia (S6): missões e trocas aproximam; machucar guaxinim afasta ─────
const REP_MAX := 100.0
const REP_QUEST := 15.0
const REP_TRADE := 2.0
const REP_HURT_RACCOON := -10.0
var reputation: float = 10.0
var _rep_tier: int = 0

# Set by MainMenu "Continuar" before the scene loads; Main consumes it (seed BEFORE generate,
# deltas after setup). Deliberately NOT touched by reset_game_state — it must survive scene entry.
var pending_load = null

func is_raining() -> bool:
	return weather == WEATHER_RAIN

func is_foggy() -> bool:
	return weather == WEATHER_FOG
var player: Node = null
var world: Node = null
var hud: Node = null
var crafting_menu: Node = null
var backpack_menu: Node = null
var chest_menu: Node = null
var trade_menu: Node = null
var map_menu: Node = null
var quest_menu: Node = null
var quest_system: Node = null

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if heat > 0.0 and not is_game_over:
		heat = maxf(0.0, heat - HEAT_DECAY_PER_MIN / 60.0 * delta)
		_check_heat_tier()

func add_heat(amount: float) -> void:
	heat = clampf(heat + amount, 0.0, HEAT_MAX)
	_check_heat_tier()

## 0 = calm, 1 = alert (≥30), 2 = manhunt (≥60). Drives human buffs + player feedback.
func heat_tier() -> int:
	if heat >= 60.0:
		return 2
	if heat >= 30.0:
		return 1
	return 0

func heat_factor() -> float:
	return clampf(heat / HEAT_MAX, 0.0, 1.0)

func _check_heat_tier() -> void:
	var t := heat_tier()
	if t == _heat_tier:
		return
	var rising := t > _heat_tier
	_heat_tier = t
	if hud == null or not hud.has_method("show_notification"):
		return
	if rising:
		if t == 1:
			hud.show_notification("👁 Os humanos estão alertas — você foi visto demais", 4.0)
		else:
			hud.show_notification("🚨 CAÇADA! Os humanos estão atrás de você", 4.5)
	elif t == 0:
		hud.show_notification("😮‍💨 Os humanos se acalmaram", 3.0)

# ── Perks ──────────────────────────────────────────────────────────────────

func has_perk(id: String) -> bool:
	return perks.has(id)

func _unlock_perk(id: String) -> void:
	if perks.has(id) or not PERKS.has(id):
		return
	perks[id] = true
	perk_unlocked.emit(id)
	var p: Dictionary = PERKS[id]
	if hud and hud.has_method("show_notification"):
		hud.show_notification("⭐ PERK: %s — %s" % [p["nome"], p["desc"]], 5.0)
	Audio.play_sfx("craft")

func on_mob_killed() -> void:
	kills += 1
	if kills >= 10:
		_unlock_perk("cacador")

func on_resource_harvested() -> void:
	harvests += 1
	if harvests >= 50:
		_unlock_perk("bracos_de_lenhador")

func on_container_looted() -> void:
	loots += 1
	if loots >= 20:
		_unlock_perk("farejador")

func on_slept() -> void:
	sleeps += 1
	if sleeps >= 3:
		_unlock_perk("sono_leve")

func on_island_reached() -> void:
	if island_reached:
		return
	island_reached = true
	_unlock_perk("lobo_do_mar")

# ── Reputação ──────────────────────────────────────────────────────────────

## 0 = Estranho, 1 = Conhecido (≥25), 2 = Amigo da Colônia (≥60). Higher tiers unlock extra
## crow offers (TradeMenu filters by this).
func rep_tier() -> int:
	if reputation >= 60.0:
		return 2
	if reputation >= 25.0:
		return 1
	return 0

func rep_tier_name() -> String:
	match rep_tier():
		2: return "Amigo da Colônia"
		1: return "Conhecido"
	return "Estranho"

func add_reputation(amount: float) -> void:
	reputation = clampf(reputation + amount, 0.0, REP_MAX)
	var t := rep_tier()
	if t == _rep_tier:
		return
	var rising := t > _rep_tier
	_rep_tier = t
	if hud == null or not hud.has_method("show_notification"):
		return
	if rising:
		hud.show_notification("🐦 A colônia confia mais em você: %s" % rep_tier_name(), 4.0)
	else:
		hud.show_notification("🐦 A colônia esfriou com você: %s" % rep_tier_name(), 4.0)

## Reset run state. This autoload outlives the gameplay scene, so a fresh run (starting from
## the title screen, restarting with R, or reloading) must clear these or stale flags/day count
## leak into the next game. Node references are cleared too — they re-register in Main._ready.
func reset_game_state() -> void:
	current_day = 1
	is_game_over = false
	is_won = false
	weather = WEATHER_CLEAR
	blood_moon = false
	debug_god = false
	heat = 0.0
	_heat_tier = 0
	night_loot_warned = false
	perks = {}
	kills = 0
	harvests = 0
	loots = 0
	sleeps = 0
	island_reached = false
	reputation = 10.0
	_rep_tier = 0
	player = null
	world = null
	hud = null
	crafting_menu = null
	backpack_menu = null
	chest_menu = null
	trade_menu = null
	map_menu = null
	quest_menu = null
	quest_system = null

func register_player(p: Node) -> void:
	player = p

func register_world(w: Node) -> void:
	world = w

func register_hud(h: Node) -> void:
	hud = h

func register_menus(crafting: Node, backpack: Node, chest: Node, trade: Node = null, map: Node = null, quest: Node = null) -> void:
	crafting_menu = crafting
	backpack_menu = backpack
	chest_menu = chest
	trade_menu = trade
	map_menu = map
	quest_menu = quest

## True while any inventory-style menu is open — gameplay clicks (attack) are suppressed so
## clicking UI slots doesn't also swing the tool.
func is_menu_open() -> bool:
	for m in [crafting_menu, backpack_menu, chest_menu, trade_menu, map_menu, quest_menu]:
		if m != null and m.is_open:
			return true
	return false

func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	game_over.emit()

func advance_day() -> void:
	current_day += 1
	new_day.emit(current_day)
	if current_day >= 3:
		_unlock_perk("casca_grossa")
	if current_day >= 7:
		_unlock_perk("veterano_da_noite")

func trigger_victory() -> void:
	if is_won or is_game_over:
		return
	is_won = true
	game_won.emit()

func get_nearby_structures(position: Vector2, radius: float) -> Array:
	var found: Array = []
	if not world:
		return found
	var structures_node = world.get_node_or_null("Structures")
	if not structures_node:
		return found
	for child in structures_node.get_children():
		if child.has_method("get_structure_type"):
			if child.global_position.distance_to(position) <= radius:
				found.append(child.get_structure_type())
	return found

func spawn_drop(position: Vector2, item_id: String, amount: int = 1) -> void:
	if not world:
		return
	var drop_scene = load("res://scenes/items/DropItem.tscn")
	if not drop_scene:
		return
	var drop = drop_scene.instantiate()
	drop.global_position = position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	drop.setup(item_id, amount)
	var items_node = world.get_node_or_null("DroppedItems")
	if items_node:
		items_node.add_child(drop)
	else:
		world.add_child(drop)
