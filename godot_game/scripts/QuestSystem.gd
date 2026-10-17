class_name QuestSystem
extends Node

## The endless game's engine of purpose (GDD S4): an authored quest CHAIN at the colony board,
## each mission sending you FARTHER — teach looting (fetch) -> the Alfa's den at the road's end ->
## the Jacaré across the sea (needs the raft). Boss quests complete automatically on the kill; the
## real prize is the boss's unique VERB relic — quest rewards are just a thank-you.

signal quest_changed

const QUESTS := [
	{
		"id": "despensa", "type": "fetch", "item": "canned_food", "amount": 2,
		"title": "A Despensa da Colônia",
		"desc": "O inverno assusta a colônia. Traga 2 Enlatados da cidade — geladeiras e mercados costumam ter.",
		"reward": {"salve": 1, "shiny_thing": 1},
	},
	{
		"id": "alfa", "type": "boss", "boss": "alfa",
		"title": "A Matilha do Alfa",
		"desc": "O Cachorro Alfa comanda os vira-latas do extremo oeste da estrada. Enquanto ele viver, as ruas são dele. Derrote-o no covil.",
		"reward": {"canned_food": 3},
	},
	{
		"id": "jacare", "type": "boss", "boss": "jacare",
		"title": "O Senhor da Caverna",
		"desc": "Dizem que algo antigo mora na caverna da Ilha de Itacuruçá. Só se chega pelo mar — leve uma balsa. E volte inteiro.",
		"reward": {"shiny_thing": 3},
	},
]

enum Stage { AVAILABLE, ACTIVE }

var index: int = 0
var stage: int = Stage.AVAILABLE
var _killed: Dictionary = {}
var _poll: float = 0.0

func is_all_done() -> bool:
	return index >= QUESTS.size()

func current_quest() -> Dictionary:
	return {} if is_all_done() else QUESTS[index]

func accept() -> void:
	if stage == Stage.AVAILABLE and not is_all_done():
		stage = Stage.ACTIVE
		quest_changed.emit()
		_check_boss()  # boss already dead? instant credit

## Fetch quests: hand the goods over at the board.
func try_deliver() -> bool:
	var q := current_quest()
	if stage != Stage.ACTIVE or str(q.get("type", "")) != "fetch":
		return false
	var p = GameManager.player
	if p == null or not p.inventory.has_item(str(q["item"]), int(q["amount"])):
		return false
	p.inventory.remove_item(str(q["item"]), int(q["amount"]))
	_complete()
	return true

## Wired to each boss's died signal (Main). Kills count even before accepting — the deed is done.
func on_boss_killed(boss_id: String) -> void:
	_killed[boss_id] = true
	_check_boss()

func _check_boss() -> void:
	var q := current_quest()
	if not is_all_done() and str(q.get("type", "")) == "boss" and _killed.has(str(q.get("boss", ""))):
		_complete()

func _complete() -> void:
	var q := current_quest()
	var p = GameManager.player
	if p != null and is_instance_valid(p):
		for id in q.get("reward", {}):
			var amt: int = q["reward"][id]
			var added: int = p.inventory.add_item(str(id), amt)
			if added < amt:
				GameManager.spawn_drop(p.global_position, str(id), amt - added)
	if GameManager.hud and GameManager.hud.has_method("show_notification"):
		GameManager.hud.show_notification("✅ Missão concluída: %s" % str(q.get("title", "")), 4.0)
	Audio.play_sfx("craft")
	GameManager.add_reputation(GameManager.REP_QUEST)  # helping the colony builds trust (S6)
	index += 1
	stage = Stage.AVAILABLE
	quest_changed.emit()
	_check_boss()  # chain: the next boss might already be dead

## One-line objective for the HUD tracker.
func objective_text() -> String:
	if is_all_done():
		return ""
	var q := current_quest()
	if stage == Stage.AVAILABLE:
		return "Missão disponível na colônia: %s" % str(q["title"])
	if str(q.get("type", "")) == "fetch":
		var have := 0
		var p = GameManager.player
		if p != null and is_instance_valid(p):
			have = p.inventory.get_count(str(q["item"]))
		return "%s — %d/%d" % [str(q["title"]), mini(have, int(q["amount"])), int(q["amount"])]
	return "%s — encontre e derrote" % str(q["title"])

func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.5
	if GameManager.hud and GameManager.hud.has_method("set_quest_text"):
		GameManager.hud.set_quest_text(objective_text())
