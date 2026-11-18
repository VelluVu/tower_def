extends RefCounted

## A bot plays one level through the real Main and reports the result, lives, reactions and damage
## per tower and enemy type; the run is also written to user://bot_playtests.jsonl like a player's
## run (`python tools/playtests.py --bot`). Script errors show up in the output.
## `python tools/gd.py run tools/reports/soak_level.gd level=4 [key=value...] --raw`
##   economy=real|free   real: the level's own gold; free: gold is topped up every frame
##   build=mixed|fire|frost|poison|physical  a tactic (BUILDS): its tower types, their element, its tree and
##                       the stats its cards should raise; mixed = every tower type, elements by rotation
##   talents=none|all|fire:30,building:10|focus:30|budget:120   points per tree (focus = the build's tree; budget = a
##                       player's total: the build's tree first, then Building, then the other trees), spent on the
##                       nearest working nodes, nodes that fit the build first
##   cards=random|fit    random offer, or the offer that best fits the build (its stats, then the luckiest roll)
##   mode=normal|hard|survival  the level mode (hard: the level's LevelModeData scales the waves and enemies;
##                       survival: endless waves, the result is the wave the lives ran out in)
##   health=1.0 speed=1.0 life=N             extra enemy multipliers and starting life, on top of the mode
##   rotation=0-2        which element each tower type takes (Fire, Frost, Poison shifted by rotation)
##   order=fixed|shuffle tower types in Bolter, Nova, Beamer order or shuffled
##   towers=40 traps=2   most towers and traps the bot builds (12 left hundreds of gold unspent late)
##   wall_min_towers=5   no walls before this many towers (a player builds a defence before a maze)
##   min_towers=3        towers placed before anything else
##   depth=3             purchases every tower gets before the next tower (3 = Up 1, Up 2, element)
##   walls=0.3           share of the spent gold that may go to walls (maze), 0 = no walls
##   early=0|1           start waves early, or only once a wave is cleared
##   unlocked=level|all  level: only the buildings unlocked by this level (BuildingListElement.unlock_level)
##   seed=1 speed_up=3.0

const MAIN_SCENE : String = "res://scenes/main.tscn"
const TOWERS : Array[String] = ["puffe_bolter", "puffe_nova", "puffe_beamer"]
const TRAP : String = "leopard_trap"
const WALL : String = "wall"
const BUILDING_LIST_PATH : String = "res://scenes/unit/building/buildings/%s.tres"
const LEAVES : Array[String] = ["FireElementEvolveLeaf", "FrostElementEvolveLeaf", "PoisonElementEvolveLeaf"]
const TALENT_BOOK : TalentBook = preload("res://scenes/talents/talent_book.tres")
const LEVEL_SECONDS : float = 1500.0
const LEVEL_LOAD_FRAMES : int = 600
const FREE_GOLD : float = 9999.0
const BLOCKED_WEIGHT : float = 100.0
const DIGITS : String = "0123456789"
const LEAF_META : StringName = &"soak_leaf"
const RANGE_META : StringName = &"soak_range"
const WALL_COVER_WEIGHT : int = 1000
const TOWER_FLAGS : Dictionary[String, int] = {"puffe_bolter": TalentEffect.BOLTER, "puffe_nova": TalentEffect.NOVA, "puffe_beamer": TalentEffect.BEAMER}
## A build: the tower types in build order, their element leaf, its talent tree, its wall share and the card
## stats it wants most first. A tower type not unlocked yet is skipped (the Bolter always is).
const BUILDS : Dictionary[String, Dictionary] = {
	"mixed": {},
	"fire": {"towers": ["puffe_bolter", "puffe_nova"], "leaf": "FireElementEvolveLeaf", "element": Utils.Element.Fire, "tree": "fire", "walls": 0.3,
		"cards": [Utils.StatType.Damage, Utils.StatType.AttackSpeed, Utils.StatType.EffectPotency, Utils.StatType.CriticalChance]},
	"frost": {"towers": ["puffe_nova", "puffe_beamer", "puffe_bolter"], "leaf": "FrostElementEvolveLeaf", "element": Utils.Element.Frost, "tree": "frost", "walls": 0.5,
		"cards": [Utils.StatType.EffectPotency, Utils.StatType.AttackRange, Utils.StatType.Damage, Utils.StatType.AttackSpeed]},
	"poison": {"towers": ["puffe_beamer", "puffe_bolter"], "leaf": "PoisonElementEvolveLeaf", "element": Utils.Element.Poison, "tree": "poison", "walls": 0.3,
		"cards": [Utils.StatType.EffectPotency, Utils.StatType.Damage, Utils.StatType.ActiveDuration, Utils.StatType.AttackSpeed]},
	"physical": {"towers": ["puffe_bolter", "puffe_beamer", "puffe_nova"], "leaf": "PhysicalElementEvolveLeaf", "element": Utils.Element.Physical, "tree": "building", "walls": 0.4,
		"cards": [Utils.StatType.Damage, Utils.StatType.CriticalChance, Utils.StatType.CriticalMultiplier, Utils.StatType.AttackSpeed]},
}

