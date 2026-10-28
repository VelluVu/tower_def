extends RefCounted

## A bot plays one level through the real Main and reports the result, lives, reactions and damage
## per tower and enemy type; the run is also written to user://bot_playtests.jsonl like a player's
## run (`python tools/playtests.py --bot`). Script errors show up in the output.
## `python tools/gd.py run tools/reports/soak_level.gd level=4 [key=value...] --raw`
##   economy=real|free   real: the level's own gold; free: gold is topped up every frame
##   talents=none|all|fire:30,building:10   points per tree, spent on the nearest working nodes
##   health=1.0 speed=1.0 life=N             enemy multipliers and starting life (Hard mode)
##   rotation=0-2        which element each tower type takes (Fire, Frost, Poison shifted by rotation)
##   order=fixed|shuffle tower types in Bolter, Nova, Beamer order or shuffled
##   towers=12 traps=2   most towers and traps the bot builds
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

var options : Dictionary[String, String] = {
	"level": "1", "economy": "real", "talents": "none", "health": "1.0", "speed": "1.0", "life": "",
	"rotation": "0", "order": "fixed", "towers": "12", "traps": "2", "min_towers": "3", "depth": "3",
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


func run(kit : TestKit, args : PackedStringArray) -> void:
	for arg in args:
		var parts : PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2:
			options[parts[0]] = parts[1]
	seed(int(options.seed))
	PlaytestLog.is_enabled = true
	PlaytestLog.player = "bot " + " ".join(args)

	var spent_talents : Dictionary[String, int] = _spend_talents(options.talents)
	var main : Main = load(MAIN_SCENE).instantiate()
	kit.root.add_child(main)
	await kit.frames(2)

	UISignals.start_level_button_pressed.emit(int(options.level))
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

	print("SOAK level %s, %s economy, start gold %.0f, talents %s, health x%s, speed x%s, life %.0f" % [
		options.level, options.economy, level.player_stats.gold, spent_talents, options.health, options.speed, starting_life])

	var speed_up : float = float(options.speed_up)
	main.time_scale = speed_up
	GameSignals.time_scale_change.emit(speed_up)
	var is_early : bool = options.early == "1"
	var start_length : int = _route_length(level)

	var time : float = 0.0
	while result == "timeout" and time < LEVEL_SECONDS:
		if is_free:
			level.player_stats.gold = FREE_GOLD
		#the first wave waits until the opening build is done
		await _spend(kit, level)
		if not level.upgrades.offered_cards.is_empty():
			cards += 1
			level.upgrades._on_upgrade_card_selected(randi() % level.upgrades.offered_cards.size())
		var is_ready : bool = level.wave_runner.wave_number > 0 or towers.size() >= int(options.min_towers)
		if is_ready and level.wave_runner.can_start_next_wave and (is_early or level.existing_enemies.is_empty()):
			UISignals.start_wave_pressed.emit()
		await kit.root.get_tree().process_frame
		time += kit.root.get_process_delta_time()

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
	for part in spec.split(",", false):
		var pair : PackedStringArray = part.split(":")
		if pair.size() == 2:
			budgets[pair[0]] = int(pair[1])

	var spent : Dictionary[String, int] = {}
	for tree in TALENT_BOOK.trees:
		PlayerProgress.reset_talent_tree(tree.id)
		var ranks : Dictionary = {}

		if spec == "all":
			for node in tree.nodes:
				ranks[node.id] = node.max_rank
		else:
			var points : int = budgets.get(String(tree.id), 0)
			var steps : Dictionary[StringName, int] = _tree_steps(tree)
			while points > 0:
				var best : TalentNode = null
				for node in tree.nodes:
					if TalentRules.can_add(tree, ranks, node, points) and (best == null or _is_better_node(node, best, steps)):
						best = node
				if best == null:
					break
				ranks[best.id] = TalentRules.get_rank(ranks, best.id) + 1
				points -= 1

		for node_id in ranks:
			PlayerProgress.set_talent_rank(tree.id, node_id, ranks[node_id])
		if not ranks.is_empty():
			spent[String(tree.id)] = TalentRules.get_spent(ranks)

	return spent


func _is_better_node(node : TalentNode, other : TalentNode, steps : Dictionary[StringName, int]) -> bool:
	if node.is_implemented != other.is_implemented:
		return node.is_implemented
	return steps.get(node.id, 99) < steps.get(other.id, 99)


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
	if wall_share > 0.0 and not is_wall_exhausted and wall_gold <= wall_share * gold_spent:
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

	if towers.size() < tower_cap:
		await _place_tower(kit, level)
	elif behind != null:
		await _buy_next(level, behind)


func _place_tower(kit : TestKit, level : Level) -> void:
	if type_order.is_empty():
		for type in TOWERS.size():
			if _is_unlocked(TOWERS[type]):
				type_order.append(type)
		if options.order == "shuffle":
			type_order.shuffle()
	var type : int = type_order[0]
	if not level.player_stats.has_enough_gold(_price_of(TOWERS[type])):
		return
	var cell : Vector2i = _best_tower_cell(level, _range_of(TOWERS[type]))
	if cell == Vector2i.MAX:
		return
	type_order.pop_front()
	var tower : Building = await _place(kit, level, TOWERS[type], cell)
	tower.set_meta(LEAF_META, LEAVES[(type + int(options.rotation)) % LEAVES.size()])
	tower.set_meta(RANGE_META, _range_of(TOWERS[type]))
	towers.append(tower)
	purchases[tower] = 0


#PlayerStats takes the price itself when the building is placed
func _place(kit : TestKit, level : Level, scene_name : String, cell : Vector2i) -> Building:
	var price : float = _price_of(scene_name)
	gold_spent += price
	if scene_name == WALL:
		wall_gold += price
	return await kit.place(scene_name, cell)


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
	return not level.building_type_upgrades.options.is_empty()


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
	var health_factor : float = float(options.health)
	if not is_equal_approx(health_factor, 1.0):
		var max_health : Stat = enemy.stats.get_stat(Utils.StatType.MaxHealth)
		max_health.value *= health_factor
		enemy.stats.get_stat(Utils.StatType.Health).value = max_health.value
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
