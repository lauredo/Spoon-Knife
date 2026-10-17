class_name WorldGenerator
extends Node

## The world, traced from a real coastal map (Vila Muriqui / Itacuruçá, RJ). Geometry is ORGANIC,
## not a grid: a wavy COASTLINE separates land (north) from sea (south); a curving ROAD spine runs
## the coast with the town strung along it; the forest/hills rise behind (the raccoon's den); and
## ISLANDS sit across the water — the late-game, reachable only by raft. "Distance from the den"
## drives richness; the map gives the shape. (See MUNDO.md / the approved conversion.)

const WORLD_SIZE := 18000.0
const HALF_WORLD := 9000.0
const SPAWN_POS := Vector2(-4500.0, -6800.0)   # the den, up in the forest behind the village

## Zones (kept enum name `District` for call-site compatibility) — derived from position, not bands.
enum District { FOREST, VILLAGE, MARINA, BEACH, SEA, ISLAND }
const MARINA_X := 1600.0
const TOWN_DEPTH := 2600.0    # how far inland the flat coastal town strip reaches
const BEACH_BAND := 300.0
const TIDE_RANGE := 520.0     # px the waterline swings between low/high tide
const CAMP_CLEAR_R := 300.0

const COLONY_POS := Vector2(-2600.0, -4600.0)  # raccoon colony at the forest/village edge
const ISLANDS := [
	{"c": Vector2(400.0, 5200.0), "r": 2300.0, "label": "Ilha de Itacuruçá"},
	{"c": Vector2(5400.0, 6100.0), "r": 1150.0, "label": "Ilha dos Martins"},
]

var world_node: Node2D
var mobs_node: Node2D
var resources_node: Node2D
var structures_node: Node2D
var items_node: Node2D
var day_night: DayNightCycle

var colony_pos: Vector2 = COLONY_POS
var landmarks: Array = []
var alfa_boss: AlfaMob = null      # S4 lair bosses — Main wires their died -> QuestSystem
var jacare_boss: JacareMob = null
## Deterministic generation (save/load): every subsystem RNG derives from this seed, so the SAME
## seed rebuilds the SAME world — saves then only need the deltas (searched/depleted/placed/etc).
var world_seed: int = 0
var placed_log: Array = []         # player-built structures [{t, node}] — persisted by SaveSystem
var tide_offset: float = 0.0   # set each tick by TideSystem; + = high tide (water reaches inland)
var sea_poly: Polygon2D        # the only ground polygon the tide moves
var _building_rects: Array = []

func setup(world: Node2D, dnc: DayNightCycle) -> void:
	world_node = world
	day_night = dnc
	resources_node = world.get_node("Resources")
	mobs_node = world.get_node("Mobs")
	structures_node = world.get_node("Structures")
	items_node = world.get_node("DroppedItems")