var options : Dictionary[String, String] = {
	"level": "1", "mode": "normal", "build": "mixed", "cards": "random", "economy": "real", "talents": "none", "health": "1.0", "speed": "1.0", "life": "",
	"rotation": "0", "order": "fixed", "towers": "40", "traps": "2", "min_towers": "3", "depth": "3", "wall_min_towers": "5",
	"walls": "0.3", "early": "0", "unlocked": "level", "seed": "1", "speed_up": "3.0",
}
var towers : Array[Building] = []
var traps : int = 0
var walls : int = 0
var purchases : Dictionary[Building, int] = {}
var prices : Dictionary[String, float] = {}
var type_order : Array[int] = []
var gold_spent : float = 0.0
var wall_gold : float = 0.0
#the paths only change when a building goes up, so the costly searches are cached until then
var cached_paths : Array[PackedVector2Array] = []
var cached_ids : Dictionary[int, bool] = {}
var is_wall_exhausted : bool = false

var reactions : Dictionary[String, int] = {}
var tower_damage : Dictionary[String, float] = {}
var enemy_damage : Dictionary[String, float] = {}
var spawned : Dictionary[String, int] = {}
var killed : Dictionary[String, int] = {}
var leaked : Dictionary[String, int] = {}
var cards : int = 0
var result : String = "timeout"
var build : Dictionary = {}


