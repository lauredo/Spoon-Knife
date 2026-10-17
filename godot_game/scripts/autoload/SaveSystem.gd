extends Node

## Autoload save/load (seed + deltas). The world regenerates DETERMINISTICALLY from
## WorldGenerator.world_seed, so the save file only stores the seed and what CHANGED: searched
## containers, depleted resources, player-built structures (with contents), dead bosses, player
## state, clock, quests and map fog. Death deletes the save — the run is the score (endless
## survival, Don't Starve rules). Auto-saved at each new day + when leaving via the pause menu.

const PATH := "user://save.json"

func has_save() -> bool:
	return FileAccess.file_exists(PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func load_data() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

# ── Collect ─────────────────────────────────────────────────────────────────

func save_game(main: Node) -> void:
	var wg = main.get("world_gen")
	var p = GameManager.player
	if wg == null or p == null or not is_instance_valid(p) or GameManager.is_game_over:
		return
	var qs = GameManager.quest_system
	var d := {
		"seed": wg.world_seed,
		"day": GameManager.current_day,
		"day_number": main.day_night.day_number,
		"time": main.day_night.time_of_day,
		"weather": GameManager.weather,
		"blood_moon": GameManager.blood_moon,
		"heat": GameManager.heat,
		"perks": GameManager.perks.keys(),
		"kills": GameManager.kills, "harvests": GameManager.harvests,
		"loots": GameManager.loots, "sleeps": GameManager.sleeps,
		"island": GameManager.island_reached,
		"rep": GameManager.reputation,
		"player": {
			"x": p.global_position.x, "y": p.global_position.y,
			"hp": p.stats.health, "hunger": p.stats.hunger, "sanity": p.stats.sanity,
			"energy": p.stats.energy, "temp": p.stats.temperature,
			"bleed": p.stats.bleeding_timer, "sick": p.stats.sick_timer,
			"items": p.inventory.items.duplicate(),
			"hotbar": p.inventory.hotbar.duplicate(),
			"slot": p.inventory.equipped_slot,
			"armor": p.inventory.equipped_armor,
			"dur": p.inventory.item_durabilities.duplicate(),
		},
		"searched": _collect_searched(wg),
		"depleted": _collect_depleted(wg),
		"bosses": {
			"alfa": wg.alfa_boss == null or not is_instance_valid(wg.alfa_boss) or wg.alfa_boss.is_dead,
			"jacare": wg.jacare_boss == null or not is_instance_valid(wg.jacare_boss) or wg.jacare_boss.is_dead,
		},
		"quests": {
			"index": qs.index if qs else 0,
			"stage": qs.stage if qs else 0,
			"killed": qs._killed.keys() if qs else [],
		},
		"fog": _collect_fog(main.get("map_menu")),
		"placed": _collect_placed(wg),
		"camp_found": main.get("_camp_found"),
		"found_lm": (main.get("_found_landmarks") as Dictionary).keys(),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func _collect_searched(wg) -> Array:
	var out: Array = []
	for c in wg.structures_node.get_children():
		if c is LootContainer and c.searched:
			out.append(c.save_id)
	return out

func _collect_depleted(wg) -> Array:
	var out: Array = []
	for r in wg.resources_node.get_children():
		if r is ResourceNode and r.is_depleted:
			out.append(r.save_id)
	return out

func _collect_fog(map_menu) -> Array:
	var out: Array = []
	if map_menu:
		for cell in map_menu._explored:
			out.append(int(cell.x) * 1000 + int(cell.y))
	return out

func _collect_placed(wg) -> Array:
	var out: Array = []
	for e in wg.placed_log:
		var n = e["node"]
		if n == null or not is_instance_valid(n):
			continue  # smashed/removed since — gone from the save too
		var rec := {"t": str(e["t"]), "x": n.global_position.x, "y": n.global_position.y}
		if n is Chest:
			rec["contents"] = n.contents.duplicate()
		elif n is Campfire:
			rec["fuel"] = n.fuel_timer
			rec["lit"] = n.is_lit
		elif n is FarmPlot:
			rec["state"] = n.state
			rec["grow"] = n.grow_timer
		out.append(rec)
	return out

# ── Apply (after the seeded world regenerated) ──────────────────────────────

func apply(main: Node, d: Dictionary) -> void:
	var wg = main.get("world_gen")
	var p = GameManager.player
	if wg == null or p == null:
		return
	# Clock & weather
	GameManager.current_day = int(d.get("day", 1))
	main.day_night.day_number = int(d.get("day_number", 1))
	main.day_night.time_of_day = float(d.get("time", 0.1))
	GameManager.weather = int(d.get("weather", 0))
	GameManager.blood_moon = bool(d.get("blood_moon", false))
	GameManager.heat = clampf(float(d.get("heat", 0.0)), 0.0, GameManager.HEAT_MAX)
	GameManager._heat_tier = GameManager.heat_tier()  # silent tier sync (no "CAÇADA" toast on load)
	var perks := {}
	for pk in d.get("perks", []):
		if GameManager.PERKS.has(str(pk)):
			perks[str(pk)] = true
	GameManager.perks = perks
	GameManager.kills = int(d.get("kills", 0))
	GameManager.harvests = int(d.get("harvests", 0))
	GameManager.loots = int(d.get("loots", 0))
	GameManager.sleeps = int(d.get("sleeps", 0))
	GameManager.island_reached = bool(d.get("island", false))
	GameManager.reputation = clampf(float(d.get("rep", 10.0)), 0.0, GameManager.REP_MAX)
	GameManager._rep_tier = GameManager.rep_tier()  # silent tier sync
	if GameManager.hud and GameManager.hud.has_method("_update_perks_label"):
		GameManager.hud._update_perks_label()
	if main.get("weather_sys"):
		main.weather_sys._apply()
	# Player
	var pd: Dictionary = d.get("player", {})
	p.global_position = Vector2(float(pd.get("x", 0.0)), float(pd.get("y", 0.0)))
	p.stats.health = float(pd.get("hp", 150.0))
	p.stats.hunger = float(pd.get("hunger", 150.0))
	p.stats.sanity = float(pd.get("sanity", 200.0))
	p.stats.energy = clampf(float(pd.get("energy", 100.0)), 0.0, PlayerStats.MAX_ENERGY)
	p.stats.temperature = clampf(float(pd.get("temp", 70.0)), 0.0, PlayerStats.MAX_TEMP)
	p.stats.bleeding_timer = maxf(0.0, float(pd.get("bleed", 0.0)))
	p.stats.sick_timer = maxf(0.0, float(pd.get("sick", 0.0)))
	p.stats.take_damage(0.0)      # re-emit the changed signals so the HUD bars sync
	p.stats._change_hunger(0.0)
	p.stats._change_sanity(0.0)
	p.stats._change_energy(0.0)
	p.stats.temperature_changed.emit(p.stats.temperature, PlayerStats.MAX_TEMP)
	# Ids no longer registered (e.g. "ham_bat" from a pre-S6 save) are DROPPED here: an unknown
	# id restored raw becomes an unusable ghost item (empty-looking slot, un-pickable drop).
	var items := {}
	for k in pd.get("items", {}):
		if ItemDatabase.has_item(str(k)):
			items[str(k)] = int(pd["items"][k])
	p.inventory.items = items
	var hb: Array = pd.get("hotbar", [])
	for i in mini(hb.size(), Inventory.HOTBAR_SIZE):
		var hid := str(hb[i])
		p.inventory.hotbar[i] = hid if hid == "" or ItemDatabase.has_item(hid) else ""
	p.inventory.equipped_slot = int(pd.get("slot", 0))
	var armor_id := str(pd.get("armor", ""))
	p.inventory.equipped_armor = armor_id if armor_id == "" or ItemDatabase.has_item(armor_id) else ""
	var durs := {}
	for k in pd.get("dur", {}):
		if ItemDatabase.has_item(str(k)):
			durs[str(k)] = int(pd["dur"][k])
	p.inventory.item_durabilities = durs
	p.inventory.inventory_changed.emit()
	p.inventory.item_equipped.emit(p.inventory.get_equipped_item())
	p.inventory.armor_changed.emit(p.inventory.equipped_armor)
	# Container / resource deltas (matched by deterministic save_id)
	var searched := {}
	for v in d.get("searched", []):
		searched[int(v)] = true
	for c in wg.structures_node.get_children():
		if c is LootContainer and searched.has(c.save_id):
			c.searched = true
			c.queue_redraw()
	var depleted := {}
	for v in d.get("depleted", []):
		depleted[int(v)] = true
	for r in wg.resources_node.get_children():
		if r is ResourceNode and depleted.has(r.save_id):
			r._deplete()
	# Bosses stay dead
	var bd: Dictionary = d.get("bosses", {})
	if bool(bd.get("alfa", false)) and wg.alfa_boss and is_instance_valid(wg.alfa_boss):
		wg.alfa_boss.queue_free()
		wg.alfa_boss = null
	if bool(bd.get("jacare", false)) and wg.jacare_boss and is_instance_valid(wg.jacare_boss):
		wg.jacare_boss.queue_free()
		wg.jacare_boss = null
	# Quests
	var qd: Dictionary = d.get("quests", {})
	var qs = GameManager.quest_system
	if qs:
		qs.index = int(qd.get("index", 0))
		qs.stage = int(qd.get("stage", 0))
		for k in qd.get("killed", []):
			qs._killed[str(k)] = true
	# Map fog
	var mm = main.get("map_menu")
	if mm:
		for v in d.get("fog", []):
			var iv := int(v)
			mm._explored[Vector2i(iv / 1000, iv % 1000)] = true
	# Player-built structures (with their live extras)
	for rec in d.get("placed", []):
		var pos := Vector2(float(rec["x"]), float(rec["y"]))
		if not wg.place_structure(str(rec["t"]), pos, p):
			continue
		var node = wg.structures_node.get_child(wg.structures_node.get_child_count() - 1)
		if node is Chest and rec.has("contents"):
			var cc := {}
			for k in rec["contents"]:
				if ItemDatabase.has_item(str(k)):  # drop unregistered ghost ids (see inventory above)
					cc[str(k)] = int(rec["contents"][k])
			node.contents = cc
		elif node is Campfire:
			if rec.has("fuel"):
				node.fuel_timer = float(rec["fuel"])
			if rec.has("lit"):
				node.is_lit = bool(rec["lit"])
		elif node is FarmPlot:
			if rec.has("state"):
				node.state = int(rec["state"])
			if rec.has("grow"):
				node.grow_timer = float(rec["grow"])
	# Discovery flags
	main.set("_camp_found", bool(d.get("camp_found", false)))
	var fl: Dictionary = main.get("_found_landmarks")
	for k in d.get("found_lm", []):
		fl[int(k)] = true
	if GameManager.hud and GameManager.hud.has_method("show_notification"):
		GameManager.hud.show_notification("💾 Jogo carregado — Dia %d" % GameManager.current_day, 3.5)