## Seeded RNG stream for one subsystem (offset keeps streams independent but reproducible).
func _seeded_rng(offset: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + offset
	return rng

func generate() -> void:
	if world_seed == 0:
		randomize()
		world_seed = randi()  # new game: roll a fresh world; loads inject the saved seed instead
	_paint_ground()
	# Town + islands FIRST: they fill _building_rects, and everything after (forest rocks via
	# _town_pos, mobs, landmarks) must avoid spawning inside buildings (confirmed bug: ~15% of
	# humans/wolves were born trapped indoors).
	_generate_town()
	_generate_islands()
	_generate_forest()
	_generate_colony()
	_generate_mobs()
	_generate_landmarks()
	_generate_bosses()
	# The den comes furnished with a free bed (S5): day 1 already teaches the sleep loop.
	# Placed directly (like the colony fire), NOT via placed_log — it regenerates with the seed.
	var den_bed := Bed.new()
	den_bed.position = SPAWN_POS + Vector2(80.0, -20.0)
	structures_node.add_child(den_bed)
	_create_boundaries()
	_assign_save_ids()

## Stable ids for delta-saving: generation is deterministic, so tree order IS the identity.
func _assign_save_ids() -> void:
	var i := 0
	for c in structures_node.get_children():
		if c is LootContainer:
			c.save_id = i
			i += 1
	var j := 0
	for r in resources_node.get_children():
		if r is ResourceNode:
			r.save_id = j
			j += 1

## S4 lair bosses: they LIVE in places (never on a calendar). Their dens are discoverable
## landmarks, and each drop is a unique VERB relic (collar / scale).
func _generate_bosses() -> void:
	var ax := -8300.0
	alfa_boss = AlfaMob.new()
	alfa_boss.position = Vector2(ax, road_y(ax) - 150.0)
	mobs_node.add_child(alfa_boss)
	landmarks.append({"pos": alfa_boss.position, "label": "Covil do Alfa"})

	var isl0: Vector2 = ISLANDS[0]["c"]
	jacare_boss = JacareMob.new()
	jacare_boss.position = isl0 + Vector2(500.0, -160.0)  # beside the island cave
	mobs_node.add_child(jacare_boss)
	landmarks.append({"pos": jacare_boss.position, "label": "Covil do Jacaré"})

# ── Geometry ────────────────────────────────────────────────────────────────

## The organic coast: land is NORTH of this line, sea SOUTH. Wiggles + a southward bulge where the
## marina peninsula juts into the water.
func coastline_y(x: float) -> float:
	var y := 1600.0
	y += sin(x * 0.00052) * 1000.0
	y += sin(x * 0.0016 + 1.1) * 380.0
	y += 1500.0 * exp(-pow((x - MARINA_X) / 1500.0, 2.0))  # marina peninsula
	return y

## Road spine: parallel to the coast, one strip inland.
func road_y(x: float) -> float:
	return coastline_y(x) - 1250.0

func _on_island(pos: Vector2) -> int:
	for i in ISLANDS.size():
		var c: Vector2 = ISLANDS[i]["c"]
		if pos.distance_to(c) < float(ISLANDS[i]["r"]):
			return i
	return -1

func is_land(pos: Vector2) -> bool:
	if absf(pos.x) > HALF_WORLD or absf(pos.y) > HALF_WORLD:
		return false
	if _on_island(pos) >= 0:
		return true
	return pos.y < coastline_y(pos.x)

## Water accounts for the tide (used for drowning). Islands are never water.
func is_water(pos: Vector2) -> bool:
	if absf(pos.x) > HALF_WORLD or absf(pos.y) > HALF_WORLD:
		return false
	if _on_island(pos) >= 0:
		return false
	return pos.y > coastline_y(pos.x) - tide_offset

func district_at(pos: Vector2) -> int:
	var isl := _on_island(pos)
	if isl >= 0:
		return District.ISLAND
	if pos.y > coastline_y(pos.x):
		return District.SEA
	var inland := coastline_y(pos.x) - pos.y   # + = distance from the water
	if inland < BEACH_BAND:
		return District.BEACH
	if inland > TOWN_DEPTH:
		return District.FOREST
	return District.MARINA if absf(pos.x - MARINA_X) < 2400.0 else District.VILLAGE

func district_display_name(d: int) -> String:
	match d:
		District.FOREST: return "Mata do Morro"
		District.VILLAGE: return "Vila Muriqui"
		District.MARINA: return "Marina"
		District.BEACH: return "Praia"
		District.SEA: return "Mar"
		District.ISLAND: return "Ilha"
	return ""

# ── Ground painting (organic polygons following the coast) ─────────────────

func _paint_ground() -> void:
	var parent := world_node.get_parent()
	if parent == null:
		return
	# Forest (green) fills the land down to the town strip.
	_add_poly(parent, _coast_band(-HALF_WORLD, -HALF_WORLD, -TOWN_DEPTH, true), Color(0.16, 0.34, 0.16), -9)
	# Town strip (concrete) hugs the coast.
	_add_poly(parent, _coast_band(0.0, -TOWN_DEPTH, 0.0, false), Color(0.42, 0.42, 0.43), -8)
	# Beach (sand) at the water's edge.
	_add_poly(parent, _coast_band(0.0, -BEACH_BAND, 0.0, false), Color(0.82, 0.76, 0.55), -8)
	# Sea (this one the tide slides).
	sea_poly = _add_poly(parent, _coast_band(HALF_WORLD, 0.0, 0.0, false, true), Color(0.09, 0.24, 0.36), -8)
	# Deep water further out (static, darker) — drawn over the far sea, still under the islands.
	_add_poly(parent, PackedVector2Array([
		Vector2(-HALF_WORLD, 4600), Vector2(HALF_WORLD, 4600),
		Vector2(HALF_WORLD, HALF_WORLD), Vector2(-HALF_WORLD, HALF_WORLD)]),
		Color(0.05, 0.16, 0.27), -8)
	# Islands (above the sea so they're visible across the water).
	for i in ISLANDS.size():
		var c: Vector2 = ISLANDS[i]["c"]
		var r: float = ISLANDS[i]["r"]
		_add_poly(parent, _blob(c, r * 1.06, i), Color(0.86, 0.79, 0.58), -7)   # sand ring
		_add_poly(parent, _blob(c, r * 0.82, i + 7), Color(0.17, 0.36, 0.17), -6)  # green

## A polygon whose TOP edge is either flat (flat_top_y across X) or the coast + top_off, and whose
## BOTTOM edge is the coast + bot_off (or flat at +HALF when `flat_bottom`).
func _coast_band(flat_y: float, top_off: float, bot_off: float, flat_top: bool, flat_bottom := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var step := 300.0
	var x := -HALF_WORLD
	while x <= HALF_WORLD:
		pts.append(Vector2(x, flat_y if flat_top else coastline_y(x) + top_off))
		x += step
	x = HALF_WORLD
	while x >= -HALF_WORLD:
		pts.append(Vector2(x, HALF_WORLD if flat_bottom else coastline_y(x) + bot_off))
		x -= step
	return pts

func _blob(c: Vector2, r: float, seed_i: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := float(i) / 24.0 * TAU
		var rr := r * (0.82 + 0.18 * sin(a * 3.0 + float(seed_i)))
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts

func _add_poly(parent: Node, poly: PackedVector2Array, col: Color, z: int) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = poly
	p.color = col
	p.z_index = z
	parent.add_child(p)
	return p

# ── Forest ──────────────────────────────────────────────────────────────────

func _generate_forest() -> void:
	var rng := _seeded_rng(3)
	for i in 1500:
		_spawn_resource(ResourceNode.ResourceType.TREE, _forest_pos(rng))
	for i in 260:
		_spawn_resource(ResourceNode.ResourceType.BUSH, _forest_pos(rng))
	for i in 500:
		_spawn_resource(ResourceNode.ResourceType.GRASS_TUFT, _forest_pos(rng))
	# Rocks on the coastal cliffs (a bit of stone near the shore).
	for i in 120:
		var p := _town_pos(rng)
		if p != Vector2.INF:
			_spawn_resource(ResourceNode.ResourceType.ROCK, p)

func _forest_pos(rng: RandomNumberGenerator) -> Vector2:
	var x := rng.randf_range(-HALF_WORLD + 200.0, HALF_WORLD - 200.0)
	var top := -HALF_WORLD + 250.0
	var bot := coastline_y(x) - TOWN_DEPTH - 120.0
	if bot <= top:
		bot = top + 120.0
	var pos := Vector2(x, rng.randf_range(top, bot))
	if pos.distance_to(colony_pos) < CAMP_CLEAR_R:
		pos.y -= CAMP_CLEAR_R
	return pos

# ── Town (road spine + buildings) ──────────────────────────────────────────

func _generate_town() -> void:
	var rng := _seeded_rng(1)
	_draw_road()
	var x := -8200.0
	while x < 3800.0:
		var ry := road_y(x)
		for side in [-1.0, 1.0]:
			var pos := Vector2(x + rng.randf_range(-120.0, 120.0), ry + side * rng.randf_range(430.0, 820.0))
			var z := district_at(pos)
			if not is_land(pos) or (z != District.VILLAGE and z != District.MARINA):
				continue
			if pos.distance_to(colony_pos) < CAMP_CLEAR_R + 150.0:
				continue
			# Whole building must stay ABOVE the spring high-tide line (TIDE_RANGE + max half
			# height + margin): coastal interiors used to flood invisibly and drown the player
			# with no water drawn and no warning (confirmed bug). CLAMP seaside buildings up to
			# the safe line instead of skipping them — keeps the seaside row (dropping it halved
			# the town) while guaranteeing dry interiors.
			pos.y = minf(pos.y, coastline_y(pos.x) - TIDE_RANGE - 250.0)
			_place_building(rng, pos, z)
			_scatter_bins(rng, pos)
		if rng.randf() < 0.6:
			_place_lamp(rng, Vector2(x, ry))
		x += rng.randf_range(440.0, 700.0)  # denser town — a coastal village, not scattered huts

func _draw_road() -> void:
	var line := Line2D.new()
	line.width = 130.0
	line.default_color = Color(0.28, 0.29, 0.32)
	line.z_index = -8
	var edge := Line2D.new()
	edge.width = 150.0
	edge.default_color = Color(0.2, 0.21, 0.24)
	edge.z_index = -9
	var x := -HALF_WORLD
	while x <= HALF_WORLD:
		var pt := Vector2(x, road_y(x))
		line.add_point(pt)
		edge.add_point(pt)
		x += 250.0
	world_node.get_parent().add_child(edge)
	world_node.get_parent().add_child(line)

func _place_building(rng: RandomNumberGenerator, pos: Vector2, zone: int) -> void:
	var b := Building.new()
	b.size = Vector2(rng.randf_range(300.0, 400.0), rng.randf_range(260.0, 340.0))
	b.door_side = rng.randi() % 4
	match zone:
		District.VILLAGE:
			b.wall_col = Color(0.62, 0.5, 0.42).lightened(rng.randf_range(-0.1, 0.15))
			b.roof_col = Color(0.5, 0.32, 0.24)
			b.has_fence = true
		District.MARINA:
			b.wall_col = Color(0.86, 0.86, 0.9).lightened(rng.randf_range(-0.1, 0.05))  # painted resort
			b.roof_col = Color(0.6, 0.3, 0.28)
		District.ISLAND:
			b.wall_col = Color(0.8, 0.78, 0.7)
			b.roof_col = Color(0.4, 0.42, 0.46)
	b.position = pos
	structures_node.add_child(b)
	_building_rects.append(Rect2(pos - b.size * 0.5, b.size))
	_furnish_building(rng, b, zone)

func _scatter_bins(rng: RandomNumberGenerator, near: Vector2) -> void:
	for i in rng.randi_range(0, 2):
		var pos := near + Vector2(rng.randf_range(-160.0, 160.0), rng.randf_range(-160.0, 160.0))
		if _inside_building(pos, 60.0) or not is_land(pos):
			continue
		var bin := LootContainer.new()
		bin.kind = LootContainer.Kind.TRASH_BIN
		bin.district = district_at(pos)
		bin.position = pos
		structures_node.add_child(bin)

func _place_lamp(rng: RandomNumberGenerator, pos: Vector2) -> void:
	if _inside_building(pos, 40.0):
		return
	var lamp := StreetLight.new()
	lamp.doomed = rng.randf() < 0.5
	lamp.position = pos
	structures_node.add_child(lamp)

## Places 1-3 containers inside a building + sometimes a rat nest (not on islands — the sea guards
## those). Matches container kind and loot to the zone.
func _furnish_building(rng: RandomNumberGenerator, b: Building, zone: int) -> void:
	var inner := b.size * 0.5 - Vector2(60.0, 60.0)
	var spots: Array = []
	for i in rng.randi_range(1, 3):
		var pos: Vector2 = b.position + Vector2(rng.randf_range(-inner.x, inner.x), rng.randf_range(-inner.y, inner.y))
		var ok := true
		for s in spots:
			if pos.distance_to(s) < 60.0:
				ok = false
				break
		if not ok:
			continue
		spots.append(pos)
		var c := LootContainer.new()
		c.district = zone
		match zone:
			District.VILLAGE:
				c.kind = LootContainer.Kind.FRIDGE if rng.randf() < 0.5 else LootContainer.Kind.CABINET
			District.MARINA:
				c.kind = LootContainer.Kind.SHELF if rng.randf() < 0.6 else LootContainer.Kind.FRIDGE
			_:
				c.kind = LootContainer.Kind.SHELF if rng.randf() < 0.6 else LootContainer.Kind.CABINET
		c.position = pos
		structures_node.add_child(c)
	if zone != District.ISLAND and rng.randf() < 0.3:
		for r in rng.randi_range(1, 2):
			var rat := RatMob.new()
			rat.home_pos = b.position + Vector2(rng.randf_range(-inner.x, inner.x), rng.randf_range(-inner.y, inner.y))
			rat.position = rat.home_pos
			mobs_node.add_child(rat)

func _inside_building(p: Vector2, margin: float = 40.0) -> bool:
	for r in _building_rects:
		if (r as Rect2).grow(margin).has_point(p):
			return true
	return false

func _town_pos(rng: RandomNumberGenerator) -> Vector2:
	for tries in 10:
		var x := rng.randf_range(-8000.0, 3600.0)
		var pos := Vector2(x + rng.randf_range(-200.0, 200.0), road_y(x) + rng.randf_range(-900.0, 400.0))
		var z := district_at(pos)
		if is_land(pos) and (z == District.VILLAGE or z == District.MARINA) and not _inside_building(pos, 60.0):
			return pos
	return Vector2.INF

# ── Islands (the raft late-game — best loot) ────────────────────────────────

func _generate_islands() -> void:
	var rng := _seeded_rng(2)
	for i in ISLANDS.size():
		var c: Vector2 = ISLANDS[i]["c"]
		var r: float = ISLANDS[i]["r"]
		for t in (6 if r > 1500.0 else 2):
			var a := rng.randf() * TAU
			var d := rng.randf_range(0.0, r * 0.55)
			_place_building(rng, c + Vector2(cos(a), sin(a)) * d, District.ISLAND)
		# A bit of green + palms feel: trees on the island (not through a roof).
		for t in int(r / 90.0):
			var a2 := rng.randf() * TAU
			var d2 := rng.randf_range(0.0, r * 0.72)
			var tpos := c + Vector2(cos(a2), sin(a2)) * d2
			if not _inside_building(tpos, 40.0):
				_spawn_resource(ResourceNode.ResourceType.TREE, tpos)

# ── Mobs ────────────────────────────────────────────────────────────────────

func _generate_mobs() -> void:
	var rng := _seeded_rng(5)
	# Wildlife in the forest; street dogs on the town edge; humans patrol the living town by day.
	for h in 5:
		var herd := _forest_pos(rng)
		for d in 3:
			var deer := DeerMob.new()
			deer.home_pos = herd + Vector2(rng.randf_range(-70, 70), rng.randf_range(-70, 70))
			deer.position = deer.home_pos
			mobs_node.add_child(deer)
	for i in 12:
		_spawn_boar(_forest_pos(rng))
	for i in 30:
		_spawn_barata(_forest_pos(rng))   # giant roaches deep in the overgrowth
	for i in 14:
		var d := _town_pos(rng)
		if d != Vector2.INF:
			_spawn_wolf(d)                # stray dogs prowling the streets
	var shirts := [Color(0.35, 0.5, 0.7), Color(0.7, 0.4, 0.35), Color(0.45, 0.6, 0.4),
		Color(0.75, 0.7, 0.45), Color(0.55, 0.45, 0.65)]
	for i in 40:
		var p := _town_pos(rng)
		if p != Vector2.INF:
			_spawn_human(p, shirts[i % shirts.size()])
	# Island crabs — the landfall threat (see CrabMob): tethered territorials, so looting
	# AROUND them is the play. No fast respawn (like the dogs) — clearing a beachhead sticks.
	for i in ISLANDS.size():
		var ic: Vector2 = ISLANDS[i]["c"]
		var ir: float = ISLANDS[i]["r"]
		var count: int = 5 if ir > 1500.0 else 3
		var placed := 0
		var guard := 0
		while placed < count and guard < 60:
			guard += 1
			var a := rng.randf() * TAU
			var d := rng.randf_range(ir * 0.15, ir * 0.65)
			var cpos := ic + Vector2(cos(a), sin(a)) * d
			if _inside_building(cpos, 60.0):
				continue
			if i == 0 and cpos.distance_to(ic + Vector2(500, -160)) < 380.0:
				continue  # keep the Jacaré cave approach a boss fight, not a gauntlet
			var crab := CrabMob.new()
			crab.home_pos = cpos
			crab.position = cpos
			mobs_node.add_child(crab)
			placed += 1

# ── Raccoon colony + landmarks ──────────────────────────────────────────────

func _generate_colony() -> void:
	colony_pos = COLONY_POS
	var fire := Campfire.new()
	fire.position = colony_pos
	fire.fuel_timer = 1.0e9
	structures_node.add_child(fire)
	for off in [Vector2(-90, -40), Vector2(85, -55), Vector2(20, -95)]:
		var tent := TribeTent.new()
		tent.position = colony_pos + off
		structures_node.add_child(tent)
	var trader := CrowTrader.new()
	trader.position = colony_pos + Vector2(70, 35)
	structures_node.add_child(trader)
	var qboard := QuestBoard.new()
	qboard.position = colony_pos + Vector2(-80, 30)
	structures_node.add_child(qboard)
	var rng := _seeded_rng(4)
	var tints := [Color(0.6, 0.58, 0.63), Color(0.48, 0.46, 0.52), Color(0.68, 0.66, 0.7)]
	for i in 3:
		var kit := ColonyRaccoon.new()
		kit.home_pos = colony_pos + Vector2(rng.randf_range(-80, 80), rng.randf_range(0, 90))
		kit.position = kit.home_pos
		kit.body_color = tints[i]
		mobs_node.add_child(kit)

func _generate_landmarks() -> void:
	var rng := _seeded_rng(6)  # deterministic: landmark extras must rebuild identically on load
	var isl0: Vector2 = ISLANDS[0]["c"]
	var placements := [
		{"kind": Landmark.Kind.ANCIENT_TREE, "pos": Vector2(-800.0, -6600.0), "label": "Cachoeira Itinguçu"},
		{"kind": Landmark.Kind.ABANDONED_CAMP, "pos": _town_pos_or(Vector2(-6000.0, -1200.0), rng)},
		{"kind": Landmark.Kind.CAVE, "pos": isl0 + Vector2(500.0, -300.0)},
	]
	for pl in placements:
		var lm := Landmark.new()
		lm.kind = pl["kind"]
		lm.position = pl["pos"]
		structures_node.add_child(lm)
		var label: String = pl.get("label", lm.label())
		landmarks.append({"pos": pl["pos"], "label": label})
		_landmark_extras(pl["kind"], pl["pos"], rng)

func _town_pos_or(fallback: Vector2, rng: RandomNumberGenerator) -> Vector2:
	var p := _town_pos(rng)
	return fallback if p == Vector2.INF else p

func _landmark_extras(kind: int, pos: Vector2, rng: RandomNumberGenerator) -> void:
	match kind:
		Landmark.Kind.ABANDONED_CAMP:
			var chest := Chest.new()
			chest.position = pos + Vector2(42, 12)
			chest.contents = {"wood": 6, "flint": 4, "bandage": 1, "cooked_meat": 2}
			structures_node.add_child(chest)
		Landmark.Kind.ANCIENT_TREE:
			for i in 7:
				var a := rng.randf() * TAU
				_spawn_resource(ResourceNode.ResourceType.TREE, pos + Vector2(cos(a), sin(a)) * rng.randf_range(75.0, 150.0))

# ── Boundaries ──────────────────────────────────────────────────────────────

const WALL_T := 120.0

func _create_boundaries() -> void:
	var body := StaticBody2D.new()
	body.name = "Boundary"
	body.collision_layer = 1
	body.collision_mask = 0
	var s := WORLD_SIZE + WALL_T * 2.0
	_add_wall(body, Vector2(0.0, -HALF_WORLD - WALL_T * 0.5), Vector2(s, WALL_T))
	_add_wall(body, Vector2(0.0, HALF_WORLD + WALL_T * 0.5), Vector2(s, WALL_T))
	_add_wall(body, Vector2(-HALF_WORLD - WALL_T * 0.5, 0.0), Vector2(WALL_T, s))
	_add_wall(body, Vector2(HALF_WORLD + WALL_T * 0.5, 0.0), Vector2(WALL_T, s))
	world_node.add_child(body)

func _add_wall(body: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	body.add_child(col)

# ── Spawners ────────────────────────────────────────────────────────────────

func _spawn_resource(type: ResourceNode.ResourceType, pos: Vector2) -> Node:
	var node := ResourceNode.new()
	node.resource_type = type
	node.position = pos
	resources_node.add_child(node)
	return node

func _spawn_barata(pos: Vector2) -> Node:
	var mob := BarataMob.new()
	mob.position = pos
	mobs_node.add_child(mob)
	if day_night:
		day_night.register_barata(mob)
	# The signal already carries the mob (died(mob)); binding it again made the callable
	# receive 2 args for a 1-arg handler -> Godot never invoked it and respawn silently died.
	mob.died.connect(_on_mob_died)
	return mob

func _spawn_boar(pos: Vector2) -> Node:
	var mob := BoarMob.new()
	mob.position = pos
	mobs_node.add_child(mob)
	mob.died.connect(_on_mob_died)
	return mob

func _spawn_wolf(pos: Vector2) -> void:
	var wolf := WolfMob.new()
	wolf.home_pos = pos
	wolf.position = pos
	mobs_node.add_child(wolf)

func _spawn_human(pos: Vector2, shirt: Color) -> void:
	var h := HumanNPC.new()
	h.home_pos = pos
	h.position = pos
	h.shirt_col = shirt
	mobs_node.add_child(h)

func _on_mob_died(mob: MobBase) -> void:
	var pos := mob.global_position
	var mob_type := "barata" if mob is BarataMob else "boar"
	# Fauna comes back in DAYS, not minutes: the old 60-120s respawn made the forest an infinite
	# buffet at the den's doorstep, so the "loot depletes -> push outward" spine never engaged
	# (review finding). 1.5-2.5 day-cycles = hunting an area actually thins it for a while.
	await get_tree().create_timer(randf_range(1.5, 2.5) * DayNightCycle.CYCLE_DURATION).timeout
	if is_instance_valid(world_node):
		var new_pos := pos + Vector2(randf_range(-200, 200), randf_range(-200, 200))
		if mob_type == "barata":
			_spawn_barata(new_pos)
		else:
			_spawn_boar(new_pos)

# ── Placement (crafted structures) ──────────────────────────────────────────

func place_structure(structure_type: String, position: Vector2, player: Player) -> bool:
	var ok := false
	match structure_type:
		"campfire": ok = _place_campfire(position)
		"chest": ok = _place_chest(position)
		"workbench": ok = _place_workbench(position)
		"wall": ok = _place_wall(position)
		"farm_plot": ok = _place_farm_plot(position)
		"bed": ok = _place_bed(position)
	if ok:
		# Log player-built structures for the save file (node ref → live extras at save time).
		placed_log.append({"t": structure_type, "node": structures_node.get_child(structures_node.get_child_count() - 1)})
	return ok

func _place_campfire(pos: Vector2) -> bool:
	var c := Campfire.new(); c.position = pos; structures_node.add_child(c); return true

func _place_chest(pos: Vector2) -> bool:
	var c := Chest.new(); c.position = pos; structures_node.add_child(c); return true

func _place_workbench(pos: Vector2) -> bool:
	var w := Workbench.new(); w.position = pos; structures_node.add_child(w); return true

func _place_wall(pos: Vector2) -> bool:
	var w := Wall.new(); w.position = pos; structures_node.add_child(w); return true

func _place_farm_plot(pos: Vector2) -> bool:
	var f := FarmPlot.new(); f.position = pos; structures_node.add_child(f); return true

func _place_bed(pos: Vector2) -> bool:
	var b := Bed.new(); b.position = pos; structures_node.add_child(b); return true