func run(kit : TestKit, args : PackedStringArray) -> void:
	var given : Dictionary[String, bool] = {}
	for arg in args:
		var parts : PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2:
			options[parts[0]] = parts[1]
			given[parts[0]] = true
	build = BUILDS.get(options.build, {})
	#the build's wall share, unless walls= was given
	if build.has("walls") and not given.has("walls"):
		options.walls = str(build.walls)
	seed(int(options.seed))
	PlaytestLog.is_enabled = true
	PlaytestLog.player = "bot " + " ".join(args)

	var spent_talents : Dictionary[String, int] = _spend_talents(options.talents)
	var main : Main = load(MAIN_SCENE).instantiate()
	kit.root.add_child(main)
	await kit.frames(2)

	var modes : Dictionary = {"normal": Utils.LevelMode.Normal, "hard": Utils.LevelMode.Hard, "survival": Utils.LevelMode.Survival}
	UISignals.start_level_button_pressed.emit(int(options.level), modes.get(options.mode, Utils.LevelMode.Normal))
	var level : Level = null
	for i in LEVEL_LOAD_FRAMES:
		await kit.frames()
		level = main.scene_manager.current_level as Level
		if level != null and level.is_node_ready():
			break
	kit.level = level
	await kit.frames(2)

	if not options.life.is_empty():
		level.player_stats.life = float(options.life)
	var starting_life : float = level.player_stats.life
	var is_free : bool = options.economy == "free"

	GameSignals.element_reaction.connect(func(_p : Vector2, reaction : ElementReaction) -> void: _add(reactions, reaction.display_name, 1))
	GameSignals.enemy_spawned.connect(_on_enemy_spawned)
	GameSignals.enemy_hit.connect(_on_enemy_hit)
	GameSignals.enemy_destroyed.connect(func(enemy : Enemy) -> void: _add(killed, _type_of(enemy), 1))
	GameSignals.enemy_reached_end_point.connect(func(enemy : Enemy) -> void: _add(leaked, _type_of(enemy), 1))
	GameSignals.level_completed.connect(func(_l : Level) -> void: result = "won")
	GameSignals.lose_game.connect(func() -> void: result = "lost")
	GameSignals.astar_grid_updated.connect(func() -> void:
		cached_paths.clear()
		is_wall_exhausted = false)

	print("SOAK level %s %s, build %s, cards %s, %s economy, start gold %.0f, talents %s, health x%s, speed x%s, life %.0f" % [
		options.level, options.mode, options.build, options.cards, options.economy, level.player_stats.gold, spent_talents, options.health, options.speed, starting_life])

	var speed_up : float = float(options.speed_up)
	main.time_scale = speed_up
	GameSignals.time_scale_change.emit(speed_up)
	var is_early : bool = options.early == "1"
	var start_length : int = _route_length(level)

	var time : float = 0.0
	while result == "timeout" and time < LEVEL_SECONDS:
		if is_free:
			level.player_stats.gold = FREE_GOLD
		#Survival never ends on its own: past the last points milestone counts as a win
		if level.wave_runner.is_endless and level.wave_runner.wave_number > SurvivalRules.MILESTONES[-1]:
			result = "won"
			break
		#the first wave waits until the opening build is done
		await _spend(kit, level)
		if not level.upgrades.offered_cards.is_empty():
			cards += 1
			level.upgrades._on_upgrade_card_selected(_pick_card(level.upgrades.offered_cards))
		var is_ready : bool = level.wave_runner.wave_number > 0 or towers.size() >= int(options.min_towers)
		if is_ready and level.wave_runner.can_start_next_wave and (is_early or level.existing_enemies.is_empty()):
			UISignals.start_wave_pressed.emit()
		await kit.root.get_tree().process_frame
		time += kit.root.get_process_delta_time()

	if result == "timeout":
		#a wave that never ends: who is still alive, and where
		for enemy in level.existing_enemies:
			if is_instance_valid(enemy):
				print("SOAK stuck %s at cell %s, health %.0f, burrowed %s" % [enemy.name, level.grid.world_position_to_grid(enemy.global_position),
					enemy.stats.get_stat_value(Utils.StatType.Health), enemy.is_burrowed])
				print("SOAK stuck   waypoint %d/%d next %s, velocity %s, deactivated %s, frozen %s, colliding building %s, path %s" % [
					enemy.current_waypoint_index, enemy.point_path.size(), level.grid.world_position_to_grid(enemy.next_waypoint),
					enemy.velocity, enemy.is_deactivated, enemy.is_frozen, enemy.is_colliding_building,
					Array(enemy.point_path).map(func(p : Vector2) -> Vector2i: return level.grid.world_position_to_grid(p))])
	await kit.frames(2)
	var elements : Dictionary[String, String] = {}
	var bought : Dictionary[String, int] = {}
	for tower in towers:
		if is_instance_valid(tower):
			elements[_type_of(tower)] = Utils.Element.find_key(tower.evolve_tree.evolve_element)
			_add(bought, _type_of(tower), purchases.get(tower, 0))
	print("SOAK result %s: wave %d/%d, life %.0f/%.0f, cards %d, early starts %d, gold left %.0f" % [
		result, level.wave_runner.wave_number, level.wave_runner.wave_count, level.player_stats.life, starting_life, cards, level.early_starts, level.player_stats.gold])
	print("SOAK built %d towers, %d traps, %d walls (%.0f of %.0f gold), route %d -> %d cells, purchases %s, elements %s" % [
		towers.size(), traps, walls, wall_gold, gold_spent, start_length, _route_length(level), bought, elements])
	print("SOAK enemies spawned %s, killed %s, leaked %s" % [spawned, killed, leaked])
	print("SOAK damage by tower %s" % _rounded(tower_damage))
	print("SOAK damage by enemy %s" % _rounded(enemy_damage))
	print("SOAK reactions %s" % reactions)
	main.get_tree().paused = false
	#writes this run to the bot log
	level.queue_free()
	await kit.frames(2)


## Spends each tree's points one rank at a time on the nearest node that can take it, working
## nodes first, so the points buy what a player would. "all" maxes every node.
func _spend_talents(spec : String) -> Dictionary[String, int]:
	var budgets : Dictionary[String, int] = {}
	#budget:N: one total, spent like a player who has learned a lot: the build's own tree, then Building, then the rest
	var total_budget : int = int(spec.get_slice(":", 1)) if spec.begins_with("budget:") else -1
	for part in ([] if total_budget >= 0 else spec.split(",", false)):
		var pair : PackedStringArray = part.split(":")
		if pair.size() == 2:
			var tree_id : String = build.get("tree", "building") if pair[0] == "focus" else pair[0]
			budgets[tree_id] = budgets.get(tree_id, 0) + int(pair[1])

	var spent : Dictionary[String, int] = {}
	var trees : Array[TalentTree] = TALENT_BOOK.trees.duplicate()
	if total_budget >= 0:
		var first : String = build.get("tree", "building")
		trees.sort_custom(func(a : TalentTree, b : TalentTree) -> bool:
			var rank_a : int = 0 if String(a.id) == first else 1 if a.id == &"building" else 2
			var rank_b : int = 0 if String(b.id) == first else 1 if b.id == &"building" else 2
			return rank_a < rank_b)
	for tree in trees:
		PlayerProgress.reset_talent_tree(tree.id)
		var ranks : Dictionary = {}

		if spec == "all":
			for node in tree.nodes:
				ranks[node.id] = node.max_rank
		else:
			var points : int = budgets.get(String(tree.id), 0) if total_budget < 0 else total_budget
			var steps : Dictionary[StringName, int] = _tree_steps(tree)
			while points > 0:
				var best : TalentNode = null
				for node in tree.nodes:
					if TalentRules.can_add(tree, ranks, node, points) and (best == null or _is_better_node(node, best, steps)):
						best = node
				if best == null or (total_budget >= 0 and not best.is_implemented):
					break
				ranks[best.id] = TalentRules.get_rank(ranks, best.id) + 1
				points -= 1
			#the budget's rest goes on to the next tree, working nodes only (a player skips the idle ones)
			if total_budget >= 0:
				total_budget = points

		for node_id in ranks:
			PlayerProgress.set_talent_rank(tree.id, node_id, ranks[node_id])
		if not ranks.is_empty():
			spent[String(tree.id)] = TalentRules.get_spent(ranks)
			print("SOAK talent nodes %s %s" % [tree.id, ranks])

	return spent


func _is_better_node(node : TalentNode, other : TalentNode, steps : Dictionary[StringName, int]) -> bool:
	if node.is_implemented != other.is_implemented:
		return node.is_implemented
	var fits : bool = _node_fits_build(node)
	if fits != _node_fits_build(other):
		return fits
	return steps.get(node.id, 99) < steps.get(other.id, 99)


## A node helps the build when one of its effects is start gold or reaches the build's towers in its element.
func _node_fits_build(node : TalentNode) -> bool:
	if build.is_empty():
		return true
	var tower_flags : int = 0
	for scene_name in build.towers:
		tower_flags |= TOWER_FLAGS[scene_name]
	for effect in node.effects:
		if effect.kind == TalentEffect.Kind.StartGold:
			return true
		if effect.buildings & tower_flags != 0 and (effect.elements == 0 or effect.elements & int(build.element) != 0):
			return true
	return false


## The offer to take: random, or with cards=fit the one whose stat the build wants most, then the
## luckiest roll (a rolled x3 beats a plain x1 of the same stat).
func _pick_card(offered : Array[UpgradeCard]) -> int:
	if options.cards != "fit" or build.is_empty():
		return randi() % offered.size()
	var best : int = 0
	var best_score : float = -INF
	var wanted : Array = build.cards
	for index in offered.size():
		var card : UpgradeCard = offered[index]
		var rank : int = wanted.find(card.resource.modify_stat_type)
		var is_stat : bool = card.resource.card_target == EvolveResource.CardTarget.Buildings
		var score : float = float(wanted.size() - rank) * 2.0 if rank >= 0 and is_stat else 0.0
		if card.resource.elements != 0 and card.resource.elements & int(build.element) == 0:
			score -= 4.0
		if card.resource.modify_value != 0.0:
			score += card.value / card.resource.modify_value
		if score > best_score:
			best_score = score
			best = index
	return best


## The tower types this run builds, in order: the build's unlocked ones, or every unlocked type.
func _tower_types() -> Array[String]:
	var types : Array[String] = []
	for scene_name in build.get("towers", TOWERS):
		if _is_unlocked(scene_name):
			types.append(scene_name)
	if types.is_empty():
		types.append(TOWERS[0])
	return types


func _tree_steps(tree : TalentTree) -> Dictionary[StringName, int]:
	var opens : Dictionary[StringName, Array] = TalentRules.get_opens(tree)
	var steps : Dictionary[StringName, int] = {tree.start_id: 0}
	var queue : Array[StringName] = [tree.start_id]
	while not queue.is_empty():
		var current : StringName = queue.pop_front()
		for next_id in opens.get(current, []):
			if not steps.has(next_id):
				steps[next_id] = steps[current] + 1
				queue.append(next_id)
	return steps


## One action a frame, like a player clicking: the first towers, then walls while they are under
## their share of the gold, then upgrades up to depth, then the next tower or trap.
## Waits (saves gold) when the chosen action costs more than it has.
func _spend(kit : TestKit, level : Level) -> void:
	var tower_cap : int = int(options.towers)
	if towers.size() < int(options.min_towers):
		await _place_tower(kit, level)
		return

	var wall_share : float = float(options.walls)
	if wall_share > 0.0 and not is_wall_exhausted and wall_gold <= wall_share * gold_spent and towers.size() >= int(options.wall_min_towers):
		if level.player_stats.has_enough_gold(_price_of(WALL)):
			var wall_cell : Vector2i = _best_wall_cell(level)
			if wall_cell != Vector2i.MAX:
				await _place(kit, level, WALL, wall_cell)
				walls += 1
				return
			is_wall_exhausted = true
		else:
			return

	var behind : Building = null
	for tower in towers:
		if is_instance_valid(tower) and _has_options(level, tower) and (behind == null or purchases.get(tower, 0) < purchases.get(behind, 0)):
			behind = tower
	if behind != null and purchases.get(behind, 0) < int(options.depth):
		await _buy_next(level, behind)
		return

	if traps < int(options.traps) and traps * 4 < towers.size() and _is_unlocked(TRAP):
		if level.player_stats.has_enough_gold(_price_of(TRAP)):
			var trap_cell : Vector2i = _best_trap_cell(level)
			if trap_cell != Vector2i.MAX:
				await _place(kit, level, TRAP, trap_cell)
				traps += 1
		return

	#no free cell left for a tower: the gold goes to upgrades instead
	if towers.size() < tower_cap and await _place_tower(kit, level):
		return
	if behind != null:
		await _buy_next(level, behind)


## False when there is no cell left for the next tower (not enough gold only waits).
func _place_tower(kit : TestKit, level : Level) -> bool:
	var types : Array[String] = _tower_types()
	if type_order.is_empty():
		for type in types.size():
			type_order.append(type)
		if options.order == "shuffle":
			type_order.shuffle()
	var type : int = type_order[0]
	var scene_name : String = types[type]
	if not level.player_stats.has_enough_gold(_placement_price(level, scene_name)):
		return true
	var cell : Vector2i = _best_tower_cell(level, _range_of(scene_name))
	if cell == Vector2i.MAX:
		return false
	type_order.pop_front()
	var tower : Building = await _place(kit, level, scene_name, cell)
	var leaf : String = build.leaf if build.has("leaf") else LEAVES[(TOWERS.find(scene_name) + int(options.rotation)) % LEAVES.size()]
	tower.set_meta(LEAF_META, leaf)
	tower.set_meta(RANGE_META, _range_of(scene_name))
	towers.append(tower)
	purchases[tower] = 0
	return true


#PlayerStats takes the price itself when the building is placed
func _place(kit : TestKit, level : Level, scene_name : String, cell : Vector2i) -> Building:
	var price : float = _placement_price(level, scene_name)
	gold_spent += price
	if scene_name == WALL:
		wall_gold += price
	return await kit.place(scene_name, cell)


#the base price plus the tower price step for every stepped building on the map
func _placement_price(level : Level, scene_name : String) -> float:
	var key : String = scene_name + "_step"
	if not prices.has(key):
		var instance : Building = load(TestKit.BUILDING_PATH % scene_name).instantiate()
		prices[key] = instance.price_step
		instance.free()
	return _price_of(scene_name) + UpgradeRules.price_step_extra(prices[key], level.get_price_step_count())


## Buys the tower's next upgrade, its element leaf when it is the evolve step.
func _buy_next(level : Level, tower : Building) -> void:
	var upgrades : BuildingTypeUpgrades = level.building_type_upgrades
	upgrades._on_unit_selected(tower)
	var offered : Array[GoldUpgradeOption] = upgrades.options
	if offered.is_empty():
		return
	var index : int = 0
	for o in offered.size():
		if str(offered[o].element_leaf_path).ends_with(tower.get_meta(LEAF_META, "")):
			index = o
	var gold_before : float = level.player_stats.gold
	upgrades._on_gold_upgrade_pressed(index)
	if level.player_stats.gold < gold_before:
		gold_spent += gold_before - level.player_stats.gold
		purchases[tower] = purchases.get(tower, 0) + 1


func _has_options(level : Level, tower : Building) -> bool:
	level.building_type_upgrades._on_unit_selected(tower)
	#a tier whose talent is not learned is shown locked, never bought
	return level.building_type_upgrades.options.any(func(o : GoldUpgradeOption) -> bool: return not o.is_locked)


## The free cell, off the routes, that has the most route cells in range; nearer the castle on a tie.
func _best_tower_cell(level : Level, range_tiles : float) -> Vector2i:
	var route_cells : Array[Vector2i] = _route_cells(level)
	var on_route : Dictionary[Vector2i, bool] = {}
	for cell in route_cells:
		on_route[cell] = true
	var castle : Vector2i = level.grid.world_position_to_grid(level.end_point.global_position)
	var best : Vector2i = Vector2i.MAX
	var best_score : float = 0.0
	var region : Rect2i = level.grid.astar_grid.region
	var reach : float = range_tiles * range_tiles

	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var cell : Vector2i = Vector2i(x, y)
			if on_route.has(cell) or not _is_free_to_build(level, cell):
				continue
			var covered : int = 0
			for route_cell in route_cells:
				if Vector2(route_cell - cell).length_squared() <= reach:
					covered += 1
			var score : float = covered - Vector2(cell - castle).length() * 0.01
			if covered > 0 and score > best_score:
				best_score = score
				best = cell
	return best


## The route cell the most towers reach.
func _best_trap_cell(level : Level) -> Vector2i:
	var best : Vector2i = Vector2i.MAX
	var best_score : int = 0
	for cell in _route_cells(level):
		if not _is_free_to_build(level, cell):
			continue
		var score : int = 0
		for tower in towers:
			if is_instance_valid(tower) and Vector2(tower.grid_position - cell).length() <= _range_of(TOWERS[0]):
				score += 1
		if score > best_score:
			best_score = score
			best = cell
	return best


## The route cell that, as a wall, keeps the most route cells in the towers' reach, then makes the
## routes longest, without closing any route. A wall never pulls the route away from the towers.
func _best_wall_cell(level : Level) -> Vector2i:
	var best : Vector2i = Vector2i.MAX
	var best_score : int = _wall_score(_open_routes(level))
	var ends : Dictionary[Vector2i, bool] = {}
	for spawner in level.get_spawners():
		ends[level.grid.world_position_to_grid(spawner.global_position)] = true
		ends[level.grid.world_position_to_grid(spawner.end_point.global_position)] = true

	for cell in _route_cells(level):
		if ends.has(cell) or not _is_free_to_build(level, cell):
			continue
		level.grid.set_cell_weight(cell, BLOCKED_WEIGHT)
		var routes : Array[Array] = _open_routes(level)
		level.grid.set_cell_weight(cell, 1.0)
		if routes.is_empty():
			continue
		var score : int = _wall_score(routes)
		if score > best_score:
			best_score = score
			best = cell
	return best


#route cells in each tower's reach (a cell two towers reach counts twice) count far more than the
#route's length, so a wall never trades one tower's time on the enemies for another's
func _wall_score(routes : Array[Array]) -> int:
	var covered : int = 0
	var length : int = 0
	for route in routes:
		length += route.size()
		for cell in route:
			for tower in towers:
				if is_instance_valid(tower) and Vector2(tower.grid_position - cell).length_squared() <= tower.get_meta(RANGE_META, 0.0) ** 2:
					covered += 1
	return covered * WALL_COVER_WEIGHT + length


#every route's cells, or none when one has to go through a building
func _open_routes(level : Level) -> Array[Array]:
	var routes : Array[Array] = []
	var ids : Dictionary[int, bool] = _active_spawner_ids(level)
	for spawner in level.get_spawners():
		if not ids.is_empty() and not ids.has(spawner.id):
			continue
		var from : Vector2i = level.grid.world_position_to_grid(spawner.global_position)
		var to : Vector2i = level.grid.world_position_to_grid(spawner.end_point.global_position)
		var path : Array[Vector2i] = level.grid.astar_grid.get_id_path(from, to)
		for cell in path:
			if level.grid.astar_grid.get_point_weight_scale(cell) >= BLOCKED_WEIGHT:
				return []
		routes.append(path)
	return routes


func _route_length(level : Level) -> int:
	var total : int = 0
	for path in _paths(level):
		total += path.size()
	return total


func _route_cells(level : Level) -> Array[Vector2i]:
	var cells : Dictionary[Vector2i, bool] = {}
	for path in _paths(level):
		for point in path:
			cells[level.grid.world_position_to_grid(point)] = true
	return cells.keys()


#the routes of the spawners the coming (or running) wave uses, so the gold goes where the enemies walk
func _paths(level : Level) -> Array[PackedVector2Array]:
	var ids : Dictionary[int, bool] = _active_spawner_ids(level)
	if cached_paths.is_empty() or cached_ids != ids:
		cached_paths.clear()
		cached_ids = ids
		for spawner in level.get_spawners():
			if ids.is_empty() or ids.has(spawner.id):
				cached_paths.append(level.grid.find_path(spawner.global_position, spawner.end_point.global_position))
	return cached_paths


func _active_spawner_ids(level : Level) -> Dictionary[int, bool]:
	var runner : WaveRunner = level.wave_runner
	var index : int = runner.current_wave_index if runner.is_spawning or not level.existing_enemies.is_empty() else runner.current_wave_index + 1
	var ids : Dictionary[int, bool] = {}
	if index >= 0 and index < runner.waves.size():
		for group in runner.waves[index].spawn_groups:
			ids[group.spawner_id] = true
	return ids


func _is_free_to_build(level : Level, cell : Vector2i) -> bool:
	return level.grid.is_position_buildable(level.grid.grid_position_to_world(cell)) and not level.grid.has_building_in_cell_position(cell)


func _price_of(scene_name : String) -> float:
	if not prices.has(scene_name):
		prices[scene_name] = _base_stat(scene_name, Utils.StatType.Price)
	return prices[scene_name]


func _range_of(scene_name : String) -> float:
	var key : String = scene_name + "_range"
	if not prices.has(key):
		#the skill's range, or the unit's when the skill has none
		var instance : Node = load(TestKit.BUILDING_PATH % scene_name).instantiate()
		var range_tiles : float = 0.0
		for stats in instance.find_children("*", "Stats", true, false):
			for stat in stats.get_children():
				if stat is Stat and stat.type == Utils.StatType.AttackRange:
					range_tiles = maxf(range_tiles, stat.base_value)
		instance.free()
		prices[key] = range_tiles
	return prices[key]


func _base_stat(scene_name : String, type : Utils.StatType) -> float:
	var instance : Node = load(TestKit.BUILDING_PATH % scene_name).instantiate()
	var value : float = 0.0
	for stat in instance.get_node("Stats").get_children():
		if stat is Stat and stat.type == type:
			value = stat.base_value
	instance.free()
	return value


func _on_enemy_spawned(enemy : Enemy) -> void:
	_add(spawned, _type_of(enemy), 1)
	LevelModeData.scale_health(enemy, float(options.health))
	var speed_factor : float = float(options.speed)
	if not is_equal_approx(speed_factor, 1.0):
		var faster : ModifierData = ModifierData.new()
		faster.stat_type = Utils.StatType.Speed
		faster.calculate_type = Utils.ModifyType.Multiply
		faster.value = speed_factor - 1.0
		enemy.modifier_manager.add_modifier(faster)


func _on_enemy_hit(enemy : Enemy, hit : DamageData) -> void:
	if hit.damage <= 0.0:
		return
	var source : String = _type_of(hit.source) if is_instance_valid(hit.source) else "none"
	if hit.is_reaction:
		source += " reaction"
	elif hit.is_overtime:
		source += " effects"
	_add(tower_damage, source, hit.damage)
	_add(enemy_damage, _type_of(enemy), hit.damage)


func _type_of(node : Node) -> String:
	return String(node.name).rstrip(DIGITS)


func _add(totals : Dictionary, key : String, amount : float) -> void:
	totals[key] = totals.get(key, 0) + amount


func _rounded(totals : Dictionary[String, float]) -> Dictionary[String, int]:
	var out : Dictionary[String, int] = {}
	for key in totals:
		out[key] = roundi(totals[key])
	return out


func _is_unlocked(building_name : String) -> bool:
	if options.unlocked == "all":
		return true
	var element : BuildingListElement = load(BUILDING_LIST_PATH % building_name)
	return element.is_unlocked(int(options.level))
